extends "res://tests/unit41_boundary_probe.gd"
## Aggregate actual inherited movement calls; the existing recorder keeps inputs.
var actual_movement_calls := 0
var maximum_actual_step := 0.0
var excessive_steps := 0


func _plan_parked_escape(neighbors: Array[Dictionary]) -> PackedVector3Array:
	var before := _capture(recorder)
	var result := super._plan_parked_escape(neighbors)
	var points := []
	for point in result:
		points.append(_vector(point))
	_record(recorder, "parked_escape_plan_result", before, {"actual_return": points,
		"provenance": "actual inherited local planner return; no additional diagnostic query"}, true)
	return result


func _move_on_navigation(desired_velocity: Vector3, delta: float) -> void:
	var start := global_position
	super._move_on_navigation(desired_velocity, delta)
	actual_movement_calls += 1
	var distance := start.distance_to(global_position)
	maximum_actual_step = maxf(maximum_actual_step, distance)
	if distance > movement_speed * delta + 0.001:
		excessive_steps += 1
