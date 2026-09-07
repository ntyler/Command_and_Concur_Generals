extends "res://tests/unit13_fixture_checks.gd"
## Inherit every original acceptance predicate including speed and settling.
const StepField = preload("res://tests/projection_step_field.gd")


func _setup_fixture() -> void:
	field = load("res://scenes/movement_stress.tscn").instantiate() as TestField
	field.set_script(StepField) # Outside tree, before any field/unit initialization.
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


func _finish_wiring() -> void:
	var installed := true
	for unit in field.units:
		installed = installed and unit.get_script() == StepField.StepProbe and unit.step_delegate_calls == 0
	_check(installed, "step harness: all50 observers installed before movement, no movement calls during parked setup")
	# E historical unit9 motion32059; read-only QUERY INPUTS, never actor state.
	var start := Vector3(22.1499996185303, 0, 18.7353382110596)
	var input := Vector3(3.58084917068481, 0, 3.48962998390198)
	var before := _configuration()
	var diagnostic: Dictionary = field.units[8].step_diagnostic(start, input, 1.0 / 60)
	_check(_configuration() == before, "step harness: captured-input native diagnostic queries do not move or alter any live actor")
	_check(_point(diagnostic.projected).distance_to(Vector3(22.209680557251, 0, 18.8499984741211)) < 0.00001, "step harness: additional native projection matches retained E endpoint")
	_check(diagnostic.path.size() >= 3 and _point(diagnostic.path[0]).distance_to(start) < 0.00001, "step harness: actual diagnostic path preserves start and exposes corner bend")
	_check(diagnostic.bounded_first_endpoint != null and _point(diagnostic.bounded_first_endpoint).distance_to(start) <= input.length() / 60 + 0.00001 and diagnostic.bounded_first_endpoint_on_navigation < 0.00001, "step harness: bounded first segment ends on synchronized navigation")
	_write_artifact("-query-harness.json", {"reference_capture": "m501e-historical-mechanism-headless-1", "reference_motion_id": 32059,
		"reference_capture_sha256": "6a4c4a8e0a8c8019c1cca3624fd040a11266facaca0f9e47a56dd68bc9774ffc",
		"reference_start": _array(start), "reference_input": _array(input), "diagnostic": diagnostic,
		"qualification": "read-only native queries on old captured numeric inputs, no live actor placement or movement"})
	await super._finish_wiring()


func _observe_cluster(commands: Array) -> Dictionary:
	var result := await super._observe_cluster(commands)
	var actor: Dictionary = result.outcomes[40]
	var exact := _point(actor.assigned) == Vector3(28.5, 0, 17.5) and int(actor.order) == 2
	_check(exact and bool(actor.arrived), "projection fixture: unit41 actually arrives at its exact accepted goal on natural order2")
	result["unit41_arrived"] = exact and bool(actor.arrived)
	var stats := []
	var bounded := true
	var coverage := true
	for unit in field.units:
		var summary: Dictionary = unit.step_summary()
		stats.append(summary)
		bounded = bounded and summary.actual_excess_count == 0
		coverage = coverage and summary.movement_calls > 0 and summary.diagnostic_queries == summary.movement_calls
	_check(bounded, "projection fixture: every actual movement delegate stays within unchanged speed times delta plus .001")
	_check(coverage, "projection fixture: every participant actual movement call has a completed diagnostic observation")
	result["step_observer"] = {"units": stats, "all_calls_bounded": bounded, "all_calls_observed": coverage}
	return result
