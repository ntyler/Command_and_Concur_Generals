extends "res://tests/fixtures/fortification_harness.gd"
## Real emitters, spherical flight and health; explicit completed-body fixtures
## isolate geometry. Paid construction/earned gameplay have separate suites.


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1280, 720)
	var logger := EngineErrorProbe.new()
	OS.add_logger(logger)
	for definition in [WALL, GATE]:
		for weapon in ["rifle", "rocket"]:
			await _intended_barrier(definition, weapon, false)
	await _intended_barrier(GATE, "rocket", true)
	await _doorway_obstruction()
	await _inflight_closure()
	await _low_wall_air()
	await _owner_attack_authority()
	if is_instance_valid(field): field.queue_free()
	await _frames(6)
	_check(root.get_children().is_empty() and get_nodes_in_group("combat_projectiles").is_empty(), "fortification combat removes all actors and in-flight shots")
	OS.remove_logger(logger)
	_check(logger.error_count() == 0, "barrier combat has no engine errors or warnings")
	print("FORTIFICATION_COMBAT_CHECKS: %d checks, %d failures; native_errors=%d" % [checks, failures, logger.error_count()])
	quit(0 if failures == 0 else 1)


func _intended_barrier(definition: ConstructionDefinition, kind: String, opening: bool) -> void:
	await _fresh_fort()
	var target := _fort_fixture(definition, Vector3(-14, 0, 16), 2, 0, opening)
	var source := _defense_mobile(Vector3(-14, 0, 21), 1, kind)
	await _until(func() -> bool: return not fort.construction.navigation.blocked, 3, "intended barrier fixture synchronizes navigation")
	var start := target.health.current
	var damage := source.combat.weapon.definition.damage
	var evidence := {"count": 0, "damage": 0.0, "outcome": GuidedProjectile.Outcome.NONE, "contact": Vector3.ZERO, "line": null}
	source.combat.weapon.fired.connect(func(_target: Node3D, projectile: GuidedProjectile) -> void:
		evidence.line = source.combat.weapon.last_fire_line
		if projectile != null:
			projectile.resolved.connect(func(amount: float) -> void:
				evidence.count += 1
				evidence.damage += amount
				evidence.outcome = projectile.outcome
				evidence.contact = projectile.contact_position))
	fort.selection.replace_units([source])
	await physics_frame
	var result := fort.issue_attack(target)
	_check(result.is_complete() and result.accepted_ids == [source.unit_id] and TeamRules.target_domain(target) == TeamRules.TargetDomain.GROUND, "explicit " + kind + " accepts hostile " + target.display_name() + " as ordinary GROUND building")
	if not await _until(func() -> bool: return source.combat.weapon.shots_fired == 1, 3, "ordinary emitter fires at intended barrier contact"): return
	source.stop()
	_check(evidence.line != null and evidence.line.is_clear() and evidence.line.intended_contact, "authoritative clear firing trace ends on exposed barrier geometry")
	if kind == "rocket":
		if not await _until(func() -> bool: return evidence.count == 1, 3, "normal spherical projectile resolves actual barrier contact"): return
		_check(evidence.outcome == GuidedProjectile.Outcome.TARGET and evidence.damage == damage, "intended blocker contact applies exactly one ordinary rocket hit")
		_check(absf(evidence.contact.z - 16.0) < 0.5 and (not opening or absf(evidence.contact.x + 14.0) > 2.9), "projectile contact is on solid wall/closed panel or retained open-gate support")
	_check(target.health.current == start - damage, "intended barrier loses exact configured weapon damage")
	await _frames(60)
	_check(target.health.current == start - damage and (kind != "rocket" or evidence.count == 1), "spent shot cannot apply damage a second time")
	_check(fort.result == BaseAssaultField.Result.RUNNING and _grid_is(1, 0, 0) and _grid_is(2, 10, 8), "barrier damage changes no victory or owner power state")


func _doorway_obstruction() -> void:
	await _fresh_fort()
	var gate := _fort_fixture(GATE, Vector3(-14, 0, 16))
	var source := _defense_mobile(Vector3(-14, 0, 20), 1)
	var target := _defense_mobile(Vector3(-14, 0, 13), 2)
	await _until(func() -> bool: return not fort.construction.navigation.blocked, 3, "closed shot fixture navigation ready")
	_check(source.combat.issue_attack(target), "blocked shot retains normal explicit hostile target")
	await _frames(90)
	_check(source.combat.state == CombatController.State.BLOCKED and source.combat.weapon.shots_fired == 0 and target.combat.health.current == 100 and gate.health.current == 700, "closed friendly gate blocks shots without target damage or invented friendly fire")
	await physics_frame
	_check(gate.request_gate(1, true).accepted, "ordinary owned gate command requests clear opening")
	if not await _until(func() -> bool: return _fort_gate_ready(gate, true), 3, "doorway synchronizes before exposing ready opening"): return
	if not await _until(func() -> bool: return source.combat.weapon.shots_fired == 1, 2, "unchanged explicit target gets actual clear shot through open doorway"): return
	source.stop()
	_check(target.combat.health.current == 88 and gate.health.current == 700, "open doorway passes exact Rifle damage without damaging gate")
	await physics_frame
	var support := fort.fire_query.segment(fort.get_world_3d(), Vector3(-17.5, 0.9, 20), Vector3(-17.5, 0.9, 13))
	var sphere := fort.fire_query.sweep_sphere(fort.get_world_3d(), Vector3(-17.5, 0.9, 20), Vector3(-17.5, 0.9, 13), 0.1)
	_check(support.blocked and sphere.blocked and gate.owns_weapon_collider(support.collider_id) and gate.owns_weapon_collider(sphere.collider_id), "open support remains real hitscan and spherical projectile blocker")


func _inflight_closure() -> void:
	await _fresh_fort()
	var gate := _fort_fixture(GATE, Vector3(-14, 0, 16), 1, 0, true)
	var source := _defense_mobile(Vector3(-14, 0, 22), 1, "rocket")
	var target := _defense_mobile(Vector3(-14, 0, 12), 2)
	await _until(func() -> bool: return not fort.construction.navigation.blocked, 3, "open projectile fixture ready")
	var evidence := {"count": 0, "damage": 0.0, "outcome": GuidedProjectile.Outcome.NONE}
	source.combat.weapon.fired.connect(func(_target: Node3D, projectile: GuidedProjectile) -> void:
		projectile.resolved.connect(func(amount: float) -> void:
			evidence.count += 1
			evidence.damage += amount
			evidence.outcome = projectile.outcome))
	_check(source.combat.issue_attack(target), "Rocket normally targets unit beyond initially open gate")
	if not await _until(func() -> bool: return source.combat.weapon.shots_fired == 1, 3, "normal emitter launches into clear opening"): return
	source.stop()
	await physics_frame
	_check(gate.request_gate(1, false).accepted, "empty doorway can close during existing projectile flight")
	if not await _until(func() -> bool: return evidence.count == 1, 3, "existing spherical shot hits the newly solid closed gate"): return
	_check(evidence.outcome == GuidedProjectile.Outcome.WORLD and evidence.damage == 0 and target.combat.health.current == 100 and gate.health.current == 700, "intervening barrier stops projectile without penetration, collateral damage or target hit")
	await _frames(60)
	_check(evidence.count == 1, "world-blocked spherical shot resolves once")


func _low_wall_air() -> void:
	await _fresh_fort()
	var barrier := _fort_fixture(WALL, Vector3(-20, 0, 16), 2, 90)
	var source := AttackHelicopter.new()
	_defense_next_id += 1
	source.unit_id = _defense_next_id
	source.owner_id = 1
	source.position = Vector3(-24, 8, 16)
	source.combat_weapon = preload("res://weapons/helicopter_rocket.tres")
	fort.add_child(source)
	fort.register_unit(source)
	await _until(func() -> bool: return not fort.construction.navigation.blocked, 3, "low wall navigation synchronizes")
	_check(source.move_to(Vector3(-16, 8, 16)), "normal helicopter flight accepts route above two-high wall")
	if not await _until(func() -> bool: return source.global_position.distance_to(Vector3(-16, 8, 16)) <= source.stopping_distance and not source.moving, 4, "actual aircraft traverses above supported low wall"): return
	await physics_frame
	_check(source.global_position.y == 8 and TeamRules.target_domain(source) == TeamRules.TargetDomain.AIR and fort.flight_plane_clearance(), "aircraft retains actual y8 cruise and full world clearance over barriers")
	var rifle := _defense_mobile(Vector3(-18, 0, 20), 2)
	_check(not TeamRules.can_attack(fort, rifle, source) and TeamRules.can_attack(fort, source, barrier), "ground-to-air restriction and helicopter-to-ground barrier eligibility remain intact")
	_check(source.combat.issue_attack(barrier), "helicopter explicitly targets hostile low wall through ordinary combat")
	if not await _until(func() -> bool: return barrier.health.current < 400, 4, "ordinary elevated guided projectile damages intended low wall"): return
	source.stop()
	_check(barrier.health.current == 376 and source.global_position.y == 8, "single helicopter rocket damages wall24 while aircraft stays airborne")


func _owner_attack_authority() -> void:
	await _fresh_fort()
	var target := _fort_fixture(WALL, Vector3(-14, 0, 16), 1)
	var enemy := _defense_mobile(Vector3(-14, 0, 21), 2)
	var second := _defense_mobile(Vector3(-16, 0, 21), 2)
	var player := _defense_mobile(Vector3(-10, 0, 21), 1)
	await _until(func() -> bool: return not fort.construction.navigation.blocked, 3, "owner-attack fixture ready")
	fort.selection.replace_units([player])
	var selected := fort.selection.selected_units()
	var feedback := fort.last_command_result
	await physics_frame
	var result := fort.issue_attack_for(2, [enemy, player], target)
	_check(result.acceptance == CommandBatchResult.Acceptance.PARTIAL and result.accepted_ids == [enemy.unit_id] and result.intended_ids == [enemy.unit_id, player.unit_id] and result.assignments.is_empty(), "owner explicit attack preserves intended/partial identities without movement assignments")
	_check(fort.selection.selected_units() == selected and fort.last_command_result == feedback and player.combat.target_actor() == null, "enemy attack authority leaves player selection/orders/feedback unchanged")
	enemy.stop()
	var newer := {"once": false, "result": null}
	var callback := func(_state: CombatController.State) -> void:
		if not newer.once:
			newer.once = true
			newer.result = fort.issue_attack_move_for(2, [enemy], Vector3(-12, 0, 21))
	enemy.combat.state_changed.connect(callback)
	result = fort.issue_attack_for(2, [enemy, second], target)
	enemy.combat.state_changed.disconnect(callback)
	_check(result.has_acceptance() and result.superseded and result.accepted_ids == [enemy.unit_id] and enemy.attack_move.parent_order_id == newer.result.generation and second.combat.target_actor() == null, "newer synchronous owner order supersedes older barrier attack without rewriting historical partial acceptance")
