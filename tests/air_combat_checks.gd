extends "res://tests/fixtures/defense_harness.gd"
## Isolated target/weapon fixtures use declared starting actors and power bodies.
## They exercise ordinary firing/health; the earned air suite proves purchases.

const AIR_DEFENSE: ConstructionDefinition = preload("res://construction/air_defense_battery.tres")
const HELICOPTER_WEAPON: WeaponDefinition = preload("res://weapons/helicopter_rocket.tres")

class ChangingDomainTarget extends RTSUnit:
	var in_air: bool = false
	func is_airborne_unit() -> bool:
		return in_air

class AirBoundaryQuery extends LineOfFire:
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
		if argument.begins_with("--air-combat-case="): chosen = argument.trim_prefix("--air-combat-case=")
	var cases := ["matrix", "pursuit", "counter", "geometry", "impact", "boundary"]
	_check(chosen == "all" or cases.has(chosen), "recognized air combat case")
	for case in cases:
		if chosen != "all" and chosen != case: continue
		var before := checks
		var failed := failures
		match case:
			"matrix": await _air_matrix()
			"pursuit": await _air_pursuit()
			"counter": await _air_counter()
			"geometry": await _air_geometry()
			"impact": await _air_impact()
			"boundary": await _air_boundary()
		print("AIR_COMBAT_CASE: %s checks=%d failures=%d" % [case, checks - before, failures - failed])
	if is_instance_valid(field): field.queue_free()
	await _frames(6)
	_check(root.get_children().is_empty() and get_nodes_in_group("combat_projectiles").is_empty(), "air combat teardown removes all actors/projectiles")
	OS.remove_logger(logger)
	_check(logger.error_count() == 0, "air combat physics/callbacks have no native errors or warnings")
	print("AIR_COMBAT_CHECKS: %d checks, %d failures; native_errors=%d" % [checks, failures, logger.error_count()])
	quit(0 if failures == 0 else 1)


func _air_actor(point: Vector3, owner: int = 1) -> AttackHelicopter:
	var actor := AttackHelicopter.new()
	_defense_next_id += 1
	actor.unit_id = _defense_next_id
	actor.owner_id = owner
	actor.combat_weapon = HELICOPTER_WEAPON
	actor.position = point
	actor.retaliation_enabled = false
	defended.add_child(actor)
	defended.register_unit(actor)
	return actor


func _air_battery(owner: int = 1, point: Vector3 = DEFENSE_POINT) -> GroundDefenseBattery:
	var battery := GroundDefenseBattery.new()
	battery.name = "DeclaredAirDefenseFixture"
	battery.owner_id = owner
	battery.kind = AIR_DEFENSE.kind
	battery.definition = AIR_DEFENSE
	battery.footprint = AIR_DEFENSE.footprint
	battery.building_height = AIR_DEFENSE.height
	battery.recipe = null
	battery.position = point
	defended.add_child(battery)
	defended.register_building(battery)
	return battery


func _air_matrix() -> void:
	await _fresh_defense()
	var source := _air_actor(Vector3(-20, 8, 16))
	var hostile_air := _air_actor(Vector3(-15, 8, 16), 2)
	var ground := _defense_mobile(Vector3(-15, 0, 16))
	var rifle := _defense_mobile(Vector3(-20, 0, 16), 1)
	var rocket := _defense_mobile(Vector3(-21, 0, 16), 1, "rocket")
	var building := _power_fixture_building(POWER_BARRACKS, 2, Vector3(-8, 0, 16))
	var battery := _defense_fixture(1, Vector3(-18, 0, 7))
	var aa := _air_battery(1, Vector3(-26, 0, 10))
	_power_fixture_building(POWER_PLANT, 1, SECOND)
	battery.set_physics_process(false)
	aa.set_physics_process(false)
	await _frames(3)
	_check(HELICOPTER_WEAPON.is_valid() and HELICOPTER_WEAPON.damage == 24 and HELICOPTER_WEAPON.attack_range == 12 and HELICOPTER_WEAPON.cooldown == 1.5 and HELICOPTER_WEAPON.projectile_speed == 12 and HELICOPTER_WEAPON.projectile_lifetime == 6 and HELICOPTER_WEAPON.projectile_collision_radius == 0.1, "helicopter guided weapon retains all exact prototype defaults")
	_check(TeamRules.target_domain(source) == TeamRules.TargetDomain.AIR and TeamRules.target_domain(ground) == TeamRules.TargetDomain.GROUND and TeamRules.target_domain(aa) == TeamRules.TargetDomain.GROUND, "actual helicopter is AIR and legacy units/new ground building remain GROUND")
	_check(TeamRules.can_attack(defended, source, ground) and TeamRules.can_attack(defended, source, building) and TeamRules.can_attack(defended, rifle, aa) == false, "helicopter accepts hostile ground unit/building; friendly building rejected")
	_check(not TeamRules.can_attack(defended, source, hostile_air) and not TeamRules.can_attack(defended, rifle, hostile_air) and not TeamRules.can_attack(defended, rocket, hostile_air), "helicopter/rifle/rocket ground weapons all reject AIR through shared authority")
	_check(not battery.target_available(hostile_air) and battery.target_available(ground) and not battery.target_available(building), "Ground Defense stays hostile ground-mobile-only")
	_check(aa.target_available(hostile_air) and not aa.target_available(ground) and not aa.target_available(building) and not aa.target_available(source), "AA targets only hostile AIR and rejects ground/friendly AIR")
	_check(rifle.combat.issue_attack(ground), "valid prior Rifle ground attack accepted")
	var prior_version := rifle.combat.order_version
	_check(not rifle.combat.issue_attack(hostile_air) and rifle.combat.order_version == prior_version and rifle.combat.target_actor() == ground, "rejected explicit AIR attack preserves Rifle prior order/version")
	_check(source.move_to(Vector3(-23, 8, 16)), "prior flight movement accepted")
	var prior_destination := source.assigned_destination
	var flight_version := source.order_version
	_check(not source.combat.issue_attack(hostile_air) and source.order_version == flight_version and source.assigned_destination == prior_destination, "rejected helicopter AIR attack preserves flight order")
	source.stop()
	rifle.stop()
	rifle.combat.retaliation_enabled = true
	rifle.combat._on_damaged(1.0, hostile_air)
	_check(rifle.combat.target_actor() == null, "retaliation applies the same ground/AIR exclusion")
	await physics_frame
	var notifications := {"count": 0}
	rifle.combat.weapon.fired.connect(func(_target: Node3D, _projectile: GuidedProjectile) -> void: notifications.count += 1)
	_check(not rifle.combat.weapon.try_fire(hostile_air) and not rocket.combat.weapon.try_fire(hostile_air) and not source.combat.weapon.try_fire(hostile_air) and not aa.weapon.try_fire(ground) and notifications.count == 0, "direct emitters authoritatively reject wrong-domain shots without success events")
	var detached := AttackHelicopter.new()
	_check(not TeamRules.can_attack(defended, aa, detached), "unregistered aircraft cannot become an AA target")
	detached.free()
	hostile_air.queue_free()
	_check(not TeamRules.can_attack(defended, aa, hostile_air), "queued/departed AIR target rejected immediately")
	# Bounded automatic acquisition excludes AIR even when it is the nearer actor.
	var new_air := _air_actor(Vector3(-20, 8, 14), 2)
	_check(source.attack_move.issue(Vector3(-20, 0, 18), Vector3(-20, 8, 18), 700, 1), "helicopter Q accepts a cruise-altitude slot")
	await physics_frame
	_check(source.attack_move._nearest_candidate() != new_air, "attack-move automatic acquisition excludes hostile AIR")
	var blocked_slot := Vector3(-23, 8, 18)
	var blocker := _vehicle_wall(Vector3(1, 1, 1), blocked_slot)
	await _frames(2)
	await physics_frame
	var parent_generation := source.attack_move._generation
	var parent_slot := source.attack_move.final_slot
	_check(not source.attack_move.issue(Vector3(-23, 0, 18), blocked_slot, 701, 1) and source.attack_move._generation == parent_generation and source.attack_move.final_slot == parent_slot, "direct Q API rejects obstructed flight destination before changing prior parent order")
	blocker.queue_free()
	source.stop()


func _air_pursuit() -> void:
	await _fresh_defense()
	var source := _air_actor(Vector3(-25, 8, 17))
	var target := _defense_mobile(Vector3(-10, 0, 17))
	var initial := source.global_position
	var fired := {"projectile": null, "resolved": 0, "damage": 0.0}
	source.combat.weapon.fired.connect(func(_target: Node3D, projectile: GuidedProjectile) -> void:
		fired.projectile = projectile
		projectile.resolved.connect(func(amount: float) -> void:
			fired.resolved += 1
			fired.damage += amount))
	_check(source.combat.issue_attack(target), "helicopter accepts distant hostile ground pursuit")
	if not await _until(func() -> bool: return fired.projectile != null, 8, "flight pursuit reaches real 3D range and normally launches guided rocket"): return
	_check(source.global_position.y == 8 and source.global_position.distance_to(initial) > 2 and source.global_position.distance_to(target.global_position) <= 12 and absf(source._visual.rotation.x) < 0.0001, "pursuit moves actual aircraft at cruise height into 3D range with horizontal-only body facing")
	_check(target.combat.health.current == 100 and source.combat.weapon.shots_fired == 1 and source.combat.weapon.cooldown_remaining > 0, "normal launch commits one cooldown before delayed damage")
	var projectile := fired.projectile as GuidedProjectile
	_check(is_instance_valid(projectile) and projectile.global_position.y > 6 and projectile.source_team == 1 and projectile.target_actor() == target, "real elevated rocket captures original target and ownership")
	source.stop()
	source.queue_free()
	if not await _until(func() -> bool: return fired.resolved == 1, 3, "committed rocket continues after source Stop/deletion"): return
	_check(fired.damage == 24 and target.combat.health.current == 76, "one normal helicopter rocket applies exactly24 delayed damage")
	await _frames(60)
	_check(fired.resolved == 1 and target.combat.health.current == 76, "terminal rocket resolves and damages exactly once")


func _air_counter() -> void:
	await _fresh_defense()
	var aa := _air_battery()
	var plant := _power_fixture_building(POWER_PLANT, 1, SECOND)
	var target := _air_actor(Vector3(-11, 8, 16), 2)
	var base_pose := aa.global_transform
	_check(AIR_DEFENSE.maximum_health == 600 and AIR_DEFENSE.power_required == 3 and AIR_DEFENSE.credit_cost == 800 and AIR_DEFENSE.duration == 12 and AIR_DEFENSE.acquisition_interval == 0.25 and AIR_DEFENSE.turret_turn_speed == 3 and aa.weapon.definition.damage == 30 and aa.attack_range == 16 and aa.weapon.definition.cooldown == 1, "AA definition retains exact construction/health/power/acquisition/yaw-pitch/weapon defaults")
	if not await _until(func() -> bool: return aa.weapon.shots_fired == 1, 3, "powered AA acquires, rotates upward and damages actual airborne helicopter"): return
	_check(target.combat.health.current == 150 and aa.turret.rotation.x > 0.1 and aa.facing_error(target.global_position) <= deg_to_rad(8) and aa.global_transform == base_pose, "AA delivers30 after upward aim while the base remains stationary")
	_check(aa.weapon.last_fire_line.is_clear() and _grid_is(1, 10, 3), "AA shot obeys real line of fire and same-owner ordinary grid")
	var cooldown := aa.weapon.cooldown_remaining
	plant.queue_free()
	_check(not aa.source_authorized() and aa.weapon.cooldown_remaining == cooldown and _grid_is(1, 0, 3), "ordinary Power Plant loss disables AA and keeps committed cooldown/nominal idle demand")
	await _frames(20)
	_check(aa.weapon.shots_fired == 1 and aa.target_actor() == null and target.combat.health.current == 150 and aa.weapon.cooldown_remaining > 0, "low power permits no future shots and cooldown continues in simulated time")
	cooldown = aa.weapon.cooldown_remaining
	_power_fixture_building(POWER_PLANT, 1, SECOND)
	_check(aa.source_authorized() and aa.weapon.cooldown_remaining == cooldown, "power restoration does not reset or erase remaining cooldown")
	await _frames(5)
	_check(aa.weapon.shots_fired == 1 and target.combat.health.current == 150, "restoration cannot fire a catch-up shot before remaining cooldown")
	if not await _until(func() -> bool: return aa.weapon.shots_fired == 2, 2, "restored AA resumes normal cadence"): return
	_check(target.combat.health.current == 120 and aa.global_transform == base_pose, "restored AA delivers exactly one further30-damage shot")
	var rifle := _defense_mobile(DEFENSE_POINT + Vector3(6, 0, 0), 2)
	var helicopter := _air_actor(DEFENSE_POINT + Vector3(6, 8, 0), 2)
	_check(TeamRules.can_attack(defended, rifle, aa) and TeamRules.can_attack(defended, helicopter, aa), "ordinary hostile ground force and helicopter may attack the AA ground building")
	var target_ref: WeakRef = weakref(target)
	await _until(func() -> bool: return not is_instance_valid(target_ref.get_ref()), 6, "ordinary powered AA shots destroy actual airborne target without crash damage")


func _air_geometry() -> void:
	await _fresh_defense()
	var source := _air_actor(Vector3(-20, 8, 16))
	var target := _defense_mobile(Vector3(-14, 0, 16))
	# Explicit 10-high test wall is outside the normal scenario's supported plane.
	var wall := _vehicle_wall(Vector3(0.4, 10, 4), Vector3(-17, 5, 16))
	_check(source.combat.issue_attack(target), "blocked explicit aerial ground attack is still an accepted intent")
	await _frames(90)
	_check(source.combat.state == CombatController.State.BLOCKED and source.combat.target_actor() == target and source.combat.weapon.shots_fired == 0 and target.combat.health.current == 100, "solid aerial line blocks real weapon; explicit attack retains target without firing")
	wall.queue_free()
	if not await _until(func() -> bool: return source.combat.weapon.shots_fired == 1, 2, "removing world obstruction allows normal elevated launch"): return
	source.stop()
	var flight: GuidedProjectile
	for candidate in get_nodes_in_group("combat_projectiles"):
		if candidate is GuidedProjectile: flight = candidate
	_check(is_instance_valid(flight), "a normally launched guided projectile exists before test-wall insertion")
	if flight == null: return
	var outcome := {"count": 0, "type": GuidedProjectile.Outcome.NONE}
	flight.resolved.connect(func(_damage: float) -> void:
		outcome.count += 1
		outcome.type = flight.outcome)
	wall = _vehicle_wall(Vector3(0.4, 10, 4), Vector3(-17, 5, 16))
	if not await _until(func() -> bool: return outcome.count == 1, 2, "real spherical rocket sweep strikes newly inserted wall"): return
	_check(outcome.type == GuidedProjectile.Outcome.WORLD and target.combat.health.current == 100, "aerial projectile obeys world collision without roof/wall penetration or target damage")


func _air_impact() -> void:
	await _fresh_defense()
	var source := _air_actor(Vector3(-20, 8, 16))
	var target := ChangingDomainTarget.new()
	_defense_next_id += 1
	target.unit_id = _defense_next_id
	target.owner_id = 2
	target.damageable = true
	target.position = Vector3(-14, 0, 16)
	defended.add_child(target)
	defended.register_unit(target)
	target.set_physics_process(false)
	var terminal := {"count": 0, "damage": 0.0, "outcome": GuidedProjectile.Outcome.NONE}
	var launched := {"projectile": null}
	source.combat.weapon.fired.connect(func(_target: Node3D, projectile: GuidedProjectile) -> void:
		launched.projectile = projectile
		projectile.resolved.connect(func(amount: float) -> void:
			terminal.count += 1
			terminal.damage += amount
			terminal.outcome = projectile.outcome))
	_check(source.combat.issue_attack(target), "normal ground-eligible launch accepted for impact-domain fixture")
	if not await _until(func() -> bool: return launched.projectile != null, 3, "normal emitter creates rocket before target-domain change"): return
	source.stop()
	target.in_air = true # Deliberate authoritative-domain mutation fixture.
	if not await _until(func() -> bool: return terminal.count == 1, 2, "in-flight rocket rechecks current target domain"): return
	_check(terminal.outcome == GuidedProjectile.Outcome.INVALIDATED and terminal.damage == 0 and target.combat.health.current == 100, "captured ground-only launch cannot damage a target that changes to AIR")
	await _frames(10)
	_check(terminal.count == 1, "domain invalidation resolves once")


func _air_boundary() -> void:
	await _fresh_defense()
	var aa := _air_battery()
	_power_fixture_building(POWER_PLANT, 1, SECOND)
	var target := _air_actor(Vector3(-11, 8, 16), 2)
	aa.set_physics_process(false)
	var query := AirBoundaryQuery.new()
	defended.fire_query = query
	await _frames(3)
	await physics_frame
	aa.face_toward(target.global_position, 1000, 1)
	query.action = func() -> void: target.owner_id = 1
	query.armed = true
	_check(not aa.weapon.try_fire(target) and aa.weapon.shots_fired == 0 and aa.weapon.cooldown_remaining == 0 and target.combat.health.current == 180, "final AA firing rechecks hostile ownership after geometry callback")
	target.owner_id = 2
	query.action = func() -> void: target.queue_free()
	query.armed = true
	_check(not aa.weapon.try_fire(target) and aa.weapon.shots_fired == 0 and aa.weapon.cooldown_remaining == 0, "final AA firing rejects target deletion during geometry callback")
	await _frames(3)
	var alive := _air_actor(Vector3(-11, 8, 16), 2)
	await _frames(2)
	await physics_frame
	aa.face_toward(alive.global_position, 1000, 1)
	query.action = func() -> void:
		for building in defended.registered_buildings():
			if building.owner_id == 1 and building.kind == RTSBuilding.Kind.POWER_PLANT: building.queue_free()
	query.armed = true
	_check(not aa.weapon.try_fire(alive) and aa.weapon.shots_fired == 0 and aa.weapon.cooldown_remaining == 0 and alive.combat.health.current == 180, "post-query power loss rejects AA commitment with no damage/cooldown")
	var source := _air_actor(Vector3(-24, 8, 16))
	var changing := ChangingDomainTarget.new()
	_defense_next_id += 1
	changing.unit_id = _defense_next_id
	changing.owner_id = 2
	changing.damageable = true
	changing.position = Vector3(-18, 0, 16)
	defended.add_child(changing)
	defended.register_unit(changing)
	changing.set_physics_process(false)
	# The intended ground actor must be outside the AA footprint for a clear ray.
	changing.global_position = Vector3(-24, 0, 10)
	await _frames(3)
	await physics_frame
	source.face_toward(changing.global_position, 3, 10)
	query.action = func() -> void: changing.in_air = true
	query.armed = true
	_check(not source.combat.weapon.try_fire(changing) and not query.armed and source.combat.weapon.shots_fired == 0 and source.combat.weapon.cooldown_remaining == 0 and changing.combat.health.current == 100, "final helicopter firing rechecks target domain after clear geometry callback without projectile/event/cooldown")
