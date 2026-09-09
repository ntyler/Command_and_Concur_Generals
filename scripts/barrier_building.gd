class_name BarrierBuilding
extends ConstructionBuilding
## Ground barriers share one picked/damageable body. Only the gate leaf changes;
## retained supports always block both movement and weapon/world traces.

signal status_changed

@export var orientation_degrees: int = 0
@export var initial_open: bool = false
var requested_open: bool = false
var physical_open: bool = false
var navigation_pending: bool = false
var effective_ready: bool = true
var transition_generation: int = 0
var nav_generation: int = 0
var _transition_owner: int = 0
var _rollback: bool = false
var _status: String = "Closed"
var _door_collider: CollisionShape3D
var _door_visual: MeshInstance3D
var _navigation: ConstructionNavigation
var _reenter_needs_navigation: bool = false


func _ready() -> void:
	physical_open = kind == Kind.GATE and initial_open and operational
	requested_open = physical_open
	_status = "Open" if physical_open else "Closed"
	super._ready()
	if definition != null:
		enable_damage(definition.maximum_health)
	availability_changed.connect(_availability_updated)


func _build_geometry() -> void:
	if kind == Kind.WALL:
		_solid(footprint, Vector2.ZERO, Color("718786"))
		return
	var size := definition.footprint
	var support := (size.x - definition.gate_opening) / 2.0
	for side in [-1.0, 1.0]:
		var offset := _oriented(Vector2(side * (size.x / 2.0 - support / 2.0), 0))
		_solid(_oriented(Vector2(support, size.y)).abs(), offset, Color("a3b6ad"))
	var door_size := _oriented(Vector2(definition.gate_opening, size.y)).abs()
	_door_collider = _solid(door_size, Vector2.ZERO, Color("5e797b"))
	_door_visual = get_child(get_child_count() - 1) as MeshInstance3D
	_set_physical(physical_open)


func _oriented(value: Vector2) -> Vector2:
	return Vector2(value.y, value.x) if orientation_degrees == 90 else value


func _solid(size: Vector2, offset: Vector2, color: Color) -> CollisionShape3D:
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(size.x, building_height, size.y)
	collider.shape = box
	collider.position = Vector3(offset.x, building_height / 2.0, offset.y)
	add_child(collider)
	_mesh(box.size, collider.position, color if owner_id == 1 else color.lerp(Color("b46c62"), 0.6))
	return collider


func rectangle() -> Rect2:
	return Rect2(Vector2(global_position.x, global_position.z) - footprint / 2.0, footprint)


func doorway_rectangle() -> Rect2:
	var size := _oriented(Vector2(definition.gate_opening, definition.footprint.y)).abs()
	return Rect2(Vector2(global_position.x, global_position.z) - size / 2.0, size)


func navigation_footprints() -> Array[Rect2]:
	var rectangles: Array[Rect2] = []
	if destroyed or _departing or is_queued_for_deletion():
		return rectangles
	if kind == Kind.WALL or not requested_open or not operational:
		rectangles.append(rectangle())
		return rectangles
	var center := Vector2(global_position.x, global_position.z)
	var size := definition.footprint
	var support := (size.x - definition.gate_opening) / 2.0
	var support_size := _oriented(Vector2(support, size.y)).abs()
	for side in [-1.0, 1.0]:
		var offset := _oriented(Vector2(side * (size.x / 2.0 - support / 2.0), 0))
		rectangles.append(Rect2(center + offset - support_size / 2.0, support_size))
	return rectangles


func barrier_blocks_ground() -> bool:
	return is_alive() and (kind == Kind.WALL or not physical_open or navigation_pending)


func owns_weapon_collider(collider_id: int) -> bool:
	return collider_id == get_instance_id()


func aim_position() -> Vector3:
	# Open gates are targeted at exposed support geometry, never empty doorway.
	var offset := Vector2.ZERO
	if kind == Kind.GATE and physical_open:
		var support := (definition.footprint.x - definition.gate_opening) / 2.0
		offset = _oriented(Vector2(-definition.footprint.x / 2.0 + support / 2.0, 0))
	return global_position + Vector3(offset.x, minf(building_height * 0.5, LineOfFire.AIM_HEIGHT), offset.y)


func gate_status() -> String:
	if destroyed or _departing:
		return "Destroyed"
	if not operational:
		return "Under construction"
	return _status if kind == Kind.GATE else "Wall"


func _owner_field() -> ConstructionField:
	var owner := gameplay_field as ConstructionField
	return owner if is_instance_valid(owner) and owner.is_inside_tree() and not owner._closing and not owner.is_queued_for_deletion() and owner.contains_building(self) and gameplay_field == owner else null


func _authorized(requester: int) -> bool:
	var owner := _owner_field()
	return owner != null and owner.gameplay_enabled and owner.construction != null and not owner.construction.closed and kind == Kind.GATE and operational and can_take_damage() and requester == owner_id


func _bind_navigation(owner: ConstructionField) -> void:
	if _navigation == owner.construction.navigation:
		return
	_disconnect_navigation()
	_navigation = owner.construction.navigation
	_navigation.synchronized.connect(_navigation_synchronized)
	_navigation.ready.connect(_navigation_ready)
	_navigation.failed.connect(_navigation_failed)


func request_gate(requester: int, open: bool) -> ConstructionResult:
	if not _authorized(requester):
		return ConstructionResult.reject("Only a live owned completed gate can be operated during the match")
	if navigation_pending:
		return ConstructionResult.reject("Gate navigation updating")
	var owner := _owner_field()
	if owner.construction.navigation.blocked:
		return ConstructionResult.reject("Navigation is not ready")
	if physical_open == open:
		return ConstructionResult.accept(0, 0, "Gate already open" if open else "Gate already closed")
	if not Engine.is_in_physics_frame():
		return ConstructionResult.reject("Gate operation requires a physics tick")
	if not open and closing_obstructed():
		_status = "Gate obstructed"
		status_changed.emit()
		return ConstructionResult.reject("Gate obstructed")
	_bind_navigation(owner)
	transition_generation += 1
	_transition_owner = requester
	requested_open = open
	navigation_pending = true
	effective_ready = false
	_rollback = false
	_status = "Opening · navigation updating" if open else "Closing · navigation updating"
	# Keep the physical leaf unchanged until the prepared map is witnessed.
	nav_generation = owner.construction._request_navigation()
	status_changed.emit()
	return ConstructionResult.accept(0, 0, "Gate opening" if open else "Gate closing")


func closing_obstructed() -> bool:
	var owner := _owner_field()
	if owner == null or not Engine.is_in_physics_frame():
		return true
	var closing := doorway_rectangle().grow(TestField.CLEARANCE + 0.002)
	for unit in owner.units:
		if owner.contains_unit(unit) and unit.is_alive() and TeamRules.target_domain(unit) == TeamRules.TargetDomain.GROUND and closing.has_point(Vector2(unit.global_position.x, unit.global_position.z)):
			return true
	return false


func _navigation_synchronized(generation: int) -> void:
	if not navigation_pending or generation != nav_generation:
		return
	if not _authorized(_transition_owner):
		freeze_gate()
		return
	if not requested_open and closing_obstructed():
		# A unit entered after the click. Restore open navigation while holding all
		# ground movement; never install a collider or queue a later automatic close.
		requested_open = true
		_rollback = true
		_status = "Gate obstructed · restoring open navigation"
		nav_generation = _owner_field().construction._request_navigation()
		status_changed.emit()
		return
	_set_physical(requested_open)


func _navigation_ready(generation: int) -> void:
	# Invalidated owner commands can finish only their rollback to the existing
	# physical state. The current owner regains controls after that synchronization.
	if not navigation_pending and not effective_ready and generation == nav_generation and requested_open == physical_open and _authorized(owner_id):
		effective_ready = true
		status_changed.emit()
		return
	if not navigation_pending or generation != nav_generation or not _authorized(_transition_owner):
		return
	navigation_pending = false
	effective_ready = true
	_status = "Gate obstructed" if _rollback else ("Open" if physical_open else "Closed")
	status_changed.emit()


func _navigation_failed(generation: int, reason: String) -> void:
	if not navigation_pending or generation != nav_generation:
		return
	transition_generation += 1
	navigation_pending = false
	effective_ready = false
	requested_open = physical_open
	_status = "Gate navigation failed: " + reason
	status_changed.emit()


func _set_physical(open: bool) -> void:
	physical_open = open
	if is_instance_valid(_door_collider):
		_door_collider.disabled = open
	if is_instance_valid(_door_visual):
		_door_visual.visible = not open


func freeze_gate() -> void:
	if not navigation_pending:
		return
	transition_generation += 1
	navigation_pending = false
	effective_ready = false
	requested_open = physical_open
	_status = "Open" if physical_open else "Closed"
	var owner := _owner_field()
	if owner != null and owner.construction != null and not owner.construction.closed:
		nav_generation = owner.construction._request_navigation()
	status_changed.emit()


func _availability_updated() -> void:
	if navigation_pending and not _authorized(_transition_owner):
		freeze_gate()


func _on_died(source: Node) -> void:
	transition_generation += 1
	navigation_pending = false
	effective_ready = false
	_disconnect_navigation()
	super._on_died(source)


func _disconnect_navigation() -> void:
	if _navigation != null:
		if _navigation.synchronized.is_connected(_navigation_synchronized):
			_navigation.synchronized.disconnect(_navigation_synchronized)
		if _navigation.ready.is_connected(_navigation_ready):
			_navigation.ready.disconnect(_navigation_ready)
		if _navigation.failed.is_connected(_navigation_failed):
			_navigation.failed.disconnect(_navigation_failed)
	_navigation = null


func _exit_tree() -> void:
	_reenter_needs_navigation = navigation_pending
	transition_generation += 1
	navigation_pending = false
	if _reenter_needs_navigation:
		effective_ready = false
	requested_open = physical_open
	_disconnect_navigation()
	# Starting barriers have no paid site/departure hook. The manager, which
	# outlives this node, reconciles their removal after a possible reparent.
	var owner := gameplay_field as ConstructionField
	if site == null and not destroyed and is_instance_valid(owner) and owner.construction != null:
		owner.construction._reconcile_barrier_departure.call_deferred(get_instance_id())
	super._exit_tree()


func _enter_tree() -> void:
	super._enter_tree()
	if _reenter_needs_navigation:
		_reconcile_reentry.call_deferred()


func _reconcile_reentry() -> void:
	var owner := _owner_field()
	if owner == null or destroyed or not _reenter_needs_navigation:
		return
	_reenter_needs_navigation = false
	_bind_navigation(owner)
	requested_open = physical_open
	navigation_pending = true
	_transition_owner = owner_id
	_status = "Gate navigation updating"
	nav_generation = owner.construction._request_navigation()
