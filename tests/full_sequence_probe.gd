extends RTSUnit
## Test-only wrappers around actual inherited operations. No navigation/physics
## queries or copied movement decisions. The field recorder owns capture limits.

var recorder: RefCounted
var probe_has_waypoint_counter := false
var _probe_context := "outside_delegate"
var _probe_query_count := 0
var _probe_callback_sequence := 0
var _probe_active_callback: Dictionary = {}


static func _vector(value: Vector3) -> Array:
	return [value.x, value.y, value.z]


static func _number(value: float) -> Dictionary:
	var classification := "finite"
	if is_nan(value):
		classification = "nan"
	elif not is_finite(value):
		classification = "positive_infinity" if value > 0.0 else "negative_infinity"
	return {"value": value if is_finite(value) else null, "classification": classification}


func _capture(source: RefCounted) -> Dictionary:
	return source.state(self) if is_instance_valid(source) and source.live else {}


func _record(source: RefCounted, kind: String, before: Dictionary, details: Dictionary = {}, important: bool = false) -> void:
	if is_instance_valid(source) and source.live:
		details["delegate_context"] = _probe_context
		source.event(kind, self, before, details, important)


func _ready() -> void:
	var lifetime: WeakRef = weakref(self)
	var source := recorder
	super._ready()
	if lifetime.get_ref() == null:
		return
	for property in get_property_list():
		probe_has_waypoint_counter = probe_has_waypoint_counter or property.name == "_recovery_waypoints"
	if is_instance_valid(source) and source.live:
		source.watch(self)


func _exit_tree() -> void:
	var source := recorder
	if is_instance_valid(source):
		source.unwatch(self)


func move_to(destination: Vector3, combat_pursuit: bool = false, preserve_attack_move: bool = false) -> bool:
	var lifetime: WeakRef = weakref(self)
	var source := recorder
	var before := _capture(source)
	var prior_context := _probe_context
	_probe_context = "move_to"
	_record(source, "move_command_requested", before, {"destination": _vector(destination), "combat_pursuit": combat_pursuit})
	var accepted := super.move_to(destination, combat_pursuit, preserve_attack_move)
	if lifetime.get_ref() == null:
		return accepted
	_record(source, "move_command_result", before, {"accepted": accepted, "requested_destination": _vector(destination)})
	_probe_context = prior_context
	return accepted


func retarget_pursuit(destination: Vector3) -> bool:
	var lifetime: WeakRef = weakref(self)
	var source := recorder
	var before := _capture(source)
	var prior_context := _probe_context
	_probe_context = "retarget_pursuit"
	var accepted := super.retarget_pursuit(destination)
	if lifetime.get_ref() == null:
		return accepted
	_record(source, "pursuit_retarget_result", before, {"accepted": accepted, "requested_destination": _vector(destination)})
	_probe_context = prior_context
	return accepted


func halt_motion() -> void:
	var lifetime: WeakRef = weakref(self)
	var source := recorder
	var before := _capture(source)
	var prior_context := _probe_context
	_probe_context = "halt_motion"
	_record(source, "halt_requested", before, {}, true)
	super.halt_motion()
	if lifetime.get_ref() == null:
		return
	_record(source, "halt_result", before)
	_probe_context = prior_context


func suspend_navigation() -> void:
	var lifetime: WeakRef = weakref(self)
	var source := recorder
	var before := _capture(source)
	var prior_context := _probe_context
	_probe_context = "suspend_navigation"
	super.suspend_navigation()
	if lifetime.get_ref() == null:
		return
	_record(source, "navigation_suspend_result", before)
	_probe_context = prior_context


func resume_navigation() -> void:
	var lifetime: WeakRef = weakref(self)
	var source := recorder
	var before := _capture(source)
	var prior_context := _probe_context
	_probe_context = "resume_navigation"
	super.resume_navigation()
	if lifetime.get_ref() == null:
		return
	_record(source, "navigation_resume_result", before)
	_probe_context = prior_context


func _physics_process(delta: float) -> void:
	var lifetime: WeakRef = weakref(self)
	var source := recorder
	var before := _capture(source)
	var prior_context := _probe_context
	_probe_context = "unit_physics"
	super._physics_process(delta)
	if lifetime.get_ref() == null:
		return
	if is_instance_valid(source) and source.live:
		source.physics(self, before)
	_probe_context = prior_context


func _remaining_path_length() -> float:
	var lifetime: WeakRef = weakref(self)
	var source := recorder
	var before := _capture(source)
	var baseline_before := _progress_remaining
	var result := super._remaining_path_length()
	if lifetime.get_ref() == null:
		return result
	_probe_query_count += 1
	_record(source, "actual_final_path_query", before, {
		"actual_return": _number(result), "baseline_before_query": _number(baseline_before),
		"derived_signed_difference": _number(baseline_before - result),
		"difference_provenance": "observer arithmetic from observed inputs; not a production branch label",
		"observer_local_query_sequence": _probe_query_count})
	return result


func _update_progress(delta: float) -> void:
	var lifetime: WeakRef = weakref(self)
	var source := recorder
	var before := _capture(source)
	var queries_before := _probe_query_count
	var prior_context := _probe_context
	_probe_context = "update_progress"
	super._update_progress(delta)
	if lifetime.get_ref() == null:
		return
	# Observing the actual delegated query distinguishes a completed sample from
	# the routine accumulator-only call without reproducing its threshold guard.
	if _probe_query_count != queries_before:
		_record(source, "progress_sample_result", before, {"delta": delta,
			"actual_queries_during_delegate": _probe_query_count - queries_before,
			"executed_branch": null})
	_probe_context = prior_context


func _recover() -> void:
	var lifetime: WeakRef = weakref(self)
	var source := recorder
	var before := _capture(source)
	var prior_order := order_version
	var prior_attempts := recovery_attempts
	var prior_context := _probe_context
	_probe_context = "recover"
	super._recover()
	if lifetime.get_ref() == null:
		return
	_record(source, "recovery_admission_result", before, {
		"attempts_before_delegate": prior_attempts, "attempts_after_delegate": recovery_attempts,
		"same_order_after_delegate": order_version == prior_order,
		"target_after_delegate": _vector(recovery_target),
		"active_target_is_final_destination_after_delegate": recovery_active and recovery_target == assigned_destination,
		"fallback_branch_provenance": "target equality observed; internal fallback versus equal-valued candidate branch unavailable",
		"selection_at_transition": "see RECOVERING state event; a synchronous listener may replace it before this result",
		"candidate_rejection_reasons": null}, true)
	_probe_context = prior_context


func _clear_recovery() -> void:
	var lifetime: WeakRef = weakref(self)
	var source := recorder
	var before := _capture(source)
	var context_before := _probe_context
	var elapsed_before := _recovery_elapsed
	var distance_before := global_position.distance_to(recovery_target)
	_probe_context = "clear_recovery"
	super._clear_recovery()
	if lifetime.get_ref() == null:
		return
	_record(source, "recovery_clear_result", before, {"caller_context": context_before,
		"recovery_elapsed_before_delegate": elapsed_before,
		"distance_to_recovery_target_before_delegate": distance_before,
		"executed_internal_branch": null,
		"reason_provenance": "caller context and numeric observations only; internal branch not instrumented"}, true)
	_probe_context = context_before


func _finish_move(final_state: MovementState = MovementState.ARRIVED) -> void:
	var lifetime: WeakRef = weakref(self)
	var source := recorder
	var before := _capture(source)
	var prior_context := _probe_context
	_probe_context = "finish_move"
	# This event is admitted before cleanup zeroes the waypoint/timers and before
	# terminal listeners can remove this unit or alter neighboring state.
	_record(source, "terminal_requested", before, {"requested_terminal_state": MovementState.keys()[final_state],
		"caller_context": prior_context, "phase": "before_production_cleanup"}, true)
	super._finish_move(final_state)
	if lifetime.get_ref() == null:
		return
	_record(source, "terminal_result", before, {"requested_terminal_state": MovementState.keys()[final_state],
		"phase": "after_production_cleanup_and_listeners"})
	_probe_context = prior_context


func _motion_state() -> Dictionary:
	return {"position": _vector(global_position), "requested_velocity": _vector(agent.velocity),
		"agent_target": _vector(agent.target_position), "order_version": order_version,
		"submitted_order": _submitted_order, "movement_frame": _last_movement_frame,
		"moving": moving, "crowd_enabled": crowd_enabled, "avoidance_enabled": agent.avoidance_enabled,
		"navigation_suspended": navigation_suspended, "radius": agent.radius}


func _contacts_after_move() -> Array:
	var contacts := []
	for index in get_slide_collision_count():
		var contact := get_slide_collision(index)
		var other := contact.get_collider()
		contacts.append({"collider_instance_id": other.get_instance_id() if is_instance_valid(other) else null,
			"point": _vector(contact.get_position()), "normal": _vector(contact.get_normal()),
			"travel": _vector(contact.get_travel()), "remainder": _vector(contact.get_remainder())})
	return contacts


func _on_avoidance_velocity(safe_velocity: Vector3) -> void:
	var lifetime: WeakRef = weakref(self)
	var source := recorder
	var previous_callback := _probe_active_callback
	_probe_callback_sequence += 1
	var received := {"kind": "avoidance_callback", "absolute_frame": Engine.get_physics_frames(),
		"observer_local_callback_sequence": _probe_callback_sequence,
		"sequence_provenance": "observer-local receipt counter, not engine submission identity",
		"callback_input": _vector(safe_velocity), "before": _motion_state(), "after": null,
		"movement_calls": [], "delegation_returned": false, "instance_survived": null}
	_probe_active_callback = received
	# The recorder retains this dictionary by reference. Admission occurs for every
	# received callback, including those whose normal delegate does not move.
	if is_instance_valid(source) and source.live:
		source.motion(self, received)
	super._on_avoidance_velocity(safe_velocity)
	received["delegation_returned"] = true
	received["instance_survived"] = lifetime.get_ref() != null
	if lifetime.get_ref() == null:
		return
	received["after"] = _motion_state()
	received["movement_delegate_invoked"] = not received.movement_calls.is_empty()
	received["applied_displacement"] = _vector(global_position - Vector3(received.before.position[0], received.before.position[1], received.before.position[2]))
	_probe_active_callback = previous_callback


func _move_on_navigation(desired_velocity: Vector3, delta: float) -> void:
	var lifetime: WeakRef = weakref(self)
	var source := recorder
	var before_position := global_position
	var before_frame := _last_movement_frame
	var received_callback := _probe_active_callback
	var movement := {"absolute_frame": Engine.get_physics_frames(), "desired_input": _vector(desired_velocity),
		"delta": delta, "position_before": _vector(before_position), "position_after": null,
		"movement_frame_before": before_frame, "movement_frame_after": null,
		"movement_frame_changed": null,
		"displacement": null, "contacts": null, "guard_branch": null,
		"contacts_provenance": "most recent CharacterBody slide results after delegate; may precede this call if it returned early",
		"guard_provenance": "actual movement delegate call observed; internal early-return branch unavailable",
		"delegation_returned": false, "instance_survived": null}
	var direct: Dictionary = {}
	if received_callback.is_empty():
		direct = {"kind": "direct_movement_call", "absolute_frame": Engine.get_physics_frames(),
			"observer_local_callback_sequence": null, "callback_input": null, "before": _motion_state(),
			"after": null, "movement_calls": [movement], "delegation_returned": false, "instance_survived": null}
		if is_instance_valid(source) and source.live:
			source.motion(self, direct)
	else:
		received_callback.movement_calls.append(movement)
	super._move_on_navigation(desired_velocity, delta)
	movement["delegation_returned"] = true
	movement["instance_survived"] = lifetime.get_ref() != null
	if lifetime.get_ref() == null:
		if not direct.is_empty():
			direct["delegation_returned"] = true
			direct["instance_survived"] = false
		return
	movement["position_after"] = _vector(global_position)
	movement["movement_frame_after"] = _last_movement_frame
	movement["movement_frame_changed"] = _last_movement_frame != before_frame
	movement["displacement"] = _vector(global_position - before_position)
	movement["contacts"] = _contacts_after_move()
	if not direct.is_empty():
		direct["after"] = _motion_state()
		direct["delegation_returned"] = true
		direct["instance_survived"] = true
		direct["applied_displacement"] = _vector(global_position - before_position)
