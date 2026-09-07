extends "res://tests/movement_stress_checks.gd"
## Explicit diagnostic entry point; unchanged inherited full suite/route or
## cluster-only replay from a real, completely arrived pre-command checkpoint.
const History = preload("res://tests/cluster_diagnostic_history.gd")
var prefix := "res://validation-output/cluster-diagnostic"
var replay_path := ""

class ReplayField extends TestField:
	var checkpoint: Dictionary
	func _create_unit(index: int) -> RTSUnit:
		var unit := super._create_unit(index)
		var entry: Dictionary = checkpoint.units[index]
		# Initial fixture placement before entering the tree, never a movement fix.
		unit.position = Vector3(entry.position[0], entry.position[1], entry.position[2])
		unit.order_version = int(entry.order_version)
		return unit


func _run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--diagnostic-prefix="):
			prefix = argument.trim_prefix("--diagnostic-prefix=")
		if argument.begins_with("--cluster-replay="):
			replay_path = argument.trim_prefix("--cluster-replay=")
	DirAccess.make_dir_recursive_absolute(prefix.get_base_dir())
	if replay_path.is_empty():
		await super._run()
		return
	root.size = Vector2i(1280, 800)
	var report: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(replay_path))
	var checkpoint: Dictionary = report.initial
	var valid: bool = checkpoint.units.size() == 50
	for entry in checkpoint.units:
		valid = valid and entry.state == "ARRIVED" and not entry.moving and entry.member
	_check(valid, "replay fixture has all 50 real, arrived gate participants")
	if not valid:
		quit(1)
		return
	var replay := ReplayField.new()
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
	_check(NavigationServer3D.map_get_iteration_id(field.get_world_3d().get_navigation_map()) > 0, "replay navigation synchronized")
	await _route("cluster_50", Vector3(30, 0, 22), 75.0)
	var matching := field.last_command_result.generation == int(report.command.generation)
	for unit in field.units:
		var expected: Array = report.command.assignments[str(unit.unit_id)]
		matching = matching and field.last_command_result.assignments[unit.unit_id] == Vector3(expected[0], expected[1], expected[2])
	_check(matching, "isolated route preserves captured full-sequence unit-to-slot mapping and group generation")
	print("CLUSTER_DIAGNOSTIC_CHECKS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _route(label: String, target: Vector3, timeout: float, gate: bool = false) -> Dictionary:
	var observer := History.new()
	root.add_child(observer)
	observer.begin(field)
	var before := failures
	var metrics := await super._route(label, target, timeout, gate)
	observer.finish(failures > before, metrics, prefix + "-" + label)
	observer.free()
	if failures > before and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var captured := root.get_texture().get_image().save_png(prefix + "-" + label + "-failure.png")
		print("DIAGNOSTIC_CAPTURE: ", captured)
	return metrics
