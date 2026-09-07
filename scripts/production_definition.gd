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
	# Both recipes compose the existing RTSUnit controller/body, with its normal
	# weapon and health configuration. Arbitrary scripts/children remain unsupported.
	var valid: bool = instance is RTSUnit and instance.get_script() == load("res://scripts/rts_unit.gd") and instance.get_child_count() == 0
	if valid:
		var unit := instance as RTSUnit
		var rifle := identifier == &"rifle" and unit.combat_weapon == preload("res://weapons/rifle.tres") and unit.maximum_health == 100.0
		var rocket := identifier == &"rocket_vehicle" and unit.combat_weapon == preload("res://weapons/rocket.tres") and unit.maximum_health == 150.0
		valid = (rifle or rocket) and unit.movement_speed == 5.0 and unit.scale == Vector3.ONE
	instance.free()
	return valid


func deployment_body() -> CapsuleShape3D:
	# Admission already validated the exact unit script and scale. Read the shape
	# from that scene's unit, using the same factory its _ready uses for collision.
	var unit := unit_scene.instantiate() as RTSUnit
	var shape := unit.body_shape()
	unit.free()
	return shape
