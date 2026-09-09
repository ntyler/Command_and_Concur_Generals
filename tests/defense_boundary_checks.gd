extends "res://tests/power_checks.gd"
## Isolated acquisition-notification boundaries. Registered fixture structures and
## one ordinary Rifle isolate synchronous listeners; builder/economy acceptance
## lives in defense_integration_checks. Never manually apply shot damage.

const BOUNDARY_DEFENSE: ConstructionDefinition = preload("res://construction/ground_defense_battery.tres")


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1280, 720)
	var logger := EngineErrorProbe.new()
	OS.add_logger(logger)
	await _scan_power_loss()
	await _committed_shot_power_loss()
	await _scan_match_result()
	await _scan_replacement("owner")
	await _scan_replacement("reparent")
	await _invalid_ground_target()
	for victim in ["source", "target", "field"]:
		await _scan_immediate_removal(victim)
	if is_instance_valid(field): field.queue_free()
	await _frames(6)
	_check(root.get_children().is_empty(), "scan-boundary teardown leaves no field or listener owners")
	OS.remove_logger(logger)
	_check(logger.error_count() == 0, "scan notification removal/replacement/freeze produce no native errors")
	print("DEFENSE_BOUNDARY_CHECKS: %d checks, %d failures; native_errors=%d" % [checks, failures, logger.error_count()])
	quit(0 if failures == 0 else 1)


func _boundary_fixture() -> Dictionary:
	await _fresh_power()
	var generator := _power_fixture_building(POWER_PLANT, 1, SECOND)
	var battery := GroundDefenseBattery.new()
	battery.definition = BOUNDARY_DEFENSE
	battery.kind = RTSBuilding.Kind.GROUND_DEFENSE_BATTERY
	battery.footprint = BOUNDARY_DEFENSE.footprint
	battery.building_height = BOUNDARY_DEFENSE.height
	battery.position = FIRST
	powered.add_child(battery)
	powered.register_building(battery)
	battery.set_physics_process(false)
	var target := powered.prepare_deployment(load("res://scenes/rifle_unit.tscn"), 2, FIRST + Vector3.RIGHT * 7.0)
	target.show()
	target.combat.retaliation_enabled = false
	await _frames(4)
	_check(_grid_is(1, 10, 3) and battery.weapon.shots_fired == 0, "boundary fixture starts powered with nominal demand and no automatic advance")
	return {"battery": battery, "generator": generator, "target": target}


func _scan_power_loss() -> void:
	var setup := await _boundary_fixture()
	var battery: GroundDefenseBattery = setup.battery
	var generator: RTSBuilding = setup.generator
	var target: RTSUnit = setup.target
	var events := {"count": 0}
	var angle := battery.turret.rotation.y
	battery.status_changed.connect(func() -> void:
		var candidate := battery.target_actor()
		if candidate != null and events.count == 0:
			events.count += 1
			generator.operational = false
	)
	battery.set_physics_process(true)
	await _frames(90)
	_check(events.count == 1 and battery.target_actor() == null and _grid_is(1, 0, 3), "power loss inside acquisition clears target and retains full nominal demand")
	_check(battery.weapon.shots_fired == 0 and battery.weapon.cooldown_remaining == 0.0 and target.combat.health.current == target.combat.health.maximum and battery.turret.rotation.y == angle, "acquisition callback power loss permits no shot, cooldown or turret command")
	var scans := battery.acquisition_scans
	await _frames(45)
	_check(battery.acquisition_scans == scans, "unpowered acquisition remains stopped after callback")
	generator.operational = true
	_check(await _until(func() -> bool: return battery.weapon.shots_fired > 0, 2.0, "restored owner power permits a later bounded acquisition and actual shot"), "power callback recovery returns to real combat")
	_check(target.combat.health.current < target.combat.health.maximum, "restoration damage comes from ordinary battery emission")


func _committed_shot_power_loss() -> void:
	var setup := await _boundary_fixture()
	var battery: GroundDefenseBattery = setup.battery
	var generator: RTSBuilding = setup.generator
	var target: RTSUnit = setup.target
	var events := {"damage": 0, "shots": 0}
	target.combat.health.damaged.connect(func(_amount: float, _source: Node) -> void:
		events.damage += 1
		generator.operational = false
		powered.refresh_power()
		# Hold this exact committed tick for cooldown/status inspection; other
		# power checks advance unpowered simulated time normally.
		battery.set_physics_process(false)
	)
	battery.weapon.fired.connect(func(_target: Node3D, _projectile: GuidedProjectile) -> void: events.shots += 1)
	battery.set_physics_process(true)
	if not await _until(func() -> bool: return events.damage == 1, 2.0, "actual defensive shot reaches a synchronous generator-loss damage listener"):
		return
	_check(target.combat.health.current == 82 and battery.weapon.shots_fired == 1 and battery.weapon.cooldown_remaining == 0.75 and events.shots == 1, "post-commit power loss preserves exactly one real18-damage shot, notification and committed cooldown")
	_check(_grid_is(1, 0, 3) and battery.target_actor() == null and battery.status_text() == "No power", "post-shot controller preserves current No power status after its damage listener cleared the target")


func _scan_match_result() -> void:
	var setup := await _boundary_fixture()
	var battery: GroundDefenseBattery = setup.battery
	var target: RTSUnit = setup.target
	var angle := battery.turret.rotation.y
	var events := {"count": 0}
	battery.status_changed.connect(func() -> void:
		var candidate := battery.target_actor()
		if candidate != null and events.count == 0:
			events.count += 1
			# Explicit result fixture, never evidence of a defensive shot.
			powered.enemy_headquarters.health.apply_damage(10000)
			powered.resolve_result()
	)
	battery.set_physics_process(true)
	await _frames(45)
	_check(events.count == 1 and powered.result == BaseAssaultField.Result.VICTORY, "ordinary HQ result resolver runs synchronously inside acquisition notification")
	_check(battery.weapon.shots_fired == 0 and target.combat.health.current == target.combat.health.maximum and battery.turret.rotation.y == angle, "result during scan suppresses current shot and turret command")
	var scans := battery.acquisition_scans
	await physics_frame
	battery._physics_process(1.0)
	var late := battery.weapon.try_fire(target)
	_check(not late and battery.acquisition_scans == scans and battery.weapon.shots_fired == 0, "direct late callbacks cannot bypass frozen match by relying on disabled processing")
	_check(powered.restart_match(), "Restart still admits after an acquisition-callback result")
	await _frames(10)
	field = current_scene as TestField
	_check(field is PowerAssaultField and (field as PowerAssaultField).result == BaseAssaultField.Result.RUNNING and not is_instance_valid(battery), "Restart destroys old scan source and constructs a clean active field")


func _scan_replacement(change: String) -> void:
	var setup := await _boundary_fixture()
	var battery: GroundDefenseBattery = setup.battery
	var target: RTSUnit = setup.target
	var angle := battery.turret.rotation.y
	var events := {"count": 0}
	var holder := Node3D.new()
	powered.add_child(holder)
	battery.status_changed.connect(func() -> void:
		var candidate := battery.target_actor()
		if candidate != null and events.count == 0:
			events.count += 1
			if change == "owner":
				battery.owner_id = 2
				battery.owner_id = 1
			else:
				battery.reparent(holder)
			battery.set_physics_process(false)
	)
	battery.set_physics_process(true)
	await _frames(35)
	_check(events.count == 1 and battery.owner_id == 1 and _grid_is(1, 10, 3), "acquisition listener restores owner without duplicating nominal demand")
	_check(battery.weapon.shots_fired == 0 and target.combat.health.current == target.combat.health.maximum and battery.turret.rotation.y == angle, "%s change invalidates the in-progress scan generation" % change)


func _invalid_ground_target() -> void:
	var setup := await _boundary_fixture()
	var battery: GroundDefenseBattery = setup.battery
	var target: RTSUnit = setup.target
	var holder := Node3D.new()
	powered.add_child(holder)
	target.reparent(holder)
	await _frames(3)
	await physics_frame
	battery.face_toward(target.global_position, 1000, 1) # Explicit boundary facing fixture.
	_check(battery.target_available(target), "same-field mobile reparent retains valid target before departure")
	holder.queue_free()
	_check(not battery.target_available(target) and not battery.weapon.try_fire(target) and battery.weapon.shots_fired == 0 and target.combat.health.current == 100, "queued target ancestor rejects current eligibility and final firing before deferred deletion")
	await _frames(3)
	_check(not is_instance_valid(target), "queued ancestor actually removes the old target")


func _scan_immediate_removal(victim: String) -> void:
	var setup := await _boundary_fixture()
	var battery: GroundDefenseBattery = setup.battery
	var target: RTSUnit = setup.target
	var owner := powered
	var events := {"count": 0, "damage": 0, "shots": 0}
	target.combat.health.damaged.connect(func(_amount: float, _source: Node) -> void: events.damage += 1)
	battery.weapon.fired.connect(func(_target: Node3D, _projectile: GuidedProjectile) -> void: events.shots += 1)
	battery.status_changed.connect(func() -> void:
		var candidate := battery.target_actor()
		if candidate != null and events.count == 0:
			events.count += 1
			match victim:
				# Godot locks a signal's emitting object. Queue this source here;
				# immediate source.free during target damage is tested separately.
				"source": battery.queue_free()
				"target": target.free()
				"field": owner.free()
	)
	battery.set_physics_process(true)
	await _frames(40)
	var removal := "queued source" if victim == "source" else "immediate " + victim
	_check(events.count == 1 and events.damage == 0 and events.shots == 0, "%s removal during scan is safe and cannot commit damage or success notification" % removal)
	if victim == "source":
		_check(not is_instance_valid(battery) and _grid_is(1, 10, 0), "removed scanning source retires nominal demand exactly once")
	elif victim == "target":
		_check(not is_instance_valid(target) and battery.target_actor() == null and battery.weapon.shots_fired == 0, "freed scan target is released without old references")
	else:
		_check(not is_instance_valid(owner) and not is_instance_valid(battery) and root.get_children().is_empty(), "field removal destroys scanning source and entire callback lifetime")
