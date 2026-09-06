extends "res://tests/milestone_checks.gd"
## Extends the Milestone 1 harness; all original assertions remain in its runner.
## Each route has a simulation deadline, plus the inherited 180-second wall deadline.

var route_metrics: Array[Dictionary] = []
var maximum_generation_ms: float = 0.0
var maximum_assignment_ms: float = 0.0
var _capture_stress: bool = true


func _run() -> void:
	root.size = Vector2i(1280, 800)
	await _fresh(30)
	_check(field.units.size() == 30, "stress layout has 30 fixed friendly units")
	_check(field.obstacles.size() == 7, "gate, L-shape and cluster geometry instantiated")
	await _capture("stress_initial_30")
	_assignment_checks(30)
	_debug_checks()
	await _route("wide_30", Vector3(-22, 0, -15), 45.0)
	await _route("choke_30", Vector3(9, 0, 0), 60.0, true)
	await _route("L_shape_30", Vector3(25, 0, -18), 60.0)
	await _route("cluster_30", Vector3(20, 0, 22), 60.0)
	await _route("boundary_30", Vector3(34.8, 0, 25.8), 60.0)
	await _fresh(50)
	_check(field.units.size() == 50, "50-unit scene option")
	_assignment_checks(50)
	var crowd_metrics := await _route("choke_50", Vector3(10, 0, 0), 75.0, true)
	if crowd_metrics.is_empty():
		quit(1)
		return
	await _route("cluster_50", Vector3(30, 0, 22), 75.0)
	await _recovery_checks()
	# Identical spawn/order, with the Milestone 1 no-avoidance behavior, for an
	# actual overlap baseline. This switch is also useful when diagnosing regressions.
	await _fresh(50, false)
	_capture_stress = false
	var baseline := await _route("overlap_baseline_50", Vector3(10, 0, 0), 45.0)
	if baseline.is_empty():
		quit(1)
		return
	var baseline_overlap: float = baseline["overlap_pair_seconds"]
	var crowd_overlap: float = crowd_metrics["overlap_pair_seconds"]
	_check(baseline_overlap > 0.1 and crowd_overlap < baseline_overlap * 0.6, "deep body-overlap time reduced by at least 40% versus disabled crowd handling")
	print("OVERLAP_COMPARISON: disabled=%.3f pair-seconds enabled=%.3f pair-seconds reduction=%.1f%%" % [baseline_overlap, crowd_overlap, 100.0 * (1.0 - crowd_overlap / maxf(0.001, baseline_overlap))])
	print("DESTINATION_TIMING: max generation=%.3f ms; max assignment=%.3f ms" % [maximum_generation_ms, maximum_assignment_ms])
	DirAccess.make_dir_recursive_absolute("res://validation-output")
	var report := FileAccess.open("res://validation-output/stress-metrics.json", FileAccess.WRITE)
	report.store_string(JSON.stringify({"routes": route_metrics, "generation_max_ms": maximum_generation_ms, "assignment_max_ms": maximum_assignment_ms, "overlap_baseline": baseline_overlap, "overlap_crowd": crowd_overlap}, "\t"))
	report.close()
	print("STRESS_CHECKS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _fresh(count: int, crowd: bool = true) -> void:
	if is_instance_valid(field):
		field.queue_free()
		await _frames(3)
	field = load("res://scenes/movement_stress.tscn").instantiate() as TestField
	field.stress_unit_count = count
	root.add_child(field)
	current_scene = field
	field.camera_rig.edge_scrolling_enabled = false
	for unit in field.units:
		unit.crowd_enabled = crowd
		field.selection.select_clicked(unit, true)
	await _frames(5)
	_check(NavigationServer3D.map_get_iteration_id(field.get_world_3d().get_navigation_map()) > 0, "%d-unit navigation ready" % count)


func _assignment_checks(count: int) -> void:
	var map := field.get_world_3d().get_navigation_map()
	for target in [Vector3(-20, 0, -12), Vector3(7, 0, 0), Vector3(34.8, 0, 25.8), Vector3(14, 0, -8)]:
		var slots := field.destinations.generate_slots(map, target, count)
		maximum_generation_ms = maxf(maximum_generation_ms, field.destinations.last_generation_usec / 1000.0)
		_check(slots.size() == count, "%d slots at %s" % [count, target])
		var valid := slots.size() == count
		var center := NavigationServer3D.map_get_closest_point(map, target)
		for a in slots.size():
			valid = valid and slots[a].distance_to(NavigationServer3D.map_get_closest_point(map, slots[a])) < 0.01
			valid = valid and slots[a].distance_to(center) <= field.destinations.maximum_radius + 0.001
			for b in range(a + 1, slots.size()):
				valid = valid and slots[a].distance_to(slots[b]) >= field.destinations.slot_spacing - 0.001
		_check(valid, "%d slots are compact, navigable and separated after projection" % count)
		_check(slots == field.destinations.generate_slots(map, target, count), "generation deterministic")
		var assigned := field.destinations.assign_slots(field.units, slots)
		maximum_assignment_ms = maxf(maximum_assignment_ms, field.destinations.last_assignment_usec / 1000.0)
		_check(assigned == field.destinations.assign_slots(field.units, slots), "assignment deterministic for unchanged units")
		var bijective := assigned.size() == count
		for slot in slots:
			bijective = bijective and assigned.count(slot) == 1
		_check(bijective, "every slot assigned exactly once")
	_check(maximum_generation_ms < 100.0 and maximum_assignment_ms < 100.0, "%d-unit destination work each stays below 100 ms measured budget" % count)
	# A deliberately impossible radius must terminate and reject atomically.
	var radius := field.destinations.maximum_radius
	field.destinations.maximum_radius = 0.5
	var before := field.units[0].order_version
	_check(not field.issue_move(Vector3(8, 0, 0)).has_acceptance(), "insufficient slots report no accepted recipients")
	_check(field.units[0].order_version == before, "insufficient compact slots preserve old orders")
	field.destinations.maximum_radius = radius
	var first := field.units[0]
	field.selection.select_clicked(first, false)
	_check(field.issue_move(field.units[1].global_position).is_complete(), "subgroup reservation command is completely accepted")
	_check(first.assigned_destination.distance_to(field.units[1].global_position) >= field.destinations.slot_spacing - 0.001, "new subgroup order respects unselected units' reserved destinations")
	for unit in field.units:
		if unit != first:
			field.selection.select_clicked(unit, true)


func _debug_checks() -> void:
	_check(not field.movement_debug and not field.units[0].debug_label.visible, "movement debug disabled by default")
	var event := InputEventKey.new()
	event.physical_keycode = KEY_F3
	event.pressed = true
	root.push_input(event, true)
	_check(field.movement_debug and field.units[0].debug_label.visible and field.units[0].waypoint_indicator.visible, "F3 enables state and waypoint visuals")
	event.pressed = false
	root.push_input(event, true)
	event.pressed = true
	root.push_input(event, true)
	_check(not field.movement_debug and not field.units[0].debug_label.visible, "F3 disables visuals cleanly")


func _route(label: String, target: Vector3, timeout: float, gate: bool = false) -> Dictionary:
	var started := Time.get_ticks_usec()
	var command_units := field.selection.selected_units()
	var versions: Array[int] = []
	for unit in command_units:
		versions.append(unit.order_version)
	var batch := field.issue_move(target)
	var accepted := batch.is_complete() and not batch.superseded
	_check(accepted, label + ": group command accepted")
	if not accepted:
		return {}
	var assignments := PackedVector3Array()
	var new_orders := command_units.size() == field.units.size()
	for i in command_units.size():
		new_orders = new_orders and command_units[i].order_version == versions[i] + 1
		var id := command_units[i].unit_id
		new_orders = new_orders and batch.accepted_ids.has(id) and batch.assignments.has(id)
		if batch.assignments.has(id):
			assignments.append(batch.assignments[id])
			new_orders = new_orders and command_units[i].assigned_destination == batch.assignments[id]
	_check(new_orders, label + ": every intended unit received a new order version")
	if not new_orders:
		return {}
	var clearance_ok := true
	var navigable := true
	var crossed: Dictionary[int, bool] = {}
	var overlap_pair_seconds: float = 0.0
	var overlap_longest: float = 0.0
	var pair_runs: Dictionary[Vector2i, float] = {}
	var entered_capture := false
	var exited_capture := false
	var cluster_capture := false
	var elapsed: float = 0.0
	var finished := false
	var frame_times := PackedFloat64Array()
	var last_frame := Time.get_ticks_usec()
	var frames := ceili(timeout * Engine.physics_ticks_per_second)
	var map := field.get_world_3d().get_navigation_map()
	for frame in frames:
		await physics_frame
		elapsed = float(frame + 1) / Engine.physics_ticks_per_second
		var now := Time.get_ticks_usec()
		frame_times.append((now - last_frame) / 1000.0)
		last_frame = now
		var still_moving := false
		for unit in field.units:
			still_moving = still_moving or unit.moving
			for obstacle in field.obstacles:
				clearance_ok = clearance_ok and not obstacle.grow(0.35).has_point(Vector2(unit.global_position.x, unit.global_position.z))
			if frame % 6 == 0:
				navigable = navigable and unit.global_position.distance_to(NavigationServer3D.map_get_closest_point(map, unit.global_position)) < 0.05
			if gate and unit.global_position.x > 2.85:
				crossed[unit.unit_id] = true
			if gate and not entered_capture and absf(unit.global_position.x) < 2.0:
				entered_capture = true
				if _capture_stress and field.units.size() == 30:
					await _capture("stress_choke_enter")
		if gate and not exited_capture and crossed.size() >= field.units.size() / 2:
			exited_capture = true
			if _capture_stress and field.units.size() == 30:
				await _capture("stress_choke_exit")
		if label == "cluster_30" and not cluster_capture:
			for unit in field.units:
				if unit.global_position.z > 8 and unit.global_position.z < 18:
					cluster_capture = true
					await _capture("stress_cluster_moving")
					break
		# Test-only pair comparisons, sampled at 10 Hz, never in gameplay movement.
		if frame % 6 == 0:
			for a in field.units.size():
				for b in range(a + 1, field.units.size()):
					var pair := Vector2i(a, b)
					if field.units[a].global_position.distance_to(field.units[b].global_position) < 0.6:
						overlap_pair_seconds += 0.1
						pair_runs[pair] = pair_runs.get(pair, 0.0) + 0.1
						overlap_longest = maxf(overlap_longest, pair_runs[pair])
					else:
						pair_runs.erase(pair)
		if not still_moving:
			finished = true
			break
	_check(finished, label + ": finishes before %.1f-second deadline" % timeout)
	var all_arrived := true
	var recovery_total: int = 0
	for i in command_units.size():
		var unit := command_units[i]
		recovery_total += unit.recovery_attempts
		var arrived := unit.order_version == versions[i] + 1 and unit.assigned_destination == assignments[i] and unit.movement_state == RTSUnit.MovementState.ARRIVED and unit.global_position.distance_to(assignments[i]) <= unit.stopping_distance + 0.01
		all_arrived = all_arrived and arrived
		if not arrived:
			print("ROUTE_DETAIL: ", label, " id=", unit.unit_id, " state=", RTSUnit.MovementState.keys()[unit.movement_state], " position=", unit.global_position, " destination=", unit.assigned_destination, " recovery=", unit.recovery_target, " attempts=", unit.recovery_attempts)
	_check(all_arrived, label + ": all units arrive within configured tolerance")
	_check(clearance_ok and navigable, label + ": units stay on navigation and outside solid obstacles")
	if gate:
		_check(crossed.size() == field.units.size() and entered_capture, label + ": entire group traverses the gate")
	var stationary := await _sample_stationary(command_units, 180)
	var settled: bool = all_arrived and stationary["stable"]
	var min_distance: float = INF
	for a in field.units.size():
		for b in range(a + 1, field.units.size()):
			min_distance = minf(min_distance, field.units[a].global_position.distance_to(field.units[b].global_position))
	_check(settled and min_distance > 0.6, label + ": no arrival jitter or stationary total overlap for three seconds")
	frame_times.sort()
	var metrics := {"route": label, "units": field.units.size(), "simulation_seconds": elapsed, "wall_ms": (Time.get_ticks_usec() - started) / 1000.0, "physics_interval_p95_ms": frame_times[int(frame_times.size() * 0.95)], "overlap_pair_seconds": overlap_pair_seconds, "longest_sampled_overlap_seconds": overlap_longest, "overlap_sample_hz": 10, "minimum_settled_distance": min_distance, "stationary_max_displacement": stationary["max_displacement"], "recoveries": recovery_total}
	route_metrics.append(metrics)
	print("ROUTE_METRICS: ", JSON.stringify(metrics))
	if _capture_stress and field.units.size() == 30:
		await _capture("stress_" + label + "_settled")
	return metrics


func _recovery_checks() -> void:
	# Place one agent in an actual physical enclosure absent from the navmesh.
	var unit := field.units[0]
	var origin := Vector3(-22, 0, 0)
	unit.global_position = origin # Fixture setup only; production recovery never sets positions.
	await _frames(3)
	# Reproduce the graphical regression: sideways oscillation is displacement,
	# but it does not reduce the remaining navigation distance to the goal.
	unit.set_physics_process(false)
	unit.crowd_enabled = false
	unit.move_to(origin + Vector3(5, 0, 0))
	for sample in range(4):
		unit.global_position = origin + Vector3(0, 0, 0.4 if sample % 2 == 0 else -0.4)
		unit.command_elapsed += unit.progress_window
		unit._update_progress(unit.progress_window)
	_check(unit.recovery_attempts > 0, "sideways oscillation does not masquerade as forward navigation progress")
	unit.global_position = origin
	unit.set_physics_process(true)
	unit.crowd_enabled = true
	unit.move_to(origin + Vector3(5, 0, 0))
	var normal_speed := unit.movement_speed
	unit.movement_speed = 0.0
	await _frames(20)
	_check(unit.recovery_attempts == 0 and unit.movement_state != RTSUnit.MovementState.RECOVERING, "ordinary brief slowing does not activate stuck recovery")
	unit.movement_speed = normal_speed
	unit.global_position = origin
	var enclosure := Node3D.new()
	field.add_child(enclosure)
	for direction in [Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK]:
		var wall := StaticBody3D.new()
		wall.position = origin + direction * 0.65 + Vector3.UP
		wall.collision_layer = 4
		var collider := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(0.15, 2, 1.5) if direction.x != 0 else Vector3(1.5, 2, 0.15)
		collider.shape = shape
		wall.add_child(collider)
		enclosure.add_child(wall)
	unit.move_to(origin + Vector3(5, 0, 0))
	var recovery_times: Array[float] = []
	var previous_attempts: int = 0
	var contained := true
	for frame in range(600): # Ten simulated seconds, explicit deadline.
		await physics_frame
		contained = contained and unit.global_position.distance_to(origin) < 0.3
		if unit.recovery_attempts > previous_attempts:
			recovery_times.append(unit.last_recovery_time)
			previous_attempts = unit.recovery_attempts
			_check(unit.movement_state == RTSUnit.MovementState.RECOVERING, "physically blocked unit enters recovery state")
		if recovery_times.size() >= 3:
			break
	_check(recovery_times.size() >= 3 and recovery_times[0] >= unit.stuck_after - 0.02, "recovery starts after sustained lack of progress (within one physics tick)")
	var spaced := true
	for index in range(1, recovery_times.size()):
		spaced = spaced and recovery_times[index] - recovery_times[index - 1] >= unit.recovery_interval - 0.02
	_check(spaced, "recovery attempts respect configured rate limit")
	_check(contained, "recovery never teleports through the physical enclosure")
	var old_version := unit.order_version
	var new_target := origin + Vector3(-5, 0, 0)
	unit.move_to(new_target)
	_check(unit.order_version == old_version + 1 and unit.recovery_attempts == 0 and not unit.recovery_active and unit.recovery_target == Vector3.ZERO and unit.stalled_for == 0 and unit.agent.target_position == new_target, "replacement order invalidates all obsolete recovery state immediately")
	unit.maximum_recoveries = 2
	for frame in range(1200):
		await physics_frame
		if unit.movement_state == RTSUnit.MovementState.FAILED:
			break
	_check(unit.movement_state == RTSUnit.MovementState.FAILED and not unit.moving and unit.recovery_attempts == 2, "permanent blockage stops safely after bounded recovery attempts")
	enclosure.queue_free()
	await _frames(3)
	unit.move_to(new_target)
	for frame in range(600):
		await physics_frame
		if not unit.moving:
			break
	_check(unit.movement_state == RTSUnit.MovementState.ARRIVED and unit.global_position.distance_to(new_target) <= unit.stopping_distance + 0.01, "new order works after blockage is removed")
	_check(not unit.recovery_active and unit.stalled_for == 0.0, "successful movement clears congestion and recovery state")
