extends "res://tests/line_of_fire_checks.gd"
## Dimensions establish expected contacts; the production query is not duplicated.
## --sphere-baseline runs existing-API reproductions on the historical implementation.

var baseline: bool = false


func _run() -> void:
	root.size = Vector2i(1280, 800)
	baseline = OS.get_cmdline_user_args().has("--sphere-baseline")
	var logger := EngineErrorProbe.new()
	OS.add_logger(logger)
	for test_case in ["graze", "near_miss", "radius", "launch", "initial", "fast", "ordering", "lifecycle"]:
		var previous := checks
		var previous_failures := failures
		match test_case:
			"graze": await _volume_travel(0.06, 9.0, 0.1, true)
			"near_miss": await _volume_travel(0.16, 9.0, 0.1, false)
			"radius":
				if baseline:
					print("NOT_EXECUTED: configurable-radius API did not exist before this repair")
				else:
					await _radius_checks()
			"launch": await _launch_volume_checks()
			"initial": await _initial_volume_checks()
			"fast": await _volume_travel(0.06, 600.0, 0.1, true)
			"ordering": await _volume_ordering_checks()
			"lifecycle": await _volume_lifecycle_checks()
		print("SPHERE_CASE: %s; checks=%d; failures=%d" % [test_case, checks - previous, failures - previous_failures])
	if is_instance_valid(field): field.queue_free()
	await _frames(3)
	_check(get_nodes_in_group("combat_projectiles").is_empty() and get_nodes_in_group("combat_world_impacts").is_empty(), "sphere suite teardown leaves no projectile or impact nodes")
	OS.remove_logger(logger)
	_check(logger.error_count() == 0, "sphere suite and teardown have no native errors or warnings")
	print("SPHERICAL_PROJECTILE_CHECKS: %d checks, %d failures; native_errors=%d baseline=%s" % [checks, failures, logger.error_count(), baseline])
	quit(0 if failures == 0 else 1)


func _has_radius(definition: WeaponDefinition) -> bool:
	for property in definition.get_property_list():
		if property["name"] == "projectile_collision_radius": return true
	return false


func _definition(radius: float, speed: float = 9.0, life: float = 6.0) -> WeaponDefinition:
	var definition := LineOfFireField.ROCKET.duplicate() as WeaponDefinition
	if _has_radius(definition): definition.set("projectile_collision_radius", radius)
	definition.projectile_speed = speed
	definition.projectile_lifetime = life
	return definition


func _grazing_lane(gap: float) -> Array[RTSUnit]:
	var pair := await _lane(4)
	# Travel z=8; wall spans x=[-4,-3.98], z=[8+gap,10+gap].
	# The initial muzzle is four units before the wall, well outside overlap.
	_solid(Vector3(0.02, 2, 2), Vector3(-3.99, 1, 9 + gap), LineOfFire.BLOCKER_MASK)
	await _frames(3)
	await physics_frame
	_check(field.fire_query.firing_line(pair[0], pair[1]).is_clear(), "finite grazing wall misses the complete muzzle-to-aim centerline")
	return pair


func _volume_travel(gap: float, speed: float, radius: float, should_hit: bool) -> void:
	var pair := await _grazing_lane(gap)
	var source := pair[0]
	var target := pair[1]
	source.combat.weapon.definition = _definition(radius, speed)
	var rocket := await _launch(source, target) # Normal authoritative weapon launch.
	if rocket == null: return
	var observed := _observe(rocket)
	var terminal := {"center": Vector3.ZERO}
	rocket.resolved.connect(func(_amount: float) -> void: terminal["center"] = rocket.global_position)
	if not baseline:
		_check(is_equal_approx(float(rocket.get("collision_radius")), radius), "normally launched rocket copies the configured collision radius")
		_check(is_equal_approx((rocket.get_child(0) as MeshInstance3D).mesh.radius, radius), "flying sphere presentation shows its actual configured world-collision radius")
		# Changing the source resource after launch cannot resize the flying shot.
		source.combat.weapon.definition.set("projectile_collision_radius", 0.01)
	for frame in range(120):
		await physics_frame
		if observed["count"] > 0: break
	var expected := GuidedProjectile.Outcome.WORLD if should_hit else GuidedProjectile.Outcome.TARGET
	_check(observed["count"] == 1 and observed["outcome"] == expected and observed["terminal_coherent"], "radius-only path resolves expected exclusive outcome: gap=%.3f radius=%.3f speed=%.1f" % [gap, radius, speed])
	_check(target.combat.health.current == (150.0 if should_hit else 118.0) and observed["damage"] == (0.0 if should_hit else 32.0), "grazing volume blocks damage; a clear near miss delivers one normal hit")
	if should_hit:
		_check(terminal["center"].x < -4.0 and terminal["center"].x > -4.2 and absf(terminal["center"].z - 8.0) < 0.0001, "grazing sphere stops before the finite wall without shifting its centerline")
	if speed == 600:
		_check(speed / 60.0 > 0.02, "high-speed radius-only graze crosses more than the wall thickness in one tick")
	await _frames(15)
	_check(not is_instance_valid(rocket) and observed["count"] == 1 and get_nodes_in_group("combat_world_impacts").is_empty(), "normal flight and reentrant completion leave no active projectile or impact")


func _radius_checks() -> void:
	var definition := _definition(0.1)
	_check(_has_radius(definition) and definition.is_valid() and is_equal_approx(float(definition.get("projectile_collision_radius")), 0.1), "positive configured sphere radius is part of the production weapon resource")
	for invalid in [0.0, -0.1, INF, NAN]:
		definition.set("projectile_collision_radius", invalid)
		_check(not definition.is_valid(), "zero, negative and nonfinite projectile radius is rejected")
	await _volume_travel(0.08, 600.0, 0.04, false)
	await _volume_travel(0.08, 600.0, 0.12, true)


func _launch_volume_checks() -> void:
	var pair := await _lane(4)
	var source := pair[0]
	var target := pair[1]
	# Center z=8 stays outside; a radius .1 sphere overlaps the face at z=8.05.
	var wall := _solid(Vector3(1, 2, 1), Vector3(-8, 1, 8.55), LineOfFire.BLOCKER_MASK)
	await _frames(3)
	await physics_frame
	source.combat.set_physics_process(false)
	var weapon := source.combat.weapon
	var events := {"fires": 0}
	weapon.fired.connect(func(_victim: RTSUnit, _rocket: GuidedProjectile) -> void: events["fires"] += 1)
	_check(field.fire_query.firing_line(source, target).is_clear() and TeamRules.can_attack(field, source, target) and not source.moving and source.facing_error(target.global_position) < 0.001 and source.global_position.distance_to(target.global_position) < 11 and weapon.cooldown_remaining == 0, "launch fixture satisfies line, body attachment, range, facing, ownership and cooldown")
	var fired_any := false
	for attempt in range(100): fired_any = weapon.try_fire(target) or fired_any
	_check(not fired_any and weapon.shots_fired == 0 and weapon.cooldown_remaining == 0 and events["fires"] == 0 and get_nodes_in_group("combat_projectiles").is_empty() and target.combat.health.current == 150, "overlapping launch volume rejects normal API without damage, projectile, successful notification or cooldown")
	if not baseline:
		_check(weapon.last_fire_line.blocked and weapon.last_fire_line.collider_id == wall.get_instance_id(), "launch rejection returns actual sphere/blocker evidence")
		source.combat.set_physics_process(true)
		source.combat.issue_attack(target)
		await _frames(30)
		_check(source.combat.state == CombatController.State.BLOCKED and not source.moving and weapon.shots_fired == 0, "launch-volume obstruction uses ordinary blocked holding")
		var version := source.combat.order_version
		field.set_movement_debug(true)
		await _frames(2)
		var volume: MeshInstance3D = source.combat.feedback.get("_launch_volume")
		_check(is_instance_valid(volume) and volume.visible and is_equal_approx(volume.mesh.radius, 0.1), "F3 shows the configured launch sphere")
		field.camera_rig.position = source.global_position
		field.camera_rig.zoom = 20
		field.camera_rig.target_zoom = 20
		field.camera_rig._apply_zoom()
		await _capture("sphere_launch_volume")
		field.set_movement_debug(false)
		_check(not volume.visible, "debug launch volume hides without changing collision")
		wall.queue_free()
		await _frames(15)
		_check(weapon.shots_fired == 1 and source.combat.order_version == version and not source.combat.feedback.fire_blocked, "launch-volume clearance resumes the retained order within recheck scheduling")


func _collision_fixture(source: RTSUnit, target: RTSUnit, origin: Vector3, radius: float, speed: float, life: float) -> GuidedProjectile:
	# Isolated collision fixture with valid copied launch data, not a normal launch.
	var rocket := GuidedProjectile.new()
	rocket.configure(field, source, target, _definition(radius, speed, life))
	rocket.position = origin
	rocket.set_physics_process(false)
	field.add_child(rocket)
	return rocket


func _initial_volume_checks() -> void:
	var pair := await _grazing_lane(0.06)
	var origin := Vector3(-3.99, 0.8, 8)
	var rocket := _collision_fixture(pair[0], pair[1], origin, 0.1, 9, 6)
	var observed := _observe(rocket)
	rocket._physics_process(1.0 / 60.0)
	_check(observed["count"] == 1 and observed["outcome"] == GuidedProjectile.Outcome.WORLD and observed["terminal_coherent"] and pair[1].combat.health.current == 150, "isolated initial sphere overlap resolves WORLD safely with zero damage")
	_check(rocket.global_position == origin, "initial overlap resolves without first moving out of or through the blocker")
	await _frames(15)
	_check(not is_instance_valid(rocket) and get_nodes_in_group("combat_world_impacts").is_empty(), "initial-overlap collision fixture cleans up")


func _volume_ordering_checks() -> void:
	for fixture in ["world_first", "target_first", "tie", "world_before_expiry", "target_before_expiry", "world_after_expiry", "target_after_expiry", "target_at_expiry", "already_expired"]:
		var pair := await _lane(5)
		var target := pair[1]
		var origin := Vector3(16, 0.75, 12)
		var life := 6.0
		target.global_position = Vector3(20, 0, 12)
		match fixture:
			"target_first": target.global_position.x = 17
			"tie": target.global_position.x = 17.9 # Sphere front meets x=18 at target arrival.
			"world_before_expiry": life = 0.005 # World contact ~.00317s; full tick is .01667s.
			"target_before_expiry":
				target.global_position.x = 17
				life = 0.005
			"world_after_expiry": life = 0.001
			"target_after_expiry":
				target.global_position.x = 17
				life = 0.001
			"target_at_expiry":
				target.global_position.x = 17
				life = 1.0 / 600.0
			"already_expired": life = 0.001
		target.halt_motion()
		var rocket := _collision_fixture(pair[0], target, origin, 0.1, 600, life)
		var observed := _observe(rocket)
		if fixture == "already_expired": rocket.age = life
		rocket._physics_process(1.0 / 60.0)
		var expected := GuidedProjectile.Outcome.WORLD
		if fixture in ["target_first", "target_before_expiry", "target_at_expiry"]: expected = GuidedProjectile.Outcome.TARGET
		if fixture.ends_with("after_expiry") or fixture == "already_expired": expected = GuidedProjectile.Outcome.EXPIRED
		_check(observed["count"] == 1 and observed["outcome"] == expected and observed["terminal_coherent"], fixture + ": contact/target/lifetime ordering is exclusive")
		_check(target.combat.health.current == (118.0 if expected == GuidedProjectile.Outcome.TARGET else 150.0), fixture + ": only valid target arrival within lifetime applies damage")
		_check(rocket.age <= life and (rocket.age < life if fixture.ends_with("before_expiry") else true), fixture + ": no simulated lifetime overshoot")
		if fixture.ends_with("after_expiry"):
			_check(absf(rocket.global_position.x - 16.6) < 0.0001 and is_equal_approx(rocket.age, life), fixture + ": final partial tick travels exactly the remaining lifetime")
		if fixture == "already_expired":
			_check(rocket.global_position == origin and rocket.age == life, "already-expired projectile cannot move or damage")
		if expected == GuidedProjectile.Outcome.WORLD:
			_check(rocket.global_position.x <= 17.9 + 0.0001 and rocket.global_position.x >= 17.89, fixture + ": sphere center never passes its first blocking contact")
		await _frames(2)
		_check(not is_instance_valid(rocket) and observed["count"] == 1, fixture + ": terminal callback reentry cannot complete twice")


func _volume_lifecycle_checks() -> void:
	for change in ["source_death", "source_free", "target_detach", "target_free"]:
		var pair := await _grazing_lane(0.06)
		var source := pair[0]
		var target := pair[1]
		var rocket := await _launch(source, target)
		if rocket == null: continue
		var observed := _observe(rocket)
		match change:
			"source_death": source.combat.health.apply_damage(1000)
			"source_free": source.free()
			"target_detach": field.remove_child(target)
			"target_free": target.free()
		for frame in range(120):
			await physics_frame
			if observed["count"] > 0: break
		var expected := GuidedProjectile.Outcome.WORLD if change.begins_with("source") else GuidedProjectile.Outcome.INVALIDATED
		_check(observed["count"] == 1 and observed["outcome"] == expected and observed["damage"] == 0 and observed["terminal_coherent"], change + ": radius-only flight preserves lifecycle and exactly-once resolution")
		if is_instance_valid(target):
			_check(target.combat.health.current == 150, change + ": no spherical world/invalid impact damage")
		if change == "target_detach": target.free()
		await _frames(15)
		_check(not is_instance_valid(rocket) and get_nodes_in_group("combat_world_impacts").is_empty(), change + ": no projectile or impact remains")
