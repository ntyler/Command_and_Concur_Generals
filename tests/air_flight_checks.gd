extends "res://tests/milestone_checks.gd"
## Explicit free fixtures isolate flight geometry/commands; economic production
## and the normal starting forces belong to the separate air integration suite.

const HELICOPTER: PackedScene = preload("res://scenes/attack_helicopter.tscn")
var _air_id: int = 800
var _last_peak_speed: float = 0.0
var _last_min_spacing: float = INF
var _last_altitude_error: float = 0.0
var _crossed_ground_obstacle: bool = false


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1280, 720)
	var logger := EngineErrorProbe.new()
	OS.add_logger(logger)
	await _takeoff_checks()
	await _flight_checks()
	await _flight_group_checks()
	await _flight_replacement_checks()
	if is_instance_valid(field):
		field.queue_free()
	await _frames(6)
	_check(root.get_children().is_empty() and get_nodes_in_group("combat_projectiles").is_empty(), "flight teardown removes actors, controllers, projectiles and top-level markers")
	OS.remove_logger(logger)
	_check(logger.error_count() == 0, "flight commands, shape sweeps and teardown have no native errors or warnings")
	print("AIR_FLIGHT_CHECKS: %d checks, %d failures; native_errors=%d" % [checks, failures, logger.error_count()])
	quit(0 if failures == 0 else 1)


func _fresh_flight() -> void:
	if is_instance_valid(field):
		field.queue_free()
		await _frames(5)
	field = load("res://scenes/test_field.tscn").instantiate() as TestField
	root.add_child(field)
	current_scene = field
	field.camera_rig.edge_scrolling_enabled = false
	for actor in field.units.duplicate():
		actor.queue_free()
	await _frames(5)
	_check(field.units.is_empty(), "isolated flight fixture removes original ground crowd without changing shared resources")


func _air(point: Vector3, owner: int = 1) -> AttackHelicopter:
	var actor := HELICOPTER.instantiate() as AttackHelicopter
	_air_id += 1
	actor.unit_id = _air_id
	actor.owner_id = owner
	actor.position = point
	field.add_child(actor)
	field.register_unit(actor)
	return actor


func _flight_ground(point: Vector3, owner: int = 1) -> RTSUnit:
	var actor := load("res://scenes/rifle_unit.tscn").instantiate() as RTSUnit
	_air_id += 1
	actor.unit_id = _air_id
	actor.owner_id = owner
	actor.position = point
	field.add_child(actor)
	field.register_unit(actor)
	return actor


func _air_wall(point: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "IsolatedFlightBlocker"
	body.collision_layer = 4 | 8
	body.collision_mask = 0
	body.position = point
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	body.add_child(collider)
	field.add_child(body)
	return body


func _takeoff_checks() -> void:
	await _fresh_flight()
	var actor := _air(Vector3(-17, 2.08, 14))
	var target := _flight_ground(Vector3(-13, 0, 14), 2)
	await _frames(2)
	var shapes := actor.get_children().filter(func(child: Node) -> bool: return child is CollisionShape3D)
	_check(shapes.size() == 1 and shapes[0].shape is SphereShape3D and is_equal_approx(shapes[0].shape.radius, 0.5) and shapes[0].position == Vector3.ZERO, "actual aircraft collision is one radius-0.5 sphere centred on gameplay body")
	_check(actor.maximum_health == 180.0 and actor.movement_speed == 8.0 and actor.takeoff_speed == 4.0 and actor.cruise_altitude == 8.0 and actor.horizontal_turn_speed == 3.0, "aircraft scene keeps exact configurable flight and health defaults")
	var clearances := [0]
	actor.takeoff_cleared.connect(func() -> void: clearances[0] += 1)
	actor.begin_takeoff()
	_check(actor.is_taking_off() and TeamRules.target_domain(actor) == TeamRules.TargetDomain.AIR, "deployed actor is AIR from the first real takeoff frame")
	_check(actor.move_to(Vector3(-5, 0, 14)), "takeoff accepts a pending movement destination")
	await _frames(18)
	_check(actor.global_position.y > 2.08 and actor.global_position.y < 4.0 and Vector2(actor.global_position.x, actor.global_position.z) == Vector2(-17, 14), "body visibly climbs at bounded speed before horizontal travel")
	_check(not actor.can_fire_weapon() and actor.combat.weapon.shots_fired == 0, "takeoff is authoritatively gated from firing")
	_check(actor.move_to(Vector3(-17, 0, -15)) and actor.assigned_destination == Vector3(-17, 8, -15), "new takeoff movement replaces the pending post-climb goal")
	_check(actor.combat.issue_attack(target), "valid explicit attack can replace a pending takeoff move")
	await _frames(2)
	_check(actor.is_taking_off() and actor.combat.weapon.shots_fired == 0 and actor.combat.target_actor() == target, "pending takeoff attack keeps its target but fires no rocket")
	actor.begin_takeoff()
	_check(actor.stop() and not actor.moving and actor.combat.target_actor() == null, "Stop clears the pending attack and motion without cancelling safe takeoff")
	await _sample_air([actor], 2.0)
	_check(not actor.is_taking_off() and clearances[0] == 1 and is_equal_approx(actor.global_position.y, 8.0), "one takeoff finishes at actual cruise altitude with one clearance notification")
	_check(_last_peak_speed <= 4.001 and Vector2(actor.global_position.x, actor.global_position.z) == Vector2(-17, 14) and not actor.moving, "stopped aircraft completes only its bounded climb then hovers")
	actor.begin_takeoff()
	await _frames(3)
	_check(not actor.is_taking_off() and clearances[0] == 1, "duplicate launch requests cannot restart takeoff or emit duplicate clearance")
	var hover := actor.global_position
	await _sample_air([actor], 0.5)
	_check(actor.global_position == hover and actor.can_fire_weapon(), "cruise hover has no drift and is eligible to fire")
	target.queue_free()
	var roof := _air_wall(Vector3(-23, 5, 16), Vector3(3, 1, 3))
	var blocked := _air(Vector3(-23, 2.08, 16))
	blocked.begin_takeoff()
	await _sample_air([blocked], 1.2)
	_check(blocked.is_taking_off() and blocked.takeoff_blocked and blocked.global_position.y < 4.001, "a real overhead solid blocks the swept takeoff sphere before roof penetration")
	_check(not blocked.can_fire_weapon(), "blocked takeoff cannot fire")
	roof.queue_free()
	await _sample_air([blocked], 1.5)
	_check(not blocked.is_taking_off() and is_equal_approx(blocked.global_position.y, 8.0), "blocked climb resumes safely when the actual obstruction departs")
	await _capture("m15-flight-takeoff")


func _flight_checks() -> void:
	await _fresh_flight()
	var actor := _air(Vector3(-16, 8, -1))
	await _frames(2)
	_check(actor.selection_anchor.global_position == actor.global_position and LineOfFire.aim(actor) == actor.global_position, "selection and weapon aim agree with actual elevated sphere centre")
	_check(actor.move_to(Vector3(-1, 0, -1)), "air accepts a ground-point destination as a cruise-plane goal")
	await _sample_air([actor], 2.5)
	_check(_crossed_ground_obstacle and actor.global_position.distance_to(Vector3(-1, 8, -1)) <= actor.stopping_distance, "body flies directly over a ground-nav obstacle without a ground detour")
	_check(_last_peak_speed <= 8.001 and _last_altitude_error < 0.00001 and absf(actor.global_position.z + 1) < 0.00001, "horizontal flight retains true altitude and an eight-units-per-second bound")
	_check(not actor.moving and actor.movement_state == RTSUnit.MovementState.ARRIVED, "flight arrival stops and reports the existing arrived state")
	var hover := actor.global_position
	await _sample_air([actor], 0.5)
	_check(actor.global_position == hover, "arrived flight position remains stable")
	_check(actor.move_to(Vector3(1000, 0, 1000)), "direct flight command clamps an exterior destination inside map bounds")
	_check(actor.assigned_destination.x <= field.field_bounds.end.x - 0.5 and actor.assigned_destination.z <= field.field_bounds.end.y - 0.5, "clamped centre retains radius clearance from both map boundaries")
	await _sample_air([actor], 7.0)
	_check(not actor.moving and field.field_bounds.grow(-0.5).has_point(Vector2(actor.global_position.x, actor.global_position.z)) and _last_peak_speed <= 8.001, "bounded flight reaches the map edge without any body escaping")
	actor.global_position = Vector3(-10, 8, -15) # Labelled relocation for obstruction fixture.
	var wall := _air_wall(Vector3(-4, 8, -15), Vector3(1, 3, 6))
	await _frames(2)
	_check(actor.move_to(Vector3(3, 0, -15)), "air can hold an otherwise valid destination beyond a newly inserted flight-plane wall")
	await _sample_air([actor], 1.5)
	_check(actor.global_position.x < -5.0 and actor.movement_state == RTSUnit.MovementState.CONGESTED and _last_peak_speed <= 8.001, "world shape sweeps stop the body at a flight-plane wall instead of passing through")
	wall.queue_free()
	await _sample_air([actor], 2.0)
	_check(not actor.moving and actor.global_position.distance_to(Vector3(3, 8, -15)) <= actor.stopping_distance, "existing flight goal resumes after its real world obstruction is removed")
	await _capture("m15-flight-obstacle")


func _flight_group_checks() -> void:
	await _fresh_flight()
	var first := _air(Vector3(-20, 8, 14))
	var second := _air(Vector3(-20, 8, 17))
	var third := _air(Vector3(-17, 8, 14))
	var ground := _flight_ground(Vector3(-20, 0, 14))
	await _frames(3)
	field.selection.select_clicked(first, false)
	field.selection.select_clicked(second, true)
	field.selection.select_clicked(third, true)
	field.selection.select_clicked(ground, true)
	var result := field.issue_move(Vector3(-7, 0, 16))
	_check(result.is_complete() and result.accepted_ids.size() == 4 and result.assignments.size() == 4, "mixed movement reports all accepted members and captured assignments")
	_check(result.assignments[ground.unit_id].y == 0.0 and result.assignments[first.unit_id].y == 8.0 and result.assignments[second.unit_id].y == 8.0 and result.assignments[third.unit_id].y == 8.0, "mixed order preserves navigable ground slots and corresponding flight slots")
	_check(result.assignments[first.unit_id].distance_to(result.assignments[second.unit_id]) >= 1.49 and result.assignments[first.unit_id].distance_to(result.assignments[third.unit_id]) >= 1.49 and result.assignments[second.unit_id].distance_to(result.assignments[third.unit_id]) >= 1.49, "three-aircraft command supplies distinct sphere-clear destination slots")
	await _sample_air([first, second, third], 5.0)
	_check(not first.moving and not second.moving and not third.moving and _last_min_spacing >= 0.999, "supported three-aircraft movement arrives without overlapping real bodies")
	_check(_last_peak_speed <= 8.001 and _last_altitude_error < 0.00001 and absf(ground.global_position.y) < 0.00001, "mixed movement preserves speed bounds and each actor's physical altitude")
	_check(first.global_position.distance_to(result.assignments[first.unit_id]) <= first.stopping_distance and second.global_position.distance_to(result.assignments[second.unit_id]) <= second.stopping_distance and third.global_position.distance_to(result.assignments[third.unit_id]) <= third.stopping_distance, "each aircraft reaches its own immutable captured assignment")
	var positions := [first.global_position, second.global_position, third.global_position]
	await _sample_air([first, second, third], 0.75)
	_check(first.global_position == positions[0] and second.global_position == positions[1] and third.global_position == positions[2], "local spacing leaves arrived aircraft hovering at their assigned positions")
	await _capture("m15-flight-mixed")


func _flight_replacement_checks() -> void:
	await _fresh_flight()
	var actor := _air(Vector3(-20, 8, 14))
	var ground := _flight_ground(Vector3(-20, 0, 14))
	await _frames(2)
	_check(actor.move_to(Vector3(20, 0, 14)), "long flight starts through the normal unit movement API")
	await _sample_air([actor], 0.4)
	_check(actor.move_to(Vector3(-20, 0, -14)), "replacement flight is accepted while an older goal is active")
	var replacement := actor.assigned_destination
	await _sample_air([actor], 4.0)
	_check(not actor.moving and actor.global_position.distance_to(replacement) <= actor.stopping_distance and actor.assigned_destination == replacement, "replacement reaches its goal without a stale path restoring the old destination")
	field.selection.select_clicked(actor, false)
	field.selection.select_clicked(ground, true)
	actor.movement_state_changed.connect(func(state: RTSUnit.MovementState) -> void:
		if state == RTSUnit.MovementState.TRAVELLING:
			field.issue_stop()
	, CONNECT_ONE_SHOT)
	var result := field.issue_move(Vector3(10, 0, 15))
	_check(result.superseded and result.accepted_ids.has(actor.unit_id) and result.assignments[actor.unit_id].y == 8.0, "mixed batch records historical air acceptance when a callback supersedes dispatch")
	await _frames(2)
	_check(not actor.moving and not ground.moving, "callback Stop retains authority over both movement domains")
	_check(actor.attack_move.issue(Vector3(-20, 0, 10), Vector3(-20, 8, 10), 999, 1), "air Attack Move accepts a cruise slot without ground navigation projection")
	await _sample_air([actor], 0.3)
	_check(actor.stop() and not actor.attack_move.active, "Stop cancels the same attack-move parent used by ground units")
	var stopped := actor.global_position
	await _sample_air([actor], 0.3)
	_check(actor.global_position == stopped and not actor.moving, "stopped flight cannot be restored by an attack-move callback")
	var launching := _air(Vector3(-24, 2.08, 17))
	launching.begin_takeoff()
	launching.move_to(Vector3(20, 0, 17))
	actor.move_to(Vector3(20, 0, -14))
	await _frames(3)
	field.gameplay_enabled = false
	var frozen_air := actor.global_position
	var frozen_launch := launching.global_position
	var shots := actor.combat.weapon.shots_fired
	await _frames(30)
	_check(actor.global_position == frozen_air and launching.global_position == frozen_launch and launching.is_taking_off(), "match gate freezes both cruise motion and in-progress real takeoff")
	_check(actor.combat.weapon.shots_fired == shots and not actor.move_to(Vector3.ZERO) and not launching.stop(), "frozen match suppresses shots and new aircraft commands")


func _sample_air(actors: Array[AttackHelicopter], seconds: float) -> void:
	_last_peak_speed = 0.0
	_last_min_spacing = INF
	_last_altitude_error = 0.0
	_crossed_ground_obstacle = false
	var ticks := ceili(seconds * Engine.physics_ticks_per_second)
	for _tick in ticks:
		var previous: Array[Vector3] = []
		for actor in actors:
			previous.append(actor.global_position)
		await physics_frame
		await process_frame
		for index in actors.size():
			var actor := actors[index]
			_last_peak_speed = maxf(_last_peak_speed, previous[index].distance_to(actor.global_position) * Engine.physics_ticks_per_second)
			if not actor.is_taking_off():
				_last_altitude_error = maxf(_last_altitude_error, absf(actor.global_position.y - actor.flight_plane_y()))
			for obstacle in field.obstacles:
				_crossed_ground_obstacle = _crossed_ground_obstacle or obstacle.has_point(Vector2(actor.global_position.x, actor.global_position.z))
			for other in range(index + 1, actors.size()):
				_last_min_spacing = minf(_last_min_spacing, actor.global_position.distance_to(actors[other].global_position))
