extends "res://tests/fixtures/tempest_harness.gd"
## Construction authority and power/charge use ordinary simulation processing.
## Observations after _frames are after the priority500 Tempest manager; API
## construction commands explicitly enter the next physics_frame boundary.


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1280, 720)
	var logger := EngineErrorProbe.new()
	OS.add_logger(logger)
	var chosen := "all"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--tempest-case="): chosen = argument.trim_prefix("--tempest-case=")
	var cases := ["eligibility", "construction", "charge", "lifecycle"]
	_check(chosen == "all" or cases.has(chosen), "recognized Tempest construction/power case")
	for case in cases:
		if chosen != "all" and chosen != case: continue
		var before := checks
		var failed := failures
		match case:
			"eligibility": await _tempest_eligibility_checks()
			"construction": await _tempest_construction_checks()
			"charge": await _tempest_charge_checks()
			"lifecycle": await _tempest_lifecycle_checks()
		print("TEMPEST_CASE: %s checks=%d failures=%d" % [case, checks - before, failures - failed])
	if is_instance_valid(field): field.queue_free()
	await _frames(6)
	_check(root.get_children().is_empty() and get_nodes_in_group("combat_projectiles").is_empty(), "Tempest construction teardown removes fields, charges and listeners")
	OS.remove_logger(logger)
	_check(logger.error_count() == 0, "Tempest construction and power have no native errors or warnings")
	print("TEMPEST_CHECKS: %d checks, %d failures; native_errors=%d" % [checks, failures, logger.error_count()])
	quit(0 if failures == 0 else 1)


func _tempest_eligibility_checks() -> void:
	await _fresh_tempest()
	_check(TEMPEST.is_valid() and TEMPEST.credit_cost == 5000 and TEMPEST.duration == 45 and TEMPEST.maximum_health == 1200, "Tempest definition has exact5000 credits,45 valid work seconds and1200HP")
	_check(TEMPEST.power_required == 8 and TEMPEST.power_generated == 0 and TEMPEST.charge_duration == 180 and TEMPEST.strike_warning == 6 and TEMPEST.strike_radius == 10 and TEMPEST.strike_damage == 1000, "exact power, charge, warning, radius and damage are configured prototype values")
	var builder := _player_builders()[0]
	var funds := tempest.credits.balance(1)
	var result := await _builder_place(builder, TEMPEST, TEMPEST_POINT)
	_check(not result.accepted and (result.reason.contains("Vehicle Factory") or result.reason.contains("Airfield")) and tempest.credits.balance(1) == funds and _tempest_facilities(1).is_empty(), "missing living owned producer rejects with actual prerequisite reason and no spend or reservation")
	var producer := _power_fixture_building(FACTORY, 2)
	result = await _builder_place(builder, TEMPEST, TEMPEST_POINT)
	_check(not result.accepted and tempest.credits.balance(1) == funds, "enemy Factory does not meet owned producer prerequisite")
	producer.owner_id = 1
	producer.operational = false
	result = await _builder_place(builder, TEMPEST, TEMPEST_POINT)
	_check(not result.accepted and tempest.credits.balance(1) == funds, "unfinished owned Factory does not meet completed prerequisite")
	producer.operational = true
	tempest.remove_child(producer)
	result = await _builder_place(builder, TEMPEST, TEMPEST_POINT)
	_check(not result.accepted and tempest.credits.balance(1) == funds, "detached producer does not meet registered active-field prerequisite")
	producer.free()
	producer = _power_fixture_building(FACTORY)
	producer.health.apply_damage(10000)
	result = await _builder_place(builder, TEMPEST, TEMPEST_POINT)
	_check(not result.accepted and tempest.credits.balance(1) == funds, "dead producer cannot satisfy prerequisite while normal destruction cleanup is pending")
	producer = _air_fixture_building(AIRFIELD, FIRST)
	_tempest_fixture(Vector3(16, 0, 17), 2)
	await _until(func() -> bool: return not tempest.construction.navigation.blocked, 3, "producer replacement completes existing serialized navigation before placement checks")
	await physics_frame
	result = tempest.construction.place(99, builder, TEMPEST, TEMPEST_POINT)
	_check(not result.accepted and not result.reason.is_empty() and tempest.credits.balance(1) == funds, "invalid requester cannot spend another owner's credits")
	result = tempest.construction.place(1, builder, TEMPEST, tempest.headquarters.global_position)
	_check(not result.accepted and not result.reason.is_empty() and tempest.credits.balance(1) == funds, "actual footprint overlap rejects without spending even with valid Airfield")
	var callbacks: Array[ConstructionResult] = []
	var attempt := func(owner: int) -> void:
		if owner == 1 and callbacks.is_empty(): callbacks.append(tempest.construction.place(1, builder, TEMPEST, TEMPEST_POINT))
	tempest.credits.changed.connect(attempt)
	result = tempest.construction.place(1, builder, TEMPEST, TEMPEST_POINT)
	tempest.credits.changed.disconnect(attempt)
	_check(result.accepted and result.paid == 5000 and tempest.credits.balance(1) == funds - 5000, "living registered owned Airfield accepts one paid facility")
	_check(callbacks.size() == 1 and not callbacks[0].accepted and _tempest_facilities(1).size() == 1, "synchronous payment callback cannot spend twice or reserve a second facility")
	_check(_tempest_facilities(2).size() == 1, "opponent facility does not reserve the player's independent facility slot")
	var duplicate := tempest.construction.place(1, builder, TEMPEST, TEMPEST_POINT + Vector3.RIGHT * 8)
	_check(not duplicate.accepted and not duplicate.reason.is_empty() and tempest.credits.balance(1) == funds - 5000, "duplicate unfinished Tempest request rejects without a second spend")
	var other := tempest.construction.place(1, builder, WALL, FORT_WALL_POINT)
	_check(not other.accepted and tempest.construction.unfinished_id == result.site_id, "Tempest preserves normal single unfinished-site concurrency limit")
	if result.accepted:
		var working := await _builder_arrival(result)
		if working != null:
			await _frames(60)
			_check(working.elapsed > 0 and working.elapsed < 45 and (working.building() as TempestArray).charge == 0, "cancellation fixture first accumulates real paid builder work without charging")
		await physics_frame
		_check(tempest.construction.cancel(1, result.site_id).accepted, "accepted Airfield-prerequisite site supports normal cancellation")
		await _until(func() -> bool: return not tempest.construction.navigation.blocked and tempest.construction.unfinished_id == 0, 3, "cancelled facility releases paid site and serialized navigation")
		_check(tempest.credits.balance(1) == funds and _tempest_facilities(1).is_empty(), "cancellation releases facility slot and refunds exactly once")
	await _fresh_tempest(4999)
	builder = _player_builders()[0]
	_power_fixture_building(FACTORY)
	result = await _builder_place(builder, TEMPEST, TEMPEST_POINT)
	_check(not result.accepted and result.reason.to_lower().contains("credit") and tempest.credits.balance(1) == 4999 and _tempest_facilities(1).is_empty(), "4999 credits reject with insufficient-funds reason and no reservation")


func _tempest_construction_checks() -> void:
	await _fresh_tempest()
	var plants := _tempest_power()
	var producer := _power_fixture_building(FACTORY)
	var builder := _player_builders()[0]
	var funds := tempest.credits.balance(1)
	var result := await _builder_place(builder, TEMPEST, TEMPEST_POINT)
	var site := _site(result)
	_check(result.accepted and site != null and result.paid == 5000, "real selected Bulldozer accepts exact5000-credit Tempest construction")
	if site == null: return
	var body := site.building() as TempestArray
	_check(body != null and not body.operational and body.charge == 0 and body.production == null and body.recipe == null and not body.can_take_damage() and _grid_is(1, 20, 4), "unfinished site has no charge, damage eligibility, queue or operational demand")
	await physics_frame
	var launch := tempest.tempest_strikes.launch(body, 1, TEMPEST_TARGET)
	_check(not launch.accepted and body.charge == 0 and tempest.tempest_strikes.pending_count() == 0, "unfinished facility cannot launch through API")
	producer.health.apply_damage(10000)
	_check(not producer.is_alive() and _grid_is(1, 20, 0) and site.cancellable(), "producer destruction after acceptance keeps existing site valid")
	if await _builder_arrival(result) == null: return
	await _frames(120)
	await physics_frame
	builder.stop()
	await _frames(2)
	var paused := site.elapsed
	await _frames(90)
	_check(site.state == ConstructionSite.State.PAUSED and site.elapsed == paused and paused > 1.9 and paused < 2.2 and body.charge == 0 and _grid_is(1, 20, 0), "actual builder work pauses without lost progress, charge or demand")
	tempest.selection.select_clicked(builder, false)
	await physics_frame
	_check(tempest.construction.assign_builder(builder, site.site_id), "owned Bulldozer resumes accepted facility without surviving producer")
	if not await _builder_complete(site): return
	_check(site.elapsed == 45 and body.operational and body.health.maximum == 1200 and body.health.current == 1200 and body.can_take_damage(), "exact45 accumulated builder work seconds activate living1200HP ground building")
	_check(body.charge == 0 and not body.is_ready() and body.charge_remaining() == 180 and _grid_is(1, 20, 8), "completion frame starts charge at zero and contributes eight demand exactly once")
	_check(body.production == null and body.recipe == null and builder.assigned_site_id == 0 and not site.rectangle.grow(builder.agent.radius).has_point(Vector2(builder.global_position.x, builder.global_position.z)), "completion releases external builder and creates no production recipes or queue")
	for index in 3:
		tempest.register_building(body)
		body.refresh_construction()
	_check(_grid_is(1, 20, 8) and tempest.credits.balance(1) == funds - 5000, "duplicate registration and completion refresh do not duplicate demand or spending")
	await _frames(60)
	var progress := body.charge
	body.health.apply_damage(100)
	await _frames(60)
	_check(absf(body.charge - progress - 1.0) <= 0.035 and body.health.current == 1100 and _grid_is(1, 20, 8), "ordinary source damage preserves full charge rate and demand before death")
	await physics_frame
	result = tempest.construction.place(1, builder, TEMPEST, SECOND)
	_check(not result.accepted and tempest.credits.balance(1) == funds - 5000, "completed owned facility retains additional per-owner limit")
	_check(plants.all(func(plant: RTSBuilding) -> bool: return plant.is_alive()), "construction and consumer completion preserve both supporting plants")


func _tempest_charge_checks() -> void:
	await _fresh_tempest()
	var plants := _tempest_power()
	var body := _tempest_fixture()
	var started := Engine.get_physics_frames()
	_check(body.charge == 0 and _grid_is(1, 20, 8), "real180-second fixture begins empty with full demand")
	await _frames(10794)
	_check(not body.is_ready() and body.charge >= 179.8 and body.charge < 180.0, "179.9 simulated powered seconds cannot grant the real180-second charge early")
	if not await _tempest_ready(body): return
	var elapsed := float(Engine.get_physics_frames() - started) / Engine.physics_ticks_per_second
	print("TEMPEST_REAL_CHARGE: simulation_seconds=%.6f charge=%.6f duration=%.6f priority=500" % [elapsed, body.charge, body.definition.charge_duration])
	_check(absf(elapsed - 180.0) <= 0.035 and body.charge == 180.0 and body.charge_remaining() == 0, "readiness occurs after real180 accumulated powered seconds within one phase tick")
	await _frames(120)
	_check(body.charge == 180 and body.is_ready() and _grid_is(1, 20, 8), "ready facility clamps one charge and keeps eight demand during excess powered time")
	for plant in plants: plant.queue_free()
	await _frames(2)
	await physics_frame
	var rejected := tempest.tempest_strikes.launch(body, 1, TEMPEST_TARGET)
	_check(not rejected.accepted and rejected.reason.to_lower().contains("power") and body.is_ready() and body.charge == 180 and _grid_is(1, 0, 8), "ready-but-unpowered launch rejects explicitly while retaining charge and demand")
	await _frames(60)
	_check(body.charge == 180 and body.charge_remaining() == 0, "ready shortage never erases accumulated charge")
	_tempest_power()
	await physics_frame
	var launched := tempest.tempest_strikes.launch(body, 1, TEMPEST_TARGET)
	_check(launched.accepted and body.charge == 0 and not body.is_ready() and _grid_is(1, 20, 8), "restored power permits launch and consumes exactly one ready charge with retained demand")
	await _frames(120)
	_check(body.charge >= 1.95 and body.charge <= 2.02 and _grid_is(1, 20, 8), "recharge starts from zero on subsequent powered ticks")
	await _fresh_tempest()
	plants = _tempest_power()
	body = _tempest_fixture(TEMPEST_POINT, 1, 8.0)
	var enemy := _tempest_fixture(Vector3(16, 0, 17), 2, 8.0)
	await _frames(120)
	_check(body.charge >= 1.95 and enemy.charge == 0 and _grid_is(2, 10, 16), "separate owner shortage cannot borrow player generation or progress")
	for plant in plants: plant.health.apply_damage(10000)
	var held := body.charge
	var remaining := body.charge_remaining()
	await _frames(180)
	_check(body.charge == held and body.charge_remaining() == remaining and body.status_text().to_lower().contains("power") and _grid_is(1, 0, 8), "three-second shortage pauses authoritative progress and remaining-time presentation")
	_tempest_power()
	await _frames(60)
	_check(absf(body.charge - held - 1.0) <= 0.035 and enemy.charge == 0, "restored owner power resumes retained progress independently")
	if not await _tempest_ready(body): return
	_check(body.charge == 8 and _grid_is(1, 20, 8), "isolated configured charge finishes once after retained powered accumulation")


func _tempest_lifecycle_checks() -> void:
	await _fresh_tempest()
	_tempest_power()
	var body := _tempest_fixture(TEMPEST_POINT, 1, 4.0)
	await _frames(60)
	var previous := body.charge
	var holder := Node3D.new()
	tempest.add_child(holder)
	body.reparent(holder)
	await _frames(2)
	_check(tempest.contains_building(body) and body.charge >= previous and _grid_is(1, 20, 8), "same-field reparent preserves identity and accumulated charge without double demand")
	var wallet := tempest.credits.balance(1)
	var removed := weakref(body)
	body.health.apply_damage(1200)
	_check(not tempest.contains_building(body) and _grid_is(1, 20, 0) and tempest.credits.balance(1) == wallet, "ordinary lethal damage releases facility contribution once without refund")
	await _until(func() -> bool: return not tempest.construction.navigation.blocked, 3, "destroyed facility finishes existing serialized navigation cleanup")
	var rebuilt := _tempest_fixture(TEMPEST_POINT, 1, 4.0)
	_check(rebuilt.charge == 0 and not rebuilt.is_ready() and rebuilt != removed.get_ref() and _grid_is(1, 20, 8), "replacement facility has distinct identity and begins with no inherited charge")
	tempest.remove_child(rebuilt)
	await _frames(2)
	_check(not tempest.contains_building(rebuilt) and _grid_is(1, 20, 0), "detachment removes operational contribution and authority")
	await physics_frame
	_check(not tempest.tempest_strikes.launch(rebuilt, 1, TEMPEST_TARGET).accepted, "detached facility cannot launch through the original field")
	rebuilt.free()
	var queued := _tempest_fixture(TEMPEST_POINT, 1, 0.1)
	if not await _tempest_ready(queued): return
	await physics_frame
	queued.queue_free()
	_check(not tempest.tempest_strikes.launch(queued, 1, TEMPEST_TARGET).accepted and _grid_is(1, 20, 0), "queued deletion immediately invalidates ready source and power contribution")
	await _frames(3)
	_check(_tempest_facilities(1).is_empty(), "immediate and deferred source destruction leave no stale facility reservation")
