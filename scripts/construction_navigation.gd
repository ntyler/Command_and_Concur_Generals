class_name ConstructionNavigation
extends RefCounted
## Serialized rectangle meshes. Submission is not readiness: both server iterations
## and geometry witness queries must describe the intended map before resuming units.

signal ready(generation: int)
signal failed(generation: int, reason: String)
signal synchronized(generation: int) # Commit guarded colliders before resuming actors.

var generation: int = 0
var busy: bool = false
var blocked: bool = false
var closed: bool = false
var submissions: int = 0
var last_build_usec: int = 0
var last_prepare_usec: int = 0
var last_prepare_seconds: float = 0.0
var _field_ref: WeakRef
var _desired: Array[Rect2] = []
var _submitted: Array[Rect2] = []
var _previous: Array[Rect2] = []
var _active_generation: int = 0
var _resume_generation: int = 0
var _mesh: NavigationMesh
var _map: RID
var _region: RID
var _map_iteration: int = 0
var _region_iteration: int = 0
var _elapsed: float = 0.0
var _started_usec: int = 0


func _init(field: ConstructionField) -> void:
	_field_ref = weakref(field)


func field() -> ConstructionField:
	var value := _field_ref.get_ref() as ConstructionField
	return value if not closed and is_instance_valid(value) and value.is_inside_tree() and not value._closing and not value.is_queued_for_deletion() else null


func request(rectangles: Array[Rect2]) -> int:
	if field() == null:
		return 0
	generation += 1
	_desired = rectangles.duplicate()
	busy = true
	blocked = true
	# No signal or mesh submission here. The caller first stores this generation
	# on its committed site; even immediate failure is published on a later tick.
	for unit in field().units.duplicate():
		if field() == null:
			break
		if is_instance_valid(unit) and field().contains_unit(unit):
			unit.suspend_navigation()
	return generation


func advance(delta: float) -> void:
	if field() == null:
		return
	if field().manual_pause_active:
		return # Keep pending topology; result/deletion cleanup remains valid.
	if _resume_generation != 0:
		_finish_ready()
		return
	if not busy:
		return
	if _active_generation == 0:
		_submit()
		return
	_elapsed += delta
	if _synchronized():
		_previous = _submitted.duplicate()
		last_prepare_seconds = _elapsed
		last_prepare_usec = Time.get_ticks_usec() - _started_usec
		var finished := _active_generation
		if finished != generation:
			_submit()
			return
		# Gate transitions may reject their final close occupancy check and submit
		# a rollback here. No actor sees the intermediate unusable navigation.
		synchronized.emit(finished)
		if field() == null or finished != generation:
			return
		if field().manual_pause_active:
			return # Retry the synchronized notification after resume; retain its mesh.
		_active_generation = 0
		_mesh = null
		_resume_generation = finished
		_finish_ready()
	elif _elapsed >= field().navigation_timeout:
		_fail("Navigation synchronization timed out; cancel site to restore terrain")


func _finish_ready() -> void:
	var finished := _resume_generation
	if field() == null or field().manual_pause_active:
		return
	if finished != generation:
		_resume_generation = 0
		return
	busy = false
	blocked = false
	for unit in field().units.duplicate():
		if field() == null or field().manual_pause_active:
			return # Already resumed actors are idempotent; remaining actors wait.
		if busy or finished != generation:
			_resume_generation = 0
			return
		if is_instance_valid(unit) and field().contains_unit(unit):
			unit.resume_navigation()
	_resume_generation = 0
	if field() != null and generation == finished and not busy:
		ready.emit(finished)


func _submit() -> void:
	_active_generation = generation
	_submitted = _desired.duplicate()
	_elapsed = 0.0
	_started_usec = Time.get_ticks_usec()
	var owner := field()
	_map = owner.get_world_3d().get_navigation_map()
	_region = owner.navigation_region.get_rid()
	_map_iteration = NavigationServer3D.map_get_iteration_id(_map)
	_region_iteration = NavigationServer3D.region_get_iteration_id(_region)
	var start := Time.get_ticks_usec()
	_mesh = owner.prepare_construction_mesh(_submitted)
	last_build_usec = Time.get_ticks_usec() - start
	if field() == null:
		return
	if _mesh == null or _mesh.get_polygon_count() == 0:
		_fail("Navigation preparation failed; paid site remains refundable")
		return
	submissions += 1
	owner.navigation_region.navigation_mesh = _mesh


func _synchronized() -> bool:
	var owner := field()
	if owner == null or owner.get_world_3d().get_navigation_map() != _map or owner.navigation_region.get_rid() != _region or owner.navigation_region.navigation_mesh != _mesh:
		return false
	if NavigationServer3D.region_get_map(_region) != _map:
		return false
	var map_version := NavigationServer3D.map_get_iteration_id(_map)
	var region_version := NavigationServer3D.region_get_iteration_id(_region)
	if map_version == 0 or map_version == _map_iteration or region_version == 0 or region_version == _region_iteration:
		return false
	# Witness the added AND removed holes, plus a stable open corner. These query
	# checks supplement (not replace) actual-path and traversal regression tests.
	if not _witness(Vector2(27, 21)):
		return false
	for rectangles in [_submitted, _previous]:
		for rectangle: Rect2 in rectangles:
			for point in [rectangle.get_center(), rectangle.position + Vector2(0.1, 0.1), rectangle.end - Vector2(0.1, 0.1)]:
				if not _witness(point):
					return false
	return true


func _witness(point: Vector2) -> bool:
	var obstructed := false
	for rectangle in _submitted:
		if rectangle.grow(TestField.CLEARANCE).has_point(point):
			obstructed = true
			break
	var world := Vector3(point.x, 0, point.y)
	var navigable := NavigationServer3D.map_get_closest_point_owner(_map, world) == _region and NavigationServer3D.map_get_closest_point(_map, world).distance_to(world) <= 0.02
	return navigable != obstructed


func _fail(reason: String) -> void:
	var failed_generation := _active_generation
	_active_generation = 0
	_mesh = null
	if failed_generation != generation:
		return # A queued cancellation gets one fresh submission on the next tick.
	busy = false
	blocked = true
	failed.emit(failed_generation, reason)


func close() -> void:
	closed = true
	generation += 1
	busy = false
	_active_generation = 0
	_resume_generation = 0
	_mesh = null
	_desired.clear()
	_submitted.clear()
	_previous.clear()
	for connection in ready.get_connections():
		ready.disconnect(connection["callable"])
	for connection in failed.get_connections():
		failed.disconnect(connection["callable"])
	for connection in synchronized.get_connections():
		synchronized.disconnect(connection["callable"])
