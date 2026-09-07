extends "res://tests/milestone_checks.gd"
## New behavioral fixture, not a replay of historical unit 41 or Issue B.
const Recorder = preload("res://tests/full_sequence_recorder.gd")
const Probe = preload("res://tests/boundary_neighbor_probe.gd")
const START := Vector3(24, 0, 19.3)
const GOAL := Vector3(28.5, 0, 17.5)
const PARKED := [Vector3(26.8, 0, 19.05), Vector3(26.8, 0, 20.15), Vector3(26.8, 0, 21.25), Vector3(26.8, 0, 22.35)]
const WITNESS := [Vector3(24, 0, 23.6), Vector3(29, 0, 23.6), GOAL]
var mover: RTSUnit
var neighbors: Array[RTSUnit] = []
var recorder: RefCounted
var output_prefix := "res://validation-output/m5-current-reliability/focused"
var case_name := "automatic"
var maximum_step := 0.0
var navigation_legal := true
var collision_legal := true
var budget_legal := true
var command_authority := true
var elapsed_frames := 0
var positions: Dictionary = {}
var parked_positions: Array[Vector3] = []
var waypoints: Array = []
var last_recovery_target := Vector3.INF
var last_attempt := -1
var minimum_route_separation := INF

class ReducedField extends TestField:
	func _unit_count() -> int:
		return 0


func _run() -> void:
	root.size = Vector2i(1280, 800)
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--diagnostic-prefix="):
			output_prefix = argument.trim_prefix("--diagnostic-prefix=")
		elif argument.begins_with("--case="):
			case_name = argument.trim_prefix("--case=")
	DirAccess.make_dir_recursive_absolute(output_prefix.get_base_dir())
	var logger := EngineErrorProbe.new()
	OS.add_logger(logger)
	await _setup()
	if case_name != "wiring":
		recorder.start_route(case_name)
		var route: Array = WITNESS if case_name == "witness" else [GOAL]
		for target in route:
			var generation := mover.order_version
			_check(mover.move_to(target) and mover.assigned_destination == target and mover.order_version == generation + 1, "boundary: explicit destination accepted on a fresh public order")
			await _wait_for_order(mover, target, generation + 1)
			_check(_arrived(mover, target), "boundary: actual arrival at each accepted destination")
			if not _arrived(mover, target):
				break
		_check(_arrived(mover, GOAL), "boundary: reaches the unchanged final destination")
		_check(float(elapsed_frames) / 60.0 < mover.command_timeout, "boundary: entire route including all witness orders fits original command deadline")
		_check(navigation_legal and collision_legal, "boundary: all sampled positions stay on navigation and outside expanded solid obstacles")
		_check(maximum_step <= mover.movement_speed / 60.0 + 0.001 and mover.excessive_steps == 0, "boundary: sampled and every actual movement call stay speed bounded")
		_check(budget_legal and command_authority, "boundary: recovery duration, attempts, order and destination remain authoritative")
		if case_name == "witness":
			_check(minimum_route_separation > RTSUnit.BODY_RADIUS * 2, "boundary: actual public witness maintains full body clearance throughout")
		var settled := await _sample_stationary(field.units, 180)
		_check(settled.stable and _minimum_separation() > 0.6, "boundary: all participants arrive and settle for original 180 ticks with original separation")
		var unchanged := true
		for index in neighbors.size():
			unchanged = unchanged and not neighbors[index].moving and neighbors[index].global_position.distance_to(parked_positions[index]) < 0.001
		_check(unchanged, "boundary: parked neighbors never move to manufacture success")
		recorder.end_route(_metrics())
	await process_frame # Finish any admitted callback before synchronous capture.
	var coverage: Dictionary = recorder.finish(output_prefix)
	_check(coverage.complete, "boundary: existing bounded recorder writes complete capture")
	print("BOUNDARY_DETAIL: ", JSON.stringify(_metrics()))
	recorder.close()
	field.queue_free()
	await _frames(5)
	_check(root.get_children().is_empty(), "boundary: teardown removes scene and units")
	OS.remove_logger(logger)
	_check(logger.error_count() == failures, "boundary: no additional native errors or warnings")
	print("BOUNDARY_NEIGHBOR_CHECKS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _setup() -> void:
	var parked_points := _parked_points()
	field = ReducedField.new()
	field.stress_layout = true
	recorder = Recorder.new()
	recorder.field = field
	recorder.run_id = output_prefix.get_file()
	recorder.source_id = FileAccess.get_sha256("res://scripts/rts_unit.gd")
	recorder.run_first_frame = Engine.get_physics_frames()
	recorder.expected_units = parked_points.size() + 1
	if case_name != "wiring":
		recorder.required_routes.assign([case_name])
	recorder.metadata = {"new_behavioral_fixture": true, "case": case_name,
		"simplification": "five fresh normally created units on original stress geometry; four public parking orders precede mover command; no historical trajectory replay",
		"fixture_sha256": FileAccess.get_sha256("res://tests/boundary_neighbor_checks.gd"),
		"probe_sha256": FileAccess.get_sha256("res://tests/boundary_neighbor_probe.gd")}
	root.add_child(field)
	current_scene = field
	field.camera_rig.edge_scrolling_enabled = false
	mover = _add_unit(1, START)
	for index in parked_points.size():
		neighbors.append(_add_unit(index + 2, parked_points[index]))
	await _frames(5)
	_check(field.units.size() == parked_points.size() + 1 and field._registered.size() == field.units.size(), "boundary: normal unit creation and registration")
	_check(NavigationServer3D.map_get_iteration_id(mover.agent.get_navigation_map()) > 0, "boundary: original stress navigation synchronized")
	var legal := _minimum_separation() > RTSUnit.BODY_RADIUS * 2
	for unit in field.units:
		legal = legal and _point_legal(unit.global_position)
	legal = legal and _point_legal(GOAL)
	_check(legal, "boundary: initial capsules separated and all initial/final centers on legal navigation")
	var route_clear := true
	var route_length := 0.0
	var route_start := START
	for endpoint in WITNESS:
		route_length += route_start.distance_to(endpoint)
		for parked in parked_points:
			route_clear = route_clear and Geometry3D.get_closest_point_to_segment(parked, route_start, endpoint).distance_to(parked) > RTSUnit.BODY_RADIUS * 2
		for sample in range(21):
			route_clear = route_clear and _point_legal(route_start.lerp(endpoint, float(sample) / 20.0))
		route_start = endpoint
	if _requires_usable_route():
		_check(route_clear and route_length / mover.movement_speed < mover.command_timeout, "boundary: proposed witness has body clearance, legal centers and bounded geometric length")
	for index in neighbors.size():
		_check(neighbors[index].move_to(parked_points[index]), "boundary: public parking command accepted")
	await _frames(3)
	var parked := true
	for unit in neighbors:
		parked = parked and _arrived(unit, unit.assigned_destination)
		parked_positions.append(unit.global_position)
	_check(parked, "boundary: every neighbor confirms arrival before mover command")
	var settled := await _sample_stationary(field.units, 180)
	_check(settled.stable, "boundary: declared initial parking settles for 180 ticks")
	_check(mover.actual_movement_calls == 0 and mover.order_version == 0 and recorder.coverage_snapshot().commands_without_watch == 0, "boundary: harness observes before commands without pre-moving the actor")
	for unit in field.units:
		positions[unit.unit_id] = unit.global_position


func _parked_points() -> Array:
	return PARKED


func _requires_usable_route() -> bool:
	return true


func _add_unit(identity: int, point: Vector3) -> RTSUnit:
	var unit := Probe.new()
	unit.unit_id = identity
	unit.position = point # Initialization before tree entry, never a live teleport.
	unit.recorder = recorder
	field.add_child(unit)
	field.register_unit(unit)
	return unit


func _wait_for_order(unit: RTSUnit, target: Vector3, generation: int) -> void:
	for frame in range(90 * 60 + 2):
		await physics_frame
		elapsed_frames += 1
		minimum_route_separation = minf(minimum_route_separation, _minimum_separation())
		for participant in field.units:
			maximum_step = maxf(maximum_step, participant.global_position.distance_to(positions[participant.unit_id]))
			positions[participant.unit_id] = participant.global_position
			for obstacle in field.obstacles:
				collision_legal = collision_legal and not obstacle.grow(RTSUnit.BODY_RADIUS).has_point(Vector2(participant.global_position.x, participant.global_position.z))
		if frame % 6 == 0:
			navigation_legal = navigation_legal and _point_legal(unit.global_position)
		budget_legal = budget_legal and unit.recovery_attempts <= unit.maximum_recoveries and unit._recovery_waypoints <= 2 and unit._recovery_elapsed <= unit.recovery_duration + 1.0 / 60.0 and unit.command_elapsed <= unit.command_timeout + 1.0 / 60.0
		command_authority = command_authority and unit.order_version == generation and unit.assigned_destination == target
		if unit.recovery_active and (last_recovery_target != unit.recovery_target or last_attempt != unit.recovery_attempts):
			last_recovery_target = unit.recovery_target
			last_attempt = unit.recovery_attempts
			waypoints.append({"frame": Engine.get_physics_frames(), "elapsed": unit.command_elapsed, "attempt": unit.recovery_attempts, "position": Recorder._vector(unit.global_position), "target": Recorder._vector(unit.recovery_target)})
		if not unit.moving:
			return


func _point_legal(point: Vector3) -> bool:
	if NavigationServer3D.map_get_closest_point(mover.agent.get_navigation_map(), point).distance_to(point) >= 0.05:
		return false
	for obstacle in field.obstacles:
		if obstacle.grow(RTSUnit.BODY_RADIUS).has_point(Vector2(point.x, point.z)):
			return false
	return true


func _minimum_separation() -> float:
	var minimum := INF
	for a in field.units.size():
		for b in range(a + 1, field.units.size()):
			minimum = minf(minimum, field.units[a].global_position.distance_to(field.units[b].global_position))
	return minimum


func _arrived(unit: RTSUnit, target: Vector3) -> bool:
	return not unit.moving and unit.movement_state == RTSUnit.MovementState.ARRIVED and unit.global_position.distance_to(target) <= unit.stopping_distance + 0.01


func _metrics() -> Dictionary:
	return {"case": case_name, "source_sha256": recorder.source_id, "arrived": _arrived(mover, GOAL), "position": Recorder._vector(mover.global_position),
		"accepted": Recorder._vector(mover.assigned_destination), "generation": mover.order_version,
		"total_route_seconds": float(elapsed_frames) / 60.0, "command_seconds": mover.command_elapsed,
		"recoveries": mover.recovery_attempts, "waypoints": waypoints.duplicate(true), "maximum_sampled_step": maximum_step,
		"actual_movement_calls": mover.actual_movement_calls, "maximum_actual_step": mover.maximum_actual_step,
		"excessive_steps": mover.excessive_steps, "minimum_final_separation": Recorder._number(_minimum_separation()), "minimum_route_separation": Recorder._number(minimum_route_separation),
		"navigation_legal": navigation_legal, "collision_legal": collision_legal}
