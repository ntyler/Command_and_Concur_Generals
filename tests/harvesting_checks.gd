extends "res://tests/combat_repair_checks.gd"
## Real fixed-step trips with bounded simulation waits, native-error probe, and
## the inherited 180s process watchdog. Run through the external 240s wrapper.

var harvest: HarvestField


func _run() -> void:
	root.size = Vector2i(1280, 800)
	var logger := EngineErrorProbe.new()
	OS.add_logger(logger)
	var chosen := "all"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--harvest-case="):
			chosen = argument.trim_prefix("--harvest-case=")
	var cases := ["loop", "quantities", "commands", "callbacks", "lifecycle", "blocked", "ui", "earned"]
	_check(chosen == "all" or cases.has(chosen), "recognized harvesting case")
	for case in cases:
		if chosen != "all" and chosen != case:
			continue
		var before := checks
		var failed := failures
		match case:
			"loop": await _loop_checks()
			"quantities": await _quantity_checks()
			"commands": await _harvest_command_checks()
			"callbacks": await _transfer_callback_checks()
			"lifecycle": await _harvest_lifecycle_checks()
			"blocked": await _blocked_harvest_checks()
			"ui": await _harvest_ui_checks()
			"earned": await _earned_production_checks()
		print("HARVEST_CASE: %s; checks=%d failures=%d" % [case, checks - before, failures - failed])
	if is_instance_valid(harvest):
		harvest.queue_free()
	await _frames(4)
	_check(root.get_children().is_empty(), "harvesting teardown leaves no fields, detached objects or controls")
	OS.remove_logger(logger)
	_check(logger.error_count() == 0, "no native errors or warnings through harvesting callbacks and teardown")
	print("HARVESTING_CHECKS: %d checks, %d failures; native_errors=%d" % [checks, failures, logger.error_count()])
	quit(0 if failures == 0 else 1)


func _fresh_harvest(supplies: int = 2000, starting: int = 1000) -> void:
	if is_instance_valid(harvest):
		harvest.queue_free()
		await _frames(3)
	harvest = load("res://scenes/harvesting_test.tscn").instantiate() as HarvestField
	harvest.cache_supplies = supplies
	harvest.starting_credits = starting
	field = harvest
	root.add_child(harvest)
	current_scene = harvest
	harvest.camera_rig.edge_scrolling_enabled = false
	# Successive fields share the viewport's World3D navigation map. A nonzero
	# map iteration may still describe the departed region; wait for this field's
	# region to own both collector starts before issuing navigation-dependent work.
	for tick in 60:
		await _frames(1)
		if _current_harvest_navigation():
			break
	_check(harvest.credits.balance(1) == starting and harvest.caches[0].remaining == supplies and harvest.collectors[0].harvesting.cargo == 0, "fresh configuration resets wallet, cache and cargo")
	_check(harvest._access_claims.is_empty() and _current_harvest_navigation(), "fresh synchronized navigation belongs to current field and has no stale access claims")


func _current_harvest_navigation() -> bool:
	var map := harvest.get_world_3d().get_navigation_map()
	if NavigationServer3D.map_get_iteration_id(map) == 0:
		return false
	for unit in harvest.collectors:
		if NavigationServer3D.map_get_closest_point_owner(map, unit.global_position) != harvest.navigation_region.get_rid():
			return false
	return true


func _until(predicate: Callable, seconds: float, description: String) -> bool:
	for tick in ceili(seconds * 60.0):
		if predicate.call():
			_check(true, description)
			return true
		await _frames(1)
	var satisfied: bool = predicate.call()
	_check(satisfied, description + " (bounded simulation deadline)")
	return satisfied


func _select_collector(index: int = 0) -> CollectorTruck:
	var unit := harvest.collectors[index]
	harvest.selection.select_clicked(unit, false)
	return unit


func _loaded() -> CollectorTruck:
	await _fresh_harvest(200)
	var unit := _select_collector()
	_check(_complete(harvest.issue_harvest(harvest.caches[0])), "cargo fixture accepts ordinary harvest command")
	await _until(func() -> bool: return unit.harvesting.cargo == 25, 10, "cargo fixture actually navigates and loads 25")
	unit.stop()
	return unit


func _loop_checks() -> void:
	await _fresh_harvest()
	_check(harvest.collectors.size() == 2 and harvest.caches.size() == 2 and harvest.units.size() == 8, "playable scene has two collectors/two caches plus six existing combat units")
	var truck := harvest.collectors[0]
	_check(truck.cargo_capacity == 100 and truck.loading_amount == 25 and truck.loading_interval == 1.0 and truck.unloading_duration == 1.0, "collector quantity and simulation-time defaults")
	_check(truck.maximum_health == 150 and truck.combat.health.current == 150 and truck.combat.weapon == null and truck.movement_speed == 4.0, "unarmed collector reuses configurable health with collector-only speed")
	_check(harvest.starting_credits == 1000 and harvest.barracks.recipe.credit_cost == 100 and harvest.barracks.recipe.training_duration == 5.0 and harvest.barracks.queue_capacity == 5, "existing economy and production defaults preserved")
	_check(harvest.caches[0].remaining == 2000 and harvest.caches[1].remaining == 2000 and not harvest.movement_debug, "finite cache defaults and diagnostics off")
	_check(not TeamRules.can_attack(harvest, truck, harvest.units[3]) and TeamRules.can_attack(harvest, harvest.units[3], truck), "unarmed collectors are valid hostile targets but cannot attack")
	var hostile := harvest.units[3]
	# Isolated combat positioning on open navigable ground; ordinary firing/damage.
	truck.global_position = Vector3(-18, 0, 18)
	hostile.global_position = Vector3(-12, 0, 18)
	truck.halt_motion()
	hostile.halt_motion()
	await _frames(3)
	_check(hostile.combat.issue_attack(truck), "existing enemy Rifle accepts a collector target")
	await _until(func() -> bool: return truck.combat.health.current < 150, 3, "enemy Rifle deals actual weapon damage to unarmed collector")
	_check(truck.combat.target_unit() == null and truck.combat.weapon == null and not truck.retaliation_enabled and not truck.moving, "damaged collector does not fire or retaliate")
	hostile.stop()
	await _fresh_harvest(125, 0)
	truck = _select_collector()
	var work := truck.harvesting
	var cache := harvest.caches[0]
	var footprint_id := cache.get_rid()
	var transfers: Array[Dictionary] = []
	work.transferred.connect(func(result: HarvestTransfer) -> void:
		transfers.append({"kind": result.kind, "amount": result.amount, "tick": Engine.get_physics_frames(), "state": work.state, "stopped": not truck.moving, "cache": cache.remaining, "cargo": work.cargo, "credits": harvest.credits.balance(1), "target": result.target_id})
	)
	_check(_complete(harvest.issue_harvest(cache)), "real automatic command accepted")
	_check(truck.moving and work.state == CollectorHarvest.State.TO_SUPPLIES, "accepted work submits the existing mover")
	await _frames(30)
	_check(work.cargo == 0 and cache.remaining == 125 and harvest.credits.balance(1) == 0, "travel cannot load supplies or grant early credit")
	if not await _until(func() -> bool: return work.state == CollectorHarvest.State.LOADING, 10, "collector reaches and stops at supplies"):
		return
	var arrived_tick := Engine.get_physics_frames()
	await _frames(58)
	_check(work.cargo == 0 and cache.remaining == 125, "loading does not commit during first 58 of 60 interval ticks")
	if not await _until(func() -> bool: return work.state == CollectorHarvest.State.UNLOADING, 15, "full collector navigates back to HQ"):
		return
	var unload_tick := Engine.get_physics_frames()
	_check(work.cargo == 100 and cache.remaining == 25 and harvest.credits.balance(1) == 0, "full cargo leaves supply but remains unspendable before unloading")
	await _frames(58)
	_check(work.cargo == 100 and harvest.credits.balance(1) == 0, "unloading cannot credit before its full duration")
	await _until(func() -> bool: return work.state == CollectorHarvest.State.IDLE and harvest.credits.balance(1) == 125, 22, "second trip deposits partial final load then becomes idle")
	_check(transfers.size() == 7, "exactly five load intervals and two deposits")
	var loads: Array[Dictionary] = []
	var deposits: Array[Dictionary] = []
	for event in transfers:
		if event["kind"] == HarvestTransfer.Kind.LOAD:
			loads.append(event)
		else:
			deposits.append(event)
	_check(loads.size() == 5 and loads[0]["tick"] - arrived_tick >= 59 and loads[0]["tick"] - arrived_tick <= 61, "first loading transfer occurs at the 60-tick boundary")
	_check(deposits.size() == 2 and deposits[0]["tick"] - unload_tick >= 59 and deposits[0]["tick"] - unload_tick <= 61 and deposits[0]["amount"] == 100 and deposits[1]["amount"] == 25, "unload boundary and historical full/partial amounts are exact")
	var coherent := true
	for event in loads:
		coherent = coherent and event["amount"] == 25 and event["stopped"] and event["state"] == CollectorHarvest.State.LOADING and event["target"] == cache.cache_id
	_check(coherent, "all loads are stopped, bounded transfers from the same assigned cache")
	for i in range(1, 4):
		_check(loads[i]["tick"] - loads[i - 1]["tick"] == 60, "successive loading intervals each require 60 simulated ticks")
	_check(cache.remaining == 0 and cache.depleted and not cache._goods.visible and cache.get_rid() == footprint_id and cache.collision_layer != 0, "depletion changes presentation while retaining collision footprint")
	_check(work.cargo == 0 and harvest.caches[1].remaining == 125 and harvest._access_claims.is_empty(), "depletion releases claims and never searches another cache")
	await _frames(120)
	_check(harvest.credits.balance(1) == 125 and work.state == CollectorHarvest.State.IDLE, "empty collector remains idle with no repeated deposit")


func _quantity_checks() -> void:
	await _fresh_harvest(225, 0)
	var first := _select_collector()
	var second := harvest.collectors[1]
	harvest.selection.select_clicked(second, true)
	var ledger := {"loaded": 0, "deposited": 0, "partial": 0, "coherent": true}
	for unit in harvest.collectors:
		unit.harvesting.transferred.connect(func(result: HarvestTransfer) -> void:
			if result.kind == HarvestTransfer.Kind.LOAD:
				ledger["loaded"] += result.amount
				if result.amount < 25: ledger["partial"] += 1
			else:
				ledger["deposited"] += result.amount
			ledger["coherent"] = ledger["coherent"] and harvest.caches[0].remaining + first.harvesting.cargo + second.harvesting.cargo + ledger["deposited"] == 225
		)
	var batch := harvest.issue_harvest(harvest.caches[0])
	_expect_batch(batch, [7, 8], [7, 8], CommandBatchResult.Acceptance.COMPLETE)
	_check(first.assigned_destination.distance_to(second.assigned_destination) >= 1.9, "concurrent collectors claim separated access positions")
	var bounded := true
	var separate := false
	for tick in 2400:
		await _frames(1)
		bounded = bounded and first.harvesting.cargo >= 0 and first.harvesting.cargo <= 100 and second.harvesting.cargo >= 0 and second.harvesting.cargo <= 100 and harvest.caches[0].remaining >= 0 and harvest.credits.balance(1) >= 0
		separate = separate or first.harvesting.cargo != second.harvesting.cargo
		if first.harvesting.state == CollectorHarvest.State.IDLE and second.harvesting.state == CollectorHarvest.State.IDLE: break
	_check(bounded and separate, "cargo is bounded, nonnegative and independent per collector")
	_check(ledger["loaded"] == 225 and ledger["deposited"] == 225 and harvest.credits.balance(1) == 225 and ledger["coherent"], "two collectors conserve every supply across loading and deposits")
	_check(first.harvesting.state == CollectorHarvest.State.IDLE and second.harvesting.state == CollectorHarvest.State.IDLE and harvest._access_claims.is_empty(), "both collectors terminate the finite loop and release claims")
	# A non-multiple exercises a contested partial final interval, not just partial cargo.
	await _fresh_harvest(30, 0)
	first = _select_collector()
	second = harvest.collectors[1]
	harvest.selection.select_clicked(second, true)
	var amounts: Array[int] = []
	for unit in harvest.collectors:
		unit.harvesting.transferred.connect(func(result: HarvestTransfer) -> void:
			if result.kind == HarvestTransfer.Kind.LOAD: amounts.append(result.amount)
		)
	_check(_complete(harvest.issue_harvest(harvest.caches[0])), "contested 30-supply cache accepts two recipients")
	await _until(func() -> bool: return harvest.credits.balance(1) == 30 and first.harvesting.state == CollectorHarvest.State.IDLE and second.harvesting.state == CollectorHarvest.State.IDLE, 22, "contested partial remainder deposits once")
	amounts.sort()
	_check(amounts == [5, 25] and harvest.caches[0].remaining == 0, "only one collector receives the final five supplies")
	await _fresh_harvest(52, 0)
	first = _select_collector()
	first.cargo_capacity = 35
	var bounded_loads: Array[int] = []
	first.harvesting.transferred.connect(func(result: HarvestTransfer) -> void:
		if result.kind == HarvestTransfer.Kind.LOAD: bounded_loads.append(result.amount)
	)
	var capacity_order := harvest.issue_harvest(harvest.caches[0])
	if not _complete(capacity_order):
		print("HARVEST_CAPACITY_REJECTION: intended=%s accepted=%s superseded=%s reason=%s current_region_ready=%s selected=%s" % [capacity_order.intended_ids, capacity_order.accepted_ids, capacity_order.superseded, first.harvesting.last_rejection, _current_harvest_navigation(), harvest.selection.selected_units() == [first]])
	_check(_complete(capacity_order), "non-multiple capacity configuration accepts harvesting")
	await _until(func() -> bool: return harvest.credits.balance(1) == 52 and first.harvesting.state == CollectorHarvest.State.IDLE, 30, "configured capacity makes two real collection trips")
	_check(bounded_loads == [25, 10, 17] and first.harvesting.cargo == 0, "transfers clamp independently to interval amount, remaining capacity and final cache contents")


func _harvest_command_checks() -> void:
	var truck := await _loaded()
	var work := truck.harvesting
	_check(work.cargo == 25 and work.state == CollectorHarvest.State.IDLE and not work.automatic and harvest._access_claims.is_empty(), "Stop immediately cancels work and claims, retaining cargo")
	await _frames(90)
	_check(work.cargo == 25 and harvest.credits.balance(1) == 1000, "obsolete loading timer cannot run after Stop")
	_check(_complete(harvest.issue_harvest(harvest.caches[1])) and work.cargo == 25 and work.cache_node() == harvest.caches[1], "new harvest assignment preserves loaded cargo")
	var generation := work.generation
	var destination := truck.assigned_destination
	_check(not harvest.issue_harvest(null).has_acceptance() and work.generation == generation and truck.assigned_destination == destination, "null harvest rejection preserves the active order")
	harvest.headquarters.owner_id = 2
	_check(not harvest.issue_harvest(harvest.caches[0]).has_acceptance() and work.generation == generation, "no owned drop-off rejects a replacement without overwriting valid history")
	_check(not harvest.issue_deposit(harvest.headquarters).has_acceptance() and work.cargo == 25, "enemy headquarters cannot accept manual cargo")
	harvest.headquarters.owner_id = 1
	var rifle := harvest.units[0]
	rifle.move_to(Vector3(-10, 0, 16))
	var rifle_order := rifle.order_version
	harvest.selection.select_clicked(rifle, true)
	var mixed := harvest.issue_harvest(harvest.caches[0])
	_expect_batch(mixed, [7, 1], [7], CommandBatchResult.Acceptance.PARTIAL)
	_check(rifle.order_version == rifle_order and rifle.moving, "ineligible combat unit keeps its previous movement order")
	harvest.selection.select_clicked(truck, false)
	_check(_complete(harvest.issue_move(Vector3(-14, 0, -1))), "normal ground Move is accepted with cargo")
	_check(work.state == CollectorHarvest.State.IDLE and work.cargo == 25 and not work.automatic and work.cache_node() == null and harvest._access_claims.is_empty(), "Move clears obsolete assignment and timers without discarding cargo")
	await _frames(180)
	_check(work.cargo == 25 and harvest.credits.balance(1) == 1000, "Move never silently resumes harvesting")
	_check(_complete(harvest.issue_deposit(harvest.headquarters)), "manual HQ return accepts existing cargo")
	await _until(func() -> bool: return work.state == CollectorHarvest.State.IDLE and harvest.credits.balance(1) == 1025, 15, "manual return navigates, unloads and idles")
	await _frames(120)
	_check(work.cargo == 0 and work.cache_node() == null and harvest.credits.balance(1) == 1025, "manual return deposits only once")
	_check(not harvest.issue_deposit(harvest.headquarters).has_acceptance(), "empty collector cannot accept deposit command")
	await _fresh_harvest(400)
	truck = _select_collector()
	work = truck.harvesting
	harvest.issue_harvest(harvest.caches[0])
	await _until(func() -> bool: return work.cargo == 100, 12, "full-replacement fixture loads a real full cargo")
	truck.stop()
	_check(_complete(harvest.issue_harvest(harvest.caches[1])) and work.cargo == 100 and work.state == CollectorHarvest.State.RETURNING and work.cache_node() == harvest.caches[1], "full collector deposits first on a new cache assignment")
	await _until(func() -> bool: return harvest.credits.balance(1) == 1100 and work.state == CollectorHarvest.State.TO_SUPPLIES, 12, "deposit continues toward the newly assigned cache")
	_check(work.cache_node() == harvest.caches[1] and harvest.caches[1].remaining == 400, "new assignment receives no premature withdrawal")
	truck.stop()
	# A synchronous accepted Stop supersedes the rest of the outer mixed batch.
	harvest.selection.select_clicked(harvest.collectors[1], true)
	var replaced := {"once": false}
	var replace := func() -> void:
		if not replaced["once"]:
			replaced["once"] = true
			harvest.issue_stop()
	work.changed.connect(replace)
	var outer := harvest.issue_harvest(harvest.caches[0])
	work.changed.disconnect(replace)
	_expect_batch(outer, [7, 8], [7], CommandBatchResult.Acceptance.PARTIAL, true)
	_check(not truck.moving and not harvest.collectors[1].moving and work.state == CollectorHarvest.State.IDLE and harvest.last_command_result.generation > outer.generation, "nested Stop remains authoritative over old dispatch")
	var reject_nested := func() -> void: harvest.issue_harvest(null)
	work.changed.connect(reject_nested)
	var accepted := harvest.issue_harvest(harvest.caches[0])
	work.changed.disconnect(reject_nested)
	_expect_batch(accepted, [7, 8], [7, 8], CommandBatchResult.Acceptance.COMPLETE)
	_check(harvest.last_command_result == accepted, "rejected nested request cannot steal batch authority")
	harvest.issue_stop()
	harvest.selection.select_clicked(null, false)
	_expect_batch(harvest.issue_harvest(harvest.caches[0]), [], [], CommandBatchResult.Acceptance.NONE)


func _transfer_callback_checks() -> void:
	# All destructive callbacks run after real navigation/timing, not manually
	# fabricated cargo, arrival flags, or production-like algorithm duplicates.
	for action in ["repeat", "stop", "move", "replace", "detach", "free_collector", "free_cache", "free_hq"]:
		await _fresh_harvest(100, 0)
		var truck := _select_collector()
		var work := truck.harvesting
		var cache := harvest.caches[0]
		var hq := harvest.headquarters
		var seen := {"called": false, "coherent": false, "repeated": false, "amount": 0, "generation": 0}
		var on_load := func() -> void:
			if seen["called"]: return
			seen["called"] = true
			seen["coherent"] = cache.remaining == 75 and work.cargo == 25
			seen["amount"] = work.last_transfer.amount
			seen["repeated"] = not work.complete_loading().committed() and not work.complete_deposit().committed()
			match action:
				"stop": truck.stop()
				"move": harvest.issue_move(Vector3(-14, 0, -1))
				"replace": harvest.issue_harvest(harvest.caches[1])
				"detach": harvest.remove_child(truck)
				"free_collector": truck.free()
				"free_cache": cache.free()
				"free_hq": hq.free()
			seen["generation"] = work.generation
		cache.changed.connect(on_load)
		_check(_complete(harvest.issue_harvest(cache)), "callback fixture accepts harvest: " + action)
		await _until(func() -> bool: return seen["called"], 10, "real loading invokes callback: " + action)
		_check(seen["coherent"] and seen["repeated"] and seen["amount"] == 25, "load sides commit coherently and repeat completion is inert: " + action)
		await _frames(2)
		match action:
			"repeat":
				await physics_frame
				_check(not work.complete_loading().committed() and work.cargo == 25 and cache.remaining == 75, "repeated completion outside notification still cannot reuse an interval")
			"stop", "move":
				_check(work.state == CollectorHarvest.State.IDLE and work.cargo == 25 and work.generation == seen["generation"], "callback interruption has no stale harvest writes: " + action)
			"replace":
				_check(work.cache_node() == harvest.caches[1] and work.cargo == 25 and work.generation == seen["generation"], "callback replacement survives the obsolete loading continuation")
			"detach":
				_check(work.state == CollectorHarvest.State.IDLE and work.cargo == 25 and harvest._access_claims.is_empty(), "detached callback retains cargo and releases access")
				harvest.add_child(truck)
				_check(harvest.contains_unit(truck) and work.state == CollectorHarvest.State.IDLE, "re-entry restores membership without obsolete automation")
			"free_collector":
				_check(not is_instance_valid(truck) and work.last_transfer.amount == 25 and harvest.credits.balance(1) == 0 and harvest._access_claims.is_empty(), "immediate free leaves a historical load result without credit or reservation")
			"free_cache":
				_check(work.cargo == 25 and work.state == CollectorHarvest.State.RETURNING, "source freed in load callback returns committed cargo")
				await _until(func() -> bool: return harvest.credits.balance(1) == 25 and work.state == CollectorHarvest.State.IDLE, 12, "departed-source partial cargo deposits exactly once")
			"free_hq":
				_check(work.state == CollectorHarvest.State.BLOCKED and work.cargo == 25 and harvest.credits.balance(1) == 0, "HQ freed in load callback blocks without losing cargo")
		if is_instance_valid(cache) and cache.changed.is_connected(on_load): cache.changed.disconnect(on_load)
	for action in ["buy", "stop", "move", "replace", "detach", "free_collector", "free_cache", "free_hq", "free_field"]:
		await _fresh_harvest(100, 0)
		var truck := _select_collector()
		var work := truck.harvesting
		var wallet := harvest.credits
		var seen := {"called": false, "coherent": false, "repeat": false, "purchased": false, "generation": 0}
		var on_credit := func(_owner: int) -> void:
			if seen["called"]: return
			seen["called"] = true
			seen["coherent"] = wallet.balance(1) == 100 and work.cargo == 0 and work.last_transfer.amount == 100
			seen["repeat"] = not work.complete_deposit().committed()
			match action:
				"buy": seen["purchased"] = harvest.barracks.production.enqueue(1, harvest.barracks.recipe).accepted
				"stop": truck.stop()
				"move": harvest.issue_move(Vector3(-14, 0, -1))
				"replace": harvest.issue_harvest(harvest.caches[1])
				"detach": harvest.remove_child(truck)
				"free_collector": truck.free()
				"free_cache": harvest.caches[0].free()
				"free_hq": harvest.headquarters.free()
				"free_field": harvest.free()
			seen["generation"] = work.generation
		wallet.changed.connect(on_credit)
		_check(_complete(harvest.issue_harvest(harvest.caches[0])), "deposit callback fixture accepts harvest: " + action)
		await _until(func() -> bool: return seen["called"], 22, "real unloading invokes credit callback: " + action)
		_check(seen["coherent"] and seen["repeat"] and work.last_transfer.amount == 100 and work.last_transfer.kind == HarvestTransfer.Kind.DEPOSIT, "deposit clears cargo before notifications and reports committed amount: " + action)
		await _frames(2)
		_check(wallet.balance(1) == (0 if action == "buy" else 100), "nested notifications cannot mint a second deposit: " + action)
		match action:
			"buy": _check(seen["purchased"] and harvest.barracks.production.count() == 1 and work.last_transfer.amount == 100, "notification buys a normal Rifle; historical deposit remains 100 despite zero wallet")
			"stop", "move": _check(work.state == CollectorHarvest.State.IDLE and work.generation == seen["generation"], "deposit interruption stays authoritative: " + action)
			"replace": _check(work.cache_node() == harvest.caches[1] and work.state == CollectorHarvest.State.TO_SUPPLIES and work.generation == seen["generation"], "deposit callback's new cache remains authoritative")
			"detach":
				_check(work.state == CollectorHarvest.State.IDLE and work.cargo == 0 and harvest._access_claims.is_empty(), "deposit callback detachment leaves no obsolete work")
				harvest.add_child(truck)
			"free_collector": _check(not is_instance_valid(truck) and harvest._access_claims.is_empty(), "collector free during deposit clears its reservation")
			"free_cache", "free_hq": _check(work.state == CollectorHarvest.State.IDLE or work.state == CollectorHarvest.State.BLOCKED, "removed destination prevents old deposit continuation: " + action)
			"free_field": _check(not is_instance_valid(harvest) and not wallet.active, "scene free during wallet notification safely deactivates the same wallet")
		wallet.changed.disconnect(on_credit)


func _harvest_lifecycle_checks() -> void:
	var truck := await _loaded()
	var work := truck.harvesting
	_check(_complete(harvest.issue_deposit(harvest.headquarters)), "ownership fixture accepts owned HQ")
	harvest.headquarters.owner_id = 2
	await _frames(2)
	_check(work.state == CollectorHarvest.State.BLOCKED and work.cargo == 25 and not truck.moving and harvest.credits.balance(1) == 1000 and harvest.credits.balance(2) == 1000, "ownership change blocks active return without crediting either owner")
	truck = await _loaded()
	work = truck.harvesting
	harvest.issue_harvest(harvest.caches[0])
	truck.owner_id = 2
	_check(work.state == CollectorHarvest.State.IDLE and work.cargo == 25 and not truck.moving and harvest._access_claims.is_empty(), "collector ownership change immediately cancels automation and preserves cargo")
	truck = await _loaded()
	work = truck.harvesting
	harvest.issue_harvest(harvest.caches[0])
	var container := Node3D.new()
	harvest.add_child(container)
	truck.reparent(container)
	_check(harvest.contains_unit(truck) and harvest.units.count(truck) == 1 and work.cargo == 25 and work.state == CollectorHarvest.State.IDLE, "same-field reparent restores exactly one membership with cargo and no stale order")
	harvest.selection.select_clicked(truck, false) # Departure prunes old selection.
	_check(_complete(harvest.issue_harvest(harvest.caches[0])), "reparented collector accepts a fresh harvest command")
	container.queue_free()
	_check(not work.can_order(harvest.caches[0], true), "queued ancestor makes collector ineligible before teardown")
	await _frames(3)
	_check(not is_instance_valid(truck) and harvest._access_claims.is_empty() and harvest.credits.balance(1) == 1000, "queued collector leaves no claims or awarded cargo")
	await _fresh_harvest(100, 0)
	truck = _select_collector()
	work = truck.harvesting
	harvest.issue_harvest(harvest.caches[0])
	var cache := harvest.caches[0]
	harvest.remove_child(cache)
	await _frames(2)
	_check(work.state == CollectorHarvest.State.IDLE and work.cargo == 0 and not truck.moving and not harvest.contains_cache(cache), "empty collector cancels when its source departs")
	harvest.add_child(cache)
	_check(harvest.contains_cache(cache) and cache.remaining == 100 and work.state == CollectorHarvest.State.IDLE, "cache re-entry restores membership without restarting old work")
	cache.queue_free()
	_check(not harvest.issue_harvest(cache).has_acceptance(), "queued cache cannot accept a new command")
	await _frames(3)
	truck = await _loaded()
	work = truck.harvesting
	harvest.issue_deposit(harvest.headquarters)
	var hq := harvest.headquarters
	harvest.remove_child(hq)
	await _frames(2)
	_check(work.cargo == 25 and work.state == CollectorHarvest.State.BLOCKED and harvest._access_claims.is_empty() and harvest.credits.balance(1) == 1000, "detached headquarters cannot receive a remote deposit")
	_check(not work.can_order(hq, false), "detached HQ rejects manual deposit")
	hq.free()
	# One explicit test ledger combines deposited, detached and destroyed cargo,
	# then normal production spending/refund. No permanent gameplay ledger exists.
	await _fresh_harvest(125)
	truck = _select_collector()
	work = truck.harvesting
	var ledger := {"deposited": 0, "destroyed": 0, "spent": 0, "refunded": 0}
	work.transferred.connect(func(result: HarvestTransfer) -> void:
		if result.kind == HarvestTransfer.Kind.DEPOSIT: ledger["deposited"] += result.amount
	)
	harvest.issue_harvest(harvest.caches[0])
	await _until(func() -> bool: return work.cargo == 25, 10, "conservation fixture loads first parcel")
	truck.stop()
	harvest.issue_deposit(harvest.headquarters)
	await _until(func() -> bool: return ledger["deposited"] == 25, 12, "conservation fixture really deposits its first parcel")
	harvest.issue_harvest(harvest.caches[0])
	await _until(func() -> bool: return work.cargo == 25, 12, "conservation fixture loads retained parcel")
	harvest.remove_child(truck)
	var second := _select_collector(1)
	harvest.issue_harvest(harvest.caches[0])
	await _until(func() -> bool: return second.harvesting.cargo == 25, 12, "conservation fixture loads parcel later lost on death")
	ledger["destroyed"] = second.harvesting.cargo
	var dead_work := second.harvesting
	var health := second.combat.health
	var death_events := {"count": 0}
	health.died.connect(func(_source: Node) -> void: death_events["count"] += 1)
	_check(TeamRules.damage_target(harvest, 2, second, 1000) == 150, "existing hostile damage kills the unarmed collector")
	_check(dead_work.cargo == 0 and death_events["count"] == 1 and not harvest.contains_unit(second), "death loses cargo and unregisters exactly once")
	await _frames(3)
	_check(not is_instance_valid(second) and harvest.credits.balance(1) == 1025, "death awards no cargo credits or refund")
	_check(250 == harvest.caches[0].remaining + harvest.caches[1].remaining + work.cargo + ledger["deposited"] + ledger["destroyed"], "supply conservation includes remaining, detached cargo, committed deposits and explicit death loss")
	var purchase := harvest.barracks.production.enqueue(1, harvest.barracks.recipe)
	if purchase.accepted: ledger["spent"] += 100
	var cancellation := harvest.barracks.production.cancel(1, purchase.job_id)
	if cancellation.accepted: ledger["refunded"] += 100
	_check(purchase.accepted and cancellation.accepted and harvest.credits.balance(1) == 1000 + ledger["deposited"] + ledger["refunded"] - ledger["spent"], "same-wallet conservation includes production payments and cancellation refunds")
	_check(harvest._access_claims.is_empty() and work.state == CollectorHarvest.State.IDLE, "dead and detached collectors leave no reservations")
	truck.free()
	await _fresh_harvest()
	_check(harvest.caches[0].remaining == 2000 and harvest.caches[1].remaining == 2000 and harvest.collectors[1].harvesting.cargo == 0 and harvest.barracks.production.count() == 0, "scene restart restores all configured inventories and empty production")


func _blocked_harvest_checks() -> void:
	var truck := await _loaded()
	var work := truck.harvesting
	_enclose(truck) # Physical-only failure fixture; leaves the real nav path intact.
	await _frames(3)
	_check(_complete(harvest.issue_deposit(harvest.headquarters)), "blocked trip accepts a valid navigation destination")
	var order := truck.order_version
	await _frames(180)
	_check(truck.order_version == order and truck.command_elapsed >= 2.9 and work.cargo == 25, "harvesting ticks never reconstruct trip orders or reset progress time")
	await _until(func() -> bool: return work.state == CollectorHarvest.State.BLOCKED, 92, "unreachable physical trip reaches a bounded safe state")
	_check(truck.movement_state == RTSUnit.MovementState.FAILED and truck.recovery_attempts <= truck.maximum_recoveries and truck.command_elapsed <= truck.command_timeout + 0.1 and truck.order_version == order, "existing movement failure budget and recovery history survive harvesting")
	_check(work.cargo == 25 and harvest.credits.balance(1) == 1000 and harvest._access_claims.is_empty() and not truck.moving, "failed access retains cargo, releases claims and cannot deposit remotely")
	await _frames(180)
	_check(work.state == CollectorHarvest.State.BLOCKED and work.cargo == 25, "blocked trip stays bounded until a player replacement")
	_check(_complete(harvest.issue_move(Vector3(-12, 0, -1))) and work.state == CollectorHarvest.State.IDLE, "failed collector still accepts new explicit movement")
	# A wall in the interaction segment denies loading after an otherwise real arrival.
	await _fresh_harvest(100, 0)
	truck = _select_collector()
	work = truck.harvesting
	harvest.issue_harvest(harvest.caches[0])
	await _until(func() -> bool: return work.state == CollectorHarvest.State.LOADING, 10, "wall fixture actually arrives before loading")
	var wall := StaticBody3D.new()
	wall.collision_layer = 4 | LineOfFire.BLOCKER_MASK
	wall.position = (truck.global_position + (work._access["dock"] as Vector3)) * 0.5 + Vector3.UP * 0.6
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.25, 1.2, 0.25)
	collider.shape = shape
	wall.add_child(collider)
	harvest.add_child(wall)
	await _frames(70)
	_check(work.state == CollectorHarvest.State.BLOCKED and work.cargo == 0 and harvest.caches[0].remaining == 100 and harvest.credits.balance(1) == 0, "commit rechecks physical interaction and cannot load through an intervening wall")


func _harvest_ui_checks() -> void:
	await _fresh_harvest(200)
	var truck := harvest.collectors[0]
	var work := truck.harvesting
	_check(not harvest.harvest_panel.visible, "cargo panel is hidden without selected collectors")
	await _click(_screen(truck), MOUSE_BUTTON_LEFT)
	_check(harvest.selection.selected_units() == [truck] and harvest.harvest_panel.visible, "viewport click selects collector and exposes contextual cargo")
	await _click(_world_screen(harvest.caches[0].global_position + Vector3.UP), MOUSE_BUTTON_RIGHT)
	_check(_complete(harvest.last_command_result) and work.state == CollectorHarvest.State.TO_SUPPLIES, "viewport cache right-click dispatches real harvesting")
	await _frames(8)
	_check(harvest.harvest_panel.label.text.contains("Cargo 0 / 100") and harvest.harvest_panel.label.text.contains("200 remaining"), "selected collector panel shows cargo and assigned-cache contents")
	await _capture("harvesting_panel")
	var version := work.generation
	await _click(harvest.harvest_panel.get_global_rect().position + Vector2(20, 20), MOUSE_BUTTON_RIGHT)
	_check(work.generation == version, "cargo panel consumes contextual mouse commands")
	await _until(func() -> bool: return work.cargo == 25, 10, "UI fixture loads real cargo")
	_motion(harvest.harvest_panel.get_global_rect().position + Vector2(20, 20))
	await _frames(2)
	_key_x()
	await _frames(2)
	_check(work.state == CollectorHarvest.State.IDLE and work.cargo == 25 and not truck.moving, "viewport X over passive cargo panel cancels work and retains cargo")
	await _click(_world_screen(harvest.caches[1].global_position + Vector3.UP), MOUSE_BUTTON_RIGHT)
	_check(work.cache_node() == harvest.caches[1] and work.cargo == 25, "viewport cache replacement retains cargo")
	var consumer := StopConsumer.new()
	consumer.focus_mode = Control.FOCUS_ALL
	consumer.position = Vector2(500, 100)
	consumer.size = Vector2(160, 40)
	root.add_child(consumer)
	consumer.grab_focus()
	version = work.generation
	_key_x()
	await _frames(2)
	_check(consumer.consumed == 1 and work.generation == version and work.automatic, "focused GUI consumes X without cancelling harvesting")
	consumer.release_focus()
	consumer.free()
	await _click(_world_screen(Vector3(-14, 0, -1)), MOUSE_BUTTON_RIGHT)
	_check(work.state == CollectorHarvest.State.IDLE and work.cargo == 25 and truck.moving, "viewport ground right-click cancels automation through existing Move")
	await _click(_world_screen(harvest.headquarters.global_position + Vector3.UP * 2), MOUSE_BUTTON_RIGHT)
	_check(work.state == CollectorHarvest.State.RETURNING and not work.automatic, "viewport HQ right-click accepts one-shot return")
	await _until(func() -> bool: return work.state == CollectorHarvest.State.IDLE and harvest.credits.balance(1) == 1025, 15, "viewport manual return actually deposits")
	_check(harvest.production_panel.credit_label.text.contains("1025"), "existing credit display updates from harvesting")
	var position_before := harvest.camera_rig.position
	_motion(Vector2(700, 650))
	var pan := InputEventKey.new()
	pan.physical_keycode = KEY_S
	pan.pressed = true
	Input.parse_input_event(pan)
	await _frames(10)
	pan.pressed = false
	Input.parse_input_event(pan)
	await _frames(2)
	_check(harvest.camera_rig.position.distance_to(position_before) > 0.1 and work.state == CollectorHarvest.State.IDLE, "S remains camera pan without creating collector orders")
	await _click(_world_screen(harvest.barracks.global_position + Vector3.UP * 2), MOUSE_BUTTON_LEFT)
	_check(harvest.selection.selected_building() == harvest.barracks and not harvest.harvest_panel.visible and harvest.production_panel.train_button.visible, "building selection hides cargo and preserves production UI")
	await _click(harvest.production_panel.train_button.get_global_rect().get_center(), MOUSE_BUTTON_LEFT)
	_check(harvest.barracks.production.count() == 1 and harvest.credits.balance(1) == 925, "existing viewport Train control spends the same wallet")
	var job_id: int = harvest.barracks.production.jobs()[0]["id"]
	await _click(harvest.production_panel.cancel_buttons[job_id].get_global_rect().get_center(), MOUSE_BUTTON_LEFT)
	_check(harvest.barracks.production.count() == 0 and harvest.credits.balance(1) == 1025, "existing viewport Cancel refunds that wallet")


func _earned_production_checks() -> void:
	await _fresh_harvest(100, 0)
	var producer := harvest.barracks.production
	var rejected := producer.enqueue(1, harvest.barracks.recipe)
	_check(not rejected.accepted and producer.count() == 0 and harvest.credits.balance(1) == 0, "zero-credit fixture rejects unaffordable production")
	var truck := _select_collector()
	var work := truck.harvesting
	var ledger := {"deposited": 0, "spending": 0}
	work.transferred.connect(func(result: HarvestTransfer) -> void:
		if result.kind == HarvestTransfer.Kind.DEPOSIT: ledger["deposited"] += result.amount
	)
	await _click(_world_screen(harvest.caches[0].global_position + Vector3.UP), MOUSE_BUTTON_RIGHT)
	_check(_complete(harvest.last_command_result), "earned-production fixture uses viewport harvest command")
	await _until(func() -> bool: return ledger["deposited"] == 100, 22, "real collector deposits enough earned supply for one Rifle")
	_check(work.cargo == 0 and harvest.caches[0].remaining == 0 and harvest.credits.balance(1) == 100, "only the committed supplies fund the available balance")
	await _click(_world_screen(harvest.barracks.global_position + Vector3.UP * 2), MOUSE_BUTTON_LEFT)
	await _click(harvest.production_panel.train_button.get_global_rect().get_center(), MOUSE_BUTTON_LEFT)
	if producer.count() == 1: ledger["spending"] = 100
	_check(producer.count() == 1 and harvest.credits.balance(1) == ledger["deposited"] - ledger["spending"] and ledger["spending"] == 100, "normal UI purchase spends exactly the earned deposit")
	await _until(func() -> bool: return harvest.units.size() == 9, 6, "existing production queue deploys the purchased Rifle")
	if harvest.units.size() != 9: return
	var rifle := harvest.units[-1]
	_check(rifle.unit_id == 9 and rifle.owner_id == 1 and rifle.combat.weapon != null and rifle.visible and harvest.contains_unit(rifle), "earned Rifle has fresh stable identity, ownership, health and weapon")
	_check(rifle.moving and rifle.assigned_destination.distance_to(producer.rally_point) < 0.01, "earned Rifle receives the existing production rally order")
	await _until(func() -> bool: return not rifle.moving, 12, "earned Rifle actually navigates to rally")
	var target := harvest.units[3]
	target.combat.retaliation_enabled = false
	var health_before := target.combat.health.current
	await _click(_screen(rifle), MOUSE_BUTTON_LEFT)
	await _click(_screen(target), MOUSE_BUTTON_RIGHT)
	_check(_complete(harvest.last_command_result) and rifle.combat.target_unit() == target, "viewport selects the produced Rifle and dispatches contextual combat")
	await _until(func() -> bool: return is_instance_valid(target) and target.combat.health.current < health_before, 18, "harvesting-funded unit pursues and deals verified weapon damage")
	_check(harvest.credits.balance(1) == 0 and ledger["deposited"] == 100 and ledger["spending"] == 100, "end-to-end spending uses no test-granted credits")
	rifle.stop()
