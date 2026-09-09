class_name AirAssaultField
extends DefenseAssaultField
## Existing powered ground economy plus one declared starting AA and helicopter.

const ENEMY_AIR_DEFENSE := Rect2(14, -1, 6, 5)
const ENEMY_AIR_START := Vector3(25, 8, 15)
@export var sortie_delay: float = 120.0
var enemy_air_defense: GroundDefenseBattery
var enemy_helicopter: RTSUnit
var sortie_issued: bool = false
var sortie_accepted: bool = false


func _build_field() -> void:
	# Separate from the inherited ground battery, Barracks and generator. The
	# north/east ground approaches to enemy power remain available.
	obstacles.append(ENEMY_AIR_DEFENSE)
	super._build_field()


func _build_obstacle(index: int, rectangle: Rect2) -> void:
	if rectangle != ENEMY_AIR_DEFENSE:
		super._build_obstacle(index, rectangle)
		return
	enemy_air_defense = GroundDefenseBattery.new()
	enemy_air_defense.name = "EnemyAirDefenseBattery"
	enemy_air_defense.owner_id = 2
	enemy_air_defense.kind = RTSBuilding.Kind.AIR_DEFENSE_BATTERY
	enemy_air_defense.definition = air_defense_definition
	enemy_air_defense.recipe = null
	enemy_air_defense.footprint = rectangle.size
	enemy_air_defense.building_height = air_defense_definition.height
	enemy_air_defense.position = Vector3(rectangle.get_center().x, 0, rectangle.get_center().y)
	add_child(enemy_air_defense)
	register_building(enemy_air_defense)


func _ready() -> void:
	super._ready()
	# This is an explicit starting force, never a wallet grant or producer job.
	enemy_helicopter = load("res://scenes/attack_helicopter.tscn").instantiate() as RTSUnit
	_next_unit += 1
	enemy_helicopter.unit_id = _next_unit
	enemy_helicopter.name = "StartingEnemyAttackHelicopter"
	enemy_helicopter.owner_id = 2
	enemy_helicopter.position = ENEMY_AIR_START
	enemy_helicopter.retaliation_enabled = false
	add_child(enemy_helicopter)
	register_unit(enemy_helicopter)
	_update_objective()


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if not is_instance_valid(self) or not gameplay_enabled or is_queued_for_deletion() or sortie_issued or elapsed < sortie_delay:
		return
	sortie_issued = true # One accepted attempt; no replacement aircraft or planner.
	if is_instance_valid(enemy_helicopter) and contains_unit(enemy_helicopter) and is_instance_valid(headquarters) and contains_building(headquarters):
		var accepted := issue_attack_move_for(2, [enemy_helicopter], headquarters.global_position)
		if is_instance_valid(self):
			sortie_accepted = accepted.has_acceptance()


func flight_plane_clearance() -> bool:
	# Physics validation of the full supported plane, including the0.5 body
	# radius. Labels and non-solid decorative meshes do not block gameplay.
	if not Engine.is_in_physics_frame():
		return false
	var shape := BoxShape3D.new()
	shape.size = Vector3(field_bounds.size.x, 1.004, field_bounds.size.y)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.collision_mask = 1 | 4 | LineOfFire.BLOCKER_MASK
	query.transform = Transform3D(Basis.IDENTITY, Vector3(field_bounds.get_center().x, 8, field_bounds.get_center().y))
	return get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


func _update_objective() -> void:
	super._update_objective()
	if is_instance_valid(objective_label) and gameplay_enabled:
		objective_label.text += " · Air sortie active" if sortie_issued else " · Air threat in %ds" % ceili(maxf(0.0, sortie_delay - elapsed))


func _exit_tree() -> void:
	sortie_issued = false
	sortie_accepted = false
	enemy_helicopter = null
	enemy_air_defense = null
	super._exit_tree()
