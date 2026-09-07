extends "res://tests/full_sequence_field.gd"
## Normal factory usable with original positions or the unchanged captured fixture.
const ContinuousProbe = preload("res://tests/continuous_capture_probe.gd")
var fixture_units: Array = []


func _create_unit(index: int) -> RTSUnit:
	var unit := super._create_unit(index)
	var identity := unit.unit_id
	var owner := unit.owner_id
	unit.set_script(ContinuousProbe)
	unit.unit_id = identity
	unit.owner_id = owner
	unit.recorder = recorder
	if not fixture_units.is_empty():
		var position: Array = fixture_units[index].position
		unit.position = Vector3(position[0], position[1], position[2])
	return unit
