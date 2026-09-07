extends "res://tests/milestone_checks.gd"
## Synthesized accounting experiment, NOT an original Issue B replay or acceptance.
const BudgetProbe = preload("res://tests/recovery_budget_probe.gd")
const History = preload("res://tests/issue_b_diagnostic_history.gd")
const START := Vector3(31.41587, 0, 19.78682)
const GOAL := Vector3(33, 0, 22)
var actor: RTSUnit
var neighbors: Array[RTSUnit] = []
var parking_events: Array = []
var observer: Node
var output_prefix := "res://validation-output/recovery-budget"
var release_control := false

class EmptyStressField extends TestField:
	func _unit_count() -> int:
		return 0


func _run() -> void:
	root.size = Vector2i(1280, 800)
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--diagnostic-prefix="):
			output_prefix = argument.trim_prefix("--diagnostic-prefix=")
		if argument == "--release-control":
			release_control = true
	DirAccess.make_dir_recursive_absolute(output_prefix.get_base_dir())
	var logger := EngineErrorProbe.new()
	OS.add_logger(logger)
	field = EmptyStressField.new()
	field.stress_layout = true
	root.add_child(field)
	current_scene = field
	field.camera_rig.edge_scrolling_enabled = false
	actor = _add(4, START, true)
	var forward := (GOAL - START).normalized()
	for index in 10:
		neighbors.append(_add(10 + index, START + forward.rotated(Vector3.UP, deg_to_rad(9 + index * 36)) * 1.4))
	for index in 39:
		_add(100 + index, Vector3(-30 + (index % 7) * 2, 0, 6 + (index / 7) * 2))
	await _frames(5)
	var separated := true
	var valid_positions := true
	var map := field.get_world_3d().get_navigation_map()
	for unit in field.units:
		valid_positions = valid_positions and NavigationServer3D.map_get_closest_point(map, unit.global_position).distance_to(unit.global_position) < 0.02
		for other in field.units:
			if unit != other:
				separated = separated and unit.global_position.distance_to(other.global_position) > RTSUnit.BODY_RADIUS * 2
	_check(separated and valid_positions and field._registered.size() == 50, "budget setup: 50 legal, separated, normally registered units on original mesh")
	observer = History.new()
	root.add_child(observer)
	observer.set_physics_process(false)
	# Reuse existing record/inspect/probe helpers, without their continuous capture.
	observer.field = field
	observer.members = field.units.duplicate()
	observer.first_frame = Engine.get_physics_frames()
	observer.supports_suspension = true
	for property in actor.get_property_list():
		observer.supports_waypoint_counter = observer.supports_waypoint_counter or property.name == "_recovery_waypoints"
	actor.recorder = observer
	for unit in field.units:
		unit.movement_state_changed.connect(_park_transition.bind(unit))
		if unit != actor:
			_check(unit.move_to(unit.global_position), "budget setup: public parking accepted for %d" % unit.unit_id)
	await _frames(3)
	var parked := true
	for unit in field.units:
		if unit != actor:
			parked = parked and unit.movement_state == RTSUnit.MovementState.ARRIVED and not unit.moving
	_check(parked, "budget setup: peers parked through normal arrival")
	var initial: Dictionary = observer.inspect()
	var version := actor.order_version
	_check(actor.move_to(GOAL), "budget setup: actor public command accepted")
	var released := false
	var maximum_step := 0.0
	var previous := actor.global_position
	for frame in 75 * 60:
		await physics_frame
		maximum_step = maxf(maximum_step, previous.distance_to(actor.global_position))
		previous = actor.global_position
		if release_control and not released and actor.recovery_attempts >= 1:
			released = true
			var destination := START + forward.rotated(Vector3.UP, deg_to_rad(9)) * 4
			_check(neighbors[0].move_to(destination), "budget control: ordinary neighbor departure accepted after first admission")
		if not actor.moving:
			break
	var arrived := actor.movement_state == RTSUnit.MovementState.ARRIVED and actor.global_position.distance_to(GOAL) <= actor.stopping_distance + 0.01
	var admissions := 0
	var fallbacks := 0
	var expiries := 0
	var unit_deltas := true
	var cooldowns := true
	var last_admission := -INF
	for item in actor.audit_events:
		if item.kind == "recovery_admission":
			admissions += 1
			fallbacks += 1 if item.details.actual_final_fallback else 0
			unit_deltas = unit_deltas and item.after.recoveries == item.before.recoveries + 1
			cooldowns = cooldowns and item.after.elapsed - last_admission >= actor.recovery_interval
			last_admission = item.after.elapsed
		if item.kind == "recovery_clear" and item.details.source_attributed_reason == "duration_expiry":
			expiries += 1
	_check(actor.order_version == version + 1 and actor.assigned_destination == GOAL, "budget: unchanged actor order and accepted destination")
	_check(unit_deltas and cooldowns and admissions == actor.recovery_attempts, "budget: exact single-charge events and unchanged cooldown")
	_check(maximum_step <= actor.movement_speed / 60 + 0.001, "budget: physical displacement remains speed bounded")
	_check(not actor.audit_truncated, "budget: event capture remains complete")
	if release_control:
		_check(released and arrived and actor.recovery_attempts >= 1, "budget control: neighbor departure permits actual arrival without refunding attempts")
	else:
		_check(not arrived and actor.movement_state == RTSUnit.MovementState.FAILED and actor.recovery_attempts == actor.maximum_recoveries and actor.command_elapsed < actor.command_timeout, "budget hold: ordinary cap failure precedes command deadline")
		_check(fallbacks == admissions and expiries == admissions, "budget hold hypothesis: every admission falls back and expires")
	var stationary := await _sample_stationary([actor], 180)
	# The shared helper's stable flag also requires ARRIVED. A negative enclosure
	# deliberately ends FAILED; check its displacement/velocity/state explicitly.
	var terminal_stable: bool = stationary.stable if release_control else actor.movement_state == RTSUnit.MovementState.FAILED and actor.velocity.is_zero_approx() and not actor.moving
	_check(terminal_stable and stationary.max_displacement < 0.001, "budget: expected terminal state remains stationary for 180 physics ticks")
	var metrics := {"synthesized": true, "release_control": release_control, "arrived": arrived,
		"admissions": admissions, "fallbacks": fallbacks, "expiries": expiries,
		"attempts": actor.recovery_attempts, "elapsed": actor.command_elapsed,
		"maximum_step": maximum_step, "stationary_displacement": stationary.max_displacement}
	var result := {"initial": initial, "final": observer.inspect(), "metrics": metrics,
		"actor_events": actor.audit_events, "parking_events": parking_events, "capture_truncated": actor.audit_truncated,
		"limitations": "Synthesized closure, not historical B. All registered peers captured at events; no hidden RVO neighbor list. Candidate reasons recomputed, actual production path query return captured without added query. Callback request is latest visible request, not an engine submission serial. Instrumentation may perturb timing."}
	var file := FileAccess.open(output_prefix + "-events.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(result))
	file.close()
	for unit in field.units:
		unit.movement_state_changed.disconnect(_park_transition.bind(unit))
	actor.recorder = null
	observer.free()
	field.queue_free()
	await _frames(5)
	_check(root.get_children().is_empty(), "budget: teardown removes units, field, and signals")
	OS.remove_logger(logger)
	_check(logger.error_count() == failures, "budget: no additional native errors or warnings")
	print("BUDGET_DETAIL: ", JSON.stringify(metrics))
	print("RECOVERY_BUDGET_CHECKS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _park_transition(state: int, unit: RTSUnit) -> void:
	parking_events.append({"absolute_frame": Engine.get_physics_frames(), "state": RTSUnit.MovementState.keys()[state], "unit": observer.record(unit)})


func _add(identity: int, point: Vector3, probe: bool = false) -> RTSUnit:
	var unit: RTSUnit = BudgetProbe.new() if probe else RTSUnit.new()
	unit.unit_id = identity
	unit.position = point # Initial scene placement only; never repositioned afterward.
	field.add_child(unit)
	field.register_unit(unit)
	return unit
