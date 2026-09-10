class_name ProductionField
extends TestField

var rifle_scene: PackedScene = load("res://scenes/rifle_unit.tscn")
const BASE_OBSTACLES: Array[Rect2] = [Rect2(-24, -10, 7, 6), Rect2(-21, 4, 6, 5), Rect2(-3, -10, 4, 7), Rect2(5, 6, 4, 6)]
const STARTS: Array[Vector3] = [Vector3(-21, 0, 13), Vector3(-18, 0, 13), Vector3(-15, 0, 13), Vector3(18, 0, -4), Vector3(18, 0, 0), Vector3(18, 0, 4)]
# Six local samples, fixed order, at most 1.56 units from the designated exit.
const SPAWN_OFFSETS: Array[Vector3] = [Vector3.ZERO, Vector3(0, 0, -1.1), Vector3(0, 0, 1.1), Vector3(1.1, 0, 0), Vector3(1.1, 0, -1.1), Vector3(1.1, 0, 1.1)]

@export var starting_credits: int = 1000
@export var power_enabled: bool = false
var power_grid: PowerGrid
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
var _spawn_claim_radii: Array[float] = []
var _air_launch_claims: Dictionary[int, Dictionary] = {}


func _ready() -> void:
	credits = create_credits()
	power_grid = PowerGrid.new(self)
	_spawn_query = PhysicsShapeQueryParameters3D.new()
	_spawn_query.shape = RTSUnit.body_shape()
	_spawn_query.collision_mask = 2 | 4 | LineOfFire.BLOCKER_MASK
	_spawn_query.margin = 0.001
	obstacles = BASE_OBSTACLES.duplicate()
	super._ready()
	if is_instance_valid(barracks):
		barracks.production.has_rally = true
		barracks.production.rally_point = Vector3(-8, 0, 3)
	production_panel = create_production_panel()
	production_panel.field = self
	get_node("ControlsFeedback").add_child(production_panel)
	var controls := info_panel.get_child(0).get_child(1) as Label
	controls.text = "WASD / arrows / edges · Pan    Wheel · Zoom\nClick / drag / Shift · Select units\nClick owned building · Select building\nBarracks + right click ground · Set rally\nUnits + right click · Move / attack hostile\nX · Stop units    F3 · Debug (off by default)"
	(info_panel.get_child(0).get_child(0) as Label).text = "FIELDWORK  /  PRODUCTION"
	_on_selection_changed(0)


func create_credits() -> PlayerCredits:
	return PlayerCredits.new([1, 2], starting_credits)


func _on_selection_changed(count: int) -> void:
	if not is_instance_valid(status_label):
		return
	status_label.text = "%02d units selected  /  Alpha: mint  /  Bravo: coral" % count


func create_production_panel() -> ProductionPanel:
	return ProductionPanel.new()


func dropoff_command_hint() -> String:
	return "HQ"


func refresh_power() -> void:
	if power_grid != null:
		power_grid.refresh()


func power_snapshot(owner_id: int) -> Dictionary:
	return power_grid.snapshot(owner_id) if power_grid != null else {"generated": 0, "required": 0, "low_power": false, "multiplier": 1.0}


func production_multiplier(building: RTSBuilding) -> float:
	if not power_enabled or not is_instance_valid(building) or building.kind not in [RTSBuilding.Kind.BARRACKS, RTSBuilding.Kind.VEHICLE_FACTORY, RTSBuilding.Kind.AIRFIELD]:
		return 1.0
	return power_snapshot(building.owner_id).multiplier


func defense_firing_allowed(building: RTSBuilding, notify: bool = true) -> bool:
	# Power publication can synchronously destroy/reparent actors or Restart.
	# A firing decision belongs to this exact live field, owner and grid.
	if not gameplay_enabled or not power_enabled or power_grid == null or not is_instance_valid(building) or building.kind not in [RTSBuilding.Kind.GROUND_DEFENSE_BATTERY, RTSBuilding.Kind.AIR_DEFENSE_BATTERY] or building.gameplay_field != self or not building.operational or not contains_building(building):
		return false
	var owner := building.owner_id
	var grid := power_grid
	var allowed := grid.firing_eligible(owner, notify)
	return allowed and is_instance_valid(self) and gameplay_enabled and power_enabled and power_grid == grid and grid.active and is_instance_valid(building) and building.owner_id == owner and building.gameplay_field == self and building.operational and contains_building(building)


func set_movement_debug(enabled: bool) -> void:
	super.set_movement_debug(enabled)
	for building in registered_buildings():
		building.set_movement_debug(enabled)


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
	if _closing or not is_inside_tree() or is_queued_for_deletion() or not is_instance_valid(building) or not building.is_inside_tree() or not building.is_alive() or not _buildings.has(building.get_instance_id()):
		return false
	var ancestor: Node = building
	while ancestor != null and ancestor != self:
		if ancestor.is_queued_for_deletion():
			return false
		ancestor = ancestor.get_parent()
	return ancestor == self


func register_building(building: RTSBuilding) -> void:
	if _closing or not is_instance_valid(building) or not is_ancestor_of(building) or building.is_queued_for_deletion() or not building.is_alive():
		return
	building.gameplay_field = self
	if building.definition == null:
		match building.kind:
			RTSBuilding.Kind.BARRACKS: building.definition = load("res://construction/barracks.tres")
			RTSBuilding.Kind.VEHICLE_FACTORY: building.definition = load("res://construction/vehicle_factory.tres")
			RTSBuilding.Kind.SUPPLY_DEPOT: building.definition = load("res://construction/supply_depot.tres")
			RTSBuilding.Kind.POWER_PLANT: building.definition = load("res://construction/power_plant.tres")
			RTSBuilding.Kind.GROUND_DEFENSE_BATTERY: building.definition = load("res://construction/ground_defense_battery.tres")
			RTSBuilding.Kind.AIRFIELD: building.definition = load("res://construction/airfield.tres")
			RTSBuilding.Kind.AIR_DEFENSE_BATTERY: building.definition = load("res://construction/air_defense_battery.tres")
	if building.kind in [RTSBuilding.Kind.GROUND_DEFENSE_BATTERY, RTSBuilding.Kind.AIR_DEFENSE_BATTERY]:
		building.recipe = null
		building.enable_damage(building.definition.maximum_health)
	building.set_movement_debug(movement_debug)
	var id := building.get_instance_id()
	_buildings[id] = weakref(building)
	var produces_units := building.kind in [RTSBuilding.Kind.BARRACKS, RTSBuilding.Kind.VEHICLE_FACTORY, RTSBuilding.Kind.SUPPLY_DEPOT, RTSBuilding.Kind.AIRFIELD] or (building.kind == RTSBuilding.Kind.HEADQUARTERS and building.supports_recipe(building.recipe))
	if produces_units and not _producers.has(id):
		building.production = UnitProduction.new(self, building, credits)
		_producers[id] = building.production
	var exiting := _building_exiting.bind(id)
	if not building.tree_exiting.is_connected(exiting):
		building.tree_exiting.connect(exiting)
		building.tree_entered.connect(register_building.bind(building))
	if building is GroundDefenseBattery:
		(building as GroundDefenseBattery).activate_defense()
	if power_enabled and power_grid != null:
		power_grid.refresh.call_deferred()


func registered_buildings() -> Array[RTSBuilding]:
	var members: Array[RTSBuilding] = []
	for entry in _buildings.values():
		var building := (entry as WeakRef).get_ref() as RTSBuilding
		if is_instance_valid(building) and contains_building(building):
			members.append(building)
	return members


func _building_exiting(id: int) -> void:
	# tree_exiting also occurs during reparent. Decide after that operation finishes;
	# the field retains only weak node refs and the small refund-capable queue.
	_reconcile_departure.call_deferred(id)
	if power_enabled and power_grid != null:
		power_grid.refresh.call_deferred()


func _reconcile_departure(id: int) -> void:
	if _closing or not _buildings.has(id):
		return
	var building := _buildings[id].get_ref() as RTSBuilding
	if is_instance_valid(building) and contains_building(building):
		return
	_buildings.erase(id)
	var producer := _producers.get(id) as UnitProduction
	_producers.erase(id)
	if power_enabled and power_grid != null:
		power_grid.refresh.call_deferred()
	if producer != null:
		producer.close(true)
	if is_instance_valid(self) and is_instance_valid(selection):
		selection.prune_building()


func _retire_building(identity: int) -> UnitProduction:
	# Silent membership commit, shared by destruction and normal departure.
	_buildings.erase(identity)
	var producer := _producers.get(identity) as UnitProduction
	_producers.erase(identity)
	if power_enabled and power_grid != null:
		power_grid.refresh.call_deferred()
	return producer


func destroy_building(building: RTSBuilding) -> void:
	if not is_instance_valid(building) or not building.destroyed or not _buildings.has(building.get_instance_id()):
		return
	var producer := _retire_building(building.get_instance_id())
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


func valid_producer_rally(building: RTSBuilding, point: Vector3) -> bool:
	if not is_instance_valid(building) or not contains_building(building):
		return false
	if building.kind == RTSBuilding.Kind.AIRFIELD:
		return valid_air_point(point)
	return valid_rally(building.exit_position(), point)


func valid_air_point(point: Vector3, radius: float = 0.5) -> bool:
	return point.is_finite() and field_bounds.grow(-radius - 0.002).has_point(Vector2(point.x, point.z))


func _prune_air_launch_claims() -> void:
	for identity in _air_launch_claims.keys():
		var claim: Dictionary = _air_launch_claims[identity]
		var reference: WeakRef = claim.get("unit")
		if reference == null:
			if claim.frame != Engine.get_physics_frames():
				_air_launch_claims.erase(identity)
			continue
		var unit := reference.get_ref() as RTSUnit
		if not is_instance_valid(unit) or not contains_unit(unit) or not unit.call("is_taking_off"):
			_air_launch_claims.erase(identity)


func air_launch_claim_count() -> int:
	_prune_air_launch_claims()
	return _air_launch_claims.size()


func _release_air_launch(producer_id: int, aircraft_id: int) -> void:
	var claim: Dictionary = _air_launch_claims.get(producer_id, {})
	if not claim.is_empty() and claim.get("aircraft_id", 0) == aircraft_id:
		_air_launch_claims.erase(producer_id)


func _find_air_spawn(building: RTSBuilding, sphere: SphereShape3D) -> PackedVector3Array:
	if sphere == null or not gameplay_enabled or not building.operational:
		return PackedVector3Array()
	_prune_air_launch_claims()
	var identity := building.get_instance_id()
	if _air_launch_claims.has(identity):
		return PackedVector3Array()
	var point := building.launch_position(sphere.radius)
	var cruise_y: float = sphere.get_meta("flight_plane_y", 8.0)
	if not is_finite(cruise_y) or not valid_air_point(point, sphere.radius) or point.y >= cruise_y:
		return PackedVector3Array()
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = sphere
	query.collision_mask = 1 | 2 | 4 | LineOfFire.BLOCKER_MASK
	query.margin = 0.002
	query.transform = Transform3D(Basis.IDENTITY, point)
	if not get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty():
		return PackedVector3Array()
	# Exact swept sphere volume for the supported straight vertical climb.
	var climb := CapsuleShape3D.new()
	climb.radius = sphere.radius
	climb.height = cruise_y - point.y + sphere.radius * 2.0
	query.shape = climb
	query.transform.origin = Vector3(point.x, (point.y + cruise_y) * 0.5, point.z)
	if not get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty():
		return PackedVector3Array()
	# Explicit registry/claim checks cover bodies registered this physics tick.
	for actor in units:
		if not contains_unit(actor) or not actor.has_method("is_taking_off"):
			continue
		var nearest := Vector3(point.x, clampf(actor.global_position.y, point.y, cruise_y), point.z)
		if actor.global_position.distance_to(nearest) < sphere.radius + float(actor.get("flight_body_radius")) + 0.002:
			return PackedVector3Array()
	for claim in _air_launch_claims.values():
		if Vector2(point.x, point.z).distance_to(Vector2(claim.point.x, claim.point.z)) < sphere.radius + claim.radius + 0.002:
			return PackedVector3Array()
	_air_launch_claims[identity] = {"frame": Engine.get_physics_frames(), "point": point, "radius": sphere.radius, "unit": null, "aircraft_id": 0}
	return PackedVector3Array([point])


func find_spawn(building: RTSBuilding, body: Shape3D = null) -> PackedVector3Array:
	if not Engine.is_in_physics_frame() or not contains_building(building):
		return PackedVector3Array()
	if body == null:
		if building.recipe == null or not building.recipe.is_valid():
			return PackedVector3Array()
		body = building.recipe.deployment_body()
	if building.kind == RTSBuilding.Kind.AIRFIELD:
		return _find_air_spawn(building, body as SphereShape3D)
	var capsule := body as CapsuleShape3D
	if capsule == null:
		return PackedVector3Array()
	var exit_point := building.exit_position()
	if not _nav_point(exit_point):
		return PackedVector3Array()
	_spawn_query.shape = capsule
	if _claims_frame != Engine.get_physics_frames():
		_claims_frame = Engine.get_physics_frames()
		_spawn_claims.clear()
		_spawn_claim_radii.clear()
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
		_spawn_query.transform = Transform3D(Basis.IDENTITY, point + Vector3.UP * capsule.height / 2.0)
		if not get_world_3d().direct_space_state.intersect_shape(_spawn_query, 1).is_empty():
			continue
		var claimed := false
		for index in _spawn_claims.size():
			if _spawn_claims[index].distance_to(point) < _spawn_claim_radii[index] + capsule.radius + 0.002:
				claimed = true
				break
		if claimed:
			continue
		# Covers two producers deploying before newly added collision bodies sync.
		_spawn_claims.append(point)
		_spawn_claim_radii.append(capsule.radius)
		return PackedVector3Array([point])
	return PackedVector3Array()


func prepare_deployment(scene: PackedScene, owner_id: int, point: Vector3, source: RTSBuilding = null) -> RTSUnit:
	if scene == null or not scene.can_instantiate():
		return null
	var instance := scene.instantiate()
	if not instance is RTSUnit:
		instance.free()
		return null
	var unit := instance as RTSUnit
	var air_source := source.get_instance_id() if is_instance_valid(source) and source.kind == RTSBuilding.Kind.AIRFIELD else 0
	_next_unit += 1
	unit.unit_id = _next_unit
	var unit_kind := "Collector" if unit.get_script() == load("res://scripts/collector_truck.gd") else ("RocketVehicle" if unit.combat_weapon == preload("res://weapons/rocket.tres") else "Rifle")
	if unit.get_script() == load("res://scripts/bulldozer.gd"):
		unit_kind = "Bulldozer"
	elif unit.has_method("is_taking_off"):
		unit_kind = "AttackHelicopter"
	unit.name = "Produced%s%03d" % [unit_kind, unit.unit_id]
	unit.owner_id = owner_id
	unit.position = point
	unit.hide()
	add_child(unit)
	if not is_instance_valid(unit):
		return null
	register_unit(unit)
	if is_instance_valid(unit) and contains_unit(unit):
		unit.set_movement_debug(movement_debug)
		if air_source != 0 and _air_launch_claims.has(air_source):
			var aircraft_id := unit.get_instance_id()
			_air_launch_claims[air_source]["unit"] = weakref(unit)
			_air_launch_claims[air_source]["aircraft_id"] = aircraft_id
			var release := _release_air_launch.bind(air_source, aircraft_id)
			unit.connect("takeoff_cleared", release, CONNECT_ONE_SHOT)
			unit.tree_exiting.connect(release, CONNECT_ONE_SHOT)
			unit.call("begin_takeoff")
	return unit


func order_deployed_unit(unit: RTSUnit, destination: Vector3) -> bool:
	if not contains_unit(unit):
		return false
	if unit.has_method("is_taking_off"):
		return valid_air_point(destination) and unit.move_to(destination)
	if not valid_rally(unit.global_position, destination):
		return false
	return unit.move_to(destination)


func follow_deployment_rally(unit: RTSUnit, source: RTSBuilding, expected_order: int, expected_harvest_generation: int = -1, collection_origin: Vector3 = Vector3.INF) -> void:
	if is_instance_valid(unit) and unit is CollectorTruck and contains_unit(unit) and collection_origin.is_finite():
		(unit as CollectorTruck).stage_deployment_collection(collection_origin, expected_order, expected_harvest_generation)
		return
	if not is_instance_valid(source) or source.kind != RTSBuilding.Kind.AIRFIELD or not is_instance_valid(unit) or not contains_unit(unit) or not unit.call("is_taking_off") or unit.order_version != expected_order:
		return
	# Weak references do not keep either source alive. A player order, including
	# X during climb, supersedes this callback. Source loss retains the already
	# staged rally; a surviving source contributes its current rally at clearance.
	unit.connect("takeoff_cleared", _apply_current_air_rally.bind(weakref(unit), weakref(source), expected_order), CONNECT_ONE_SHOT)


func _apply_current_air_rally(unit_ref: WeakRef, source_ref: WeakRef, expected_order: int) -> void:
	var unit := unit_ref.get_ref() as RTSUnit
	var source := source_ref.get_ref() as RTSBuilding
	if not gameplay_enabled or _closing or not is_inside_tree() or is_queued_for_deletion() or not is_instance_valid(unit) or not contains_unit(unit) or unit.order_version != expected_order:
		return
	if not is_instance_valid(source) or not contains_building(source) or source.owner_id != unit.owner_id or source.production == null or not source.production.has_rally:
		return
	var current := source.production.rally_point
	if valid_air_point(current):
		unit.move_to(current)


func _exit_tree() -> void:
	_closing = true
	if power_grid != null:
		power_grid.close()
	if credits != null:
		credits.active = false
	for producer in _producers.values():
		producer.close(false)
	_producers.clear()
	_buildings.clear()
	_spawn_claims.clear()
	_spawn_claim_radii.clear()
	_air_launch_claims.clear()
