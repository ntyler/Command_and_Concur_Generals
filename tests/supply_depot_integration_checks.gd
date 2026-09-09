extends "res://tests/construction_checks.gd"
## Real earned M11 economy, using the normal scene and fixed-step test harness.
## Only player starting credits (0) and earliest enemy wave (600s) are overridden.
## No grants, cargo prefills, direct deployments, teleports, or transfer calls.

const DEPOT: ConstructionDefinition = preload("res://construction/supply_depot.tres")
const COLLECTOR_RECIPE: ProductionDefinition = preload("res://production/collector_truck.tres")
const ECONOMIC_DEPOT := Vector3(-10.1, 0, -6)
const COLLECTOR_RALLY := Vector3(-5, 0, 2)
const RETURN_ORIGIN := Vector3(-10.5, 0, -13)
var economy: EconomyAssaultField
var player_cache: SupplyCache


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1280, 720)
	var logger := EngineErrorProbe.new()
	OS.add_logger(logger)
	await _earned_depot_loop()
	if is_instance_valid(economy): economy.queue_free()
	await _frames(6)
	_check(root.get_children().is_empty() and get_nodes_in_group("combat_projectiles").is_empty(), "earned depot integration releases the field, queues, claims and actors")
	OS.remove_logger(logger)
	_check(logger.error_count() == 0, "earned depot integration has no native errors or warnings")
	print("SUPPLY_DEPOT_INTEGRATION_CHECKS: %d checks, %d failures; native_errors=%d" % [checks, failures, logger.error_count()])
	quit(0 if failures == 0 else 1)


func _fresh_depot_economy() -> void:
	economy = load("res://scenes/supply_depot_assault.tscn").instantiate() as EconomyAssaultField
	economy.starting_credits = 0
	economy.enemy_config = economy.enemy_config.duplicate(true) as EnemyEconomyConfig
	economy.enemy_config.first_wave_time = 600.0
	field = economy
	world = economy
	harvest = economy
	root.add_child(economy)
	current_scene = economy
	economy.camera_rig.edge_scrolling_enabled = false
	# EconomyAssault registers its enemy-assigned cache before the inherited
	# western caches. Resolve the actual declared player-side geometry, not order.
	var expected := HarvestField.CACHE_FOOTPRINTS[0].get_center()
	for candidate in economy.registered_caches():
		if Vector2(candidate.global_position.x, candidate.global_position.z).is_equal_approx(expected):
			player_cache = candidate
	await _until(_current_harvest_navigation, 2, "new economy field owns all actual collector navigation starts")
	_check(is_instance_valid(player_cache) and player_cache != economy.enemy_cache and player_cache.cache_id == 1, "earned fixture resolves western cache one by declared geometry independently of registration order")
	_check(economy.credits.balance(1) == 0 and economy.registered_caches().all(func(cache: SupplyCache) -> bool: return cache.remaining == 2000), "supported pre-ready configuration starts player at zero with unchanged finite supplies")
	_check(economy.supply_depot_definition == DEPOT and economy.construction.sites.is_empty() and economy.registered_buildings().all(func(building: RTSBuilding) -> bool: return building.kind != RTSBuilding.Kind.SUPPLY_DEPOT), "normal supply-depot assault composition starts without a prebuilt depot")
	_check(economy.units.size() == 10 and economy.collectors.size() == 4 and economy.enemy_config.starting_credits == 300 and economy.enemy_config.wave_interval == 60 and economy.enemy_config.preferred_wave_size == 3, "controlled first-wave deferral preserves original forces, enemy funds and repeat-wave defaults")


func _record_earned(truck: CollectorTruck, ledger: Dictionary) -> void:
	truck.harvesting.transferred.connect(func(transfer: HarvestTransfer) -> void:
		ledger["owner_correct"] = ledger["owner_correct"] and transfer.owner_id == 1 and transfer.collector_id == truck.unit_id
		if transfer.kind == HarvestTransfer.Kind.LOAD:
			ledger["loaded"] += transfer.amount
		else:
			ledger["deposited"] += transfer.amount
			ledger["events"].append({"collector": transfer.collector_id, "target": transfer.target_id, "amount": transfer.amount, "tick": Engine.get_physics_frames(), "wallet": economy.credits.balance(1)})
		var cargo := 0
		for actor in economy.units:
			if actor is CollectorTruck and actor.owner_id == 1: cargo += (actor as CollectorTruck).harvesting.cargo
		ledger["conserved"] = ledger["conserved"] and player_cache.remaining + cargo + ledger["deposited"] == 2000
		ledger["coherent"] = ledger["coherent"] and economy.credits.balance(1) == ledger["deposited"] - ledger["spent"]
	)


func _earned_build(definition: ConstructionDefinition, point: Vector3, ledger: Dictionary) -> RTSBuilding:
	await physics_frame
	var placed := economy.construction.place(1, economy.headquarters, definition, point)
	if placed.accepted: ledger["spent"] += placed.paid
	_check(placed.accepted and placed.paid == definition.credit_cost and economy.credits.balance(1) == ledger["deposited"] - ledger["spent"], "earned %s construction commits its actual configured price once: %s" % [definition.display_name(), placed.reason])
	var site := await _ready_site(placed)
	if site == null or not await _complete_site(site): return null
	return site.building()


func _deployed_collector(producer: UnitProduction) -> CollectorTruck:
	var identity: int = producer.last_deployment.get("unit_id", -1)
	for actor in economy.units:
		if actor.unit_id == identity: return actor as CollectorTruck
	return null


func _earned_depot_loop() -> void:
	await _fresh_depot_economy()
	if not is_instance_valid(player_cache): return
	var first := economy.collectors[0]
	var cache := player_cache
	var ledger := {"loaded": 0, "deposited": 0, "spent": 0, "owner_correct": true, "conserved": true, "coherent": true, "events": []}
	_record_earned(first, ledger)
	await physics_frame
	var unfunded := economy.construction.place(1, economy.headquarters, DEPOT, ECONOMIC_DEPOT)
	_check(not unfunded.accepted and economy.credits.balance(1) == 0 and economy.construction.sites.is_empty(), "zero-credit start cannot build the depot before harvesting")
	economy.selection.select_clicked(first, false)
	_check(_complete(economy.issue_harvest(cache)), "existing player collector receives an ordinary real-cache harvest assignment")
	if not await _until(func() -> bool: return economy.credits.balance(1) == 300, 65, "actual HQ loading, travel and deposits earn the 300-credit depot cost"):
		_print_earned_failure(first, ledger, "HQ funds")
		return
	first.stop()
	_check(ledger.deposited == 300 and ledger.events.size() == 3 and ledger.events.all(func(event: Dictionary) -> bool: return event.target == economy.headquarters.get_instance_id() and event.amount == 100), "all three initial full loads actually committed to the existing owned HQ")
	var depot := await _earned_build(DEPOT, ECONOMIC_DEPOT, ledger)
	if depot == null: return
	_check(depot.operational and depot.recipe == COLLECTOR_RECIPE and depot.health.current == economy.barracks_health and economy.valid_dropoff(depot, 1), "normally completed depot becomes the health-default drop-off and Collector producer")
	economy.selection.select_clicked(first, false)
	_check(_complete(economy.issue_harvest(cache)), "original collector resumes the same real cache after normal depot construction")
	if not await _until(func() -> bool: return economy.credits.balance(1) == 600, 85, "existing collector earns collector and barracks costs through real depot trips"):
		_print_earned_failure(first, ledger, "depot funds")
		return
	first.stop()
	_check(ledger.deposited == 900 and ledger.events.slice(3).all(func(event: Dictionary) -> bool: return event.target == depot.get_instance_id()), "later automatic trips use the newly completed useful depot while preserving the owner wallet")
	# Park both original trucks through normal commands, clearing the used depot
	# dock as well as its approach. No actor is teleported to simplify the route.
	for index in 2:
		var original := economy.collectors[index]
		economy.selection.select_clicked(original, false)
		_check(_complete(economy.issue_move(Vector3(-23 + index * 3, 0, 18))), "original collector accepts ordinary movement away from the controlled delivery lanes")
		if not await _until(func() -> bool: return original.movement_state == RTSUnit.MovementState.ARRIVED, 20, "original collector physically clears the controlled delivery lane"): return
	var barrack := await _earned_build(economy.construction_definition, SECOND, ledger)
	if barrack == null: return
	var producer := depot.production
	_check(producer.set_rally(1, COLLECTOR_RALLY).accepted, "earned depot accepts the existing ground-rally operation")
	var deployments: Array[Dictionary] = []
	producer.deployed.connect(func(job: int, identity: int, rally: bool) -> void:
		deployments.append({"job": job, "unit": identity, "rally": rally, "tick": Engine.get_physics_frames()})
	)
	var accepted := producer.enqueue(1, COLLECTOR_RECIPE)
	if accepted.accepted: ledger["spent"] += 200
	var queued_tick := Engine.get_physics_frames()
	_check(accepted.accepted and producer.count() == 1 and producer.jobs()[0].paid == 200 and producer.jobs()[0].duration == 6 and economy.credits.balance(1) == 0, "900 actually earned credits fund depot 300, barracks 400 and one normal Collector queue job 200")
	await _frames(358)
	_check(deployments.is_empty() and producer.count() == 1 and producer.progress() < 1.0, "collector production cannot deploy before six simulated seconds")
	if not await _until(func() -> bool: return deployments.size() == 1, 2, "real six-second Collector queue deploys through ordinary safe spawn and registration"): return
	var produced := _deployed_collector(producer)
	_check(is_instance_valid(produced) and deployments[0].job == accepted.job_id and deployments[0].rally and deployments[0].tick - queued_tick >= 360 and producer.count() == 0, "one deployed collector traces to its paid job and accepted ground rally")
	if not is_instance_valid(produced): return
	_check(economy.contains_unit(produced) and economy.collectors.has(produced) and produced.owner_id == 1 and produced.unit_id > 10 and produced.harvesting.cargo == 0 and produced.harvesting.state == CollectorHarvest.State.IDLE and produced.harvesting.cache_node() == null, "produced collector has fresh empty idle harvesting state, correct owner, stable identity and field membership")
	_check(produced.movement_speed == 4.0 and produced.maximum_health == 150 and produced.combat.health.current == 150 and produced.combat.weapon == null and produced.cargo_capacity == 100 and produced.loading_amount == 25 and produced.loading_interval == 1.0 and produced.unloading_duration == 1.0, "produced truck preserves all existing movement, health, cargo and transfer defaults")
	if not await _until(func() -> bool: return not produced.moving, 10, "normally produced collector physically arrives at its ground rally"): return
	_check(produced.movement_state == RTSUnit.MovementState.ARRIVED and produced.global_position.distance_to(COLLECTOR_RALLY) <= produced.stopping_distance and produced.harvesting.cache_node() == null and economy.credits.balance(1) == 0, "ground rally performs no automatic harvesting assignment or income")
	_record_earned(produced, ledger)
	# Observe the normal produced collector through viewport selection and resource
	# input. Existing harness events are automated input, not a human playtest.
	await _click(_screen(produced), MOUSE_BUTTON_LEFT)
	_check(economy.selection.selected_units() == [produced], "viewport selects the normally produced collector")
	await _click(_world_screen(cache.global_position + Vector3.UP), MOUSE_BUTTON_RIGHT)
	_check(produced.harvesting.automatic and produced.harvesting.cache_node() == cache, "viewport resource command assigns the produced truck to the actual cache")
	if not await _until(func() -> bool: return produced.harvesting.state == CollectorHarvest.State.RETURNING and produced.harvesting.cargo == 100, 15, "produced collector physically reaches cache and loads four unchanged 25-supply intervals"): return
	if not await _prepare_return(produced): return
	var depot_trip := await _measure_delivery(produced, depot, economy.headquarters, ledger, "depot", true)
	if depot_trip.is_empty(): return
	produced.stop()
	_check(economy.credits.balance(1) == 100 and ledger.deposited == 1000 and ledger.events[-1].collector == produced.unit_id and ledger.events[-1].target == depot.get_instance_id(), "produced collector's actual depot deposit is the only money available for army production")
	var army_job := barrack.production.enqueue(1, barrack.recipe)
	if army_job.accepted: ledger["spent"] += 100
	_check(army_job.accepted and economy.credits.balance(1) == 0 and barrack.production.jobs()[0].paid == 100, "that exact depot income pays for ordinary 100-credit Rifle production")
	if not await _until(func() -> bool: return barrack.production.count() == 0 and not barrack.production.last_deployment.is_empty(), 6, "depot-funded Rifle actually completes ordinary training and safe deployment"): return
	var rifle: RTSUnit
	for actor in economy.units:
		if actor.unit_id == barrack.production.last_deployment.unit_id: rifle = actor
	_check(is_instance_valid(rifle) and not rifle is CollectorTruck and rifle.owner_id == 1 and rifle.combat.weapon != null and economy.contains_unit(rifle), "depot-to-collector-to-army chain ends in an armed registered player Rifle")
	await _capture("m11_earned_depot_collector_rifle_1280x720")
	# A shared approach to the cache did not ensure a shared loading bay in the
	# original failed fixture. Move the genuinely loaded truck to RETURN_ORIGIN
	# before BOTH return commands; preparation is outside both timed intervals.
	economy.selection.select_clicked(produced, false)
	_check(_complete(economy.issue_move(COLLECTOR_RALLY)), "controlled comparison returns to the original cache approach through ordinary movement")
	if not await _until(func() -> bool: return produced.movement_state == RTSUnit.MovementState.ARRIVED, 10, "comparison collector physically reaches its original rally approach"): return
	await _click(_world_screen(cache.global_position + Vector3.UP), MOUSE_BUTTON_RIGHT)
	_check(produced.harvesting.automatic and produced.harvesting.cache_node() == cache, "controlled comparison uses viewport harvesting from the same approach to obtain real cargo")
	if not await _until(func() -> bool: return produced.harvesting.state == CollectorHarvest.State.RETURNING and produced.harvesting.cargo == 100, 15, "same produced collector genuinely loads the comparison cargo"): return
	if not await _prepare_return(produced): return
	var hq_trip := await _measure_delivery(produced, economy.headquarters, depot, ledger, "HQ")
	if hq_trip.is_empty(): return
	_check(produced.harvesting.state == CollectorHarvest.State.IDLE and not produced.harvesting.automatic and produced.harvesting.cargo == 0, "actual manual HQ delivery completes once and idles")
	_check(depot_trip.start.distance_to(hq_trip.start) <= 0.4 and depot_trip.obstacles == hq_trip.obstacles and depot_trip.nav_iteration == hq_trip.nav_iteration and depot_trip.configuration == hq_trip.configuration and depot_trip.cargo == hq_trip.cargo, "both measured returns begin at the same controlled point within ordinary stopping tolerance with identical cargo, configuration and navigation geometry")
	_check(depot_trip.start.distance_to(hq_trip.start) <= 0.4 and depot_trip.planned < depot_trip.alternative and hq_trip.alternative < hq_trip.planned and depot_trip.travelled < hq_trip.travelled and depot_trip.return_seconds < hq_trip.return_seconds and depot_trip.delivery_seconds < hq_trip.delivery_seconds, "controlled same-cache comparison observes a shorter valid depot route and shorter actual return without modified truck values")
	_check(ledger.owner_correct and ledger.conserved and ledger.coherent and ledger.loaded == 1100 and ledger.deposited == 1100 and ledger.spent == 1000 and economy.credits.balance(1) == 100 and cache.remaining == 900, "finite economy reconciles exactly: 1100 real supplies deposited, 1000 normally spent, 100 remaining")
	_check(deployments.size() == 1 and economy.result == BaseAssaultField.Result.RUNNING and not economy.assault_issued and economy.elapsed < 240, "earned chain retains one collector deployment and the unchanged live match objective within its controlled budget")
	print("SUPPLY_DEPOT_INTEGRATION: elapsed=%.3f collector=%d rifle=%d ledger=%s depot_trip=%s hq_trip=%s enemy_wallet=%d" % [economy.elapsed, produced.unit_id, rifle.unit_id if is_instance_valid(rifle) else -1, ledger, depot_trip, hq_trip, economy.credits.balance(2)])


func _print_earned_failure(truck: CollectorTruck, ledger: Dictionary, stage: String) -> void:
	var work := truck.harvesting
	var cache := work.cache_node()
	var target := work.dropoff_node()
	print("SUPPLY_DEPOT_INTEGRATION_FAILURE: stage=%s elapsed=%.3f collector=%d position=%s moving=%s movement_state=%s assigned=%s harvest_state=%s reason=%s rejected=%s cargo=%d cache=%s cache_position=%s cache_remaining=%d dropoff=%s dropoff_position=%s wallet=%d ledger=%s" % [stage, economy.elapsed, truck.unit_id, truck.global_position, truck.moving, truck.movement_state, truck.assigned_destination, work.state, work.reason, work.last_rejection, work.cargo, cache.cache_id if is_instance_valid(cache) else -1, cache.global_position if is_instance_valid(cache) else Vector3.ZERO, cache.remaining if is_instance_valid(cache) else -1, target.name if is_instance_valid(target) else "none", target.global_position if is_instance_valid(target) else Vector3.ZERO, economy.credits.balance(1), ledger])


func _prepare_return(truck: CollectorTruck) -> bool:
	_check(truck.stop() and truck.harvesting.cargo == 100, "ordinary Stop preserves the entire genuinely loaded comparison cargo")
	economy.selection.select_clicked(truck, false)
	_check(_complete(economy.issue_move(RETURN_ORIGIN)), "loaded collector accepts ordinary movement to the shared return origin")
	if not await _until(func() -> bool: return truck.movement_state == RTSUnit.MovementState.ARRIVED, 8, "loaded collector physically reaches the shared return origin"): return false
	_check(truck.global_position.distance_to(RETURN_ORIGIN) <= truck.stopping_distance and truck.harvesting.cargo == 100 and truck.harvesting.state == CollectorHarvest.State.IDLE and not truck.moving, "return preparation ends at ordinary stopping tolerance with unchanged real cargo and idle harvesting")
	return true


func _measure_delivery(truck: CollectorTruck, target: RTSBuilding, alternative: RTSBuilding, ledger: Dictionary, label: String, automatic: bool = false) -> Dictionary:
	var work := truck.harvesting
	await physics_frame
	var planned := economy.plan_access(truck, target)
	var other := economy.plan_access(truck, alternative)
	_check(not planned.is_empty() and not other.is_empty(), "%s comparison has physically usable navigable access to both buildings" % label)
	if planned.is_empty() or other.is_empty(): return {}
	_check(absf(float(planned.route_length) - truck.global_position.distance_to(planned.point)) <= 0.05, "%s measured return is an unobstructed navigable segment in the controlled fixture" % label)
	_check(absf(float(other.route_length) - truck.global_position.distance_to(other.point)) <= 0.05, "%s alternative also has an unobstructed navigable segment from the same actual origin" % label)
	var measurement := {"start": truck.global_position, "requested_origin": RETURN_ORIGIN, "target_access": planned.point, "target_dock": planned.dock, "target_slot": planned.slot, "alternative_access": other.point, "planned": planned.route_length, "alternative": other.route_length, "travelled": 0.0, "return_seconds": 0.0, "unload_seconds": 0.0, "delivery_seconds": 0.0, "retained": true, "cargo": work.cargo, "configuration": [truck.movement_speed, truck.cargo_capacity, truck.loading_amount, truck.loading_interval, truck.unloading_duration, truck.stopping_distance], "obstacles": economy.obstacles.duplicate(), "nav_iteration": NavigationServer3D.map_get_iteration_id(economy.get_world_3d().get_navigation_map()), "navigation_suspended": truck.navigation_suspended, "closest_other_actor": INF}
	# Existing route queries prove both segments are straight. Check the actual
	# other actors against both segments throughout travel, without disabling any.
	var accepted := economy.issue_harvest(player_cache) if automatic else economy.issue_deposit(target)
	_check(_complete(accepted) and work.automatic == automatic and work.dropoff_node() == target and work._access.point == planned.point and not truck.navigation_suspended, "%s public return command selects the measured access immediately from the prepared origin" % label)
	var generation := work.generation
	var start_tick := Engine.get_physics_frames()
	var previous := truck.global_position
	var before: int = ledger.deposited
	var wallet := economy.credits.balance(1)
	for tick in 1800:
		if work.state != CollectorHarvest.State.RETURNING: break
		for actor in economy.units:
			if actor == truck: continue
			for endpoint: Vector3 in [planned.point, other.point]:
				var nearest := Geometry3D.get_closest_point_to_segment(actor.global_position, measurement.start, endpoint)
				measurement.closest_other_actor = minf(measurement.closest_other_actor, actor.global_position.distance_to(nearest))
		measurement.retained = measurement.retained and work.generation == generation and work.dropoff_node() == target
		await _frames(1)
		measurement.travelled += truck.global_position.distance_to(previous)
		previous = truck.global_position
	measurement.return_seconds = float(Engine.get_physics_frames() - start_tick) / 60.0
	measurement.start_tick = start_tick
	measurement.unloading_tick = Engine.get_physics_frames()
	_check(measurement.closest_other_actor > RTSUnit.BODY_RADIUS * 2.0 + 1.0 and economy.result == BaseAssaultField.Result.RUNNING and not economy.assault_issued, "%s controlled return lanes remain clear of unrelated actor traffic and combat" % label)
	_check(work.state == CollectorHarvest.State.UNLOADING and measurement.retained and work.dropoff_node() == target, "%s actual return retains its chosen identity/order and reaches valid unloading" % label)
	if work.state != CollectorHarvest.State.UNLOADING: return {}
	var unloading_tick := Engine.get_physics_frames()
	_check(work.cargo == 100 and ledger.deposited == before and economy.credits.balance(1) == wallet, "%s actual arrival retains all cargo until its unload boundary" % label)
	await _frames(58)
	_check(work.cargo == 100 and ledger.deposited == before and economy.credits.balance(1) == wallet, "%s unload does not credit early during the first 58 ticks" % label)
	if not await _until(func() -> bool: return ledger.deposited == before + 100, 1.1, "%s real unload transfers exactly 100 once" % label): return {}
	measurement.unload_seconds = float(Engine.get_physics_frames() - unloading_tick) / 60.0
	measurement.deposit_tick = Engine.get_physics_frames()
	measurement.delivery_seconds = float(measurement.deposit_tick - start_tick) / 60.0
	_check(ledger.events[-1].target == target.get_instance_id() and ledger.events[-1].collector == truck.unit_id and economy.credits.balance(1) == wallet + 100 and measurement.unload_seconds >= 1.0, "%s committed transfer names the actual target, owner collector and completed unload interval" % label)
	return measurement
