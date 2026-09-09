extends "res://tests/fixtures/air_harness.gd"
## Paid real builder work and production. Extra initial funds, paused enemies,
## and explicit completed generator fixtures isolate timing and callbacks.


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1280, 720)
	var logger := EngineErrorProbe.new()
	OS.add_logger(logger)
	await _air_construction()
	await _air_launch_and_rally()
	await _air_source_departure()
	await _air_freeze_restart()
	if is_instance_valid(field): field.queue_free()
	await _frames(6)
	_check(root.get_children().is_empty() and get_nodes_in_group("combat_projectiles").is_empty(), "air production teardown removes actors, claims and projectiles")
	OS.remove_logger(logger)
	_check(logger.error_count() == 0, "air construction, production and callback lifecycle have no native errors")
	print("AIR_PRODUCTION_CHECKS: %d checks, %d failures; native_errors=%d" % [checks, failures, logger.error_count()])
	quit(0 if failures == 0 else 1)


func _air_construction() -> void:
	await _fresh_air()
	_check(AIRFIELD.is_valid() and AIR_DEFENSE.is_valid() and HELICOPTER_RECIPE.is_valid(), "configured Airfield, AA and helicopter definitions pass authoritative admission")
	_check(AIRFIELD.credit_cost == 1000 and AIRFIELD.duration == 15 and AIRFIELD.power_required == 3 and AIRFIELD.maximum_health == 450 and AIR_DEFENSE.credit_cost == 800 and AIR_DEFENSE.duration == 12 and AIR_DEFENSE.maximum_health == 600 and AIR_DEFENSE.power_required == 3, "new building resources preserve exact costs, work durations, health and power")
	_check(HELICOPTER_RECIPE.credit_cost == 600 and HELICOPTER_RECIPE.training_duration == 10 and HELICOPTER_RECIPE.deployment_body() is SphereShape3D, "paid helicopter recipe uses600 credits,10 seconds and actual spherical deployment volume")
	var actor := _player_builders()[0]
	var accepted := await _builder_place(actor, AIRFIELD, FIRST)
	var site := _site(accepted)
	_check(accepted.accepted and accepted.paid == 1000 and air.credits.balance(1) == 5000, "Bulldozer places and pays exact Airfield cost through existing site authority")
	if site == null: return
	_check(not site.building().operational and not site.building().production.enqueue(1, HELICOPTER_RECIPE).accepted and _grid_is(1, 0, 0), "unfinished Airfield has no production or power contribution")
	_check(not air.construction.can_begin(1, actor, AIR_DEFENSE).is_empty(), "Airfield preserves the existing one unfinished-site limit")
	_check(air.construction.cancel(1, site.site_id).accepted and air.credits.balance(1) == 6000 and not air.construction.cancel(1, site.site_id).accepted, "Airfield cancellation refunds1000 exactly once")
	if not await _until(func() -> bool: return air.construction.unfinished_id == 0 and not air.construction.navigation.blocked, 3, "cancelled air construction restores ground topology"): return
	var airfield := await _power_build(actor, AIRFIELD, FIRST)
	if airfield == null: return
	_check(airfield.operational and airfield.health.current == 450 and airfield.site.elapsed == 15 and _grid_is(1, 0, 3) and air.production_multiplier(airfield) == 0.5, "real15-second Airfield completion uses existing450HP producer default and nominal3 demand at low power")
	_check(not airfield.production.enqueue(1, POWER_RIFLE).accepted and not airfield.production.enqueue(1, ROCKET_RECIPE).accepted and not air.headquarters.production.enqueue(1, HELICOPTER_RECIPE).accepted, "Airfield accepts no ground recipes and HQ rejects helicopter recipe")
	var jobs: Array[int] = []
	for index in 5:
		var job := airfield.production.enqueue(1, HELICOPTER_RECIPE)
		_check(job.accepted, "ordinary five-slot queue accepts paid helicopter job%d" % index)
		jobs.append(job.job_id)
	_check(air.credits.balance(1) == 2000 and not airfield.production.enqueue(1, HELICOPTER_RECIPE).accepted, "five paid jobs cost3000 and sixth is rejected without spending")
	await _frames(60)
	var elapsed_job: float = airfield.production.jobs()[0].elapsed
	_check(absf(elapsed_job - 0.5) < 0.04, "one simulated second advances low-power Airfield by half a training second")
	for identity in jobs:
		_check(airfield.production.cancel(1, identity).accepted, "cancelling queued helicopter returns captured payment")
	_check(air.credits.balance(1) == 5000 and airfield.production.count() == 0, "all paid queue cancellations restore original post-construction balance")
	var aa_result := await _builder_place(actor, AIR_DEFENSE, SECOND)
	var aa_site := await _builder_arrival(aa_result)
	if aa_site == null: return
	var aa := aa_site.building() as GroundDefenseBattery
	_check(not aa.operational and aa.weapon.shots_fired == 0 and _grid_is(1, 0, 3), "unfinished AA neither fires nor consumes operational power")
	if not await _builder_complete(aa_site): return
	_check(aa.operational and aa.health.current == 600 and aa.production == null and aa_site.elapsed == 12 and _grid_is(1, 0, 6), "real paid AA completion creates stationary600HP nonproducer and full3 demand while unpowered")


func _air_launch_and_rally() -> void:
	await _fresh_air()
	var airfield := _air_fixture_building(AIRFIELD)
	var generator := _air_fixture_building(POWER_PLANT, SECOND)
	await _frames(3)
	var producer := airfield.production
	var pad := airfield.launch_position()
	var blocker := _vehicle_wall(Vector3(1, 1, 1), pad)
	var committed := {"count": 0}
	producer.deployed.connect(func(_job: int, _unit: int, _rally: bool) -> void: committed.count += 1)
	_check(producer.set_rally(1, Vector3(-5, 0, 3)).accepted and producer.enqueue(1, HELICOPTER_RECIPE).accepted, "powered paid helicopter starts with valid post-takeoff rally")
	if not await _until(func() -> bool: return producer.progress() >= 1 and producer.message == "Exit blocked", 11, "actual sphere obstruction keeps completed paid job waiting"): return
	_check(producer.count() == 1 and committed.count == 0 and _player_aircraft().is_empty() and air.air_launch_claim_count() == 0, "blocked deployment creates no aircraft, successful deployment event or leaked claim")
	blocker.queue_free()
	if not await _until(func() -> bool: return committed.count == 1, 1, "clear launch volume commits one registered paid aircraft"): return
	var helicopter := _last_unit(producer) as AttackHelicopter
	if helicopter == null: return
	_check(helicopter.owner_id == 1 and helicopter.is_taking_off() and helicopter.global_position.y >= pad.y and helicopter.global_position.y < 8 and air.air_launch_claim_count() == 1, "deployed owner1 body begins visible real climb and owns one launch claim")
	await physics_frame
	_check(air.find_spawn(airfield).is_empty() and not helicopter.can_fire_weapon(), "takeoff claim prevents second launch and authoritative weapon firing")
	# Sample after the current physics step, matching _frames' return phase.
	# A physics_frame signal precedes body updates and otherwise adds one step.
	await process_frame
	var first_y := helicopter.global_position.y
	var climb_frame := Engine.get_physics_frames()
	var climb_in_physics := Engine.is_in_physics_frame()
	await _frames(15)
	print("AIR_TIMING: climb distance=%s frames=%d start_in_physics=%s end_in_physics=%s" % [helicopter.global_position.y - first_y, Engine.get_physics_frames() - climb_frame, climb_in_physics, Engine.is_in_physics_frame()])
	_check(helicopter.global_position.y > first_y and helicopter.global_position.y - first_y <= 1.01 and helicopter.global_position.x == pad.x and helicopter.global_position.z == pad.z, "takeoff moves actual center vertically at bounded4units/s before horizontal mission movement")
	_check(producer.set_rally(1, Vector3(-7, 0, 9)).accepted, "Airfield rally may change while aircraft safely climbs")
	if not await _until(func() -> bool: return not helicopter.is_taking_off(), 2, "aircraft completes safe climb to cruise plane"): return
	_check(helicopter.assigned_destination.distance_to(Vector3(-7, 8, 9)) < 0.01 and air.air_launch_claim_count() == 0 and committed.count == 1, "clearance releases claim and reads current Airfield rally exactly once")
	if not await _until(func() -> bool: return not helicopter.moving, 3, "paid helicopter reaches current rally and hovers"): return
	generator.operational = false # Explicit power transition in isolated fixture.
	await physics_frame
	await process_frame
	var cruise_start := helicopter.global_position
	var cruise_frame := Engine.get_physics_frames()
	var cruise_in_physics := Engine.is_in_physics_frame()
	helicopter.move_to(Vector3(10, 0, 9))
	await _frames(60)
	print("AIR_TIMING: cruise distance=%s frames=%d start_in_physics=%s end_in_physics=%s" % [helicopter.global_position.distance_to(cruise_start), Engine.get_physics_frames() - cruise_frame, cruise_in_physics, Engine.is_in_physics_frame()])
	_check(_grid_is(1, 0, 3) and helicopter.global_position.distance_to(cruise_start) > 7.7 and helicopter.global_position.distance_to(cruise_start) <= 8.02, "ordinary shortage leaves deployed aircraft at full bounded8units/s cruise speed")
	helicopter.stop()
	generator.operational = true
	_check(producer.enqueue(1, HELICOPTER_RECIPE).accepted, "same Airfield accepts another normal paid job after launch clearance")
	if not await _until(func() -> bool: return committed.count == 2, 11, "next paid job independently launches after clearance"): return
	var second := _last_unit(producer) as AttackHelicopter
	_check(second != helicopter and second.unit_id != helicopter.unit_id and _player_aircraft().size() == 2, "two paid jobs register two distinct correctly owned aircraft once")
	second.move_to(Vector3(0, 0, 5))
	second.move_to(Vector3(-3, 0, 8))
	second.stop()
	producer.set_rally(1, Vector3(6, 0, 16))
	if not await _until(func() -> bool: return not second.is_taking_off(), 2, "X during takeoff clears pending order but completes safe climb"): return
	_check(not second.moving and second.global_position.distance_to(Vector3(pad.x, 8, pad.z)) < 0.01 and second.combat.weapon.shots_fired == 0 and air.air_launch_claim_count() == 0, "newest X supersedes replacement Moves and later Airfield rally without cancelling climb")
	await _frames(30)
	_check(_player_aircraft().size() == 2 and committed.count == 2 and producer.count() == 0, "finished launch callbacks never refund, duplicate or respawn units")
	second.move_to(Vector3(6, 0, 16))
	_check(producer.enqueue(1, HELICOPTER_RECIPE).accepted, "departure fixture pays for a third ordinary aircraft")
	if not await _until(func() -> bool: return committed.count == 3, 11, "vacated pad deploys third paid aircraft into a reserved climb"): return
	var departing := _last_unit(producer) as AttackHelicopter
	var departing_ref: WeakRef = weakref(departing)
	var paid_balance := air.credits.balance(1)
	_check(departing.is_taking_off() and air.air_launch_claim_count() == 1, "departure fixture observes an actual live takeoff claim before destruction")
	departing.combat.health.apply_damage(180) # Isolated lifecycle trigger; earned combat uses real weapons.
	await _frames(3)
	_check(departing_ref.get_ref() == null and air.air_launch_claim_count() == 0 and _player_aircraft().size() == 2 and producer.count() == 0 and air.credits.balance(1) == paid_balance, "takeoff death releases its claim without refund, duplicate deployment or surviving callback")


func _air_source_departure() -> void:
	await _fresh_air()
	var airfield := _air_fixture_building(AIRFIELD)
	_air_fixture_building(POWER_PLANT, SECOND)
	await _frames(3)
	var producer := airfield.production
	producer.set_rally(1, Vector3(-5, 0, 4))
	for index in 3: _check(producer.enqueue(1, HELICOPTER_RECIPE).accepted, "source-departure fixture pays ordinary helicopter job%d" % index)
	var source_ref: WeakRef = weakref(airfield)
	producer.deployed.connect(func(_job: int, _unit: int, _rally: bool) -> void:
		var source := source_ref.get_ref() as RTSBuilding
		if is_instance_valid(source): source.health.apply_damage(source.health.current)
	, CONNECT_ONE_SHOT)
	if not await _until(func() -> bool: return not producer.last_deployment.is_empty(), 11, "deployed callback removes source immediately after one paid commit"): return
	var helicopter := _last_unit(producer) as AttackHelicopter
	await _frames(3)
	_check(is_instance_valid(helicopter) and air.contains_unit(helicopter) and helicopter.is_taking_off() and source_ref.get_ref() == null and producer.count() == 0 and air.credits.balance(1) == 5400, "source departure preserves committed helicopter and refunds only two undeployed600-credit jobs")
	_check(not producer.cancel(1, producer.last_deployment.job_id).accepted and _grid_is(1, 10, 0), "deployed unit cannot be cancelled and source departure removes only its own demand")
	if not await _until(func() -> bool: return not helicopter.is_taking_off() and not helicopter.moving, 4, "independent aircraft completes climb and saved rally after source deletion"): return
	_check(air.air_launch_claim_count() == 0 and _player_aircraft().size() == 1 and helicopter.global_position.distance_to(Vector3(-5, 8, 4)) < 0.4, "departed source leaves no launch claim, duplicate or stranded post-takeoff order")


func _air_freeze_restart() -> void:
	await _fresh_air()
	var airfield := _air_fixture_building(AIRFIELD)
	_air_fixture_building(POWER_PLANT, SECOND)
	await _frames(3)
	var producer := airfield.production
	producer.set_rally(1, Vector3(8, 0, 5))
	producer.enqueue(1, HELICOPTER_RECIPE)
	producer.enqueue(1, HELICOPTER_RECIPE)
	if not await _until(func() -> bool: return not producer.last_deployment.is_empty(), 11, "freeze fixture pays and commits aircraft into actual takeoff"): return
	var helicopter := _last_unit(producer) as AttackHelicopter
	air.headquarters.health.apply_damage(1200)
	await _frames(2)
	_check(air.result == BaseAssaultField.Result.DEFEAT and not air.gameplay_enabled and helicopter.is_taking_off(), "HQ result freezes aircraft during its real climb")
	var position := helicopter.global_position
	var progress := producer.progress()
	await _frames(90)
	_check(helicopter.global_position == position and producer.progress() == progress and not helicopter.move_to(Vector3.ZERO) and not producer.enqueue(1, HELICOPTER_RECIPE).accepted, "frozen result prevents climb, mission orders and production progress")
	var old_grid := air.power_grid
	var old_wallet := air.credits
	_check(air.restart_match(), "same air scenario Restart is accepted")
	await _frames(6)
	air = current_scene as AirAssaultField
	_adopt_defense(air)
	_check(air != null and air.result == BaseAssaultField.Result.RUNNING and air.restart_scene == "res://scenes/air_assault.tscn" and _player_aircraft().is_empty() and air.air_launch_claim_count() == 0, "Restart restores Air Assault with no player aircraft or stale launch claims")
	_check(not old_grid.active and not old_wallet.active and not producer.is_available() and not air.sortie_issued and air.sortie_delay == 120 and _grid_is(2, 10, 8), "Restart closes old power/jobs/listeners and restores normally powered120-second starting sortie")
	producer.advance(30)
	_check(air.air_launch_claim_count() == 0 and _player_aircraft().is_empty() and air.credits.balance(1) == 1000, "late calls on retired producer cannot deploy into restarted field")
