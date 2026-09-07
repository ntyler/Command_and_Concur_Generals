extends "res://tests/continuous_capture_recorder.gd"
## J adapter only: original stream and gameplay predicates stay inherited.
var gameplay_receipt: Dictionary = {}
var completed_route_result: Dictionary = {}
var actual_calls := 0
var actual_excesses := 0
var incomplete_calls := 0
var maximum_actual_step := 0.0
var calls_by_unit := {}


func _init() -> void:
	# Evidence storage capacity, not a movement/acceptance threshold. No eviction.
	max_bytes = 4294967296
	for id in range(1, 51):
		calls_by_unit[id] = 0


func start_route(label: String) -> void:
	route_label = label
	route_first_frame = Engine.get_physics_frames()
	event_group("continuous_route_start", {"label": label, "before_cluster_commands": true}, true)


func end_route(result: Dictionary) -> void:
	completed_route_result = result.duplicate(true)
	event_group("continuous_route_end", {"result": result}, true)


func _write_line(value: Dictionary, hash_line: bool = true) -> bool:
	if value.get("type") == "frame":
		for row in value.rows:
			for kind in ["callbacks", "direct_movements"]:
				for delegate in row[kind]:
					for movement in delegate.movement_calls:
						actual_calls += 1
						calls_by_unit[int(row.id)] += 1
						var returned := bool(movement.get("delegation_returned", false)) and movement.get("position_after") != null
						if not returned:
							incomplete_calls += 1
							continue
						var start: Array = movement.position_before
						var end: Array = movement.position_after
						var step := Vector3(start[0], start[1], start[2]).distance_to(Vector3(end[0], end[1], end[2]))
						maximum_actual_step = maxf(maximum_actual_step, step)
						if step > float(row.state.movement_speed) * float(movement.delta) + 0.001:
							actual_excesses += 1
	elif value.get("type") == "footer":
		# Attach executed suite totals before the immutable footer is serialized.
		value["gameplay"] = gameplay_receipt.duplicate(true)
		value["actual_call_summary"] = call_summary()
		value["resource_limit_note"] = "J allows4GiB evidence bytes; all movement/gameplay predicates are unchanged"
	return super._write_line(value, hash_line)


func call_summary() -> Dictionary:
	return {"movement_calls": actual_calls, "actual_excesses": actual_excesses,
		"incomplete_calls": incomplete_calls, "maximum_actual_step": maximum_actual_step,
		"calls_by_unit": calls_by_unit.duplicate(), "provenance": "arithmetic on fully returned actual calls at frame serialization; no native diagnostic query"}
