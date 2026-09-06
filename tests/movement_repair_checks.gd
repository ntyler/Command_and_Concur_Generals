extends "res://tests/movement_stress_checks.gd"
## Focused integration regressions for the six Milestone 1.5 review findings.
## Negative harness checks intercept only their expected assertion failures.

var _expect_route_rejection: bool = false
var _rejection_messages: Array[String] = []


func _run() -> void:
	root.size = Vector2i(1280, 800)
	_capture_stress = false
	await _fresh(30)
	_edge_assignment_checks()
	await _route_rejection_checks()
	await _signal_replacement_checks()
	await _other_transition_checks()
	await _crowd_toggle_checks()
	await _departure_checks()
	await _progress_cleanup_checks()
	await _stationary_observation_checks()
	print("REPAIR_CHECKS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _edge_assignment_checks() -> void:
	var map := field.get_world_3d().get_navigation_map()
	var empty_units: Array[RTSUnit] = []
	_check(field.destinations.generate_slots(map, Vector3.ZERO, 0).is_empty(), "zero units generate zero slots")
	_check(field.destinations.assign_slots(empty_units, PackedVector3Array()).is_empty(), "zero units assign safely")
	var target := Vector3(-20, 0, -12)
	var slots := field.destinations.generate_slots(map, target, 1)
	var single: Array[RTSUnit] = [field.units[0]]
	_check(slots.size() == 1 and slots[0].distance_to(target) < 0.01, "one unit gets the clicked navigable slot")
	_check(field.destinations.assign_slots(single, slots) == slots, "one-unit assignment is a bijection")
	_check(field.destinations.assign_slots(single, PackedVector3Array()).is_empty(), "mismatched slot count rejects safely")


func _route_rejection_checks() -> void:
	await _route("repair_setup", Vector3(-22, 0, -15), 45.0)
	var previous_slots := field.last_command_slots.duplicate()
	var versions: Array[int] = []
	var targets := PackedVector3Array()
	for unit in field.units:
		versions.append(unit.order_version)
		targets.append(unit.assigned_destination)
	field.destinations.maximum_radius = 0.5 # Same bounded rejection fixture as the stress suite.
	_expect_route_rejection = true
	var frame_before := Engine.get_physics_frames()
	var result := await _route("intentional_rejection", Vector3(9, 0, 0), 1.0)
	var frames_elapsed := Engine.get_physics_frames() - frame_before
	_expect_route_rejection = false
	field.destinations.maximum_radius = 18.0
	_check(_rejection_messages.size() == 1 and _rejection_messages[0].contains("command accepted"), "rejected route reports its command failure")
	_check(result.is_empty() and frames_elapsed == 0, "rejected route returns immediately without validating stale ARRIVED units")
	var preserved := field.last_command_slots == previous_slots
	for i in field.units.size():
		var unit := field.units[i]
		preserved = preserved and unit.order_version == versions[i] and unit.assigned_destination == targets[i] and unit.movement_state == RTSUnit.MovementState.ARRIVED and not unit.moving
	_check(preserved, "rejected command preserves the prior coherent production order")
	field.selection.select_clicked(null, false)
	var rejected := field.issue_move(Vector3.ZERO)
	_check(not rejected.has_acceptance() and rejected.intended_ids.is_empty() and not rejected.superseded, "command API explicitly rejects an empty selection")


func _solo(crowd: bool = true) -> RTSUnit:
	await _fresh(30)
	var unit := RTSUnit.new()
	unit.unit_id = 31
	unit.crowd_enabled = crowd
	unit.position = Vector3(-22, 0, -10) # Test setup on empty, flat navigation.
	field.add_child(unit) # Configure the public mode before _ready(), just like a scene export.
	field.register_unit(unit)
	await _frames(3)
	return unit


func _temporary_state_cleared(unit: RTSUnit) -> bool:
	return not unit.recovery_active and unit.recovery_target == Vector3.ZERO and unit._recovery_elapsed == 0.0 and unit.agent.avoidance_priority == 0.5 and unit.agent.target_position == unit.assigned_destination


func _signal_replacement_checks() -> void:
	var unit := await _solo()
	var origin := unit.global_position
	var target_b := origin + Vector3(0, 0, -8)
	unit.move_to(origin + Vector3(8, 0, 0))
	var old_version := unit.order_version
	var observed := {"coherent": false, "calls": 0}
	var listener := func(state: RTSUnit.MovementState) -> void:
		if state == RTSUnit.MovementState.RECOVERING:
			observed["calls"] += 1
			observed["coherent"] = unit.recovery_active and unit.recovery_attempts == 1 and unit._recovery_elapsed == 0.0 and is_equal_approx(unit.agent.avoidance_priority, unit.recovery_priority) and unit.agent.target_position == unit.recovery_target and unit.recovery_target != Vector3.ZERO
			unit.move_to(target_b)
	unit.movement_state_changed.connect(listener)
	unit._recover() # Exercise the real transition and its synchronous public signal.
	unit.movement_state_changed.disconnect(listener)
	_check(observed["calls"] == 1 and observed["coherent"], "RECOVERING signal observes a complete transition")
	_check(unit.order_version == old_version + 1 and unit.assigned_destination == target_b and _temporary_state_cleared(unit), "synchronous signal replacement owns every target and temporary state")
	_check(unit.recovery_attempts == 0 and unit.stalled_for == 0.0 and unit.command_elapsed == 0.0 and unit._progress_elapsed == 0.0 and unit.last_recovery_time == -INF, "signal replacement clears all obsolete timers and attempt history")
	var stayed_replaced := true
	for frame in range(60):
		await physics_frame
		stayed_replaced = stayed_replaced and unit.order_version == old_version + 1 and unit.assigned_destination == target_b and _temporary_state_cleared(unit)
	_check(stayed_replaced and unit.global_position.distance_to(target_b) < origin.distance_to(target_b) - 1.0, "subsequent physics ticks never restore the obsolete recovery waypoint")
	await _arrive_bounded(unit, target_b, "signal replacement")


func _arrive_bounded(unit: RTSUnit, target: Vector3, label: String) -> void:
	var bounded := true
	var previous := unit.global_position
	for frame in range(900):
		await physics_frame
		bounded = bounded and unit.global_position.distance_to(previous) <= unit.movement_speed / Engine.physics_ticks_per_second + 0.001
		previous = unit.global_position
		if not unit.moving:
			break
	_check(bounded, label + ": at most one speed-bounded displacement per physics tick")
	_check(unit.movement_state == RTSUnit.MovementState.ARRIVED and unit.global_position.distance_to(target) <= unit.stopping_distance + 0.01, label + ": clean arrival before deadline")


func _other_transition_checks() -> void:
	var unit := await _solo(false)
	unit.set_physics_process(false)
	var target := unit.global_position + Vector3(6, 0, 0)
	var audit := {"coherent": true, "seen": {}}
	var inspect := func(state: RTSUnit.MovementState) -> void:
		audit["seen"][state] = true
		var coherent := unit.movement_state == state
		if state == RTSUnit.MovementState.RECOVERING:
			coherent = coherent and unit.moving and unit.recovery_active and unit.agent.target_position == unit.recovery_target and is_equal_approx(unit.agent.avoidance_priority, unit.recovery_priority)
		elif state in [RTSUnit.MovementState.ARRIVED, RTSUnit.MovementState.FAILED]:
			coherent = coherent and not unit.moving and not unit.recovery_active and unit.recovery_target == Vector3.ZERO and unit._recovery_elapsed == 0 and unit.velocity == Vector3.ZERO and unit.agent.max_speed == 0 and unit.agent.avoidance_priority == 1.0
		else:
			coherent = coherent and unit.moving and _temporary_state_cleared(unit)
		audit["coherent"] = audit["coherent"] and coherent
	unit.movement_state_changed.connect(inspect)
	unit.move_to(target)
	unit._update_progress(unit.progress_window)
	unit._recover()
	unit._clear_recovery()
	unit._fail_move()
	unit.move_to(unit.global_position)
	unit.set_physics_process(true)
	await _frames(3)
	unit.movement_state_changed.disconnect(inspect)
	_check(audit["coherent"] and audit["seen"].size() == 5, "all five public movement states expose coherent transition data")
	# A new order from CONGESTED must prevent the old sample from starting recovery.
	unit.set_physics_process(false)
	unit.move_to(target)
	var before := unit.order_version
	var replacement := unit.global_position + Vector3(0, 0, -6)
	var replace_congested := func(state: RTSUnit.MovementState) -> void:
		if state == RTSUnit.MovementState.CONGESTED:
			unit.move_to(replacement)
	unit.movement_state_changed.connect(replace_congested)
	unit._update_progress(unit.stuck_after)
	unit.movement_state_changed.disconnect(replace_congested)
	_check(unit.order_version == before + 1 and unit.recovery_attempts == 0 and unit.assigned_destination == replacement and _temporary_state_cleared(unit), "CONGESTED listener replacement prevents obsolete follow-on recovery")
	unit._finish_move()
	var replaced := {"once": false}
	var replace_travelling := func(state: RTSUnit.MovementState) -> void:
		if state == RTSUnit.MovementState.TRAVELLING and not replaced["once"]:
			replaced["once"] = true
			unit.move_to(replacement)
	unit.movement_state_changed.connect(replace_travelling)
	unit.move_to(target)
	unit.movement_state_changed.disconnect(replace_travelling)
	_check(unit.assigned_destination == replacement and unit.destination_indicator.global_position.is_equal_approx(replacement + Vector3.UP * 0.055) and _temporary_state_cleared(unit), "TRAVELLING listener replacement also owns the debug destination")
	unit.set_physics_process(true)


func _crowd_toggle_checks() -> void:
	for start_enabled in [true, false]:
		var unit := await _solo(start_enabled)
		var target := unit.global_position + Vector3(10, 0, 0)
		unit.move_to(target)
		await _frames(12)
		var before_toggle := unit.global_position
		unit.crowd_enabled = not start_enabled
		_check(unit.agent.avoidance_enabled == unit.crowd_enabled and unit._submitted_order == -1, "public crowd toggle synchronizes avoidance and invalidates submissions")
		if not unit.crowd_enabled:
			unit._on_avoidance_velocity(Vector3(5, 0, 0)) # A stale callback must be harmless.
			_check(unit.global_position == before_toggle, "disabled crowd mode rejects stale avoidance displacement")
		await _arrive_bounded(unit, target, "crowd toggle %s to %s" % [start_enabled, not start_enabled])
		_check(unit.global_position.distance_to(before_toggle) > 1.0, "movement continues after changing only the public crowd property")


func _departure_checks() -> void:
	for detach in [true, false]:
		for selected_departure in [true, false]:
			await _fresh(30)
			var departed := field.units[0]
			var remaining := field.units[1]
			var old_target := Vector3(-22, 0, -10)
			departed.move_to(old_target)
			field.selection.select_clicked(remaining, false)
			if selected_departure:
				field.selection.select_clicked(departed, true)
			var old_version := departed.order_version
			if detach:
				field.remove_child(departed)
				_check(not field.selection._selected.has(departed), "tree exit promptly removes detached selection")
			else:
				departed.queue_free()
				await _frames(3)
			var label := "%s %s" % ["detached" if detach else "freed", "selected" if selected_departure else "unselected"]
			_check(field.selection.selected_units() == [remaining], label + ": departure pruned from selection")
			_check(field.units.size() == 29, label + ": active field enumeration excludes departure")
			for repeat in range(2):
				_check(field.issue_move(old_target).is_complete(), "remaining member accepts a fresh reservation reuse command")
				_check(remaining.assigned_destination.distance_to(old_target) < 0.01, label + ": old reservation released and repeated cleanup safe")
			if detach:
				_check(departed.order_version == old_version, "detached unit receives no stale group command")
				departed.free() # Detached fixture ownership belongs to this test.
	await _fresh(30)
	var unit := field.units[0]
	var holder := Node3D.new()
	field.add_child(holder)
	unit.reparent(holder)
	await _frames(3)
	_check(field.units.size() == 30 and field.units.count(unit) == 1, "reparenting within the field restores exactly one active membership")
	field.selection.select_clicked(unit, false)
	var old_version := unit.order_version
	_check(field.issue_move(Vector3(-22, 0, -10)).is_complete(), "reparented member accepts a fresh move command")
	_check(unit.order_version == old_version + 1, "unit remains commandable after internal reparenting")


func _progress_cleanup_checks() -> void:
	var unit := await _solo()
	unit.crowd_enabled = false
	unit.set_physics_process(false)
	var origin := unit.global_position
	var target := origin + Vector3(8, 0, 0)
	unit.move_to(target)
	unit._recover()
	var attempts := unit.recovery_attempts
	unit._recovery_elapsed = 1.0
	unit.global_position += Vector3(unit.meaningful_progress + 0.1, 0, 0) # Deterministic progress fixture.
	var observed := {"coherent": false}
	var listener := func(state: RTSUnit.MovementState) -> void:
		if state == RTSUnit.MovementState.TRAVELLING:
			observed["coherent"] = _temporary_state_cleared(unit) and unit._progress_elapsed == 0.0 and unit.stalled_for == 0.0
	unit.movement_state_changed.connect(listener)
	unit._update_progress(unit.progress_window)
	unit.movement_state_changed.disconnect(listener)
	_check(observed["coherent"] and _temporary_state_cleared(unit), "meaningful progress clears temporary recovery before TRAVELLING is emitted")
	_check(unit.recovery_attempts == attempts and attempts == 1, "progress cleanup preserves the per-order attempt cap")
	unit.set_physics_process(true)
	await _arrive_bounded(unit, target, "progress cleanup")
	_check(not unit.recovery_active and unit.agent.target_position == target, "expired recovery cannot restore a temporary path")


func _stationary_observation_checks() -> void:
	var unit := await _solo(false)
	var anchor := unit.global_position
	var sample := {"frame": 0}
	var oscillate := func() -> void:
		sample["frame"] += 1
		unit.global_position = anchor + (Vector3.RIGHT * 0.1 if sample["frame"] % 2 else Vector3.ZERO)
	physics_frame.connect(oscillate)
	var observed := await _sample_stationary([unit], 12)
	physics_frame.disconnect(oscillate)
	_check(unit.global_position == anchor and not observed["stable"] and observed["max_displacement"] > 0.09, "stationary sampler rejects oscillation even when final position equals arrival position")


func _check(condition: bool, description: String) -> void:
	if _expect_route_rejection:
		if not condition:
			_rejection_messages.append(description)
		return
	super._check(condition, description)
