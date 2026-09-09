extends "res://tests/enemy_economy_checks.gd"
## Zero-credit, real-queue, two-wave combat. Only schedule is shortened (30/20s).


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1280, 720)
	var logger := EngineErrorProbe.new()
	OS.add_logger(logger)
	var settings := _enemy_settings(0)
	settings.first_wave_time = 30
	settings.wave_interval = 20
	await _fresh_enemy(settings)
	var ai := economy.enemy_controller
	var accounting := {"deposits": 0, "loads": 0, "spent": 0}
	var jobs: Dictionary[int, bool] = {}
	var produced: Dictionary[int, int] = {}
	var waves: Array[Dictionary] = []
	var damage: Dictionary[int, float] = {}
	var travel: Dictionary[int, Dictionary] = {}
	for truck in _enemy_collectors():
		truck.harvesting.transferred.connect(func(result: HarvestTransfer) -> void:
			accounting["deposits" if result.kind == HarvestTransfer.Kind.DEPOSIT else "loads"] += result.amount)
	ai.job_accepted.connect(func(id: int, paid: int) -> void:
		_check(not jobs.has(id), "normal production accepts each paid job identity once")
		jobs[id] = true
		accounting.spent += paid)
	ai.troop_deployed.connect(func(job: int, id: int) -> void:
		_check(jobs.has(job) and not produced.has(id), "deployed troop traces to a unique paid queue job")
		produced[id] = job)
	ai.wave_launched.connect(func(time: float, result: CommandBatchResult) -> void:
		waves.append({"time": time, "ids": result.accepted_ids.duplicate(), "assignments": result.assignments.duplicate()})
		for id in result.accepted_ids:
			_check(produced.has(id) and not travel.has(id), "wave recipient is normally produced and dispatched once")
			travel[id] = {"engaged": false, "origin": null, "resumed": 0.0})
	for actor in economy.units:
		if actor.owner_id == 1:
			actor.combat.health.damaged.connect(func(amount: float, source: Node) -> void:
				if source is RTSUnit and produced.has(source.unit_id): damage[source.unit_id] = damage.get(source.unit_id, 0.0) + amount)
	economy.headquarters.health.damaged.connect(func(amount: float, source: Node) -> void:
		if source is RTSUnit and produced.has(source.unit_id): damage[source.unit_id] = damage.get(source.unit_id, 0.0) + amount)
	var reached := false
	for tick in 12000:
		await _frames(1)
		for id in travel:
			var unit := _enemy_unit(id)
			if unit == null: continue
			var entry: Dictionary = travel[id]
			if unit.attack_move.target_actor() != null: entry.engaged = true
			if entry.engaged and unit.attack_move.active and unit.combat.target_actor() == null and unit.moving:
				if entry.origin == null: entry.origin = unit.position
				entry.resumed = maxf(entry.resumed, unit.position.distance_to(entry.origin))
		if waves.size() >= 2:
			reached = true
			for wave in waves.slice(0, 2):
				for id in wave.ids:
					if damage.get(id, 0.0) <= 0: reached = false
			if reached: break
		if economy.result != BaseAssaultField.Result.RUNNING: break
	_check(waves.size() >= 2 and reached, "zero-credit normal harvesting/production launches two distinct waves and every member deals real hostile damage")
	if waves.size() >= 2:
		_check(waves[0].time >= 30 - 0.000001 and waves[1].time - waves[0].time >= 20 - 0.000001 and waves[0].ids.size() == 3 and waves[1].ids.size() == 3, "documented shortened 30/20 schedule still requires three assembled troops per wave")
	_check(accounting.deposits > 0 and accounting.spent >= 600 and economy.credits.balance(2) == accounting.deposits - accounting.spent and economy.credits.balance(1) == 1000, "real deposits minus ordinary payments exactly reconcile enemy wallet without affecting player")
	var cargo := 0
	for truck in _enemy_collectors(): cargo += truck.harvesting.cargo
	_check(economy.enemy_cache.remaining + cargo + accounting.deposits == 2000 and accounting.loads == cargo + accounting.deposits, "finite cache/cargo/deposit accounting conserves all original supplies")
	_check(travel.values().any(func(entry: Dictionary) -> bool: return entry.engaged and entry.resumed > 0.5), "produced attack-move troop physically resumes retained travel after actual combat")
	_check(not economy.assault_issued and economy.assault_acceptances == 0 and ai.population() <= 12, "two-wave loop has no old scripted assault or population overflow")
	print("ENEMY_INTEGRATION: time=%.3f waves=%s produced=%s damage=%s travel=%s accounting=%s wallet=%d cache=%d cargo=%d result=%d" % [economy.elapsed, waves, produced, damage, travel, accounting, economy.credits.balance(2), economy.enemy_cache.remaining, cargo, economy.result])
	await _enemy_capture("two_waves_1280x720")
	battle.queue_free()
	await _frames(6)
	_check(root.get_children().is_empty(), "two-wave integration releases all scene references")
	OS.remove_logger(logger)
	_check(logger.error_count() == 0, "two-wave real economy/combat has no native errors or warnings")
	print("ENEMY_ECONOMY_INTEGRATION_CHECKS: %d checks, %d failures; native_errors=%d" % [checks, failures, logger.error_count()])
	quit(0 if failures == 0 else 1)
