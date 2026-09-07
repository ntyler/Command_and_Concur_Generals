extends "res://tests/milestone_checks.gd"
## Both originally failed participants, with all 48 recorded parked neighbors.
## Clear recorded detour positions avoid manufacturing initial body overlaps.
const Focused = preload("res://tests/parked_deadlock_checks.gd")
const History = preload("res://tests/cluster_diagnostic_history.gd")


func _run() -> void:
	root.size = Vector2i(1280, 800)
	var prefix := "res://validation-output/captured-parked-cluster"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--diagnostic-prefix="):
			prefix = argument.trim_prefix("--diagnostic-prefix=")
	DirAccess.make_dir_recursive_absolute(prefix.get_base_dir())
	var logger := EngineErrorProbe.new()
	OS.add_logger(logger)
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/parked_cluster_capture.json"))
	field = Focused.ReducedField.new()
	field.stress_layout = true
	root.add_child(field)
	current_scene = field
	field.camera_rig.edge_scrolling_enabled = false
	var goals := {}
	var parked := {}
	var movers: Array[RTSUnit] = []
	for entry in fixture.units:
		var unit := RTSUnit.new()
		unit.unit_id = int(entry.id)
		unit.position = Vector3(entry.position[0], entry.position[1], entry.position[2])
		field.add_child(unit)
		field.register_unit(unit)
		goals[unit.unit_id] = Vector3(entry.assigned[0], entry.assigned[1], entry.assigned[2])
		if unit.unit_id in [6, 12]:
			movers.append(unit)
		else:
			parked[unit.unit_id] = unit.global_position
	await _frames(5)
	_check(field.units.size() == 50 and field._registered.size() == 50, "captured arrangement retains all 50 normally registered participants")
	var separated := true
	for a in field.units.size():
		for b in range(a + 1, field.units.size()):
			separated = separated and field.units[a].global_position.distance_to(field.units[b].global_position) > 2 * RTSUnit.BODY_RADIUS
	_check(separated, "captured arrangement starts without overlapping collision capsules")
	var parked_ok := true
	for unit in field.units:
		if parked.has(unit.unit_id):
			parked_ok = unit.move_to(goals[unit.unit_id]) and parked_ok
	await _frames(3)
	for unit in field.units:
		if parked.has(unit.unit_id):
			parked_ok = parked_ok and not unit.moving and unit.movement_state == RTSUnit.MovementState.ARRIVED
	_check(parked_ok, "48 neighbors enter normal parked state through public move orders")
	var observer := History.new()
	root.add_child(observer)
	observer.begin(field)
	var accepted := true
	var versions := {}
	for unit in movers:
		versions[unit.unit_id] = unit.order_version + 1
		accepted = unit.move_to(goals[unit.unit_id]) and accepted
	_check(accepted, "both originally failed units accept fresh commands at captured goals")
	var stationary_neighbors := true
	for frame in range(75 * 60):
		await physics_frame
		for unit in field.units:
			if parked.has(unit.unit_id):
				stationary_neighbors = stationary_neighbors and unit.global_position.distance_to(parked[unit.unit_id]) < 0.001 and not unit.moving
		if not movers[0].moving and not movers[1].moving:
			break
	var arrived := true
	for unit in movers:
		var reached: bool = unit.order_version == versions[unit.unit_id] and unit.assigned_destination == goals[unit.unit_id] and unit.movement_state == RTSUnit.MovementState.ARRIVED and unit.global_position.distance_to(goals[unit.unit_id]) <= unit.stopping_distance + 0.01
		_check(reached, "captured unit %d actually arrives at its original accepted goal" % unit.unit_id)
		arrived = arrived and reached
		print("CAPTURED_DETAIL: id=", unit.unit_id, " state=", unit.movement_state, " position=", unit.global_position, " goal=", unit.assigned_destination, " order=", unit.order_version, " elapsed=", unit.command_elapsed, " attempts=", unit.recovery_attempts)
	_check(stationary_neighbors, "all 48 parked neighbors remain stationary during recovery")
	var settled := await _sample_stationary(field.units, 180)
	_check(not arrived or settled.stable, "successful captured arrangement remains settled for 180 physics ticks")
	observer.finish(not arrived, {"all_arrived": arrived, "stationary_displacement": settled.max_displacement}, prefix)
	observer.free()
	field.queue_free()
	await _frames(5)
	_check(root.get_children().is_empty(), "captured arrangement teardown removes all nodes and observer")
	OS.remove_logger(logger)
	_check(logger.error_count() == failures, "captured arrangement has no additional native errors or warnings")
	print("CAPTURED_PARKED_CHECKS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
