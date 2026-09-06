extends "res://tests/milestone_checks.gd"
## Fixed-step integration tests; inherits internal watchdog, run through external wrapper.


func _run() -> void:
	root.size = Vector2i(1280, 800)
	var error_probe := EngineErrorProbe.new()
	OS.add_logger(error_probe)
	var load_only := OS.get_cmdline_user_args().has("--combat-load")
	if OS.get_cmdline_user_args().has("--verify-combat-errors"):
		# Isolated negative check: real engine error must produce runner exit 1.
		var detached := Node3D.new()
		var _invalid_transform := detached.global_transform
		detached.free()
	elif load_only:
		await _load_checks()
	else:
		_health_checks()
		await _ownership_checks()
		await _hitscan_checks()
		await _pursuit_checks()
		await _multiple_and_blocked_checks()
		await _death_and_departure_checks()
		await _replacement_signal_checks()
		await _group_reentrancy_checks()
		await _projectile_checks()
		await _retaliation_checks()
		await _engagement_checks()
	# Include teardown: descendants can exit before the unit's tree_exiting signal.
	if is_instance_valid(field):
		field.queue_free()
	await _frames(3)
	OS.remove_logger(error_probe)
	_check(error_probe.error_count() == 0, "no engine errors or warnings during combat paths and complete scene teardown")
	print("%s: %d checks, %d failures" % ["COMBAT_LOAD_CHECKS" if load_only else "COMBAT_CHECKS", checks, failures])
	quit(0 if failures == 0 else 1)


func _fresh_combat(retaliation: bool = false) -> void:
	if is_instance_valid(field):
		field.queue_free()
		await _frames(3)
	field = load("res://scenes/combat_test.tscn").instantiate() as TestField
	root.add_child(field)
	current_scene = field
	field.camera_rig.edge_scrolling_enabled = false
	if not retaliation:
		for unit in field.units:
			unit.combat.retaliation_enabled = false
	await _frames(5)
	_check(NavigationServer3D.map_get_iteration_id(field.get_world_3d().get_navigation_map()) > 0, "combat navigation synchronized")


func _pair(rocket: bool = false, distance: float = 6.0) -> Array[RTSUnit]:
	await _fresh_combat()
	var source := field.units[4 if rocket else 0]
	var target := field.units[6]
	# Fixture setup on empty southern navigation; gameplay pursuit never teleports.
	source.global_position = Vector3(-18, 0, 16)
	target.global_position = source.global_position + Vector3.RIGHT * distance
	source.halt_motion()
	target.halt_motion()
	await _frames(3)
	return [source, target]


func _align(source: RTSUnit, target: RTSUnit) -> void:
	source.face_toward(target.global_position, 1000.0, 1.0) # Explicit initial-facing fixture.


func _health_checks() -> void:
	var health := UnitHealth.new()
	health.maximum = 50.0
	root.add_child(health)
	var events := {"damage": 0, "death": 0}
	health.damaged.connect(func(_amount: float, _source: Node) -> void: events["damage"] += 1)
	health.died.connect(func(_source: Node) -> void: events["death"] += 1)
	_check(health.current == 50.0 and health.is_alive(), "health starts at configured maximum independently of visuals")
	for invalid in [0.0, -5.0, NAN, INF]:
		_check(health.apply_damage(invalid) == 0.0 and health.current == 50.0, "nonpositive/nonfinite damage rejected without healing")
	_check(events["damage"] == 0, "rejected damage emits no damage notification")
	_check(health.apply_damage(12.0) == 12.0 and health.current == 38.0, "damage subtracts the exact amount")
	_check(health.apply_damage(1000.0) == 38.0 and health.current == 0.0 and not health.is_alive(), "lethal damage clamps health to zero")
	_check(health.apply_damage(10.0) == 0.0 and events["death"] == 1 and events["damage"] == 2, "death fires once and subsequent damage has no effect")
	health.free()
	var nested := UnitHealth.new()
	nested.maximum = 10.0
	root.add_child(nested)
	var deaths := {"count": 0}
	nested.died.connect(func(_source: Node) -> void: deaths["count"] += 1)
	nested.damaged.connect(func(_amount: float, _source: Node) -> void:
		if nested.is_alive():
			nested.apply_damage(20.0))
	nested.apply_damage(1.0)
	_check(deaths["count"] == 1 and not nested.is_alive(), "nested damage listener cannot duplicate death")
	nested.free()


func _ownership_checks() -> void:
	await _fresh_combat(true)
	_check(field.units.size() == 12 and field.obstacles.size() >= 2, "combat scene contains twelve units and navigation obstacles")
	var counts := {"1_0": 0, "1_1": 0, "2_0": 0, "2_1": 0}
	for i in field.units.size():
		var unit := field.units[i]
		counts["%d_%d" % [unit.owner_id, unit.combat.weapon.definition.mode]] += 1
		_check(unit.global_position == CombatField.STARTS[i] and field.contains_unit(unit), "fixed registered combat spawn %02d" % unit.unit_id)
	_check(counts == {"1_0": 4, "1_1": 2, "2_0": 4, "2_1": 2}, "each team has four Rifle Units and two Rocket Vehicles")
	await _frames(60)
	var idle := true
	for unit in field.units:
		idle = idle and unit.combat.target_unit() == null and unit.combat.weapon.shots_fired == 0
	_check(idle, "hostiles do not acquire or launch a strategic attack at startup")
	await _capture("combat_initial_teams")
	var source := field.units[0]
	var target := field.units[6]
	await _click(_screen(source), MOUSE_BUTTON_LEFT)
	_check(field.selection.selected_units() == [source], "friendly unit selected through actual raycast")
	await _click(_screen(target), MOUSE_BUTTON_LEFT, true)
	_check(field.selection.selected_units() == [source], "hostile click cannot enter local selection")
	field.selection.select_rectangle(root.get_visible_rect(), true)
	_check(field.selection.selected_units().size() == 6, "rectangle accepts only six local team units")
	await _capture("combat_friendly_selection")
	field.selection.select_clicked(source, false)
	var before := source.combat.order_version
	await _click(_screen(target), MOUSE_BUTTON_RIGHT)
	_check(source.combat.order_version == before + 1 and source.combat.target_unit() == target, "contextual hostile right-click accepts a new attack order")
	before = source.combat.order_version
	await _click(_screen(field.units[1]), MOUSE_BUTTON_RIGHT)
	_check(source.combat.order_version == before and source.combat.target_unit() == target, "friendly right-click does not replace an attack with a friendly attack")
	_check(not field.issue_attack(field.units[1]).has_acceptance() and source.combat.order_version == before, "friendly command returns explicit rejection without stale acceptance")
	_check(field.issue_attack(field.units[7]).is_complete() and source.combat.order_version == before + 1 and source.combat.target_unit() == field.units[7], "replacement attack increments the order version and changes target")
	await _click(_world_screen(Vector3(-12, 0, 18)), MOUSE_BUTTON_RIGHT)
	_check(source.combat.target_unit() == null and source.combat.state == CombatController.State.NONE and source.moving, "ground right-click cancels attack and issues ordinary movement")
	var stop_event := InputEventKey.new()
	stop_event.physical_keycode = KEY_X
	stop_event.pressed = true
	root.push_input(stop_event, true)
	stop_event.pressed = false
	root.push_input(stop_event, true)
	await _frames(2)
	_check(not source.moving and source.combat.target_unit() == null and source.combat.player_command == CombatController.PlayerCommand.STOP, "named X Stop cancels movement and combat")
	field.selection.select_clicked(null, false)
	before = source.combat.order_version
	_check(not field.issue_attack(target).has_acceptance() and not field.issue_stop().has_acceptance(), "no selection explicitly rejects attack and stop")
	await _click(_screen(target), MOUSE_BUTTON_RIGHT)
	_check(source.combat.order_version == before, "empty-selection hostile click does nothing")
	var unregistered := (field as CombatField)._create_unit(0)
	unregistered.owner_id = 2
	field.add_child(unregistered)
	field.selection.select_clicked(source, false)
	_check(not field.contains_unit(unregistered) and not field.issue_attack(unregistered).has_acceptance(), "unregistered unit inside the scene is not a combat target")
	_check(not unregistered.combat.issue_attack(source) and not unregistered.move_to(Vector3.ZERO), "unregistered combat unit also rejects its own attack and movement orders")
	unregistered.owner_id = 1
	field.selection.select_clicked(unregistered, true)
	_check(field.selection.selected_units() == [source], "unregistered unit cannot enter selection")
	unregistered.queue_free()


func _hitscan_checks() -> void:
	var pair := await _pair()
	var source := pair[0]
	var target := pair[1]
	var weapon := source.combat.weapon
	source.combat.set_physics_process(false)
	await physics_frame # Direct weapon queries belong to safe physics processing.
	_check(not weapon.try_fire(target) and target.combat.health.current == 100.0, "outside-facing-tolerance hitscan cannot fire")
	_align(source, target)
	var observed := {"count": 0, "health": 0.0, "cooldown": 0.0}
	weapon.fired.connect(func(victim: RTSUnit, _projectile: GuidedProjectile) -> void:
		observed["count"] += 1
		observed["health"] = victim.combat.health.current
		observed["cooldown"] = weapon.cooldown_remaining)
	_check(weapon.try_fire(target) and target.combat.health.current == 88.0, "hitscan applies exactly one damage amount at fire time")
	_check(observed["count"] == 1 and observed["health"] == 88.0 and observed["cooldown"] == 0.75, "fired signal observes immediate damage and established cooldown")
	_check(target.combat.feedback.health_label.text.contains("88 / 100") and target.combat.feedback.flash_remaining > 0.0, "health feedback and damage flash update immediately")
	await _capture("combat_rifle_fire")
	await physics_frame # A graphical capture resumes outside safe query processing.
	_check(not weapon.try_fire(target) and target.combat.health.current == 88.0, "same shot cannot be repeated during cooldown")
	weapon.advance(0.74)
	_check(not weapon.try_fire(target), "cooldown blocks early repeat fire")
	weapon.advance(0.01)
	_check(weapon.try_fire(target) and observed["count"] == 2 and target.combat.health.current == 76.0, "simulation-time cooldown permits exactly the next shot")
	source.combat.issue_attack(target)
	source.stop()
	_check(not weapon.try_fire(target) and weapon.cooldown_remaining == 0.75, "replacement and stop orders cannot bypass a fired weapon's cooldown")
	target.global_position = source.global_position + Vector3.RIGHT * 12.0
	target.halt_motion()
	weapon.advance(1.0)
	_check(not weapon.try_fire(target), "out-of-range weapon cannot fire even when facing and ready")
	var angle_before := source._visual.rotation.y
	source.face_toward(source.global_position + Vector3.FORWARD * 5, 4.0, 1.0 / 60)
	_check(absf(angle_difference(angle_before, source._visual.rotation.y)) <= 4.0 / 60.0 + 0.00001, "combat yaw turn is bounded by radians per simulation second")
	var angle_start := source._visual.rotation.y
	for tick in range(12):
		source.face_toward(source.global_position + Vector3.FORWARD * 5, 4.0, 1.0 / 60)
	var angle_60 := source._visual.rotation.y
	source._visual.rotation.y = angle_start
	for tick in range(6):
		source.face_toward(source.global_position + Vector3.FORWARD * 5, 4.0, 1.0 / 30)
	_check(absf(angle_difference(angle_60, source._visual.rotation.y)) < 0.00001 and source.rotation == Vector3.ZERO, "facing agrees at 30/60 Hz and does not rotate the navigation body")


func _pursuit_checks() -> void:
	var pair := await _pair(false, 20.0)
	var source := pair[0]
	var target := pair[1]
	var before := source.combat.order_version
	_check(source.combat.issue_attack(target) and source.combat.order_version == before + 1, "out-of-range attack explicitly accepted")
	var previous := source.global_position
	var valid_motion := true
	var firing_position := Vector3.ZERO
	for frame in range(900):
		await physics_frame
		valid_motion = valid_motion and source.global_position.distance_to(previous) <= source.movement_speed / 60.0 + 0.001
		previous = source.global_position
		valid_motion = valid_motion and source.global_position.distance_to(NavigationServer3D.map_get_closest_point(source.agent.get_navigation_map(), source.global_position)) < 0.05
		for obstacle in field.obstacles:
			valid_motion = valid_motion and not obstacle.grow(0.35).has_point(Vector2(source.global_position.x, source.global_position.z))
		if frame == 60:
			await _capture("combat_pursuit")
		if source.combat.weapon.shots_fired > 0:
			firing_position = source.global_position
			break
	_check(valid_motion and firing_position != Vector3.ZERO, "pursuit uses speed-bounded navigation and reaches firing range before deadline")
	_check(source.combat.pursuit_updates == 1, "stationary target does not rebuild pursuit paths every frame or interval")
	_check(not source.moving and source.velocity == Vector3.ZERO and source.facing_error(target.global_position) <= deg_to_rad(8.0) and source.global_position.distance_to(target.global_position) <= 8.0, "attacker stops and faces within tolerance before firing")
	var stable := true
	for frame in range(60):
		await physics_frame
		stable = stable and not source.moving and source.global_position.distance_to(firing_position) < 0.001
	_check(stable, "in-range attacker remains stationary throughout cooldown and subsequent fire")
	var shots := source.combat.weapon.shots_fired
	var transitions := {"pursue": 0}
	var listener := func(next: CombatController.State) -> void:
		if next == CombatController.State.PURSUING:
			transitions["pursue"] += 1
	source.combat.state_changed.connect(listener)
	for frame in range(40):
		target.global_position = firing_position + Vector3.RIGHT * (8.3 if frame % 2 else 8.5)
		await physics_frame
	_check(transitions["pursue"] == 0 and source.global_position.distance_to(firing_position) < 0.001 and source.combat.weapon.shots_fired == shots, "hysteresis band avoids pursuit oscillation and does not permit out-of-range shots")
	target.global_position = firing_position + Vector3.RIGHT * 11.0
	target.halt_motion()
	await _frames(20)
	_check(transitions["pursue"] == 1 and source.moving and source.combat.pursuit_updates == 2, "target leaving range plus margin resumes bounded pursuit")
	source.combat.state_changed.disconnect(listener)
	source.crowd_enabled = false
	await _frames(10)
	source.crowd_enabled = true
	await _frames(10)
	_check(source.agent.avoidance_enabled and source.crowd_enabled and source.global_position.distance_to(firing_position) > 0.5, "public crowd toggles continue movement during pursuit")
	source.move_to(Vector3(-23, 0, 16))
	_check(source.combat.target_unit() == null and source.combat.state == CombatController.State.NONE and source.combat.pursuit_elapsed == 0.0 and source.combat.pursuit_updates == 0, "replacement movement clears target and all temporary pursuit state")


func _multiple_and_blocked_checks() -> void:
	var pair := await _pair(false, 20.0)
	var source := pair[0]
	var target := pair[1]
	var other := field.units[1]
	other.global_position = source.global_position + Vector3(0, 0, 4)
	other.halt_motion()
	field.selection.select_clicked(source, false)
	field.selection.select_clicked(other, true)
	_check(field.issue_attack(target).is_complete(), "multiple selected attackers accept the same hostile target")
	await _frames(5)
	_check(source.assigned_destination.distance_to(target.global_position) > 4.0 and other.assigned_destination.distance_to(target.global_position) > 4.0 and source.assigned_destination.distance_to(other.assigned_destination) > 0.5, "attackers navigate to separate near-target positions rather than its origin")
	pair = await _pair(false, 20.0)
	source = pair[0]
	target = pair[1]
	var origin := source.global_position
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
	source.maximum_recoveries = 2 # Bounded obstruction fixture, same as movement tests.
	source.command_timeout = 12.0
	source.combat.issue_attack(target)
	var attempts: int = 0
	var contained := true
	for frame in range(900):
		await physics_frame
		attempts = maxi(attempts, source.recovery_attempts)
		contained = contained and source.global_position.distance_to(origin) < 0.3
		if source.combat.target_unit() == null:
			break
	_check(contained and attempts > 0 and attempts <= 2 and source.combat.end_reason == "pursuit_budget_exhausted", "blocked pursuit preserves bounded recovery and never teleports")
	_check(source.combat.target_unit() == null and not source.moving and source.combat.weapon.shots_fired == 0, "exhausted pursuit returns safely idle without false fire")


func _death_and_departure_checks() -> void:
	var pair := await _pair()
	var source := pair[0]
	var target := pair[1]
	var remaining := field.units[1]
	var old_destination := Vector3(-10, 0, 18)
	source.move_to(old_destination)
	field.selection.select_clicked(source, false)
	target.combat.issue_attack(source)
	var deaths := {"count": 0}
	source.combat.health.died.connect(func(_attacker: Node) -> void: deaths["count"] += 1)
	source.combat.health.apply_damage(1000.0, target)
	_check(deaths["count"] == 1 and not source.is_alive() and not source.moving and not source.recovery_active, "death immediately marks dead and clears movement/recovery")
	_check(not source.move_to(Vector3.ZERO) and not source.stop() and not source.combat.issue_attack(target), "dead unit rejects movement, stop and combat orders")
	_check(field.selection.selected_units().is_empty() and not field.contains_unit(source) and field.units.size() == 11, "death immediately removes selection and active registration")
	_check(target.combat.target_unit() == null and not target.moving, "death immediately notifies and stops an attacker")
	field.selection.select_clicked(remaining, false)
	_check(not field.issue_attack(source).has_acceptance(), "dead target returns explicit attack rejection")
	_check(field.issue_move(old_destination).is_complete() and remaining.assigned_destination.distance_to(old_destination) < 0.01, "death releases the old movement destination reservation")
	var dead_ref: WeakRef = weakref(source)
	await _frames(3)
	_check(dead_ref.get_ref() == null, "dead unit disappears and is freed deterministically")
	await _capture("combat_destroyed")
	await _frames(30)
	_check(remaining.moving and field.selection.selected_units() == [remaining], "surviving selected unit remains controllable after death")
	await _capture("combat_survivor_control")
	for departure in ["detach", "free", "other_parent", "team"]:
		pair = await _pair(false, 20.0)
		source = pair[0]
		target = pair[1]
		source.combat.issue_attack(target)
		field.selection.select_clicked(source, false)
		await _frames(3)
		var holder: Node3D
		if departure == "detach":
			field.remove_child(target)
		elif departure == "free":
			target.queue_free()
			_check(not field.issue_attack(target).has_acceptance(), "queued-for-deletion target rejects attack before the next frame")
		elif departure == "other_parent":
			holder = Node3D.new()
			root.add_child(holder)
			target.reparent(holder)
		else:
			target.owner_id = source.owner_id
		await _frames(3)
		_check(source.combat.target_unit() == null and not source.moving and source.combat.state == CombatController.State.NONE, departure + ": attacker cancels and safely idles")
		field.selection.select_clicked(source, false)
		if is_instance_valid(target):
			var before := source.combat.order_version
			_check(not field.issue_attack(target).has_acceptance() and source.combat.order_version == before, departure + ": unavailable target rejected without a new version")
		if departure == "detach":
			target.free()
		if is_instance_valid(holder):
			holder.queue_free()


func _replacement_signal_checks() -> void:
	for trigger in [CombatController.State.PURSUING, CombatController.State.FACING, CombatController.State.ATTACKING, CombatController.State.TARGET_INVALIDATED]:
		var pair := await _pair(false, 20.0 if trigger == CombatController.State.PURSUING else 6.0)
		var source := pair[0]
		var target := pair[1]
		var replacement := field.units[7]
		replacement.global_position = Vector3(-18, 0, -2)
		replacement.halt_motion()
		var observed := {"calls": 0, "coherent": false}
		var next_move := Vector3(-23, 0, 16)
		if trigger == CombatController.State.ATTACKING:
			_align(source, target)
		var listener := func(next: CombatController.State) -> void:
			if next != trigger or observed["calls"] != 0:
				return
			observed["calls"] += 1
			observed["coherent"] = source.combat.state == next and (source.combat.target_unit() == target if next != CombatController.State.TARGET_INVALIDATED else source.combat.target_unit() == null) and (not source.moving if next != CombatController.State.PURSUING else true)
			if next in [CombatController.State.PURSUING, CombatController.State.ATTACKING]:
				source.combat.issue_attack(replacement)
			else:
				source.move_to(next_move)
		source.combat.state_changed.connect(listener)
		source.combat.issue_attack(target)
		if trigger == CombatController.State.TARGET_INVALIDATED:
			field.remove_child(target)
		await _frames(12)
		source.combat.state_changed.disconnect(listener)
		var replaced := source.combat.target_unit() == replacement if trigger in [CombatController.State.PURSUING, CombatController.State.ATTACKING] else source.combat.target_unit() == null and source.assigned_destination == next_move and source.agent.target_position == next_move
		_check(observed["calls"] == 1 and observed["coherent"] and replaced, "synchronous %s listener owns its replacement order on subsequent ticks" % CombatController.State.keys()[trigger])
		_check(target.combat.health.current == 100.0, "obsolete transition never fires at the previous target")
		if trigger == CombatController.State.TARGET_INVALIDATED:
			target.free()
	var pair := await _pair()
	var source := pair[0]
	var target := pair[1]
	var changed := {"once": false}
	var move_listener := func(next: RTSUnit.MovementState) -> void:
		if next == RTSUnit.MovementState.TRAVELLING and not changed["once"]:
			changed["once"] = true
			source.combat.issue_attack(target)
	source.movement_state_changed.connect(move_listener)
	source.move_to(Vector3(-23, 0, 16))
	source.movement_state_changed.disconnect(move_listener)
	_check(changed["once"] and source.combat.target_unit() == target, "movement signal replacement cannot be cleared by obsolete move completion")


func _launch(source: RTSUnit, target: RTSUnit) -> GuidedProjectile:
	source.combat.set_physics_process(false) # Isolate exactly one real weapon launch.
	if not Engine.is_in_physics_frame():
		await physics_frame
	_align(source, target)
	var shot := {"projectile": null}
	var listener := func(_target: RTSUnit, projectile: GuidedProjectile) -> void: shot["projectile"] = projectile
	source.combat.weapon.fired.connect(listener)
	var accepted := source.combat.weapon.try_fire(target)
	source.combat.weapon.fired.disconnect(listener)
	_check(accepted and shot["projectile"] != null, "guided weapon fires one visible projectile")
	return shot["projectile"] as GuidedProjectile


func _group_reentrancy_checks() -> void:
	for replacement in ["move", "stop", "attack"]:
		var pair := await _pair(false, 20.0)
		var source := pair[0]
		var target := pair[1]
		var other := field.units[1]
		var target_b := field.units[7]
		field.selection.select_clicked(source, false)
		field.selection.select_clicked(other, true)
		var observed := {"once": false}
		var listener := func(next: CombatController.State) -> void:
			if next != CombatController.State.PURSUING or observed["once"]:
				return
			observed["once"] = true
			if replacement == "move":
				_check(field.issue_move(Vector3(-20, 0, 20)).has_acceptance(), "group dispatch records actual acceptance")
			elif replacement == "stop":
				_check(field.issue_stop().has_acceptance(), "group dispatch records actual acceptance")
			else:
				_check(field.issue_attack(target_b).has_acceptance(), "group dispatch records actual acceptance")
		source.combat.state_changed.connect(listener)
		_check(field.issue_attack(target).has_acceptance(), "group dispatch records actual acceptance")
		source.combat.state_changed.disconnect(listener)
		var coherent: bool = observed["once"]
		for unit in [source, other]:
			coherent = coherent and (unit.combat.target_unit() == target_b if replacement == "attack" else unit.combat.target_unit() == null)
			if replacement == "move":
				coherent = coherent and unit.moving and unit.combat.player_command == CombatController.PlayerCommand.MOVE
			elif replacement == "stop":
				coherent = coherent and not unit.moving and unit.combat.player_command == CombatController.PlayerCommand.STOP
		_check(coherent, "synchronous group " + replacement + " supersedes the entire obsolete attack dispatch")
	for initial in ["move", "stop"]:
		var group := await _pair(false, 20.0)
		var first := group[0]
		var target_a := group[1]
		var second := field.units[1]
		var target_b := field.units[7]
		field.selection.select_clicked(first, false)
		field.selection.select_clicked(second, true)
		_check(field.issue_attack(target_a).has_acceptance(), "group dispatch records actual acceptance")
		var replaced := {"once": false}
		var replace_group := func(next: CombatController.State) -> void:
			if next == CombatController.State.NONE and not replaced["once"]:
				replaced["once"] = true
				_check(field.issue_attack(target_b).has_acceptance(), "group dispatch records actual acceptance")
		first.combat.state_changed.connect(replace_group)
		if initial == "move":
			_check(field.issue_move(Vector3(-20, 0, 20)).has_acceptance(), "group dispatch records actual acceptance")
		else:
			_check(field.issue_stop().has_acceptance(), "group dispatch records actual acceptance")
		first.combat.state_changed.disconnect(replace_group)
		_check(replaced["once"] and first.combat.target_unit() == target_b and second.combat.target_unit() == target_b, "replacement attack supersedes entire synchronous group " + initial)
	var invalid_group := await _pair()
	var member := field.units[1]
	member.combat.weapon.definition = member.combat.weapon.definition.duplicate() as WeaponDefinition
	member.combat.weapon.definition.damage = 0.0
	field.selection.select_clicked(invalid_group[0], false)
	field.selection.select_clicked(member, true)
	_check(not field.issue_attack(invalid_group[1]).has_acceptance() and invalid_group[0].combat.order_version == 0 and member.combat.order_version == 0, "invalid weapon rejects the batch before dispatching any member")
	var pair := await _pair()
	var source := pair[0]
	var target := pair[1]
	source.combat.issue_attack(target)
	var observed := {"coherent": false, "once": false}
	var listener := func(next: CombatController.State) -> void:
		if next == CombatController.State.NONE and not observed["once"]:
			observed["once"] = true
			observed["coherent"] = source.combat.target_unit() == null and source.moving and source.combat.pursuit_elapsed == 0.0
			source.combat.issue_attack(target)
	source.combat.state_changed.connect(listener)
	source.move_to(Vector3(-23, 0, 16))
	source.combat.state_changed.disconnect(listener)
	_check(observed["coherent"] and source.combat.target_unit() == target, "NONE signal observes coherent movement and preserves a synchronous replacement attack")


func _projectile_checks() -> void:
	var pair := await _pair(true, 8.0)
	var source := pair[0]
	var target := pair[1]
	var projectile := await _launch(source, target)
	if projectile == null:
		return
	var launch_position := projectile.global_position
	var result := {"count": 0, "damage": 0.0}
	projectile.resolved.connect(func(amount: float) -> void:
		result["count"] += 1
		result["damage"] += amount)
	_check(target.combat.health.current == 100.0 and get_nodes_in_group("combat_projectiles").size() == 1, "launch creates one projectile and applies no immediate damage")
	await _frames(10)
	_check(projectile.global_position.distance_to(launch_position) > 0.5 and target.combat.health.current == 100.0 and projectile.age > 0.0, "visible projectile travels over simulation time before damage")
	await _capture("combat_projectile_flight")
	source.move_to(Vector3(-24, 0, 16))
	_check(projectile.target_unit() == target and not projectile.spent, "source movement does not cancel or retarget a fired projectile")
	source.combat.issue_attack(field.units[7])
	_check(projectile.target_unit() == target, "replacement source attack leaves original projectile target unchanged")
	source.combat.health.apply_damage(1000.0)
	var flight: WeakRef = weakref(projectile)
	for frame in range(360):
		await physics_frame
		if result["count"] > 0:
			break
	_check(result["count"] == 1 and result["damage"] == 32.0 and target.combat.health.current == 68.0, "projectile hits its original hostile once even after source death")
	await _capture("combat_projectile_impact")
	await _frames(10)
	_check(flight.get_ref() == null and result["count"] == 1 and target.combat.health.current == 68.0, "impact despawns projectile and cannot apply a second hit")
	for invalidation in ["death", "detach", "free", "friendly", "lifetime"]:
		pair = await _pair(true, 8.0)
		source = pair[0]
		target = pair[1]
		if invalidation == "lifetime":
			source.combat.weapon.definition = source.combat.weapon.definition.duplicate() as WeaponDefinition
			source.combat.weapon.definition.projectile_speed = 0.1
			source.combat.weapon.definition.projectile_lifetime = 0.2
		projectile = await _launch(source, target)
		if projectile == null:
			continue
		var outcome := {"count": 0, "damage": 0.0, "age": 0.0}
		projectile.resolved.connect(func(amount: float) -> void:
			outcome["count"] += 1
			outcome["damage"] += amount
			outcome["age"] = projectile.age)
		flight = weakref(projectile)
		if invalidation == "death":
			target.combat.health.apply_damage(1000.0)
		elif invalidation == "detach":
			field.remove_child(target)
		elif invalidation == "free":
			target.queue_free()
		elif invalidation == "friendly":
			target.owner_id = source.owner_id
		await _frames(30)
		_check(flight.get_ref() == null and outcome["count"] == 1 and outcome["damage"] == 0.0, invalidation + ": projectile resolves safely without damage")
		if invalidation == "lifetime":
			_check(outcome["age"] >= 0.2 and outcome["age"] <= 0.2 + 1.0 / 60 + 0.00001, "projectile expiration is bounded by configured simulation lifetime")
		if invalidation in ["detach", "friendly", "lifetime"]:
			_check(target.combat.health.current == 100.0, invalidation + ": target health unchanged by rejected impact")
		if invalidation == "detach":
			target.free()


func _retaliation_checks() -> void:
	var pair := await _pair()
	var source := pair[0]
	var target := pair[1]
	target.combat.retaliation_enabled = true
	_align(source, target)
	await physics_frame
	source.combat.weapon.try_fire(target)
	var version := target.combat.order_version
	_check(target.combat.target_unit() == source and target.combat.player_command == CombatController.PlayerCommand.NONE, "damaged retaliation-enabled hostile attacks valid damage source")
	TeamRules.damage_target(field, source.owner_id, target, 1.0, source)
	await _frames(30)
	_check(target.combat.order_version == version, "retaliation retains one order instead of repeatedly creating orders")
	for invalid_source in ["friendly", "dead", "detached"]:
		pair = await _pair()
		source = pair[0]
		target = pair[1]
		target.combat.retaliation_enabled = true
		if invalid_source == "friendly":
			source.owner_id = target.owner_id
		elif invalid_source == "dead":
			source.combat.health.apply_damage(1000.0)
		else:
			field.remove_child(source)
		target.combat.health.apply_damage(1.0, source)
		_check(target.combat.target_unit() == null and target.combat.order_version == 0, "retaliation rejects " + invalid_source + " damage source")
		if invalid_source == "detached":
			source.free()
	for command in ["move", "stop", "attack"]:
		pair = await _pair()
		source = pair[0]
		target = pair[1]
		source.combat.retaliation_enabled = true
		TeamRules.damage_target(field, target.owner_id, source, 1.0, target)
		_check(source.combat.target_unit() == target, command + ": fixture starts with a retaliation order")
		field.selection.select_clicked(source, false)
		var replacement := field.units[7]
		if command == "move":
			_check(field.issue_move(Vector3(-24, 0, 16)).has_acceptance(), "group dispatch records actual acceptance")
		elif command == "stop":
			_check(field.issue_stop().has_acceptance(), "group dispatch records actual acceptance")
		else:
			_check(field.issue_attack(replacement).has_acceptance(), "group dispatch records actual acceptance")
		version = source.combat.order_version
		TeamRules.damage_target(field, target.owner_id, source, 1.0, target)
		_check(source.combat.order_version == version and (source.combat.target_unit() == replacement if command == "attack" else source.combat.target_unit() == null), "explicit player " + command + " supersedes retaliation and survives new damage")


func _engagement_checks() -> void:
	await _fresh_combat(true)
	var tally := {"damage": 0.0, "deaths": 0}
	for unit in field.units:
		unit.combat.health.damaged.connect(func(amount: float, _source: Node) -> void: tally["damage"] += amount)
		unit.combat.health.died.connect(func(_source: Node) -> void: tally["deaths"] += 1)
		if TeamRules.is_controlled(field, unit, 1):
			field.selection.select_clicked(unit, true)
	_check(field.issue_attack(field.units[6]).is_complete(), "six-player-unit deterministic engagement accepts target")
	var completed := false
	for frame in range(1200):
		await physics_frame
		if tally["deaths"] > 0:
			completed = true
			break
	_check(completed and tally["damage"] >= 100.0 and field.units.size() < 12, "fixed engagement produces observed damage and death before its 20-second deadline")
	await _frames(5)
	_check(get_nodes_in_group("combat_projectiles").is_empty(), "projectiles targeting the destroyed engagement target clean up")
	var survivor := field.selection.selected_units()[0]
	_check(field.issue_move(Vector3(-18, 0, 18)).is_complete() and survivor.combat.target_unit() == null, "survivors accept ordinary group movement after engagement")


func _load_checks() -> void:
	await _fresh_combat(true)
	for index in range(12):
		var unit := (field as CombatField)._create_unit(index)
		unit.unit_id = index + 13
		unit.name = "LoadUnit%02d" % unit.unit_id
		field.add_child(unit)
		field.register_unit(unit)
	var alpha: Array[RTSUnit] = []
	var bravo: Array[RTSUnit] = []
	var tally := {"shots": 0, "damage": 0.0, "deaths": 0}
	for unit in field.units:
		var team := alpha if unit.owner_id == 1 else bravo
		var rank := team.size()
		team.append(unit)
		unit.global_position = Vector3((-1 if unit.owner_id == 1 else 1) * (18 + (rank % 3) * 2.4), 0, -8 + (rank / 3) * 4.8)
		unit.halt_motion()
		unit.combat.weapon.fired.connect(func(_target: RTSUnit, _projectile: GuidedProjectile) -> void: tally["shots"] += 1)
		unit.combat.health.damaged.connect(func(amount: float, _source: Node) -> void: tally["damage"] += amount)
		unit.combat.health.died.connect(func(_source: Node) -> void: tally["deaths"] += 1)
	await _frames(5)
	_check(alpha.size() == 12 and bravo.size() == 12, "load fixture registers twelve units per team with mixed weapons")
	var accepted := true
	for i in range(12):
		accepted = alpha[i].combat.issue_attack(bravo[i]) and accepted
		accepted = bravo[i].combat.issue_attack(alpha[i], false) and accepted
	_check(accepted, "all twenty-four bounded load orders explicitly accepted")
	var intervals := PackedFloat64Array()
	var previous := Time.get_ticks_usec()
	var started := previous
	var peak_projectiles: int = 0
	var maximum_pursuit_updates: int = 0
	var members_alive := true
	for frame in range(720): # Fixed twelve-second endpoint, no auto-acquisition.
		await physics_frame
		var now := Time.get_ticks_usec()
		intervals.append((now - previous) / 1000.0)
		previous = now
		peak_projectiles = maxi(peak_projectiles, get_nodes_in_group("combat_projectiles").size())
		for unit in field.units:
			members_alive = members_alive and unit.is_alive() and field.contains_unit(unit)
			maximum_pursuit_updates = maxi(maximum_pursuit_updates, unit.combat.pursuit_updates)
	intervals.sort()
	var metrics := {"units_at_start": 24, "simulation_seconds": 12, "wall_ms": (Time.get_ticks_usec() - started) / 1000.0, "physics_interval_p95_ms": intervals[int(intervals.size() * 0.95)], "shots": tally["shots"], "damage": tally["damage"], "deaths": tally["deaths"], "survivors": field.units.size(), "peak_projectiles": peak_projectiles, "maximum_pursuit_updates": maximum_pursuit_updates}
	_check(tally["shots"] > 0 and tally["damage"] > 0 and tally["deaths"] > 0, "load endpoint includes firing, damage and deaths")
	_check(members_alive and peak_projectiles <= 32 and maximum_pursuit_updates <= 25, "load has live-only membership and bounded projectile/path work")
	for unit in field.units.duplicate():
		unit.stop()
	await _frames(390) # Every outstanding shot must resolve within its six-second life.
	_check(get_nodes_in_group("combat_projectiles").is_empty(), "all load projectiles disappear after impact or lifetime")
	print("COMBAT_LOAD_METRICS: ", JSON.stringify(metrics))
	DirAccess.make_dir_recursive_absolute("res://validation-output")
	var output := FileAccess.open("res://validation-output/combat-load-metrics.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(metrics, "\t"))
	output.close()
