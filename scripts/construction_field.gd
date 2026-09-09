class_name ConstructionField
extends HarvestField
## Small flat-field construction. Geometry comes only from committed rectangles.

const BUILD_AREA := Rect2(-27, -21, 54, 43)
const ACCESS_CORRIDORS: Array[Rect2] = [Rect2(-16.7, -13.3, 28, 2), Rect2(-17, -13.3, 3, 9), Rect2(-27, 10, 25, 2)]
@export var construction_definition: ConstructionDefinition = load("res://construction/barracks.tres")
@export var vehicle_factory_definition: ConstructionDefinition
@export var supply_depot_definition: ConstructionDefinition
@export var power_plant_definition: ConstructionDefinition
@export var defense_definition: ConstructionDefinition
@export var airfield_definition: ConstructionDefinition
@export var air_defense_definition: ConstructionDefinition
@export var navigation_timeout: float = 5.0
@export var builder_construction_enabled: bool = false
@export_range(0.85, 2.0, 0.05) var builder_work_distance: float = 1.3
var construction: BuildingConstruction
var placement: BuildingPlacement
var static_footprints: Array[Rect2] = []
var _placement_shape := BoxShape3D.new()
var _placement_query := PhysicsShapeQueryParameters3D.new()
var _ground_query := PhysicsRayQueryParameters3D.new()
var placement_guides: MeshInstance3D


func _ready() -> void:
	construction = BuildingConstruction.new(self)
	process_physics_priority = -100
	_placement_query.shape = _placement_shape
	_placement_query.collision_mask = 2 | 4 | LineOfFire.BLOCKER_MASK
	_placement_query.margin = 0.001
	_ground_query.collision_mask = 1
	super._ready()
	static_footprints = obstacles.duplicate()
	placement = BuildingPlacement.new()
	placement.field = self
	placement.name = "BarracksPlacement"
	add_child(placement)
	(info_panel.get_child(0).get_child(0) as Label).text = "FIELDWORK  /  CONSTRUCTION"
	placement_guides = MeshInstance3D.new()
	placement_guides.name = "PlacementAccessGuides"
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	placement_guides.material_override = material
	add_child(placement_guides)
	construction.changed.connect(_refresh_placement_guides)
	construction.navigation.ready.connect(_refresh_placement_guides)
	_refresh_placement_guides()
	(production_panel as ConstructionPanel).refresh_construction()


func _build_field() -> void:
	obstacles.erase(BASE_OBSTACLES[1])
	super._build_field()


func _build_obstacle(_index: int, rectangle: Rect2) -> void:
	var original := BASE_OBSTACLES.find(rectangle)
	if original >= 0:
		super._build_obstacle(original, rectangle)
	else:
		super._build_obstacle(BASE_OBSTACLES.size() + CACHE_FOOTPRINTS.find(rectangle), rectangle)


func create_production_panel() -> ProductionPanel:
	return ConstructionPanel.new()


func dropoff_command_hint() -> String:
	return "HQ / depot" if supply_depot_definition != null else "HQ"


func _physics_process(delta: float) -> void:
	construction.advance(delta)


func prepare_construction_mesh(rectangles: Array[Rect2]) -> NavigationMesh:
	# Narrow override point for deterministic preparation-failure fixtures.
	return create_navigation_mesh(rectangles)


func register_unit(unit: RTSUnit) -> void:
	super.register_unit(unit)
	if construction != null and construction.navigation.blocked and is_instance_valid(unit) and contains_unit(unit):
		unit.suspend_navigation()


func unregister_unit(unit: RTSUnit) -> void:
	# Suspension belongs to this field generation, never to a detached unit or
	# a unit subsequently registered in another scene. No queries during exit.
	if is_instance_valid(unit):
		unit.navigation_suspended = false
	super.unregister_unit(unit)


func valid_rally(origin: Vector3, point: Vector3) -> bool:
	return (construction == null or not construction.navigation.blocked) and super.valid_rally(origin, point)


func find_spawn(building: RTSBuilding, body: Shape3D = null) -> PackedVector3Array:
	if construction.navigation.blocked and building.kind != RTSBuilding.Kind.AIRFIELD:
		return PackedVector3Array()
	return super.find_spawn(building, body)


func supports_construction(definition: ConstructionDefinition) -> bool:
	return definition != null and (definition == construction_definition or definition == vehicle_factory_definition or definition == supply_depot_definition or definition == power_plant_definition or (builder_construction_enabled and power_enabled and definition in [defense_definition, airfield_definition, air_defense_definition]))


func builder_work_positions(rectangle: Rect2) -> Array[Dictionary]:
	var positions: Array[Dictionary] = []
	var center := Vector3(rectangle.get_center().x, 0, rectangle.get_center().y)
	for axis in [Vector3.RIGHT, Vector3.LEFT, Vector3.BACK, Vector3.FORWARD]:
		var side := Vector3(-axis.z, 0, axis.x)
		var extent := rectangle.size.x / 2.0 if axis.x != 0 else rectangle.size.y / 2.0
		for offset in [-1.0, 1.0]:
			var dock: Vector3 = center + axis * (extent + 0.1) + side * offset
			positions.append({"point": dock + axis * (builder_work_distance - 0.1), "dock": dock, "slot": positions.size()})
	return positions


func plan_builder_access(builder: Bulldozer, rectangle: Rect2) -> Dictionary:
	if not Engine.is_in_physics_frame() or not construction.eligible_builder(builder, builder.owner_id) or construction.navigation.blocked:
		return {}
	var best: Dictionary = {}
	var shortest := INF
	# The same eight bounded access/physics checks used by harvesting; commands
	# and synchronized site preparation are the only path-search boundaries.
	for candidate in builder_work_positions(rectangle):
		var point: Vector3 = candidate["point"]
		if not valid_rally(builder.global_position, point) or not _clear_access(builder, candidate):
			continue
		var path := NavigationServer3D.map_get_path(get_world_3d().get_navigation_map(), builder.global_position, point, true)
		var length := builder.global_position.distance_to(path[0])
		for index in range(1, path.size()):
			length += path[index - 1].distance_to(path[index])
		if length < shortest - 0.001:
			best = candidate
			shortest = length
	return best


func builder_can_work(builder: Bulldozer, site: ConstructionSite) -> bool:
	if not Engine.is_in_physics_frame() or construction.navigation.blocked or not construction.eligible_builder(builder, site.owner_id) or site.builder() != builder or builder.assigned_site_id != site.site_id or site.work_access.is_empty():
		return false
	var body := site.building()
	if not is_instance_valid(body) or not contains_building(body) or body.owner_id != site.owner_id or body.operational:
		return false
	var center := Vector3(site.rectangle.get_center().x, 0, site.rectangle.get_center().y)
	if body.global_position.distance_to(center) > 0.02:
		return false
	var access := site.work_access
	var point: Vector3 = access["point"]
	var slot := int(access["slot"])
	var positions := builder_work_positions(site.rectangle)
	if slot < 0 or slot >= positions.size() or (positions[slot]["point"] as Vector3).distance_to(point) > 0.02 or (positions[slot]["dock"] as Vector3).distance_to(access["dock"]) > 0.02:
		return false
	if builder.navigation_suspended or builder.moving or builder.movement_state != RTSUnit.MovementState.ARRIVED or builder.order_version != site.work_order_version or builder.global_position.distance_to(point) > builder.work_tolerance or not _nav_point(builder.global_position) or not _nav_point(point):
		return false
	if not _clear_access(builder, access):
		return false
	# Arrival must also clear the capsule at its actual position, including any
	# standing offset, and the final interaction segment to the outside face.
	return _clear_access(builder, {"point": builder.global_position, "dock": access["dock"]})


func protected_areas() -> Array[Rect2]:
	var rectangles: Array[Rect2] = ACCESS_CORRIDORS.duplicate()
	var targets: Array[Node3D] = []
	if is_instance_valid(headquarters) and contains_building(headquarters):
		targets.append(headquarters)
	# Sites reserve their delivery bays immediately, before becoming operational.
	for building in registered_buildings():
		if building.kind == RTSBuilding.Kind.SUPPLY_DEPOT:
			targets.append(building)
	for cache in caches:
		if is_instance_valid(cache) and contains_cache(cache):
			targets.append(cache)
	for target in targets:
		for access in access_positions(target):
			var point: Vector3 = access["point"]
			var dock: Vector3 = access["dock"]
			rectangles.append(Rect2(Vector2(point.x, point.z), Vector2(dock.x - point.x, dock.z - point.z)).abs().grow(0.7))
	for site in construction.sites.values():
		if site.state in [ConstructionSite.State.CANCELLING, ConstructionSite.State.CANCELLED]:
			continue
		var body: RTSBuilding = site.building()
		if is_instance_valid(body) and body.kind in [RTSBuilding.Kind.POWER_PLANT, RTSBuilding.Kind.GROUND_DEFENSE_BATTERY, RTSBuilding.Kind.AIRFIELD, RTSBuilding.Kind.AIR_DEFENSE_BATTERY]:
			continue # Generators and defenses need builder access, but no deployment exit.
		# Protect the entire fixed six-sample exit neighborhood, plus the link from
		# the door. This is geometry protection, not a center-point test.
		rectangles.append(exit_area(site.rectangle))
	return rectangles


func exit_area(rectangle: Rect2) -> Rect2:
	return Rect2(rectangle.end.x, rectangle.get_center().y - 1.8, 3.1, 3.6)


func depot_access_areas(rectangle: Rect2) -> Array[Rect2]:
	var areas: Array[Rect2] = []
	var center := rectangle.get_center()
	for access in RTSBuilding.depot_access_layout(Vector3(center.x, 0, center.y), rectangle.size):
		var point: Vector3 = access["point"]
		var dock: Vector3 = access["dock"]
		areas.append(Rect2(Vector2(point.x, point.z), Vector2(dock.x - point.x, dock.z - point.z)).abs().grow(0.7))
	return areas


func placement_geometry(point: Vector3, definition: ConstructionDefinition) -> String:
	if not point.is_finite() or absf(point.y) > 0.05:
		return "Requires flat ground"
	var rectangle := Rect2(Vector2(point.x, point.z) - definition.footprint / 2.0, definition.footprint)
	var clear := rectangle.grow(CLEARANCE)
	if not BUILD_AREA.encloses(clear) or not field_bounds.grow(-CLEARANCE).encloses(clear):
		return "Full footprint and clearance must fit inside the green boundary"
	for occupied in obstacles:
		if clear.intersects(occupied.grow(CLEARANCE), true):
			return "Too close to a building, obstacle or supply cache"
	for protected in protected_areas():
		if clear.intersects(protected, true):
			return "Protected deposit, supply, exit or access corridor"
	# Fixed generators and defenses have no production exit.
	if definition.kind not in [RTSBuilding.Kind.POWER_PLANT, RTSBuilding.Kind.GROUND_DEFENSE_BATTERY, RTSBuilding.Kind.AIRFIELD, RTSBuilding.Kind.AIR_DEFENSE_BATTERY]:
		var exit_rectangle := exit_area(rectangle)
		if not BUILD_AREA.encloses(exit_rectangle):
			return "%s exit must fit inside the construction area" % definition.display_name()
		for occupied in obstacles:
			if exit_rectangle.intersects(occupied.grow(CLEARANCE), true):
				return "%s exit would be obstructed" % definition.display_name()
	if definition.kind == RTSBuilding.Kind.SUPPLY_DEPOT:
		# The same layout drives delivery, placement and future protected access.
		# Existing units can leave a bay normally; fixed geometry cannot cover it.
		for access in depot_access_areas(rectangle):
			if not BUILD_AREA.encloses(access):
				return "Supply Depot delivery access must fit inside the construction area"
			for occupied in obstacles:
				if access.intersects(occupied.grow(CLEARANCE), true):
					return "Supply Depot delivery access would be obstructed"
	for sample: Vector2 in [clear.position, Vector2(clear.end.x, clear.position.y), clear.end, Vector2(clear.position.x, clear.end.y), clear.get_center()]:
		_ground_query.from = Vector3(sample.x, 4, sample.y)
		_ground_query.to = Vector3(sample.x, -1, sample.y)
		var hit := get_world_3d().direct_space_state.intersect_ray(_ground_query)
		if hit.is_empty() or absf((hit["position"] as Vector3).y) > 0.05 or (hit["normal"] as Vector3).dot(Vector3.UP) < 0.999:
			return "Complete footprint requires flat terrain"
	_placement_shape.size = Vector3(clear.size.x, definition.height + 0.1, clear.size.y)
	_placement_query.transform = Transform3D(Basis.IDENTITY, point + Vector3.UP * (definition.height / 2.0 + 0.02))
	if not get_world_3d().direct_space_state.intersect_shape(_placement_query, 1).is_empty():
		return "Footprint clearance is occupied"
	# Explicit live-unit bounds also cover a unit registered earlier in this tick,
	# before its new physics body has reached the broad phase.
	for unit in units:
		if contains_unit(unit) and unit.global_position.y < definition.height + 0.6 and clear.grow(RTSUnit.BODY_RADIUS).has_point(Vector2(unit.global_position.x, unit.global_position.z)):
			return "A unit occupies the footprint clearance"
	return ""


func set_movement_debug(enabled: bool) -> void:
	super.set_movement_debug(enabled)
	update_placement_guides_visibility()


func update_placement_guides_visibility() -> void:
	if is_instance_valid(placement_guides):
		var relevant := movement_debug or (is_instance_valid(placement) and placement.active)
		if relevant and not placement_guides.visible:
			_refresh_placement_guides()
		placement_guides.visible = relevant


func _refresh_placement_guides(_site_id: int = 0) -> void:
	if not is_inside_tree() or is_queued_for_deletion() or not is_instance_valid(placement_guides):
		return
	# Presentation of the same validation rectangles, rebuilt only on lifecycle
	# changes. A single persistent node makes repeated F3 toggles allocation-free.
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	_outline(mesh, BUILD_AREA, Color("7eb9a0"))
	for rectangle in protected_areas():
		_outline(mesh, rectangle, Color("b6a677"))
	mesh.surface_end()
	placement_guides.mesh = mesh
	placement_guides.visible = movement_debug or (is_instance_valid(placement) and placement.active)


func _outline(mesh: ImmediateMesh, rectangle: Rect2, color: Color) -> void:
	mesh.surface_set_color(color)
	var corners := [rectangle.position, Vector2(rectangle.end.x, rectangle.position.y), rectangle.end, Vector2(rectangle.position.x, rectangle.end.y)]
	for i in 4:
		for point: Vector2 in [corners[i], corners[(i + 1) % 4]]:
			mesh.surface_add_vertex(Vector3(point.x, 0.025, point.y))


func destroy_building(building: RTSBuilding) -> void:
	if not is_instance_valid(building) or not building.destroyed or not _buildings.has(building.get_instance_id()):
		return
	var producer := _retire_building(building.get_instance_id())
	# Erase the authoritative footprint before navigation suspension can notify anyone.
	if building is ConstructionBuilding and building.site != null:
		construction.sites.erase(building.site.site_id)
	else:
		var rectangle := Rect2(Vector2(building.global_position.x, building.global_position.z) - building.footprint / 2.0, building.footprint)
		static_footprints.erase(rectangle)
	construction._request_navigation()
	if producer != null:
		producer.close(true)
	if is_instance_valid(self) and is_instance_valid(selection):
		selection.prune_building()


func _exit_tree() -> void:
	if construction != null:
		construction.close()
	super._exit_tree()
