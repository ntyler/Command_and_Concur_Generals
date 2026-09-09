extends "res://tests/fixtures/defense_harness.gd"
## Earned M14 opening: original1000 credits, original Bulldozer, paid Depot and
## Collector, actual finite supplies and paid battery/Power Plant. No injected
## cargo, free credits, completion writes, hidden generation or actor teleports.
## Instance-only first-wave delay600s isolates economic acceptance; enemy paid
## production/harvesting stay live. Original enemy Rifles receive explicit test
## movement/attack orders (no new strategic AI). Normal scene remains90/60s.

const DEFENSE_BUILDER_PARK := Vector3(-14.5, 0, -1.5)
const DEFENSE_COLLECTOR_RALLY := Vector3(-5, 0, 2)
const DEFENSE_LANE := Vector3(-4, 0, 3)


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1280, 720)
	var logger := EngineErrorProbe.new()
	OS.add_logger(logger)
	await _earned_defense_opening()
	await _defense_real_result()
	if is_instance_valid(field): field.queue_free()
	await _frames(6)
	_check(root.get_children().is_empty() and get_nodes_in_group("combat_projectiles").is_empty(), "earned defense teardown removes actors, grid, sites and projectiles")
	OS.remove_logger(logger)
	_check(logger.error_count() == 0, "earned defense work/combat/result/Restart produce no native errors or warnings")
	print("DEFENSE_INTEGRATION_CHECKS: %d checks, %d failures; native_errors=%d" % [checks, failures, logger.error_count()])
	quit(0 if failures == 0 else 1)


func _earned_defense_opening() -> void:
	await _fresh_defense(1000, true, true)
	var actor := _player_builders()[0]
	var cache := _depot_player_cache()
	var original_enemies: Array[RTSUnit] = []
	for unit in defended.units:
		if unit.owner_id == 2 and not unit is CollectorTruck and unit.combat.weapon != null:
			original_enemies.append(unit)
			unit.combat.retaliation_enabled = false # Explicit lane/target isolation only.
	_check(cache != null and cache.remaining == 2000 and original_enemies.size() == 3 and defended.credits.balance(1) == 1000 and defended.enemy_controller.is_physics_processing(), "earned defense starts from original finite-cache wallet/builder/three hostile Rifles with live enemy economy")
	if cache == null or original_enemies.size() != 3: return
	var depot := await _power_build(actor, DEPOT, DEPOT_POINT)
	if depot == null: return
	_check(defended.credits.balance(1) == 700 and defended.valid_dropoff(depot, 1) and _grid_is(1, 0, 0), "original Bulldozer builds paid300-credit functioning Depot without power prerequisite")
	defended.selection.select_clicked(actor, false)
	await physics_frame
	_check(defended.issue_move(DEFENSE_BUILDER_PARK).has_acceptance(), "builder receives ordinary Move to clear Depot delivery/production face")
	if not await _until(func() -> bool: return actor.movement_state == RTSUnit.MovementState.ARRIVED, 10, "builder physically clears new Depot face"): return
	await physics_frame
	_check(depot.production.set_rally(1, DEFENSE_COLLECTOR_RALLY).accepted, "Depot accepts ordinary Collector rally")
	var job := depot.production.enqueue(1, COLLECTOR_RECIPE)
	_check(job.accepted and defended.credits.balance(1) == 500, "normal paid Collector costs200 and leaves500 credits")
	if not await _until(func() -> bool: return depot.production.count() == 0 and not depot.production.last_deployment.is_empty(), 7, "paid Collector trains/deploys through normal production"): return
	var truck := _last_unit(depot.production) as CollectorTruck
	_check(truck != null and defended.contains_unit(truck) and truck.harvesting.cargo == 0, "paid Collector is an ordinary registered initially empty mobile unit")
	if truck == null: return
	if not await _until(func() -> bool: return truck.movement_state == RTSUnit.MovementState.ARRIVED, 12, "paid Collector physically reaches rally"): return
	var ledger := {"loaded": 0, "deposited": 0, "spent": 500, "low_loads": 0, "low_deposits": 0, "owner_correct": true, "conserved": true, "coherent": true}
	truck.harvesting.transferred.connect(func(transfer: HarvestTransfer) -> void:
		ledger.owner_correct = ledger.owner_correct and transfer.owner_id == 1 and transfer.collector_id == truck.unit_id
		var low: bool = defended.power_snapshot(1).low_power
		if transfer.kind == HarvestTransfer.Kind.LOAD:
			ledger.loaded += transfer.amount
			if low: ledger.low_loads += transfer.amount
		else:
			ledger.deposited += transfer.amount
			if low: ledger.low_deposits += transfer.amount
		ledger.conserved = ledger.conserved and cache.remaining + truck.harvesting.cargo + ledger.deposited == 2000
		ledger.coherent = ledger.coherent and defended.credits.balance(1) == 1000 + ledger.deposited - ledger.spent
	)
	await _hud_pick_unit(truck)
	await _click(_world_screen(cache.global_position + Vector3.UP), MOUSE_BUTTON_RIGHT)
	_check(truck.harvesting.automatic and truck.harvesting.cache_node() == cache, "viewport harvest command starts real finite supply collection")
	if not await _until(func() -> bool: return ledger.deposited >= 200, 55, "real loading/travel/unloading earns the battery's otherwise missing200 credits"):
		_defense_earned_failure(truck, ledger)
		return
	var result := await _builder_place(actor, DEFENSE, FIRST)
	if result.accepted: ledger.spent += DEFENSE.credit_cost
	var site := await _builder_arrival(result)
	if site == null: return
	var battery := site.building() as GroundDefenseBattery
	_check(result.paid == 700 and not battery.operational and battery.weapon.shots_fired == 0 and _grid_is(1, 0, 0), "earned700-credit unfinished battery has real builder work and no hidden operational power/fire")
	if not await _builder_complete(site): return
	var stationary := battery.global_transform
	_check(site.elapsed == 12 and battery.health.current == 600 and _grid_is(1, 0, 3) and battery.weapon.shots_fired == 0, "normal12-second paid builder completion creates stationary600HP consumer during genuine shortage")
	var target := original_enemies[0]
	await physics_frame
	_check(target.move_to(DEFENSE_LANE), "ordinary original hostile Rifle accepts test-lane ground movement")
	if not await _until(func() -> bool: return target.movement_state == RTSUnit.MovementState.ARRIVED and target.global_position.distance_to(DEFENSE_LANE) < 0.5, 20, "hostile physically enters a clear in-range lane without teleports"): return
	await _frames(60)
	await physics_frame
	_check(defended.fire_query.weapon_clearance(battery, target, DEFENSE.weapon_data).is_clear() and target.combat.health.current == 100 and battery.weapon.shots_fired == 0 and battery.target_actor() == null and battery.status_text() == "No power", "actual clear eligible threat takes no damage while completed battery is unpowered")
	if not await _until(func() -> bool: return defended.credits.balance(1) >= 500 and ledger.low_loads > 0 and ledger.low_deposits > 0, 100, "real Collector keeps earning through shortage until the500-credit Power Plant is affordable"):
		_defense_earned_failure(truck, ledger)
		return
	_check(ledger.deposited >= 700 and _grid_is(1, 0, 3) and battery.weapon.shots_fired == 0, "finite supply earnings fund recovery without power grants or pre-restoration damage")
	result = await _builder_place(actor, POWER_PLANT, SECOND)
	if result.accepted: ledger.spent += POWER_PLANT.credit_cost
	var plant_site := await _builder_arrival(result)
	if plant_site == null: return
	var plant := plant_site.building()
	var damage := {"events": 0, "total": 0.0, "first_tick": -1, "source_correct": true, "completed": true}
	target.combat.health.damaged.connect(func(amount: float, source: Node) -> void:
		damage.events += 1
		damage.total += amount
		if damage.first_tick < 0: damage.first_tick = Engine.get_physics_frames()
		damage.source_correct = damage.source_correct and source == battery
		damage.completed = damage.completed and plant_site.state == ConstructionSite.State.OPERATIONAL and defended.power_snapshot(1).generated == 10
	)
	await _frames(60)
	_check(plant_site.state == ConstructionSite.State.CONSTRUCTING and plant_site.elapsed > 0 and plant_site.elapsed < 10 and battery.weapon.shots_fired == 0 and target.combat.health.current == 100 and _grid_is(1, 0, 3), "unfinished paid Power Plant grants no generation or defensive shot during real work")
	if not await _builder_complete(plant_site): return
	var completion_tick := Engine.get_physics_frames()
	_check(plant.operational and plant_site.elapsed == 10 and _grid_is(1, 10, 3), "same original Bulldozer's actual ten-second plant completion restores sufficient owner power")
	if not await _until(func() -> bool: return damage.events > 0, 3, "actual generation completion enables battery rotation and real18-damage hitscan"): return
	_check(damage.events == 1 and damage.total == 18 and damage.source_correct and damage.completed and damage.first_tick >= completion_tick - 1 and target.combat.health.current == 82, "first real damage notification proves battery source and powered-completion timing")
	var target_ref: WeakRef = weakref(target)
	if not await _until(func() -> bool: return target_ref.get_ref() == null or not target_ref.get_ref().is_alive(), 5, "six ordinary battery hits destroy the hostile ground threat"): return
	_check(damage.events == 6 and damage.total == 100 and battery.weapon.shots_fired == 6 and battery.global_transform == stationary and _grid_is(1, 10, 3), "real six-shot defense kill clamps100 damage and preserves stationary base/full nominal demand")
	await _hud_pick_building(battery)
	await _defense_capture("defense_earned_powered_1280x720")
	var attacker := original_enemies[1]
	await physics_frame
	_check(attacker.move_to(Vector3(5, 0, 16)), "second ordinary hostile receives an approach outside battery range")
	if not await _until(func() -> bool: return attacker.movement_state == RTSUnit.MovementState.ARRIVED, 20, "hostile physically approaches the paid Power Plant on southern ground"): return
	var plant_damage := {"events": 0, "amount": 0.0, "ordinary": true}
	plant.health.damaged.connect(func(amount: float, source: Node) -> void:
		plant_damage.events += 1
		plant_damage.amount += amount
		plant_damage.ordinary = plant_damage.ordinary and source == attacker
	)
	await physics_frame
	_check(attacker.combat.issue_attack(plant), "ordinary hostile Rifle Attack targets completed player power infrastructure")
	var plant_ref: WeakRef = weakref(plant)
	if not await _until(func() -> bool: return plant_ref.get_ref() == null or not plant_ref.get_ref().is_alive(), 40, "real unchanged Rifle weapon destroys paid generator through ordinary facing/cooldown/damage"): return
	await _frames(3)
	_check(plant_damage.events == 38 and plant_damage.amount == 450 and plant_damage.ordinary and _grid_is(1, 0, 3) and battery.status_text() == "No power" and defended.result == BaseAssaultField.Result.RUNNING, "actual infrastructure attack removes generator once and interrupts battery without ending HQ match")
	var survivor := original_enemies[2]
	await physics_frame
	_check(survivor.move_to(DEFENSE_LANE), "another ordinary threat receives the previously proven clear lane")
	if not await _until(func() -> bool: return survivor.movement_state == RTSUnit.MovementState.ARRIVED, 20, "new hostile physically enters lane after generator destruction"): return
	var shots := battery.weapon.shots_fired
	await _frames(90)
	_check(survivor.combat.health.current == 100 and battery.weapon.shots_fired == shots and battery.target_actor() == null and _grid_is(1, 0, 3), "destroyed power infrastructure prevents subsequent otherwise-ready defensive damage")
	truck.stop()
	_check(ledger.spent == 1700 and ledger.owner_correct and ledger.conserved and ledger.coherent and cache.remaining + truck.harvesting.cargo + ledger.deposited == 2000 and defended.credits.balance(1) == 1000 + ledger.deposited - 1700, "earned loop reconciles original1000 plus real deposits minus1700 paid Depot/Collector/Battery/Plant")
	_check(defended.enemy_controller.accepted_jobs > 0 and defended.enemy_controller.deployments > 0 and defended.enemy_controller.harvest_assignments == 2 and defended.enemy_cache.remaining < 2000 and _grid_is(2, 10, 5), "real enemy paid production and finite harvesting continue independently throughout player power defense loop")
	print("DEFENSE_INTEGRATION: elapsed=%.3f battery_shots=%d defense_damage=%s plant_damage=%s ledger=%s wallet=%d grid=%s enemy_jobs=%d enemy_deployments=%d" % [defended.elapsed, battery.weapon.shots_fired, damage, plant_damage, ledger, defended.credits.balance(1), defended.power_snapshot(1), defended.enemy_controller.accepted_jobs, defended.enemy_controller.deployments])


func _defense_earned_failure(truck: CollectorTruck, ledger: Dictionary) -> void:
	print("DEFENSE_INTEGRATION_FAILURE: elapsed=%.3f collector=%d position=%s destination=%s movement=%s harvest=%s reason=%s cargo=%d wallet=%d grid=%s ledger=%s" % [defended.elapsed, truck.unit_id, truck.global_position, truck.assigned_destination, truck.movement_state, truck.harvesting.state, truck.harvesting.reason, truck.harvesting.cargo, defended.credits.balance(1), defended.power_snapshot(1), ledger])


func _defense_real_result() -> void:
	# Separate explicitly isolated combat layout; these four test Rifles are not
	# presented as earned units. Real existing emitters must remove all1200 HQHP.
	await _fresh_defense(1000, true)
	var target := defended.enemy_headquarters
	var audit := {"damage": 0.0, "events": 0}
	target.health.damaged.connect(func(amount: float, _source: Node) -> void:
		audit.damage += amount
		audit.events += 1
	)
	var attackers: Array[RTSUnit] = []
	for offset in [Vector3(-2, 0, -6), Vector3(0, 0, -6), Vector3(2, 0, -6), Vector3(4, 0, -6)]:
		var actor := _defense_mobile(target.global_position + offset, 1)
		actor.set_physics_process(true)
		attackers.append(actor)
	await _frames(3)
	for actor in attackers:
		await physics_frame
		_check(actor.combat.issue_attack(target), "isolated result fixture Rifle accepts actual hostile HQ Attack")
	if not await _until(func() -> bool: return defended.result != BaseAssaultField.Result.RUNNING, 35, "real Rifle hitscan combat reaches normal HQ match result in defense scene"): return
	_check(defended.result == BaseAssaultField.Result.VICTORY and audit.damage == 1200 and audit.events == 100 and defended.restart_button.visible, "real100 unchanged Rifle hits remove1200 objectiveHP and expose normal Victory/Restart")
	var old_grid := defended.power_grid
	await _click(defended.restart_button.get_global_rect().get_center(), MOUSE_BUTTON_LEFT)
	await _frames(10)
	_adopt_defense(current_scene as DefenseAssaultField)
	_check(defended != null and defended.scene_file_path == "res://scenes/defense_assault.tscn" and defended.result == BaseAssaultField.Result.RUNNING and _grid_is(1, 0, 0) and _grid_is(2, 10, 5) and defended.credits.balance(1) == 1000 and old_grid.changed.get_connections().is_empty(), "viewport Restart after real emitter victory restores clean normal defense opening")
	if defended == null: return
	var config := defended.enemy_config
	_check(config.first_wave_time == 90 and config.wave_interval == 60 and config.starting_credits == 300 and config.population_limit == 12 and config.preferred_wave_size == 3 and config.maximum_wave_size == 3 and config.partial_wait == 30, "fresh normal scene retains exact enemy timing/wallet/population/wave rules")
