extends "res://tests/full_sequence_checks.gd"
## Wiring/capture tests only. These are not Issue B reproductions.


func _run() -> void:
	_configure_capture()
	root.size = Vector2i(1280, 800)
	var logger := EngineErrorProbe.new()
	OS.add_logger(logger)
	# Ordinary original field first; no concurrent crowd processes/cohorts.
	field = load("res://scenes/movement_stress.tscn").instantiate() as TestField
	field.stress_unit_count = 50
	root.add_child(field)
	current_scene = field
	field.camera_rig.edge_scrolling_enabled = false
	for unit in field.units:
		field.selection.select_clicked(unit, true)
	await _frames(5)
	var plain_configuration := _configuration()
	_assignment_checks(50) # The actual original checks/commands, not a substitute.
	var plain_command := _command_configuration()
	await _fresh(50)
	recorder.required_routes.clear() # This separate wiring harness is not a full run.
	var recorded_configuration := _configuration()
	_check(plain_configuration == recorded_configuration, "recorder wiring: original scene/unit/agent setup and registration are preserved")
	_check(recorder.coverage_snapshot().get("covered_unit_ids", []).size() == 50, "recorder wiring: all 50 participants watched before assignment commands")
	_assignment_checks(50)
	var recorded_command := _command_configuration()
	_check(plain_command == recorded_command, "recorder wiring: original assignment checks preserve group generations, acceptance and per-unit orders")
	var wiring_file := FileAccess.open(prefix + "-wiring.json", FileAccess.WRITE)
	_check(wiring_file != null, "recorder wiring: configuration/command comparison artifact opens")
	if wiring_file != null:
		wiring_file.store_string(JSON.stringify({"plain_configuration": plain_configuration, "recorded_configuration": recorded_configuration,
			"plain_command": plain_command, "recorded_command": recorded_command, "not_a_trajectory_comparison": true}))
		wiring_file.close()
	var tracked := field.units[0]
	field.selection.select_clicked(tracked, false)
	recorder.start_route("harness_movement")
	var accepted := field.issue_move(tracked.global_position + Vector3(0, 0, -6))
	_check(accepted.is_complete(), "recorder harness: ordinary command accepted for progress/arrival capture")
	var destination := tracked.assigned_destination
	var observed_order := tracked.order_version
	for frame in 600:
		await physics_frame
		if not tracked.moving:
			break
	_check(tracked.movement_state == RTSUnit.MovementState.ARRIVED and tracked.global_position.distance_to(destination) <= tracked.stopping_distance + 0.01,
		"recorder harness: actual arrival through inherited movement")
	var stationary := await _sample_stationary([tracked], 180)
	_check(stationary.stable, "recorder harness: ordinary arrival remains settled")
	# Explicit synthetic signal, confined to this harness. It validates observation
	# of received-but-rejected callbacks; it is never called in the original run.
	var position_before := tracked.global_position
	recorder.event_group("harness_synthetic_callback_before", {"unit_id": tracked.unit_id, "not_engine_generated": true}, true)
	tracked.agent.velocity_computed.emit(Vector3.RIGHT)
	recorder.event_group("harness_synthetic_callback_after", {"unit_id": tracked.unit_id, "not_engine_generated": true}, true)
	_check(tracked.global_position == position_before, "recorder harness: stopped synthetic callback preserves production movement rejection")
	var rejected_callback_recorded := false
	var applied_callback_recorded := false
	var clocks_consistent := true
	for envelope in recorder.archived_motion.values():
		var motion: Dictionary = envelope.record
		clocks_consistent = clocks_consistent and envelope.clock.absolute_frame == motion.absolute_frame
		if motion.kind == "avoidance_callback" and motion.absolute_frame == Engine.get_physics_frames() and motion.callback_input == [1.0, 0.0, 0.0] and not motion.before.moving:
			rejected_callback_recorded = motion.movement_calls.is_empty() and not motion.movement_delegate_invoked and motion.delegation_returned
		if motion.kind == "avoidance_callback" and motion.before.moving:
			for movement in motion.movement_calls:
				applied_callback_recorded = applied_callback_recorded or movement.get("movement_frame_changed", false)
	_check(rejected_callback_recorded, "recorder harness: received callback with no movement call is explicitly retained")
	_check(applied_callback_recorded, "recorder harness: received callback and actual movement delegation are linked")
	_check(clocks_consistent, "recorder harness: callback and recorder absolute-frame domains agree")
	# Queue ordinary sender deletion from arrival. Godot locks the emitting object
	# against immediate free(); this uses its supported scene lifetime operation.
	var departing := field.units[-1]
	var departing_lifetime: WeakRef = weakref(departing)
	departing.movement_state_changed.connect(func(state: int) -> void:
		if state == RTSUnit.MovementState.ARRIVED and departing_lifetime.get_ref() != null:
			departing_lifetime.get_ref().queue_free())
	_check(departing.move_to(departing.global_position), "recorder harness: public zero-distance arrival command accepted for lifetime test")
	await _frames(3)
	_check(departing_lifetime.get_ref() == null, "recorder harness: queued sender deletion from terminal transition is safe")
	var queries := 0
	var sampled_queries := 0
	var progress_samples := 0
	var precleanup := 0
	var postcleanup := 0
	for event in recorder.events:
		var matches_actor: bool = event.before.get("id") == tracked.unit_id and event.before.get("order_version") == observed_order
		if event.kind == "actual_final_path_query" and matches_actor:
			queries += 1
			if event.details.get("delegate_context") == "update_progress" and event.details.actual_return.classification == "finite":
				sampled_queries += 1
		if event.kind == "progress_sample_result" and matches_actor:
			progress_samples += 1
		if event.kind == "terminal_requested" and matches_actor and event.before.get("moving", false):
			precleanup += 1
		if event.kind == "terminal_result" and matches_actor and not event.after.get("moving", true):
			postcleanup += 1
	_check(queries >= 2 and sampled_queries >= 1 and sampled_queries == progress_samples, "recorder harness: actual progress-window queries and results are captured for the accepted order")
	_check(precleanup > 0 and postcleanup > 0, "recorder harness: terminal state is captured before and after cleanup")
	recorder.end_route({"harness_only": true})
	var route_origins := {}
	for event in recorder.events:
		var clock: Dictionary = event.clock
		var origin: int = clock.absolute_frame - clock.route_frame
		clocks_consistent = clocks_consistent and clock.run_frame == clock.absolute_frame - run_first_frame
		clocks_consistent = clocks_consistent and is_equal_approx(clock.run_seconds, float(clock.run_frame) / clock.physics_ticks_per_second)
		clocks_consistent = clocks_consistent and is_equal_approx(clock.route_seconds, float(clock.route_frame) / clock.physics_ticks_per_second)
		clocks_consistent = clocks_consistent and route_origins.get(clock.route, origin) == origin
		route_origins[clock.route] = origin
	_check(clocks_consistent and route_origins.size() == 2, "recorder harness: explicit setup/route/run frame and simulation-time mappings agree")
	var observed: Dictionary = recorder.inspection()
	var file := FileAccess.open(prefix + "-harness-observation.json", FileAccess.WRITE)
	_check(file != null, "recorder harness: observation artifact opens")
	if file != null:
		file.store_string(JSON.stringify(observed))
		file.close()
	var lifetime: WeakRef = weakref(tracked)
	var capture := recorder
	field.queue_free()
	await _frames(5)
	_check(lifetime.get_ref() == null and root.get_children().is_empty(), "recorder harness: ordinary field teardown frees units")
	var coverage: Dictionary = capture.finish(prefix)
	_check(bool(coverage.get("complete", false)), "recorder harness: serialization and bounded coverage are complete")
	capture.close()
	_check(capture.connections.is_empty(), "recorder harness: teardown releases every observer listener")
	OS.remove_logger(logger)
	_check(logger.error_count() == failures, "recorder harness: no additional engine errors, warnings or leaks")
	print("FULL_SEQUENCE_HARNESS_CHECKS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _configuration() -> Dictionary:
	var result := {"units": [], "selected": _ids(field.selection.selected_units()),
		"registered": field._registered.size(), "name": str(field.name),
		"geometry": _static_configuration(field).geometry_sha256}
	for unit in field.units:
		var values := {"id": unit.unit_id, "name": str(unit.name), "owner": unit.owner_id,
			"position": [unit.position.x, unit.position.y, unit.position.z],
			"layer": unit.collision_layer, "mask": unit.collision_mask,
			"process_priority": unit.process_priority, "physics_priority": unit.process_physics_priority,
			"motion_mode": unit.motion_mode, "registered": field.contains_unit(unit)}
		for property in unit.get_property_list():
			# Configurable primitive script values cover all movement/crowd exports.
			if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE and property.usage & PROPERTY_USAGE_EDITOR and property.type in [TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING]:
				values[property.name] = unit.get(property.name)
		var agent_values := {}
		for property in ["path_desired_distance", "target_desired_distance", "path_max_distance", "radius", "height", "max_speed",
			"neighbor_distance", "max_neighbors", "time_horizon_agents", "avoidance_priority", "avoidance_enabled", "avoidance_layers", "avoidance_mask"]:
			agent_values[property] = unit.agent.get(property)
		values["agent"] = agent_values
		result.units.append(values)
	return result


func _command_configuration() -> Dictionary:
	var result := {"generation": field._command_version, "next": field._next_command_generation,
		"selected": _ids(field.selection.selected_units()), "accepted": Array(field.last_command_result.accepted_ids), "units": []}
	for unit in field.units:
		result.units.append({"id": unit.unit_id, "order": unit.order_version,
			"assigned": [unit.assigned_destination.x, unit.assigned_destination.y, unit.assigned_destination.z], "moving": unit.moving})
	return result
