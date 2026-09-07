extends "res://tests/unit13_fixture_field.gd"
## Same frozen creation inputs; install only unit41's narrower observer before tree entry.
const BoundaryProbe = preload("res://tests/unit41_boundary_probe.gd")


func _create_unit(index: int) -> RTSUnit:
	var unit := super._create_unit(index)
	if unit.unit_id == 41:
		var identity := unit.unit_id
		var owner := unit.owner_id
		unit.set_script(BoundaryProbe)
		unit.unit_id = identity
		unit.owner_id = owner
		unit.recorder = recorder
	return unit
