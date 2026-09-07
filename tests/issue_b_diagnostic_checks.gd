extends "res://tests/movement_stress_checks.gd"
## Issue B only: preserve original full sequence, or explicitly replay a later
## matching unit-4/goal checkpoint. Original acceptance assertions are inherited.
const IssueBHistory = preload("res://tests/issue_b_diagnostic_history.gd")
const Replay = preload("res://tests/cluster_diagnostic_checks.gd")
var prefix := "res://validation-output/issue-b"
var checkpoint_path := ""


func _run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--diagnostic-prefix="):
			prefix = argument.trim_prefix("--diagnostic-prefix=")
		if argument.begins_with("--issue-b-checkpoint="):
			checkpoint_path = argument.trim_prefix("--issue-b-checkpoint=")
	DirAccess.make_dir_recursive_absolute(prefix.get_base_dir())
	if checkpoint_path.is_empty():
		await super._run()
		return
	root.size = Vector2i(1280, 800)
	var report: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(checkpoint_path))
	var checkpoint: Dictionary = report.initial
	var valid: bool = checkpoint.units.size() == 50
	for entry in checkpoint.units:
		valid = valid and entry.state == "ARRIVED" and not entry.moving and entry.member
	_check(valid, "Issue B checkpoint retains 50 genuinely arrived gate participants")
	if not valid:
		quit(1)
		return
	var replay := Replay.ReplayField.new()
	replay.stress_layout = true
	replay.stress_unit_count = 50
	replay.checkpoint = checkpoint
	field = replay
	root.add_child(field)
	current_scene = field
	field.camera_rig.edge_scrolling_enabled = false
	field._command_version = int(checkpoint.group_generation)
	field._next_command_generation = int(checkpoint.next_generation)
	for index in field.units.size():
		var unit := field.units[index]
		var entry: Dictionary = checkpoint.units[index]
		unit.agent.radius = entry.radius
		unit.assigned_destination = Vector3(entry.assigned[0], entry.assigned[1], entry.assigned[2])
		unit.agent.target_position = unit.assigned_destination
		field.selection.select_clicked(unit, true)
	await _frames(5)
	_check(NavigationServer3D.map_get_iteration_id(field.get_world_3d().get_navigation_map()) > 0, "Issue B checkpoint navigation synchronized")
	await _route("cluster_50", Vector3(30, 0, 22), 75.0)
	var matching := field.last_command_result.generation == int(report.command.generation)
	for unit in field.units:
		var expected: Array = report.command.assignments[str(unit.unit_id)]
		matching = matching and field.last_command_result.assignments[unit.unit_id] == Vector3(expected[0], expected[1], expected[2])
	_check(matching and field.last_command_result.assignments[4] == IssueBHistory.HISTORICAL_GOAL, "later checkpoint retains captured assignments, including unit 4 at historical goal")
	print("ISSUE_B_CHECKS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _route(label: String, target: Vector3, timeout: float, gate: bool = false) -> Dictionary:
	if label != "cluster_50":
		return await super._route(label, target, timeout, gate)
	var observer := IssueBHistory.new()
	root.add_child(observer)
	observer.begin(field)
	var before := failures
	var metrics := await super._route(label, target, timeout, gate)
	observer.finish(failures > before, metrics, prefix)
	_check(not observer.history_truncated and not observer.command.is_empty() and not observer.focused_frames.is_empty() and observer.connections.is_empty(), "Issue B trace retains complete command/trajectory and disconnects listeners")
	observer.free()
	return metrics
