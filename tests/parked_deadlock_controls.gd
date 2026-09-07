extends "res://tests/parked_deadlock_checks.gd"
## Discriminating controls run separately from the unchanged captured-goal case.


func _run() -> void:
	root.size = Vector2i(1280, 800)
	var logger := EngineErrorProbe.new()
	OS.add_logger(logger)
	# Every comparison recreates the original case first; edits never carry over.
	await _setup()
	neighbors[0].free()
	await _frames(3)
	await _command_arrival(mover, GOAL, "one implicated neighbor removed")
	_check(field.units.size() == 2, "departed neighbor is absent from membership/reservations")
	await _setup()
	await _command_arrival(neighbors[0], Vector3(33, 0, 12), "neighbor moves to nonblocking position")
	await _command_arrival(mover, GOAL, "one implicated neighbor moved")
	await _setup()
	for unit in neighbors:
		unit.free()
	await _frames(3)
	await _command_arrival(mover, GOAL, "clear destination without parked neighbors")
	await _setup()
	# A reachability witness via public orders, NOT a production repair or a
	# substitute for arrival under the original single captured-goal command.
	for point in [Vector3(33.5, 0, 16), Vector3(30, 0, 16), GOAL]:
		await _command_arrival(mover, point, "explicit outer detour witness")
	for index in neighbors.size():
		_check(neighbors[index].global_position.distance_to(PARKED[index]) < 0.001, "outer detour needs no parked-unit motion")
	await _setup()
	var replacement := START + Vector3(0, 0, 3)
	var receipt: Array[CommandBatchResult] = []
	field.selection.select_clicked(mover, false)
	var on_recover := func(state: RTSUnit.MovementState) -> void:
		if state == RTSUnit.MovementState.RECOVERING and receipt.is_empty():
			receipt.append(field.issue_move(replacement))
	mover.movement_state_changed.connect(on_recover)
	var version := mover.order_version
	_check(mover.move_to(GOAL), "replacement fixture initial command accepted")
	await _wait_stopped(mover)
	mover.movement_state_changed.disconnect(on_recover)
	_check(receipt.size() == 1 and receipt[0].is_complete() and not receipt[0].superseded and receipt[0].assignments[mover.unit_id] == replacement, "synchronous recovery replacement retains complete historical batch")
	_check(mover.order_version == version + 2 and mover.assigned_destination == replacement and mover.recovery_attempts == 0, "replacement clears obsolete recovery and owns new assignment")
	_check(_arrived(mover, replacement), "recovery replacement actually arrives")
	await _setup()
	var departed := {"done": false}
	var depart_on_recover := func(state: RTSUnit.MovementState) -> void:
		if state == RTSUnit.MovementState.RECOVERING and not departed.done:
			departed.done = true
			neighbors[0].free() # Immediate deletion of a neighboring node, not the emitting mover.
	mover.movement_state_changed.connect(depart_on_recover)
	await _command_arrival(mover, GOAL, "neighbor departs synchronously during recovery")
	mover.movement_state_changed.disconnect(depart_on_recover)
	_check(departed.done and field.units.size() == 2, "departure control actually ran during recovery")
	# The second leg is new state: interrupt it through real public commands.
	for stop_order in [true, false]:
		await _setup()
		field.selection.select_clicked(mover, false)
		_check(mover.move_to(GOAL), "second-leg fixture command accepted")
		var reached_second := false
		for frame in range(10 * 60):
			await physics_frame
			if mover.recovery_active and int(mover.get("_recovery_waypoints")) == 2:
				reached_second = true
				break
		_check(reached_second, "interrupt fixture reaches actual second recovery leg")
		version = mover.order_version
		if stop_order:
			var event := InputEventKey.new()
			event.physical_keycode = KEY_X
			event.pressed = true
			root.push_input(event, true)
			event = event.duplicate()
			event.pressed = false
			root.push_input(event, true)
			await _frames(2)
			var stopped := await _sample_stationary([mover], 180)
			_check(stopped.stable and mover.order_version == version + 1 and int(mover.get("_recovery_waypoints")) == 0, "viewport X Stop clears second leg and stays stationary")
		else:
			var batch := field.issue_move(replacement)
			_check(batch.is_complete() and not batch.superseded and batch.assignments[mover.unit_id] == replacement, "second-leg replacement captures complete batch assignment")
			await _wait_stopped(mover)
			_check(_arrived(mover, replacement) and mover.order_version == version + 1 and int(mover.get("_recovery_waypoints")) == 0, "second-leg replacement arrives without reviving obsolete waypoint")
	await _setup()
	var enclosure := Node3D.new()
	field.add_child(enclosure)
	for direction in [Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK]:
		var wall := StaticBody3D.new()
		wall.position = START + direction + Vector3.UP
		wall.collision_layer = 4
		var shape := BoxShape3D.new()
		shape.size = Vector3(0.15, 2, 2.2) if direction.x != 0 else Vector3(2.2, 2, 0.15)
		var collider := CollisionShape3D.new()
		collider.shape = shape
		wall.add_child(collider)
		enclosure.add_child(wall)
	await _frames(3)
	_check(mover.move_to(replacement), "inaccessible fixture command accepted on unchanged navmesh")
	await _wait_stopped(mover)
	_check(mover.movement_state == RTSUnit.MovementState.FAILED and not mover.moving and mover.recovery_attempts <= mover.maximum_recoveries and mover.command_elapsed <= mover.command_timeout, "solid enclosure causes bounded failure without false arrival")
	_check(mover.global_position.distance_to(START) < 0.8, "inaccessible case never crosses its solid enclosure")
	enclosure.queue_free()
	await _frames(3)
	await _command_arrival(mover, replacement, "FAILED unit accepts a fresh reachable command")
	var settled := await _sample_stationary([mover], 180)
	_check(settled.stable, "normal post-arrival position and velocity remain stable for 180 ticks")
	field.queue_free()
	await _frames(5)
	_check(root.get_children().is_empty(), "controls teardown leaves no fields, walls or listeners")
	OS.remove_logger(logger)
	_check(logger.error_count() == failures, "controls have no additional native errors or warnings")
	print("PARKED_CONTROL_CHECKS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _command_arrival(unit: RTSUnit, target: Vector3, label: String) -> void:
	var version := unit.order_version
	_check(unit.move_to(target) and unit.order_version == version + 1 and unit.assigned_destination == target, label + ": fresh command accepted")
	await _wait_stopped(unit)
	_check(unit.order_version == version + 1 and unit.assigned_destination == target and _arrived(unit, target), label + ": actual arrival at accepted target")
	print("CONTROL_DETAIL: ", label, " elapsed=", unit.command_elapsed, " attempts=", unit.recovery_attempts, " position=", unit.global_position)


func _wait_stopped(unit: RTSUnit) -> void:
	for frame in range(90 * 60 + 2):
		await physics_frame
		if not unit.moving:
			return


func _arrived(unit: RTSUnit, point: Vector3) -> bool:
	return not unit.moving and unit.movement_state == RTSUnit.MovementState.ARRIVED and unit.global_position.distance_to(point) <= unit.stopping_distance + 0.01
