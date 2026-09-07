extends "res://tests/full_sequence_harness_checks.gd"
## One fixed derived cluster fixture, not the original full suite or hidden-state replay.
## Reuses unchanged observation, setup inspection and original settling predicates.
const FixtureField = preload("res://tests/unit13_fixture_field.gd")
const FIXTURE_PATH := "res://tests/fixtures/unit13_predeadlock.json"
var fixture: Dictionary = {}
var wiring_only := false
var fixture_logger: EngineErrorProbe
var wiring: Dictionary = {}


func _run() -> void:
	_configure_capture()
	root.size = Vector2i(1280, 800)
	wiring_only = OS.get_cmdline_user_args().has("--fixture-wiring-only")
	fixture_logger = EngineErrorProbe.new()
	OS.add_logger(fixture_logger)
	fixture = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE_PATH))
	_check(fixture.get("units", []).size() == 50, "unit13 fixture: all 50 source participants provided")
	if failures > 0:
		quit(1)
		return
	await _setup_fixture()
	# Only ordinary public moves establish parked state and the original goals.
	var parking := _dispatch("parking_goal")
	_check(_accepted(parking), "unit13 fixture: all captured gate parking goals publicly accepted")
	await _frames(3)
	var parked := true
	for index in field.units.size():
		var unit := field.units[index]
		parked = parked and not unit.moving and unit.movement_state == RTSUnit.MovementState.ARRIVED
		parked = parked and is_equal_approx(unit.agent.radius, unit.parked_radius)
		parked = parked and unit.global_position.distance_to(_point(fixture.units[index].position)) < 0.001
	_check(parked, "unit13 fixture: all peers and actor park normally without changing captured starting poses")
	var initial_settling := await _sample_stationary(field.units, 180)
	_check(initial_settling.stable, "unit13 fixture: captured starting arrangement settles for 180 unchanged ticks")
	wiring["parking_commands"] = parking
	wiring["parked_configuration"] = _configuration()
	wiring["parked_minimum_separation"] = _minimum_separation()
	recorder.event_group("derived_fixture_parked", {"source_event": fixture.source_pose_event_id, "settling": initial_settling}, true)
	if failures > 0:
		# A malformed setup is a harness failure, never a mechanism execution result.
		await _finish_fixture({"classification": "fixture_setup_failure"})
		return
	recorder.start_route("fixture_wiring" if wiring_only else "unit13_cluster")
	var commands := _dispatch("goal")
	wiring["cluster_commands"] = commands
	wiring["command_configuration"] = _configuration()
	_check(_accepted(commands), "unit13 fixture: all exact captured cluster goals publicly accepted with fresh natural orders")
	_check(field.units[12].assigned_destination == Vector3(33, 0, 26.5), "unit13 fixture: actor 13 retains its captured accepted destination")
	_check(field._command_version == 0, "unit13 fixture: per-unit public dispatch does not fabricate original group generation 4")
	_write_artifact("-wiring.json", wiring)
	if wiring_only:
		await _finish_wiring()
		return
	if not _accepted(commands):
		recorder.end_route({"classification": "fixture_command_failure"})
		await _finish_fixture({"classification": "fixture_command_failure"})
		return
	var result := await _observe_cluster(commands)
	recorder.end_route(result)
	await _finish_fixture(result)


func _setup_fixture() -> void:
	field = load("res://scenes/movement_stress.tscn").instantiate() as TestField
	field.set_script(FixtureField) # Outside tree, before any field/unit initialization.
	field.stress_layout = true
	field.stress_unit_count = 50
	field.fixture_units = fixture.units
	recorder = Recorder.new()
	recorder.field = field
	recorder.run_id = run_id
	recorder.source_id = FileAccess.get_sha256("res://scripts/rts_unit.gd")
	recorder.field_generation = 1
	recorder.run_first_frame = run_first_frame
	recorder.route_first_frame = Engine.get_physics_frames()
	recorder.expected_units = 50
	recorder.required_routes.assign(["fixture_wiring" if wiring_only else "unit13_cluster"])
	field.recorder = recorder
	root.add_child(field)
	current_scene = field
	field.camera_rig.edge_scrolling_enabled = false
	for unit in field.units:
		field.selection.select_clicked(unit, true)
	await _frames(5)
	recorder.metadata = _static_configuration(field)
	recorder.metadata["fixture_sha256"] = FileAccess.get_sha256(FIXTURE_PATH)
	recorder.metadata["derived_fixture"] = {"source_event": fixture.source_pose_event_id, "source_frame": fixture.source_absolute_frame,
		"source_command_event": fixture.source_command_event_id, "omitted": "30/gate trajectories and hidden navigation/RVO history",
		"dispatch": "public exact-goal per-unit moves; natural orders and field generation, no private-state replay"}
	_check(field.units.size() == 50 and field._registered.size() == 50, "unit13 fixture: 50 normally registered units")
	_check(NavigationServer3D.map_get_iteration_id(field.get_world_3d().get_navigation_map()) > 0, "unit13 fixture: original navigation map synchronized")
	_check(recorder.metadata.geometry_sha256 == fixture.geometry_sha256, "unit13 fixture: navigation geometry equals canonical captured topology")
	var correct := true
	var clear := true
	var map := field.get_world_3d().get_navigation_map()
	for index in field.units.size():
		var unit := field.units[index]
		var entry: Dictionary = fixture.units[index]
		correct = correct and unit.unit_id == int(entry.id) and unit.owner_id == int(entry.owner_id)
		correct = correct and field.contains_unit(unit) and unit.order_version == 0 and unit.recovery_attempts == 0
		correct = correct and unit.global_position == _point(entry.position) and not unit.moving
		clear = clear and unit.global_position.distance_to(NavigationServer3D.map_get_closest_point(map, unit.global_position)) < 0.05
		for obstacle in field.obstacles:
			clear = clear and not obstacle.grow(RTSUnit.BODY_RADIUS).has_point(Vector2(unit.global_position.x, unit.global_position.z))
	_check(correct, "unit13 fixture: captured IDs/owners/poses enter through normal initialization with zero fresh command history")
	_check(clear and _minimum_separation() > 2 * RTSUnit.BODY_RADIUS, "unit13 fixture: all initial capsules separated and outside solids on navigation")
	var coverage: Dictionary = recorder.coverage_snapshot()
	var watched: bool = coverage.covered_unit_ids.size() == 50 and coverage.commands_without_watch == 0
	for observation in coverage.watched:
		watched = watched and observation.order_version_at_watch == 0
	_check(watched, "unit13 fixture: all 50 watched before any public parking or cluster commands")
	wiring = {"schema_version": 1, "fixture_sha256": FileAccess.get_sha256(FIXTURE_PATH),
		"source_event": fixture.source_pose_event_id, "source_command_event": fixture.source_command_event_id,
		"initial_configuration": _configuration(), "initial_minimum_separation": _minimum_separation()}
	recorder.event_group("derived_fixture_ready", {"fixture": recorder.metadata.derived_fixture}, true)


func _dispatch(goal_key: String) -> Array:
	var commands := []
	for index in field.units.size():
		var unit := field.units[index]
		var goal := _point(fixture.units[index][goal_key])
		var before := unit.order_version
		var accepted := unit.move_to(goal)
		commands.append({"id": unit.unit_id, "accepted": accepted, "before_order": before,
			"after_order": unit.order_version, "requested": _array(goal), "assigned": _array(unit.assigned_destination)})
	recorder.event_group("derived_public_dispatch", {"goal_key": goal_key, "commands": commands,
		"field_generation": field._command_version, "not_original_group_dispatch": true}, true)
	return commands


func _accepted(commands: Array) -> bool:
	var accepted := commands.size() == 50
	for command in commands:
		accepted = accepted and command.accepted and command.after_order == command.before_order + 1 and command.assigned == command.requested
	return accepted


func _finish_wiring() -> void:
	var terminals := {}
	var queries := 0
	for event in recorder.events:
		if event.kind == "terminal_requested" and event.before.get("order_version") == 1:
			terminals[event.before.id] = bool(event.before.moving) and event.details.requested_terminal_state == "ARRIVED"
		if event.kind == "actual_final_path_query":
			queries += 1
	_check(terminals.size() == 50 and not terminals.values().has(false), "unit13 harness: every normal parking arrival recorded before cleanup")
	_check(queries == 100, "unit13 harness: each of 100 public commands captures exactly its actual initial path-query return")
	recorder.end_route({"wiring_only": true, "cluster_physics_steps": 0})
	# The command calls have returned. Free this field synchronously before another
	# physics tick, so the wiring harness cannot spend a hidden mechanism attempt.
	var lifetime: WeakRef = weakref(field.units[12])
	field.free()
	_check(lifetime.get_ref() == null, "unit13 harness: teardown removes actor before any cluster movement tick")
	await _frames(5)
	await _finish_fixture({"classification": "wiring_only", "cluster_physics_steps": 0})


func _observe_cluster(commands: Array) -> Dictionary:
	var previous := PackedVector3Array()
	for unit in field.units:
		previous.append(unit.global_position)
	var finished := false
	var clear := true
	var navigable := true
	var authority := true
	var speed_bounded := true
	var recovery_bounded := true
	var elapsed := 0.0
	var maximum_step := 0.0
	var overlap_pair_seconds := 0.0
	var map := field.get_world_3d().get_navigation_map()
	for frame in range(75 * 60):
		await physics_frame
		elapsed = float(frame + 1) / 60
		var moving := false
		for index in field.units.size():
			var unit := field.units[index]
			moving = moving or unit.moving
			var step := unit.global_position.distance_to(previous[index])
			maximum_step = maxf(maximum_step, step)
			speed_bounded = speed_bounded and step <= unit.movement_speed / 60 + 0.001
			previous[index] = unit.global_position
			authority = authority and unit.order_version == int(commands[index].after_order) and unit.assigned_destination == _point(commands[index].assigned)
			recovery_bounded = recovery_bounded and unit.recovery_attempts <= unit.maximum_recoveries
			for obstacle in field.obstacles:
				clear = clear and not obstacle.grow(0.35).has_point(Vector2(unit.global_position.x, unit.global_position.z))
			if frame % 6 == 0:
				navigable = navigable and unit.global_position.distance_to(NavigationServer3D.map_get_closest_point(map, unit.global_position)) < 0.05
		# Original stress overlap definition, test-only unordered pairs at10Hz.
		if frame % 6 == 0:
			for a in field.units.size():
				for b in range(a + 1, field.units.size()):
					if field.units[a].global_position.distance_to(field.units[b].global_position) < 0.6:
						overlap_pair_seconds += 0.1
		if not moving:
			finished = true
			break
	_check(finished, "unit13 cluster: all units terminate before unchanged 75-second deadline")
	var outcomes := []
	var all_arrived := true
	for unit in field.units:
		var arrived := unit.movement_state == RTSUnit.MovementState.ARRIVED and unit.global_position.distance_to(unit.assigned_destination) <= unit.stopping_distance + 0.01
		all_arrived = all_arrived and arrived
		outcomes.append({"id": unit.unit_id, "state": RTSUnit.MovementState.keys()[unit.movement_state],
			"position": _array(unit.global_position), "assigned": _array(unit.assigned_destination), "arrived": arrived,
			"order": unit.order_version, "elapsed": unit.command_elapsed, "recoveries": unit.recovery_attempts})
		if not arrived:
			print("UNIT13_ROUTE_DETAIL: ", JSON.stringify(outcomes[-1]))
	_check(bool(outcomes[12].arrived), "unit13 cluster: actor 13 actually arrives at its accepted goal within stopping_distance + .01")
	_check(all_arrived, "unit13 cluster: all 50 participants actually arrive within original tolerance")
	_check(authority, "unit13 cluster: all accepted goals and order versions remain authoritative throughout movement")
	_check(clear and navigable, "unit13 cluster: units remain on navigation and outside solid obstacles")
	_check(speed_bounded and recovery_bounded, "unit13 cluster: normal speed and per-command attempt bounds remain intact")
	var settling := await _sample_stationary(field.units, 180)
	var separation := _minimum_separation()
	_check(all_arrived and settling.stable and separation > 0.6, "unit13 cluster: original 180-tick settling and minimum separation > .6")
	var unchanged := true
	for index in field.units.size():
		var unit := field.units[index]
		unchanged = unchanged and unit.order_version == int(outcomes[index].order) and unit.recovery_attempts == int(outcomes[index].recoveries)
		unchanged = unchanged and not unit.recovery_active and unit.assigned_destination == _point(outcomes[index].assigned)
	_check(unchanged, "unit13 cluster: settling does not reactivate recovery or replace any command")
	return {"classification": "derived_cluster_outcome", "all_arrived": all_arrived, "actor13_arrived": outcomes[12].arrived,
		"simulation_seconds": elapsed, "finished": finished, "outcomes": outcomes, "stationary": settling,
		"minimum_settled_distance": separation, "maximum_step": maximum_step,
		"overlap_pair_seconds": overlap_pair_seconds, "overlap_sample_hz": 10,
		"metric_note": "unordered pairs with distance<.6, adding.1 pair-seconds per10Hz sample; not a continuous contact integral"}


func _finish_fixture(result: Dictionary) -> void:
	if is_instance_valid(field):
		field.queue_free()
		await _frames(5)
	_check(root.get_children().is_empty(), "unit13 fixture: teardown removes all field nodes")
	final_coverage = recorder.finish(prefix)
	_check(bool(final_coverage.complete), "unit13 fixture: complete bounded recorder artifact without dropped critical history")
	recorder.close()
	_check(recorder.connections.is_empty(), "unit13 fixture: every capture listener disconnected")
	OS.remove_logger(fixture_logger)
	_check(fixture_logger.error_count() == failures, "unit13 fixture: no additional engine errors or warnings")
	# The authoritative total is printed after the two result-write assertions.
	result["checks_before_result_write"] = checks
	result["failures_before_result_write"] = failures
	result["capture_complete"] = final_coverage.complete
	result["wiring_only"] = wiring_only
	_write_artifact("-result.json", result)
	print("UNIT13_FIXTURE_CHECKS: %d checks, %d failures; wiring_only=%s" % [checks, failures, wiring_only])
	quit(0 if failures == 0 else 1)


func _write_artifact(suffix: String, data: Dictionary) -> void:
	var file := FileAccess.open(prefix + suffix, FileAccess.WRITE)
	_check(file != null, "unit13 fixture: artifact opens " + suffix)
	if file != null:
		file.store_string(JSON.stringify(data))
		file.flush()
		var error := file.get_error()
		file.close()
		_check(error == OK, "unit13 fixture: artifact write succeeds " + suffix)


func _minimum_separation() -> float:
	var minimum := INF
	for a in field.units.size():
		for b in range(a + 1, field.units.size()):
			minimum = minf(minimum, field.units[a].global_position.distance_to(field.units[b].global_position))
	return minimum


static func _point(value: Array) -> Vector3:
	return Vector3(value[0], value[1], value[2])


static func _array(value: Vector3) -> Array:
	return [value.x, value.y, value.z]
