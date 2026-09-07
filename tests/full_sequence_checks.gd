extends "res://tests/movement_stress_checks.gd"
## Inherits the complete original _run, assignment checks, routes and assertions.
## Only field construction and route-boundary observation are extended.
const RecordedField = preload("res://tests/full_sequence_field.gd")
const Recorder = preload("res://tests/full_sequence_recorder.gd")
var recorder: RefCounted
var prefix := "res://validation-output/full-sequence"
var run_id := "full-sequence"
var run_first_frame := 0
var field_generation := 0
var final_coverage: Dictionary = {}


func _run() -> void:
	_configure_capture()
	await super._run()
	if recorder != null and recorder.live and final_coverage.is_empty():
		_finalize_capture("original runner returned before full capture boundary")
	# quit() requested by the original runner; synchronous final record only.
	print("FULL_SEQUENCE_COVERAGE: ", JSON.stringify(final_coverage))


func _finalize() -> void:
	# Also retain partial evidence if the inherited wall watchdog requested quit.
	# No quit override here: the original exit code and deadline remain authoritative.
	if recorder != null and recorder.live and final_coverage.is_empty():
		_finalize_capture("main loop finalized before full capture boundary")


func _finalize_capture(reason: String) -> void:
	recorder.event_group("incomplete_runner_boundary", {"reason": reason}, true)
	final_coverage = recorder.finish(prefix)
	recorder.close()


func _configure_capture() -> void:
	run_first_frame = Engine.get_physics_frames()
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--diagnostic-prefix="):
			prefix = argument.trim_prefix("--diagnostic-prefix=")
		if argument.begins_with("--capture-run-id="):
			run_id = argument.trim_prefix("--capture-run-id=")
	DirAccess.make_dir_recursive_absolute(prefix.get_base_dir())


func _fresh(count: int, crowd: bool = true) -> void:
	# Keep original field lifetime, scene, count, selection, readiness wait and
	# assertion. Only the fresh 50-agent avoidance-enabled field is instrumented.
	if is_instance_valid(field):
		field.queue_free()
		await _frames(3)
	field_generation += 1
	field = load("res://scenes/movement_stress.tscn").instantiate() as TestField
	if count == 50 and crowd:
		var scene_stress_layout := field.stress_layout
		var scene_debug := field.movement_debug
		field.set_script(RecordedField) # Before tree entry or any unit initialization.
		field.stress_layout = scene_stress_layout
		field.movement_debug = scene_debug
		recorder = Recorder.new()
		recorder.field = field
		recorder.run_id = run_id
		recorder.source_id = FileAccess.get_sha256("res://scripts/rts_unit.gd")
		recorder.field_generation = field_generation
		recorder.run_first_frame = run_first_frame
		recorder.route_first_frame = Engine.get_physics_frames()
		recorder.expected_units = 50
		recorder.required_routes.assign(["choke_50", "cluster_50"])
		field.recorder = recorder
	field.stress_unit_count = count
	root.add_child(field)
	current_scene = field
	field.camera_rig.edge_scrolling_enabled = false
	for unit in field.units:
		unit.crowd_enabled = crowd
		field.selection.select_clicked(unit, true)
	await _frames(5)
	_check(NavigationServer3D.map_get_iteration_id(field.get_world_3d().get_navigation_map()) > 0, "%d-unit navigation ready" % count)
	if count == 50 and crowd:
		recorder.metadata = _static_configuration(field)
		recorder.event_group("setup_ready", {"selected_ids": _ids(field.selection.selected_units())}, true)


func _route(label: String, target: Vector3, timeout: float, gate: bool = false) -> Dictionary:
	if label not in ["choke_50", "cluster_50"]:
		return await super._route(label, target, timeout, gate)
	recorder.start_route(label)
	var before_failures := failures
	var metrics := await super._route(label, target, timeout, gate)
	recorder.end_route({"metrics": metrics, "assertion_failures": failures - before_failures,
		"original_deadline": timeout, "gate": gate})
	if label == "choke_50":
		# Deliberate partial checkpoint; the final receipt still requires cluster.
		recorder.finish(prefix + "-after-gate")
	if label == "cluster_50":
		final_coverage = recorder.finish(prefix)
		_check(bool(final_coverage.get("complete", false)), "full sequence: complete all-unit setup/gate/cluster capture without dropped critical events")
		recorder.close()
		_check(recorder.connections.is_empty(), "full sequence: recorder listeners disconnected before original synthetic recovery checks")
	return metrics


func _ids(units: Array[RTSUnit]) -> Array:
	var result := []
	for unit in units:
		result.append(unit.unit_id)
	return result


func _static_configuration(source: TestField) -> Dictionary:
	# One boundary snapshot, never called from movement callbacks. No extra path
	# or physics-space queries. Include exact topology for offline reconstruction.
	var mesh := source.navigation_region.navigation_mesh
	var vertices := []
	var polygons := []
	for point in mesh.get_vertices():
		vertices.append([point.x, point.y, point.z])
	for index in mesh.get_polygon_count():
		polygons.append(Array(mesh.get_polygon(index)))
	var geometry := {"vertices": vertices, "polygons": polygons}
	var obstacles := []
	for obstacle in source.obstacles:
		obstacles.append([obstacle.position.x, obstacle.position.y, obstacle.size.x, obstacle.size.y])
	return {"engine": Engine.get_version_info(), "display": DisplayServer.get_name(),
		"renderer": RenderingServer.get_current_rendering_method(), "physics_ticks": Engine.physics_ticks_per_second,
		"physics_engine_setting": ProjectSettings.get_setting("physics/3d/physics_engine"),
		"max_physics_steps": Engine.max_physics_steps_per_frame, "physics_jitter_fix": Engine.physics_jitter_fix,
		"time_scale": Engine.time_scale, "geometry": geometry, "geometry_sha256": JSON.stringify(geometry).sha256_text(),
		"obstacles": obstacles, "map_iteration": NavigationServer3D.map_get_iteration_id(source.get_world_3d().get_navigation_map()),
		"region_iteration": NavigationServer3D.region_get_iteration_id(source.navigation_region.get_rid()),
		"test_source_sha256": FileAccess.get_sha256("res://tests/movement_stress_checks.gd"),
		"project_sha256": FileAccess.get_sha256("res://project.godot"),
		"arguments_note": "Use external invocation manifest for complete engine-handled flags."}
