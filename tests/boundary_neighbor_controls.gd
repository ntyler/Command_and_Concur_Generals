extends "res://tests/boundary_neighbor_checks.gd"
## Public-command controls for the new boundary/fence fixture, not historical replay.
var suite_prefix := "res://validation-output/m5-current-reliability/controls"
var control_results: Array = []
var control_first_check := 0
var control_first_failure := 0


func _run() -> void:
	root.size = Vector2i(1280, 800)
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--diagnostic-prefix="):
			suite_prefix = argument.trim_prefix("--diagnostic-prefix=")
	DirAccess.make_dir_recursive_absolute(suite_prefix.get_base_dir())
	var logger := EngineErrorProbe.new()
	OS.add_logger(logger)
	await _begin_control("clear")
	await _public_arrival(GOAL, "clear route without parked units")
	await _finish_control()
	await _begin_control("inaccessible")
	var version := mover.order_version
	_check(mover.move_to(GOAL), "inaccessible: occupied final goal command accepted")
	await _wait_for_order(mover, GOAL, version + 1)
	_check(not mover.moving and mover.movement_state == RTSUnit.MovementState.FAILED and not _arrived(mover, GOAL), "inaccessible: occupied final goal produces failure without false arrival")
	_check(mover.recovery_attempts <= mover.maximum_recoveries and mover.command_elapsed <= mover.command_timeout + 1.0 / 60.0, "inaccessible: failure respects the original attempt and command budgets")
	_check(neighbors[0].global_position.distance_to(GOAL) < 0.001 and not neighbors[0].moving, "inaccessible: stationary goal occupant remains in place")
	recorder.event_group("inaccessible_bounded_failure", _metrics(), true)
	await _public_arrival(START, "FAILED unit replacement to clear initial position")
	await _finish_control()
	await _begin_control("replacement")
	await _start_and_recover()
	field.selection.select_clicked(mover, false)
	version = mover.order_version
	var replacement := START + Vector3(0, 0, 3)
	var batch := field.issue_move(replacement)
	_check(batch.is_complete() and not batch.superseded and batch.assignments.get(mover.unit_id) == replacement, "recovery replacement: complete CommandBatchResult preserves accepted target")
	await _wait_for_order(mover, replacement, version + 1)
	_check(_arrived(mover, replacement) and mover.order_version == version + 1 and not mover.recovery_active and mover.recovery_attempts == 0, "recovery replacement: new order arrives and obsolete recovery cannot resume")
	await _finish_control()
	await _begin_control("stop")
	await _start_and_recover()
	field.selection.select_clicked(mover, false)
	version = mover.order_version
	var event := InputEventKey.new()
	event.physical_keycode = KEY_X
	event.pressed = true
	root.push_input(event, true)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event, true)
	await _frames(2)
	var stop_goal := mover.assigned_destination
	var stopped := await _sample_stationary(field.units, 180)
	_check(stopped.stable and mover.order_version == version + 1 and not mover.recovery_active and mover.recovery_attempts == 0 and mover.global_position.distance_to(stop_goal) < 0.001, "viewport X Stop: clears actual recovery and holds its accepted stop position for 180 ticks")
	# Stop can occur in congestion. A separate public move tests subsequent arrival
	# and the original arrival separation, without changing where Stop takes effect.
	for participant in field.units:
		positions[participant.unit_id] = participant.global_position
	await _public_arrival(START, "replacement after viewport X Stop")
	await _finish_control()
	await _begin_control("neighbor_departure")
	await _start_and_recover()
	var departure_goal := Vector3(29.5, 0, 19.05)
	var neighbor_version := neighbors[0].order_version
	_check(neighbors[0].move_to(departure_goal), "departure: implicated first fence neighbor receives an ordinary move during recovery")
	await _wait_for_order(mover, GOAL, mover.order_version)
	_check(_arrived(mover, GOAL), "departure: mover reaches unchanged final goal after neighbor moves")
	await _wait_for_order(neighbors[0], departure_goal, neighbor_version + 1)
	_check(_arrived(neighbors[0], departure_goal), "departure: commanded neighbor reaches its own accepted destination")
	await _finish_control(0)
	await _begin_control("nearby_variation")
	await _public_arrival(GOAL, "nearby fence shifted 0.2 metres in x")
	await _finish_control()
	# The planned escape retains state across two legs. Interrupt that actual
	# second leg separately from the existing first-admission controls above.
	await _second_leg_interrupt(false)
	await _second_leg_interrupt(true)
	_check(root.get_children().is_empty(), "boundary controls: all fresh fields and listeners are removed")
	OS.remove_logger(logger)
	_check(logger.error_count() == failures, "boundary controls: no additional native errors or warnings")
	print("BOUNDARY_CONTROL_RESULTS: ", JSON.stringify(control_results))
	print("BOUNDARY_CONTROL_CHECKS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _parked_points() -> Array:
	if case_name == "clear":
		return []
	if case_name == "inaccessible":
		return [GOAL]
	var result: Array = PARKED.duplicate()
	if case_name == "nearby_variation":
		for index in result.size():
			result[index] += Vector3(0.2, 0, 0)
	return result


func _requires_usable_route() -> bool:
	return case_name != "inaccessible"


func _begin_control(label: String) -> void:
	control_first_check = checks
	control_first_failure = failures
	case_name = label
	output_prefix = suite_prefix + "-" + label
	neighbors.clear()
	parked_positions.clear()
	positions.clear()
	waypoints.clear()
	maximum_step = 0.0
	minimum_route_separation = INF
	navigation_legal = true
	collision_legal = true
	budget_legal = true
	command_authority = true
	elapsed_frames = 0
	last_recovery_target = Vector3.INF
	last_attempt = -1
	await _setup()
	recorder.metadata["control_simplification"] = {
		"clear": "Fresh normal scene with no neighbors; original obstacle geometry, actor start and goal.",
		"inaccessible": "One normally created and publicly parked unit occupies the exact final goal; success is not expected before a replacement order.",
		"nearby_variation": "All four neighbor initial/public parking positions shifted +0.2 in x before tree entry; actor start, final goal and obstacle geometry unchanged."
	}.get(label, "Fresh original five-unit boundary fixture with a declared public command during actual recovery.")
	recorder.start_route(case_name)


func _public_arrival(target: Vector3, label: String) -> void:
	var version := mover.order_version
	_check(mover.move_to(target) and mover.order_version == version + 1 and mover.assigned_destination == target, label + ": fresh public order accepted")
	await _wait_for_order(mover, target, version + 1)
	_check(_arrived(mover, target), label + ": actual arrival at accepted destination")


func _start_and_recover(require_second: bool = false) -> void:
	var version := mover.order_version
	_check(mover.move_to(GOAL), case_name + ": initial public goal accepted")
	for frame in range(90 * 60 + 2):
		await physics_frame
		elapsed_frames += 1
		_observe_recovery_wait(version + 1)
		if (mover.recovery_active and (not require_second or mover._recovery_waypoints == 2)) or not mover.moving:
			break
	_check(mover.recovery_active and mover.movement_state == RTSUnit.MovementState.RECOVERING, case_name + ": intervention occurs during actual engine-driven recovery")
	if require_second:
		_check(mover.recovery_active and mover._recovery_waypoints == 2 and not mover._recovery_escape.is_empty(), case_name + ": actual planned second leg has retained escape state before intervention")
	recorder.event_group("public_control_intervention", {"case": case_name, "recovery_active": mover.recovery_active, "attempt": mover.recovery_attempts,
		"waypoint_count": mover._recovery_waypoints, "retained_escape_points": mover._recovery_escape.size()}, true)


func _second_leg_interrupt(stop_order: bool) -> void:
	await _begin_control("stop_second" if stop_order else "replacement_second")
	await _start_and_recover(true)
	field.selection.select_clicked(mover, false)
	var version := mover.order_version
	var replacement := Vector3(30, 0, 24)
	if stop_order:
		var event := InputEventKey.new()
		event.physical_keycode = KEY_X
		event.pressed = true
		root.push_input(event, true)
		event = event.duplicate()
		event.pressed = false
		root.push_input(event, true)
		await _frames(2)
		var stop_goal := mover.assigned_destination
		_check(mover.order_version == version + 1 and not mover.recovery_active and mover._recovery_waypoints == 0 and mover._recovery_escape.is_empty(), "second-leg X Stop: public input immediately clears the retained plan")
		var stopped := await _sample_stationary(field.units, 180)
		_check(stopped.stable and mover.global_position.distance_to(stop_goal) < 0.001 and mover._recovery_escape.is_empty(), "second-leg X Stop: obsolete planned leg stays inactive through 180 stationary ticks")
		for participant in field.units:
			positions[participant.unit_id] = participant.global_position
		await _public_arrival(replacement, "new clear-route command after second-leg X Stop")
	else:
		var batch := field.issue_move(replacement)
		_check(batch.is_complete() and not batch.superseded and batch.assignments.get(mover.unit_id) == replacement, "second-leg replacement: complete batch accepts the new destination")
		_check(mover.order_version == version + 1 and not mover.recovery_active and mover._recovery_waypoints == 0 and mover._recovery_escape.is_empty(), "second-leg replacement: public command immediately clears the retained plan")
		await _wait_for_order(mover, replacement, version + 1)
	_check(_arrived(mover, replacement) and mover._recovery_escape.is_empty() and mover._recovery_waypoints == 0, case_name + ": new command actually arrives without restoring the obsolete planned leg")
	await _finish_control()


func _observe_recovery_wait(generation: int) -> void:
	minimum_route_separation = minf(minimum_route_separation, _minimum_separation())
	for participant in field.units:
		maximum_step = maxf(maximum_step, participant.global_position.distance_to(positions[participant.unit_id]))
		positions[participant.unit_id] = participant.global_position
		for obstacle in field.obstacles:
			collision_legal = collision_legal and not obstacle.grow(RTSUnit.BODY_RADIUS).has_point(Vector2(participant.global_position.x, participant.global_position.z))
	if elapsed_frames % 6 == 0:
		navigation_legal = navigation_legal and _point_legal(mover.global_position)
	budget_legal = budget_legal and mover.recovery_attempts <= mover.maximum_recoveries and mover._recovery_waypoints <= 2 and mover._recovery_elapsed <= mover.recovery_duration + 1.0 / 60.0 and mover.command_elapsed <= mover.command_timeout + 1.0 / 60.0
	command_authority = command_authority and mover.order_version == generation and mover.assigned_destination == GOAL
	if mover.recovery_active and (last_recovery_target != mover.recovery_target or last_attempt != mover.recovery_attempts):
		last_recovery_target = mover.recovery_target
		last_attempt = mover.recovery_attempts
		waypoints.append({"frame": Engine.get_physics_frames(), "elapsed": mover.command_elapsed, "attempt": mover.recovery_attempts,
			"position": Recorder._vector(mover.global_position), "target": Recorder._vector(mover.recovery_target)})


func _finish_control(departing_index: int = -1) -> void:
	var all_calls_bounded := true
	for participant in field.units:
		all_calls_bounded = all_calls_bounded and participant.excessive_steps == 0
		_check(_point_legal(participant.global_position), case_name + ": final participant center remains legally navigable")
	_check(navigation_legal and collision_legal and maximum_step <= mover.movement_speed / 60.0 + 0.001 and all_calls_bounded, case_name + ": movement remains navigable, collision-constrained and speed bounded")
	_check(budget_legal and command_authority, case_name + ": duration, attempts and accepted commands retain authority")
	var unchanged := true
	for index in neighbors.size():
		if index != departing_index:
			unchanged = unchanged and not neighbors[index].moving and neighbors[index].global_position.distance_to(parked_positions[index]) < 0.001
	_check(unchanged, case_name + ": every uncommanded parked neighbor remains fixed")
	var settled := await _sample_stationary(field.units, 180)
	_check(settled.stable and _minimum_separation() > 0.6, case_name + ": all final arrivals settle for original 180 ticks and separation")
	var result := _metrics()
	result["final_accepted_goal_arrived"] = _arrived(mover, mover.assigned_destination)
	result["stationary"] = settled
	result["checks"] = checks - control_first_check
	result["failures"] = failures - control_first_failure
	recorder.end_route(result)
	await process_frame
	var coverage: Dictionary = recorder.finish(output_prefix)
	_check(coverage.complete, case_name + ": existing bounded recorder capture is complete")
	result["checks"] = checks - control_first_check
	result["failures"] = failures - control_first_failure
	result["capture_complete"] = coverage.complete
	control_results.append(result)
	print("BOUNDARY_CONTROL_DETAIL: ", JSON.stringify(result))
	recorder.close()
	field.queue_free()
	await _frames(5)
