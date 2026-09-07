extends "res://tests/movement_stress_checks.gd"
## Derived current gate regression: unchanged fresh50 setup and gate command.
## Omits preceding30-unit routes. Disabled mode is the original no-crowd control.
const GateField = preload("res://tests/gate_movement_field.gd")
const Recorder = preload("res://tests/full_sequence_recorder.gd")
var recorder: RefCounted
var prefix := "res://validation-output/m5-gate-repair/focused"
var wiring_only := false
var enabled := false
var query_only := false
var observed_ids: Array[int] = [20]


func _run() -> void:
	root.size = Vector2i(1280, 800)
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--diagnostic-prefix="):
			prefix = argument.trim_prefix("--diagnostic-prefix=")
		elif argument == "--wiring-only":
			wiring_only = true
		elif argument == "--avoidance":
			enabled = true
		elif argument == "--observe23":
			observed_ids.assign([20, 23])
		elif argument == "--query-only":
			query_only = true
			wiring_only = true
	DirAccess.make_dir_recursive_absolute(prefix.get_base_dir())
	var logger := EngineErrorProbe.new()
	OS.add_logger(logger)
	await _fresh(50, enabled)
	_check(field.units.size() == 50 and field._registered.size() == 50, "gate: all50 normal participants registered")
	var actor: RTSUnit = field.units[19]
	_check(actor.unit_id == 20 and actor.order_version == 0 and actor.movement_calls == 0 and recorder.coverage_snapshot().covered_ids == observed_ids, "gate: selected observers installed before any command or movement")
	if query_only:
		_query_recorded_input(actor)
	if not wiring_only:
		if enabled:
			_assignment_checks(50) # Preserve original enabled50 public-command setup.
		recorder.start_route("gate")
		var result := await _route("current_gate_50", Vector3(10, 0, 0), 75.0 if enabled else 45.0, true)
		_check(actor.excessive_steps == 0, "gate: every observed actual movement call stays within unchanged speed bound")
		result["observed_actor"] = {"id": actor.unit_id, "calls": actor.movement_calls,
			"max_step": actor.maximum_step, "blocked_calls": actor.blocked_calls, "diagnostics": actor.diagnostic_count,
			"cell_checks": actor.cell_checks, "cell_acceptances": actor.cell_acceptances}
		recorder.end_route(result)
		print("GATE_DETAIL: ", JSON.stringify(result))
	await process_frame
	var coverage: Dictionary = recorder.finish(prefix)
	_check(coverage.complete, "gate: existing recorder writes complete bounded actor capture")
	recorder.close()
	field.queue_free()
	await _frames(5)
	_check(root.get_children().is_empty(), "gate: teardown clears field and recorder listeners")
	OS.remove_logger(logger)
	_check(logger.error_count() == failures, "gate: no additional engine errors or warnings")
	print("GATE_MOVEMENT_CHECKS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _query_recorded_input(actor: RTSUnit) -> void:
	# Numeric input from this task's actual frame280 call, never actor placement.
	var start := Vector3(-2.84999990463257, 0, 1.03365671634674)
	var proposed := Vector3(-2.76667547225952, 0, 1.03243374824524)
	var map := actor.agent.get_navigation_map()
	var projected := NavigationServer3D.map_get_closest_point(map, proposed)
	var corner := Vector3(-2.84999990463257, 0, 0.949999928474426)
	_check(actor._navigation_cell_contains_segment(start, start.move_toward(corner, 5.0 / 60)), "gate geometry: entire bounded boundary leg belongs to one existing cell")
	_check(not actor._navigation_cell_contains_segment(start, start.move_toward(projected, 5.0 / 60)), "gate geometry: diagonal shortcut across clearance corner is rejected")
	_check(not actor._navigation_cell_contains_segment(Vector3(-3, 0, 2), Vector3(3, 0, 2)), "gate geometry: separated legal endpoints cannot bridge the obstacle hole")
	_check(not actor._navigation_cell_contains_segment(start + Vector3.UP, corner), "gate geometry: an off-surface start is rejected")
	var records := []
	for end in [projected, Vector3(-2.84999990463257, 0, 0.949999928474426)]:
		for optimize in [true, false]:
			var path := NavigationServer3D.map_get_path(map, start, end, optimize)
			var points := []
			for point in path:
				points.append(Recorder._vector(point))
			records.append({"optimize": optimize, "end": Recorder._vector(end), "path": points})
	var result := {"provenance": "additional native queries using recorded numeric inputs, no live actor movement", "start": Recorder._vector(start), "queries": records}
	var output := FileAccess.open(prefix + "-queries.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(result))
	output.close()
	_check(actor.movement_calls == 0 and actor.order_version == 0, "gate queries: diagnostic inputs never move or command the live actor")
	print("GATE_QUERIES: ", JSON.stringify(result))


func _fresh(count: int, crowd: bool = true) -> void:
	field = load("res://scenes/movement_stress.tscn").instantiate() as TestField
	field.set_script(GateField)
	field.stress_layout = true
	field.stress_unit_count = count
	field.observed_ids.assign(observed_ids)
	recorder = Recorder.new()
	recorder.field = field
	recorder.run_id = prefix.get_file()
	recorder.source_id = FileAccess.get_sha256("res://scripts/rts_unit.gd")
	recorder.run_first_frame = Engine.get_physics_frames()
	recorder.metadata = {"case": "current_gate_50", "avoidance": crowd, "observed_ids": observed_ids,
		"simplification": "original fresh50 arrangement and public gate command; selected IDs recorded; preceding30 routes omitted",
		"fixture_sha256": FileAccess.get_sha256("res://tests/gate_movement_checks.gd"),
		"probe_sha256": FileAccess.get_sha256("res://tests/gate_movement_probe.gd")}
	if not wiring_only:
		recorder.required_routes.assign(["gate"])
	field.recorder = recorder
	root.add_child(field)
	current_scene = field
	field.camera_rig.edge_scrolling_enabled = false
	for unit in field.units:
		unit.crowd_enabled = crowd
		field.selection.select_clicked(unit, true)
	await _frames(5)
	_check(NavigationServer3D.map_get_iteration_id(field.get_world_3d().get_navigation_map()) > 0, "gate: original mesh synchronized")
