extends "res://tests/builder_checks.gd"
## Actual M12 opening: normal initial builder and1000 credits, paid Depot300,
## Collector200, finite harvesting, Factory600 and Rocket250, all ordinary work.
## No cargo injection, wallet grants, direct progress, free actors or teleports.
## Only the instance's first enemy wave is deferred to600 simulated seconds;
## the enemy economy, normal unit defaults and shared scene remain unchanged.

const ECONOMY_BUILDER_PARK := Vector3(-14.5, 0, -1.5)
const ECONOMY_COLLECTOR_RALLY := Vector3(-5, 0, 2)


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1280, 720)
	var logger := EngineErrorProbe.new()
	OS.add_logger(logger)
	await _earned_builder_opening()
	if is_instance_valid(field): field.queue_free()
	await _frames(6)
	_check(root.get_children().is_empty() and get_nodes_in_group("combat_projectiles").is_empty(), "builder earned integration removes all actors, queues and construction/access claims")
	OS.remove_logger(logger)
	_check(logger.error_count() == 0, "builder earned integration has no native errors or warnings")
	print("BUILDER_INTEGRATION_CHECKS: %d checks, %d failures; native_errors=%d" % [checks, failures, logger.error_count()])
	quit(0 if failures == 0 else 1)


func _earned_builder_opening() -> void:
	await _fresh_builder(1000, true)
	var actor := _player_builders()[0]
	var cache := _depot_player_cache()
	_check(cache != null and cache.cache_id == 1 and cache.remaining == 2000 and cache != builders.enemy_cache, "normal opening exposes the original finite accessible player cache")
	if cache == null: return
	_check(builders.starting_credits == 1000 and DEPOT.credit_cost + COLLECTOR_RECIPE.credit_cost <= builders.credits.balance(1), "unchanged starting credits fund the actual Depot300 and first Collector200 opening")
	var depot_site := await _builder_arrival(await _builder_place(actor))
	if depot_site == null or not await _builder_complete(depot_site): return
	var depot := depot_site.building()
	_check(depot.kind == RTSBuilding.Kind.SUPPLY_DEPOT and depot.operational and depot.recipe == COLLECTOR_RECIPE and builders.valid_dropoff(depot, 1) and actor.assigned_site_id == 0 and builders.credits.balance(1) == 700, "initial builder physically completes the paid Depot and unlocks ordinary Collector production/dropoff")
	_check(not depot.production.enqueue(1, BUILDER_RECIPE).accepted and not depot.production.enqueue(1, ROCKET_RECIPE).accepted, "completed Depot remains Collector-only and cannot train builders or combat vehicles")
	# The initial builder clears the working area by an ordinary accepted Move,
	# preserving safe producer/delivery clearance without repositioning any actor.
	builders.selection.select_clicked(actor, false)
	await physics_frame
	_check(_complete(builders.issue_move(ECONOMY_BUILDER_PARK)), "completed builder accepts normal Move away from the Depot work face")
	if not await _until(func() -> bool: return actor.movement_state == RTSUnit.MovementState.ARRIVED, 10, "initial builder physically clears the completed Depot approach"): return
	await physics_frame
	_check(depot.production.set_rally(1, ECONOMY_COLLECTOR_RALLY).accepted, "Depot accepts unchanged normal ground rally for its first Collector")
	var deployments: Array[Dictionary] = []
	depot.production.deployed.connect(func(job: int, identity: int, rally: bool) -> void:
		deployments.append({"job": job, "unit": identity, "rally": rally, "tick": Engine.get_physics_frames()})
	)
	var queued := depot.production.enqueue(1, COLLECTOR_RECIPE)
	var queued_tick := Engine.get_physics_frames()
	_check(queued.accepted and depot.production.count() == 1 and depot.production.jobs()[0].paid == 200 and builders.credits.balance(1) == 500, "normal Depot queue charges exactly200 for the opening's first player Collector")
	await _frames(358)
	_check(deployments.is_empty() and depot.production.progress() < 1.0, "paid Collector does not deploy before its unchanged six-second duration")
	if not await _until(func() -> bool: return deployments.size() == 1, 3, "real Depot queue safely deploys its first paid Collector"): return
	var truck := _last_unit(depot.production) as CollectorTruck
	_check(truck != null and builders.contains_unit(truck) and truck.owner_id == 1 and builders.collectors.has(truck) and deployments[0].job == queued.job_id and deployments[0].tick - queued_tick >= 360 and deployments[0].rally, "first player Collector is ordinary registered paid deployment with completed training and accepted rally")
	if truck == null: return
	_check(truck.harvesting.cargo == 0 and truck.harvesting.cache_node() == null and truck.harvesting.dropoff_node() == null and not truck.harvesting.automatic and truck.combat.weapon == null, "new Collector begins empty and unassigned, with no builder or attack capability")
	builders.selection.select_clicked(truck, false)
	await physics_frame
	_check(not builders.construction.place(1, truck, builders.construction_definition, FIRST).accepted and builders.credits.balance(1) == 500, "normally produced Collector cannot construct or spend building credits")
	if not await _until(func() -> bool: return truck.movement_state == RTSUnit.MovementState.ARRIVED, 12, "first paid Collector physically follows its normal rally"): return
	var ledger := {"loaded": 0, "deposited": 0, "spent": 500, "owner_correct": true, "conserved": true, "coherent": true, "events": []}
	truck.harvesting.transferred.connect(func(transfer: HarvestTransfer) -> void:
		ledger.owner_correct = ledger.owner_correct and transfer.owner_id == 1 and transfer.collector_id == truck.unit_id
		if transfer.kind == HarvestTransfer.Kind.LOAD: ledger.loaded += transfer.amount
		else:
			ledger.deposited += transfer.amount
			ledger.events.append({"amount": transfer.amount, "target": transfer.target_id, "tick": Engine.get_physics_frames()})
		ledger.conserved = ledger.conserved and cache.remaining + truck.harvesting.cargo + ledger.deposited == 2000
		ledger.coherent = ledger.coherent and builders.credits.balance(1) == 1000 + ledger.deposited - ledger.spent
	)
	await _hud_pick_unit(truck)
	await _click(_world_screen(cache.global_position + Vector3.UP), MOUSE_BUTTON_RIGHT)
	_check(truck.harvesting.automatic and truck.harvesting.cache_node() == cache, "viewport right-click sends the normally produced Collector to the actual finite cache")
	if not await _until(func() -> bool: return ledger.deposited >= 400, 90, "actual loading, travel and unloading earn400 additional player credits"):
		_print_builder_economy_failure(truck, ledger)
		return
	truck.stop()
	_check(ledger.deposited == 400 and ledger.events.size() == 4 and ledger.events.all(func(event: Dictionary) -> bool: return event.amount == 100 and event.target == depot.get_instance_id()) and builders.credits.balance(1) == 900, "four actual full Depot deposits fund the production-building-and-army expansion")
	_check(builders.credits.balance(1) - ledger.deposited < FACTORY.credit_cost, "without the proven earned deposits the normal remaining opening balance cannot fund the Factory")
	var factory_result := await _builder_place(actor, FACTORY, FIRST)
	if factory_result.accepted: ledger.spent += FACTORY.credit_cost
	_check(factory_result.accepted and factory_result.paid == 600 and builders.credits.balance(1) == 300, "same initial builder commits the existing600-credit Factory using genuinely earned income")
	var factory_site := await _builder_arrival(factory_result)
	if factory_site == null or not await _builder_complete(factory_site): return
	var factory := factory_site.building()
	_check(factory.kind == RTSBuilding.Kind.VEHICLE_FACTORY and factory.operational and factory.recipe == ROCKET_RECIPE and factory_site.elapsed == 15 and actor.assigned_site_id == 0 and not actor.moving, "initial Bulldozer physically completes the full ordinary15-second Factory and becomes idle")
	var army_job := factory.production.enqueue(1, ROCKET_RECIPE)
	if army_job.accepted: ledger.spent += 250
	_check(army_job.accepted and factory.production.jobs()[0].paid == 250 and builders.credits.balance(1) == 50, "earned expansion pays the ordinary250-credit Rocket Vehicle through normal Factory queue")
	if not await _until(func() -> bool: return factory.production.count() == 0 and not factory.production.last_deployment.is_empty(), 11, "paid Rocket Vehicle completes actual training and collision-safe deployment"): return
	var rocket := _last_unit(factory.production)
	_check(rocket != null and builders.contains_unit(rocket) and rocket.owner_id == 1 and not rocket is Bulldozer and not rocket is CollectorTruck and rocket.combat.weapon != null and rocket.combat.weapon.definition == CombatField.ROCKET, "Depot-to-Collector-to-earned-Factory chain produces an ordinary armed registered player vehicle")
	if rocket == null: return
	builders.selection.select_clicked(rocket, false)
	await physics_frame
	_check(_complete(builders.issue_move(Vector3(-5, 0, 16))), "earned combat vehicle accepts an ordinary player ground command")
	if not await _until(func() -> bool: return not rocket.moving, 25, "earned combat unit physically executes its ordinary movement command"): return
	_check(rocket.movement_state == RTSUnit.MovementState.ARRIVED and rocket.global_position.distance_to(Vector3(-5, 0, 16)) < 0.5, "earned combat unit actually reaches the ordered ground position")
	await physics_frame
	_check(_complete(builders.issue_attack_move(Vector3(8, 0, 16))) and rocket.attack_move.active, "produced combat actor retains ordinary Attack Move capability toward the enemy side")
	_check(ledger.owner_correct and ledger.conserved and ledger.coherent and ledger.loaded == 400 and ledger.deposited == 400 and ledger.spent == 1350 and cache.remaining == 1600 and truck.harvesting.cargo == 0 and builders.credits.balance(1) == 50, "normal opening reconciles1000 starting+400 real income−1350 paid construction/units=50 remaining")
	_check(deployments.size() == 1 and _player_builders().size() == 1 and builders.collectors.filter(func(unit: CollectorTruck) -> bool: return unit.owner_id == 1).size() == 1 and builders.result == BaseAssaultField.Result.RUNNING, "complete real opening retains exactly the initial builder and one paid Collector in an active match")
	await _builder_capture("builder_earned_depot_collector_factory_army_1280x720")
	print("BUILDER_INTEGRATION: elapsed=%.3f builder=%d collector=%d combat=%d ledger=%s enemy_wallet=%d" % [builders.elapsed, actor.unit_id, truck.unit_id, rocket.unit_id, ledger, builders.credits.balance(2)])


func _print_builder_economy_failure(truck: CollectorTruck, ledger: Dictionary) -> void:
	print("BUILDER_INTEGRATION_FAILURE: elapsed=%.3f collector=%d position=%s destination=%s moving=%s movement=%s harvest=%s reason=%s cargo=%d wallet=%d ledger=%s" % [builders.elapsed, truck.unit_id, truck.global_position, truck.assigned_destination, truck.moving, truck.movement_state, truck.harvesting.state, truck.harvesting.reason, truck.harvesting.cargo, builders.credits.balance(1), ledger])
