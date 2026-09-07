extends "res://tests/milestone_checks.gd"
## Controlled reconstruction of M501 pair 7 baseline, not hidden-engine replay.
## All initial bodies are separated. Public move orders park the two neighbors
## under the ordinary arrival threshold; no private movement state is fabricated.
const History = preload("res://tests/cluster_diagnostic_history.gd")
const GOAL := Vector3(30, 0, 17.5)
const START := Vector3(33.4688262939453, 0, 18.1151809692383) # Unit 12 at event frame 609.
const PARKED := [Vector3(31.4158058166504, 0, 17.6870384216309), Vector3(31.376335144043, 0, 18.8210067749023)]
const PARKED_GOALS := [Vector3(31.5, 0, 17.5), Vector3(31.5, 0, 19)]
var mover: RTSUnit
var neighbors: Array[RTSUnit] = []
var output_prefix := "res://validation-output/parked-deadlock"

class ReducedField extends TestField:
	func _unit_count() -> int:
		return 0


func _run() -> void:
	root.size = Vector2i(1280, 800)
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--diagnostic-prefix="):
			output_prefix = argument.trim_prefix("--diagnostic-prefix=")
	DirAccess.make_dir_recursive_absolute(output_prefix.get_base_dir())
	var logger := EngineErrorProbe.new()
	OS.add_logger(logger)
	await _setup()
	var observer := History.new()
	root.add_child(observer)
	observer.begin(field)
	var before_version := mover.order_version
	var accepted := mover.move_to(GOAL)
	var captured := mover.assigned_destination
	_check(accepted and captured == GOAL and mover.order_version == before_version + 1, "focused: fresh explicit movement acceptance at captured destination")
	var collided := false
	var maximum_step := 0.0
	var detours := []
	var last_target := Vector3.INF
	var last_detour_attempt := 0
	var bounded_recovery := true
	var previous_recovery_elapsed := 0.0
	var previous_attempt := 0
	var has_waypoint_counter := false
	for property in mover.get_property_list():
		has_waypoint_counter = has_waypoint_counter or property.name == "_recovery_waypoints"
	var previous := mover.global_position
	for frame in range(75 * 60):
		await physics_frame
		collided = collided or mover.get_slide_collision_count() > 0
		maximum_step = maxf(maximum_step, mover.global_position.distance_to(previous))
		previous = mover.global_position
		if mover.recovery_active:
			if mover.recovery_attempts == previous_attempt:
				bounded_recovery = bounded_recovery and mover._recovery_elapsed >= previous_recovery_elapsed
			previous_attempt = mover.recovery_attempts
			previous_recovery_elapsed = mover._recovery_elapsed
			bounded_recovery = bounded_recovery and mover._recovery_elapsed <= mover.recovery_duration + 1.0 / 60
			if has_waypoint_counter:
				bounded_recovery = bounded_recovery and int(mover.get("_recovery_waypoints")) <= 2
			if last_target != mover.recovery_target or last_detour_attempt != mover.recovery_attempts:
				last_target = mover.recovery_target
				last_detour_attempt = mover.recovery_attempts
				detours.append({"attempt": mover.recovery_attempts, "elapsed": mover.command_elapsed,
					"attempt_elapsed": mover._recovery_elapsed, "waypoint": History.vector(last_target)})
		if not mover.moving:
			break
	var arrived := mover.movement_state == RTSUnit.MovementState.ARRIVED and mover.global_position.distance_to(captured) <= mover.stopping_distance + 0.01
	_check(arrived, "focused: actual arrival at originally accepted destination")
	_check(mover.order_version == before_version + 1 and mover.assigned_destination == captured, "focused: recovery preserves command authority and assignment")
	_check(maximum_step <= mover.movement_speed / 60 + 0.001, "focused: movement remains speed bounded")
	_check(bounded_recovery and mover.recovery_attempts <= mover.maximum_recoveries, "focused: continuation never resets recovery duration or attempt bounds")
	var stationary := await _sample_stationary([mover], 180)
	_check(not arrived or stationary.stable, "focused: successful arrival stays settled for all 180 physics ticks")
	var parked_unchanged := true
	for index in neighbors.size():
		parked_unchanged = parked_unchanged and neighbors[index].global_position.distance_to(PARKED[index]) < 0.001 and not neighbors[index].moving
	_check(parked_unchanged, "focused: parked neighbors remain stationary")
	var metrics := {"arrived": arrived, "elapsed": mover.command_elapsed, "recoveries": mover.recovery_attempts,
		"captured_assignment": History.vector(captured), "collision_contacts": collided,
		"stationary_displacement": stationary.max_displacement, "maximum_step": maximum_step, "detours": detours}
	observer.finish(not arrived, metrics, output_prefix)
	observer.free()
	print("PARKED_DETAIL: ", JSON.stringify(metrics), " position=", mover.global_position)
	field.queue_free()
	await _frames(5)
	_check(root.get_children().is_empty(), "focused: teardown removes field and observer")
	OS.remove_logger(logger)
	# _check itself calls push_error once per failed assertion. Count those as
	# assertions, not a second independent native-engine failure.
	_check(logger.error_count() == failures, "focused: no additional native errors or warnings")
	print("PARKED_DEADLOCK_CHECKS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _setup() -> void:
	if is_instance_valid(field):
		field.queue_free()
		await _frames(4)
	neighbors.clear()
	field = ReducedField.new()
	field.stress_layout = true
	root.add_child(field)
	current_scene = field
	field.camera_rig.edge_scrolling_enabled = false
	for index in PARKED.size():
		var unit := _add_unit(1 if index == 0 else 26, PARKED[index])
		neighbors.append(unit)
	mover = _add_unit(12, START)
	await _frames(5)
	_check(NavigationServer3D.map_get_iteration_id(field.get_world_3d().get_navigation_map()) > 0, "focused: original obstacle mesh synchronized")
	var separated := true
	for a in field.units.size():
		for b in range(a + 1, field.units.size()):
			separated = separated and field.units[a].global_position.distance_to(field.units[b].global_position) > RTSUnit.BODY_RADIUS * 2
	_check(separated and field._registered.size() == 3, "focused: three normally registered units with no initial body overlap")
	for index in neighbors.size():
		_check(neighbors[index].move_to(PARKED_GOALS[index]), "focused: public neighbor parking command accepted")
	await _frames(3)
	var parked := true
	for unit in neighbors:
		parked = parked and unit.movement_state == RTSUnit.MovementState.ARRIVED and not unit.moving and is_equal_approx(unit.agent.radius, unit.parked_radius)
	_check(parked, "focused: captured neighbors park through ordinary arrival logic")


func _add_unit(identity: int, point: Vector3) -> RTSUnit:
	var unit := RTSUnit.new()
	unit.unit_id = identity
	unit.position = point # Legal initial scene placement only.
	field.add_child(unit)
	field.register_unit(unit)
	return unit
