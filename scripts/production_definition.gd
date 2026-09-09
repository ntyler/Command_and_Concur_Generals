class_name ProductionDefinition
extends Resource
## Shared configuration only. Accepted jobs snapshot price, scene and duration.

@export var identifier: StringName = &"rifle"
@export var display_name: String = "Rifle Unit"
@export var unit_scene: PackedScene
@export var credit_cost: int = 100
@export var training_duration: float = 5.0


func is_valid() -> bool:
	if identifier.is_empty() or display_name.is_empty() or credit_cost < 0 or not is_finite(training_duration) or training_duration <= 0.0:
		return false
	if unit_scene == null or not unit_scene.can_instantiate():
		return false
	var instance := unit_scene.instantiate()
	# Recipes compose existing unit controllers, preserving their normal settings.
	# Arbitrary scripts, added children and scaled collision bodies remain unsupported.
	var valid: bool = instance is RTSUnit and instance.get_child_count() == 0
	if valid:
		var unit := instance as RTSUnit
		var combat_script: bool = unit.get_script() == load("res://scripts/rts_unit.gd")
		var rifle: bool = combat_script and identifier == &"rifle" and unit.combat_weapon == preload("res://weapons/rifle.tres") and unit.maximum_health == 100.0
		var rocket: bool = combat_script and identifier == &"rocket_vehicle" and unit.combat_weapon == preload("res://weapons/rocket.tres") and unit.maximum_health == 150.0
		# Resolve the specific collector script at runtime, avoiding an eager
		# recipe -> collector -> field -> construction-resource preload cycle.
		var collector: Variant = unit if unit.get_script() == load("res://scripts/collector_truck.gd") else null
		var collecting: bool = identifier == &"collector_truck" and collector != null
		if collecting:
			collecting = unit.combat_weapon == null and unit.damageable and unit.maximum_health == 150.0 and unit.movement_speed == 4.0 and not unit.retaliation_enabled and collector.cargo_capacity == 100 and collector.loading_amount == 25 and collector.loading_interval == 1.0 and collector.unloading_duration == 1.0 and collector.interaction_distance == 0.3
		var builder: Variant = unit if unit.get_script() == load("res://scripts/bulldozer.gd") else null
		var building: bool = identifier == &"bulldozer" and builder != null
		if building:
			building = unit.combat_weapon == null and unit.damageable and unit.maximum_health == 200.0 and unit.movement_speed == 3.5 and not unit.retaliation_enabled and builder.work_tolerance == 0.3 and builder.assigned_site_id == 0
		var helicopter: bool = identifier == &"attack_helicopter" and unit.get_script() == load("res://scripts/attack_helicopter.gd") and unit.damageable and unit.combat_weapon != null and unit.combat_weapon.is_valid() and unit.combat_weapon.mode == WeaponDefinition.Mode.GUIDED_PROJECTILE and unit.combat_weapon.target_domain == TeamRules.TargetDomain.GROUND
		if helicopter:
			for property in ["maximum_health", "movement_speed", "flight_body_radius", "cruise_altitude", "takeoff_speed", "horizontal_turn_speed"]:
				var value: float = unit.get(property)
				helicopter = helicopter and is_finite(value) and value > 0.0
			helicopter = helicopter and is_finite(float(unit.get("ground_datum")))
		valid = (((rifle or rocket) and unit.movement_speed == 5.0) or collecting or building or helicopter) and unit.scale == Vector3.ONE
	instance.free()
	return valid


func deployment_body() -> Shape3D:
	# Admission already validated the exact unit script and scale. Read the shape
	# from that scene's unit, using the same factory its _ready uses for collision.
	var unit := unit_scene.instantiate() as RTSUnit
	if identifier == &"attack_helicopter":
		var sphere := SphereShape3D.new()
		sphere.radius = unit.get("flight_body_radius") if unit.get("flight_body_radius") != null else 0.5
		sphere.set_meta("flight_plane_y", float(unit.get("ground_datum")) + float(unit.get("cruise_altitude")))
		unit.free()
		return sphere
	var shape := unit.body_shape()
	unit.free()
	return shape
