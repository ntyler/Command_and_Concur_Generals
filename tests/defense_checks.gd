extends "res://tests/fixtures/defense_harness.gd"
class BoundaryQuery extends LineOfFire:
	var action: Callable
	var armed: bool = false
	func weapon_clearance(source: Node3D, target: Node3D, data: WeaponDefinition) -> LineOfFire.Trace:
		var result := super.weapon_clearance(source, target, data)
		if armed:
			armed = false
			action.call()
		return result


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1280, 720)
	var logger := EngineErrorProbe.new()
	OS.add_logger(logger)
	var chosen := "all"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--defense-case="): chosen = argument.trim_prefix("--defense-case=")
	var cases := ["construction", "replacement", "targeting", "geometry", "power", "callbacks", "lifecycle", "weapons", "freeze"]
	_check(chosen == "all" or cases.has(chosen), "recognized defense case")
	for case in cases:
		if chosen != "all" and chosen != case: continue
		var before := checks
		var failed := failures
		match case:
			"construction": await _defense_construction()
			"replacement": await _defense_replacement()
			"targeting": await _defense_targeting()
			"geometry": await _defense_geometry()
			"power": await _defense_power()
			"callbacks": await _defense_callbacks()
			"lifecycle": await _defense_lifecycle()
			"weapons": await _defense_weapons()
			"freeze": await _defense_freeze()
		print("DEFENSE_CASE: %s checks=%d failures=%d" % [case, checks - before, failures - failed])
	if is_instance_valid(field): field.queue_free()
	await _frames(6)
	_check(root.get_children().is_empty() and get_nodes_in_group("combat_projectiles").is_empty(), "defense teardown removes actors, projectiles and callbacks")
	OS.remove_logger(logger)
	_check(logger.error_count() == 0, "defense physics, synchronous callbacks and teardown have no native errors or warnings")
	print("DEFENSE_CHECKS: %d checks, %d failures; native_errors=%d" % [checks, failures, logger.error_count()])
	quit(0 if failures == 0 else 1)


func _defense_construction() -> void:
	await _fresh_defense()
	_check(DEFENSE.is_valid() and DEFENSE.credit_cost == 700 and DEFENSE.duration == 12 and DEFENSE.maximum_health == 600 and DEFENSE.power_required == 3 and DEFENSE.power_generated == 0, "battery resource fixes700 credits/12 work seconds/600HP/3 demand/zero generation")
	var data := DEFENSE.weapon_data
	_check(data.is_valid() and data.mode == WeaponDefinition.Mode.HITSCAN and data.damage == 18 and data.cooldown == 0.75 and data.attack_range == 12 and data.facing_tolerance_degrees == 8 and DEFENSE.acquisition_interval == 0.25 and DEFENSE.turret_turn_speed == 3, "single existing hitscan resource supplies18 damage/.75 cooldown/12 range/8 degree facing and bounded.25 scans/3rad turn")
	var actor := _player_builders()[0]
	var starting := defended.credits.balance(1)
	await physics_frame
	_check(not defended.construction.place(1, defended.headquarters, DEFENSE, FIRST).accepted and defended.credits.balance(1) == starting, "HQ cannot bypass normal Bulldozer defense construction")
	var result := await _builder_place(actor, DEFENSE, FIRST)
	var site := _site(result)
	_check(result.accepted and result.paid == 700 and defended.credits.balance(1) == starting - 700, "defense commits exact ordinary700-credit payment once")
	if site == null: return
	var battery := site.building() as GroundDefenseBattery
	var hostile := _defense_mobile(FIRST + Vector3(8, 0, 0))
	_check(battery != null and site.builder_required and not battery.operational and _grid_is(1, 0, 0), "unfinished battery uses builder-gated stationary construction and contributes no demand")
	if battery == null: return
	_check(battery.production == null and battery.recipe == null and not battery.can_take_damage(), "unfinished site preserves damageability policy and has no unit queue")
	if await _builder_arrival(result) == null: return
	await _frames(60)
	actor.stop()
	var elapsed := site.elapsed
	await _frames(90)
	_check(site.state == ConstructionSite.State.PAUSED and site.elapsed == elapsed and battery.weapon.shots_fired == 0 and battery.acquisition_scans == 0 and hostile.combat.health.current == 100 and _grid_is(1, 0, 0), "paused unfinished battery earns no work, demand, scans, shots or damage")
	_check(defended.construction.cancel(1, site.site_id).accepted, "unfinished battery accepts ordinary cancellation")
	if not await _until(func() -> bool: return site.state == ConstructionSite.State.CANCELLED, 6, "cancelled defense releases navigation and construction slot"): return
	_check(defended.credits.balance(1) == starting and not defended.construction.cancel(1, site.site_id).accepted and _grid_is(1, 0, 0), "defense cancellation refunds700 exactly once")
	var complete := await _power_build(actor, DEFENSE, FIRST) as GroundDefenseBattery
	if complete == null: return
	_check(complete.operational and complete.site.elapsed == 12 and complete.health.current == 600 and complete.production == null and complete.recipe == null and actor.assigned_site_id == 0 and _grid_is(1, 0, 3), "real12-second completion activates600HP/3 demand once and releases builder without producer")
	var location := complete.global_transform
	for index in 3: defended.register_building(complete)
	await _frames(60)
	_check(_grid_is(1, 0, 3) and complete.weapon.shots_fired == 0 and complete.target_actor() == null and complete.status_text() == "No power", "completed idle shortage retains nominal demand and cannot acquire or fire")
	_check(complete.global_transform == location and defended.units.all(func(unit: RTSUnit) -> bool: return unit.get_instance_id() != complete.get_instance_id()) and not complete.is_in_group("rts_units"), "built battery remains a StaticBody outside mobile registry and groups")
	await physics_frame
	_check(not defended._nav_point(complete.global_position) and not defended.fire_query.segment(defended.get_world_3d(), FIRST + Vector3(-4, 0.7, 0), FIRST + Vector3(4, 0.7, 0)).is_clear(), "committed defense footprint blocks actual navigation and weapon segment")
	var collider: CollisionShape3D
	for child in complete.get_children():
		if child is CollisionShape3D: collider = child
	_check(collider != null and (collider.shape as BoxShape3D).size == Vector3(DEFENSE.footprint.x, DEFENSE.height, DEFENSE.footprint.y), "defense collider exactly matches committed configurable footprint")
	await _defense_capture("defense_built_no_power_1280x720")


func _defense_replacement() -> void:
	# Labelled isolated wallet: exactly 700 for this battery and 500 for a
	# normally trained replacement. The earned integration uses real income.
	await _fresh_defense(1200)
	var original := _player_builders()[0]
	var site := await _builder_arrival(await _builder_place(original, DEFENSE, FIRST))
	if site == null: return
	var battery := site.building() as GroundDefenseBattery
	if battery == null:
		_check(false, "replacement fixture creates an actual Ground Defense Battery site")
		return
	await _frames(90)
	await physics_frame
	var identity := site.site_id
	var progress := site.elapsed
	var stationary := battery.global_transform
	_check(progress > 0 and progress < 12 and site.paid == 700 and defended.credits.balance(1) == 500, "original builder earns partial battery work after its exact 700-credit payment")
	# Explicit builder-death fixture through existing health authority, not
	# evidence of battery firing or of an enemy's weapon engagement.
	_check(TeamRules.damage_target(defended, 2, original, 10000, defended.units[3]) == 200, "ordinary health authority removes original builder from partially completed battery")
	await _frames(90)
	_check(site.state == ConstructionSite.State.PAUSED and site.site_id == identity and site.elapsed == progress and site.builder() == null and _player_builders().is_empty() and defended.credits.balance(1) == 500, "builder loss preserves the same paid battery and its accumulated work without refund")
	_check(not battery.operational and battery.weapon.shots_fired == 0 and battery.acquisition_scans == 0 and _grid_is(1, 0, 0), "orphaned unfinished battery gains no work, demand or defensive activity")
	var replacement := await _paid_builder()
	if replacement == null: return
	defended.selection.select_clicked(replacement, false)
	await physics_frame
	_check(defended.construction.assign_builder(replacement, identity), "normally paid HQ replacement claims this same unfinished battery")
	_check(site.site_id == identity and site.paid == 700 and site.elapsed == progress and defended.credits.balance(1) == 0, "replacement costs exactly 500 without repaying or resetting the battery site")
	if not await _until(func() -> bool: return site.state == ConstructionSite.State.CONSTRUCTING, 30, "replacement physically reaches usable battery work access before resuming progress"):
		return
	# Work-position authority performs physics queries, matching _builder_arrival.
	await physics_frame
	_check(site.builder() == replacement and defended.builder_can_work(replacement, site) and not site.work_access.is_empty(), "replacement construction requires the registered builder's real arrived work position")
	defended.selection.select_building(battery)
	_check(not battery.range_indicator.visible, "selected unfinished replacement site keeps its operational range hidden")
	if not await _builder_complete(site): return
	_check(site.site_id == identity and site.elapsed == 12 and site.paid == 700 and battery.operational and battery.health.current == 600 and battery.global_transform == stationary and _grid_is(1, 0, 3), "replacement finishes exactly 12 total working seconds on the same stationary 600-HP battery and adds demand once")
	_check(replacement.assigned_site_id == 0 and site.builder() == null and not replacement.moving and defended.construction.unfinished_id == 0 and battery.production == null and battery.recipe == null and defended.credits.balance(1) == 0, "completion releases replacement and construction slot with no production queue or extra payment")
	_check(defended.selection.selected_building() == battery and battery.range_indicator.visible, "selected site becomes a battery with visible range without requiring reselection")


func _defense_targeting() -> void:
	await _fresh_defense()
	var battery := _defense_fixture()
	_power_fixture_building(POWER_PLANT, 1, SECOND)
	var near := _defense_mobile(DEFENSE_POINT + Vector3(6, 0, 0))
	var tied := _defense_mobile(DEFENSE_POINT + Vector3(0, 0, -6))
	var far := _defense_mobile(DEFENSE_POINT + Vector3(10, 0, 0))
	var friendly := _defense_mobile(DEFENSE_POINT + Vector3(3, 0, 0), 1)
	var building := _power_fixture_building(POWER_BARRACKS, 2, Vector3(-15, 0, -17))
	var decoration := Node3D.new()
	defended.add_child(decoration)
	var detached := RTSUnit.new()
	_check(battery.target_available(near) and battery.target_available(tied) and not battery.target_available(friendly) and not battery.target_available(building) and not battery.target_available(decoration) and not battery.target_available(detached) and not battery.target_available(defended.caches[0]), "battery ground predicate accepts hostiles and rejects friendlies, buildings, decoration, detached actors and supplies")
	detached.free()
	for kind in ["rocket", "collector", "builder"]:
		var actor := _defense_mobile(DEFENSE_POINT + Vector3(9, 0, 2), 2, kind)
		_check(battery.target_available(actor), "ordinary hostile %s is an eligible mobile ground threat" % kind)
		actor.queue_free()
	await _frames(2)
	var rotation_before := battery.turret.rotation.y
	var stationary := battery.global_transform
	var scan_before := battery.acquisition_scans
	if not await _until(func() -> bool: return battery.target_actor() != null, 1, "configured bounded scan acquires an eligible hostile"): return
	_check(battery.target_actor() == near, "nearest equivalent-distance tie uses the stable earlier unit identity")
	_check(battery.weapon.shots_fired == 0, "acquisition cannot fire immediately before actual turret facing")
	if not await _until(func() -> bool: return battery.weapon.shots_fired == 1, 2, "real turret rotation precedes first authoritative shot"): return
	_check(near.combat.health.current == 82 and battery.turret.rotation.y != rotation_before and battery.global_transform == stationary, "first committed hitscan deals18 and rotates only turret with stationary base")
	var shot_tick := Engine.get_physics_frames()
	var notifications := {"count": 0}
	battery.weapon.fired.connect(func(_target: Node3D, _projectile: GuidedProjectile) -> void: notifications.count += 1)
	await _frames(20)
	_check(battery.target_actor() == near and battery.weapon.shots_fired == 1 and near.combat.health.current == 82, "valid retained target does not switch during scan and cooldown prevents early damage")
	if not await _until(func() -> bool: return battery.weapon.shots_fired == 2, 1, "remaining ordinary cooldown permits exactly the second shot"): return
	_check(absf((Engine.get_physics_frames() - shot_tick) / 60.0 - 0.75) <= 0.04 and near.combat.health.current == 64 and notifications.count == 1, "second shot respects.75 simulated seconds and one success notification")
	_check(battery.acquisition_scans - scan_before <= 9 and battery.global_transform == stationary, "automatic scan budget stays bounded and defense never pursues")
	near.queue_free()
	await _frames(2)
	_check(battery.target_actor() == null or battery.target_actor() == tied, "queued target deletion immediately releases invalid reference")
	if not await _until(func() -> bool: return battery.target_actor() == tied, 1, "next scheduled scan reacquires remaining nearest threat"): return
	tied.global_position = DEFENSE_POINT + Vector3(0, 0, -15) # Labelled range-boundary fixture.
	await _frames(2)
	_check(battery.target_actor() == null or battery.target_actor() == far, "target leaving actual12-unit range is released without pursuit")
	await _until(func() -> bool: return battery.target_actor() == far, 1, "bounded scan reacquires clear remaining in-range hostile")
	_check(battery.global_transform == stationary, "target departure/reacquisition never moves battery base")


func _defense_geometry() -> void:
	await _fresh_defense()
	var battery := _defense_fixture()
	_power_fixture_building(POWER_PLANT, 1, SECOND)
	var outside := _defense_mobile(DEFENSE_POINT + Vector3(13, 0, 0))
	await _frames(3)
	var queries := defended.fire_query.clearance_queries
	var scans := battery.acquisition_scans
	await _frames(60)
	_check(battery.target_actor() == null and battery.weapon.shots_fired == 0 and battery.acquisition_scans - scans <= 5 and defended.fire_query.clearance_queries == queries, "distance filtering excludes outside-range units before obstruction queries at bounded scan frequency")
	outside.queue_free()
	var target := _defense_mobile()
	var wall := _vehicle_wall(Vector3(0.4, 5, 4), DEFENSE_POINT + Vector3(4, 2.5, 0))
	await _frames(90)
	_check(battery.target_actor() == null and battery.weapon.shots_fired == 0 and target.combat.health.current == 100 and battery.weapon.cooldown_remaining == 0, "solid wall prevents acquisition, successful shots, damage and new cooldown")
	wall.queue_free()
	if not await _until(func() -> bool: return battery.weapon.shots_fired == 1, 3, "opening the real lane permits ordinary acquisition/rotation/damage"): return
	_check(target.combat.health.current == 82 and battery.weapon.last_fire_line.is_clear(), "real shot uses clear final muzzle-to-target geometry without self-blocking")
	wall = _vehicle_wall(Vector3(0.4, 5, 4), DEFENSE_POINT + Vector3(4, 2.5, 0))
	await _frames(65)
	_check(battery.target_actor() == null and battery.weapon.shots_fired == 1 and target.combat.health.current == 82 and battery.weapon.cooldown_remaining == 0, "new obstruction releases engaged target and expired cooldown does not authorize wall damage")
	wall.queue_free()
	await _frames(3)
	battery.set_physics_process(false)
	battery.turret.rotation.y = -PI / 2.0 # Explicit facing-only final-boundary fixture.
	var muzzle := LineOfFire.muzzle(battery)
	var origin_blocker := _vehicle_wall(Vector3(0.2, 0.2, 0.2), muzzle)
	await _frames(3)
	await physics_frame
	var before := battery.weapon.shots_fired
	_check(not battery.weapon.try_fire(target) and battery.weapon.shots_fired == before and target.combat.health.current == 82 and battery.weapon.cooldown_remaining == 0, "invalid muzzle origin cannot commit a shot, damage or cooldown")
	origin_blocker.queue_free()


func _defense_power() -> void:
	await _fresh_defense()
	var battery := _defense_fixture()
	var target := _defense_mobile()
	await _frames(90)
	_check(_grid_is(1, 0, 3) and battery.weapon.shots_fired == 0 and battery.acquisition_scans == 0 and target.combat.health.current == 100, "insufficient owner power retains full idle demand and suppresses all scans/shots")
	var plant := _power_fixture_building(POWER_PLANT, 1, SECOND)
	if not await _until(func() -> bool: return battery.weapon.shots_fired == 1, 3, "real registered generation enables first ordinary shot"): return
	var cooldown := battery.weapon.cooldown_remaining
	var scans := battery.acquisition_scans
	plant.queue_free()
	await _frames(2)
	_check(_grid_is(1, 0, 3) and battery.target_actor() == null and battery.status_text() == "No power" and battery.weapon.cooldown_remaining <= cooldown and battery.weapon.cooldown_remaining > 0.6, "power loss clears temporary target and preserves remaining committed cooldown")
	await _frames(10)
	plant = _power_fixture_building(POWER_PLANT, 1, SECOND)
	await _frames(10)
	_check(battery.weapon.shots_fired == 1 and target.combat.health.current == 82 and battery.weapon.cooldown_remaining > 0.2, "early restoration cannot reset cooldown for an extra shot")
	if not await _until(func() -> bool: return battery.weapon.shots_fired == 2, 1, "restored defense resumes after the original cooldown expires"): return
	_check(target.combat.health.current == 64 and battery.acquisition_scans - scans <= 4, "restoration resumes bounded acquisition and one ordinary shot")
	plant.queue_free()
	await _frames(120)
	_check(battery.weapon.cooldown_remaining == 0 and battery.weapon.shots_fired == 2 and _grid_is(1, 0, 3), "active-match cooldown continues while unpowered without oscillating nominal demand")
	plant = _power_fixture_building(POWER_PLANT, 1, SECOND)
	await _frames(20)
	_check(battery.weapon.shots_fired == 3 and target.combat.health.current == 46, "long power outage accumulates no burst; restoration emits at most one ready shot")
	var producer := _power_fixture_building(FACTORY, 1, Vector3(-10, 0, -18))
	var other := _power_fixture_building(FACTORY, 1, Vector3(-18, 0, -18))
	await _frames(2)
	_check(_grid_is(1, 10, 11) and not defended.defense_firing_allowed(battery) and defended.production_multiplier(producer) == 0.5 and defended.defense_firing_allowed(defended.enemy_battery), "same real shortage disables battery, halves existing producers and preserves another owner's defense")
	var starting := defended.credits.balance(1)
	var job := producer.production.enqueue(1, ROCKET_RECIPE)
	await _frames(60)
	_check(job.accepted and defended.credits.balance(1) == starting - 250 and absf(producer.production.jobs()[0].elapsed - 0.5) <= 0.04, "battery shortage preserves normal paid Factory250-credit queue and established50percent rate")
	other.health.apply_damage(10000) # Explicit consumer-destruction accounting fixture, not shot evidence.
	await _frames(2)
	_check(_grid_is(1, 10, 7) and defended.defense_firing_allowed(battery) and defended.production_multiplier(producer) == 1.0, "destroying one consumer restores sufficient power without touching surviving battery demand")


func _defense_callbacks() -> void:
	for action_name in ["power", "target_owner", "target_remove", "source_depart", "source_reparent", "freeze"]:
		await _fresh_defense()
		var battery := _defense_fixture()
		var plant := _power_fixture_building(POWER_PLANT, 1, SECOND)
		var target := _defense_mobile()
		battery.set_physics_process(false)
		battery.turret.rotation.y = -PI / 2.0
		await _frames(3)
		var query := BoundaryQuery.new()
		defended.fire_query = query
		query.action = func() -> void:
			match action_name:
				"power": plant.queue_free()
				"target_owner": target.owner_id = 1
				"target_remove": target.queue_free()
				"source_depart": battery.reparent(root)
				"source_reparent":
					var holder := Node3D.new()
					defended.add_child(holder)
					battery.reparent(holder)
					defended.register_building(battery)
				"freeze": defended.gameplay_enabled = false
		query.armed = true
		var notifications := {"count": 0}
		battery.weapon.fired.connect(func(_target: Node3D, _projectile: GuidedProjectile) -> void: notifications.count += 1)
		await physics_frame
		var fired := battery.weapon.try_fire(target)
		_check(not query.armed and not fired and battery.weapon.shots_fired == 0 and battery.weapon.cooldown_remaining == 0 and target.combat.health.current == 100 and notifications.count == 0, "authoritative final boundary rejects %s mutation during geometry callback without any shot commitment" % action_name)
		if action_name == "source_depart": battery.queue_free()
	for remove in ["source", "target", "field"]:
		await _fresh_defense()
		var battery := _defense_fixture()
		_power_fixture_building(POWER_PLANT, 1, SECOND)
		var target := _defense_mobile()
		var emitting_health := target.combat.health
		var audit := {"events": 0, "amount": 0.0, "shots": 0, "cooldown": 0.0}
		target.combat.health.damaged.connect(func(amount: float, source: Node) -> void:
			audit.events += 1
			audit.amount += amount
			audit.shots = battery.weapon.shots_fired
			audit.cooldown = battery.weapon.cooldown_remaining
			match remove:
				"source": source.free()
				"target", "field":
					# Godot forbids freeing the Object currently emitting a signal.
					# Preserve only that health signal emitter until emission returns;
					# target/source/field actors still disappear immediately here.
					emitting_health.reparent(root)
					if remove == "target": target.free()
					else: defended.free()
					emitting_health.queue_free()
		)
		if not await _until(func() -> bool: return audit.events > 0, 3, "real shot reaches immediate %s-removal damage callback" % remove): return
		await _frames(5)
		_check(audit.events == 1 and audit.amount == 18 and audit.shots == 1 and audit.cooldown == 0.75, "committed shot remains exactly once through immediate %s deletion" % remove)
		if remove == "source": _check(_grid_is(1, 10, 0) and target.combat.health.current == 82, "source deletion removes demand once without undoing committed damage")
		if remove == "target": _check(is_instance_valid(battery) and battery.target_actor() == null, "immediate target deletion leaves no dangling temporary target")
		if remove == "field": _check(not is_instance_valid(defended) and root.get_children().is_empty(), "damage callback field deletion leaves no old actors or callbacks")


func _defense_lifecycle() -> void:
	await _fresh_defense()
	var actor := _player_builders()[0]
	var battery := await _power_build(actor, DEFENSE, FIRST) as GroundDefenseBattery
	if battery == null: return
	var holder := Node3D.new()
	defended.add_child(holder)
	var original := battery.global_transform
	battery.reparent(holder)
	defended.register_building(battery)
	await _frames(4)
	_check(defended.contains_building(battery) and _grid_is(1, 0, 3) and battery.global_transform == original, "same-field reparent retains stationary identity and exactly one demand contribution")
	defended.selection.select_building(battery)
	await _frames(3)
	await _hud_key(KEY_3, true)
	await _hud_key(KEY_Q)
	_check(defended.selection.selected_building() == battery and defended.selection.selected_units().is_empty() and defended.control_groups.group_members(3).is_empty() and not defended.selection.attack_move_targeting, "battery selection stays building-only and cannot enter mobile groups or Q targeting")
	await physics_frame
	_check(not defended.issue_move(Vector3(-5, 0, 16)).has_acceptance() and battery.global_transform == original, "selected battery has no Move command or pursuit")
	defended.tactical_minimap.refresh_markers()
	var identity := battery.get_instance_id()
	_check(_marker(identity).get("kind") == "ground_defense_battery", "completed battery participates through distinct minimap marker")
	var credits := defended.credits.balance(1)
	battery.health.apply_damage(10000) # Labelled lifecycle death trigger, not firing evidence.
	await _frames(3)
	_check(not is_instance_valid(battery) and not defended._buildings.has(identity) and _grid_is(1, 0, 0) and defended.selection.selected_building() == null and defended.credits.balance(1) == credits and defended.result == BaseAssaultField.Result.RUNNING, "destruction removes selection/demand without completed refund or HQ result")
	if not await _until(func() -> bool: return defended._nav_point(FIRST), 6, "destroyed committed battery releases its navigation footprint"): return
	defended.tactical_minimap.refresh_markers()
	_check(_marker(identity).is_empty(), "destroyed battery disappears from minimap")
	await _fresh_defense()
	battery = _defense_fixture()
	_power_fixture_building(POWER_PLANT, 1, SECOND)
	var target := _defense_mobile()
	if not await _until(func() -> bool: return battery.weapon.shots_fired == 1, 3, "departure fixture begins with real target and committed cooldown"): return
	battery.reparent(root)
	await _frames(3)
	var shots := battery.weapon.shots_fired
	await _frames(60)
	_check(not defended.contains_building(battery) and _grid_is(1, 10, 0) and battery.target_actor() == null and battery.weapon.shots_fired == shots and target.combat.health.current == 82, "battery departure clears authority and target without delayed damage or nominal demand")
	battery.queue_free()
	await _fresh_defense()
	var preplaced := defended.enemy_battery
	var footprint_point := preplaced.global_position
	var preplaced_id := preplaced.get_instance_id()
	_check(preplaced.site == null and not defended._nav_point(footprint_point) and defended.obstacles.has(DefenseAssaultField.ENEMY_DEFENSE), "explicit completed enemy battery owns its normally committed static footprint without a construction site")
	preplaced.health.apply_damage(10000) # Labelled preplaced-body cleanup trigger.
	if not await _until(func() -> bool: return defended._nav_point(footprint_point), 6, "destroyed preplaced enemy defense releases actual static navigation footprint"): return
	defended.tactical_minimap.refresh_markers()
	_check(not defended.obstacles.has(DefenseAssaultField.ENEMY_DEFENSE) and not defended._buildings.has(preplaced_id) and _grid_is(2, 10, 2) and _marker(preplaced_id).is_empty() and defended.result == BaseAssaultField.Result.RUNNING, "preplaced enemy death removes static obstacle/registration/marker/3 demand without changing HQ objective")


func _defense_weapons() -> void:
	for kind in ["rifle", "rocket"]:
		await _fresh_defense()
		var battery := _defense_fixture(2)
		battery.set_physics_process(false) # Isolated incoming-weapons fixture.
		var actor := _defense_mobile(DEFENSE_TARGET, 1, kind)
		actor.set_physics_process(true)
		await _frames(3)
		defended.selection.select_clicked(actor, false)
		await _click(_world_screen(battery.global_position + Vector3.UP * 0.7), MOUSE_BUTTON_RIGHT)
		_check(actor.combat.target_actor() == battery and actor.combat.target_unit() == null, "ordinary viewport %s right-click attacks battery through building target API" % kind)
		if not await _until(func() -> bool: return battery.health.current < 600, 5, "normal %s weapon faces and delivers actual damage to battery" % kind): return
		actor.stop()
		_check(battery.health.current == 600 - (12 if kind == "rifle" else 32) and actor.combat.weapon.shots_fired == 1, "unchanged %s damage commits once against defense building" % kind)
		await _frames(60)
		await physics_frame
		_check(defended.issue_attack_move(DEFENSE_POINT).has_acceptance(), "ordinary %s Attack Move accepts hostile battery approach" % kind)
		if not await _until(func() -> bool: return actor.combat.target_actor() == battery, 2, "existing Attack Move registry acquires hostile defense building"): return
		_check(not actor.combat.target_actor() is RTSUnit, "Attack Move preserves building identity rather than mobile adaptation")


func _defense_freeze() -> void:
	await _fresh_defense()
	var battery := _defense_fixture()
	_power_fixture_building(POWER_PLANT, 1, SECOND)
	var target := _defense_mobile()
	if not await _until(func() -> bool: return battery.weapon.shots_fired == 1, 3, "freeze fixture starts with a real shot/target/cooldown"): return
	await physics_frame
	TeamRules.damage_target(defended, 1, defended.enemy_headquarters, 10000, defended.units[0]) # Explicit result fixture.
	defended.resolve_result()
	var shots := battery.weapon.shots_fired
	var scans := battery.acquisition_scans
	var rotation := battery.turret.rotation
	var hp := target.combat.health.current
	await _frames(90)
	await physics_frame
	_check(defended.result == BaseAssaultField.Result.VICTORY and not battery.weapon.try_fire(target) and battery.weapon.shots_fired == shots and battery.acquisition_scans == scans and battery.turret.rotation == rotation and target.combat.health.current == hp, "HQ match result suppresses scans, turret commands and final-boundary firing/damage")
	var old_battery: WeakRef = weakref(battery)
	var old_target: WeakRef = weakref(target)
	var old_grid := defended.power_grid
	_check(defended.restart_match(), "normal Restart accepts completed match")
	await _frames(10)
	_adopt_defense(current_scene as DefenseAssaultField)
	_check(defended != null and defended.scene_file_path == "res://scenes/defense_assault.tscn" and old_battery.get_ref() == null and old_target.get_ref() == null and defended.power_grid != old_grid and old_grid.changed.get_connections().is_empty(), "Restart removes old battery/target/listeners and loads fresh defense field")
	if defended == null: return
	defended.camera_rig.edge_scrolling_enabled = false
	old_grid.refresh()
	await _frames(3)
	_check(_grid_is(1, 0, 0) and _grid_is(2, 10, 5) and defended.credits.balance(1) == 1000 and defended.enemy_battery.weapon.shots_fired == 0 and defended.enemy_battery.target_actor() == null and defended.enemy_battery.weapon.cooldown_remaining == 0 and not defended.help_panel.is_open(), "Restart restores configured demand/wallet and fresh target/cooldown/Help state")
	_check(defended.enemy_controller.is_physics_processing() and defended.enemy_config.first_wave_time == 90 and defended.enemy_config.wave_interval == 60 and defended.enemy_config.starting_credits == 300, "normal reloaded enemy economy and wave settings remain unchanged")
