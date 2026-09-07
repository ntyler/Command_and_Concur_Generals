extends "res://tests/full_sequence_probe.gd"
## Observe the actual delegate once. Extra native queries below are diagnostics
## AFTER movement; their results never drive the actor or replace engine returns.
var step_delegate_calls := 0
var step_movement_calls := 0
var step_max_actual_distance := 0.0
var step_actual_excess_count := 0
var step_diagnostic_queries := 0
var step_projected_excess_count := 0


func step_diagnostic(start: Vector3, input: Vector3, delta: float) -> Dictionary:
	var map := agent.get_navigation_map()
	var proposed := start + input * delta
	var projected := NavigationServer3D.map_get_closest_point(map, proposed)
	var budget := input.length() * delta
	var distance := start.distance_to(projected)
	var result := {"proposed": _vector(proposed), "projected": _vector(projected),
		"projected_distance": distance, "projected_excess": distance > budget + 0.001,
		"path": [], "path_length": 0.0, "first_segment_end": null,
		"bounded_first_endpoint": null, "bounded_first_endpoint_on_navigation": null,
		"map_iteration": NavigationServer3D.map_get_iteration_id(map),
		"provenance": "additional native closest-point/path queries after production delegate; not intercepted production returns"}
	if not result.projected_excess:
		return result
	var path := NavigationServer3D.map_get_path(map, start, projected, true)
	for point in path:
		result.path.append(_vector(point))
	for index in range(1, path.size()):
		result.path_length += path[index - 1].distance_to(path[index])
		if result.first_segment_end == null and path[index].distance_to(start) > 0.000001:
			result.first_segment_end = _vector(path[index])
			var bounded := start.move_toward(path[index], budget)
			result.bounded_first_endpoint = _vector(bounded)
			result.bounded_first_endpoint_on_navigation = bounded.distance_to(NavigationServer3D.map_get_closest_point(map, bounded))
	return result


func _move_on_navigation(desired_velocity: Vector3, delta: float) -> void:
	var start := global_position
	var prior_frame := _last_movement_frame
	var before := _capture(recorder)
	step_delegate_calls += 1
	super._move_on_navigation(desired_velocity, delta)
	if _last_movement_frame == prior_frame:
		return
	step_movement_calls += 1
	var actual_distance := start.distance_to(global_position)
	step_max_actual_distance = maxf(step_max_actual_distance, actual_distance)
	var excess := actual_distance > movement_speed * delta + 0.001
	if excess:
		step_actual_excess_count += 1
	var diagnostic := step_diagnostic(start, desired_velocity, delta)
	step_diagnostic_queries += 1
	if diagnostic.projected_excess:
		step_projected_excess_count += 1
	if not excess and not diagnostic.projected_excess:
		return
	var callback := _probe_active_callback
	_record(recorder, "projection_step_observation", before, {
		"start": _vector(start), "input": _vector(desired_velocity), "delta": delta,
		"budget": desired_velocity.length() * delta, "actual_end": _vector(global_position),
		"actual_displacement": _vector(global_position - start), "actual_distance": actual_distance,
		"speed_limit": movement_speed, "frame_before": prior_frame, "frame_after": _last_movement_frame,
		"is_avoidance_callback": not callback.is_empty(),
		"movement_calls_in_callback": callback.get("movement_calls", []).size(),
		"contacts": _contacts_after_move(), "diagnostic": diagnostic,
		"actual_end_on_navigation": global_position.distance_to(NavigationServer3D.map_get_closest_point(agent.get_navigation_map(), global_position)),
		"actual_provenance": "actual returned production movement delegate; containing avoidance callback returns after this observer"}, true)


func step_summary() -> Dictionary:
	return {"id": unit_id, "delegate_calls": step_delegate_calls, "movement_calls": step_movement_calls,
		"max_actual_distance": step_max_actual_distance, "actual_excess_count": step_actual_excess_count,
		"diagnostic_queries": step_diagnostic_queries, "projected_excess_count": step_projected_excess_count}
