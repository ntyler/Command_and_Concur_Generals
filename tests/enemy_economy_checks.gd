extends "res://tests/attack_move_ui_checks.gd"
## Focused M10 fixtures use the real scene and inherited viewport/physics harness.

var economy: EconomyAssaultField


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1280, 720)
	var logger := EngineErrorProbe.new()
	OS.add_logger(logger)
	for case in ["normal", "economy", "production", "timing", "partial", "authority", "wave_callbacks", "lifecycle"]:
		var before := checks
		var failed := failures
		match case:
			"normal": await _enemy_normal()
			"economy": await _enemy_economy()
			"production": await _enemy_production()
			"timing": await _enemy_timing()
			"partial": await _enemy_partial()
			"authority": await _enemy_authority()
			"wave_callbacks": await _enemy_wave_callbacks()
			"lifecycle": await _enemy_lifecycle()
		print("ENEMY_CASE: %s checks=%d failures=%d" % [case, checks - before, failures - failed])
	if is_instance_valid(battle): battle.queue_free()
	await _frames(6)
	_check(root.get_children().is_empty(), "opponent teardown removes fields/controllers/HUD")
	OS.remove_logger(logger)
	_check(logger.error_count() == 0, "opponent paths have no native errors or warnings")
	print("ENEMY_ECONOMY_CHECKS: %d checks, %d failures; native_errors=%d" % [checks, failures, logger.error_count()])
	quit(0 if failures == 0 else 1)


func _enemy_settings(credits: int = 300, supplies: int = 2000) -> EnemyEconomyConfig:
	var settings := EnemyEconomyConfig.new()
	settings.starting_credits = credits
	settings.cache_contents = supplies
	return settings


func _fresh_enemy(settings: EnemyEconomyConfig = null) -> void:
	if is_instance_valid(battle):
		battle.queue_free()
		await _frames(5)
	economy = load("res://scenes/economy_assault.tscn").instantiate() as EconomyAssaultField
	if settings != null: economy.enemy_config = settings
	battle = economy
	field = battle
	world = battle
	harvest = battle
	root.add_child(battle)
	current_scene = battle
	battle.camera_rig.edge_scrolling_enabled = false
	await _frames(8)
	await physics_frame
	_check(battle._nav_point(economy.enemy_barracks.exit_position()) and battle._nav_point(economy.enemy_config.staging_point) and battle._nav_point(economy.enemy_config.assault_approach), "enemy exit/staging/HQ approach are real navigable ground")


func _enemy_unit(id: int) -> RTSUnit:
	for unit in economy.units:
		if economy.contains_unit(unit) and unit.unit_id == id: return unit
	return null


func _enemy_collectors() -> Array[CollectorTruck]:
	var owned: Array[CollectorTruck] = []
	for unit in economy.units:
		if unit is CollectorTruck and unit.owner_id == 2: owned.append(unit)
	return owned


func _enemy_blocker(size: Vector3, position: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = 4 | LineOfFire.BLOCKER_MASK
	body.collision_mask = 0
	body.position = position
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	body.add_child(collider)
	economy.add_child(body)
	return body


func _enemy_capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://validation-output/m10/screenshots")
	var picture := root.get_texture().get_image()
	_check(picture.save_png("res://validation-output/m10/screenshots/%s.png" % label) == OK and picture.get_size() == root.size, "saved actual opponent viewport " + label)


func _enemy_normal() -> void:
	await _fresh_enemy()
	var ai := economy.enemy_controller
	var c := ai.config
	_check(c.starting_credits == 300 and c.cache_contents == 2000 and c.planning_interval == 0.5 and c.first_wave_time == 90 and c.wave_interval == 60 and c.preferred_wave_size == 3 and c.maximum_wave_size == 3 and c.partial_wait == 30 and c.population_limit == 12, "normal scene uses every requested M10 default")
	_check(economy.units.size() == 10 and economy.collectors.size() == 4 and economy.caches.size() == 3 and economy._producers.size() == 1, "only declared enemy barracks/cache/two collectors augment original forces")
	_check(economy.credits.balance(1) == 1000 and economy.credits.balance(2) == 300 and economy.enemy_cache.remaining == 2000, "player and enemy start in separate authoritative wallets")
	_check(economy.caches.filter(func(cache: SupplyCache) -> bool: return cache != economy.enemy_cache).all(func(cache: SupplyCache) -> bool: return cache.remaining == 2000), "both existing player supply amounts are untouched")
	_check(not economy.uses_scripted_assault() and not economy.assault_issued and economy.assault_acceptances == 0, "new scene disables one-shot mechanism without changing old scene defaults")
	for truck in _enemy_collectors():
		_check(economy.headquarters_for_owner(truck.owner_id) == economy.enemy_headquarters and not economy.plan_access(truck, economy.enemy_cache).is_empty() and not economy.plan_access(truck, economy.enemy_headquarters).is_empty(), "enemy collector has owned HQ and accessible finite supply/deposit positions")
	for dimensions in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		root.size = dimensions
		await _frames(8)
		_check(economy.objective_label.text.contains("Earliest enemy assault") and not economy.production_panel.credit_label.text.contains("300"), "normal HUD gives earliest eligibility and only player credits")
		await _enemy_capture("normal_%dx%d" % [dimensions.x, dimensions.y])
	root.size = Vector2i(1280, 720)
	await _until(func() -> bool: return ai.harvest_assignments == 2, 2, "startup assigns both normal enemy collectors once")
	_check(not economy.enemy_barracks.production.enqueue(1, economy.enemy_barracks.recipe).accepted, "player requester cannot train at enemy barracks")
	economy.selection.replace_units([economy.units[0]])
	await _am_ui_key(KEY_Q)
	_check(economy.selection.attack_move_targeting, "new scenario retains viewport Q targeting")
	await _am_ui_key(KEY_ESCAPE)
	_check(economy.manual_pause_active and not economy.selection.attack_move_targeting, "targeting Escape pauses the economy match on the same press")
	await _am_ui_key(KEY_ESCAPE)
	_check(not economy.manual_pause_active, "second Escape resumes before group input")
	await _tactical_key(3, true)
	await _tactical_key(3)
	_check(economy.control_groups.group_members(3) == [economy.units[0]], "new scenario retains normal control groups")
	await _am_ui_key(KEY_X)
	_check(not economy.units[0].moving, "new scenario retains X Stop")


func _enemy_economy() -> void:
	# 75 finite supplies cannot afford a Rifle; no test credit mutation.
	await _fresh_enemy(_enemy_settings(0, 75))
	var ai := economy.enemy_controller
	var trucks := _enemy_collectors()
	if not await _until(func() -> bool: return ai.harvest_assignments == 2, 2, "zero-credit opponent starts real automatic harvesting"): return
	var generations := [trucks[0].harvesting.generation, trucks[1].harvesting.generation]
	await _frames(60)
	_check([trucks[0].harvesting.generation, trucks[1].harvesting.generation] == generations, "planning does not restart valid harvesting trips")
	if not await _until(func() -> bool: return economy.credits.balance(2) == 75, 25, "normal loading/travel/deposit credits all 75 finite supplies to enemy"): return
	_check(economy.credits.balance(1) == 1000 and economy.enemy_cache.depleted and ai.accepted_jobs == 0, "enemy deposits isolate player funds and insufficient funds reject production")
	await _frames(600)
	_check(economy.credits.balance(2) == 75 and ai.harvest_assignments == 2 and ai.deployments == 0, "depleted finite cache gives no free replenishment or harvest reissue")
	await _fresh_enemy(_enemy_settings(0))
	trucks = _enemy_collectors()
	for truck in trucks: truck.combat.health.apply_damage(10000, economy.units[0])
	await _frames(900)
	_check(economy.credits.balance(2) == 0 and economy.enemy_controller.accepted_jobs == 0 and _enemy_collectors().is_empty() and economy.enemy_cache.remaining == 2000, "collector death leaves no free replacements/deposits/production")
	await _fresh_enemy(_enemy_settings(0))
	trucks = _enemy_collectors()
	economy.unregister_unit(trucks[0])
	trucks[0].queue_free()
	# Detach owned HQ without combat to isolate missing-dropoff rejection.
	var hq := economy.enemy_headquarters
	economy.remove_child(hq)
	await _frames(60)
	_check(economy.credits.balance(2) == 0 and not trucks[1].harvesting.automatic, "detached HQ prevents invalid startup deposits; departed collector is not commanded")
	hq.free()


func _enemy_production() -> void:
	var settings := _enemy_settings(1000, 0)
	settings.population_limit = 6
	await _fresh_enemy(settings)
	var ai := economy.enemy_controller
	var producer := economy.enemy_barracks.production
	await _frames(40)
	_check(producer.count() == 3 and ai.population() == 6 and economy.credits.balance(2) == 700, "population counts three defenders plus three paid jobs, excludes collectors")
	_check(producer.jobs().all(func(job: Dictionary) -> bool: return job.paid == 100 and job.duration == 5 and job.payer == 2), "normal Rifle price/training duration and payer are retained")
	await _frames(240)
	_check(ai.deployments == 0, "Rifle cannot deploy before five simulated training seconds")
	if not await _until(func() -> bool: return ai.deployments == 3, 17, "three paid normal FIFO deployments reach the field"): return
	_check(ai.population() == 6 and ai.accepted_jobs == 3 and economy.credits.balance(1) == 1000, "deployment replaces pending population without double purchase")
	# Destruction refunds queued units while retaining a deployed actor.
	await _fresh_enemy(_enemy_settings(1000, 0))
	ai = economy.enemy_controller
	producer = economy.enemy_barracks.production
	if not await _until(func() -> bool: return ai.deployments >= 1, 7, "destruction fixture obtains a normally produced troop"): return
	var troop := _enemy_unit(11)
	var paid := 0
	for job in producer.jobs(): paid += job.paid
	var funds := economy.credits.balance(2)
	await physics_frame
	economy.enemy_barracks.health.apply_damage(10000, economy.units[0])
	await _frames(8)
	_check(producer.count() == 0 and economy.credits.balance(2) == funds + paid and not producer.is_available(), "barracks destruction returns only paid undeployed jobs once")
	_check(is_instance_valid(troop) and economy.contains_unit(troop), "barracks loss does not erase its deployed Rifle")
	var accepted := ai.accepted_jobs
	await _frames(480)
	_check(ai.accepted_jobs == accepted and economy.credits.balance(2) == funds + paid and not economy.construction.navigation.blocked, "destroyed producer is never rebuilt/requeued and topology cleanup completes")
	# Blocked-complete jobs remain paid and counted. No cancel/requeue workaround.
	await _fresh_enemy(_enemy_settings(1000, 0))
	ai = economy.enemy_controller
	producer = economy.enemy_barracks.production
	var blocker := _enemy_blocker(Vector3(4, 3, 5), economy.enemy_barracks.exit_position() + Vector3(0.7, 1.5, 0))
	await _frames(420)
	var ids := producer.jobs().map(func(job: Dictionary) -> int: return job.id)
	_check(producer.count() == 5 and producer.progress() == 1 and producer.message == "Exit blocked" and ai.deployments == 0 and ai.population() == 8, "blocked completed head stays in five-slot queue and population")
	await _frames(180)
	_check(producer.jobs().map(func(job: Dictionary) -> int: return job.id) == ids and ai.accepted_jobs == 5 and economy.credits.balance(2) == 500, "blocked exits preserve exact paid jobs without duplication/refund cycling")
	blocker.queue_free()
	await _until(func() -> bool: return ai.deployments > 0, 2, "cleared physical exit deploys existing completed job")


func _enemy_timing() -> void:
	# Empty southern endpoint isolates normal 90/60 timing from HQ destruction.
	var settings := _enemy_settings(900, 0)
	settings.assault_approach = Vector3(24, 0, 21)
	await _fresh_enemy(settings)
	var ai := economy.enemy_controller
	var waves: Array[Dictionary] = []
	ai.wave_launched.connect(func(time: float, result: CommandBatchResult) -> void: waves.append({"time": time, "ids": result.accepted_ids.duplicate()}))
	while economy.elapsed < 89.9: await _frames(1)
	_check(waves.is_empty() and ai.assembled().size() >= 3 and not economy.assault_issued, "assembled troops wait through normal 90-second first threshold; old assault stays off")
	if not await _until(func() -> bool: return waves.size() == 1, 1, "three assembled paid troops launch at first permitted plan"): return
	_check(waves[0].time >= 90 - 0.000001 and waves[0].ids.size() == 3, "first accepted wave contains exactly three produced recipients")
	var first_ids: Array = waves[0].ids
	var versions: Dictionary = {}
	for id in first_ids: versions[id] = _enemy_unit(id).order_version
	await _frames(180)
	_check(first_ids.all(func(id: int) -> bool: return _enemy_unit(id).order_version == versions[id]), "active wave receives no repeated orders from planning")
	while economy.elapsed < waves[0].time + 59.9: await _frames(1)
	_check(waves.size() == 1, "second assembled group waits full configured 60-second launch interval")
	if not await _until(func() -> bool: return waves.size() == 2, 1, "second distinct wave launches after normal interval"): return
	_check(waves[1].time - waves[0].time >= 60 - 0.001 and waves[1].ids.size() == 3 and waves[1].ids.all(func(id: int) -> bool: return not first_ids.has(id) and id > 10), "repeat launches respect interval and never reuse recipients or starting defenders")
	_check(economy.objective_label.text.contains("reinforcements active") and not economy.objective_label.text.contains("in "), "post-threshold HUD avoids a guaranteed next-wave countdown")
	print("ENEMY_TIMING: ", waves)


func _enemy_partial() -> void:
	var settings := _enemy_settings(100, 0)
	settings.first_wave_time = 0
	settings.assault_approach = Vector3(24, 0, 21)
	await _fresh_enemy(settings)
	var ai := economy.enemy_controller
	if not await _until(func() -> bool: return ai._waiting_since >= 0, 15, "partial timer begins only after the paid Rifle reaches staging"): return
	var since := ai._waiting_since
	_check(since > 5 and ai.launches == 0, "partial wait is not measured from match start or queued job")
	while economy.elapsed < since + 29.9: await _frames(1)
	_check(ai.launches == 0, "one assembled Rifle waits configured 30 seconds")
	if not await _until(func() -> bool: return ai.launches == 1, 1, "partial wave launches after assembly wait"): return
	_check(ai.last_wave.accepted_ids == [11], "only the actually produced waiting recipient enters partial wave")
	await _frames(180)
	_check(ai.launches == 1, "finite one-unit force is never relaunched")


func _enemy_authority() -> void:
	await _fresh_enemy(_enemy_settings(0, 0))
	var ai := economy.enemy_controller
	economy.selection.replace_units([economy.units[0]])
	await physics_frame
	economy.issue_move(Vector3(-12, 0, 12))
	var selected := economy.selection.selected_units()
	var player_order := economy.units[0].order_version
	var player_batch := economy.last_command_result
	await _am_ui_key(KEY_Q)
	var enemy := economy.units[3]
	var result := economy.issue_attack_move_for(2, [enemy, economy.units[0], _enemy_collectors()[0]], Vector3(24, 0, 21))
	_check(result.acceptance == CommandBatchResult.Acceptance.PARTIAL and result.intended_ids.size() == 3 and result.accepted_ids == [enemy.unit_id] and result.assignments.size() == 1, "owner-aware batch reports intended/accepted identities and rejects player/collector control")
	_check(economy.selection.selected_units() == selected and economy.selection.attack_move_targeting and economy.last_command_result == player_batch and economy.units[0].order_version == player_order, "AI dispatch preserves player selection, pending Q, orders and command feedback")
	_check(not economy.can_attack_move(enemy) and not economy.issue_harvest_for(2, [economy.collectors[0]], economy.enemy_cache).has_acceptance(), "player-facing attack-move and enemy harvesting cannot cross ownership")
	var feedback := economy.status_label.text
	economy.issue_harvest_for(2, [_enemy_collectors()[0]], economy.enemy_cache)
	_check(economy.status_label.text == feedback and economy.last_command_result == player_batch, "rejected AI harvesting also preserves player command feedback")
	# Actual callback departure produces partial historical acceptance.
	var second := economy.units[4]
	var second_id := second.unit_id
	enemy.stop() # Force an actual idle-to-travelling notification boundary.
	var callback := func(_state: RTSUnit.MovementState) -> void:
		if is_instance_valid(second) and economy.contains_unit(second): economy.unregister_unit(second)
	enemy.movement_state_changed.connect(callback)
	result = economy.issue_attack_move_for(2, [enemy, second], Vector3(25, 0, 18))
	enemy.movement_state_changed.disconnect(callback)
	_check(result.intended_ids == [enemy.unit_id, second_id] and result.accepted_ids == [enemy.unit_id] and result.acceptance == CommandBatchResult.Acceptance.PARTIAL, "synchronous departure retains intended identity but cannot falsely accept departed unit")
	second.queue_free()
	# A newer owner-aware command wins; outer result remains historical acceptance.
	var newer := {"once": false, "result": null}
	enemy.stop()
	callback = func(_state: RTSUnit.MovementState) -> void:
		if not newer.once:
			newer.once = true
			newer.result = economy.issue_attack_move_for(2, [enemy], Vector3(25, 0, 20))
	enemy.movement_state_changed.connect(callback)
	result = economy.issue_attack_move_for(2, [enemy], Vector3(24, 0, 19))
	enemy.movement_state_changed.disconnect(callback)
	_check(result.has_acceptance() and result.superseded and enemy.attack_move.parent_order_id == newer.result.generation, "newer synchronous enemy batch supersedes older dispatch without loss of historical acceptance")
	_check(ai.launches == 0 and ai.deployments == 0, "direct authority fixture does not masquerade as produced-wave evidence")


func _enemy_wave_callbacks() -> void:
	var settings := _enemy_settings(300, 0)
	settings.assault_approach = Vector3(24, 0, 21)
	await _fresh_enemy(settings)
	var ai := economy.enemy_controller
	if not await _until(func() -> bool: return ai.assembled().size() == 3, 25, "wave callback fixture assembles three paid normal troops"): return
	ai.set_physics_process(false)
	settings.first_wave_time = 0 # Isolated dispatch fixture, not normal schedule.
	settings.assault_approach = Vector3(999, 0, 999)
	ai.launch_ready()
	_check(ai.launches == 0 and not ai.last_wave.has_acceptance() and ai.assembled().size() == 3, "totally rejected wave neither marks recipients nor advances launch clock")
	settings.assault_approach = Vector3(24, 0, 21)
	var ready := ai.assembled()
	var departed: WeakRef = weakref(ready[1])
	var ids: Array[int] = [ready[0].unit_id, ready[1].unit_id, ready[2].unit_id]
	var callback := func(_state: RTSUnit.MovementState) -> void:
		var unit := departed.get_ref() as RTSUnit
		if is_instance_valid(unit): unit.free()
		ai.launch_ready() # Dispatch reentry must not double-send the accepted unit.
	ready[0].movement_state_changed.connect(callback)
	ai.launch_ready()
	ready[0].movement_state_changed.disconnect(callback)
	_check(ai.launches == 1 and ai.last_wave.intended_ids == ids and ai.last_wave.accepted_ids == [ids[0], ids[2]] and ai.last_wave.acceptance == CommandBatchResult.Acceptance.PARTIAL, "controller records only real accepted paid recipients after synchronous free/reentry")
	_check(ai._troops[ids[0]].dispatched and ai._troops[ids[2]].dispatched and ai.assembled().is_empty() and not ai._troops.has(ids[1]), "accepted troops are marked once and departed pending reference is pruned")
	var versions := [ready[0].order_version, ready[2].order_version]
	ai.launch_ready()
	_check(ai.launches == 1 and [ready[0].order_version, ready[2].order_version] == versions, "partial acceptance cannot redispatch the same active troops")
	var parents := [ready[0].attack_move.parent_order_id, ready[2].attack_move.parent_order_id]
	await physics_frame
	economy.enemy_barracks.health.apply_damage(10000, economy.units[0])
	await _frames(8)
	_check([ready[0].attack_move.parent_order_id, ready[2].attack_move.parent_order_id] == parents and ready[0].attack_move.active and ready[2].attack_move.active, "destroying barracks preserves already dispatched troops and their original attack-move parents")


func _enemy_lifecycle() -> void:
	# Each outcome uses explicit damage solely as a lifecycle fixture.
	for outcome in [BaseAssaultField.Result.VICTORY, BaseAssaultField.Result.DEFEAT, BaseAssaultField.Result.DRAW]:
		await _fresh_enemy()
		var ai := economy.enemy_controller
		await _frames(40)
		await physics_frame
		if outcome != BaseAssaultField.Result.DEFEAT: economy.enemy_headquarters.health.apply_damage(10000, economy.units[0])
		if outcome != BaseAssaultField.Result.VICTORY: economy.headquarters.health.apply_damage(10000, economy.units[3])
		await _frames(4)
		_check(economy.result == outcome and ai._stopped and economy.result_overlay.visible and not economy.credits.active, "HQ result %s stops AI and existing gameplay" % outcome)
		var counts := [ai.plans, ai.accepted_jobs, ai.deployments, ai.launches, economy.credits.balance(2)]
		ai.plan()
		ai._on_deployed(1, 11, true)
		ai.launch_ready()
		await _frames(60)
		_check([ai.plans, ai.accepted_jobs, ai.deployments, ai.launches, economy.credits.balance(2)] == counts, "finished-match direct callbacks/ticks cannot deposit, produce or launch")
		var old: WeakRef = weakref(ai)
		await _click(economy.restart_button.get_global_rect().get_center(), MOUSE_BUTTON_LEFT)
		await _frames(8)
		economy = current_scene as EconomyAssaultField
		battle = economy
		field = economy
		world = economy
		harvest = economy
		economy.camera_rig.edge_scrolling_enabled = false
		_check(old.get_ref() == null and economy.enemy_controller.launches == 0 and economy.enemy_controller._troops.is_empty() and economy.units.size() == 10 and economy.enemy_cache.remaining == 2000 and economy.credits.balance(2) == 300 and economy.credits.balance(1) == 1000, "viewport Restart disposes old controller and restores exact configured economy")
		_check(not economy.selection.attack_move_targeting and not economy.help_panel.is_open() and economy.control_groups.group_members(3).is_empty(), "Restart clears pending input/Help/groups in the new scenario")
	# Enqueue callback destroys producer. The plan must not continue buying.
	await _fresh_enemy(_enemy_settings(1000, 0))
	var ai := economy.enemy_controller
	var producer := economy.enemy_barracks.production
	var event := {"once": false}
	economy.credits.changed.connect(func(owner: int) -> void:
		if owner == 2 and not event.once:
			event.once = true
			economy.enemy_barracks.health.apply_damage(10000, economy.units[0])
			ai.plan())
	await _frames(50)
	_check(event.once and producer.count() == 0 and ai.accepted_jobs == 1 and economy.credits.balance(2) == 1000, "synchronous producer destruction/reentrant plan refunds once and stops further enqueues")
	await _fresh_enemy(_enemy_settings(1000, 0))
	ai = economy.enemy_controller
	event = {"once": false}
	economy.credits.changed.connect(func(owner: int) -> void:
		if owner == 2 and not event.once:
			event.once = true
			economy.credits.spend(2, 900)) # Isolated callback fixture, never integration income.
	await _frames(40)
	_check(event.once and economy.credits.balance(2) == 0 and ai.accepted_jobs == 1 and economy.enemy_barracks.production.count() == 1, "callback spending is rechecked before another enqueue; no overspending")
	await _fresh_enemy(_enemy_settings(1000, 0))
	economy.enemy_barracks.owner_id = 1
	await _frames(40)
	_check(economy.enemy_controller.accepted_jobs == 0 and economy.credits.balance(1) == 1000 and economy.credits.balance(2) == 1000, "controller refuses a producer that no longer belongs to the enemy")
	await _fresh_enemy(_enemy_settings(1000, 0))
	ai = economy.enemy_controller
	event = {"once": false}
	economy.credits.changed.connect(func(owner: int) -> void:
		if owner == 2 and not event.once:
			event.once = true
			economy.enemy_headquarters.health.apply_damage(10000, economy.units[0]))
	await _frames(40)
	_check(event.once and economy.result == BaseAssaultField.Result.VICTORY and ai._stopped and ai.deployments == 0 and ai.launches == 0, "HQ destruction during enqueue prevents continued planning and late deployment callbacks")
