extends "res://tests/full_sequence_probe.gd"
## Existing actual-call recorder plus bounded, explicitly additional diagnostics.
var movement_calls := 0
var excessive_steps := 0
var maximum_step := 0.0
var blocked_calls := 0
var diagnostic_count := 0
var last_diagnostic_frame := -1000
var cell_checks := 0
var cell_acceptances := 0
var cell_records := 0
var pending_cell := {}


func _move_on_navigation(desired_velocity: Vector3, delta: float) -> void:
	pending_cell = {}
	var before := _capture(recorder)
	var start := global_position
	var stamp := _last_movement_frame
	var cached_before := agent.get_current_navigation_path()
	var index_before := agent.get_current_navigation_path_index()
	super._move_on_navigation(desired_velocity, delta)
	if stamp == _last_movement_frame:
		return
	movement_calls += 1
	var distance := start.distance_to(global_position)
	maximum_step = maxf(maximum_step, distance)
	excessive_steps += int(distance > movement_speed * delta + 0.001)
	if not pending_cell.is_empty() and cell_records < 8:
		cell_records += 1
		_record(recorder, "actual_cell_fallback", before, {"cell": pending_cell, "actual_start": _vector(start),
			"actual_end": _vector(global_position), "actual_input": _vector(desired_velocity), "actual_delta": delta,
			"actual_displacement": distance, "actual_stamp_before": stamp, "actual_stamp_after": _last_movement_frame,
			"actual_contacts": _contacts_after_move()}, true)
	var at_gate := absf(start.x + 2.85) < 0.3 and absf(start.z) < 5.0
	if not at_gate or desired_velocity.length() < 0.1 or distance > 0.00001:
		return
	blocked_calls += 1
	if diagnostic_count >= 8 or Engine.get_physics_frames() - last_diagnostic_frame < 60:
		return
	diagnostic_count += 1
	last_diagnostic_frame = Engine.get_physics_frames()
	var map := agent.get_navigation_map()
	var proposed := start + desired_velocity * delta
	var projected := NavigationServer3D.map_get_closest_point(map, proposed)
	var projection_path := NavigationServer3D.map_get_path(map, start, projected, true)
	var waypoint_path := NavigationServer3D.map_get_path(map, start, next_waypoint, true)
	_record(recorder, "gate_blocked_call", before, {"actual_start": _vector(start), "actual_end": _vector(global_position),
		"actual_input": _vector(desired_velocity), "actual_delta": delta, "actual_displacement": distance,
		"actual_stamp_before": stamp, "actual_stamp_after": _last_movement_frame, "actual_contacts": _contacts_after_move(),
		"actual_cached_path_before_move": _points(cached_before), "actual_cached_index_before_move": index_before,
		"actual_next_waypoint": _vector(next_waypoint), "actual_body_velocity_after": _vector(velocity),
		"diagnostics": {"provenance": "additional native queries AFTER returned movement; not intercepted production query returns",
			"proposed_from_actual_input": _vector(proposed), "closest_proposed": _vector(projected),
			"closest_start": _vector(NavigationServer3D.map_get_closest_point(map, start)),
			"projection_path": _points(projection_path), "waypoint_path": _points(waypoint_path),
			"map_iteration": NavigationServer3D.map_get_iteration_id(map)}}, true)


func _navigation_cell_contains_segment(start: Vector3, end: Vector3) -> bool:
	var accepted := super._navigation_cell_contains_segment(start, end)
	cell_checks += 1
	cell_acceptances += int(accepted)
	pending_cell = {"provenance": "actual production helper arguments and return during movement; no additional query",
		"start": _vector(start), "candidate": _vector(end), "accepted": accepted}
	return accepted


func _points(path: PackedVector3Array) -> Array:
	var result := []
	for point in path:
		result.append(_vector(point))
	return result
