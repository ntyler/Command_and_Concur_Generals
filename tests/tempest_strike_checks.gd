extends "res://tests/fixtures/tempest_harness.gd"
## Fixed-step commitment, one safe impact snapshot, counterplay and result
## lifecycle. Short configured charge/warnings are declared isolated fixtures;
## timing explicitly exercises the real six-second warning independently.


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1280, 720)
	var logger := EngineErrorProbe.new()
	OS.add_logger(logger)
	var chosen := "all"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--tempest-strike-case="): chosen = argument.trim_prefix("--tempest-strike-case=")
	var cases := ["commit", "timing", "damage", "escape", "callbacks", "results"]
	_check(chosen == "all" or cases.has(chosen), "recognized Tempest strike case")
	for case in cases:
		if chosen != "all" and chosen != case: continue
		var before := checks
		var failed := failures
		match case:
			"commit": await _tempest_commit_checks()
			"timing": await _tempest_timing_checks()
			"damage": await _tempest_damage_checks()
			"escape": await _tempest_escape_checks()
			"callbacks": await _tempest_callback_checks()
			"results": await _tempest_result_checks()
		print("TEMPEST_STRIKE_CASE: %s checks=%d failures=%d" % [case, checks - before, failures - failed])
	if is_instance_valid(field): field.queue_free()
	await _frames(6)
	_check(root.get_children().is_empty() and get_nodes_in_group("combat_projectiles").is_empty(), "strike teardown removes warnings, scheduled impacts, fields and old callbacks")
	OS.remove_logger(logger)
	_check(logger.error_count() == 0, "strike authority and callback lifecycle have no native errors or warnings")
	print("TEMPEST_STRIKE_CHECKS: %d checks, %d failures; native_errors=%d" % [checks, failures, logger.error_count()])
	quit(0 if failures == 0 else 1)


func _tempest_impact(id: int, seconds: float = 1.0) -> bool:
	return await _until(func() -> bool: return tempest.tempest_strikes.strike_snapshot(id).get("state") == "impacted", seconds, "accepted strike reaches its authoritative single impact")


func _tempest_commit_checks() -> void:
	await _fresh_tempest()
	_tempest_power()
	var source := _tempest_fixture(TEMPEST_POINT, 1, 0.2)
	var target := _tempest_ground(TEMPEST_TARGET)
	await physics_frame
	var result := tempest.tempest_strikes.launch(source, 1, TEMPEST_TARGET)
	_check(not result.accepted and source.charge == 0 and tempest.tempest_strikes.pending_count() == 0, "uncharged source rejects without side effects")
	if not await _tempest_ready(source): return
	var wallet := tempest.credits.balance(1)
	await physics_frame
	for request in [{"owner": 2, "target": TEMPEST_TARGET}, {"owner": 99, "target": TEMPEST_TARGET}, {"owner": 1, "target": Vector3(1000, 0, 0)}, {"owner": 1, "target": Vector3(NAN, 0, 0)}]:
		result = tempest.tempest_strikes.launch(source, request.owner, request.target)
		_check(not result.accepted and not result.reason.is_empty() and source.is_ready() and tempest.tempest_strikes.pending_count() == 0 and tempest.credits.balance(1) == wallet, "invalid ownership or target preserves charge, credits and strike state")
	var notifications: Array[int] = []
	var repeats: Array[Dictionary] = []
	var observed: Array[bool] = []
	var on_commit := func(id: int) -> void:
		notifications.append(id)
		observed.append(source.charge == 0 and tempest.tempest_strikes.pending_count() == 1 and tempest.tempest_strikes.strike_snapshot(id).state == "warning")
		repeats.append(tempest.tempest_strikes.launch(source, 1, TEMPEST_TARGET + Vector3.RIGHT))
	tempest.tempest_strikes.strike_committed.connect(on_commit)
	result = tempest.tempest_strikes.launch(source, 1, TEMPEST_TARGET)
	var duplicate := tempest.tempest_strikes.launch(source, 1, TEMPEST_TARGET)
	tempest.tempest_strikes.strike_committed.disconnect(on_commit)
	_check(result.accepted and result.strike_id > 0 and not duplicate.accepted and repeats.size() == 1 and not repeats[0].accepted and notifications == [result.strike_id] and observed == [true], "double and synchronous reentrant launch see coherent committed state and cannot spend one charge twice")
	_check(source.charge == 0 and tempest.credits.balance(1) == wallet and target.combat.health.current == 1500, "commit resets charge without charging credits or dealing early damage")
	var strike := tempest.tempest_strikes.strike_snapshot(result.strike_id)
	_check(strike.target == TEMPEST_TARGET and strike.owner_id == 1 and strike.state == "warning" and tempest.tempest_strikes.warning_markers().size() == 1, "one match-scoped warning captures stable ID, original owner and fixed target")
	source.owner_id = 2
	_check(tempest.tempest_strikes.strike_snapshot(result.strike_id).owner_id == 1, "source ownership change cannot rewrite committed attribution")
	await _fresh_tempest()
	_tempest_power()
	source = _tempest_fixture(TEMPEST_POINT, 1, 0.1, 0.1)
	if not await _tempest_ready(source): return
	var edge := Vector3(tempest.field_bounds.end.x - 0.1, 0, tempest.field_bounds.end.y - 0.1)
	await physics_frame
	result = tempest.tempest_strikes.launch(source, 1, edge)
	_check(result.accepted and tempest.tempest_strikes.strike_snapshot(result.strike_id).target == edge, "in-bounds center accepts radius beyond map edges without silently moving the center")
	await _tempest_impact(result.strike_id)
	# Current power publication may synchronously invalidate an otherwise ready
	# source; the commit must revalidate after that callback before consuming it.
	await _fresh_tempest()
	_tempest_power()
	source = _tempest_fixture(TEMPEST_POINT, 1, 0.1)
	if not await _tempest_ready(source): return
	var changed := {"called": false}
	var change_owner := func() -> void:
		if not changed.called:
			changed.called = true
			source.owner_id = 2
	tempest.power_grid.changed.connect(change_owner)
	await physics_frame
	_power_fixture_building(POWER_PLANT, 1, Vector3(-3, 0, 3))
	result = tempest.tempest_strikes.launch(source, 1, TEMPEST_TARGET)
	tempest.power_grid.changed.disconnect(change_owner)
	_check(changed.called and not result.accepted and source.is_ready() and tempest.tempest_strikes.pending_count() == 0, "synchronous grid callback ownership change rejects stale source commitment without consuming readiness")


func _tempest_timing_checks() -> void:
	await _fresh_tempest()
	var plants := _tempest_power()
	var source := _tempest_fixture(TEMPEST_POINT, 1, 0.2, 6.0)
	var target := _tempest_ground(TEMPEST_TARGET)
	var hit_ticks: Array[int] = []
	var hit_sources: Array[Dictionary] = []
	target.combat.health.damaged.connect(func(_amount: float, attribution: Node) -> void:
		hit_ticks.append(Engine.get_physics_frames())
		hit_sources.append({"valid": is_instance_valid(attribution), "owner": attribution.get("owner_id") if is_instance_valid(attribution) else -1}))
	if not await _tempest_ready(source): return
	await physics_frame
	var result := tempest.tempest_strikes.launch(source, 1, TEMPEST_TARGET)
	var began := Engine.get_physics_frames()
	_check(result.accepted and tempest.tempest_strikes.pending_count() == 1 and target.combat.health.current == 1500, "real six-second warning starts without immediate damage")
	source.health.apply_damage(1200)
	for plant in plants: plant.health.apply_damage(10000)
	await _frames(354)
	var elapsed := float(Engine.get_physics_frames() - began) / Engine.physics_ticks_per_second
	var warning := tempest.tempest_strikes.strike_snapshot(result.strike_id)
	_check(elapsed < 6 and warning.state == "warning" and warning.remaining > 0 and target.combat.health.current == 1500 and hit_ticks.is_empty(), "5.9 simulated seconds of visible warning deal no damage despite source destruction and power loss")
	if not await _tempest_impact(result.strike_id, 0.2): return
	var hit_elapsed := float(hit_ticks[0] - began) / Engine.physics_ticks_per_second if not hit_ticks.is_empty() else -1.0
	print("TEMPEST_REAL_WARNING: simulation_seconds=%.6f warning=6.000000 commit_tick=%d hit_tick=%s priority=500" % [hit_elapsed, began, hit_ticks])
	_check(hit_ticks.size() == 1 and absf(hit_elapsed - 6.0) <= 0.017 and target.combat.health.current == 500 and hit_sources == [{"valid": true, "owner": 1}], "actual six-second impact deals one1000-damage event with safe captured owner attribution after source destruction")
	_check(tempest.result == BaseAssaultField.Result.RUNNING and tempest.tempest_strikes.pending_count() == 0 and tempest.tempest_strikes.warning_markers().is_empty(), "ongoing-match committed strike survives source/power loss and removes terminal warning")
	await _frames(120)
	_check(hit_ticks.size() == 1 and target.combat.health.current == 500, "terminal strike never reapplies damage on later ticks")


func _tempest_damage_checks() -> void:
	await _fresh_tempest()
	_tempest_power()
	var source := _tempest_fixture(TEMPEST_POINT, 1, 0.1, 0.5)
	var enemy := _tempest_ground(TEMPEST_TARGET)
	var friendly := _tempest_ground(TEMPEST_TARGET + Vector3.LEFT * 2, 1)
	var boundary := _tempest_ground(TEMPEST_TARGET + Vector3.RIGHT * 10)
	var outside := _tempest_ground(TEMPEST_TARGET + Vector3.RIGHT * 10.01)
	var cover_target := _tempest_ground(TEMPEST_TARGET + Vector3.RIGHT * 3)
	var moving_in := _tempest_ground(TEMPEST_TARGET + Vector3.FORWARD * 12)
	var moving_out := _tempest_ground(TEMPEST_TARGET + Vector3.FORWARD * 5)
	var counts := {"enemy": 0, "friendly": 0, "boundary": 0, "covered": 0}
	enemy.combat.health.damaged.connect(func(_amount: float, _source: Node) -> void: counts.enemy += 1)
	friendly.combat.health.damaged.connect(func(_amount: float, _source: Node) -> void: counts.friendly += 1)
	boundary.combat.health.damaged.connect(func(_amount: float, _source: Node) -> void: counts.boundary += 1)
	cover_target.combat.health.damaged.connect(func(_amount: float, _source: Node) -> void: counts.covered += 1)
	var extra_collider := CollisionShape3D.new()
	extra_collider.shape = RTSUnit.body_shape()
	enemy.add_child(extra_collider)
	var wall := _fort_fixture(WALL, TEMPEST_TARGET + Vector3.RIGHT * 1.6, 1, 90)
	var cache := SupplyCache.new()
	cache.initial_supplies = 77
	cache.cache_id = 90
	cache.position = TEMPEST_TARGET + Vector3.BACK * 3
	tempest.add_child(cache)
	tempest.register_cache(cache)
	var decoration := Node3D.new()
	decoration.position = TEMPEST_TARGET
	tempest.add_child(decoration)
	var decoration_health := UnitHealth.new()
	decoration_health.maximum = 90
	decoration.add_child(decoration_health)
	var unfinished := _tempest_fixture(TEMPEST_TARGET + Vector3.LEFT * 5, 2, 1)
	unfinished.operational = false
	var helicopter := AttackHelicopter.new()
	_defense_next_id += 1
	helicopter.unit_id = _defense_next_id
	helicopter.owner_id = 2
	helicopter.position = TEMPEST_TARGET + Vector3(0, 2, 2)
	tempest.add_child(helicopter)
	tempest.register_unit(helicopter)
	helicopter.begin_takeoff()
	helicopter.set_physics_process(false)
	var air_health := helicopter.combat.health.current
	var departed := _tempest_ground(TEMPEST_TARGET + Vector3(0, 0, -2))
	tempest.remove_child(departed)
	await _until(func() -> bool: return not tempest.construction.navigation.blocked, 3, "isolated wall fixture synchronizes existing navigation")
	await physics_frame
	_check(not tempest.fire_query.segment(tempest.get_world_3d(), TEMPEST_TARGET + Vector3.UP, cover_target.global_position + Vector3.UP).is_clear(), "ordinary line-of-fire query confirms actual wall cover in fixture")
	_check(helicopter.is_taking_off() and TeamRules.target_domain(helicopter) == TeamRules.TargetDomain.AIR, "takeoff fixture is registered AIR before cruise altitude")
	if not await _tempest_ready(source):
		departed.free()
		return
	await physics_frame
	var result := tempest.tempest_strikes.launch(source, 1, TEMPEST_TARGET)
	_check(result.accepted, "isolated damage fixture accepts one scheduled strike")
	# Declared position changes isolate impact-time membership from locomotion;
	# earned/input suites use ordinary orders. They do not assert movement repair.
	moving_in.global_position = TEMPEST_TARGET + Vector3.FORWARD * 4
	moving_out.global_position = TEMPEST_TARGET + Vector3.FORWARD * 12
	if not await _tempest_impact(result.strike_id):
		departed.free()
		return
	_check(enemy.combat.health.current == 500 and friendly.combat.health.current == 500 and counts.enemy == 1 and counts.friendly == 1, "1000 damage applies once to both owners despite duplicate target colliders")
	_check(boundary.combat.health.current == 500 and counts.boundary == 1 and outside.combat.health.current == 1500, "anchor exactly10 units is included and10.01 is excluded beyond small numerical tolerance")
	_check(cover_target.combat.health.current == 500 and counts.covered == 1 and (not is_instance_valid(wall) or not wall.is_alive()), "area damage ignores real wall cover without ordinary line-of-fire filtering")
	_check(moving_in.combat.health.current == 500 and moving_out.combat.health.current == 1500, "one snapshot evaluates current impact positions for entered and escaped ground units")
	_check(helicopter.combat.health.current == air_health and helicopter.is_taking_off(), "AIR helicopter during takeoff takes no ground-area damage")
	_check(cache.remaining == 77 and decoration_health.current == 90 and unfinished.health.current == 1200 and departed.combat.health.current == 1500, "resources, decoration health, non-damageable unfinished site and departed ground object remain untouched")
	departed.free()
	await _until(func() -> bool: return not tempest.construction.navigation.blocked, 3, "blast wall death finishes existing serialized topology cleanup")


func _tempest_escape_checks() -> void:
	await _fresh_tempest()
	_tempest_power()
	var source := _tempest_fixture(TEMPEST_POINT, 1, 0.1, 6)
	var escaping := _tempest_ground(Vector3(0, 0, 18), 1)
	var entering := _tempest_ground(Vector3(12, 0, 18), 1)
	escaping.set_physics_process(true)
	entering.set_physics_process(true)
	await _until(_builder_navigation_current, 3, "ordinary counterplay movers use current field navigation")
	if not await _tempest_ready(source): return
	await physics_frame
	var result := tempest.tempest_strikes.launch(source, 1, TEMPEST_TARGET)
	_check(result.accepted, "actual movement counterplay fixture commits normal six-second strike")
	tempest.selection.select_clicked(escaping, false)
	_check(_complete(tempest.issue_move(Vector3(-10.7, 0, 18))), "selected friendly unit accepts normal Move order out of warning radius")
	tempest.selection.select_clicked(entering, false)
	_check(_complete(tempest.issue_move(Vector3(5, 0, 18))), "second selected friendly unit accepts normal Move order into warning radius")
	if not await _tempest_impact(result.strike_id, 6.2): return
	var escaped_distance := Vector2(escaping.global_position.x, escaping.global_position.z).distance_to(Vector2(TEMPEST_TARGET.x, TEMPEST_TARGET.z))
	var entered_distance := Vector2(entering.global_position.x, entering.global_position.z).distance_to(Vector2(TEMPEST_TARGET.x, TEMPEST_TARGET.z))
	print("TEMPEST_COUNTERPLAY: escaped_distance=%.6f entered_distance=%.6f escaped_hp=%.1f entered_hp=%.1f" % [escaped_distance, entered_distance, escaping.combat.health.current, entering.combat.health.current])
	_check(escaped_distance > 10.0001 and escaping.combat.health.current == 1500, "ordinary unit movement exits warning radius before impact and avoids all damage")
	_check(entered_distance < 10 and entering.combat.health.current == 500, "ordinary unit movement enters fixed warning radius before impact and receives exactly1000 friendly-fire damage")


func _tempest_callback_checks() -> void:
	await _fresh_tempest()
	_tempest_power()
	var source := _tempest_fixture(TEMPEST_POINT, 1, 0.1, 0.1)
	var first := _tempest_ground(TEMPEST_TARGET)
	var removed := _tempest_ground(TEMPEST_TARGET + Vector3.RIGHT * 3)
	var reused_id := removed.unit_id
	var replacements: Array[RTSUnit] = []
	var terminal_seen: Array[bool] = []
	var strike_id := {"value": 0}
	var substitute := func(_amount: float, _source: Node) -> void:
		terminal_seen.append(tempest.tempest_strikes.strike_snapshot(strike_id.value).state == "impacted")
		removed.free()
		var replacement := _tempest_ground(TEMPEST_TARGET + Vector3.RIGHT * 3)
		tempest.unregister_unit(replacement)
		replacement.unit_id = reused_id
		tempest.register_unit(replacement)
		replacements.append(replacement)
	first.combat.health.damaged.connect(substitute)
	if not await _tempest_ready(source): return
	await physics_frame
	var result := tempest.tempest_strikes.launch(source, 1, TEMPEST_TARGET)
	strike_id.value = result.strike_id
	if not await _tempest_impact(result.strike_id): return
	first.combat.health.damaged.disconnect(substitute)
	_check(terminal_seen == [true] and replacements.size() == 1 and replacements[0].unit_id == reused_id and replacements[0].combat.health.current == 1500, "impact commits terminal state before callbacks and never substitutes newly registered object reusing snapshot identifier")
	_check(first.combat.health.current == 500, "callback deletion of later target does not repeat or abort earlier damage")
	var plants: Array[RTSBuilding] = []
	for offset in [-3.0, 3.0]: plants.append(_power_fixture_building(POWER_PLANT, 2, TEMPEST_TARGET + Vector3(offset, 0, -3)))
	var deaths := {"count": 0}
	for plant in plants: plant.health.died.connect(func(_source: Node) -> void: deaths.count += 1)
	if not await _tempest_ready(source): return
	await physics_frame
	result = tempest.tempest_strikes.launch(source, 1, TEMPEST_TARGET + Vector3.FORWARD * 3)
	if not await _tempest_impact(result.strike_id): return
	await _until(func() -> bool: return not tempest.construction.navigation.blocked, 3, "multiple simultaneous building deaths serialize their existing navigation removal")
	_check(deaths.count == 2 and plants.all(func(body: RTSBuilding) -> bool: return not is_instance_valid(body) or not body.is_alive()) and _grid_is(2, 10, 8), "multiple blast building deaths emit once and remove all nominal generation without stale contributions")
	# A callback can remove the entire active field. Stop the remaining batch;
	# queued deletion remains valid just long enough to observe safe identity.
	await _fresh_tempest()
	_tempest_power()
	source = _tempest_fixture(TEMPEST_POINT, 1, 0.1, 0.1)
	first = _tempest_ground(TEMPEST_TARGET)
	var later := _tempest_ground(TEMPEST_TARGET + Vector3.RIGHT * 2)
	var later_hits := {"count": 0}
	later.combat.health.damaged.connect(func(_amount: float, _source: Node) -> void: later_hits.count += 1)
	var old_field := weakref(tempest)
	first.combat.health.damaged.connect(func(_amount: float, _source: Node) -> void: tempest.queue_free())
	if not await _tempest_ready(source): return
	await physics_frame
	result = tempest.tempest_strikes.launch(source, 1, TEMPEST_TARGET)
	_check(result.accepted, "field-removal callback fixture commits strike normally")
	await _frames(20)
	_check(old_field.get_ref() == null and later_hits.count == 0, "field destruction during first damage stops later batch applications safely")
	await _fresh_tempest()
	_check(tempest.tempest_strikes.pending_count() == 0 and tempest.tempest_strikes.warning_markers().is_empty(), "replacement field inherits no pending impact or warning from callback-destroyed field")


func _tempest_result_checks() -> void:
	await _fresh_tempest()
	_tempest_power()
	var source := _tempest_fixture(TEMPEST_POINT, 1, 0.1, 0.2)
	# Both original full-health HQs are moved into an isolated common blast area.
	# Two normal1000-damage strikes exercise natural1200HP rules; no forced win.
	tempest.headquarters.global_position = TEMPEST_TARGET + Vector3.LEFT * 4
	tempest.enemy_headquarters.global_position = TEMPEST_TARGET + Vector3.RIGHT * 4
	var results: Array[int] = []
	tempest.match_finished.connect(func(value: int) -> void: results.append(value))
	for index in 2:
		if not await _tempest_ready(source): return
		await physics_frame
		var shot := tempest.tempest_strikes.launch(source, 1, TEMPEST_TARGET)
		_check(shot.accepted, "normal strike%d accepts against both original full-health objective identities" % (index + 1))
		if not await _tempest_impact(shot.strike_id): return
		if index == 0:
			_check(tempest.headquarters.health.current == 200 and tempest.enemy_headquarters.health.current == 200 and tempest.result == BaseAssaultField.Result.RUNNING, "first1000-damage impact leaves both original1200HP HQs alive and match active")
	await _frames(2)
	_check(results == [BaseAssaultField.Result.DRAW] and tempest.result == BaseAssaultField.Result.DRAW and not tempest.gameplay_enabled, "both HQ deaths in one complete impact batch yield one DRAW after priority1000 result resolution")
	var charge := source.charge
	await _frames(60)
	await physics_frame
	_check(source.charge == charge and not tempest.tempest_strikes.launch(source, 1, TEMPEST_TARGET).accepted, "completed match freezes charge and rejects all new launches")
	await _fresh_tempest()
	_tempest_power()
	source = _tempest_fixture(TEMPEST_POINT, 1, 0.1, 6)
	var target := _tempest_ground(TEMPEST_TARGET)
	if not await _tempest_ready(source): return
	await physics_frame
	var result := tempest.tempest_strikes.launch(source, 1, TEMPEST_TARGET)
	_check(result.accepted, "prior-result fixture commits six-second warning in active match")
	tempest.enemy_headquarters.health.apply_damage(1200)
	await _frames(2)
	_check(tempest.result == BaseAssaultField.Result.VICTORY and tempest.tempest_strikes.pending_count() == 0 and tempest.tempest_strikes.strike_snapshot(result.strike_id).state == "cancelled", "unrelated earlier match result cancels unresolved strike under existing freeze policy")
	await _frames(370)
	_check(target.combat.health.current == 1500 and tempest.tempest_strikes.warning_markers().is_empty(), "cancelled warning never damages frozen survivors after former impact deadline")
	var old_source := weakref(source)
	var old_manager := weakref(tempest.tempest_strikes)
	_check(tempest.restart_match(), "existing Restart accepts transition from completed Tempest match")
	await _frames(6)
	_adopt_tempest(current_scene as SuperweaponAssaultField)
	_check(tempest != null and old_source.get_ref() == null and old_manager.get_ref() == null and tempest.result == BaseAssaultField.Result.RUNNING, "Restart replaces old source/manager identities with a running new Tempest scenario")
	_check(_tempest_facilities(1).is_empty() and tempest.construction.sites.is_empty() and tempest.tempest_strikes.pending_count() == 0 and tempest.tempest_strikes.warning_markers().is_empty() and tempest.credits.balance(1) == 1000, "Restart clears charges, facility reservations, warnings and scheduling while restoring original opening wallet")
	var new_hq_health := tempest.headquarters.health.current
	await _frames(370)
	_check(tempest.headquarters.health.current == new_hq_health and tempest.tempest_strikes.pending_count() == 0, "old strike cannot bind numeric identities or apply damage into replacement field")
