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
	# This milestone supports the existing Rifle body/controller, not vehicles or
	# arbitrary scripted factories with different collision/lifecycle contracts.
	var valid: bool = instance is RTSUnit and instance.get_script() == load("res://scripts/rts_unit.gd") and instance.get_child_count() == 0
	if valid:
		var unit := instance as RTSUnit
		valid = unit.combat_weapon == preload("res://weapons/rifle.tres") and unit.maximum_health == 100.0 and unit.movement_speed == 5.0 and unit.scale == Vector3.ONE
	instance.free()
	return valid
