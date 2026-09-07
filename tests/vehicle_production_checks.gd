extends "res://tests/base_assault_checks.gd"
## Focused M7 checks on the existing physics/viewport harness. Isolated fixtures
## may configure funds/actors; _combined_loop starts at zero and never grants any.

const FACTORY: ConstructionDefinition = preload("res://construction/vehicle_factory.tres")
const ROCKET_RECIPE: ProductionDefinition = preload("res://production/rocket_vehicle.tres")

class RefusingAssault extends BaseAssaultField:
	var reject_rally: bool = false
	func order_deployed_unit(unit: RTSUnit, destination: Vector3) -> bool:
		return false if reject_rally else super.order_deployed_unit(unit, destination)


func _run() -> void:
	root.size = Vector2i(1280, 800)
	var logger := EngineErrorProbe.new()
	OS.add_logger(logger)
	var chosen := "all"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--vehicle-case="):
			chosen = argument.trim_prefix("--vehicle-case=")
	var cases := ["construction", "queues", "deployment", "weapons", "results", "timing", "loop"]
	_check(chosen == "all" or cases.has(chosen), "recognized vehicle production case")
	for case in cases:
		if chosen != "all" and chosen != case: continue
		var before := checks
		var failed := failures
		match case:
			"construction": await _factory_construction()
			"queues": await _factory_queues()
			"deployment": await _vehicle_deployment()
			"weapons": await _vehicle_weapons()
			"results": await _factory_results()
			"timing": await _default_assault_timing()
			"loop": await _combined_loop()
		print("VEHICLE_CASE: %s; checks=%d failures=%d" % [case, checks - before, failures - failed])
	if is_instance_valid(battle): battle.queue_free()
	await _frames(5)
	_check(root.get_children().is_empty() and get_nodes_in_group("combat_projectiles").is_empty(), "vehicle teardown removes fields, previews, units, queues and projectiles")
	OS.remove_logger(logger)
	_check(logger.error_count() == 0, "vehicle checks and teardown have no native errors or warnings")
	print("VEHICLE_PRODUCTION_CHECKS: %d checks, %d failures; native_errors=%d" % [checks, failures, logger.error_count()])
	quit(0 if failures == 0 else 1)


func _fresh_combined(funds: int = 1000, delay: float = 90.0, refusing: bool = false) -> void:
	if is_instance_valid(battle):
		battle.queue_free()
		await _frames(4)
	battle = RefusingAssault.new() if refusing else load("res://scenes/combined_arms_assault.tscn").instantiate() as BaseAssaultField
	if refusing: battle.vehicle_factory_definition = FACTORY
	battle.starting_credits = funds
	battle.assault_delay = delay
	field = battle
	world = battle
	harvest = battle
	root.add_child(battle)
	current_scene = battle
	battle.camera_rig.edge_scrolling_enabled = false
	await _frames(5)
	_check(battle.credits.balance(1) == funds and battle.units.size() == 8 and battle.collectors.size() == 2 and battle.caches[0].remaining == 2000 and battle._producers.is_empty(), "combined scene starts with configured funds, original force/resources and neither production building")
	_check(battle.vehicle_factory_definition == FACTORY and battle.result == BaseAssaultField.Result.RUNNING and battle.headquarters.health.current == 1200 and battle.enemy_headquarters.health.current == 1200, "combined scene opts into factory with original HQ/result defaults")


func _place_factory(point: Vector3 = FIRST) -> ConstructionResult:
	await physics_frame
	return battle.construction.place(1, battle.headquarters, FACTORY, point)


func _factory(point: Vector3 = FIRST) -> RTSBuilding:
	var site := await _ready_site(await _place_factory(point))
	if site == null or not await _complete_site(site): return null
	return site.building()


func _last_unit(producer: UnitProduction) -> RTSUnit:
	for unit in battle.units:
		if unit.unit_id == producer.last_deployment.get("unit_id", -1): return unit
	return null


func _train_vehicle(building: RTSBuilding) -> RTSUnit:
	_check(building.production.enqueue(1, building.recipe).accepted, "normal factory queue accepts paid Rocket Vehicle")
	if not await _until(func() -> bool: return building.production.count() == 0, 9, "eight-second Rocket training actually deploys through ordinary registration"): return null
	return _last_unit(building.production)


func _vehicle_wall(size: Vector3, point: Vector3) -> StaticBody3D:
	var wall := StaticBody3D.new()
	wall.collision_layer = 4 | 8
	wall.collision_mask = 0
	wall.position = point
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	collider.shape = box
	wall.add_child(collider)
	battle.add_child(wall)
	return wall


func _factory_construction() -> void:
	await _fresh_combined()
	var panel := battle.production_panel as ConstructionPanel
	_check(FACTORY.is_valid() and FACTORY.credit_cost == 600 and FACTORY.duration == 15 and FACTORY.footprint == Vector2(6, 5), "factory has specified configurable price/time and fixed modest footprint")
	_check(panel.build_button.visible and panel.factory_button.visible and panel.factory_button.text.contains("600") and panel.factory_button.text.contains("15"), "HQ offers both priced construction choices")
	await _click(panel.factory_button.get_global_rect().get_center(), MOUSE_BUTTON_LEFT)
	_motion(_world_screen(FIRST))
	await _frames(8)
	_check(battle.placement.active and battle.placement.definition == FACTORY and battle.placement.valid and (battle.placement.preview.mesh as BoxMesh).size == Vector3(6, 2.8, 5), "viewport factory choice creates the matching free valid preview")
	await _click(panel.credit_label.get_global_rect().get_center(), MOUSE_BUTTON_LEFT)
	_check(battle.construction.sites.is_empty() and battle.credits.balance(1) == 1000, "UI click does not leak into factory placement or spending")
	await _capture("m7_factory_preview")
	await physics_frame
	for point in [Vector3(27, 0, 0), battle.headquarters.position, Vector3(-13, 0, -12), battle.units[0].position]:
		_check(not battle.construction.place(1, battle.headquarters, FACTORY, point).accepted and battle.credits.balance(1) == 1000, "factory invalid boundary/obstacle/access/live-unit geometry spends nothing at %s" % point)
	_check(not battle.construction.place(2, battle.headquarters, FACTORY, FIRST).accepted, "factory placement rejects unauthorized HQ")
	await _click(_world_screen(FIRST), MOUSE_BUTTON_LEFT)
	var result := battle.placement.last_result
	if result == null or not result.accepted:
		_check(false, "viewport confirms a paid factory site")
		return
	var site := await _ready_site(result)
	if site == null: return
	var building := site.building()
	_check(battle.credits.balance(1) == 400 and site.paid == 600 and site.duration == 15 and building.kind == RTSBuilding.Kind.VEHICLE_FACTORY and building.footprint == FACTORY.footprint, "accepted site captures 600/15 and correct factory identity/geometry")
	_check(not building.production.enqueue(1, ROCKET_RECIPE).accepted and not building.can_take_damage() and not panel.train_button.visible and panel.cancel_site_button.visible, "unfinished factory cannot train or take damage and exposes only construction controls")
	await physics_frame
	_check(not battle.construction.place(1, battle.headquarters, battle.construction_definition, SECOND).accepted and not battle.construction.place(1, battle.headquarters, FACTORY, SECOND).accepted, "one unfinished limit is shared by barracks and factories")
	_check(not battle._nav_point(FIRST) and battle.fire_query.segment(battle.get_world_3d(), FIRST + Vector3(-4, 1, 0), FIRST + Vector3(4, 1, 0)).blocked, "unfinished factory's authoritative footprint blocks navigation and weapons")
	await _frames(600)
	_check(not building.operational and site.elapsed >= 10 and site.elapsed < 15, "factory is still unfinished after ten simulated seconds")
	await _cleanup_site(site)
	_check(battle.credits.balance(1) == 1000 and not battle.construction.cancel(1, site.site_id).accepted and battle._nav_point(FIRST), "factory cancellation refunds captured 600 exactly once and restores actual navigation")
	building = await _factory()
	if building == null: return
	_check(building.operational and building.health.current == 450 and building.can_take_damage() and building.recipe == ROCKET_RECIPE and building.queue_capacity == 5, "fifteen-second completion enables normal factory health and Rocket queue")
	battle.selection.select_building(building)
	_check(panel.train_button.visible and panel.train_button.text.contains("Rocket Vehicle") and panel.train_button.text.contains("250") and panel.train_button.text.contains("8") and not panel.factory_button.visible, "completed factory UI has correct recipe/cost/time and hides HQ build actions")
	await _capture("m7_factory_ready")
	await _fresh_assault()
	_check(battle.vehicle_factory_definition == null and not (battle.production_panel as ConstructionPanel).factory_button.visible, "original M6 scene retains Barracks-only defaults")
	await physics_frame
	_check(not battle.construction.place(1, battle.headquarters, FACTORY, FIRST).accepted and battle.credits.balance(1) == 1000, "original scene rejects factory API without spending")


func _factory_queues() -> void:
	await _fresh_combined(3400, 1000) # Isolated queue accounting fixture, not earned loop.
	var a := await _factory()
	var b := await _factory(SECOND)
	if a == null or b == null: return
	# An additional API-only barracks tests the same wallet without adding a third
	# construction layout. It never deploys; real barracks construction is in the loop.
	var barrack := RTSBuilding.new()
	barrack.position = Vector3(20, 0, 18)
	battle.add_child(barrack)
	battle.register_building(barrack)
	barrack.set_physics_process(false)
	var p := a.production
	var q := b.production
	_check(p != q and a.recipe == b.recipe and p.count() == 0 and q.count() == 0, "two actual factories share recipe configuration but own separate empty queues")
	var balance := battle.credits.balance(1)
	_check(not p.enqueue(2, ROCKET_RECIPE).accepted and not p.enqueue(1, barrack.recipe).accepted and not barrack.production.enqueue(1, ROCKET_RECIPE).accepted and battle.credits.balance(1) == balance, "unauthorized and cross-building recipes reject without wallet/queue mutation")
	var old_recipe := a.recipe
	a.recipe = barrack.recipe
	_check(not p.enqueue(1, a.recipe).accepted, "replacing a factory recipe with Rifle cannot bypass building type admission")
	a.recipe = old_recipe
	var jobs: Array[int] = []
	for i in 5: jobs.append(p.enqueue(1, ROCKET_RECIPE).job_id)
	_check(p.count() == 5 and not p.enqueue(1, ROCKET_RECIPE).accepted and battle.credits.balance(1) == balance - 1250, "five paid Rocket slots include active head; sixth rejects with one deduction each")
	_check(q.enqueue(1, ROCKET_RECIPE).accepted and barrack.production.enqueue(1, barrack.recipe).accepted and battle.credits.balance(1) == balance - 1600, "independent factory and barracks debit the same owner wallet")
	await _frames(60)
	_check(p.jobs()[0]["elapsed"] >= 0.99 and p.jobs()[0]["elapsed"] < 1.1 and p.jobs()[1]["elapsed"] == 0 and q.jobs()[0]["elapsed"] > 0.9, "FIFO advances each producer's head independently by simulated time")
	_check(p.cancel(1, jobs[2]).accepted and not p.cancel(1, jobs[2]).accepted, "middle Rocket cancellation refunds once")
	for job in p.jobs(): p.cancel(1, job["id"])
	for job in q.jobs(): q.cancel(1, job["id"])
	for job in barrack.production.jobs(): barrack.production.cancel(1, job["id"])
	_check(battle.credits.balance(1) == balance, "all undeployed cancellation returns exactly captured queue payments")
	a.recipe = ROCKET_RECIPE.duplicate() as ProductionDefinition
	b.recipe = a.recipe
	var captured := p.enqueue(1, a.recipe)
	a.recipe.credit_cost = 1
	a.recipe.training_duration = 0.5
	a.recipe.display_name = "Changed future recipe"
	a.recipe.unit_scene = load("res://scenes/rifle_unit.tscn")
	_check(p.jobs()[0]["paid"] == 250 and p.jobs()[0]["duration"] == 8 and p.jobs()[0]["name"] == "Rocket Vehicle" and not q.enqueue(1, b.recipe).accepted, "shared definition mutation leaves accepted job values intact and rejects invalid future scene")
	if not await _until(func() -> bool: return p.count() == 0, 9, "captured Rocket job deploys its original scene despite shared recipe replacement"): return
	_check(_last_unit(p).combat.weapon.definition == CombatField.ROCKET and not p.cancel(1, captured.job_id).accepted and battle.credits.balance(1) == balance - 250, "captured scene remains Rocket and deployed job cannot refund")
	a.recipe = ROCKET_RECIPE
	b.recipe = ROCKET_RECIPE
	# Exhaust remaining funds with captured default prices, without a credit grant.
	for producer in [p, q, barrack.production]:
		while producer.enqueue(1, producer.building().recipe).accepted: pass
	_check(battle.credits.balance(1) >= 0 and battle.credits.balance(1) < 100, "factories and barracks cannot overspend the common wallet")
	var pending := q.count()
	var saved_recipe := b.recipe
	battle.remove_child(b)
	_check(not q.enqueue(1, saved_recipe).accepted and q.count() == pending, "detached factory immediately rejects stale API without touching jobs")
	await _frames(3)
	_check(not q.is_available() and q.count() == 0, "permanent factory departure closes and reconciles pending queue")
	b.free()
	_check(not q.enqueue(1, saved_recipe).accepted, "freed factory queue reference rejects safely")


func _vehicle_deployment() -> void:
	await _fresh_combined(3000, 1000, true)
	var building := await _factory()
	if building == null: return
	var p := building.production
	var occupants: Array[RTSUnit] = []
	for offset in ProductionField.SPAWN_OFFSETS:
		var actor := RTSUnit.new()
		actor.unit_id = 100 + occupants.size()
		actor.position = building.exit_position() + offset
		battle.add_child(actor)
		battle.register_unit(actor)
		occupants.append(actor)
	await _frames(3)
	var first := p.enqueue(1, ROCKET_RECIPE)
	var second := p.enqueue(1, ROCKET_RECIPE)
	var completed: Array[int] = []
	p.deployed.connect(func(job: int, _unit: int, _rally: bool) -> void: completed.append(job))
	await _frames(479)
	_check(completed.is_empty() and p.progress() < 1, "479 physics ticks cannot complete eight-second Rocket training")
	await _frames(61)
	battle.selection.select_building(building)
	_check(p.count() == 2 and p.progress() == 1 and p.jobs()[1]["elapsed"] == 0 and completed.is_empty() and battle.production_panel.feedback.text.contains("Exit blocked"), "occupied exit holds paid completed Rocket and later FIFO job with visible Exit blocked")
	var waiting: Array[int] = []
	for i in 3: waiting.append(p.enqueue(1, ROCKET_RECIPE).job_id)
	_check(p.count() == 5 and not p.enqueue(1, ROCKET_RECIPE).accepted and battle.production_panel.feedback.text.contains("Queue full"), "completed blocked Rocket counts toward the five-slot factory capacity")
	for identity in waiting: p.cancel(1, identity)
	var balance := battle.credits.balance(1)
	var version := battle.units[0].order_version
	await _click(_world_screen(Vector3(-5, 0, 5)), MOUSE_BUTTON_RIGHT)
	_check(p.has_rally and p.rally_point.distance_to(Vector3(-5, 0, 5)) < 0.02, "viewport right-click changes factory rally while completed Rocket waits for exit")
	var chosen_rally := p.rally_point
	var observation := {"registered": false, "clear": false, "shape": false}
	p.deployed.connect(func(_job: int, identity: int, _rally: bool) -> void:
		var unit := _last_unit(p)
		observation["registered"] = unit != null and unit.unit_id == identity and unit.visible and battle.contains_unit(unit)
		var collider := unit.get_child(0) as CollisionShape3D
		var shape := collider.shape as CapsuleShape3D
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = shape
		query.transform = collider.global_transform
		query.exclude = [unit.get_rid()]
		query.collision_mask = 2 | 4 | 8
		observation["clear"] = battle.get_world_3d().direct_space_state.intersect_shape(query).is_empty() and battle._nav_point(unit.position)
		observation["shape"] = shape.radius == (battle._spawn_query.shape as CapsuleShape3D).radius and shape.height == (battle._spawn_query.shape as CapsuleShape3D).height)
	occupants[0].queue_free()
	if not await _until(func() -> bool: return completed.size() == 1, 1, "clearing one occupied slot deploys original completed Rocket on bounded retry"): return
	var unit := _last_unit(p)
	_check(completed == [first.job_id] and p.count() == 1 and observation.values().all(func(value: bool) -> bool: return value) and battle.credits.balance(1) == balance, "deployment is once, registered before exposure, actual-capsule clear and costs no additional credits")
	_check(unit.maximum_health == 150 and unit.combat.weapon.definition == CombatField.ROCKET and unit.movement_speed == 5 and unit.collision_layer == 2 and unit.collision_mask == 4 and unit.agent != null, "produced Rocket retains ordinary combat, movement, collision and navigation configuration")
	_check(p.last_deployment["rally"] == chosen_rally and p.last_deployment["rally_accepted"] and battle.selection.selected_building() == building and battle.units[0].order_version == version, "deployment uses current rally and preserves selection and existing unit orders")
	var vehicle_order := unit.order_version
	_check(p.set_rally(1, Vector3(-3, 0, 6)).accepted and unit.order_version == vehicle_order, "new rally does not rewrite deployed Rocket's order")
	p.cancel(1, second.job_id)
	for i in range(1, occupants.size()): occupants[i].queue_free()
	if not await _until(func() -> bool: return unit.movement_state == RTSUnit.MovementState.ARRIVED, 8, "produced Rocket reaches ordinary rally"): return
	battle.selection.select_clicked(unit, false)
	_check(_complete(battle.issue_move(Vector3(-20, 0, 3))), "Rocket accepts group Move to opposite side of its factory")
	if not await _until(func() -> bool: return unit.movement_state == RTSUnit.MovementState.ARRIVED, 15, "Rocket follows actual navigation around factory footprint"): return
	_check(battle.issue_move(Vector3(-20, 0, 17)).has_acceptance(), "Rocket accepts replacement Move")
	_key_x()
	await _frames(3)
	_check(not unit.moving and unit.combat.player_command == CombatController.PlayerCommand.STOP, "viewport X stops normal produced Rocket movement")
	(battle as RefusingAssault).reject_rally = true
	var rejected := await _train_vehicle(building)
	if rejected == null: return
	_check(not rejected.moving and not p.last_deployment["rally_accepted"] and p.message.contains("rally rejected") and p.count() == 0, "rejected normal rally leaves a paid idle Rocket, no refund or redeployment")
	var count := battle.units.size()
	await _frames(40)
	_check(battle.units.size() == count and completed.size() == 2, "completion callbacks/retries cannot duplicate committed deployment")
	# World volume on valid nav must reject the entire local exit, without projection.
	var wall := _vehicle_wall(Vector3(3.5, 0.3, 4), building.exit_position() + Vector3(0.5, 0.15, 0))
	await _frames(3)
	await physics_frame
	_check(battle.find_spawn(building).is_empty(), "full produced capsule rejects low world geometry on otherwise usable exit navigation")
	wall.queue_free()
	var original := building.position
	building.position = battle.headquarters.position - Vector3(4.3, 0, 0)
	await physics_frame
	_check(battle.find_spawn(building).is_empty(), "factory exit inside HQ hole cannot project through that footprint")
	building.position = original


func _vehicle_weapons() -> void:
	await _fresh_combined(3000, 1000)
	var building := await _factory()
	if building == null: return
	var rocket := await _train_vehicle(building)
	if rocket == null: return
	# Isolated firing positions; actor itself was paid, trained and registered normally.
	rocket.stop()
	rocket.position = Vector3(11, 0, -9)
	var target := battle.enemy_headquarters
	var flights: Array[GuidedProjectile] = []
	rocket.combat.weapon.fired.connect(func(_target: Node3D, shot: GuidedProjectile) -> void: flights.append(shot))
	await _frames(3)
	battle.selection.select_clicked(rocket, false)
	await _click(_world_screen(target.position + Vector3.UP), MOUSE_BUTTON_RIGHT)
	if not await _until(func() -> bool: return not flights.is_empty(), 3, "viewport Attack launches a real produced vehicle projectile"): return
	rocket.stop()
	_check(target.health.current == 1200 and flights[0].collision_radius == 0.1 and flights[0].lifetime == 6 and flights[0].speed == 9, "ordinary Rocket has delayed damage and unchanged captured spherical flight data")
	var impacts: Array[float] = []
	flights[0].resolved.connect(func(amount: float) -> void: impacts.append(amount))
	if not await _until(func() -> bool: return not impacts.is_empty(), 3, "produced vehicle projectile travels to hostile building"): return
	_check(impacts == [32.0] and target.health.current == 1168, "real delayed projectile resolves building damage exactly once after source Stop")
	await _until(func() -> bool: return rocket.combat.weapon.cooldown_remaining == 0, 2, "ordinary cooldown expires before interception fixture")
	rocket.combat.issue_attack(target)
	if not await _until(func() -> bool: return flights.size() == 2, 2, "second normal Rocket launches before world interception"): return
	rocket.stop()
	var intercepted: Array[float] = []
	flights[1].resolved.connect(func(amount: float) -> void: intercepted.append(amount))
	var wall := _vehicle_wall(Vector3(0.4, 2, 5), Vector3(15, 1, -11))
	if not await _until(func() -> bool: return not intercepted.is_empty(), 3, "produced vehicle's spherical flight meets intervening world geometry"): return
	_check(intercepted == [0.0] and target.health.current == 1168, "factory-produced Rocket respects world collision and cannot damage through intervening wall")
	wall.queue_free()
	await _frames(3)
	var enemy := battle.units[3]
	enemy.stop()
	enemy.combat.retaliation_enabled = false
	enemy.position = Vector3(19, 0, -8)
	rocket.position = Vector3(11, 0, -8)
	await _frames(3)
	rocket.combat.issue_attack(enemy)
	if not await _until(func() -> bool: return flights.size() == 3, 3, "produced Rocket launches against an ordinary hostile unit"): return
	rocket.stop()
	# In-flight shot and deployed actor are independent of producer destruction.
	var p := building.production
	_check(p.enqueue(1, ROCKET_RECIPE).accepted and p.enqueue(1, ROCKET_RECIPE).accepted, "factory holds two captured paid jobs before destruction")
	var balance := battle.credits.balance(1)
	battle.selection.select_building(building)
	var reentrant := {"calls": 0}
	p.changed.connect(func() -> void:
		reentrant["calls"] += 1
		p.close(true))
	await physics_frame
	_check(TeamRules.damage_target(battle, 2, building, 10000, enemy) == 450, "completed factory is damageable through ordinary hostile building authority")
	_check(battle.credits.balance(1) == balance + 500 and p.count() == 0 and reentrant["calls"] == 1 and not p.is_available() and battle.selection.selected_building() == null, "factory destruction refunds only undeployed payments once and prunes producer/UI selection")
	_check(battle.result == BaseAssaultField.Result.RUNNING and battle.contains_unit(rocket), "factory is not an HQ objective; its deployed Rocket survives")
	var panel := battle.production_panel
	panel._train()
	panel._cancel(p, 1)
	_check(battle.credits.balance(1) == balance + 500 and not p.enqueue(1, ROCKET_RECIPE).accepted, "stale destroyed factory UI/API cannot spend or refund again")
	if not await _until(func() -> bool: return enemy.combat.health.current == 68, 3, "independent in-flight Rocket damages hostile unit after producer destruction"): return
	if not await _until(func() -> bool: return not battle.construction.navigation.blocked, 6, "factory destruction completes ordinary navigation cleanup"): return
	await physics_frame
	_check(battle._nav_point(FIRST) and battle.fire_query.segment(battle.get_world_3d(), FIRST + Vector3(-4, 1, 0), FIRST + Vector3(4, 1, 0)).is_clear(), "destroyed factory removes both navigation footprint and weapon blocker")
	# Actual source death after launch must not cancel the independent shot.
	rocket.combat.issue_attack(enemy)
	if not await _until(func() -> bool: return flights.size() == 4, 3, "surviving deployed Rocket can fire after producer loss"): return
	var after_death: Array[float] = []
	flights[3].resolved.connect(func(amount: float) -> void: after_death.append(amount))
	rocket.combat.health.apply_damage(150, enemy)
	if not await _until(func() -> bool: return not after_death.is_empty(), 3, "fired shot outlives actual source death"): return
	_check(after_death == [32.0] and enemy.combat.health.current == 36, "source death leaves captured team/weapon and once-only damage intact")
	# A second normally produced vehicle tests target death and blocked-job refunds.
	building = await _factory()
	if building == null: return
	rocket = await _train_vehicle(building)
	if rocket == null: return
	rocket.stop()
	rocket.position = Vector3(11, 0, -8)
	var doomed: Array[GuidedProjectile] = []
	rocket.combat.weapon.fired.connect(func(_target: Node3D, shot: GuidedProjectile) -> void: doomed.append(shot))
	await _frames(3)
	rocket.combat.issue_attack(enemy)
	if not await _until(func() -> bool: return not doomed.is_empty(), 3, "target-death fixture uses another normally produced projectile"): return
	rocket.stop()
	var invalidated: Array[float] = []
	doomed[0].resolved.connect(func(amount: float) -> void: invalidated.append(amount))
	enemy.combat.health.apply_damage(100, rocket)
	if not await _until(func() -> bool: return not invalidated.is_empty(), 2, "target death invalidates its in-flight projectile without stale reference"): return
	_check(invalidated == [0.0], "dead target receives no duplicate projectile damage")
	wall = _vehicle_wall(Vector3(3.5, 2, 4), building.exit_position() + Vector3(0.5, 1, 0))
	building.production.enqueue(1, ROCKET_RECIPE)
	await _frames(500)
	_check(building.production.progress() == 1 and building.production.message == "Exit blocked", "destruction fixture has an actually completed blocked Rocket")
	balance = battle.credits.balance(1)
	await physics_frame
	TeamRules.damage_target(battle, 2, building, 10000, battle.units[3])
	_check(battle.credits.balance(1) == balance + 250, "destroyed factory refunds completed-but-blocked Rocket payment, never construction cost")


func _factory_results() -> void:
	for outcome in [BaseAssaultField.Result.VICTORY, BaseAssaultField.Result.DEFEAT, BaseAssaultField.Result.DRAW]:
		await _fresh_combined(3000, 1000)
		var factory := await _factory()
		if factory == null: return
		var vehicle := await _train_vehicle(factory)
		if vehicle == null: return
		vehicle.stop()
		vehicle.position = Vector3(11, 0, -9)
		var flights: Array[GuidedProjectile] = []
		vehicle.combat.weapon.fired.connect(func(_target: Node3D, shot: GuidedProjectile) -> void: flights.append(shot))
		await _frames(3)
		vehicle.combat.issue_attack(battle.enemy_headquarters)
		if not await _until(func() -> bool: return not flights.is_empty(), 3, "result fixture has an actual factory-produced Rocket in flight"): return
		var p := factory.production
		p.enqueue(1, ROCKET_RECIPE)
		var site := _site(await _place_factory(SECOND))
		if site == null: return
		await physics_frame
		if outcome in [BaseAssaultField.Result.DEFEAT, BaseAssaultField.Result.DRAW]:
			TeamRules.damage_target(battle, 2, battle.headquarters, 1200, battle.units[3])
		if outcome in [BaseAssaultField.Result.VICTORY, BaseAssaultField.Result.DRAW]:
			TeamRules.damage_target(battle, 1, battle.enemy_headquarters, 1200, vehicle)
		await _frames(2)
		_check(battle.result == outcome and battle.result_overlay.visible and not battle.gameplay_enabled, "HQ damage resolves expected result with factory work present: %s" % outcome)
		var paid := battle.credits.balance(1)
		var training: float = p.jobs()[0]["elapsed"]
		var construction_time := site.elapsed
		var position := vehicle.position
		var projectile := flights[0]
		var shot_age := projectile.age if is_instance_valid(projectile) else -1.0
		var count := battle.units.size()
		await _frames(600)
		_check(p.jobs()[0]["elapsed"] == training and site.elapsed == construction_time and battle.units.size() == count and battle.credits.balance(1) == paid and vehicle.position == position, "result freezes factory training/construction/deployment/economy/movement")
		_check(not is_instance_valid(projectile) or projectile.age == shot_age, "result freezes any surviving independent projectile")
		_check(not p.enqueue(1, ROCKET_RECIPE).accepted and not vehicle.move_to(Vector3.ZERO) and not battle.placement.begin(battle.headquarters, FACTORY), "terminal factory/movement/placement APIs reject late commands")
		var old_wallet := battle.credits
		var manager := battle.construction
		await _click(battle.restart_button.get_global_rect().get_center(), MOUSE_BUTTON_LEFT)
		await _frames(5)
		battle = current_scene as BaseAssaultField
		field = battle
		world = battle
		harvest = battle
		battle.camera_rig.edge_scrolling_enabled = false
		_check(battle.scene_file_path == "res://scenes/combined_arms_assault.tscn" and battle.vehicle_factory_definition == FACTORY and battle.result == BaseAssaultField.Result.RUNNING, "Restart retains combined-arms scene and its two build choices")
		_check(battle.units.size() == 8 and battle._producers.is_empty() and battle.construction.sites.is_empty() and battle._access_claims.is_empty() and get_nodes_in_group("combat_projectiles").is_empty() and not battle.placement.active, "Restart clears factories/jobs/sites/claims/preview/projectiles and restores initial force")
		_check(battle.credits.balance(1) == 1000 and battle.caches[0].remaining == 2000 and battle.headquarters.health.current == 1200 and battle.enemy_headquarters.health.current == 1200 and not battle.assault_issued and battle.elapsed < 1 and battle.assault_delay == 90, "Restart restores playable defaults, resources, full HQ health and original assault clock")
		manager.advance(100)
		p.advance(100)
		_check(not old_wallet.active and manager.closed and not p.is_available() and battle._producers.is_empty() and battle.credits.balance(1) == 1000, "retained old callbacks cannot spawn or spend into restarted match")
	await _capture("m7_restarted")


func _default_assault_timing() -> void:
	await _fresh_combined() # No scripted-assault timing override in this case.
	_check(battle.assault_delay == 90 and not battle.restart_match(), "playable combined scene retains ninety-second assault and rejects running Restart")
	await _frames(5300)
	_check(battle.elapsed < 90 and not battle.assault_issued and battle.assault_acceptances == 0, "no enemy dispatch before real default assault time")
	if not await _until(func() -> bool: return battle.assault_issued, 2, "unchanged scripted assault dispatches at ninety simulated seconds"): return
	_check(battle.assault_acceptances == 3 and battle.elapsed >= 90 and battle.elapsed < 90.1, "one default-timed assault gives the three original enemies normal HQ attacks")
	if not await _until(func() -> bool: return battle.result == BaseAssaultField.Result.DEFEAT, 50, "unaltered enemy force actually destroys undefended HQ"): return
	_check(battle.assault_acceptances == 3 and battle.result_label.text == "DEFEAT", "default assault is never redispatched and produces normal defeat")


func _combined_loop() -> void:
	# Explicit automated economy budget: zero starting credits, 600s assault delay,
	# <=240s earning, <=45s final combat. Playable scene remains 1000 credits/90s;
	# _default_assault_timing separately verifies that exact real script behavior.
	await _fresh_combined(0, 600)
	var earned := {"amount": 0}
	for truck in battle.collectors:
		truck.harvesting.transferred.connect(func(transfer: HarvestTransfer) -> void:
			if transfer.kind == HarvestTransfer.Kind.DEPOSIT: earned["amount"] += transfer.amount)
		battle.selection.select_clicked(truck, truck != battle.collectors[0])
	_check(_complete(battle.issue_harvest(battle.caches[0])), "zero-credit integrated match assigns both existing collectors to actual supplies")
	if not await _until(func() -> bool: return battle.credits.balance(1) >= 600, 70, "real travel/load/return/deposit earns factory construction funds from zero"): return
	_check(battle.credits.balance(1) == earned["amount"] and earned["amount"] >= 600, "every initial construction credit comes from real deposited supplies")
	var panel := battle.production_panel as ConstructionPanel
	battle.selection.select_building(battle.headquarters)
	await _click(panel.factory_button.get_global_rect().get_center(), MOUSE_BUTTON_LEFT)
	await _click(_world_screen(FIRST), MOUSE_BUTTON_LEFT)
	var factory_site := await _ready_site(battle.placement.last_result)
	if factory_site == null or not await _complete_site(factory_site): return
	var factory := factory_site.building()
	if not await _until(func() -> bool: return battle.credits.balance(1) >= 400, 50, "collectors earn barracks cost through same wallet during factory construction"): return
	var barrack_site := await _ready_site(await _place(SECOND))
	if barrack_site == null or not await _complete_site(barrack_site): return
	var barrack := barrack_site.building()
	var army: Array[RTSUnit] = []
	var spent := 1000
	for index in 6:
		var producer_building := barrack if index < 4 else factory
		var price := producer_building.recipe.credit_cost
		if not await _until(func() -> bool: return battle.credits.balance(1) >= price, 35, "harvesting earns next combined-arms purchase %d" % (index + 1)): return
		var p := producer_building.production
		var rally := Vector3(-5 + (index % 3) * 1.5, 0, 2 + (index / 3) * 2)
		_check(p.set_rally(1, rally).accepted, "earned unit has an ordinary clear rally")
		battle.selection.select_building(producer_building)
		_check(panel.train_button.text.contains(producer_building.recipe.display_name) and not panel.factory_button.visible and not panel.build_button.visible, "switching producer updates contextual recipe controls")
		var funds := battle.credits.balance(1)
		await _click(panel.train_button.get_global_rect().get_center(), MOUSE_BUTTON_LEFT)
		spent += price
		_check(p.count() == 1 and battle.credits.balance(1) == earned["amount"] - spent and battle.credits.balance(1) <= funds, "viewport Train enqueues once using exclusively earned shared-wallet credits")
		if not await _until(func() -> bool: return p.count() == 0, 9, "earned unit actually trains and deploys"): return
		var unit := _last_unit(p)
		if unit == null:
			_check(false, "earned deployment remains registered")
			return
		army.append(unit)
	for truck in battle.collectors: truck.stop()
	_check(army.size() == 6 and spent == 1900 and battle.credits.balance(1) == earned["amount"] - 1900 and battle.caches[0].remaining < 2000 and battle.elapsed < 240, "zero-credit loop constructs both buildings and produces four Rifles/two Rockets solely from conserved earned funds within documented budget")
	for index in army.size(): battle.selection.select_clicked(army[index], index > 0)
	_check(not panel.train_button.visible and not panel.factory_button.visible and battle.selection.selected_building() == null, "unit selection removes all contextual building actions")
	_check(_complete(battle.issue_move(Vector3(12, 0, -5))), "all normally produced Rifles and Rockets accept staging Move")
	if not await _until(func() -> bool: return army.all(func(unit: RTSUnit) -> bool: return is_instance_valid(unit) and unit.movement_state == RTSUnit.MovementState.ARRIVED), 25, "actual combined force traverses map through existing navigation"): return
	var damage := {"rifle": 0.0, "rocket": 0.0}
	battle.enemy_headquarters.health.damaged.connect(func(amount: float, source: Node) -> void:
		if source is RTSUnit and army.has(source):
			damage["rocket" if source.combat_weapon == CombatField.ROCKET else "rifle"] += amount)
	await _capture("m7_combined_army")
	_check(_complete(battle.issue_attack(battle.enemy_headquarters)), "earned combined force attacks enemy HQ through normal command batch")
	if not await _until(func() -> bool: return battle.result != BaseAssaultField.Result.RUNNING, 45, "earned combined force destroys full-health enemy HQ by real hitscan/projectile damage"): return
	_check(battle.result == BaseAssaultField.Result.VICTORY and battle.result_overlay.visible and battle.result_label.text == "VICTORY" and damage["rifle"] > 0 and damage["rocket"] > 0, "both produced types inflict real HQ damage and integrated match displays victory")
	print("COMBINED_LOOP: elapsed=%.3f earned=%d spent=%d rifle_damage=%.1f rocket_damage=%.1f" % [battle.elapsed, earned["amount"], spent, damage["rifle"], damage["rocket"]])
	await _capture("m7_victory")
	await _click(battle.restart_button.get_global_rect().get_center(), MOUSE_BUTTON_LEFT)
	await _frames(5)
	battle = current_scene as BaseAssaultField
	field = battle
	world = battle
	harvest = battle
	battle.camera_rig.edge_scrolling_enabled = false
	_check(battle.scene_file_path == "res://scenes/combined_arms_assault.tscn" and battle.result == BaseAssaultField.Result.RUNNING and battle.credits.balance(1) == 1000 and battle._producers.is_empty() and battle.construction.sites.is_empty() and battle.units.size() == 8 and battle.caches.all(func(cache: SupplyCache) -> bool: return cache.remaining == 2000), "earned victory restarts actual combined scene with clean playable initial match")
