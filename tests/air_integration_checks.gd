extends "res://tests/fixtures/air_harness.gd"
## Earned M15 integration: original1000-credit wallet and starting builder;
## paid Depot, Collector, Airfield, Power Plant and helicopter. Actual finite
## supply loading/deposits fund every purchase. Instance-only first wave and
## declared starting helicopter sortie are delayed to600s to observe the economy.
## Enemy paid ground production/harvesting and both normal defenses stay live.


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1280, 720)
	var logger := EngineErrorProbe.new()
	OS.add_logger(logger)
	await _earned_air_operation()
	if is_instance_valid(field): field.queue_free()
	await _frames(6)
	_check(root.get_children().is_empty() and get_nodes_in_group("combat_projectiles").is_empty(), "earned air integration cleanly removes economy, aircraft, launch claims and projectiles")
	OS.remove_logger(logger)
	_check(logger.error_count() == 0, "earned air construction, production and real combined-domain combat produce no native errors")
	print("AIR_INTEGRATION_CHECKS: %d checks, %d failures; native_errors=%d" % [checks, failures, logger.error_count()])
	quit(0 if failures == 0 else 1)


func _earned_air_operation() -> void:
	await _fresh_air(1000, true, true)
	var actor := _player_builders()[0]
	var cache := _depot_player_cache()
	_check(cache != null and cache.remaining == 2000 and air.enemy_controller.is_physics_processing() and air.enemy_air_defense.is_physics_processing(), "earned opening keeps original finite supplies and live normal enemy paid economy/AA")
	if cache == null: return
	var depot := await _power_build(actor, DEPOT, DEPOT_POINT)
	if depot == null: return
	_check(air.credits.balance(1) == 700 and air.valid_dropoff(depot, 1), "original builder pays300 and completes functioning Supply Depot")
	await physics_frame
	_check(actor.move_to(Vector3(-14.5, 0, -1.5)), "builder uses normal ground Move to clear Depot face")
	if not await _until(func() -> bool: return not actor.moving, 10, "builder physically clears the Collector production and deposit face"): return
	depot.production.set_rally(1, Vector3(-5, 0, 2))
	_check(depot.production.enqueue(1, COLLECTOR_RECIPE).accepted and air.credits.balance(1) == 500, "ordinary paid Collector production spends200 with no grants")
	if not await _until(func() -> bool: return not depot.production.last_deployment.is_empty(), 7, "paid Collector actually trains and deploys"): return
	var truck := _last_unit(depot.production) as CollectorTruck
	if truck == null: return
	if not await _until(func() -> bool: return not truck.moving, 12, "paid Collector physically reaches production rally"): return
	var ledger := {"loaded": 0, "deposited": 0, "spent": 500, "conserved": true, "owner_correct": true}
	truck.harvesting.transferred.connect(func(transfer: HarvestTransfer) -> void:
		ledger.owner_correct = ledger.owner_correct and transfer.owner_id == 1 and transfer.collector_id == truck.unit_id
		if transfer.kind == HarvestTransfer.Kind.LOAD: ledger.loaded += transfer.amount
		else: ledger.deposited += transfer.amount
		ledger.conserved = ledger.conserved and cache.remaining + truck.harvesting.cargo + ledger.deposited == 2000
	)
	await physics_frame
	_check(truck.harvesting.issue(cache, true), "normal collector authority starts automatic finite-supply harvesting")
	if not await _until(func() -> bool: return air.credits.balance(1) >= 1000, 100, "real loads and deposits earn otherwise missing Airfield funds"): return
	var result := await _builder_place(actor, AIRFIELD, FIRST)
	if result.accepted: ledger.spent += AIRFIELD.credit_cost
	var site := await _builder_arrival(result)
	if site == null or not await _builder_complete(site): return
	var airfield := site.building()
	_check(site.elapsed == 15 and airfield.health.current == 450 and _grid_is(1, 0, 3) and ledger.spent == 1500, "earned1000-credit Airfield completes real15-second builder work with normal demand and450HP")
	if not await _until(func() -> bool: return air.credits.balance(1) >= 500, 100, "finite-supply deposits fund actual Power Plant cost"): return
	result = await _builder_place(actor, POWER_PLANT, SECOND)
	if result.accepted: ledger.spent += POWER_PLANT.credit_cost
	var plant_site := await _builder_arrival(result)
	if plant_site == null or not await _builder_complete(plant_site): return
	_check(plant_site.elapsed == 10 and _grid_is(1, 10, 3) and air.production_multiplier(airfield) == 1.0, "same original builder earns and builds normal500-credit generator restoring100percent Airfield rate")
	if not await _until(func() -> bool: return air.credits.balance(1) >= 600, 100, "real Collector earns full helicopter payment"): return
	airfield.production.set_rally(1, Vector3(-6, 0, 5))
	var job := airfield.production.enqueue(1, HELICOPTER_RECIPE)
	if job.accepted: ledger.spent += HELICOPTER_RECIPE.credit_cost
	_check(job.accepted and ledger.spent == 2600 and ledger.deposited >= 1600 and air.credits.balance(1) == 1000 + ledger.deposited - ledger.spent, "actual deposits fund2600 total spending including paid600-credit helicopter with conserved wallet")
	if not await _until(func() -> bool: return not airfield.production.last_deployment.is_empty(), 11, "earned powered helicopter trains ten simulated seconds and commits one safe deployment"): return
	var helicopter := _last_unit(airfield.production) as AttackHelicopter
	_check(helicopter != null and helicopter.is_taking_off() and air.contains_unit(helicopter) and air.air_launch_claim_count() == 1, "earned aircraft begins genuine claimed takeoff as correctly owned registered AIR actor")
	if helicopter == null: return
	if not await _until(func() -> bool: return not helicopter.is_taking_off() and not helicopter.moving, 4, "earned aircraft climbs to8 and physically reaches post-takeoff rally"): return
	_check(helicopter.global_position.y == 8 and air.air_launch_claim_count() == 0 and ledger.conserved and ledger.owner_correct, "paid takeoff clears launch reservation and real finite supply transfers remain conserved")
	var ground_target := air.enemy_battery
	var helicopter_identity := helicopter.get_instance_id()
	var damage := {"events": 0, "amount": 0.0, "correct_source": true}
	ground_target.health.damaged.connect(func(amount: float, source: Node) -> void:
		damage.events += 1
		damage.amount += amount
		damage.correct_source = damage.correct_source and is_instance_valid(source) and source.get_instance_id() == helicopter_identity
	)
	await physics_frame
	air.selection.select_clicked(helicopter, false)
	_check(air.issue_attack(ground_target).has_acceptance(), "earned helicopter accepts ordinary explicit attack on real hostile ground-defense building")
	if not await _until(func() -> bool: return damage.events > 0, 12, "paid helicopter flies into3D range, launches real rocket and damages hostile ground building"): return
	_check(helicopter.combat.weapon.shots_fired > 0 and damage.amount >= 24 and damage.correct_source and ground_target.health.current < 600, "actual guided-projectile impact credits earned helicopter with24 damage against normal hostile building")
	await _air_capture("air_earned_ground_damage_1280x720")
	var hits := {"events": 0, "amount": 0.0, "correct_source": true}
	helicopter.combat.health.damaged.connect(func(amount: float, source: Node) -> void:
		hits.events += 1
		hits.amount += amount
		hits.correct_source = hits.correct_source and source == air.enemy_air_defense
	)
	await physics_frame
	_check(helicopter.move_to(Vector3(17, 0, 6)), "same paid aircraft accepts normal flight into explicit enemy AA coverage")
	if not await _until(func() -> bool: return hits.events > 0, 6, "normally powered enemy AA acquires, pitches upward and hits actual earned helicopter"): return
	_check(hits.amount >= 30 and hits.correct_source and air.enemy_air_defense.weapon.shots_fired > 0 and _grid_is(2, 10, 8), "real owner-grid-powered AA counters paid helicopter with30-damage hitscan")
	var helicopter_ref: WeakRef = weakref(helicopter)
	if not await _until(func() -> bool: return helicopter_ref.get_ref() == null or not helicopter_ref.get_ref().is_alive(), 8, "normal AA fire removes the hostile paid helicopter without crash damage"): return
	_check(_player_aircraft().is_empty() and air.air_launch_claim_count() == 0 and airfield.production.count() == 0, "actual AA kill leaves no replacement aircraft, refund job or leaked launch ownership")
	var ground: RTSUnit
	for unit in air.units:
		if unit.owner_id == 1 and not unit is Bulldozer and not unit is CollectorTruck:
			ground = unit
			break
	if ground == null:
		_check(false, "original player ground force remains available")
		return
	# Ordinary ground navigation follows the open south/east approach; no flight
	# destinations or teleports are used to make power infrastructure attackable.
	for point in [Vector3(27, 0, 19), Vector3(29, 0, 3)]:
		await physics_frame
		_check(ground.move_to(point), "ordinary starting Rifle accepts navigable eastern approach waypoint")
		if not await _until(func() -> bool: return not ground.moving, 25, "original Rifle physically traverses normal ground approach"): return
	var infrastructure := air.enemy_power_plant
	var original_health := infrastructure.health.current
	await physics_frame
	_check(ground.combat.issue_attack(infrastructure), "ordinary existing ground weapon accepts AA's power infrastructure as a ground target")
	if not await _until(func() -> bool: return infrastructure.health.current < original_health, 8, "original ground Rifle produces real damage against enemy AA power infrastructure"): return
	_check(ground.combat.weapon.shots_fired > 0 and ledger.conserved and ledger.owner_correct and air.credits.balance(1) == 1000 + ledger.deposited - ledger.spent and air.enemy_controller.accepted_jobs > 0, "earned combined-domain operation preserves real spending/deposits and unchanged paid enemy ground production")
	await _air_capture("air_earned_ground_power_attack_1280x720")
	var economy := {"starting_funds": 1000, "loaded": ledger.loaded, "deposited": ledger.deposited, "spending": {"supply_depot": 300, "collector": 200, "airfield": 1000, "power_plant": 500, "helicopter": 600}, "total_spent": ledger.spent, "final_balance": air.credits.balance(1), "cargo": truck.harvesting.cargo, "remaining_supply": cache.remaining, "conserved": ledger.conserved, "owner_correct": ledger.owner_correct}
	print("AIR_EARNED_LEDGER: " + JSON.stringify(economy))
	DirAccess.make_dir_recursive_absolute("res://validation-output/m15")
	var ledger_file := FileAccess.open("res://validation-output/m15/earned-ledger.json", FileAccess.WRITE)
	_check(ledger_file != null, "earned opening saves actual construction/production spending and final deposit balance")
	if ledger_file != null:
		ledger_file.store_string(JSON.stringify(economy, "\t"))
