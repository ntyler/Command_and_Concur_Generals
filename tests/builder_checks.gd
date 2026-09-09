extends "res://tests/supply_depot_checks.gd"
## M12 focused fixtures use real physics/navigation and normal paid production.
## Isolated fixtures freeze the enemy scheduler, configure extra starting funds,
## and insert labelled physical blockers; earned gameplay is a separate suite.
## The inherited wall watchdog and tools/run-godot.ps1 bound every engine run.

const BUILDER_RECIPE: ProductionDefinition = preload("res://production/bulldozer.tres")
const BUILDER_PARK := Vector3(-19, 0, 17)
var builders: BuilderAssaultField


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1280, 720)
	var logger := EngineErrorProbe.new()
	OS.add_logger(logger)
	var chosen := "all"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--builder-case="):
			chosen = argument.trim_prefix("--builder-case=")
	var cases := ["production", "placement", "work", "replacement", "claims", "callbacks", "lifecycle", "blocked", "ui", "freeze"]
	_check(chosen == "all" or cases.has(chosen), "recognized builder case")
	for case in cases:
		if chosen != "all" and chosen != case: continue
		var before := checks
		var failed := failures
		match case:
			"production": await _builder_production()
			"placement": await _builder_placement()
			"work": await _builder_work()
			"replacement": await _builder_replacement()
			"claims": await _builder_claims()
			"callbacks": await _builder_callbacks()
			"lifecycle": await _builder_lifecycle()
			"blocked": await _builder_blocked()
			"ui": await _builder_ui()
			"freeze": await _builder_freeze()
		print("BUILDER_CASE: %s checks=%d failures=%d" % [case, checks - before, failures - failed])
	if is_instance_valid(field): field.queue_free()
	await _frames(6)
	_check(root.get_children().is_empty() and get_nodes_in_group("combat_projectiles").is_empty(), "builder teardown removes field, claims, queues, listeners and controls")
	OS.remove_logger(logger)
	_check(logger.error_count() == 0, "builder physics, callbacks and teardown have no native errors or warnings")
	print("BUILDER_CHECKS: %d checks, %d failures; native_errors=%d" % [checks, failures, logger.error_count()])
	quit(0 if failures == 0 else 1)


func _fresh_builder(funds: int = 2000, live_enemy: bool = false) -> void:
	if is_instance_valid(field):
		field.queue_free()
		await _frames(5)
	builders = load("res://scenes/builder_assault.tscn").instantiate() as BuilderAssaultField
	builders.starting_credits = funds
	if live_enemy:
		# Same bounded first-wave isolation as the M11 earned integration; enemy
		# harvesting, queues and repeat-wave configuration continue unchanged.
		builders.enemy_config = builders.enemy_config.duplicate(true) as EnemyEconomyConfig
		builders.enemy_config.first_wave_time = 600.0
	battle = builders
	world = builders
	harvest = builders
	field = builders
	root.add_child(builders)
	current_scene = builders
	builders.camera_rig.edge_scrolling_enabled = false
	if not live_enemy:
		builders.enemy_controller.set_physics_process(false)
		for actor in builders.units:
			if actor.owner_id == 2:
				actor.stop()
				actor.set_physics_process(false)
	await _until(_builder_navigation_current, 2, "builder scene owns its actual actor navigation starts")
	_check(builders.builder_construction_enabled and builders.credits.balance(1) == funds and builders.construction.sites.is_empty(), "fresh builder scenario has configured wallet and no old sites")
	_check(_player_builders().size() == 1 and builders.collectors.filter(func(actor: CollectorTruck) -> bool: return actor.owner_id == 1).is_empty(), "normal opening has exactly one player Bulldozer and no player collectors")
	_check(builders.units.filter(func(actor: RTSUnit) -> bool: return actor.owner_id == 1 and not actor is Bulldozer).size() == 3 and builders.registered_buildings().filter(func(body: RTSBuilding) -> bool: return body.owner_id == 1 and body.kind != RTSBuilding.Kind.HEADQUARTERS).is_empty(), "normal opening retains three combat actors and no player production buildings")
	_check(builders.collectors.filter(func(actor: CollectorTruck) -> bool: return actor.owner_id == 2).size() == 2 and builders.enemy_config.starting_credits == 300 and builders.enemy_config.wave_interval == 60, "builder composition preserves enemy collectors and economy configuration")


func _builder_navigation_current() -> bool:
	var map := builders.get_world_3d().get_navigation_map()
	if NavigationServer3D.map_get_iteration_id(map) == 0: return false
	for actor in builders.units:
		if NavigationServer3D.map_get_closest_point_owner(map, actor.global_position) != builders.navigation_region.get_rid(): return false
	return true


func _player_builders() -> Array[Bulldozer]:
	var result: Array[Bulldozer] = []
	for actor in builders.units:
		if actor is Bulldozer and actor.owner_id == 1 and builders.contains_unit(actor): result.append(actor)
	return result


func _builder_place(actor: Bulldozer, definition: ConstructionDefinition = DEPOT, point: Vector3 = DEPOT_POINT) -> ConstructionResult:
	builders.selection.select_clicked(actor, false)
	await physics_frame
	return builders.construction.place(1, actor, definition, point)


func _builder_arrival(result: ConstructionResult) -> ConstructionSite:
	_check(result.accepted, "selected builder placement accepted: " + result.reason)
	var site := _site(result)
	if site == null: return null
	if not await _until(func() -> bool: return site.state == ConstructionSite.State.CONSTRUCTING, 30, "assigned builder physically reaches a usable site work position"):
		_print_builder_site(site, "arrival")
		return null
	var actor := site.builder()
	await physics_frame
	_check(actor != null and actor.assigned_site_id == site.site_id and builders.builder_can_work(actor, site) and not site.work_access.is_empty(), "actual construction starts with a registered assigned builder at physically usable access")
	return site


func _builder_complete(site: ConstructionSite) -> bool:
	if site == null: return false
	if not await _until(func() -> bool: return site.state == ConstructionSite.State.OPERATIONAL, site.duration + 1, "present builder completes the remaining real simulated construction duration"):
		_print_builder_site(site, "completion")
		return false
	return true


func _print_builder_site(site: ConstructionSite, phase: String) -> void:
	var actor := site.builder()
	print("BUILDER_DIAGNOSTIC: phase=%s id=%d state=%d elapsed=%.6f reason=%s access=%s actor=%s movement=%s" % [phase, site.site_id, site.state, site.elapsed, site.reason, site.work_access, actor.global_position if actor != null else "missing", actor.movement_state if actor != null else -1])


func _paid_builder() -> Bulldozer:
	var producer := builders.headquarters.production
	var count := _player_builders().size()
	var balance := builders.credits.balance(1)
	var result := producer.enqueue(1, BUILDER_RECIPE)
	_check(result.accepted and builders.credits.balance(1) == balance - 500, "HQ queue captures and deducts the ordinary 500-credit Bulldozer payment")
	if not result.accepted: return null
	if not await _until(func() -> bool: return _player_builders().size() == count + 1, 9, "normal HQ queue trains and physically deploys the paid Bulldozer"):
		return null
	var actor := _last_unit(producer) as Bulldozer
	_check(actor != null and builders.contains_unit(actor) and actor.owner_id == 1 and actor.assigned_site_id == 0, "paid deployment is registered with a stable ID and no inherited construction assignment")
	return actor


func _builder_capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://validation-output/m12/screenshots")
	var picture := root.get_texture().get_image()
	_check(picture.save_png("res://validation-output/m12/screenshots/%s.png" % label) == OK and picture.get_size() == root.size, "saved actual M12 viewport " + label)


func _builder_production() -> void:
	await _fresh_builder(2500)
	var actor := _player_builders()[0]
	var producer := builders.headquarters.production
	_check(BUILDER_RECIPE.is_valid() and BUILDER_RECIPE.credit_cost == 500 and BUILDER_RECIPE.training_duration == 6, "Bulldozer recipe preserves configurable 500-credit/six-second defaults")
	_check(actor.maximum_health == 200 and actor.combat.health.current == 200 and actor.movement_speed == 3.5 and actor.combat.weapon == null and not actor.retaliation_enabled, "Bulldozer is modestly durable, unarmed and uses documented 200-health/3.5-speed configuration")
	_check(not (actor as RTSUnit) is CollectorTruck and builders.collectors.all(func(truck: CollectorTruck) -> bool: return truck.get_instance_id() != actor.get_instance_id()) and not builders.can_attack_move(actor) and not TeamRules.can_attack(builders, actor, builders.units[3]), "builder has neither collector nor offensive capabilities")
	builders.selection.select_clicked(actor, false)
	await physics_frame
	_check(not builders.issue_harvest(_depot_player_cache()).has_acceptance(), "selected Bulldozer cannot receive harvesting work")
	var balance := builders.credits.balance(1)
	_check(not producer.enqueue(2, BUILDER_RECIPE).accepted and not producer.enqueue(1, COLLECTOR_RECIPE).accepted and not producer.enqueue(1, ROCKET_RECIPE).accepted and builders.credits.balance(1) == balance, "HQ rejects enemy requests, collectors and combat recipes without spending")
	var cancelled := producer.enqueue(1, BUILDER_RECIPE)
	_check(cancelled.accepted and producer.cancel(1, cancelled.job_id).accepted and not producer.cancel(1, cancelled.job_id).accepted and builders.credits.balance(1) == balance, "normal HQ cancellation refunds original Bulldozer payment exactly once")
	var occupants: Array[RTSUnit] = []
	for offset in ProductionField.SPAWN_OFFSETS:
		var occupant := RTSUnit.new()
		occupant.unit_id = 100 + occupants.size()
		occupant.position = builders.headquarters.exit_position() + offset
		builders.add_child(occupant)
		builders.register_unit(occupant)
		occupants.append(occupant)
	await _frames(3)
	var paid := producer.enqueue(1, BUILDER_RECIPE)
	var deployments: Array[int] = []
	producer.deployed.connect(func(job: int, _identity: int, _rally: bool) -> void: deployments.append(job))
	await _frames(359)
	_check(deployments.is_empty() and producer.progress() < 1, "Bulldozer cannot deploy before six actual simulated training seconds")
	await _frames(40)
	_check(producer.progress() == 1 and producer.count() == 1 and deployments.is_empty(), "physically occupied HQ exits retain one paid completed builder job")
	_check(producer.set_rally(1, Vector3(-5, 0, 3)).accepted, "HQ accepts normal navigable ground rally for its builder")
	for occupant in occupants: occupant.queue_free()
	if not await _until(func() -> bool: return deployments.size() == 1, 2, "clearing actual HQ exit deploys the completed Bulldozer once"): return
	var produced := _last_unit(producer) as Bulldozer
	_check(produced != null and produced != actor and builders.contains_unit(produced) and produced.unit_id != actor.unit_id and produced.assigned_site_id == 0 and deployments == [paid.job_id] and producer.count() == 0, "paid queue deploys one ordinary registered independent builder")
	if produced == null: return
	_check(produced.combat.health.current == 200 and not (produced as RTSUnit) is CollectorTruck and not producer.cancel(1, paid.job_id).accepted, "deployed builder has ordinary health and completed job cannot refund")
	await _until(func() -> bool: return not produced.moving, 18, "produced Bulldozer follows normal ground-rally movement")
	_check(produced.movement_state == RTSUnit.MovementState.ARRIVED and produced.position.distance_to(producer.rally_point) < 0.4 and produced.assigned_site_id == 0, "Bulldozer physically reaches HQ rally without starting unsolicited work")
	await physics_frame
	_check(TeamRules.damage_target(builders, 2, produced, 25, builders.units[3]) and produced.combat.health.current == 175 and produced.combat.target_actor() == null, "normally produced builder is damageable and does not retaliate")


func _builder_placement() -> void:
	await _fresh_builder()
	var actor := _player_builders()[0]
	var manager := builders.construction
	var balance := builders.credits.balance(1)
	await physics_frame
	_check(not manager.place(1, builders.headquarters, DEPOT, DEPOT_POINT).accepted, "builder-enabled HQ cannot directly authorize construction")
	builders.selection.select_clicked(builders.units[0], false)
	_check(not manager.place(1, actor, DEPOT, DEPOT_POINT).accepted, "unselected owned builder cannot authorize construction")
	builders.selection.select_clicked(actor, true)
	_check(not manager.place(1, actor, DEPOT, DEPOT_POINT).accepted, "mixed selection cannot silently choose a builder")
	builders.selection.select_clicked(actor, false)
	_check(not manager.place(2, actor, DEPOT, DEPOT_POINT).accepted, "wrong-owner builder placement rejects at the authority boundary")
	_check(not manager.place(1, actor, DEPOT, actor.global_position).accepted and builders.credits.balance(1) == balance, "site cannot enclose the builder in its new footprint and every refusal spends nothing")
	_check(_complete(builders.issue_move(BUILDER_PARK)), "builder accepts ordinary prior movement for preview preservation fixture")
	var order := actor.order_version
	var destination := actor.assigned_destination
	_check(builders.placement.begin(actor, DEPOT), "exactly selected eligible builder can enter normal placement preview")
	_check(actor.order_version == order and actor.assigned_destination == destination and actor.moving, "entering preview preserves the builder's earlier valid order")
	await physics_frame
	var invalid := manager.place(1, actor, DEPOT, Vector3(1000, 0, 1000))
	_check(not invalid.accepted and manager.sites.is_empty() and builders.credits.balance(1) == balance and actor.order_version == order and actor.assigned_destination == destination, "invalid placement spends nothing and preserves current order")
	await _hud_key(KEY_ESCAPE)
	_check(not builders.placement.active and actor.order_version == order and actor.assigned_destination == destination, "Escape preview cancellation preserves the accepted earlier order")
	_check(builders.placement.begin(actor, DEPOT), "builder may re-enter the same preview without replacing movement")
	await _click(_world_screen(DEPOT_POINT), MOUSE_BUTTON_RIGHT)
	_check(not builders.placement.active and actor.order_version == order, "right-click preview cancellation does not replace the earlier order")
	var result := await _builder_place(actor)
	var site := _site(result)
	_check(result.accepted and site != null and result.paid == 300 and site.paid == 300 and builders.credits.balance(1) == balance - 300 and manager.sites.size() == 1, "accepted placement commits exactly one stable paid site")
	if site == null: return
	_check(site.builder() == actor and actor.assigned_site_id == site.site_id and site.elapsed == 0 and site.state == ConstructionSite.State.PREPARING, "accepted placement assigns selected builder but accrues no pre-navigation progress")
	await _until(func() -> bool: return site.state == ConstructionSite.State.TRAVELLING, 6, "ready map dispatches final builder work approach")
	_check(actor.order_version > order and actor.assigned_destination != destination and not site.work_access.is_empty(), "valid committed placement replaces the prior command only with a real work approach")
	actor.stop()
	await _frames(3)
	await physics_frame
	_check(site.state == ConstructionSite.State.PAUSED and manager.unfinished_id == site.site_id and not manager.place(1, actor, FACTORY, SECOND).accepted, "paused unfinished site still consumes the existing concurrency slot")
	await _cleanup_site(site)
	_check(actor.assigned_site_id == 0 and not actor.moving and builders.credits.balance(1) == balance and not manager.cancel(1, site.site_id).accepted, "site cancellation clears obsolete work and refunds captured construction cost once")


func _builder_work() -> void:
	await _fresh_builder()
	var actor := _player_builders()[0]
	var result := await _builder_place(actor, builders.construction_definition, FIRST)
	var site := _site(result)
	if site == null:
		_check(false, "builder work fixture accepted normal Barracks placement: " + result.reason)
		return
	await _until(func() -> bool: return site.state == ConstructionSite.State.TRAVELLING, 6, "site enters explicit builder travelling state")
	var observed_travel := 0
	var no_travel_time := true
	for tick in 1800:
		if site.state == ConstructionSite.State.CONSTRUCTING: break
		if site.state == ConstructionSite.State.TRAVELLING:
			observed_travel += 1
			no_travel_time = no_travel_time and site.elapsed == 0 and not site.building().operational
		await _frames(1)
	_check(observed_travel >= 2 and no_travel_time and site.state == ConstructionSite.State.CONSTRUCTING, "multiple actual travelling ticks accrue zero time and physical arrival starts construction")
	if site.state != ConstructionSite.State.CONSTRUCTING:
		_print_builder_site(site, "travel gate")
		return
	await physics_frame
	_check(builders.builder_can_work(actor, site), "progress eligibility includes actual reachable clear work access")
	await _frames(90)
	var elapsed := site.elapsed
	var balance := builders.credits.balance(1)
	_check(elapsed > 1.3 and elapsed < site.duration and not site.building().operational, "present builder accumulates ordinary fixed-step progress without early production activation")
	builders.selection.select_clicked(actor, false)
	await physics_frame
	_check(_complete(builders.issue_move(BUILDER_PARK)), "ordinary ground Move redirects the working builder")
	await _frames(90)
	_check(site.state == ConstructionSite.State.PAUSED and site.builder() == null and actor.assigned_site_id == 0 and site.elapsed == elapsed and builders.credits.balance(1) == balance and site.cancellable(), "Move pauses and releases the builder without reset, cancellation or refund")
	await physics_frame
	_check(builders.construction.assign_builder(actor, site.site_id), "one selected builder may resume its unclaimed unfinished site")
	if not await _until(func() -> bool: return site.state == ConstructionSite.State.CONSTRUCTING, 30, "redirected builder navigates back normally before resuming"): return
	await _frames(60)
	elapsed = site.elapsed
	await _hud_key(KEY_X)
	var stopped_elapsed := site.elapsed
	await _frames(90)
	_check(stopped_elapsed >= elapsed and site.elapsed == stopped_elapsed and site.state == ConstructionSite.State.PAUSED and site.builder() == null and actor.assigned_site_id == 0 and not actor.moving and builders.credits.balance(1) == balance, "viewport X Stop pauses construction without refunding or clearing accumulated progress")
	await physics_frame
	_check(builders.construction.assign_builder(actor, site.site_id), "stopped builder remains responsive to ordinary resumption")
	if not await _until(func() -> bool: return site.state == ConstructionSite.State.CONSTRUCTING, 30, "stopped builder actually regains valid access"): return
	if not await _builder_complete(site): return
	var building := site.building()
	_check(building.operational and building.production.is_available() and actor.assigned_site_id == 0 and site.builder() == null and not actor.moving and builders.construction.unfinished_id == 0, "completion activates normal producer once and leaves builder idle with no assignment")
	_check(building.production.enqueue(1, building.recipe).accepted and building.production.count() == 1, "normally builder-completed Barracks accepts ordinary paid combat production")
	await physics_frame
	_check(not builders.construction.assign_builder(actor, site.site_id), "completed structures cannot be resumed or repaired")


func _builder_replacement() -> void:
	await _fresh_builder(1000)
	var original := _player_builders()[0]
	var site := await _builder_arrival(await _builder_place(original))
	if site == null: return
	await _frames(90)
	var paid := site.paid
	var identity := site.site_id
	var progress := site.elapsed
	var balance := builders.credits.balance(1)
	await physics_frame
	_check(TeamRules.damage_target(builders, 2, original, 10000, builders.units[3]), "replacement fixture destroys the original builder through normal health/damage")
	await _frames(90)
	_check(site.state == ConstructionSite.State.PAUSED and site.elapsed == progress and site.builder() == null and builders.credits.balance(1) == balance and _player_builders().is_empty(), "builder death preserves one paid paused site and accumulated progress without refund")
	var replacement := await _paid_builder()
	if replacement == null: return
	builders.selection.select_clicked(replacement, false)
	await physics_frame
	_check(builders.construction.assign_builder(replacement, identity), "normally paid HQ replacement claims the same surviving site")
	_check(site.site_id == identity and site.paid == paid and site.elapsed == progress and builders.credits.balance(1) == 200, "replacement costs exactly 500 while preserving site identity/payment/progress from normal1000 opening")
	if not await _until(func() -> bool: return site.state == ConstructionSite.State.CONSTRUCTING, 30, "replacement navigates to actual usable access before resumed work"): return
	if not await _builder_complete(site): return
	_check(site.building().operational and replacement.assigned_site_id == 0 and not replacement.moving and builders.credits.balance(1) == 200, "replacement completes remaining duration without repayment or unsolicited follow-up work")


func _builder_claims() -> void:
	await _fresh_builder()
	var first := _player_builders()[0]
	var second := await _paid_builder()
	if second == null: return
	builders.selection.select_clicked(first, false)
	builders.selection.select_clicked(second, true)
	await physics_frame
	_check(not builders.construction.place(1, first, DEPOT, DEPOT_POINT).accepted, "two selected builders cannot silently authorize placement")
	var site := await _builder_arrival(await _builder_place(first))
	if site == null: return
	builders.selection.select_clicked(second, false)
	await physics_frame
	_check(not builders.construction.assign_builder(second, site.site_id) and site.builder() == first and second.assigned_site_id == 0, "second builder cannot steal or concurrently accelerate another valid builder's site")
	first.stop()
	var elapsed := site.elapsed
	var balance := builders.credits.balance(1)
	await _frames(30)
	await physics_frame
	_check(builders.construction.assign_builder(second, site.site_id) and site.builder() == second and first.assigned_site_id == 0 and site.elapsed == elapsed, "selected second builder resumes preserved progress only after original releases the claim")
	second.stop()
	second.owner_id = 2
	await physics_frame
	_check(not builders.construction.assign_builder(second, site.site_id) and not builders.construction.place(1, second, DEPOT, SECOND).accepted, "enemy-owned builder cannot resume or place for the player")
	second.owner_id = 1
	builders.selection.select_clicked(second, false)
	await physics_frame
	_check(builders.construction.assign_builder(second, site.site_id) and builders.credits.balance(1) == balance, "reassignment never charges for an already paid site")
	await _cleanup_site(site)
	_check(first.assigned_site_id == 0 and second.assigned_site_id == 0 and not second.moving, "cancellation clears the currently assigned second builder without touching unrelated first builder")


func _builder_callbacks() -> void:
	await _fresh_builder()
	var original := _player_builders()[0]
	var entered := {"acted": false, "order": -1}
	builders.child_entered_tree.connect(func(child: Node) -> void:
		if not child is ConstructionBuilding or entered.acted: return
		entered.acted = original.move_to(BUILDER_PARK)
		entered.order = original.order_version
	)
	var callback_result := await _builder_place(original)
	var callback_site := _site(callback_result)
	_check(callback_result.accepted and entered.acted and callback_site != null, "site child-entered callback can accept a replacement builder Move during placement")
	if callback_site != null:
		await _until(func() -> bool: return not builders.construction.navigation.blocked, 6, "callback-replaced site finishes its committed navigation preparation")
		_check(callback_site.state == ConstructionSite.State.PAUSED and callback_site.builder() == null and original.assigned_site_id == 0 and original.order_version == entered.order and original.assigned_destination == BUILDER_PARK and builders.credits.balance(1) == 1700, "placement callback replacement order survives and leaves one paid site needing a builder")
	for mode in ["cancel", "free_site"]:
		await _fresh_builder()
		var actor := _player_builders()[0]
		var manager := builders.construction
		var wallet := builders.credits
		var observation := {"acted": false, "site": null, "generation": 0}
		manager.changed.connect(func(identity: int) -> void:
			var site := manager.sites.get(identity) as ConstructionSite
			if observation.acted or site == null or site.state != ConstructionSite.State.PREPARING: return
			observation.acted = true
			observation.site = site
			observation.generation = site.nav_generation
			if mode == "cancel": manager.cancel(1, identity)
			else: site.building().free()
		)
		var result := await _builder_place(actor)
		await _frames(10)
		var site := observation.site as ConstructionSite
		_check(result.accepted and observation.acted and site != null, "accepted placement supports synchronous %s callback after coherent commit" % mode)
		if site == null: continue
		await _until(func() -> bool: return manager.unfinished_id == 0 and not manager.navigation.blocked, 6, "callback cancellation/removal drains navigation cleanup")
		manager._navigation_ready(observation.generation)
		await _frames(60)
		_check(site.state == ConstructionSite.State.CANCELLED and site.elapsed == 0 and actor.assigned_site_id == 0 and not actor.moving and wallet.balance(1) == 2000 and manager.sites.is_empty(), "late navigation cannot resurrect callback-abandoned site or replay its refund")
	for mode in ["move", "cancel", "free_site"]:
		await _fresh_builder()
		var actor := _player_builders()[0]
		var site := await _builder_arrival(await _builder_place(actor))
		if site == null: continue
		var manager := builders.construction
		var observation := {"count": 0, "accepted": false, "order": -1}
		manager.changed.connect(func(identity: int) -> void:
			if identity != site.site_id or site.state != ConstructionSite.State.OPERATIONAL: return
			observation.count += 1
			if observation.count != 1: return
			if mode == "move":
				builders.selection.select_clicked(actor, false)
				observation.accepted = _complete(builders.issue_move(BUILDER_PARK))
				observation.order = actor.order_version
			elif mode == "cancel": observation.accepted = manager.cancel(1, identity).accepted
			else:
				site.building().free()
				observation.accepted = true
		)
		if not await _builder_complete(site): continue
		await _frames(60)
		_check(observation.count == 1 and actor.assigned_site_id == 0 and site.builder() == null and builders.credits.balance(1) == 1700, "completion %s callback crosses exactly one nonrefundable boundary" % mode)
		if mode == "move": _check(observation.accepted and actor.order_version == observation.order and actor.assigned_destination.distance_to(BUILDER_PARK) < 0.5, "synchronous completion listener's replacement Move survives outer cleanup")
		elif mode == "cancel": _check(not observation.accepted and site.building().operational, "completion callback cannot cancel or refund a completed site")
		else: _check(observation.accepted and not is_instance_valid(site.building()) and not manager.sites.has(site.site_id), "synchronous completed-building removal cannot recreate producer or site")


func _builder_lifecycle() -> void:
	for mode in ["free", "queue_free", "detach", "owner", "reparent"]:
		await _fresh_builder()
		var actor := _player_builders()[0]
		var site := await _builder_arrival(await _builder_place(actor))
		if site == null: continue
		await _frames(30)
		var elapsed := site.elapsed
		var balance := builders.credits.balance(1)
		var identity := actor.unit_id
		match mode:
			"free": actor.free()
			"queue_free": actor.queue_free()
			"detach": builders.remove_child(actor)
			"owner": actor.owner_id = 2
			"reparent":
				var holder := Node3D.new()
				builders.add_child(holder)
				actor.reparent(holder)
		await _frames(90)
		if mode == "reparent":
			_check(builders.contains_unit(actor) and actor.unit_id == identity and site.builder() == null and actor.assigned_site_id == 0 and site.elapsed == elapsed and site.state == ConstructionSite.State.PAUSED, "same-field reparent preserves stable identity and safely pauses the old construction claim")
			builders.selection.select_clicked(actor, false)
			await physics_frame
			_check(builders.construction.assign_builder(actor, site.site_id), "same-field reparented registered builder can explicitly resume its preserved site")
		else:
			_check(site.state == ConstructionSite.State.PAUSED and site.builder() == null and site.elapsed == elapsed and site.cancellable() and builders.credits.balance(1) == balance, "%s builder invalidation pauses without reset, refund or stale strong reference" % mode)
			if is_instance_valid(actor): _check(actor.assigned_site_id == 0, "%s retained builder has no stale site assignment" % mode)
		if mode == "detach": actor.free()


func _builder_blocked() -> void:
	await _builder_inaccessible_placement()
	await _fresh_builder()
	var actor := _player_builders()[0]
	var result := await _builder_place(actor, builders.construction_definition, FIRST)
	var site := _site(result)
	_check(result.accepted and site != null, "physical-blocker fixture first accepts a valid ordinary site")
	if site == null: return
	if not await _until(func() -> bool: return site.state == ConstructionSite.State.TRAVELLING, 6, "blocker fixture observes the committed final work destination"): return
	var access: Vector3 = site.work_access["point"]
	# Add an actual solid capsule after dispatch, without altering navigation or
	# the selected work projection. This is a focused obstruction, not arrival.
	var obstruction := StaticBody3D.new()
	obstruction.collision_layer = 4 | LineOfFire.BLOCKER_MASK
	obstruction.position = access
	var shape := CollisionShape3D.new()
	shape.shape = RTSUnit.body_shape()
	shape.position = RTSUnit.BODY_CENTER
	obstruction.add_child(shape)
	builders.add_child(obstruction)
	await _frames(3)
	await physics_frame
	_check(not builders.builder_can_work(actor, site) and site.elapsed == 0, "navigation-projected work target does not override an actual physical blocker")
	var order := actor.order_version
	var submissions := builders.construction.navigation.submissions
	await _until(func() -> bool: return site.state == ConstructionSite.State.PAUSED, 35, "blocked builder approach exhausts its bounded movement budget and pauses safely")
	_check(site.elapsed == 0 and site.builder() == null and actor.assigned_site_id == 0 and not actor.moving and actor.order_version == order and builders.construction.navigation.submissions == submissions, "inaccessible access adds no progress and does not recreate movement orders or navigation each frame")
	obstruction.queue_free()
	await _frames(3)
	builders.selection.select_clicked(actor, false)
	await physics_frame
	_check(_complete(builders.issue_move(BUILDER_PARK)), "builder remains responsive after bounded blocked-work failure")
	await _cleanup_site(site)
	await _builder_intervening_solid()


func _builder_inaccessible_placement() -> void:
	await _fresh_builder()
	var actor := _player_builders()[0]
	var definition := builders.construction_definition
	var rectangle := Rect2(Vector2(FIRST.x, FIRST.z) - definition.footprint / 2.0, definition.footprint)
	builders.selection.select_clicked(actor, false)
	await physics_frame
	_check(_complete(builders.issue_move(BUILDER_PARK)), "inaccessible-placement fixture starts a normal prior builder Move")
	var order := actor.order_version
	var destination := actor.assigned_destination
	var balance := builders.credits.balance(1)
	var blockers: Array[StaticBody3D] = []
	for access in builders.builder_work_positions(rectangle):
		var body := StaticBody3D.new()
		body.collision_layer = 4 | LineOfFire.BLOCKER_MASK
		body.position = access["point"]
		var collider := CollisionShape3D.new()
		collider.shape = RTSUnit.body_shape()
		collider.position = RTSUnit.BODY_CENTER
		body.add_child(collider)
		builders.add_child(body)
		blockers.append(body)
	await _frames(3)
	await physics_frame
	_check(blockers.size() == 8 and builders.placement_geometry(FIRST, definition).is_empty(), "eight real outside-footprint blockers leave ordinary full-footprint placement geometry clear")
	var projected := 0
	for access in builders.builder_work_positions(rectangle):
		if builders._nav_point(access["point"]): projected += 1
	_check(projected > 0 and builders.plan_builder_access(actor, rectangle).is_empty(), "existing navigation projections cannot substitute for any physically usable work position")
	var refused := builders.construction.place(1, actor, definition, FIRST)
	_check(not refused.accepted and refused.reason.to_lower().contains("work position") and builders.credits.balance(1) == balance and builders.construction.sites.is_empty() and actor.assigned_site_id == 0 and actor.order_version == order and actor.assigned_destination == destination, "inaccessible work rejects before payment/site creation and preserves the prior valid builder order")
	for body in blockers: body.queue_free()
	await _frames(3)


func _builder_intervening_solid() -> void:
	await _fresh_builder()
	var actor := _player_builders()[0]
	var site := await _builder_arrival(await _builder_place(actor))
	if site == null: return
	await _frames(60)
	var access: Vector3 = site.work_access["point"]
	var dock: Vector3 = site.work_access["dock"]
	var before := site.elapsed
	var balance := builders.credits.balance(1)
	# Thin physical wall between the arrived builder and the outside site face.
	# Keep it clear of the actual builder capsule: only the work segment is cut.
	var wall := StaticBody3D.new()
	wall.collision_layer = 4 | LineOfFire.BLOCKER_MASK
	wall.position = access.lerp(dock, 0.7)
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.08, 2, 0.7) if absf(access.x - dock.x) > 0.5 else Vector3(0.7, 2, 0.08)
	collider.shape = box
	collider.position = Vector3.UP
	wall.add_child(collider)
	builders.add_child(wall)
	await _frames(3)
	await physics_frame
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = RTSUnit.body_shape()
	query.transform = Transform3D(Basis.IDENTITY, actor.global_position + RTSUnit.BODY_CENTER)
	query.collision_mask = 4 | LineOfFire.BLOCKER_MASK
	_check(builders.get_world_3d().direct_space_state.intersect_shape(query).is_empty() and actor.global_position.distance_to(access) <= actor.work_tolerance, "intervening wall leaves arrived builder capsule physically clear and within configured site proximity")
	var ray := PhysicsRayQueryParameters3D.create(access + Vector3.UP, dock + Vector3.UP, 4 | LineOfFire.BLOCKER_MASK)
	_check(not builders.get_world_3d().direct_space_state.intersect_ray(ray).is_empty() and not builders.builder_can_work(actor, site), "real intervening solid blocks construction despite valid navigation, actual arrival and proximity")
	var paused := site.elapsed
	await _frames(90)
	_check(site.state == ConstructionSite.State.PAUSED and site.builder() == null and actor.assigned_site_id == 0 and site.elapsed == paused and paused >= before and paused < before + 0.1 and builders.credits.balance(1) == balance, "solid-interrupted work pauses within physics synchronization and never accrues construction through the wall")
	wall.queue_free()
	await _frames(3)
	await _cleanup_site(site)


func _builder_ui() -> void:
	await _fresh_builder(2500)
	var actor := _player_builders()[0]
	var panel := builders.production_panel as ConstructionPanel
	await _hud_pick_building(builders.headquarters)
	_check(panel.train_button.visible and panel.train_button.text.contains("Bulldozer") and panel.train_button.text.contains("500") and not panel.build_button.visible and not panel.depot_button.visible and not panel.factory_button.visible, "HQ context exposes paid Bulldozer production without direct construction controls")
	await _hud_pick_unit(actor)
	_check(panel.build_button.visible and panel.factory_button.visible and panel.depot_button.visible and not panel.depot_button.disabled, "single owned Bulldozer exposes all existing building choices")
	for dimensions in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		await _hud_layout(dimensions)
		await _builder_capture("builder_choices_%dx%d" % [dimensions.x, dimensions.y])
	root.size = Vector2i(1280, 720)
	await _frames(5)
	await _hud_key(KEY_Q)
	_check(not builders.selection.attack_move_targeting and actor.attack_move == null, "builder-only viewport Q rejects Attack Move")
	await _hud_key(KEY_2, true)
	await _hud_pick_unit(builders.units[0])
	await _hud_key(KEY_2)
	_check(builders.selection.selected_units() == [actor] and builders.control_groups.group_members(2) == [actor], "builder retains ordinary control-group assignment and recall")
	await _hud_pick_unit(builders.units[0], true)
	var explanation := panel.feedback.text + " " + panel.selection_details.text
	_check((not panel.depot_button.visible or panel.depot_button.disabled) and explanation.to_lower().contains("bulldozer") and (explanation.to_lower().contains("one") or explanation.contains("1")), "mixed selection explains exactly one eligible Bulldozer is needed for placement")
	await _hud_key(KEY_Q)
	_check(builders.selection.attack_move_targeting, "mixed selection Q remains available to eligible combat units")
	await _click(_minimap_point(Vector3(-8, 0, 14)), MOUSE_BUTTON_LEFT)
	_check(builders.units[0].attack_move.active and actor.attack_move == null and actor.assigned_site_id == 0, "mixed minimap Attack Move dispatch commands only eligible combat actor")
	await _hud_key(KEY_X)
	await _hud_pick_unit(actor)
	await _click(panel.depot_button.get_global_rect().get_center(), MOUSE_BUTTON_LEFT)
	_motion(_world_screen(DEPOT_POINT))
	await _frames(8)
	_check(builders.placement.active and builders.placement.valid and builders.placement.definition == DEPOT, "viewport builder build choice drives existing valid Depot preview")
	var balance := builders.credits.balance(1)
	var preview_order := actor.order_version
	await _click(_minimap_point(Vector3(-10, 0, 6)), MOUSE_BUTTON_RIGHT)
	_check(not builders.placement.active and builders.construction.sites.is_empty() and builders.credits.balance(1) == balance and actor.order_version == preview_order, "right-click preview cancellation over minimap spends nothing and leaks no builder Move")
	await _click(panel.depot_button.get_global_rect().get_center(), MOUSE_BUTTON_LEFT)
	_motion(_world_screen(DEPOT_POINT))
	await _frames(8)
	await _builder_capture("builder_depot_preview_1280x720")
	await _click(_world_screen(DEPOT_POINT), MOUSE_BUTTON_LEFT)
	var result := builders.placement.last_result
	if result == null:
		_check(false, "viewport builder placement commits a real site")
		return
	var site := await _builder_arrival(result)
	if site == null: return
	await _hud_pick_unit(actor)
	_check((panel.feedback.text + panel.selection_details.text + panel.site_status.text).to_lower().contains("construct"), "builder context shows current construction activity")
	await _builder_capture("builder_constructing_1280x720")
	await _click(_minimap_point(BUILDER_PARK), MOUSE_BUTTON_RIGHT)
	await _frames(3)
	_check(site.state == ConstructionSite.State.PAUSED and actor.assigned_site_id == 0 and actor.moving, "ordinary minimap Move releases and pauses builder construction")
	await _click(_world_screen(site.building().global_position + Vector3.UP), MOUSE_BUTTON_RIGHT)
	_check(site.builder() == actor and actor.assigned_site_id == site.site_id, "viewport right-click owned unfinished site resumes with exactly selected eligible builder")
	await _hud_key(KEY_X)
	await _hud_pick_building(site.building())
	await _builder_capture("builder_paused_site_1280x720")
	await _click(panel.cancel_site_button.get_global_rect().get_center(), MOUSE_BUTTON_LEFT)
	await _until(func() -> bool: return site.state == ConstructionSite.State.CANCELLED, 6, "viewport site cancellation restores navigation")
	_check(builders.credits.balance(1) == balance and actor.assigned_site_id == 0, "viewport cancellation refunds the site while builder Stop alone did not")
	await _hud_key(KEY_F1)
	for dimensions in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		await _hud_layout(dimensions)
		await _builder_capture("builder_help_%dx%d" % [dimensions.x, dimensions.y])
	_check(builders.help_panel.is_open() and not builders.movement_debug, "existing contextual Help and hidden movement diagnostics remain intact")


func _builder_freeze() -> void:
	await _fresh_builder()
	var actor := _player_builders()[0]
	var site := await _builder_arrival(await _builder_place(actor))
	if site == null: return
	await _frames(30)
	var producer := builders.headquarters.production
	_check(producer.enqueue(1, BUILDER_RECIPE).accepted, "freeze fixture purchases normal pending HQ builder job")
	var manager := builders.construction
	var navigation := manager.navigation
	var wallet := builders.credits
	await physics_frame
	TeamRules.damage_target(builders, 1, builders.enemy_headquarters, 10000, builders.units[0])
	builders.resolve_result()
	var elapsed := site.elapsed
	var progress := producer.progress()
	var balance := wallet.balance(1)
	var generation := site.nav_generation
	await _frames(120)
	_check(builders.result == BaseAssaultField.Result.VICTORY and site.elapsed == elapsed and producer.progress() == progress and wallet.balance(1) == balance and actor.assigned_site_id == 0 and site.builder() == null, "match result freezes progress/payment and clears builder construction claims")
	_check(not producer.enqueue(1, BUILDER_RECIPE).accepted and not manager.assign_builder(actor, site.site_id) and not manager.cancel(1, site.site_id).accepted, "frozen match rejects stale construction assignment, cancellation and HQ purchases")
	await _builder_capture("builder_match_result_1280x720")
	await _click(builders.restart_button.get_global_rect().get_center(), MOUSE_BUTTON_LEFT)
	await _frames(10)
	builders = current_scene as BuilderAssaultField
	battle = builders
	world = builders
	harvest = builders
	field = builders
	if builders == null:
		_check(false, "viewport Restart loads the intended builder scenario")
		return
	builders.camera_rig.edge_scrolling_enabled = false
	_check(builders.scene_file_path == "res://scenes/builder_assault.tscn" and builders.result == BaseAssaultField.Result.RUNNING and builders.credits.balance(1) == 1000 and builders.construction.sites.is_empty() and _player_builders().size() == 1 and _player_builders()[0].assigned_site_id == 0, "Restart restores normal1000 opening with exactly one fresh unassigned builder and no old site")
	_check(builders.collectors.filter(func(unit: CollectorTruck) -> bool: return unit.owner_id == 1).is_empty() and builders.headquarters.production.count() == 0 and manager.closed and manager.sites.is_empty() and not wallet.active and producer.count() == 0 and navigation.ready.get_connections().is_empty() and navigation.failed.get_connections().is_empty(), "Restart removes old claims/jobs/wallet/listeners without introducing player collectors")
	manager._navigation_ready(generation)
	navigation.advance(10)
	await _frames(30)
	_check(builders.credits.balance(1) == 1000 and builders.construction.sites.is_empty() and _player_builders()[0].assigned_site_id == 0, "obsolete navigation callbacks cannot attach to reused unit IDs after Restart")
	await _builder_capture("builder_restart_1280x720")
