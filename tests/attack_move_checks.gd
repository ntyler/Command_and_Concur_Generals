extends "res://tests/line_of_fire_checks.gd"
## M9 focused real physics tests. Clear routes and deliberate obstruction cases
## are separate cases; inherited watchdog and tools/run-godot.ps1 bound execution.

const AttackField = preload("res://tests/fixtures/attack_move_field.gd")


func _run() -> void:
	root.size = Vector2i(1280, 800)
	var logger := EngineErrorProbe.new()
	OS.add_logger(logger)
	var chosen := "all"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--attack-move-case="):
			chosen = argument.trim_prefix("--attack-move-case=")
	var cases := ["empty", "engagement", "eligibility", "bounds", "commands", "callbacks", "lifecycle"]
	_check(chosen == "all" or cases.has(chosen), "recognized attack-move case")
	for case in cases:
		if chosen != "all" and chosen != case: continue
		var before := checks
		var failed := failures
		match case:
			"empty": await _am_empty()
			"engagement": await _am_engagement()
			"eligibility": await _am_eligibility()
			"bounds": await _am_bounds()
			"commands": await _am_commands()
			"callbacks": await _am_callbacks()
			"lifecycle": await _am_lifecycle()
		print("ATTACK_MOVE_CASE: %s; checks=%d failures=%d" % [case, checks - before, failures - failed])
	if is_instance_valid(field): field.queue_free()
	await _frames(5)
	_check(root.get_children().is_empty() and get_nodes_in_group("combat_projectiles").is_empty(), "attack-move teardown releases fixture, coordinators, targets and projectiles")
	OS.remove_logger(logger)
	_check(logger.error_count() == 0, "attack-move paths and teardown have no native errors or warnings")
	print("ATTACK_MOVE_CHECKS: %d checks, %d failures; native_errors=%d" % [checks, failures, logger.error_count()])
	quit(0 if failures == 0 else 1)


func _am_fresh() -> void:
	if is_instance_valid(field):
		field.queue_free()
		await _frames(4)
	field = AttackField.new()
	root.add_child(field)
	current_scene = field
	field.camera_rig.edge_scrolling_enabled = false
	await _frames(5)
	await physics_frame
	_check(field.obstacles.is_empty() and NavigationServer3D.map_get_iteration_id(field.get_world_3d().get_navigation_map()) > 0, "small clear fixture has synchronized navigation")


func _am_actor(identity: int, point: Vector3, team: int = 1, rocket: bool = false) -> RTSUnit:
	return (field as AttackField).add_actor(identity, point, team, rocket)


func _am_until(predicate: Callable, seconds: float, description: String) -> bool:
	for tick in ceili(seconds * 60.0):
		if predicate.call():
			_check(true, description)
			return true
		await _frames(1)
	var satisfied: bool = predicate.call()
	_check(satisfied, description + " (bounded simulation deadline)")
	return satisfied


func _am_order(source: RTSUnit, point: Vector3 = Vector3(23, 0, 0)) -> CommandBatchResult:
	field.selection.replace_units([source])
	return field.issue_attack_move(point)


func _am_arrived(unit: RTSUnit, slot: Vector3) -> bool:
	return is_instance_valid(unit) and not unit.attack_move.active and not unit.moving and unit.movement_state == RTSUnit.MovementState.ARRIVED and unit.global_position.distance_to(slot) <= unit.stopping_distance + 0.02


func _am_empty() -> void:
	await _am_fresh()
	var a := _am_actor(1, Vector3(-20, 0, -2))
	var b := _am_actor(2, Vector3(-20, 0, 2), 1, true)
	await _frames(3)
	_check(a.attack_move.acquisition_interval == 0.25 and a.attack_move.acquisition_radius == 12.0 and a.attack_move.engagement_leash == 16.0 and a.attack_move.blocked_fire_duration == 2.0 and a.attack_move.ignore_duration == 3.0, "new attack-move defaults match requested simulated-time/radius settings")
	field.selection.replace_units([a, b])
	var goal := Vector3(20, 0, 0)
	var result := field.issue_attack_move(goal)
	_expect_batch(result, [1, 2], [1, 2], CommandBatchResult.Acceptance.COMPLETE)
	var slots: Array[Vector3] = [a.attack_move.final_slot, b.attack_move.final_slot]
	_check(slots[0].distance_to(slots[1]) > 0.7 and result.assignments[1] == slots[0] and result.assignments[2] == slots[1], "two combat participants receive distinct captured final slots")
	_check(a.attack_move.final_destination == goal and b.attack_move.final_destination == goal and a.attack_move.parent_order_id == result.generation and b.attack_move.parent_order_id == result.generation, "parent identity and player destination are stable across the batch")
	if not await _am_until(func() -> bool: return _am_arrived(a, slots[0]) and _am_arrived(b, slots[1]), 15, "empty Rifle/Rocket route reaches both accepted final slots"): return
	var positions := [a.position, b.position]
	await _frames(90)
	_check([a.position, b.position] == positions and a.combat.weapon.shots_fired == 0 and b.combat.weapon.shots_fired == 0, "arrived group settles without firing or restarting travel")
	var nearby := _am_actor(3, a.position + Vector3(0, 0, 5), 2)
	await _frames(60)
	_check(a.combat.target_actor() == null and b.combat.target_actor() == null and nearby.combat.health.current == 100, "completed attack-move returns to existing idle with no new automatic acquisition")


func _am_engagement() -> void:
	for mixed in [false, true]:
		await _am_fresh()
		var a := _am_actor(1, Vector3(-23, 0, -1 if mixed else 0))
		var army: Array[RTSUnit] = [a]
		if mixed: army.append(_am_actor(2, Vector3(-23, 0, 1), 1, true))
		var targets: Array[RTSUnit] = [_am_actor(3, Vector3(-8, 0, 0), 2)]
		if mixed: targets.append(_am_actor(4, Vector3(9, 0, 0), 2))
		var evidence := {"rifle": 0.0, "rocket": 0.0, "deaths": 0, "pursuit": false, "resumed": false}
		for target in targets:
			target.combat.health.damaged.connect(func(amount: float, source: Node) -> void:
				if source is RTSUnit and army.has(source): evidence["rocket" if source.combat_weapon == CombatField.ROCKET else "rifle"] += amount)
			target.combat.health.died.connect(func(_source: Node) -> void: evidence["deaths"] += 1)
		await _frames(3)
		field.selection.replace_units(army)
		var result := field.issue_attack_move(Vector3(24, 0, 0))
		_check(_complete(result), "clear encountered-enemy route accepts %s" % ("mixed group" if mixed else "Rifle"))
		var original_slots := result.assignments.duplicate()
		var origins: Dictionary[int, Vector3] = {}
		for unit in army: origins[unit.unit_id] = unit.position
		var preserved := true
		for tick in 2400:
			await _frames(1)
			for unit in army:
				preserved = preserved and unit.attack_move.final_slot == original_slots[unit.unit_id]
				if unit.attack_move.active: preserved = preserved and unit.attack_move.parent_order_id == result.generation
				if unit.combat.state == CombatController.State.PURSUING and unit.position.distance_to(origins[unit.unit_id]) > 1: evidence["pursuit"] = true
				if evidence["deaths"] > 0 and unit.moving and unit.combat.target_actor() == null and unit.attack_move.active: evidence["resumed"] = true
			if army.all(func(unit: RTSUnit) -> bool: return _am_arrived(unit, original_slots[unit.unit_id])): break
		_check(evidence["deaths"] == targets.size() and evidence["rifle"] > 0 and (not mixed or evidence["rocket"] > 0), "existing weapons inflict real damage and destroy every encountered target: %s" % evidence)
		_check(evidence["pursuit"] and evidence["resumed"] and preserved, "real pursuit gives way to resumed original travel without changing assigned slots")
		_check(army.all(func(unit: RTSUnit) -> bool: return _am_arrived(unit, original_slots[unit.unit_id])), "surviving army reaches original final slots after real engagements")
		print("ATTACK_MOVE_ENGAGEMENT: mixed=%s evidence=%s slots=%s" % [mixed, evidence, original_slots])


func _am_eligibility() -> void:
	await _am_fresh()
	var source := _am_actor(1, Vector3(-20, 0, 0))
	var friendly := _am_actor(2, Vector3(-18, 0, 0))
	var outside := _am_actor(3, Vector3(20, 0, 0), 2)
	var detached := _am_actor(4, Vector3(-15, 0, 0), 2)
	field.remove_child(detached)
	var plain := RTSUnit.new()
	plain.unit_id = 5
	plain.owner_id = 2
	plain.position = Vector3(-15, 0, 2)
	field.add_child(plain)
	field.register_unit(plain)
	var scenery := Node3D.new()
	field.add_child(scenery)
	var queued := _am_actor(6, Vector3(-15, 0, -2), 2)
	queued.queue_free()
	await _frames(3)
	_check(not TeamRules.can_attack(field, source, friendly) and not TeamRules.can_attack(field, source, detached) and not TeamRules.can_attack(field, source, plain) and not TeamRules.can_attack(field, source, scenery) and not TeamRules.can_attack(field, source, null), "shared ownership/registry rules reject friendly, detached, noncombat, scenery and null")
	_check(_complete(_am_order(source, Vector3(-20, 0, 20))), "eligibility fixture starts an ordinary attack-move leg")
	await _frames(30)
	_check(source.attack_move.target_actor() == null and source.combat.weapon.shots_fired == 0 and outside.combat.health.current == 100, "nearby invalid objects and distant hostile cause no automatic acquisition")
	detached.free()
	# Equidistant eligible targets are created with reverse stable identity order.
	await _am_fresh()
	source = _am_actor(1, Vector3(-20, 0, 0))
	var high := _am_actor(9, Vector3(-10, 0, 2), 2)
	var low := _am_actor(2, Vector3(-10, 0, -2), 2)
	await _frames(3)
	_check(_complete(_am_order(source)), "tie-break fixture accepts route")
	if not await _am_until(func() -> bool: return source.attack_move.target_actor() != null, 0.6, "nearby target acquired within bounded scan interval"): return
	_check(source.attack_move.target_actor() == low, "equal-distance acquisition chooses lower stable unit identity independent of insertion order")
	var version := source.combat.order_version
	high.position = source.position + Vector3(0, 0, 1)
	await _frames(30)
	_check(source.attack_move.target_actor() == low and source.combat.order_version == version, "retained target is neither switched nor reissued on later scans")
	await _am_fresh()
	source = _am_actor(1, Vector3(-20, 0, 0))
	var building: RTSBuilding = (field as AttackField).add_target_building(Vector3(-10, 0, 0))
	await _frames(3)
	_check(_complete(_am_order(source, Vector3(-2, 0, 8))), "targetable building fixture accepts clear route")
	await _am_until(func() -> bool: return building.health.current < building.health.maximum, 5, "automatic acquisition uses registered hostile building target and authoritative real damage")


func _am_bounds() -> void:
	# Deliberate blocker cases are isolated from all clear route acceptance.
	await _am_fresh()
	var source := _am_actor(1, Vector3(-20, 0, 0))
	var target := _am_actor(2, Vector3(-12, 0, 0), 2)
	_solid(Vector3(0.5, 3, 12), Vector3(-16, 1.5, 0))
	await _frames(3)
	_check(_complete(_am_order(source, Vector3(-20, 0, 20))), "wall-filter fixture accepts route parallel to wall")
	await _frames(45)
	_check(source.attack_move.target_actor() == null and source.combat.weapon.shots_fired == 0 and target.combat.health.current == 100, "world blocker prevents automatic acquisition through the wall")
	await _am_fresh()
	source = _am_actor(1, Vector3(-20, 0, 0))
	target = _am_actor(2, Vector3(-10, 0, 0), 2)
	await _frames(3)
	_check(_complete(_am_order(source, Vector3(-20, 0, 20))), "leash fixture accepts route")
	if not await _am_until(func() -> bool: return source.attack_move.target_actor() == target, 0.6, "out-of-weapon-range target is acquired for existing pursuit"): return
	target.position = Vector3(10, 0, 0) # Test-only fleeing fixture beyond 16-unit anchor leash.
	await _frames(3)
	_check(source.attack_move.active and source.attack_move.target_actor() == null and source.moving, "target outside acquisition-anchor leash is abandoned and final travel resumes")
	target.position = source.position + Vector3(5, 0, 0)
	for tick in 90:
		target.position = source.position + Vector3(5, 0, 0)
		await _frames(1)
	_check(source.attack_move.target_actor() == null and source.combat.weapon.shots_fired == 0, "temporary ignore prevents immediate reacquisition after fleeing target returns nearby")
	for tick in 120:
		target.position = source.position + Vector3(5, 0, 0)
		await _frames(1)
		if source.attack_move.target_actor() == target: break
	_check(source.attack_move.target_actor() == target and source.attack_move.ignored_target_count() == 0, "ignored target becomes eligible again after finite ignore expiry and old entry is removed")
	await _am_fresh()
	source = _am_actor(1, Vector3(-20, 0, 0))
	target = _am_actor(2, Vector3(-13, 0, 0), 2)
	await _frames(3)
	_check(_complete(_am_order(source, Vector3(-20, 0, 20))), "continuous blockage fixture accepts route")
	if not await _am_until(func() -> bool: return source.attack_move.target_actor() == target, 0.6, "temporary target acquired before wall appears"): return
	var wall := _solid(Vector3(0.5, 3, 14), Vector3(-16, 1.5, 0))
	await _frames(65)
	_check(source.attack_move.target_actor() == target, "temporary engagement remains before two continuous simulated seconds of blockage")
	await _am_until(func() -> bool: return source.attack_move.active and source.attack_move.target_actor() == null and source.moving, 1.3, "two-second continuous blocked firing releases engagement and resumes travel")
	wall.queue_free()
	await _frames(90)
	_check(source.attack_move.target_actor() == null, "removed obstruction does not bypass temporary ignore immediately")
	# Normal manual Attack remains persistent when obstructed.
	_check(source.combat.issue_attack(target), "manual explicit Attack accepts target after automatic abandonment")
	wall = _solid(Vector3(0.5, 3, 40), Vector3(-16, 1.5, 0))
	await _frames(180)
	_check(not source.attack_move.active and source.combat.target_actor() == target, "manual Attack retains existing blocked behavior beyond attack-move abandonment duration")
	await _am_fresh()
	source = _am_actor(1, Vector3(-20, 0, 0))
	await _frames(3)
	var enclosure := _enclose(source)
	await _frames(3)
	_check(source.command_timeout == 90 and source.maximum_recoveries == 8, "deliberate unreachable-final fixture preserves existing movement budgets")
	_check(_complete(_am_order(source)), "navigation-valid destination is accepted before physical enclosure blocks travel")
	var slot := source.attack_move.final_slot
	await _am_until(func() -> bool: return not source.attack_move.active, source.command_timeout + 1, "physically unreachable final leg terminates within existing simulated movement budget")
	_check(not source.moving and source.position.distance_to(slot) > 5 and not source.attack_move.end_reason.is_empty() and source.attack_move.end_reason != "arrived", "bounded final-leg failure reports failure without false arrival or endless retry")
	enclosure.queue_free()
	await _frames(3)
	_check(_complete(_am_order(source, Vector3(-10, 0, 0))), "bounded final failure remains receptive to a fresh valid command")


func _am_commands() -> void:
	await _am_fresh()
	var source := _am_actor(1, Vector3(-20, 0, 0))
	var target := _am_actor(2, Vector3(-10, 0, 5), 2)
	await _frames(3)
	field.selection.replace_units([source])
	_check(_complete(field.issue_move(Vector3(-20, 0, 20))), "ordinary Move accepted near hostile")
	await _frames(60)
	_check(not source.attack_move.active and source.combat.target_actor() == null and source.combat.weapon.shots_fired == 0, "ordinary Move never gains attack-move acquisition")
	for command in ["move", "attack", "stop", "replace"]:
		_check(_complete(_am_order(source)), "fresh parent accepted before " + command)
		var parent: int = source.attack_move.parent_order_id
		var accepted: CommandBatchResult
		match command:
			"move": accepted = field.issue_move(Vector3(-5, 0, 15))
			"attack": accepted = field.issue_attack(target)
			"stop": accepted = field.issue_stop()
			"replace": accepted = field.issue_attack_move(Vector3(-20, 0, -15))
		_check(_complete(accepted), "manual replacement batch accepts " + command)
		_check(source.attack_move.active and source.attack_move.parent_order_id != parent and source.attack_move.final_destination == Vector3(-20, 0, -15) if command == "replace" else not source.attack_move.active, "accepted " + command + " supersedes old parent")
	_check(_complete(_am_order(source)), "valid parent established for rejection checks")
	var parent: int = source.attack_move.parent_order_id
	var slot: Vector3 = source.attack_move.final_slot
	for invalid in [Vector3(NAN, 0, 0), Vector3(1000, 0, 1000)]:
		var result := field.issue_attack_move(invalid)
		_expect_batch(result, [1], [], CommandBatchResult.Acceptance.NONE)
		_check(source.attack_move.active and source.attack_move.parent_order_id == parent and source.attack_move.final_slot == slot, "invalid attack-move destination preserves accepted parent/slot")
	_check(not field.issue_attack(source).has_acceptance() and source.attack_move.parent_order_id == parent and source.attack_move.active, "rejected friendly explicit Attack preserves valid attack-move")


func _am_callbacks() -> void:
	await _am_fresh()
	var a := _am_actor(1, Vector3(-20, 0, 0))
	var target := _am_actor(2, Vector3(-10, 0, 0), 2)
	await _frames(3)
	_check(_complete(_am_order(a)), "target-state callback fixture establishes parent")
	if not await _am_until(func() -> bool: return a.attack_move.target_actor() == target, 0.6, "target-state callback fixture acquires temporary target"): return
	var replacement := Vector3(-20, 0, 15)
	a.combat.state_changed.connect(func(_state: int) -> void: field.issue_move(replacement), CONNECT_ONE_SHOT)
	field.remove_child(target)
	target.free()
	await _frames(45)
	_check(not a.attack_move.active and a.combat.target_actor() == null and a.assigned_destination.distance_to(replacement) < 0.1 and a.moving, "target invalidation callback's accepted newer Move cannot be overwritten by delayed resume")


func _am_lifecycle() -> void:
	for operation in ["death", "depart", "free", "other_kill"]:
		await _am_fresh()
		var source := _am_actor(1, Vector3(-20, 0, 0))
		var target := _am_actor(2, Vector3(-10, 0, 0), 2)
		await _frames(3)
		_check(_complete(_am_order(source, Vector3(-20, 0, 20))), operation + ": parent accepted")
		if not await _am_until(func() -> bool: return source.attack_move.target_actor() == target, 0.6, operation + ": target acquired"): return
		var slot: Vector3 = source.attack_move.final_slot
		match operation:
			"death": target.combat.health.apply_damage(10000, source)
			"depart": field.remove_child(target)
			"free": target.free()
			"other_kill":
				var other := _am_actor(3, Vector3(-25, 0, -10))
				target.combat.health.apply_damage(10000, other)
		await _frames(3)
		_check(source.attack_move.active and source.attack_move.target_actor() == null and source.combat.target_actor() == null and source.attack_move.final_slot == slot and source.moving, operation + ": invalid target clears safely and resumes retained final leg")
		if operation == "depart": target.free()
		await _am_until(func() -> bool: return _am_arrived(source, slot), 8, operation + ": resumed leg actually reaches accepted slot")
	for operation in ["source_death", "source_depart", "source_owner"]:
		await _am_fresh()
		var source := _am_actor(1, Vector3(-20, 0, 0))
		var target := _am_actor(2, Vector3(-10, 0, 0), 2)
		await _frames(3)
		_check(_complete(_am_order(source)), operation + ": parent accepted")
		if not await _am_until(func() -> bool: return source.attack_move.target_actor() == target, 0.6, operation + ": target acquired"): return
		var reference: WeakRef = weakref(source.attack_move)
		if operation == "source_death": source.combat.health.apply_damage(10000, target)
		elif operation == "source_depart": field.remove_child(source)
		else: source.owner_id = 2
		await _frames(3)
		_check(not is_instance_valid(reference.get_ref()) or not reference.get_ref().active, operation + ": no active parent remains after source becomes unavailable")
		if operation == "source_owner":
			_check(source.combat.target_actor() == null and not source.moving, "ownership change clears automatic combat and movement as well as parent")
		if operation == "source_depart": source.free()
	await _am_fresh()
	var source := _am_actor(1, Vector3(-20, 0, 0))
	await _frames(3)
	_check(_complete(_am_order(source)), "pending-scan freeze fixture accepts parent")
	field.gameplay_enabled = false
	_am_actor(2, Vector3(-10, 0, 0), 2)
	var position := source.position
	await _frames(60)
	_check(source.position == position and source.combat.target_actor() == null and source.combat.weapon.shots_fired == 0, "match gameplay gate freezes travel and pending acquisition")
	_check(not field.issue_attack_move(Vector3(20, 0, 10)).has_acceptance(), "frozen field rejects attack-move dispatch before selection query")
