class_name ConstructionField
extends HarvestField
## Small flat-field construction. Geometry comes only from committed rectangles.

const BUILD_AREA := Rect2(-27, -21, 54, 43)
const ACCESS_CORRIDORS: Array[Rect2] = [Rect2(-16.7, -13.3, 28, 2), Rect2(-17, -13.3, 3, 9), Rect2(-27, 10, 25, 2)]
@export var construction_definition: ConstructionDefinition = preload("res://construction/barracks.tres")
@export var navigation_timeout: float = 5.0
var construction: BuildingConstruction
var placement: BuildingPlacement
var static_footprints: Array[Rect2] = []
var _placement_shape := BoxShape3D.new()
var _placement_query := PhysicsShapeQueryParameters3D.new()
var _ground_query := PhysicsRayQueryParameters3D.new()


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
	_outline(BUILD_AREA, Color("7eb9a0"))
	for rectangle in protected_areas():
		_outline(rectangle, Color("b6a677"))
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


func find_spawn(building: RTSBuilding) -> PackedVector3Array:
	if construction.navigation.blocked:
		return PackedVector3Array()
	return super.find_spawn(building)


func protected_areas() -> Array[Rect2]:
	var rectangles: Array[Rect2] = ACCESS_CORRIDORS.duplicate()
	var targets: Array[Node3D] = []
	if is_instance_valid(headquarters) and contains_building(headquarters):
		targets.append(headquarters)
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
		# Protect the entire fixed six-sample exit neighborhood, plus the link from
		# the door. This is geometry protection, not a center-point test.
		rectangles.append(exit_area(site.rectangle))
	return rectangles


func exit_area(rectangle: Rect2) -> Rect2:
	return Rect2(rectangle.end.x, rectangle.get_center().y - 1.8, 3.1, 3.6)


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
	# A new barracks must itself have a clear usable exit; later sites protect it.
	var exit_rectangle := exit_area(rectangle)
	if not BUILD_AREA.encloses(exit_rectangle):
		return "Barracks exit must fit inside the construction area"
	for occupied in obstacles:
		if exit_rectangle.intersects(occupied.grow(CLEARANCE), true):
			return "Barracks exit would be obstructed"
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
		if contains_unit(unit) and clear.grow(RTSUnit.BODY_RADIUS).has_point(Vector2(unit.global_position.x, unit.global_position.z)):
			return "A unit occupies the footprint clearance"
	return ""


func _outline(rectangle: Rect2, color: Color) -> void:
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	var corners := [rectangle.position, Vector2(rectangle.end.x, rectangle.position.y), rectangle.end, Vector2(rectangle.position.x, rectangle.end.y)]
	for i in 4:
		for point: Vector2 in [corners[i], corners[(i + 1) % 4]]:
			mesh.surface_add_vertex(Vector3(point.x, 0.025, point.y))
	mesh.surface_end()
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	visual.material_override = material
	add_child(visual)


func _exit_tree() -> void:
	if construction != null:
		construction.close()
	super._exit_tree()
