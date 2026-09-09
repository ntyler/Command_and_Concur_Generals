extends "res://tests/fixtures/fortification_harness.gd"
## A disclosed single-door terrain fixture keeps the real configured HQ
## approach, paid Rifle queue, physical deployment/rally and ordinary damage.
## No wave actor, wallet grant, damage injection or manual barrier deletion.


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1280, 720)
	var logger := EngineErrorProbe.new()
	OS.add_logger(logger)
	await _paid_single_breach()
	await _bounded_negative()
	await _breach_freeze()
	if is_instance_valid(field): field.queue_free()
	await _frames(6)
	_check(root.get_children().is_empty(), "breach teardown removes field and retained controller objectives")
	OS.remove_logger(logger)
	_check(logger.error_count() == 0, "breach coordinator, callbacks and ordinary combat have no native errors")
	print("FORTIFICATION_BREACH_CHECKS: %d checks, %d failures; native_errors=%d" % [checks, failures, logger.error_count()])
	quit(0 if failures == 0 else 1)


func _breach_field() -> BarrierBuilding:
	if is_instance_valid(field):
		field.queue_free()
		await _frames(5)
	_adopt_fort(load("res://scenes/fortified_assault.tscn").instantiate() as FortifiedAssaultField)
	fort.enemy_config = fort.enemy_config.duplicate(true) as EnemyEconomyConfig
	# Three starting defenders plus three normally purchased Rifle jobs. The
	# staging point moves six units south to expose the exterior of the door;
	# price, training, first-wave90s, wave size and actual HQ approach stay normal.
	fort.enemy_config.cache_contents = 0
	fort.enemy_config.population_limit = 6
	fort.enemy_config.staging_point = Vector3(24, 0, 22)
	fort.sortie_delay = 600
	root.add_child(fort)
	current_scene = fort
	fort.enemy_controller.set_physics_process(false) # Start after fixture observers attach.
	fort.camera_rig.edge_scrolling_enabled = false
	fort.enemy_battery.set_physics_process(false)
	fort.enemy_air_defense.set_physics_process(false)
	for actor in fort.units:
		if actor.owner_id == 2:
			actor.stop()
			actor.set_physics_process(false) # Starting defenders only; paid actors remain live.
	await _until(func() -> bool: return not fort.construction.navigation.blocked and _builder_navigation_current(), 3, "breach fixture inherits current opening navigation")
	# Fixed terrain joins both edges of this one doorway. It is never removed.
	# The only destructible blocker on the retained approach is the actual gate.
	_breach_terrain(Rect2(11.7, -24, 0.6, 32))
	_breach_terrain(Rect2(11.7, 16, 0.6, 8))
	var gate := _fort_fixture(GATE, Vector3(12, 0, 12), 1, 90)
	if not await _until(func() -> bool: return not fort.construction.navigation.blocked, 3, "closed single-barrier approach synchronizes real terrain and gate"):
		await _breach_diagnostic("initial_navigation", gate)
	return gate


func _breach_terrain(rectangle: Rect2) -> void:
	var body := StaticBody3D.new()
	body.name = "DeclaredSingleBreachTerrain"
	body.collision_layer = 4 | LineOfFire.BLOCKER_MASK
	body.collision_mask = 0
	body.position = Vector3(rectangle.get_center().x, 1, rectangle.get_center().y)
	var shape := BoxShape3D.new()
	shape.size = Vector3(rectangle.size.x, 2, rectangle.size.y)
	var collider := CollisionShape3D.new()
	collider.shape = shape
	body.add_child(collider)
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = shape.size
	visual.mesh = mesh
	body.add_child(visual)
	fort.add_child(body)
	fort.static_footprints.append(rectangle)


func _paid_single_breach() -> void:
	var gate := await _breach_field()
	var ai := fort.enemy_controller
	var evidence := {"paid": 0, "jobs": [], "deployed": [], "sources": [], "damage": 0.0, "hits": 0, "started": 0, "resumed": 0, "target_id": gate.get_instance_id(), "start_result": null, "resume_result": null}
	ai.job_accepted.connect(func(job: int, paid: int) -> void:
		evidence.paid += paid
		evidence.jobs.append(job))
	ai.troop_deployed.connect(func(_job: int, identity: int) -> void: evidence.deployed.append(identity))
	ai.breach_started.connect(func(identity: int, result: CommandBatchResult) -> void:
		evidence.started += 1
		evidence.start_result = result
		_check(identity == evidence.target_id, "breach selects the actually blocking player gate"))
	ai.breach_resumed.connect(func(result: CommandBatchResult) -> void:
		evidence.resumed += 1
		evidence.resume_result = result)
	gate.health.damaged.connect(func(amount: float, source: Node) -> void:
		evidence.hits += 1
		evidence.damage += amount
		if source is RTSUnit and not evidence.sources.has(source.unit_id): evidence.sources.append(source.unit_id))
	ai.set_physics_process(true)
	_check(ai.config.breach_enabled and ai.config.breach_reassessment_interval == 0.5 and ai.config.assault_approach == Vector3(-14, 0, -7) and ai.config.first_wave_time == 90 and ai.config.starting_credits == 300, "opt-in breach retains requested0.5s assessment and normal90s HQ approach/starting wallet")
	var selected := fort.selection.selected_units()
	var feedback := fort.last_command_result
	if not await _until(func() -> bool: return ai.deployments == 3 and ai.assembled().size() == 3, 30, "three normally paid trained deployed Rifles physically reach staging"):
		await _breach_diagnostic("paid_assembly", gate)
		return
	_check(ai.accepted_jobs == 3 and fort.credits.balance(2) == 0 and evidence.paid == 300 and evidence.jobs.size() == 3 and evidence.deployed.size() == 3, "ordinary three-job queue spends exactly300 once with no free wave")
	var troops := ai.assembled()
	_check(troops.all(func(unit: RTSUnit) -> bool: return evidence.deployed.has(unit.unit_id) and unit.unit_id > 11 and unit.is_physics_processing() and unit.global_position.distance_to(ai.config.staging_point) <= ai.config.staging_radius), "every recipient is its live produced actor at physically reached staging")
	await physics_frame
	_check(not ai._approach_reachable(troops, ai.config.assault_approach), "closed fixture genuinely rejects a navigation path to retained HQ approach")
	if not await _until(func() -> bool: return ai.retained_objective_count() == 1, 70, "normal first-wave schedule retains blocked approach despite rejected initial attack move"): return
	_check(ai.launches == 0 and ai.last_wave != null and not ai.last_wave.has_acceptance() and ai.last_wave.assignments.is_empty() and ai._objectives[0]["objective"] == ai.config.assault_approach, "initial rejection is not reported as accepted movement and does not erase objective")
	if not await _until(func() -> bool: return evidence.started == 1 and evidence.damage > 0, 10, "ordinary produced wave selects reachable blocking gate and deals actual Rifle damage"):
		await _breach_diagnostic("paid_attack", gate)
		return
	_check(ai.active_breach_target() == gate and evidence.start_result.is_complete() and evidence.start_result.assignments.is_empty(), "one stable barrier attack batch accepts produced recipients without movement claims")
	var versions: Dictionary[int, int] = {}
	for unit in troops: versions[unit.unit_id] = unit.combat.order_version
	await _frames(60)
	_check(ai.breach_dispatches == 1 and evidence.started == 1 and troops.all(func(unit: RTSUnit) -> bool: return unit.combat.order_version == versions[unit.unit_id]), "half-second plans do not reissue attack or reset combat pursuit budgets")
	var gate_ref: WeakRef = weakref(gate)
	if not await _until(func() -> bool: return not is_instance_valid(gate_ref.get_ref()), 40, "ordinary Rifle fire destroys real700HP gate without injected damage"): return
	_check(evidence.damage == 700 and evidence.hits >= 59 and evidence.sources.all(func(identity: int) -> bool: return evidence.deployed.has(identity)), "every applied destruction hit comes from paid deployed wave and totals exactly700 health")
	if not await _until(func() -> bool: return evidence.resumed == 1 and not fort.construction.navigation.blocked, 4, "destruction cleanup synchronizes before surviving wave resumes"): return
	_check(ai.breach_resumptions == 1 and evidence.resume_result.has_acceptance() and evidence.resume_result.assignments.size() == evidence.resume_result.accepted_ids.size() and troops.any(func(unit: RTSUnit) -> bool: return unit.attack_move.active and unit.attack_move.final_destination == ai.config.assault_approach), "survivors receive real accepted movement toward the exact retained HQ objective")
	if not await _until(func() -> bool: return troops.any(func(unit: RTSUnit) -> bool: return fort.contains_unit(unit) and unit.global_position.x < 11.0), 12, "surviving paid troop physically crosses the synchronized destroyed-gate breach"): return
	_check(fort.selection.selected_units() == selected and fort.last_command_result == feedback and fort.result == BaseAssaultField.Result.RUNNING, "enemy breach/resume preserves local selection/command feedback and gate destruction does not end match")
	_check(ai.accepted_jobs == 3 and ai.deployments == 3 and fort.credits.balance(2) == 0 and fort.credits.balance(1) == 1000, "complete breach leaves original paid economy conserved with no extra units or grants")
	DirAccess.make_dir_recursive_absolute("res://validation-output/m16")
	var file := FileAccess.open("res://validation-output/m16/paid-breach-ledger.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"starting_enemy_credits": 300, "paid": evidence.paid, "ending_enemy_credits": fort.credits.balance(2), "job_ids": evidence.jobs, "deployed_ids": evidence.deployed, "damage_sources": evidence.sources, "actual_damage": evidence.damage, "actual_hits": evidence.hits, "breach_dispatches": ai.breach_dispatches, "resumptions": ai.breach_resumptions, "retained_objective": str(ai.config.assault_approach), "simulated_seconds": fort.elapsed}, "\t"))
	file.close()
	await _fort_capture("paid_wave_crosses_real_breach_1280x720")


func _bounded_negative() -> void:
	var gate := await _breach_field()
	var ai := fort.enemy_controller
	# This negative places an indestructible world blocker before the gate.
	# It must never be counted as successful reachable breach evidence.
	_breach_terrain(Rect2(13.1, 14, 9.8, 0.6))
	fort.construction._request_navigation()
	await _until(func() -> bool: return not fort.construction.navigation.blocked, 3, "inaccessible negative fixture synchronizes its extra world obstruction")
	ai.config.first_wave_time = 0
	ai.config.preferred_wave_size = 1
	ai.config.maximum_wave_size = 1
	ai.config.partial_wait = 0
	ai.set_physics_process(true)
	if not await _until(func() -> bool: return ai.retained_objective_count() > 0, 30, "negative normally produced recipient retains rejected approach"): return
	var before := ai.breach_candidate_checks
	await _frames(180)
	_check(ai.breach_dispatches == 0 and gate.health.current == 700 and ai.retained_objective_count() > 0, "inaccessible obstruction remains a clear bounded wait without attacking through terrain")
	_check(ai.breach_candidate_checks - before <= 8 * 6 and ai.status.contains("waiting"), "negative candidate evaluation remains bounded at half-second intervals")
	_check(ai.last_wave != null and not ai.last_wave.has_acceptance(), "negative rejected approach never masquerades as movement acceptance")


func _breach_freeze() -> void:
	var gate := await _breach_field()
	var ai := fort.enemy_controller
	ai.config.first_wave_time = 0
	ai.config.preferred_wave_size = 1
	ai.config.maximum_wave_size = 1
	ai.config.partial_wait = 0
	ai.set_physics_process(true)
	if not await _until(func() -> bool: return ai.breach_dispatches == 1, 30, "freeze fixture obtains ordinary paid active breach target"):
		await _breach_diagnostic("freeze_attack", gate)
		return
	await physics_frame
	fort.headquarters.health.apply_damage(10000, fort.enemy_headquarters) # Result fixture only; barrier damage remains ordinary.
	if not await _until(func() -> bool: return fort.result != BaseAssaultField.Result.RUNNING, 2, "ordinary HQ result freezes active breach"): return
	var health := gate.health.current
	var dispatches := ai.breach_dispatches
	var resumes := ai.breach_resumptions
	await _frames(120)
	_check(ai.retained_objective_count() == 0 and ai.active_breach_target() == null and ai.status == "Stopped" and ai.breach_dispatches == dispatches and ai.breach_resumptions == resumes and gate.health.current == health, "result freeze clears retained targets and permits no new breach damage/commands")


func _breach_diagnostic(label: String, gate: BarrierBuilding) -> void:
	await physics_frame
	var ai := fort.enemy_controller
	var actors: Array[Dictionary] = []
	for identity in ai._troops:
		var unit := (ai._troops[identity]["unit"] as WeakRef).get_ref() as RTSUnit
		if not is_instance_valid(unit): continue
		var ray := fort.fire_query.segment(fort.get_world_3d(), LineOfFire.muzzle(unit), ai.config.assault_approach + Vector3.UP * LineOfFire.AIM_HEIGHT)
		var collider: Object = instance_from_id(ray.collider_id) if ray.collider_id != 0 else null
		actors.append({"id": identity, "position": str(unit.global_position), "moving": unit.moving, "movement": RTSUnit.MovementState.keys()[unit.movement_state], "target": str(unit.combat.target_actor()), "combat_reason": unit.combat.end_reason, "dispatched": ai._troops[identity]["dispatched"], "first_obstruction": str(collider), "obstruction_position": str(ray.position), "gate_eligible": TeamRules.can_attack(fort, unit, gate), "exterior_reachable": ai._exterior_fire_reachable(unit, gate)})
	print("BREACH_DIAGNOSTIC: ", JSON.stringify({"case": label, "status": ai.status, "elapsed": fort.elapsed, "jobs": ai.accepted_jobs, "deployed": ai.deployments, "retained": ai.retained_objective_count(), "nav_blocked": fort.construction.navigation.blocked, "nav_busy": fort.construction.navigation.busy, "gate_position": str(gate.global_position), "actors": actors}))
