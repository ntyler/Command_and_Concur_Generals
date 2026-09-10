extends "res://tests/supply_depot_checks.gd"
## Real fixed-step local collection, empty-area parking, and production-command
## races. Focused geometry/cargo setup is labeled; the earned depot integration
## independently proves production and automatic income without cargo injection.


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1280, 720)
	var logger := EngineErrorProbe.new()
	OS.add_logger(logger)
	var chosen := "all"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--automatic-case="):
			chosen = argument.trim_prefix("--automatic-case=")
	var cases := ["production", "local", "reachability", "waiting", "commands"]
	_check(chosen == "all" or cases.has(chosen), "recognized automatic harvesting case")
	for case in cases:
		if chosen != "all" and chosen != case: continue
		var before := checks
		var failed := failures
		match case:
			"production": await _automatic_production()
			"local": await _automatic_local()
			"reachability": await _automatic_reachability()
			"waiting": await _automatic_waiting()
			"commands": await _automatic_commands()
		print("AUTOMATIC_CASE: %s checks=%d failures=%d" % [case, checks - before, failures - failed])
	if is_instance_valid(field): field.queue_free()
	await _frames(6)
	_check(root.get_children().is_empty(), "automatic harvesting teardown removes actors, cache and parking reservations")
	OS.remove_logger(logger)
	_check(logger.error_count() == 0, "automatic harvesting has no native errors or warnings")
	print("AUTOMATIC_HARVESTING_CHECKS: %d checks, %d failures; native_errors=%d" % [checks, failures, logger.error_count()])
	quit(0 if failures == 0 else 1)


func _automatic_production() -> void:
	await _fresh_depot(500)
	var depot := await _depot()
	if depot == null: return
	var producer := depot.production
	var trucks: Array[CollectorTruck] = []
	var ledger := {"loaded": 0, "deposited": 0, "events": 0, "generation": -1, "conserved": true, "owner": true, "stable": true}
	producer.deployed.connect(func(_job: int, _identity: int, _rally: bool) -> void:
		var truck := _last_unit(producer) as CollectorTruck
		trucks.append(truck)
		truck.harvesting.transferred.connect(func(transfer: HarvestTransfer) -> void:
			if ledger["generation"] < 0: ledger["generation"] = transfer.generation
			ledger["stable"] = ledger["stable"] and transfer.generation == ledger["generation"]
			ledger["owner"] = ledger["owner"] and transfer.owner_id == 1 and transfer.collector_id == truck.unit_id
			if transfer.kind == HarvestTransfer.Kind.LOAD:
				ledger["loaded"] += transfer.amount
			else:
				ledger["deposited"] += transfer.amount
				ledger["events"] += 1
				ledger["owner"] = ledger["owner"] and transfer.target_id == depot.get_instance_id()
				ledger["conserved"] = ledger["conserved"] and truck.harvesting.complete_deposit().amount == 0
			ledger["conserved"] = ledger["conserved"] and _depot_player_cache().remaining + _depot_player_cache(1).remaining + truck.harvesting.cargo + battle.credits.balance(1) == 4000
		)
	)
	_check(producer.enqueue(1, COLLECTOR_RECIPE).accepted and battle.credits.balance(1) == 0, "normal depot and truck costs spend the full 500-credit wallet before automatic gathering")
	if not await _until(func() -> bool: return ledger["events"] == 2, 38, "a normally produced truck automatically collects, deposits and repeats with no manual truck commands"): return
	var truck := trucks[0]
	_check(trucks.size() == 1 and producer.count() == 0 and ledger["loaded"] == 200 and ledger["deposited"] == 200 and battle.credits.balance(1) == 200 and truck.harvesting.cargo == 0, "two unchanged full loads replenish the existing zero-credit player wallet by exactly 200")
	_check(ledger["conserved"] and ledger["owner"] and ledger["stable"] and _depot_player_cache().remaining + _depot_player_cache(1).remaining == 3800, "automatic deposits preserve finite-cache conservation, eligible owned depot routing and exactly-once transfers")
	_check(truck.harvesting.automatic and truck.harvesting.state == CollectorHarvest.State.TO_SUPPLIES and truck.harvesting.collection_origin == depot.global_position, "after two deposits the unchanged automatic assignment immediately starts its next local collection trip")


func _automatic_local() -> void:
	await _fresh_harvest(35, 0)
	var truck := _select_collector()
	truck.collection_radius = 24.0
	var work := truck.harvesting
	var first := harvest.caches[0]
	var second := harvest.caches[1]
	var anchor := first.global_position
	var ledger := {"loads": 0, "deposits": 0, "conserved": true, "owner": true, "events": []}
	work.transferred.connect(func(result: HarvestTransfer) -> void:
		ledger["owner"] = ledger["owner"] and result.owner_id == 1
		if result.kind == HarvestTransfer.Kind.LOAD:
			ledger["loads"] += result.amount
			ledger["events"].append("L%d:%d" % [result.target_id, result.amount])
		else:
			ledger["deposits"] += result.amount
			ledger["events"].append("D:%d" % result.amount)
			ledger["conserved"] = ledger["conserved"] and work.complete_deposit().amount == 0
		ledger["conserved"] = ledger["conserved"] and first.remaining + second.remaining + work.cargo + harvest.credits.balance(1) == 70
	)
	_check(_complete(harvest.issue_harvest(first)), "explicit assignment starts the local finite collection loop at zero credits")
	if not await _until(func() -> bool: return work.state == CollectorHarvest.State.WAITING and harvest.credits.balance(1) == 70, 48, "truck delivers partial final cargo and automatically harvests the second nearby cache"): return
	_check(ledger["events"] == ["L1:25", "L1:10", "D:35", "L2:25", "L2:10", "D:35"], "each exhausted cache's remaining cargo deposits before loading from the next cache")
	_check(ledger["loads"] == 70 and ledger["deposits"] == 70 and ledger["conserved"] and ledger["owner"] and work.cargo == 0, "real local trips conserve finite supplies and exactly-once owner wallet deposits")
	_check(work.collection_origin == anchor and work.reason == "No nearby supplies" and work.automatic and harvest._access_claims.is_empty(), "reselection retains its fixed local anchor and waits with the required status after all local sources empty")
	await _until(func() -> bool: return not truck.moving, 4, "empty collector finishes ordinary movement away from its last delivery bay")
	await physics_frame
	_check(harvest.collection_wait_position_clear(truck, truck.global_position), "exhausted collector waits clear of all production and delivery access")
	await _frames(180)
	_check(harvest.credits.balance(1) == 70 and ledger["events"].size() == 6 and work.state == CollectorHarvest.State.WAITING, "empty-area retries do not replay deposits or replenish cache resources")


func _automatic_reachability() -> void:
	var route := await _fresh_route()
	var truck := route.collectors[0]
	var first := route.caches[0]
	var second := route.caches[1]
	truck.position = Vector3(-13, 0, -16)
	await _frames(3)
	await physics_frame
	var choice := route.choose_collection_cache(truck, first.global_position, 24.0)
	_check(choice.get("cache") == first and not route.plan_access(truck, first).is_empty(), "initial local assignment chooses an actually reachable nearby source")
	# Collision-only occlusion leaves navigation projection valid, so a geometric
	# nearest-source scan would incorrectly choose the covered cache.
	var blocker := StaticBody3D.new()
	blocker.collision_layer = 4 | LineOfFire.BLOCKER_MASK
	blocker.position = first.position + Vector3.UP
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(10, 3, 9)
	collider.shape = shape
	blocker.add_child(collider)
	route.add_child(blocker)
	await _frames(3)
	await physics_frame
	_check(route.plan_access(truck, first).is_empty() and route.choose_collection_cache(truck, first.position, 24.0).get("cache") == second, "a blocked closest cache is skipped for another reachable local source")
	_check(route.choose_collection_cache(truck, first.position, 5.0).is_empty(), "blocked local access cannot expand a configured five-unit collection area")
	blocker.queue_free()
	route.obstacles[2] = Rect2(-1, -24, 2, 48)
	route._box(Vector3(2, 2, 48), Vector3(0, 1, 0), Color("8b7866"), 4 | LineOfFire.BLOCKER_MASK)
	route.navigation_region.navigation_mesh = route.create_navigation_mesh(route.obstacles)
	first.take_silent(first.remaining)
	first.refresh_presentation()
	await _frames(8)
	await physics_frame
	_check(route.access_positions(second).any(func(access: Dictionary) -> bool: return route._nav_point(access["point"])) and route.plan_access(truck, second).is_empty(), "disconnected cache has projected access points but no complete route")
	_check(route.choose_collection_cache(truck, first.position, 24.0).is_empty(), "automatic source selection rejects the disconnected cache despite local distance")
	# Fresh connected geometry isolates a fixed anchor from the truck's current
	# position, which can be far away after an owned drop-off return.
	await _fresh_harvest(100, 0)
	truck = _select_collector()
	truck.collection_radius = 5.0
	first = harvest.caches[0]
	second = harvest.caches[1]
	truck.position = Vector3(11, 0, -17)
	first.take_silent(first.remaining)
	first.refresh_presentation()
	await _frames(4)
	await physics_frame
	_check(not harvest.plan_access(truck, second).is_empty() and harvest.choose_collection_cache(truck, first.position, truck.collection_radius).is_empty(), "truck proximity after travel does not expand the original collection area to a distant cache")
	_check(truck.harvesting.start_local_collection(first.position) and truck.harvesting.state == CollectorHarvest.State.WAITING, "empty fixed collection area waits even with a reachable source near the truck")
	_check(_complete(harvest.issue_harvest(second)) and truck.harvesting.cache_node() == second and truck.harvesting.collection_origin == second.position, "deliberate harvesting order selects a distant source and establishes its new local area")


func _automatic_waiting() -> void:
	await _fresh_depot(2000, 0)
	var depot := await _depot()
	if depot == null: return
	var producer := depot.production
	var trucks: Array[CollectorTruck] = []
	var starts_clear := {"value": true}
	producer.deployed.connect(func(_job: int, _identity: int, _rally: bool) -> void:
		var truck := _last_unit(producer) as CollectorTruck
		trucks.append(truck)
		var observed := {"started": false}
		truck.harvesting.changed.connect(func() -> void:
			if truck.harvesting.automatic and not observed["started"]:
				observed["started"] = true
				starts_clear["value"] = starts_clear["value"] and battle.collection_wait_position_clear(truck, truck.global_position)
		)
	)
	for index in 5: _check(producer.enqueue(1, COLLECTOR_RECIPE).accepted, "empty local supplies do not prevent an affordable truck production job")
	if not await _until(func() -> bool: return trucks.size() == 5 and trucks.all(func(truck: CollectorTruck) -> bool: return truck.harvesting.state == CollectorHarvest.State.WAITING and not truck.moving), 36, "a full queue of five normally produced trucks clears the exit and waits when all supplies are empty"): return
	_check(producer.count() == 0 and starts_clear["value"] and battle.credits.balance(1) == 700 and battle._access_claims.is_empty(), "waiting trucks leave production unblocked, preserve captured costs and hold no delivery bays")
	var clear := true
	for truck in trucks:
		clear = clear and truck.harvesting.reason == "No nearby supplies" and truck.harvesting.collection_origin == depot.global_position
		await physics_frame
		clear = clear and battle.collection_wait_position_clear(truck, truck.global_position)
	_check(clear, "each waiting truck displays No nearby supplies and parks clear of access with the depot as its fixed anchor")
	_check((battle as EconomyAssaultField).enemy_cache.remaining == 2000 and (battle as EconomyAssaultField).enemy_cache.global_position.distance_to(depot.global_position) > trucks[0].collection_radius, "default local collection leaves the nonempty distant enemy-side cache untouched")
	battle.selection.select_clicked(trucks[0], false)
	await _frames(3)
	_check(battle.harvest_panel.label.text.contains("No nearby supplies"), "selected waiting truck exposes its actionable shortage status in the existing harvest panel")
	await _automatic_capture("no-nearby-supplies")
	await _hud_key(KEY_X)
	var stopped_generation := trucks[0].harvesting.generation
	# A focused 25-cargo fixture exercises delivery while the five trucks wait;
	# it is never counted as earned-resource coverage.
	var delivery := battle.collectors[0]
	delivery.harvesting.cargo = 25
	battle.selection.select_clicked(delivery, false)
	_check(_complete(battle.issue_deposit(depot)), "owned depot still accepts delivery while automatic collectors wait nearby")
	await _until(func() -> bool: return delivery.harvesting.cargo == 0 and battle.credits.balance(1) == 725, 12, "delivery reaches the owned depot and credits the existing wallet despite empty caches")
	# Reintroduce the same source through the supported cache registry, with a
	# focused 25-supply fixture solely for retry behavior rather than earned income.
	var cache := _depot_player_cache()
	battle.remove_child(cache)
	cache.remaining = 25
	cache.refresh_presentation()
	battle.add_child(cache)
	if not await _until(func() -> bool: return trucks.any(func(truck: CollectorTruck) -> bool: return truck.harvesting.cache_node() == cache), 4, "bounded retry notices a newly available local source without a player harvest command"): return
	_check(trucks.all(func(truck: CollectorTruck) -> bool: return truck.harvesting.collection_origin == depot.global_position), "retry preserves every truck's original depot collection area")
	await _frames(180)
	_check(trucks[0].harvesting.state == CollectorHarvest.State.IDLE and not trucks[0].harvesting.automatic and trucks[0].harvesting.generation == stopped_generation and trucks[0].harvesting.cargo == 0, "X Stop during No nearby supplies prevents restart when a local source becomes available")


func _automatic_commands() -> void:
	for action in ["stop", "move", "harvest"]:
		await _fresh_depot(2000)
		var depot := await _depot()
		if depot == null: return
		var producer := depot.production
		var commanded: Array[CollectorTruck] = []
		var expected := {"generation": -1, "order": -1, "accepted": false}
		_check(producer.set_rally(1, Vector3(-5, 0, 3)).accepted, "command-race fixture accepts an ordinary depot rally")
		producer.deployed.connect(func(_job: int, _identity: int, _rally: bool) -> void:
			var truck := _last_unit(producer) as CollectorTruck
			commanded.append(truck)
			battle.selection.select_clicked(truck, false)
			match action:
				"stop": expected["accepted"] = _complete(battle.issue_stop())
				"move": expected["accepted"] = _complete(battle.issue_move(Vector3(-17, 0, 2)))
				"harvest": expected["accepted"] = _complete(battle.issue_harvest(_depot_player_cache(1)))
			expected["generation"] = truck.harvesting.generation
			expected["order"] = truck.order_version
		)
		_check(producer.enqueue(1, COLLECTOR_RECIPE).accepted, "command-race fixture buys a real six-second collector")
		if not await _until(func() -> bool: return commanded.size() == 1, 7, "deployment notification accepts newer player %s" % action): return
		var truck := commanded[0]
		await _frames(3)
		_check(expected["accepted"] and not truck.deployment_collection_pending() and truck.harvesting.generation == expected["generation"], "newer %s generation cancels the deferred new-truck assignment" % action)
		if action == "harvest":
			_check(truck.harvesting.cache_node() == _depot_player_cache(1) and truck.harvesting.collection_origin == _depot_player_cache(1).global_position and not battle._access_claims.is_empty(), "explicit harvest retains its chosen cache, new local area and access claim after the canceled deployment callback")
			await _until(func() -> bool: return truck.harvesting.cargo > 0, 20, "explicit harvesting command still reaches and collects from its chosen source")
		else:
			await _frames(600)
			_check(truck.harvesting.state == CollectorHarvest.State.IDLE and not truck.harvesting.automatic and truck.harvesting.generation == expected["generation"] and truck.order_version == expected["order"] and truck.harvesting.cargo == 0, "newer %s stays authoritative beyond several automatic retry intervals" % action)
			if action == "move": _check(truck.position.distance_to(Vector3(-17, 0, 2)) <= truck.stopping_distance, "newer Move actually reaches its destination through the existing mover")
	# X Stop also overrides automation after the production handoff has completed.
	await _fresh_depot(2000)
	var depot := await _depot()
	if depot == null: return
	_check(depot.production.enqueue(1, COLLECTOR_RECIPE).accepted, "post-handoff X fixture produces an ordinary truck")
	if not await _until(func() -> bool: return not depot.production.last_deployment.is_empty(), 7, "post-handoff fixture completes actual production"): return
	var truck := _last_unit(depot.production) as CollectorTruck
	if not await _until(func() -> bool: return truck.harvesting.cargo == 25, 15, "produced truck automatically clears the exit and gathers real cargo without a rally"): return
	battle.selection.select_clicked(truck, false)
	await _hud_key(KEY_X)
	var generation := truck.harvesting.generation
	await _frames(240)
	_check(truck.harvesting.state == CollectorHarvest.State.IDLE and not truck.harvesting.automatic and truck.harvesting.cargo == 25 and truck.harvesting.generation == generation and not truck.moving, "viewport X Stop preserves cargo and does not restart automatic gathering")


func _automatic_capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://validation-output/automatic-harvesting")
	var picture := root.get_texture().get_image()
	_check(picture.save_png("res://validation-output/automatic-harvesting/%s.png" % label) == OK and picture.get_size() == root.size, "saved actual automatic harvesting viewport " + label)
