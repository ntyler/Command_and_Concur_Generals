extends RTSUnit
## Opt-in instrumentation: super calls preserve production decisions and queries.
## Not referenced by gameplay. Event snapshots may perturb execution timing.
const History = preload("res://tests/issue_b_diagnostic_history.gd")
var recorder: Node
var audit_events: Array = []
var recent_motion: Array = []
var audit_truncated := false
var audit_context := "outside_progress"
var callback_context: Dictionary = {}
var audit_sequence := 0


func snapshot() -> Dictionary:
	var result: Dictionary = recorder.record(self)
	result["absolute_frame"] = Engine.get_physics_frames()
	result["progress_elapsed"] = _progress_elapsed
	result["group_generation"] = recorder.field._command_version
	result["map_iteration"] = NavigationServer3D.map_get_iteration_id(agent.get_navigation_map())
	return result


func event(kind: String, before: Dictionary, details: Dictionary = {}, context_window: bool = false) -> void:
	if recorder == null:
		return
	if audit_events.size() >= 512:
		audit_truncated = true
		return
	var item := {"sequence": audit_sequence, "kind": kind, "context": audit_context,
		"before": before, "after": snapshot(), "details": details}
	audit_sequence += 1
	if context_window:
		item["recent_motion"] = recent_motion.duplicate(true)
		item["all_units"] = recorder.records()
		item["contacts"] = recorder._contacts(self)
	audit_events.append(item)


func _remaining_path_length() -> float:
	var result := super._remaining_path_length()
	if recorder != null:
		event("actual_final_path_query", snapshot(), {"remaining": result if is_finite(result) else -1.0,
			"finite": is_finite(result), "signed_progress": _progress_remaining - result if is_finite(_progress_remaining) and is_finite(result) else null})
	return result


func _update_progress(delta: float) -> void:
	var prior_context := audit_context
	audit_context = "update_progress"
	var sampled := _progress_elapsed + delta >= progress_window
	var before := snapshot() if recorder != null and sampled else {}
	super._update_progress(delta)
	if not before.is_empty():
		event("progress_sample_end", before)
	audit_context = prior_context


func _recover() -> void:
	var before := snapshot() if recorder != null else {}
	super._recover()
	if recorder != null:
		event("recovery_admission", before, {"actual_final_fallback": recovery_target == assigned_destination,
			"recomputed_probe": recorder._probe_recovery(self)}, true)


func _clear_recovery() -> void:
	var before := snapshot() if recorder != null else {}
	var reason := "meaningful_progress" if audit_context == "update_progress" else ("duration_expiry" if _recovery_elapsed >= recovery_duration else "waypoint_tolerance")
	super._clear_recovery()
	event("recovery_clear", before, {"source_attributed_reason": reason}, true)


func _finish_move(final_state: MovementState = MovementState.ARRIVED) -> void:
	var before := snapshot() if recorder != null else {}
	super._finish_move(final_state)
	event("terminal", before, {"state": MovementState.keys()[final_state]}, true)


func _physics_process(delta: float) -> void:
	var prior_context := audit_context
	audit_context = "unit_physics"
	var old_target := recovery_target
	super._physics_process(delta)
	if recorder != null and old_target != recovery_target:
		event("target_change_after_physics", {}, {"old_target": History.vector(old_target), "target": History.vector(recovery_target)})
	audit_context = prior_context


func _on_avoidance_velocity(safe_velocity: Vector3) -> void:
	if recorder != null:
		callback_context = {"absolute_frame": Engine.get_physics_frames(), "requested_at_callback": History.vector(agent.velocity),
			"safe": History.vector(safe_velocity), "order": order_version, "submitted": _submitted_order,
			"target_at_callback": History.vector(agent.target_position), "last_movement_frame_before": _last_movement_frame}
	super._on_avoidance_velocity(safe_velocity)


func _move_on_navigation(desired_velocity: Vector3, delta: float) -> void:
	var before := global_position
	var old_frame := _last_movement_frame
	super._move_on_navigation(desired_velocity, delta)
	if recorder != null:
		if recent_motion.size() >= 120:
			recent_motion.pop_front()
		recent_motion.append({"absolute_frame": Engine.get_physics_frames(), "position_before": History.vector(before),
			"position_after": History.vector(global_position), "applied_displacement": History.vector(global_position - before),
			"desired_input": History.vector(desired_velocity), "delta": delta, "old_movement_frame": old_frame,
			"movement_frame": _last_movement_frame, "order": order_version, "callback": callback_context.duplicate(true)})
