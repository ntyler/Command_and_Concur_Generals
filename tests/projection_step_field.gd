extends "res://tests/unit13_fixture_field.gd"
## Identical frozen normal creation, with the movement observer on all 50 units.
const StepProbe = preload("res://tests/projection_step_probe.gd")


func _create_unit(index: int) -> RTSUnit:
	var unit := super._create_unit(index)
	var identity := unit.unit_id
	var owner := unit.owner_id
	unit.set_script(StepProbe)
	unit.unit_id = identity
	unit.owner_id = owner
	unit.recorder = recorder
	return unit
