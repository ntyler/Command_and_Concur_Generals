extends "res://tests/full_sequence_field.gd"
## Derived captured layout: positions are set only during normal factory creation.
var fixture_units: Array = []


func _create_unit(index: int) -> RTSUnit:
	var unit := super._create_unit(index)
	var entry: Dictionary = fixture_units[index]
	unit.position = Vector3(entry.position[0], entry.position[1], entry.position[2])
	return unit
