extends "res://tests/construction_checks.gd"
## Scenario checks use the existing harness, wrapper and real gameplay components.

var battle: BaseAssaultField


func _run() -> void:
	root.size = Vector2i(1280, 800)
	var logger := EngineErrorProbe.new()
	OS.add_logger(logger)
	var chosen := "all"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--assault-case="):
			chosen = argument.trim_prefix("--assault-case=")
	var cases := ["weapons", "lifecycle", "outcomes", "loop"]
	_check(chosen == "all" or cases.has(chosen), "recognized base assault case")
	for case in cases:
		if chosen != "all" and chosen != case:
			continue
		var before := checks
		var failed := failures
		match case:
			"weapons": await _building_weapons()
			"lifecycle": await _destruction_lifecycle()
			"outcomes": await _match_outcomes()
			"loop": await _playable_loop()
		print("ASSAULT_CASE: %s; checks=%d failures=%d" % [case, checks - before, failures - failed])
	if is_instance_valid(battle):
		battle.queue_free()
	await _frames(5)
	_check(root.get_children().is_empty(), "assault teardown removes scene, UI and projectiles")
	OS.remove_logger(logger)
	_check(logger.error_count() == 0, "no native errors or warnings through assault checks and teardown")
	print("BASE_ASSAULT_CHECKS: %d checks, %d failures; native_errors=%d" % [checks, failures, logger.error_count()])
	quit(0 if failures == 0 else 1)


func _fresh_assault(delay: float = 90.0) -> void:
	if is_instance_valid(battle):
		battle.queue_free()
		await _frames(4)
	battle = load("res://scenes/base_assault.tscn").instantiate() as BaseAssaultField
	battle.assault_delay = delay
	field = battle
	world = battle
	harvest = battle
	root.add_child(battle)
	current_scene = battle
	battle.camera_rig.edge_scrolling_enabled = false
	await _frames(5)
	_check(battle.units.size() == 8 and battle.collectors.size() == 2 and battle.caches.size() == 2 and battle._producers.is_empty(), "new assault has existing small forces/collectors/resources, no barracks")
	_check(battle.credits.balance(1) == 1000 and battle.caches[0].remaining == 2000 and battle.headquarters.health.current == 1200 and battle.enemy_headquarters.health.current == 1200, "fresh default funds, finite supplies and HQ health")
	_check(battle.result == BaseAssaultField.Result.RUNNING and battle.gameplay_enabled and not battle.result_overlay.visible and not battle.assault_issued, "fresh match starts running without old result or assault")


func _building_weapons() -> void:
	await _fresh_assault(1000)
	var source := battle.units[0]
	var target := battle.enemy_headquarters
	# Isolated weapons fixture; the separate integrated loop never repositions actors.
	source.global_position = Vector3(12.5, 0, -12)
	source.halt_motion()
	await _frames(3)
	battle.selection.select_clicked(source, false)
	await _click(_world_screen(target.global_position + Vector3.UP * 1.5), MOUSE_BUTTON_RIGHT)
	_check(source.combat.target_actor() == target and source.combat.target_unit() == null, "viewport hostile-building click uses combat target without pretending it is a unit")
	if not await _until(func() -> bool: return target.health.current < target.health.maximum, 3, "Rifle actually faces and damages its building target through its own collider"): return
	source.stop()
	var weapon := source.combat.weapon
	var shots := weapon.shots_fired
	var health_before := target.health.current
	await physics_frame
	_check(not weapon.try_fire(target) and weapon.shots_fired == shots and target.health.current == health_before, "building target cannot bypass existing committed cooldown")
	_check(not battle.fire_query.segment(battle.get_world_3d(), LineOfFire.muzzle(source), LineOfFire.aim(target)).is_clear(), "ordinary line query still sees HQ blocker; target exclusion does not leak")
	var wall := StaticBody3D.new()
	wall.collision_layer = LineOfFire.BLOCKER_MASK
	wall.collision_mask = 0
	wall.position = Vector3(15, 1, -12)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.4, 2, 3)
	shape.shape = box
	wall.add_child(shape)
	battle.add_child(wall)
	await _frames(3)
	_check(source.combat.issue_attack(target), "building behind intervening wall accepts persistent Attack")
	await _frames(90)
	_check(source.combat.state == CombatController.State.BLOCKED and weapon.shots_fired == shots and target.health.current == health_before, "intervening wall blocks Rifle without committing damage or cooldown")
	source.stop()
	wall.queue_free()
	await _frames(3)
	var rocket := RTSUnit.new()
	rocket.unit_id = 90
	rocket.owner_id = 1
	rocket.combat_weapon = load("res://weapons/rocket.tres")
	rocket.position = Vector3(11, 0, -9)
	battle.add_child(rocket)
	battle.register_unit(rocket)
	await _frames(3)
	_check(rocket.combat.issue_attack(target), "existing Rocket configuration accepts building target")
	if not await _until(func() -> bool: return target.health.current <= health_before - 32, 5, "guided spherical Rocket reaches intended building and applies existing damage"): return
	rocket.stop()
	await _frames(10)
	# One ordinary in-flight shot meets a newly introduced static wall before the HQ.
	await _until(func() -> bool: return rocket.combat.weapon.cooldown_remaining == 0, 2, "Rocket cooldown expires before separate world-contact case")
	var flights: Array[GuidedProjectile] = []
	var launched := func(_target: Node3D, projectile: GuidedProjectile) -> void: flights.append(projectile)
	rocket.combat.weapon.fired.connect(launched)
	_check(rocket.combat.issue_attack(target), "Rocket begins another ordinary building attack")
	if not await _until(func() -> bool: return not flights.is_empty(), 2, "building-directed projectile launches before obstruction is introduced"): return
	rocket.stop()
	var outcomes: Array[float] = []
	flights[0].resolved.connect(func(amount: float) -> void: outcomes.append(amount))
	health_before = target.health.current
	wall = StaticBody3D.new()
	wall.collision_layer = LineOfFire.BLOCKER_MASK
	wall.collision_mask = 0
	wall.position = Vector3(15, 1, -11)
	shape = CollisionShape3D.new()
	box = BoxShape3D.new()
	box.size = Vector3(0.4, 2, 5)
	shape.shape = box
	wall.add_child(shape)
	battle.add_child(wall)
	if not await _until(func() -> bool: return not outcomes.is_empty(), 3, "actual building-directed Rocket resolves against intervening wall"): return
	_check(outcomes == [0.0] and target.health.current == health_before, "target-body exclusion does not let Rocket pass through another blocker")
	shots = rocket.combat.weapon.shots_fired
	_check(rocket.combat.issue_attack(target), "Rocket retains target while wall is present")
	await _frames(130)
	_check(rocket.combat.state == CombatController.State.BLOCKED and rocket.combat.weapon.shots_fired == shots, "intervening wall also blocks new Rocket launches at the building")
	rocket.stop()
	rocket.combat.weapon.fired.disconnect(launched)
	wall.queue_free()
	await _frames(3)
	await physics_frame
	_check(battle.fire_query.sweep_sphere(battle.get_world_3d(), Vector3(15, 0.75, -12), Vector3(20, 0.75, -12), 0.1).blocked, "ordinary sphere query still collides with building after target-specific flight exclusion")
	_check(not battle.issue_attack(battle.headquarters).has_acceptance(), "friendly HQ rejects hostile Attack")
	battle.selection.select_clicked(battle.collectors[0], false)
	_check(not battle.issue_attack(target).has_acceptance(), "collectors remain unarmed against buildings")
	battle.selection.select_clicked(source, false)
	_check(source.move_to(Vector3(11, 0, -13)), "source accepts normal replacement Move")
	var version := source.order_version
	_check(not battle.issue_attack(battle.headquarters).has_acceptance() and source.order_version == version and source.moving, "rejected friendly building target preserves existing movement order")
	var detached := RTSBuilding.new()
	detached.owner_id = 2
	detached.position = Vector3(23, 0, 17)
	battle.add_child(detached)
	battle.register_building(detached)
	_check(source.combat.issue_attack(detached), "registered hostile building fixture accepts Attack")
	battle.remove_child(detached)
	_check(source.combat.target_actor() == null and not TeamRules.can_attack(battle, source, detached), "building departure immediately invalidates dependent attack")
	detached.free()
	var stale: Variant = detached
	_check(not battle.issue_attack(stale).has_acceptance(), "freed building reference rejects safely at public command boundary")
	var other := ProductionField.new()
	root.add_child(other)
	_check(not TeamRules.can_attack(battle, source, other.headquarters), "foreign-field building cannot become a target")
	_check(other.headquarters.health == null and not TeamRules.can_attack(other, other.units[3], other.headquarters), "legacy production buildings remain invulnerable by default")
	other.queue_free()
	await _frames(4)
	var truck := battle.collectors[0]
	battle.selection.select_clicked(truck, false)
	_check(_complete(battle.issue_harvest(battle.caches[0])), "new-scenario collector accepts normal loading trip for manual deposit")
	if not await _until(func() -> bool: return truck.harvesting.cargo >= 25, 12, "collector actually loads cargo before owned-HQ click"): return
	truck.stop()
	var cargo := truck.harvesting.cargo
	var balance := battle.credits.balance(1)
	await _click(_world_screen(battle.headquarters.global_position + Vector3.UP * 1.5), MOUSE_BUTTON_RIGHT)
	_check(truck.harvesting.state == CollectorHarvest.State.RETURNING and not truck.harvesting.automatic, "viewport owned damageable-HQ click retains manual deposit command")
	if not await _until(func() -> bool: return truck.harvesting.cargo == 0, 12, "manual deposit actually returns and unloads at the damageable HQ"): return
	_check(battle.credits.balance(1) == balance + cargo and truck.harvesting.state == CollectorHarvest.State.IDLE, "manual HQ deposit credits cargo exactly once and idles")


func _destruction_lifecycle() -> void:
	await _fresh_assault(1000)
	var site := await _ready_site(await _place())
	if site == null: return
	var building := site.building()
	var enemy := battle.units[3]
	_check(building.health != null and not building.can_take_damage() and TeamRules.damage_target(battle, 2, building, 100, enemy) == 0, "unfinished site remains immune with its original paid cancellation lifecycle")
	if not await _complete_site(site): return
	_check(building.can_take_damage() and building.health.current == 450 and building._identity_label.visible and not building.health_label.visible and building.health_bar.visible == building.selection_indicator.visible, "completion enables configured barracks health with compact identity and contextual health feedback")
	var producer := building.production
	_check(producer.enqueue(1, building.recipe).accepted, "destruction fixture first pays for a real deployed Rifle")
	if not await _until(func() -> bool: return producer.count() == 0, 7, "first destruction-fixture Rifle actually deploys"): return
	var deployed: RTSUnit
	for unit in battle.units:
		if unit.unit_id == producer.last_deployment["unit_id"]: deployed = unit
	var job := producer.enqueue(1, building.recipe)
	_check(job.accepted, "destruction fixture pays for an ordinary undeployed job")
	var pending := await _place(SECOND)
	_check(pending.accepted, "second paid site starts navigation preparation")
	var pending_site := _site(pending)
	if pending_site == null: return
	var old_balance := battle.credits.balance(1)
	var old_version := battle.construction.navigation.generation
	var notifications := {"count": 0, "coherent": true}
	producer.changed.connect(func() -> void:
		notifications["count"] += 1
		notifications["coherent"] = notifications["coherent"] and not battle.contains_building(building) and not battle.obstacles.has(site.rectangle) and not producer.enqueue(1, building.recipe).accepted and producer.count() == 0
		producer.close(true))
	battle.selection.select_building(building)
	await physics_frame
	var applied := TeamRules.damage_target(battle, 2, building, 10000, enemy)
	_check(applied == 450 and building.destroyed and building.collision_layer == 0 and not producer.is_available(), "lethal building damage commits terminal collision and producer unavailability")
	_check(battle.credits.balance(1) == old_balance + 100 and producer.count() == 0 and notifications["count"] == 1 and notifications["coherent"], "destruction refunds only captured undeployed payment once, before coherent reentrant notification")
	_check(is_instance_valid(deployed) and battle.contains_unit(deployed), "destroying the producer leaves its already deployed Rifle alive without refunding it")
	_check(TeamRules.damage_target(battle, 2, building, 10000, enemy) == 0 and not battle.construction.cancel(1, site.site_id).accepted, "dead completed building cannot be killed, cancelled or construction-refunded again")
	_check(not battle.construction.sites.has(site.site_id) and battle.selection.selected_building() == null and pending_site.nav_generation > old_version, "destruction removes selection/site and updates the other site's navigation generation")
	if not await _until(func() -> bool: return pending_site.state == ConstructionSite.State.CONSTRUCTING, 6, "latest combined navigation completes after destruction during preparation"): return
	_check(battle._nav_point(FIRST) and not battle._nav_point(SECOND), "actual navigation restores destroyed footprint and retains unfinished footprint")
	await physics_frame
	_check(battle.fire_query.segment(battle.get_world_3d(), FIRST + Vector3(-4, 1, 0), FIRST + Vector3(4, 1, 0)).is_clear(), "destroyed barracks no longer obstructs weapon queries")
	await _cleanup_site(pending_site)
	_check(battle.construction.unfinished_id == 0 and not battle.construction.navigation.blocked, "subsequent cancellation releases construction slot normally")
	# Terminal callbacks may remove the field; the old coordinators cannot resume it.
	site = await _ready_site(await _place())
	if site == null or not await _complete_site(site): return
	building = site.building()
	producer = building.production
	_check(producer.enqueue(1, building.recipe).accepted, "callback-removal fixture has one paid job")
	var wallet := battle.credits
	producer.changed.connect(func() -> void: battle.queue_free())
	await physics_frame
	TeamRules.damage_target(battle, 2, building, 10000, enemy)
	await _frames(4)
	_check(not is_instance_valid(battle) and not wallet.active and not producer.is_available(), "destruction callback can remove the scene without stale producer work")


func _match_outcomes() -> void:
	await _fresh_assault(0.25) # Only the new scenario's configurable preparation delay differs.
	_check(not battle.restart_match(), "Restart rejects while match is running")
	battle.destroy_building(battle.headquarters)
	_check(battle._lost_headquarters.is_empty(), "cleanup API cannot manufacture an HQ loss from a living building")
	if not await _until(func() -> bool: return battle.result != BaseAssaultField.Result.RUNNING, 50, "scripted enemy force actually attacks and destroys player HQ"): return
	_check(battle.result == BaseAssaultField.Result.DEFEAT and battle.result_label.text == "DEFEAT" and battle.assault_acceptances == 3, "one ordinary scripted assault produces defeat and usable result UI")
	await _capture("m6_defeat")
	await _frames(30)
	_check(battle.assault_acceptances == 3, "assault never retries or resets orders after its one trigger")
	for reverse in [false, true]:
		await _fresh_assault(1000)
		var results: Array[int] = []
		battle.match_finished.connect(func(outcome: int) -> void: results.append(outcome))
		await physics_frame
		if reverse:
			TeamRules.damage_target(battle, 1, battle.enemy_headquarters, 1200, battle.units[0])
			TeamRules.damage_target(battle, 2, battle.headquarters, 1200, battle.units[3])
		else:
			TeamRules.damage_target(battle, 2, battle.headquarters, 1200, battle.units[3])
			TeamRules.damage_target(battle, 1, battle.enemy_headquarters, 1200, battle.units[0])
		_check(battle.result == BaseAssaultField.Result.RUNNING and battle.gameplay_enabled, "same-tick lethal damage waits for end-of-physics result resolution")
		await _frames(3)
		_check(results == [BaseAssaultField.Result.DRAW] and battle.result_label.text == "DRAW", "both HQ losses produce exactly one draw regardless of damage callback order")
		battle.resolve_result()
		_check(results.size() == 1, "terminal resolution is idempotent")
	await _capture("m6_draw")


func _playable_loop() -> void:
	await _fresh_assault() # Actual scene defaults; no grants, actor relocation or artificial army.
	await _capture("m6_initial")
	var site := await _ready_site(await _place())
	if site == null or not await _complete_site(site): return
	var building := site.building()
	var producer := building.production
	var army: Array[RTSUnit] = []
	# Spend all six remaining starting-credit purchases through normal timed production.
	for index in 6:
		var rally := Vector3(-5 + (index % 3) * 1.5, 0, 2 + (index / 3) * 2)
		_check(producer.set_rally(1, rally).accepted and producer.enqueue(1, building.recipe).accepted, "starting-credit Rifle %d enqueued with ordinary distinct rally" % (index + 1))
		if not await _until(func() -> bool: return producer.count() == 0, 7, "Rifle completes five-second training and actual safe deployment"): return
		var identity: int = producer.last_deployment["unit_id"]
		for unit in battle.units:
			if unit.unit_id == identity: army.append(unit)
	_check(army.size() == 6 and battle.credits.balance(1) == 0 and battle.caches[0].remaining == 2000, "construction and six actual deployments consume exactly the starting 1000 credits")
	_check(not producer.enqueue(1, building.recipe).accepted, "seventh Rifle cannot be afforded before earning supplies")
	var truck := battle.collectors[0]
	var deposited := {"amount": 0}
	truck.harvesting.transferred.connect(func(transfer: HarvestTransfer) -> void:
		if transfer.kind == HarvestTransfer.Kind.DEPOSIT: deposited["amount"] += transfer.amount)
	battle.selection.select_clicked(truck, false)
	_check(_complete(battle.issue_harvest(battle.caches[0])), "collector receives actual cache assignment")
	if not await _until(func() -> bool: return battle.credits.balance(1) >= 100, 20, "actual travel/load/return/unload earns at least 100 credits"): return
	truck.stop()
	_check(deposited["amount"] == battle.credits.balance(1) and deposited["amount"] > 0, "every spendable credit now comes from deposited supplies")
	var before := battle.credits.balance(1)
	_check(producer.set_rally(1, Vector3(-5, 0, 6)).accepted and producer.enqueue(1, building.recipe).accepted and battle.credits.balance(1) == before - 100, "earned funds purchase the seventh Rifle through the same wallet and queue")
	if not await _until(func() -> bool: return producer.count() == 0, 7, "earned Rifle actually deploys"): return
	var earned: RTSUnit
	for unit in battle.units:
		if unit.unit_id == producer.last_deployment["unit_id"]: earned = unit
	if not is_instance_valid(earned):
		_check(false, "earned Rifle remains a live registered actor")
		return
	army.append(earned)
	battle.selection.select_clicked(army[0], false)
	for index in range(1, army.size()): battle.selection.select_clicked(army[index], true)
	_check(_complete(battle.issue_move(Vector3(12, 0, -5))), "all seven produced Rifles accept a real group staging command")
	if not await _until(func() -> bool: return army.all(func(unit: RTSUnit) -> bool: return is_instance_valid(unit) and unit.movement_state == RTSUnit.MovementState.ARRIVED), 25, "produced army actually traverses the map to its assigned staging slots"): return
	await _capture("m6_army")
	_check(_complete(battle.issue_attack(battle.enemy_headquarters)), "produced army accepts enemy HQ Attack")
	if not await _until(func() -> bool: return battle.result != BaseAssaultField.Result.RUNNING, 25, "produced army actually destroys enemy HQ and displays a match result"): return
	_check(battle.result == BaseAssaultField.Result.VICTORY and battle.result_label.text == "VICTORY" and battle.result_overlay.visible, "full economic/combat loop reaches visible victory")
	_check(earned.combat.weapon.shots_fired > 0, "earned-credit Rifle contributes actual committed shots to the victory")
	await _capture("m6_victory")
	var wallet := battle.credits
	var manager := battle.construction
	var navigation := manager.navigation
	var balance := wallet.balance(1)
	var supplies := battle.caches[0].remaining
	var clock := battle.elapsed
	var positions: Array[Vector3] = []
	for unit in army: positions.append(unit.global_position)
	await physics_frame
	_check(not battle.issue_move(Vector3.ZERO).has_acceptance() and not earned.move_to(Vector3.ZERO) and not producer.enqueue(1, building.recipe).accepted and not manager.place(1, battle.headquarters, battle.construction_definition, SECOND).accepted, "result rejects field/unit orders, production and construction APIs")
	_check(not truck.harvesting.issue(battle.caches[0], true) and not wallet.credit(1, 100) and earned.combat.health.apply_damage(12) == 0, "result rejects harvesting, deposits and further health mutation")
	await _frames(180)
	var stationary := true
	for index in army.size(): stationary = stationary and army[index].global_position == positions[index]
	_check(stationary and wallet.balance(1) == balance and battle.caches[0].remaining == supplies and battle.elapsed == clock, "gameplay positions/economy/clock stay frozen behind the result")
	_check(not navigation.busy and not navigation.blocked and battle._nav_point(Vector3(20, 0, -12)), "committed HQ destruction finishes real navigation cleanup after result")
	await _click(battle.restart_button.get_global_rect().get_center(), MOUSE_BUTTON_LEFT)
	await _frames(5)
	battle = current_scene as BaseAssaultField
	field = battle
	world = battle
	harvest = battle
	_check(is_instance_valid(battle), "viewport Restart loads the actual base-assault scene")
	if not is_instance_valid(battle): return
	battle.camera_rig.edge_scrolling_enabled = false
	_check(battle.result == BaseAssaultField.Result.RUNNING and battle.gameplay_enabled and battle.credits.balance(1) == 1000 and battle.caches[0].remaining == 2000 and battle.units.size() == 8, "Restart restores initial outcome, funds, supplies and units")
	_check(battle._producers.is_empty() and battle.construction.sites.is_empty() and battle._access_claims.is_empty() and battle.collectors.all(func(unit: CollectorTruck) -> bool: return unit.harvesting.cargo == 0) and battle.headquarters.health.current == 1200 and battle.enemy_headquarters.health.current == 1200, "Restart restores empty work/cargo/claims and both HQs")
	_check(not battle.assault_issued and battle.elapsed < 1 and not battle.result_overlay.visible and not wallet.active and manager.closed and not producer.is_available(), "Restart has fresh assault clock and closes old wallet/construction/producer state")
	navigation.advance(10)
	manager.advance(10)
	producer.advance(10)
	_check(battle.credits.balance(1) == 1000 and battle._producers.is_empty(), "late calls on old work cannot mutate the replacement match")
	await _capture("m6_restarted")
