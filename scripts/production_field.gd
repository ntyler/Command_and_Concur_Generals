class_name ProductionField
extends TestField

var rifle_scene: PackedScene = load("res://scenes/rifle_unit.tscn")
const BASE_OBSTACLES: Array[Rect2] = [Rect2(-24, -10, 7, 6), Rect2(-21, 4, 6, 5), Rect2(-3, -10, 4, 7), Rect2(5, 6, 4, 6)]
const STARTS: Array[Vector3] = [Vector3(-21, 0, 13), Vector3(-18, 0, 13), Vector3(-15, 0, 13), Vector3(18, 0, -4), Vector3(18, 0, 0), Vector3(18, 0, 4)]
# Six local samples, fixed order, at most 1.56 units from the designated exit.
const SPAWN_OFFSETS: Array[Vector3] = [Vector3.ZERO, Vector3(0, 0, -1.1), Vector3(0, 0, 1.1), Vector3(1.1, 0, 0), Vector3(1.1, 0, -1.1), Vector3(1.1, 0, 1.1)]

@export var starting_credits: int = 1000
var credits: PlayerCredits
var headquarters: RTSBuilding
var barracks: RTSBuilding
var production_panel: ProductionPanel
var _buildings: Dictionary[int, WeakRef] = {}
var _producers: Dictionary[int, UnitProduction] = {}
var _next_job: int = 0
var _next_unit: int = STARTS.size()
var _closing: bool = false
var _spawn_query: PhysicsShapeQueryParameters3D
var _claims_frame: int = -1
var _spawn_claims := PackedVector3Array()


func _ready() -> void:
	credits = PlayerCredits.new([1, 2], starting_credits)
	_spawn_query = PhysicsShapeQueryParameters3D.new()
	_spawn_query.shape = RTSUnit.body_shape()
	_spawn_query.collision_mask = 2 | 4 | LineOfFire.BLOCKER_MASK
	_spawn_query.margin = 0.001
	obstacles = BASE_OBSTACLES.duplicate()
	super._ready()
	barracks.production.has_rally = true
	barracks.production.rally_point = Vector3(-8, 0, 3)
	production_panel = ProductionPanel.new()
	production_panel.field = self
	get_node("ControlsFeedback").add_child(production_panel)
	var controls := info_panel.get_child(0).get_child(1) as Label
	controls.text = "WASD / arrows / edges · Pan    Wheel · Zoom\nClick / drag / Shift · Select units\nClick owned building · Select building\nBarracks + right click ground · Set rally\nUnits + right click · Move / attack hostile\nX · Stop units    F3 · Debug (off by default)"
	(info_panel.get_child(0).get_child(0) as Label).text = "FIELDWORK  /  PRODUCTION"
	_on_selection_changed(0)


func _on_selection_changed(count: int) -> void:
	if not is_instance_valid(status_label):
		return
	status_label.text = "%02d units selected  /  Alpha: mint  /  Bravo: coral" % count


func _unit_count() -> int:
	return STARTS.size()


func _create_unit(index: int) -> RTSUnit:
	var unit := rifle_scene.instantiate() as RTSUnit
	unit.unit_id = index + 1
	unit.name = "Rifle%02d" % unit.unit_id
	unit.position = STARTS[index]
	unit.owner_id = 1 if index < 3 else 2
	unit.retaliation_enabled = index >= 3
	return unit


func _build_obstacle(index: int, rectangle: Rect2) -> void:
	if index > 1:
		super._build_obstacle(index, rectangle)
		return
	var building := RTSBuilding.new()
	building.kind = RTSBuilding.Kind.HEADQUARTERS if index == 0 else RTSBuilding.Kind.BARRACKS
	building.name = building.display_name()
	building.footprint = rectangle.size
	building.position = Vector3(rectangle.get_center().x, 0, rectangle.get_center().y)
	building.building_height = 3.2 if index == 0 else 2.6
	add_child(building)
	register_building(building)
	if index == 0:
		headquarters = building
	else:
		barracks = building


func contains_building(building: RTSBuilding) -> bool:
	if _closing or not is_inside_tree() or is_queued_for_deletion() or not is_instance_valid(building) or not building.is_inside_tree() or not _buildings.has(building.get_instance_id()):
		return false
	var ancestor: Node = building
	while ancestor != null and ancestor != self:
		if ancestor.is_queued_for_deletion():
			return false
		ancestor = ancestor.get_parent()
	return ancestor == self


func register_building(building: RTSBuilding) -> void:
	if _closing or not is_instance_valid(building) or not is_ancestor_of(building) or building.is_queued_for_deletion():
		return
	var id := building.get_instance_id()
	_buildings[id] = weakref(building)
	if building.kind == RTSBuilding.Kind.BARRACKS and not _producers.has(id):
		building.production = UnitProduction.new(self, building, credits)
		_producers[id] = building.production
	var exiting := _building_exiting.bind(id)
	if not building.tree_exiting.is_connected(exiting):
		building.tree_exiting.connect(exiting)
		building.tree_entered.connect(register_building.bind(building))


func _building_exiting(id: int) -> void:
	# tree_exiting also occurs during reparent. Decide after that operation finishes;
	# the field retains only weak node refs and the small refund-capable queue.
	_reconcile_departure.call_deferred(id)


func _reconcile_departure(id: int) -> void:
	if _closing or not _buildings.has(id):
		return
	var building := _buildings[id].get_ref() as RTSBuilding
	if is_instance_valid(building) and contains_building(building):
		return
	_buildings.erase(id)
	var producer := _producers.get(id) as UnitProduction
	_producers.erase(id)
	if producer != null:
		producer.close(true)
	if is_instance_valid(self) and is_instance_valid(selection):
		selection.prune_building()


func next_job_id() -> int:
	_next_job += 1
	return _next_job


func _nav_point(point: Vector3) -> bool:
	if not point.is_finite() or absf(point.y) > 0.05 or not field_bounds.grow(-CLEARANCE).has_point(Vector2(point.x, point.z)):
		return false
	var map := get_world_3d().get_navigation_map()
	return NavigationServer3D.map_get_iteration_id(map) > 0 and NavigationServer3D.map_get_closest_point_owner(map, point) == navigation_region.get_rid() and NavigationServer3D.map_get_closest_point(map, point).distance_to(point) <= 0.02


func valid_rally(origin: Vector3, point: Vector3) -> bool:
	if not _nav_point(origin) or not _nav_point(point):
		return false
	var path := NavigationServer3D.map_get_path(get_world_3d().get_navigation_map(), origin, point, true)
	return not path.is_empty() and path[-1].distance_to(point) <= 0.02


func find_spawn(building: RTSBuilding) -> PackedVector3Array:
	if not Engine.is_in_physics_frame() or not contains_building(building):
		return PackedVector3Array()
	var exit_point := building.exit_position()
	if not _nav_point(exit_point):
		return PackedVector3Array()
	if _claims_frame != Engine.get_physics_frames():
		_claims_frame = Engine.get_physics_frames()
		_spawn_claims.clear()
	for offset in SPAWN_OFFSETS:
		var point := exit_point + offset
		if not _nav_point(point):
			continue
		# Require a direct local navigation segment. A short projection must never
		# manufacture a spawn on the other side of a wall or across a disconnected hole.
		var path := NavigationServer3D.map_get_path(get_world_3d().get_navigation_map(), exit_point, point, true)
		var length := 0.0
		for i in range(1, path.size()):
			length += path[i - 1].distance_to(path[i])
		if path.is_empty() or path[-1].distance_to(point) > 0.02 or length > exit_point.distance_to(point) + 0.02:
			continue
		_spawn_query.transform = Transform3D(Basis.IDENTITY, point + RTSUnit.BODY_CENTER)
		if not get_world_3d().direct_space_state.intersect_shape(_spawn_query, 1).is_empty():
			continue
		var claimed := false
		for previous in _spawn_claims:
			if previous.distance_to(point) < RTSUnit.BODY_RADIUS * 2.0 + 0.002:
				claimed = true
				break
		if claimed:
			continue
		# Covers two producers deploying before newly added collision bodies sync.
		_spawn_claims.append(point)
		return PackedVector3Array([point])
	return PackedVector3Array()


func prepare_deployment(scene: PackedScene, owner_id: int, point: Vector3) -> RTSUnit:
	if scene == null or not scene.can_instantiate():
		return null
	var instance := scene.instantiate()
	if not instance is RTSUnit:
		instance.free()
		return null
	var unit := instance as RTSUnit
	_next_unit += 1
	unit.unit_id = _next_unit
	unit.name = "ProducedRifle%03d" % unit.unit_id
	unit.owner_id = owner_id
	unit.position = point
	unit.hide()
	add_child(unit)
	if not is_instance_valid(unit):
		return null
	register_unit(unit)
	if is_instance_valid(unit) and contains_unit(unit):
		unit.set_movement_debug(movement_debug)
	return unit


func order_deployed_unit(unit: RTSUnit, destination: Vector3) -> bool:
	if not contains_unit(unit) or not valid_rally(unit.global_position, destination):
		return false
	return unit.move_to(destination)


func _exit_tree() -> void:
	_closing = true
	if credits != null:
		credits.active = false
	for producer in _producers.values():
		producer.close(false)
	_producers.clear()
	_buildings.clear()
	_spawn_claims.clear()
