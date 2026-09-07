extends TestField
const Probe = preload("res://tests/gate_movement_probe.gd")
var recorder: RefCounted
var observed_ids: Array[int] = [20]


func _create_unit(index: int) -> RTSUnit:
	var unit := super._create_unit(index)
	# Observe20 from the retained disabled failure; optional23 observes the later
	# graphical failure. All other participants keep the ordinary production script.
	if unit.unit_id in observed_ids:
		var identity := unit.unit_id
		var owner := unit.owner_id
		unit.set_script(Probe) # Before tree entry; no live placement/state injection.
		unit.unit_id = identity
		unit.owner_id = owner
		unit.recorder = recorder
	return unit
