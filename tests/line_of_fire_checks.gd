extends "res://tests/combat_repair_checks.gd"
## Geometry and gameplay observations, using the actual physics/weapon interfaces.


func _run() -> void:
	root.size = Vector2i(1280, 800)
	var logger := EngineErrorProbe.new()
	OS.add_logger(logger)
	var chosen := "all"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--fire-case="): chosen = argument.trim_prefix("--fire-case=")
	var cases := ["hitscan", "restoration", "filtering", "authority", "projectiles", "geometry", "lifecycle", "commands", "pursuit", "load"]
	_check(chosen == "all" or cases.has(chosen), "recognized line-of-fire case")
	for fire_case in cases:
		if chosen != "all" and chosen != fire_case: continue
		var before_checks := checks
		var before_failures := failures
		match fire_case:
			"hitscan": await _fire_hitscan_checks()
			"restoration": await _restoration_checks()
			"filtering": await _filter_checks()
			"authority": await _authority_checks()
			"projectiles": await _rocket_wall_checks()
			"geometry": await _swept_geometry_checks()
			"lifecycle": await _fire_lifecycle_checks()
			"commands": await _blocked_command_checks()
			"pursuit": await _fire_pursuit_checks()
			"load": await _fire_load_checks()
		print("FIRE_CASE: %s; checks=%d; failures=%d" % [fire_case, checks - before_checks, failures - before_failures])
	if is_instance_valid(field): field.queue_free()
	await _frames(3)
	_check(get_nodes_in_group("combat_projectiles").is_empty() and get_nodes_in_group("combat_world_impacts").is_empty(), "scene teardown removes projectiles and impact feedback")
	OS.remove_logger(logger)
	_check(logger.error_count() == 0, "no native errors or warnings through line-of-fire teardown")
	print("LINE_OF_FIRE_CHECKS: %d checks, %d failures; native_errors=%d" % [checks, failures, logger.error_count()])
	quit(0 if failures == 0 else 1)


func _fresh_fire() -> void:
	if is_instance_valid(field):
		field.queue_free()
		await _frames(3)
	field = load("res://scenes/line_of_fire_test.tscn").instantiate() as TestField
	root.add_child(field)
	current_scene = field
	field.camera_rig.edge_scrolling_enabled = false
	await _frames(5)
	await physics_frame
	_check(NavigationServer3D.map_get_iteration_id(field.get_world_3d().get_navigation_map()) > 0 and Engine.is_in_physics_frame(), "fire fixture synchronized in a safe physics step")


func _lane(index: int) -> Array[RTSUnit]:
	await _fresh_fire()
	var source := field.units[index]
	var target := field.units[index + 6]
	_align(source, target)
	return [source, target]


func _solid(size: Vector3, position: Vector3, mask: int = 4 | LineOfFire.BLOCKER_MASK) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = mask
	body.collision_mask = 0
	body.position = position
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	body.add_child(collider)
	field.add_child(body)
	return body


func _fire_hitscan_checks() -> void:
	for lane in [0, 1]:
		var pair := await _lane(lane)
		var source := pair[0]
		var target := pair[1]
		source.combat.set_physics_process(false)
		var weapon := source.combat.weapon
		_check(TeamRules.can_attack(field, source, target) and not source.moving and source.global_position.distance_to(target.global_position) <= weapon.definition.attack_range and source.facing_error(target.global_position) <= deg_to_rad(8) and weapon.cooldown_remaining == 0.0 and weapon.definition == LineOfFireField.RIFLE, "lane satisfies all non-obstruction firing prerequisites with the same rifle")
		var events := {"fired": 0}
		weapon.fired.connect(func(_target: RTSUnit, _rocket: GuidedProjectile) -> void: events["fired"] += 1)
		var accepted := weapon.try_fire(target)
		if lane == 0:
			_check(accepted and events["fired"] == 1 and weapon.shots_fired == 1 and target.combat.health.current == 88.0, "clear lane commits one immediate hitscan")
			_check(get_nodes_in_group("combat_tracers").size() == 1, "successful hitscan produces its tracer")
		else:
			_check(not accepted and weapon.last_fire_line.blocked and weapon.last_fire_line.collider_id != 0 and absf(weapon.last_fire_line.position.x + 5.15) < 0.001, "blocked rifle returns actual wall contact evidence")
			for attempt in range(100): accepted = weapon.try_fire(target) or accepted
			_check(not accepted and target.combat.health.current == 100.0 and weapon.shots_fired == 0 and weapon.cooldown_remaining == 0.0 and events["fired"] == 0, "repeated blocked attempts commit no damage, shots, cooldown or notification")
			_check(get_nodes_in_group("combat_tracers").is_empty() and get_nodes_in_group("combat_projectiles").is_empty(), "blocked attempts create no successful visuals or projectiles")
	await _fresh_fire()
	await _capture("fire_initial_lanes")


func _restoration_checks() -> void:
	var pair := await _lane(1)
	var source := pair[0]
	var target := pair[1]
	_check(source.combat.issue_attack(target), "blocked attack is accepted without invalidating hostility")
	await _frames(3)
	var version := source.combat.order_version
	var moving_version := source.order_version
	var origin := source.global_position
	_check(source.combat.state == CombatController.State.BLOCKED and source.combat.feedback.fire_blocked and source.combat.fire_line.blocked and not source.moving, "blocked state and visible feedback are coherent")
	var queries := field.fire_query.clearance_queries
	var notices := {"count": 0}
	var notice := func(_state: int) -> void: notices["count"] += 1
	source.combat.state_changed.connect(notice)
	await _frames(180)
	source.combat.state_changed.disconnect(notice)
	_check(source.global_position == origin and source.order_version == moving_version and source.combat.order_version == version and source.combat.target_unit() == target and source.recovery_attempts == 0 and source.combat.pursuit_elapsed == 0.0, "intentional holding retains target/order without movement recovery or pursuit time")
	_check(field.fire_query.clearance_queries - queries <= 17 and notices["count"] == 0, "blocked clearance is interval-bounded without repeated identical notifications")
	field.set_movement_debug(true)
	await _frames(15)
	await _capture("fire_blocked_debug")
	field.set_movement_debug(false)
	_check(not source.combat.feedback._fire_segment.visible and not source.combat.feedback._fire_contact.visible, "F3 fire debug hides independently of gameplay blocked feedback")
	_check(target.move_to(Vector3(-2, 0, -7)), "target moves through the opening using ordinary navigation")
	var first_clear := -1
	var first_shot := -1
	var ready_when_clear := false
	for frame in range(180):
		await physics_frame
		if first_clear < 0 and field.fire_query.firing_line(source, target).is_clear():
			first_clear = frame
			ready_when_clear = source.facing_error(target.global_position) <= deg_to_rad(8) and source.combat.weapon.cooldown_remaining == 0.0
		if source.combat.weapon.shots_fired > 0:
			first_shot = frame
			break
	print("CLEARANCE_RESTORED: clear_frame=%d shot_frame=%d interval=%.3f" % [first_clear, first_shot, source.combat.blocked_recheck_interval])
	_check(first_clear >= 0 and ready_when_clear and first_shot >= first_clear and first_shot - first_clear <= ceili(source.combat.blocked_recheck_interval * 60) + 2, "ready attacker resumes within recheck interval plus physics scheduling")
	_check(source.combat.order_version == version and source.combat.target_unit() == target and target.combat.health.current == 88.0 and not source.combat.feedback.fire_blocked, "retained attack resumes damage without a new player order")
	# Return to the wall during the real shot's cooldown; blocked checks never restart it.
	target.global_position = LineOfFireField.STARTS[7]
	target.halt_motion()
	await _frames(15)
	var cooldown := source.combat.weapon.cooldown_remaining
	_check(source.combat.state == CombatController.State.BLOCKED and cooldown > 0.0 and cooldown < 0.75, "existing cooldown continues while a newly obstructed target is held")
	await _frames(45)
	_check(source.combat.weapon.cooldown_remaining == 0.0 and source.combat.weapon.shots_fired == 1 and target.combat.health.current == 88.0, "blocked rechecks neither restart cooldown nor fire through the wall")


func _filter_checks() -> void:
	for lane in [0, 2, 3]:
		var pair := await _lane(lane)
		for reverse in [false, true]:
			var source := pair[1] if reverse else pair[0]
			var target := pair[0] if reverse else pair[1]
			_align(source, target)
			_check(source.combat.weapon.try_fire(target), "clear/opening/wall-behind geometry supports direction: lane=%d reverse=%s" % [lane, reverse])
	var pair := await _lane(0)
	var source := pair[0]
	var target := pair[1]
	var interloper := field.units[1]
	interloper.global_position = (source.global_position + target.global_position) * 0.5
	interloper.halt_motion()
	_solid(Vector3(0.2, 2, 2), interloper.global_position + Vector3.RIGHT + Vector3.UP, 4) # Explicitly unmarked decoration.
	await _frames(3)
	await physics_frame
	_check(source.combat.weapon.try_fire(target) and target.combat.health.current == 88 and interloper.combat.health.current == 100, "self, non-target units and unmarked decorative collision do not intercept fire")
	for attachment_only in [false, true]:
		pair = await _lane(0)
		source = pair[0]
		target = pair[1]
		var body := _solid(Vector3(1, 0.02, 1) if attachment_only else Vector3(1, 2, 1), source.global_position + Vector3.UP * (0.75 if attachment_only else 0.9))
		await _frames(3)
		await physics_frame
		_check(not source.combat.weapon.try_fire(target) and source.combat.weapon.last_fire_line.blocked and source.combat.weapon.last_fire_line.collider_id == body.get_instance_id() and target.combat.health.current == 100, "origin-inside/body-to-muzzle obstruction fails safely: attachment=" + str(attachment_only))


func _authority_checks() -> void:
	var pair := await _lane(0)
	var source := pair[0]
	var target := pair[1]
	await process_frame
	var queries := field.fire_query.physics_queries
	_check(not source.combat.weapon.try_fire(target) and field.fire_query.physics_queries == queries and target.combat.health.current == 100, "out-of-physics direct firing is rejected without an unsafe query")
	pair = await _lane(1)
	source = pair[0]
	target = pair[1]
	target.global_position = Vector3(-2, 0, -7)
	target.halt_motion()
	_align(source, target)
	var observed := {"clear": false, "ready": false}
	var replace_geometry := func(next: int) -> void:
		if next != CombatController.State.ATTACKING: return
		observed["clear"] = source.combat.fire_line.is_clear()
		target.global_position = LineOfFireField.STARTS[7]
		target.halt_motion()
		_align(source, target)
		observed["ready"] = source.combat.weapon.cooldown_remaining == 0.0 and source.global_position.distance_to(target.global_position) < 8 and source.facing_error(target.global_position) < 0.001
	source.combat.issue_attack(target)
	source.combat.state_changed.connect(replace_geometry, CONNECT_ONE_SHOT)
	await _frames(3)
	_check(observed["clear"] and observed["ready"] and source.combat.state == CombatController.State.BLOCKED and source.combat.fire_line.blocked, "fresh emitter query rejects stale clear controller evidence after callback")
	_check(source.combat.weapon.shots_fired == 0 and source.combat.weapon.cooldown_remaining == 0.0 and target.combat.health.current == 100, "stale clearance cannot authorize damage or cooldown commitment")


func _observe(projectile: GuidedProjectile) -> Dictionary:
	var observation := {"count": 0, "damage": 0.0, "outcome": GuidedProjectile.Outcome.NONE, "position": Vector3.ZERO, "terminal_coherent": false}
	projectile.resolved.connect(func(applied: float) -> void:
		observation["count"] += 1
		observation["damage"] = applied
		observation["outcome"] = projectile.outcome
		observation["position"] = projectile.contact_position
		observation["terminal_coherent"] = projectile.spent and projectile.is_queued_for_deletion()
		projectile._physics_process(1.0) # Deliberate reentry after terminal commitment.
		projectile._finish(GuidedProjectile.Outcome.EXPIRED))
	return observation


func _rocket_wall_checks() -> void:
	var pair := await _lane(4)
	var source := pair[0]
	var target := pair[1]
	var initial_health := target.combat.health.current
	var rocket := await _launch(source, target)
	if rocket == null: return
	var observed := _observe(rocket)
	_check(target.combat.health.current == initial_health, "clear rocket launch has no immediate damage")
	_check(target.move_to(Vector3(0, 0, 14)), "rocket target navigates behind the existing shadow wall after launch")
	for frame in range(120):
		await physics_frame
		if observed["count"] > 0: break
	_check(observed["count"] == 1 and observed["outcome"] == GuidedProjectile.Outcome.WORLD and observed["damage"] == 0 and target.combat.health.current == initial_health, "homing rocket hits the wall rather than damaging its moving target")
	_check(observed["terminal_coherent"] and absf(observed["position"].x + 4.15) < 0.001, "world outcome commits before callbacks at the detected contact")
	var sparks := get_nodes_in_group("combat_world_impacts")
	_check(sparks.size() == 1 and sparks[0].global_position.distance_to(observed["position"]) < 0.001, "world-impact presentation is located at contact")
	await _capture("fire_rocket_world_impact")
	await _frames(15)
	_check(not is_instance_valid(rocket) and get_nodes_in_group("combat_world_impacts").is_empty(), "world impact removes rocket and bounded visual feedback")
	pair = await _lane(4)
	source = pair[0]
	target = pair[1]
	target.global_position = Vector3(0, 0, 14)
	target.halt_motion()
	_align(source, target)
	_check(not source.combat.weapon.try_fire(target) and source.combat.weapon.last_fire_line.blocked and get_nodes_in_group("combat_projectiles").is_empty() and source.combat.weapon.shots_fired == 0 and source.combat.weapon.cooldown_remaining == 0.0, "blocked rocket launch creates no projectile or new cooldown")


func _isolated_rocket(source: RTSUnit, target: RTSUnit, origin: Vector3, speed: float, life: float = 6.0) -> GuidedProjectile:
	var definition := LineOfFireField.ROCKET.duplicate() as WeaponDefinition
	definition.projectile_speed = speed
	definition.projectile_lifetime = life
	var rocket := GuidedProjectile.new()
	rocket.configure(field, source, target, definition)
	rocket.position = origin
	rocket.set_physics_process(false) # Advance the real implementation exactly one tick.
	field.add_child(rocket)
	return rocket


func _swept_geometry_checks() -> void:
	for fixture in ["thin", "target_first", "near_wall", "inside", "tie", "expiry"]:
		var pair := await _lane(5)
		var source := pair[0]
		var target := pair[1]
		var origin := Vector3(16, 0.75, 12)
		var speed := 600.0
		var life := 6.0
		target.global_position = Vector3(20, 0, 12)
		match fixture:
			"target_first": target.global_position.x = 17.0
			"near_wall":
				target.global_position.x = 18.03
				origin.x = 17.98
				speed = 1.5
			"inside": origin.x = 18.01
			"tie": target.global_position.x = 18.0
			"expiry": life = 1.0 / 60.0
		target.halt_motion()
		var rocket := _isolated_rocket(source, target, origin, speed, life)
		var observed := _observe(rocket)
		rocket._physics_process(1.0 / 60.0)
		var expected := GuidedProjectile.Outcome.TARGET if fixture == "target_first" else GuidedProjectile.Outcome.WORLD
		if fixture == "expiry": expected = GuidedProjectile.Outcome.EXPIRED
		_check(observed["count"] == 1 and observed["outcome"] == expected and observed["terminal_coherent"], fixture + ": segment ordering resolves exactly once with terminal state committed")
		_check(target.combat.health.current == (118.0 if expected == GuidedProjectile.Outcome.TARGET else 150.0) and observed["damage"] == (32.0 if expected == GuidedProjectile.Outcome.TARGET else 0.0), fixture + ": only earlier target impact applies one hit")
		if expected == GuidedProjectile.Outcome.WORLD:
			_check(absf(observed["position"].x - (18.01 if fixture == "inside" else 18.0)) < 0.001, fixture + ": actual contact stops at thin wall or the contained origin")
		if fixture == "thin":
			_check(speed / 60.0 > 0.02 and rocket.last_segment_end == LineOfFire.aim(target), "ten-meter step is clamped to target yet detects the twenty-millimeter wall")
		await _frames(2)
		_check(not is_instance_valid(rocket) and observed["count"] == 1, fixture + ": terminal projectile is removed without a second resolution")


func _fire_lifecycle_checks() -> void:
	for change in ["replace", "source_death", "source_free", "target_death", "target_detach", "target_queue", "target_free", "source_free_world"]:
		var pair := await _lane(4)
		var source := pair[0]
		var target := pair[1]
		var rocket := await _launch(source, target)
		if rocket == null: continue
		var observed := _observe(rocket)
		match change:
			"replace":
				source.move_to(Vector3(-12, 0, 4))
				source.combat.issue_attack(field.units[11])
				_check(rocket.target_unit() == target, "source movement and replacement preserve immutable projectile target")
			"source_death": source.combat.health.apply_damage(1000.0)
			"source_free", "source_free_world": source.free()
			"target_death": target.combat.health.apply_damage(1000.0)
			"target_detach": field.remove_child(target)
			"target_queue": target.queue_free()
			"target_free": target.free()
		if change == "source_free_world": target.move_to(Vector3(0, 0, 14))
		for frame in range(120):
			await physics_frame
			if observed["count"] > 0: break
		var expected := GuidedProjectile.Outcome.INVALIDATED if change.begins_with("target_") else GuidedProjectile.Outcome.TARGET
		if change == "source_free_world": expected = GuidedProjectile.Outcome.WORLD
		_check(observed["count"] == 1 and observed["outcome"] == expected and observed["terminal_coherent"], change + ": correct exclusive terminal outcome survives lifecycle change")
		_check(observed["damage"] == (32.0 if expected == GuidedProjectile.Outcome.TARGET else 0.0), change + ": launch ownership applies damage only to the original valid target")
		if is_instance_valid(target) and target.is_alive():
			_check(target.combat.health.current == (118.0 if expected == GuidedProjectile.Outcome.TARGET else 150.0), change + ": externally observed health matches resolution")
		if change == "target_detach": target.free()
		await _frames(15)
		_check(not is_instance_valid(rocket) and get_nodes_in_group("combat_world_impacts").is_empty(), change + ": projectile and feedback cleanup finishes")
	var pair := await _lane(4)
	var rocket := await _launch(pair[0], pair[1])
	var reference: WeakRef = weakref(rocket)
	field.queue_free()
	await _frames(3)
	_check(reference.get_ref() == null and get_nodes_in_group("combat_projectiles").is_empty(), "scene teardown removes a live in-flight projectile")


func _blocked_command_checks() -> void:
	for replacement in ["move", "stop", "attack", "listener"]:
		var pair := await _lane(1)
		var source := pair[0]
		var target := pair[1]
		field.selection.select_clicked(source, false)
		var historical := field.issue_attack(target)
		var version := source.combat.order_version
		await _frames(3)
		_check(_complete(historical) and source.combat.state == CombatController.State.BLOCKED, replacement + ": accepted attack reaches coherent blocked holding")
		var captured := {"coherent": false, "batch": null}
		match replacement:
			"move": captured["batch"] = field.issue_move(Vector3(-8, 0, -7))
			"stop":
				_key_x()
				await _frames(2) # Viewport input dispatch completes before observing Stop.
			"attack":
				field.units[6].global_position = Vector3(-8, 0, -6)
				field.units[6].halt_motion()
				captured["batch"] = field.issue_attack(field.units[6])
			"listener":
				source.combat.issue_stop()
				source.combat.state_changed.connect(func(next: int) -> void:
					if next != CombatController.State.BLOCKED or captured["coherent"]: return
					captured["coherent"] = not source.moving and source.combat.target_unit() == target and source.combat.fire_line.blocked and source.combat.feedback.fire_blocked
					captured["batch"] = field.issue_move(Vector3(-8, 0, -7)))
				field.issue_attack(target)
				await _frames(3)
		_check(source.combat.order_version > version and not source.combat.feedback.fire_blocked and source.combat.state != CombatController.State.BLOCKED, replacement + ": new command clears blocked status")
		_check(source.combat.target_unit() == (field.units[6] if replacement == "attack" else null), replacement + ": newer target or cancellation remains authoritative")
		if replacement == "listener": _check(captured["coherent"], "synchronous blocked listener observes coherent state before replacing it")
		if captured["batch"] != null:
			_check(_complete(captured["batch"]) and _complete(historical), "later command preserves historical batch acceptance")
			if replacement != "attack":
				var assignments: Dictionary = captured["batch"].assignments.duplicate()
				await _frames(3)
				_check(captured["batch"].assignments == assignments and assignments.has(source.unit_id), "captured move assignments survive subsequent physics")
		await _frames(10)
		_check(target.combat.health.current == 100 and source.combat.state != CombatController.State.BLOCKED, replacement + ": obsolete blocked order cannot resume or damage old target")
	for invalidation in ["friendly", "death", "detach", "free"]:
		var pair := await _lane(1)
		var source := pair[0]
		var target := pair[1]
		source.combat.issue_attack(target)
		await _frames(3)
		match invalidation:
			"friendly": target.owner_id = source.owner_id
			"death": target.combat.health.apply_damage(1000)
			"detach": field.remove_child(target)
			"free": target.free()
		await _frames(3)
		_check(source.combat.target_unit() == null and source.combat.fire_line == null and not source.combat.feedback.fire_blocked and not source.moving, invalidation + ": blocked targeting and cached geometry clear on invalidation")
		if invalidation == "detach": target.free()
	# Independent historical acceptance/supersession assertions; no copied algorithm.
	await _batch_checks()


func _fire_pursuit_checks() -> void:
	var pair := await _lane(1)
	var source := pair[0]
	var target := pair[1]
	target.global_position = Vector3(5, 0, -12)
	target.halt_motion()
	var origin := source.global_position
	_check(source.combat.issue_attack(target), "out-of-range obstructed hostile remains a valid attack target")
	await _frames(10)
	_check(source.moving and source.combat.state == CombatController.State.PURSUING and source.global_position.distance_to(origin) > 0.1 and source.combat.pursuit_updates == 1, "out-of-range order advances using existing navigation pursuit")
	_check(field.fire_query.clearance_queries == 0, "out-of-range pursuit does not perform unnecessary clearance checks")
	pair = await _lane(1)
	source = pair[0]
	target = pair[1]
	source.combat.issue_attack(target)
	await _frames(3)
	target.global_position = source.global_position + Vector3.RIGHT * 8.5
	target.halt_motion()
	await _frames(3)
	_check(not source.moving and source.combat.state == CombatController.State.FACING and not source.combat.feedback.fire_blocked, "existing hysteresis holds outside exact firing range without reporting blocked fire")
	target.global_position.x += 1.0
	target.halt_motion()
	await _frames(3)
	_check(source.moving and source.combat.state == CombatController.State.PURSUING and source.combat.target_unit() == target, "target leaving hysteresis resumes ordinary pursuit with retained target")
	await _retarget_checks() # Existing bounded moving-target recovery regressions.


func _fire_load_checks() -> void:
	await _fresh_fire()
	for unit in field.units.duplicate(): unit.queue_free()
	await _frames(3)
	var alpha: Array[RTSUnit] = []
	var bravo: Array[RTSUnit] = []
	var tally := {"shots": 0, "damage": 0.0, "deaths": 0}
	for team_id in [1, 2]:
		for rank in range(12):
			var unit := RTSUnit.new()
			unit.unit_id = (team_id - 1) * 12 + rank + 1
			unit.owner_id = team_id
			unit.position = Vector3(-8 if team_id == 1 else -2, 0, -18 + rank * 3.2)
			unit.combat_weapon = LineOfFireField.ROCKET if rank % 3 == 0 else LineOfFireField.RIFLE
			unit.maximum_health = 150 if rank % 3 == 0 else 100
			field.add_child(unit)
			field.register_unit(unit)
			(alpha if team_id == 1 else bravo).append(unit)
			unit.combat.weapon.fired.connect(func(_target: RTSUnit, _projectile: GuidedProjectile) -> void: tally["shots"] += 1)
			unit.combat.health.damaged.connect(func(amount: float, _source: Node) -> void: tally["damage"] += amount)
			unit.combat.health.died.connect(func(_source: Node) -> void: tally["deaths"] += 1)
	await _frames(5)
	var accepted := true
	for rank in range(12):
		_align(alpha[rank], bravo[rank])
		_align(bravo[rank], alpha[rank])
		accepted = alpha[rank].combat.issue_attack(bravo[rank]) and accepted
		accepted = bravo[rank].combat.issue_attack(alpha[rank]) and accepted
	_check(accepted and field.units.size() == 24, "mixed load accepts twenty-four explicit paired attacks")
	var peak := 0
	var blocked_seen := 0
	var maximum_updates := 0
	var members_alive := true
	var started := Time.get_ticks_usec()
	for frame in range(720):
		await physics_frame
		peak = maxi(peak, get_nodes_in_group("combat_projectiles").size())
		var blocked := 0
		for unit in field.units:
			members_alive = members_alive and unit.is_alive() and field.contains_unit(unit)
			maximum_updates = maxi(maximum_updates, unit.combat.pursuit_updates)
			if unit.combat.state == CombatController.State.BLOCKED: blocked += 1
		blocked_seen = maxi(blocked_seen, blocked)
	var query_limit := 24 * (ceili(12.0 / 0.2) + ceili(12.0 / 0.75) + 3)
	var metrics := {"units_at_start": 24, "simulation_seconds": 12, "wall_ms": (Time.get_ticks_usec() - started) / 1000.0, "shots": tally["shots"], "damage": tally["damage"], "deaths": tally["deaths"], "survivors": field.units.size(), "peak_projectiles": peak, "active_projectiles": get_nodes_in_group("combat_projectiles").size(), "peak_blocked_units": blocked_seen, "maximum_pursuit_updates": maximum_updates, "clearance_queries": field.fire_query.clearance_queries, "clearance_query_limit": query_limit, "segment_queries": field.fire_query.segment_queries, "physics_queries": field.fire_query.physics_queries}
	_check(tally["shots"] > 0 and tally["damage"] > 0 and tally["deaths"] > 0 and blocked_seen > 0, "load observes firing, damage, deaths and intentional blocked holding")
	_check(members_alive and peak <= 32 and maximum_updates == 0, "load preserves live membership, bounded projectiles and no unnecessary move dispatch")
	_check(field.fire_query.clearance_queries <= query_limit, "controller rechecks plus committed attempts have bounded query cost")
	for unit in field.units.duplicate(): unit.stop()
	await _frames(390)
	_check(get_nodes_in_group("combat_projectiles").is_empty() and get_nodes_in_group("combat_world_impacts").is_empty(), "load cleanup leaves no projectile or world-impact nodes")
	print("FIRE_LOAD_METRICS: ", JSON.stringify(metrics))
	DirAccess.make_dir_recursive_absolute("res://validation-output")
	var output := FileAccess.open("res://validation-output/fire-load-metrics.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(metrics, "\t"))
	output.close()
