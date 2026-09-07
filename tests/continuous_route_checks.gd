extends "res://tests/unit41_boundary_checks.gd"
## New orchestration; original setup predicates and cluster observation inherited.
const ContinuousField = preload("res://tests/continuous_capture_field.gd")
const RouteRecorder = preload("res://tests/continuous_route_recorder.gd")
const FROZEN_FIXTURE_SHA := "d56be378d165d2c5fbf65e1391e8e9d41f0b5d82c77f648e87db8b93d7c55307"
const PRODUCTION_SHA := "1af671d1fd8da9f65b89a7e95022e0785c94b05885b7d8ed3f79f7fbf17e4da4"
var route_mode := ""
var route_inputs := ""
var capture_failed := false


func _run() -> void:
	_configure_capture()
	root.size = Vector2i(1280, 800)
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--continuous-route-mode="):
			route_mode = argument.trim_prefix("--continuous-route-mode=")
		elif argument.begins_with("--continuous-route-inputs="):
			route_inputs = argument.trim_prefix("--continuous-route-inputs=")
	if route_mode not in ["validate", "observe"] or not FileAccess.file_exists(route_inputs) or not prefix.get_file().begins_with("m501j-"):
		_capture_abort("invalid mode/input/output; no field created")
		return
	var parsed := JSON.new()
	if parsed.parse(FileAccess.get_file_as_string(route_inputs)) != OK or not parsed.data is Dictionary:
		_capture_abort("invalid prepared JSON; no field created")
		return
	var prepared: Dictionary = parsed.data
	if FileAccess.get_sha256(FIXTURE_PATH) != FROZEN_FIXTURE_SHA or FileAccess.get_sha256("res://scripts/rts_unit.gd") != PRODUCTION_SHA:
		_capture_abort("production/fixture identity changed; no field created")
		return
	fixture = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE_PATH))
	if prepared.get("mode") != route_mode or prepared.get("fixture_sha256") != FROZEN_FIXTURE_SHA or prepared.get("production_sha256") != PRODUCTION_SHA or prepared.get("fixture") != fixture:
		_capture_abort("prepared inputs differ from exact frozen source; no field created")
		return
	wiring_only = route_mode == "validate"
	fixture_logger = EngineErrorProbe.new()
	OS.add_logger(fixture_logger)
	_check(fixture.get("units", []).size() == 50, "unit13 fixture: all 50 source participants provided")
	if failures > 0:
		quit(1)
		return
	recorder = RouteRecorder.new()
	recorder.run_id = run_id
	recorder.source_id = PRODUCTION_SHA
	recorder.capture_failed.connect(_capture_abort)
	if not recorder.open_stream(prefix + ".jsonl", "parked_wiring" if wiring_only else "route", FROZEN_FIXTURE_SHA, Engine.get_physics_frames()):
		_capture_abort("capture output unavailable; no field created")
		return
	await _setup_fixture()
	if capture_failed:
		return
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
	if failures > 0 or capture_failed:
		await _finish_fixture({"classification": "fixture_setup_failure"})
		return
	if wiring_only:
		_write_artifact("-wiring.json", wiring)
		await _finish_fixture({"classification": "precluster_validation", "cluster_physics_steps": 0})
		return
	# Preserve the original physics-frame continuation: no idle wait here.
	recorder.start_route("unit13_cluster")
	var commands := _dispatch("goal")
	wiring["cluster_commands"] = commands
	wiring["command_configuration"] = _configuration()
	_check(_accepted(commands), "unit13 fixture: all exact captured cluster goals publicly accepted with fresh natural orders")
	_check(field.units[12].assigned_destination == Vector3(33, 0, 26.5), "unit13 fixture: actor 13 retains its captured accepted destination")
	_check(field._command_version == 0, "unit13 fixture: per-unit public dispatch does not fabricate original group generation 4")
	_write_artifact("-wiring.json", wiring)
	if not _accepted(commands):
		recorder.end_route({"classification": "fixture_command_failure"})
		await _finish_fixture({"classification": "fixture_command_failure"})
		return
	var result := await _observe_cluster(commands)
	recorder.end_route(result)
	await _finish_fixture(result)


func _setup_fixture() -> void:
	field = load("res://scenes/movement_stress.tscn").instantiate() as TestField
	field.set_script(ContinuousField) # Outside tree, before any field/unit initialization.
	field.stress_layout = true
	field.stress_unit_count = 50
	field.fixture_units = fixture.units
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
	_check(recorder.begin_continuous(), "continuous route: immutable all50 observation begins before first physics")
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


func _observe_cluster(commands: Array) -> Dictionary:
	# Calls unchanged unit41 assertion and the entire original unit13 observer.
	var result := await super._observe_cluster(commands)
	var summary: Dictionary = recorder.call_summary()
	var observed: bool = int(summary.incomplete_calls) == 0
	for count in summary.calls_by_unit.values():
		observed = observed and int(count) > 0
	_check(summary.actual_excesses == 0, "projection fixture: every actual movement delegate stays within unchanged speed times delta plus .001")
	_check(observed, "continuous route: every participant actual movement call has a completed returned observation")
	result["actual_call_summary"] = summary
	return result


func _finish_fixture(result: Dictionary) -> void:
	# Drain the final tick only at teardown, never before original cluster dispatch.
	await process_frame
	if is_instance_valid(field):
		field.free()
		field = null
		current_scene = null
	_check(root.get_children().is_empty(), "unit13 fixture: teardown removes all field nodes")
	_check(recorder.connections.is_empty(), "unit13 fixture: every capture listener disconnected")
	_check(fixture_logger.error_count() == failures, "unit13 fixture: no additional engine errors or warnings")
	recorder.gameplay_receipt = {"checks": checks, "failures": failures,
		"scope": "all gameplay/teardown assertions already executed; final capture/result-write checks in native log"}
	final_coverage = recorder.finish_stream(wiring_only, result.has("outcomes"))
	_check(bool(final_coverage.complete), "continuous route: complete continuous capture with no dropped frame or participant")
	OS.remove_logger(fixture_logger)
	result["mode"] = route_mode
	result["checks"] = checks
	result["failures"] = failures
	result["checks_before_result_write"] = checks
	result["failures_before_result_write"] = failures
	result["capture_complete"] = final_coverage.complete
	result["footer"] = final_coverage
	result["cluster_commands"] = recorder.cluster_commands
	result["live_field"] = false
	result["wiring_only"] = wiring_only
	_write_artifact("-result.json", result)
	print("CONTINUOUS_ROUTE_CHECKS: %d checks, %d failures; mode=%s" % [checks, failures, route_mode])
	quit(2 if capture_failed or not bool(final_coverage.complete) else (0 if failures == 0 else 1))


func _capture_abort(message: String) -> void:
	capture_failed = true
	push_error("CONTINUOUS_ROUTE_INCOMPLETE: " + message)
	quit(2)


func _finalize() -> void:
	if is_instance_valid(field):
		field.free()
		field = null
	if recorder != null and not recorder.stream_finished:
		recorder.finish_stream(false, false)
