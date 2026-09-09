extends "res://tests/builder_checks.gd"
## M13 isolated fixtures use configurable funds and explicitly labelled registered
## buildings for accounting/timing. Actual construction and recovery use paid
## Bulldozer work; power_integration_checks proves the unmodified earned opening.
## Timing observes completed physics ticks: each producer reads the current owner
## snapshot immediately before advancing its active job. No time_scale changes.

const POWER_PLANT: ConstructionDefinition = preload("res://construction/power_plant.tres")
const POWER_BARRACKS: ConstructionDefinition = preload("res://construction/barracks.tres")
const POWER_RIFLE: ProductionDefinition = preload("res://production/rifle.tres")
var powered: PowerAssaultField


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1280, 720)
	var logger := EngineErrorProbe.new()
	OS.add_logger(logger)
	var chosen := "all"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--power-case="): chosen = argument.trim_prefix("--power-case=")
	var cases := ["accounting", "construction", "timing", "blocked", "lifecycle", "callbacks", "recovery", "freeze", "compatibility"]
	_check(chosen == "all" or cases.has(chosen), "recognized power case")
	for case in cases:
		if chosen != "all" and chosen != case: continue
		var before := checks
		var failed := failures
		match case:
			"accounting": await _power_accounting()
			"construction": await _power_construction()
			"timing": await _power_timing()
			"blocked": await _power_blocked()
			"lifecycle": await _power_lifecycle()
			"callbacks": await _power_callbacks()
			"recovery": await _power_recovery()
			"freeze": await _power_freeze()
			"compatibility": await _power_compatibility()
		print("POWER_CASE: %s checks=%d failures=%d" % [case, checks - before, failures - failed])
	if is_instance_valid(field): field.queue_free()
	await _frames(6)
	_check(root.get_children().is_empty() and get_nodes_in_group("combat_projectiles").is_empty(), "power teardown removes field, actors, queues and listeners")
	OS.remove_logger(logger)
	_check(logger.error_count() == 0, "power physics, synchronous callbacks and teardown produce no native errors or warnings")
	print("POWER_CHECKS: %d checks, %d failures; native_errors=%d" % [checks, failures, logger.error_count()])
	quit(0 if failures == 0 else 1)


func _fresh_power(funds: int = 4000, live_enemy: bool = false) -> void:
	if is_instance_valid(field):
		field.queue_free()
		await _frames(5)
	powered = load("res://scenes/power_assault.tscn").instantiate() as PowerAssaultField
	powered.starting_credits = funds
	if live_enemy:
		# Instance-only first-wave isolation matches the existing earned opening.
		powered.enemy_config = powered.enemy_config.duplicate(true) as EnemyEconomyConfig
		powered.enemy_config.first_wave_time = 600.0
	builders = powered
	battle = powered
	world = powered
	harvest = powered
	field = powered
	root.add_child(powered)
	current_scene = powered
	powered.camera_rig.edge_scrolling_enabled = false
	if not live_enemy:
		powered.enemy_controller.set_physics_process(false)
		for actor in powered.units:
			if actor.owner_id == 2:
				actor.stop()
				actor.set_physics_process(false)
	await _until(_builder_navigation_current, 2, "powered scene synchronizes its actual actor navigation starts")
	_check(powered.power_enabled and powered.builder_construction_enabled and powered.power_plant_definition == POWER_PLANT, "new scenario opts into power and the normal builder construction authority")
	_check(powered.credits.balance(1) == funds and powered.construction.sites.is_empty() and _player_builders().size() == 1, "fresh power fixture has configured funds, one original builder and no stale sites")
	_check(powered.registered_buildings().filter(func(body: RTSBuilding) -> bool: return body.owner_id == 1 and body.kind != RTSBuilding.Kind.HEADQUARTERS).is_empty(), "powered opening adds no player production structures or generator")
	_check(powered.power_snapshot(1) == {"generated": 0, "required": 0, "low_power": false, "multiplier": 1.0}, "zero generation and zero demand is NORMAL")
	_check(_grid_is(2, 10, 2) and powered.enemy_config.starting_credits == 300 and (live_enemy or powered.credits.balance(2) == 300) and powered.enemy_config.wave_interval == 60, "one normally registered enemy plant powers the unchanged enemy Barracks and configured wallet")


func _grid_is(owner: int, generation: int, demand: int) -> bool:
	var value := powered.power_snapshot(owner)
	return value.generated == generation and value.required == demand and value.low_power == (generation < demand) and is_equal_approx(value.multiplier, 0.5 if generation < demand else 1.0)


func _power_fixture_building(definition: ConstructionDefinition, owner: int = 1, point: Vector3 = FIRST) -> RTSBuilding:
	# Isolated fixture only. Register a real living body with definition data;
	# never write runtime totals or mutate the shared resource.
	var body := RTSBuilding.new()
	body.name = "PowerFixture%s" % definition.display_name().replace(" ", "")
	body.kind = definition.kind
	body.definition = definition
	body.owner_id = owner
	body.footprint = definition.footprint
	body.building_height = definition.height
	body.position = point
	match definition.kind:
		RTSBuilding.Kind.POWER_PLANT: body.recipe = null
		RTSBuilding.Kind.VEHICLE_FACTORY: body.recipe = ROCKET_RECIPE
		RTSBuilding.Kind.SUPPLY_DEPOT: body.recipe = COLLECTOR_RECIPE
		_: body.recipe = POWER_RIFLE
	powered.add_child(body)
	powered.register_building(body)
	return body


func _power_build(actor: Bulldozer, definition: ConstructionDefinition, point: Vector3 = FIRST) -> ConstructionBuilding:
	var site := await _builder_arrival(await _builder_place(actor, definition, point))
	if site == null or not await _builder_complete(site): return null
	return site.building() as ConstructionBuilding


func _power_capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://validation-output/m13/screenshots")
	var picture := root.get_texture().get_image()
	_check(picture.save_png("res://validation-output/m13/screenshots/%s.png" % label) == OK and picture.get_size() == root.size, "saved actual M13 viewport " + label)


func _power_accounting() -> void:
	await _fresh_power()
	_check(POWER_PLANT.is_valid() and POWER_PLANT.credit_cost == 500 and POWER_PLANT.duration == 10 and POWER_PLANT.power_generated == 10 and POWER_PLANT.power_required == 0, "configurable plant definition has exactly500 credits/10seconds/10 generation/zero demand")
	_check(POWER_BARRACKS.power_required == 2 and FACTORY.power_required == 4 and DEPOT.power_required == 0 and DEPOT.power_generated == 0, "building definitions provide nominal demands without changing recipes")
	var plant := _power_fixture_building(POWER_PLANT, 1, SECOND)
	var consumers: Array[RTSBuilding] = []
	for index in 5:
		consumers.append(_power_fixture_building(POWER_BARRACKS, 1, Vector3(-10, 0, -18)))
	_check(_grid_is(1, 10, 10) and consumers.all(func(body: RTSBuilding) -> bool: return body.production.count() == 0), "all five idle Barracks contribute full nominal demand and equality remains NORMAL")
	var factory := _power_fixture_building(FACTORY)
	_check(_grid_is(1, 10, 14) and consumers.all(func(body: RTSBuilding) -> bool: return powered.production_multiplier(body) == 0.5) and powered.production_multiplier(factory) == 0.5, "shortage halves every eligible producer uniformly without removing any demand")
	for index in 4:
		powered.register_building(plant)
		powered.register_building(factory)
	_check(_grid_is(1, 10, 14) and _grid_is(2, 10, 2), "duplicate registration neither doubles contributions nor changes another owner")
	plant.health.apply_damage(100)
	_check(plant.health.current == 350 and _grid_is(1, 10, 14), "ordinary nonlethal damage leaves full generator output until death")
	plant.health.apply_damage(10000)
	powered.destroy_building(plant)
	_check(_grid_is(1, 0, 14) and powered.result == BaseAssaultField.Result.RUNNING, "generator death removes output exactly once without ending the match")
	var refund := powered.credits.balance(1)
	var pending := factory.production.enqueue(1, ROCKET_RECIPE)
	_check(pending.accepted and powered.credits.balance(1) == refund - ROCKET_RECIPE.credit_cost, "low-power Factory still accepts exactly one normal paid job")
	factory.health.apply_damage(10000)
	powered.destroy_building(factory)
	_check(_grid_is(1, 0, 10) and powered.credits.balance(1) == refund and factory.production.count() == 0, "consumer death removes nominal demand once and preserves original paid-job refund")
	await _fresh_power()
	_power_fixture_building(POWER_PLANT, 1, SECOND)
	var survivor := _power_fixture_building(FACTORY)
	var removed: RTSBuilding
	for index in 4:
		removed = _power_fixture_building(POWER_BARRACKS, 1, Vector3(-10, 0, -18))
	_check(_grid_is(1, 10, 12) and powered.production_multiplier(survivor) == 0.5, "consumer-death restoration fixture has genuine shortage with surviving Factory")
	removed.health.apply_damage(10000)
	_check(_grid_is(1, 10, 10) and powered.production_multiplier(survivor) == 1.0, "consumer death alone restores sufficient power and surviving Factory rate")


func _power_construction() -> void:
	await _fresh_power()
	var actor := _player_builders()[0]
	var balance := powered.credits.balance(1)
	await physics_frame
	_check(not powered.construction.place(1, powered.headquarters, POWER_PLANT, FIRST).accepted, "HQ cannot directly construct a Power Plant")
	var result := await _builder_place(actor, POWER_PLANT)
	var site := _site(result)
	_check(result.accepted and result.paid == 500 and site != null and site.builder_required and _grid_is(1, 0, 0), "paid plant site requires assigned builder and contributes no preparation/travel generation")
	if site == null: return
	_check(site.building().production == null and site.building().recipe == null, "unfinished Power Plant has no production queue or accidental unit recipe")
	if await _builder_arrival(result) == null: return
	await _frames(60)
	actor.stop()
	var elapsed := site.elapsed
	await _frames(90)
	_check(site.state == ConstructionSite.State.PAUSED and site.elapsed == elapsed and _grid_is(1, 0, 0), "paused builder work remains unfinished and generates nothing")
	_check(powered.construction.cancel(1, site.site_id).accepted, "unfinished plant follows existing cancellation policy")
	await _until(func() -> bool: return site.state == ConstructionSite.State.CANCELLED, 6, "cancelled plant releases navigation and construction slot")
	_check(powered.credits.balance(1) == balance and _grid_is(1, 0, 0) and not powered.construction.cancel(1, site.site_id).accepted, "cancelled plant refunds exactly500 once and never contributes")
	var completed := await _power_build(actor, POWER_PLANT)
	if completed == null: return
	_check(completed.site.elapsed == 10 and completed.operational and completed.health.current == 450 and completed.production == null and _grid_is(1, 10, 0), "real ten-second builder completion activates exactly10 generation with established450-health non-producer conventions")
	var holder := Node3D.new()
	powered.add_child(holder)
	completed.reparent(holder)
	powered.register_building(completed)
	await _frames(3)
	_check(_grid_is(1, 10, 0) and powered.construction.sites.has(completed.site.site_id), "same-field completed-site reparent preserves identity without registering generation twice")
	await physics_frame
	_check(not powered._nav_point(completed.global_position) and not powered.fire_query.segment(powered.get_world_3d(), completed.global_position + Vector3(-4, 1, 0), completed.global_position + Vector3(4, 1, 0)).is_clear(), "committed plant footprint blocks movement and weapon fire through existing authorities")


func _power_timing() -> void:
	await _fresh_power()
	var barracks := _power_fixture_building(POWER_BARRACKS)
	var plant := _power_fixture_building(POWER_PLANT, 1, SECOND)
	var producer := barracks.production
	var completions: Array[Dictionary] = []
	producer.deployed.connect(func(job: int, unit: int, _rally: bool) -> void: completions.append({"job": job, "unit": unit, "tick": Engine.get_physics_frames()}))
	var starting := powered.credits.balance(1)
	var normal := producer.enqueue(1, POWER_RIFLE)
	var start_tick := Engine.get_physics_frames()
	await _frames(120)
	_check(producer.count() == 1 and absf(producer.jobs()[0].elapsed - 2.0) <= 0.035, "NORMAL Rifle earns two observable training seconds in two simulated seconds")
	if not await _until(func() -> bool: return completions.size() == 1, 4, "normal Rifle actually deploys"): return
	var normal_time: float = (completions[0].tick - start_tick) / 60.0
	_check(completions[0].job == normal.job_id and absf(normal_time - POWER_RIFLE.training_duration) <= 0.035, "sufficient-power job completes at unchanged five-second nominal duration")
	var first_unit := _last_unit(producer)
	first_unit.queue_free()
	plant.queue_free()
	_check(_grid_is(1, 0, 2), "queued-for-deletion plant is excluded immediately before another production tick")
	await _frames(3)
	var slow := producer.enqueue(1, POWER_RIFLE)
	start_tick = Engine.get_physics_frames()
	await _frames(300)
	_check(producer.count() == 1 and absf(producer.jobs()[0].elapsed - 2.5) <= 0.035, "uninterrupted LOW POWER Rifle earns only2.5 progress after five simulated seconds")
	if not await _until(func() -> bool: return completions.size() == 2, 6, "half-rate Rifle eventually deploys exactly once"): return
	var slow_time: float = (completions[1].tick - start_tick) / 60.0
	_check(completions[1].job == slow.job_id and absf(slow_time - POWER_RIFLE.training_duration * 2.0) <= 0.035, "uninterrupted half-rate training requires twice the nominal simulated time")
	_last_unit(producer).queue_free()
	await _frames(3)
	var mixed := producer.enqueue(1, POWER_RIFLE)
	var waiting := producer.enqueue(1, POWER_RIFLE)
	await _frames(120)
	var before: float = producer.jobs()[0].elapsed
	var captured := producer.jobs()[0]
	plant = _power_fixture_building(POWER_PLANT, 1, SECOND)
	await _frames(60)
	_check(absf(producer.jobs()[0].elapsed - before - 1.0) <= 0.035 and producer.jobs()[0].id == mixed.job_id and producer.jobs()[0].duration == captured.duration and producer.jobs()[0].paid == captured.paid, "mid-job restoration retains identity/payment/duration/progress and earns full-rate work")
	before = producer.jobs()[0].elapsed
	plant.queue_free()
	await _frames(60)
	_check(absf(producer.jobs()[0].elapsed - before - 0.5) <= 0.035 and producer.jobs()[1].id == waiting.job_id and producer.jobs()[1].elapsed == 0, "mid-job power loss retains progress and unchanged FIFO waiting job")
	plant = _power_fixture_building(POWER_PLANT, 1, SECOND)
	_check(producer.cancel(1, waiting.job_id).accepted and powered.credits.balance(1) == starting - 3 * POWER_RIFLE.credit_cost, "repeated power changes preserve original paid-cost cancellation refund")
	if not await _until(func() -> bool: return completions.size() == 3, 4, "same mixed-rate job completes after restoration"): return
	await _frames(60)
	_check(completions.size() == 3 and completions[2].job == mixed.job_id and producer.count() == 0 and powered.credits.balance(1) == starting - 300, "repeated rate transitions never duplicate completion or alter the three deployed units' total cost")


func _power_blocked() -> void:
	await _fresh_power()
	var body := _power_fixture_building(POWER_BARRACKS)
	var plant := _power_fixture_building(POWER_PLANT, 1, SECOND)
	var wall := _vehicle_wall(Vector3(4, 3, 5), body.exit_position() + Vector3(0.6, 1.5, 0))
	await _frames(3)
	var producer := body.production
	var completions: Array[int] = []
	producer.deployed.connect(func(job: int, _unit: int, _rally: bool) -> void: completions.append(job))
	var job := producer.enqueue(1, POWER_RIFLE)
	if not await _until(func() -> bool: return producer.progress() == 1 and producer.message == "Exit blocked", 6, "real blocked-exit job finishes training and waits at100percent"): return
	plant.queue_free()
	await _frames(60)
	_check(producer.progress() == 1 and producer.message == "Exit blocked" and completions.is_empty() and _grid_is(1, 0, 2), "low power keeps blocked-complete job complete and retains full idle nominal demand")
	wall.queue_free()
	var opened := Engine.get_physics_frames()
	if not await _until(func() -> bool: return completions.size() == 1, 0.4, "blocked-complete job deploys at unchanged quarter-second retry cadence during shortage"): return
	_check((Engine.get_physics_frames() - opened) / 60.0 <= body.spawn_retry_interval + 0.05 and completions[0] == job.job_id, "power changes never slow spawn retry timing or replace the completed paid job")


func _power_lifecycle() -> void:
	await _fresh_power()
	var body := _power_fixture_building(POWER_BARRACKS)
	var plant := _power_fixture_building(POWER_PLANT, 1, SECOND)
	var holder := Node3D.new()
	powered.add_child(holder)
	plant.reparent(holder)
	await _frames(3)
	_check(_grid_is(1, 10, 2), "same-field generator reparent preserves its sole contribution")
	plant.owner_id = 2
	_check(_grid_is(1, 0, 2) and _grid_is(2, 20, 2), "supported internal ownership change moves generation to the correct owner immediately")
	plant.owner_id = 1
	plant.reparent(root)
	_check(_grid_is(1, 0, 2) and _grid_is(2, 10, 2), "foreign-parent departure excludes generator without retaining stale output")
	await _frames(3)
	plant.reparent(powered)
	powered.register_building(plant)
	_check(_grid_is(1, 10, 2), "supported generator re-entry rebuilds exactly one contribution")
	var events := {"count": 0}
	powered.power_grid.changed.connect(func() -> void: events.count += 1)
	powered.power_snapshot(1)
	var initial_events: int = events.count
	await _frames(60)
	_check(events.count == initial_events, "unchanged shortage/totals never emit repetitive per-frame notifications")
	plant.queue_free()
	_check(powered.production_multiplier(body) == 0.5 and _grid_is(1, 0, 2), "production's next snapshot excludes queued deletion before deferred removal")
	body.queue_free()
	_check(_grid_is(1, 0, 0), "queued consumer deletion removes demand without negative totals")
	await _frames(4)
	_check(_grid_is(1, 0, 0) and _grid_is(2, 10, 2), "deferred cleanup remains idempotent and owner isolated")
	var enemy_plant := powered.registered_buildings().filter(func(item: RTSBuilding) -> bool: return item.kind == RTSBuilding.Kind.POWER_PLANT and item.owner_id == 2)[0] as RTSBuilding
	var producer := powered.enemy_barracks.production
	_check(producer.enqueue(2, POWER_RIFLE).accepted, "enemy paid Rifle enters its unchanged ordinary queue")
	await _frames(60)
	var progress: float = producer.jobs()[0].elapsed
	enemy_plant.health.apply_damage(10000)
	await _frames(60)
	_check(_grid_is(1, 0, 0) and _grid_is(2, 0, 2) and absf(producer.jobs()[0].elapsed - progress - 0.5) <= 0.035, "enemy plant death slows actual paid enemy progress without changing player state")


func _power_callbacks() -> void:
	await _fresh_power()
	var body := _power_fixture_building(POWER_BARRACKS)
	var plant := _power_fixture_building(POWER_PLANT, 1, SECOND)
	var state := {"armed": true, "coherent": true, "calls": 0}
	powered.power_grid.changed.connect(func() -> void:
		state.calls += 1
		var value := powered.power_snapshot(1)
		state.coherent = state.coherent and value.low_power == (value.generated < value.required)
		if state.armed and value.generated == 0:
			state.armed = false
			body.health.apply_damage(10000)
			state.coherent = state.coherent and _grid_is(1, 0, 0)
	)
	plant.health.apply_damage(10000)
	_check(_grid_is(1, 0, 0) and state.coherent and not state.armed and state.calls > 0, "synchronous power listener can destroy a consumer while observing committed coherent snapshots")
	await _frames(3)
	_check(_grid_is(1, 0, 0), "older notification cannot overwrite newer nested destruction state")
	await _fresh_power()
	body = _power_fixture_building(POWER_BARRACKS)
	plant = _power_fixture_building(POWER_PLANT, 1, SECOND)
	var producer := body.production
	var callback_field := powered
	var queued := {"accepted": false}
	powered.power_grid.changed.connect(func() -> void:
		if not is_instance_valid(callback_field) or callback_field.is_queued_for_deletion(): return
		if callback_field.power_snapshot(1).low_power:
			queued.accepted = producer.enqueue(1, POWER_RIFLE).accepted
			callback_field.queue_free()
	)
	plant.queue_free()
	powered.power_snapshot(1)
	await _frames(5)
	_check(queued.accepted and not is_instance_valid(callback_field) and not producer.is_available() and producer.count() == 0, "power callback can queue a normal paid job then remove field without stale work or invalid references")
	# These narrow reentrancy fixtures invoke one ordinary production advance in
	# a physics frame before the field's earlier callback has reconciled deletion.
	# Automatic processing of this fixture producer is disabled to avoid doubling
	# its work; no job elapsed/progress is assigned by the harness.
	await _fresh_power()
	body = _power_fixture_building(POWER_BARRACKS)
	body.set_physics_process(false)
	plant = _power_fixture_building(POWER_PLANT, 1, SECOND)
	producer = body.production
	var balance := powered.credits.balance(1)
	var cancel_job := producer.enqueue(1, POWER_RIFLE)
	var cancel_state := {"armed": true, "accepted": false}
	var cancel_producer := producer
	powered.power_grid.changed.connect(func() -> void:
		if cancel_state.armed and powered.power_snapshot(1).low_power:
			cancel_state.armed = false
			cancel_state.accepted = cancel_producer.cancel(1, cancel_job.job_id).accepted
	)
	await physics_frame
	plant.queue_free()
	producer.advance(1.0 / 60.0)
	_check(cancel_state.accepted and producer.count() == 0 and powered.credits.balance(1) == balance and producer.last_deployment.is_empty(), "callback cancellation inside active rate read refunds original payment and prevents stale advancement/deployment")
	await _fresh_power()
	body = _power_fixture_building(POWER_BARRACKS)
	body.set_physics_process(false)
	plant = _power_fixture_building(POWER_PLANT, 1, SECOND)
	producer = body.production
	_check(producer.enqueue(1, POWER_RIFLE).accepted, "ownership callback fixture queues a normal original-owner paid job")
	var owner_state := {"armed": true}
	var changing_owner := body
	powered.power_grid.changed.connect(func() -> void:
		if owner_state.armed and powered.power_snapshot(1).low_power:
			owner_state.armed = false
			changing_owner.owner_id = 2
	)
	await physics_frame
	plant.queue_free()
	producer.advance(1.0 / 60.0)
	_check(not owner_state.armed and body.owner_id == 2 and producer.jobs()[0].elapsed == 0 and _grid_is(1, 0, 0) and _grid_is(2, 10, 4), "owner mutation during snapshot skips old-owner increment and commits coherent new-owner demand")
	await physics_frame
	producer.advance(1.0 / 60.0)
	_check(absf(producer.jobs()[0].elapsed - 1.0 / 60.0) < 0.00001 and producer.jobs()[0].payer == 1, "next producer advance uses new owner's full rate while retaining captured payer")
	await _fresh_power()
	body = _power_fixture_building(POWER_BARRACKS)
	body.set_physics_process(false)
	plant = _power_fixture_building(POWER_PLANT, 1, SECOND)
	producer = body.production
	_check(producer.enqueue(1, POWER_RIFLE).accepted, "result callback fixture queues a normal paid job")
	var finish_state := {"armed": true}
	powered.power_grid.changed.connect(func() -> void:
		if finish_state.armed and powered.power_snapshot(1).low_power:
			finish_state.armed = false
			powered.enemy_headquarters.health.apply_damage(10000)
			powered.resolve_result()
	)
	await physics_frame
	plant.queue_free()
	producer.advance(1.0 / 60.0)
	_check(powered.result == BaseAssaultField.Result.VICTORY and producer.jobs()[0].elapsed == 0 and producer.last_deployment.is_empty(), "synchronous match result during rate read prevents that progress increment and any deployment")


func _power_recovery() -> void:
	await _fresh_power()
	var actor := _player_builders()[0]
	var body := _power_fixture_building(POWER_BARRACKS, 1, SECOND)
	var depot := _power_fixture_building(DEPOT, 1, DEPOT_POINT)
	_check(_grid_is(1, 0, 2), "recovery starts in genuine owner shortage")
	actor.combat.health.apply_damage(10000)
	var start_tick := Engine.get_physics_frames()
	var replacement := await _paid_builder()
	if replacement == null: return
	_check((Engine.get_physics_frames() - start_tick) / 60.0 <= BUILDER_RECIPE.training_duration + 0.05 and _grid_is(1, 0, 2), "HQ replaces a lost builder in the ordinary six seconds while Barracks lacks power")
	start_tick = Engine.get_physics_frames()
	_check(depot.production.enqueue(1, COLLECTOR_RECIPE).accepted, "Depot accepts a paid Collector during shortage")
	if not await _until(func() -> bool: return not depot.production.last_deployment.is_empty(), 7, "Depot actually deploys a Collector during shortage"): return
	_check((Engine.get_physics_frames() - start_tick) / 60.0 <= COLLECTOR_RECIPE.training_duration + 0.05, "Depot Collector keeps normal six-second training independent of power")
	# Fixtures above leave the full FIRST approach clear. The newly paid builder
	# now travels and performs all ten construction seconds through normal orders.
	var result := await _builder_place(replacement, POWER_PLANT, FIRST)
	var site := await _builder_arrival(result)
	if site == null: return
	_check(_grid_is(1, 0, 2) and site.elapsed < site.duration and replacement.global_position.distance_to(powered.headquarters.global_position) > 4, "replacement builder physically travels and starts work while owner remains short")
	if not await _builder_complete(site): return
	_check(_grid_is(1, 10, 2) and powered.production_multiplier(body) == 1.0 and site.elapsed == 10, "normally completed replacement plant restores full production after actual builder work")


func _power_freeze() -> void:
	await _fresh_power()
	var body := _power_fixture_building(POWER_BARRACKS, 1, SECOND)
	var site := await _builder_arrival(await _builder_place(_player_builders()[0], POWER_PLANT, FIRST))
	if site == null: return
	var producer := body.production
	_check(producer.enqueue(1, POWER_RIFLE).accepted, "freeze fixture holds a paid low-power Rifle and active real construction")
	await _frames(60)
	var old_grid = powered.power_grid
	var old_manager := powered.construction
	var old_wallet := powered.credits
	var old_field := powered
	await physics_frame
	powered.enemy_headquarters.health.apply_damage(10000)
	powered.resolve_result()
	var elapsed := site.elapsed
	var progress := producer.progress()
	var deployed := powered.units.size()
	_power_fixture_building(POWER_PLANT, 1, Vector3(4, 0, 17))
	powered.power_snapshot(1)
	await _frames(120)
	_check(powered.result == BaseAssaultField.Result.VICTORY and site.elapsed == elapsed and producer.progress() == progress and powered.units.size() == deployed and not producer.enqueue(1, POWER_RIFLE).accepted, "late power recovery cannot reactivate frozen construction/production or deploy post-result")
	_check(powered.restart_match(), "Restart remains usable after shortage and result")
	await _frames(10)
	powered = current_scene as PowerAssaultField
	builders = powered
	battle = powered
	world = powered
	harvest = powered
	field = powered
	if powered == null:
		_check(false, "Restart reloads power_assault scene")
		return
	powered.camera_rig.edge_scrolling_enabled = false
	_check(not is_instance_valid(old_field) and powered.scene_file_path == "res://scenes/power_assault.tscn" and powered.result == BaseAssaultField.Result.RUNNING and powered.credits.balance(1) == 1000 and _grid_is(1, 0, 0) and _grid_is(2, 10, 2), "Restart rebuilds configured opening owner totals from fresh actual buildings")
	_check(old_grid.changed.get_connections().is_empty() and not old_wallet.active and producer.count() == 0 and old_manager.closed, "old grid listeners, wallet, jobs and construction manager are closed on restart")
	old_grid.changed.emit()
	await _frames(3)
	_check(_grid_is(1, 0, 0) and powered.construction.sites.is_empty() and _player_builders().size() == 1, "old grid notification cannot reach new field or reused unit IDs")


func _power_compatibility() -> void:
	await _fresh_builder()
	_check(not builders.power_enabled and builders.power_plant_definition == null, "earlier builder scene explicitly remains opted out with its unchanged build choices")
	var body := RTSBuilding.new()
	body.kind = RTSBuilding.Kind.BARRACKS
	body.definition = POWER_BARRACKS
	body.position = FIRST
	builders.add_child(body)
	builders.register_building(body)
	var producer := body.production
	_check(producer.enqueue(1, POWER_RIFLE).accepted, "opt-out producer accepts unchanged normal paid recipe")
	await _frames(120)
	_check(absf(producer.jobs()[0].elapsed - 2.0) <= 0.035 and builders.production_multiplier(body) == 1.0, "earlier scene keeps full observable progress despite no generator and nominal Barracks demand")
