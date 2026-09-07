extends TestField
## Test-only factory/delegation seam. The original scene is initialized normally.
const Probe = preload("res://tests/full_sequence_probe.gd")
var recorder: RefCounted


func _create_unit(index: int) -> RTSUnit:
	# Use production's ID/name/position configuration. Install the derived script
	# while the newly constructed node is OUTSIDE the tree, before _ready/signals.
	var unit := super._create_unit(index)
	if recorder != null:
		var identity := unit.unit_id
		var owner := unit.owner_id
		unit.set_script(Probe)
		unit.unit_id = identity
		unit.owner_id = owner
		unit.recorder = recorder
	return unit


func register_unit(unit: RTSUnit) -> void:
	super.register_unit(unit)
	if recorder != null and is_instance_valid(unit):
		recorder.event("membership_registered", unit, {}, {"registered": contains_unit(unit)})


func unregister_unit(unit: RTSUnit) -> void:
	var observation := recorder
	var before: Dictionary = observation.state(unit) if observation != null and is_instance_valid(unit) else {}
	var identity: WeakRef = weakref(unit) if is_instance_valid(unit) else null
	super.unregister_unit(unit)
	if observation != null and identity != null and identity.get_ref() != null:
		observation.event("membership_unregistered", identity.get_ref(), before)


func issue_move(clicked: Vector3) -> CommandBatchResult:
	var observation := recorder
	if observation != null:
		observation.event_group("group_command_requested", {"clicked": [clicked.x, clicked.y, clicked.z],
			"next_generation_before": _next_command_generation})
	var lifetime: WeakRef = weakref(self)
	var result := super.issue_move(clicked)
	if observation != null and lifetime.get_ref() != null:
		var assigned := {}
		for id in result.assignments:
			var point: Vector3 = result.assignments[id]
			assigned[str(id)] = [point.x, point.y, point.z]
		observation.event_group("group_command_result", {"generation": result.generation,
			"intended_ids": Array(result.intended_ids), "accepted_ids": Array(result.accepted_ids),
			"assignments": assigned, "superseded": result.superseded, "complete": result.is_complete()}, true)
	return result
