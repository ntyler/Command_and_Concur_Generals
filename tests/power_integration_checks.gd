extends "res://tests/power_checks.gd"
## Actual M13 opening: original1000 credits and initial Bulldozer; paid Depot,
## paid Collector, actual finite-cache deliveries, paid Barracks/Plant/Rifle.
## No free credits, direct progress writes, injected cargo, actor teleports or
## manually registered buildings. Only instance first-wave time is deferred,
## exactly as in the earlier earned opening; the enemy economy remains active.

const POWER_ECONOMY_BUILDER_PARK := Vector3(-14.5, 0, -1.5)
const POWER_ECONOMY_COLLECTOR_RALLY := Vector3(-5, 0, 2)


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1280, 720)
	var logger := EngineErrorProbe.new()
	OS.add_logger(logger)
	await _earned_power_opening()
	if is_instance_valid(field): field.queue_free()
	await _frames(6)
	_check(root.get_children().is_empty() and get_nodes_in_group("combat_projectiles").is_empty(), "earned power integration removes actors, queues, grid listeners and construction/access claims")
	OS.remove_logger(logger)
	_check(logger.error_count() == 0, "earned power opening and teardown have no native errors or warnings")
	print("POWER_INTEGRATION_CHECKS: %d checks, %d failures; native_errors=%d" % [checks, failures, logger.error_count()])
	quit(0 if failures == 0 else 1)


func _earned_power_opening() -> void:
	await _fresh_power(1000, true)
	var actor := _player_builders()[0]
	var cache := _depot_player_cache()
	_check(cache != null and cache.remaining == 2000 and powered.credits.balance(1) == 1000 and powered.collectors.filter(func(truck: CollectorTruck) -> bool: return truck.owner_id == 1).is_empty(), "earned power opening starts from actual1000 credits, original builder, finite cache and no free player Collector")
	if cache == null: return
	var depot := await _power_build(actor, DEPOT, DEPOT_POINT)
	if depot == null: return
	_check(powered.credits.balance(1) == 700 and depot.operational and powered.valid_dropoff(depot, 1) and _grid_is(1, 0, 0), "initial builder completes ordinary paid300-credit Depot with no power prerequisite or demand")
	powered.selection.select_clicked(actor, false)
	await physics_frame
	_check(_complete(powered.issue_move(POWER_ECONOMY_BUILDER_PARK)), "initial builder accepts ordinary Move to clear Depot work face")
	if not await _until(func() -> bool: return actor.movement_state == RTSUnit.MovementState.ARRIVED, 10, "builder physically clears the Collector production and delivery face"): return
	await physics_frame
	_check(depot.production.set_rally(1, POWER_ECONOMY_COLLECTOR_RALLY).accepted, "Depot accepts ordinary first-Collector rally")
	var collector_job := depot.production.enqueue(1, COLLECTOR_RECIPE)
	_check(collector_job.accepted and powered.credits.balance(1) == 500, "ordinary Depot queue charges exactly200 for its first Collector")
	if not await _until(func() -> bool: return depot.production.count() == 0 and not depot.production.last_deployment.is_empty(), 7, "paid Collector finishes actual ordinary training and deployment"): return
	var truck := _last_unit(depot.production) as CollectorTruck
	_check(truck != null and powered.contains_unit(truck) and truck.harvesting.cargo == 0 and not truck.harvesting.automatic, "paid Collector is a real registered empty unassigned unit")
	if truck == null: return
	if not await _until(func() -> bool: return truck.movement_state == RTSUnit.MovementState.ARRIVED, 12, "paid Collector physically reaches its ordinary rally"): return
	var ledger := {"loaded": 0, "deposited": 0, "spent": 500, "low_loads": 0, "low_deposits": 0, "owner_correct": true, "conserved": true, "coherent": true, "events": []}
	truck.harvesting.transferred.connect(func(transfer: HarvestTransfer) -> void:
		ledger.owner_correct = ledger.owner_correct and transfer.owner_id == 1 and transfer.collector_id == truck.unit_id
		var low: bool = powered.power_snapshot(1).low_power
		if transfer.kind == HarvestTransfer.Kind.LOAD:
			ledger.loaded += transfer.amount
			if low: ledger.low_loads += transfer.amount
		else:
			ledger.deposited += transfer.amount
			if low: ledger.low_deposits += transfer.amount
			ledger.events.append({"amount": transfer.amount, "target": transfer.target_id, "low_power": low, "tick": Engine.get_physics_frames()})
		ledger.conserved = ledger.conserved and cache.remaining + truck.harvesting.cargo + ledger.deposited == 2000
		ledger.coherent = ledger.coherent and powered.credits.balance(1) == 1000 + ledger.deposited - ledger.spent
	)
	await _hud_pick_unit(truck)
	await _click(_world_screen(cache.global_position + Vector3.UP), MOUSE_BUTTON_RIGHT)
	_check(truck.harvesting.automatic and truck.harvesting.cache_node() == cache, "viewport harvest command sends paid Collector to the actual finite player cache")
	if not await _until(func() -> bool: return ledger.deposited >= 200, 55, "actual loading, travel and unloading earn expansion income"):
		_power_economy_failure(truck, ledger)
		return
	var barracks_result := await _builder_place(actor, POWER_BARRACKS, FIRST)
	if barracks_result.accepted: ledger.spent += POWER_BARRACKS.credit_cost
	var barracks_site := await _builder_arrival(barracks_result)
	if barracks_site == null or not await _builder_complete(barracks_site): return
	var barracks := barracks_site.building()
	_check(barracks.operational and barracks_site.elapsed == POWER_BARRACKS.duration and _grid_is(1, 0, 2), "initial builder completes the ordinary paid Barracks before any player plant and incurs full idle demand")
	if not await _until(func() -> bool: return powered.credits.balance(1) >= POWER_PLANT.credit_cost + POWER_RIFLE.credit_cost and ledger.low_loads > 0 and ledger.low_deposits > 0, 90, "Collector keeps loading/travelling/depositing through shortage until real income funds plant and Rifle"):
		_power_economy_failure(truck, ledger)
		return
	_check(ledger.deposited >= 500 and ledger.low_loads > 0 and ledger.low_deposits > 0 and _grid_is(1, 0, 2), "earned recovery proves actual Collector transfers continue while owner producers operate at half rate")
	var plant_result := await _builder_place(actor, POWER_PLANT, SECOND)
	if plant_result.accepted: ledger.spent += POWER_PLANT.credit_cost
	var plant_site := await _builder_arrival(plant_result)
	if plant_site == null: return
	_check(plant_result.paid == 500 and plant_site.elapsed < 1 and _grid_is(1, 0, 2), "same original Bulldozer travels and starts paid Power Plant work during genuine shortage")
	if not await _until(func() -> bool: return plant_site.elapsed >= 7.0, 8, "builder performs seven actual seconds before late Rifle scheduling"): return
	var producer := barracks.production
	var completions: Array[Dictionary] = []
	producer.deployed.connect(func(job: int, unit: int, rally: bool) -> void: completions.append({"job": job, "unit": unit, "rally": rally, "tick": Engine.get_physics_frames()}))
	var queued := producer.enqueue(1, POWER_RIFLE)
	if queued.accepted: ledger.spent += POWER_RIFLE.credit_cost
	var queue_tick := Engine.get_physics_frames()
	_check(queued.accepted and plant_site.elapsed >= 7.0 and plant_site.elapsed < 8.0 and producer.jobs()[0].duration == 5.0 and producer.jobs()[0].paid == 100, "late normal100-credit Rifle enqueue preserves five-second recipe while plant is unfinished")
	await _frames(60)
	_check(plant_site.state == ConstructionSite.State.CONSTRUCTING and producer.count() == 1 and absf(producer.jobs()[0].elapsed - 0.5) <= 0.035 and _grid_is(1, 0, 2), "same paid Rifle visibly earns half a training second during one real shortage second")
	var before_completion: float = producer.jobs()[0].elapsed
	if not await _builder_complete(plant_site): return
	_check(_grid_is(1, 10, 2) and producer.count() == 1 and producer.jobs()[0].id == queued.job_id and producer.jobs()[0].elapsed >= before_completion and producer.progress() < 1, "actual ten-second plant completion restores power while the original Rifle job remains active with preserved progress")
	var full_start: float = producer.jobs()[0].elapsed
	await _frames(60)
	_check(producer.count() == 1 and producer.jobs()[0].id == queued.job_id and absf(producer.jobs()[0].elapsed - full_start - 1.0) <= 0.035, "same active Rifle earns a full second immediately after real builder-driven power restoration")
	truck.stop()
	if not await _until(func() -> bool: return completions.size() == 1, 5, "earned mixed-rate Rifle completes once and deploys safely"): return
	var rifle := _last_unit(producer)
	_check(rifle != null and powered.contains_unit(rifle) and rifle.owner_id == 1 and rifle.combat.weapon != null and completions[0].job == queued.job_id and (completions[0].tick - queue_tick) / 60.0 > POWER_RIFLE.training_duration, "real paid Rifle deployment retains owner/job identity and observable extra time from shortage")
	if rifle == null: return
	powered.selection.select_clicked(rifle, false)
	await physics_frame
	var destination := Vector3(-15, 0, 16)
	_check(_complete(powered.issue_move(destination)), "newly produced Rifle accepts an ordinary player movement command")
	if not await _until(func() -> bool: return not rifle.moving, 25, "earned Rifle physically executes ordinary movement"): return
	_check(rifle.movement_state == RTSUnit.MovementState.ARRIVED and rifle.global_position.distance_to(destination) < 0.5, "paid mixed-rate Rifle actually reaches its commanded ground location")
	await physics_frame
	_check(_complete(powered.issue_attack_move(Vector3(8, 0, 16))) and rifle.attack_move.active, "produced Rifle retains normal Attack Move capability")
	_check(ledger.spent == 1500 and ledger.owner_correct and ledger.conserved and ledger.coherent and cache.remaining + truck.harvesting.cargo + ledger.deposited == 2000 and powered.credits.balance(1) == 1000 + ledger.deposited - 1500, "opening reconciles1000 starting plus actual deposits minus1500 paid Depot/Collector/Barracks/Plant/Rifle spending")
	_check(completions.size() == 1 and _player_builders().size() == 1 and powered.collectors.filter(func(unit: CollectorTruck) -> bool: return unit.owner_id == 1).size() == 1 and powered.result == BaseAssaultField.Result.RUNNING, "complete earned opening retains exactly original builder, one paid Collector and one Rifle deployment in an active match")
	await _power_capture("power_earned_opening_1280x720")
	print("POWER_INTEGRATION: elapsed=%.3f builder=%d collector=%d rifle=%d grid=%s ledger=%s wallet=%d enemy_wallet=%d" % [powered.elapsed, actor.unit_id, truck.unit_id, rifle.unit_id, powered.power_snapshot(1), ledger, powered.credits.balance(1), powered.credits.balance(2)])


func _power_economy_failure(truck: CollectorTruck, ledger: Dictionary) -> void:
	print("POWER_INTEGRATION_FAILURE: elapsed=%.3f collector=%d position=%s destination=%s movement=%s harvest=%s reason=%s cargo=%d wallet=%d grid=%s ledger=%s" % [powered.elapsed, truck.unit_id, truck.global_position, truck.assigned_destination, truck.movement_state, truck.harvesting.state, truck.harvesting.reason, truck.harvesting.cargo, powered.credits.balance(1), powered.power_snapshot(1), ledger])
