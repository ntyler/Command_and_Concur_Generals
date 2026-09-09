class_name AttackHelicopter
extends RTSUnit
## A sphere-centred hovering actor. Identity/combat/selection stay in RTSUnit;
## only locomotion uses the supported flat flight plane instead of ground nav.

const FLIGHT_BODY_RADIUS: float = 0.5
const FLIGHT_WORLD_MASK: int = 1 | 2 | 4 | 8
const FLIGHT_SKIN: float = 0.001

signal takeoff_cleared

@export_group("Flight")
@export var cruise_altitude: float = 8.0
@export var ground_datum: float = 0.0
@export var takeoff_speed: float = 4.0
@export var flight_body_radius: float = FLIGHT_BODY_RADIUS
@export var horizontal_turn_speed: float = 3.0
@export var local_spacing: float = 1.5
@export var spacing_lookahead: float = 0.3

var takeoff_blocked: bool = false
var _taking_off: bool = false
var _takeoff_started: bool = false
var _flight_query: PhysicsShapeQueryParameters3D
var _rotor: Node3D
var _ground_marker: MeshInstance3D


func _init() -> void:
	movement_speed = 8.0
	maximum_health = 180.0
	unit_display_name = "Attack Helicopter"
	damageable = true


static func flight_body_shape(radius: float = FLIGHT_BODY_RADIUS) -> SphereShape3D:
	var shape := SphereShape3D.new()
	shape.radius = radius
	return shape


func _ready() -> void:
	crowd_enabled = false
	super._ready()
	# Retain one selectable body on layer 2, replacing the ground capsule with
	# exactly the sphere used for launch occupancy and every flight sweep.
	for child in get_children():
		if child is CollisionShape3D:
			child.shape = flight_body_shape(flight_body_radius)
			child.position = Vector3.ZERO
	collision_mask = FLIGHT_WORLD_MASK
	agent.avoidance_enabled = false
	selection_anchor.position = Vector3.ZERO
	selection_indicator.position.y = -0.4
	_flight_query = PhysicsShapeQueryParameters3D.new()
	_flight_query.shape = flight_body_shape(flight_body_radius)
	_flight_query.margin = FLIGHT_SKIN
	_flight_query.collision_mask = FLIGHT_WORLD_MASK
	_flight_query.collide_with_areas = false
	_flight_query.exclude = [get_rid()]
	_ground_marker = _ring(0.36, 0.43, Color(0.18, 0.30, 0.32, 0.6))
	var material := _ground_marker.material_override as StandardMaterial3D
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	add_child(_ground_marker)
	_ground_marker.top_level = true
	_ground_marker.global_position = Vector3(global_position.x, ground_datum + 0.065, global_position.z)
	if is_instance_valid(combat):
		combat.turn_speed = horizontal_turn_speed
		combat.feedback.health_bar.position.y = 0.9
		combat.feedback.health_label.position.y = 1.65


func _build_visual() -> void:
	# The fuselage is inside the authoritative radius; rotor/tail are decoration.
	_add_box(Vector3(0.56, 0.4, 0.72), Vector3.ZERO, Color("42c5cc"))
	_add_box(Vector3(0.48, 0.22, 0.3), Vector3(0, 0.06, -0.26), Color("b3e7df"))
	_add_box(Vector3(0.13, 0.14, 0.78), Vector3(0, 0.04, 0.6), Color("42c5cc"))
	_add_box(Vector3(0.58, 0.055, 0.18), Vector3(0, 0.08, 0.86), Color("ffd680"))
	_add_box(Vector3(0.08, 0.08, 0.66), Vector3(-0.3, -0.27, 0.01), Color("263c49"))
	_add_box(Vector3(0.08, 0.08, 0.66), Vector3(0.3, -0.27, 0.01), Color("263c49"))
	_rotor = Node3D.new()
	_rotor.position.y = 0.3
	_visual.add_child(_rotor)
	var blade := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(1.75, 0.035, 0.11)
	blade.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("263c49")
	blade.material_override = material
	_rotor.add_child(blade)


func is_airborne_unit() -> bool:
	return true # Deployment is AIR from its first registered takeoff frame.


func is_taking_off() -> bool:
	return _taking_off


func can_fire_weapon() -> bool:
	return is_inside_tree() and not _taking_off and TeamRules.is_combat_member(gameplay_field, self) and is_alive() and absf(global_position.y - flight_plane_y()) <= 0.01


func flight_plane_y() -> float:
	return ground_datum + cruise_altitude


func weapon_origin() -> Vector3:
	return global_position + Vector3(0, -0.15, 0)


func weapon_attachment() -> Vector3:
	return global_position


func aim_position() -> Vector3:
	return global_position


func begin_takeoff() -> void:
	# No signal/callback at deployment commit, and no second launch is possible.
	if _takeoff_started or not is_inside_tree() or not is_alive() or not TeamRules.is_combat_member(gameplay_field, self):
		return
	_takeoff_started = true
	_taking_off = true
	takeoff_blocked = false


func flight_destination(point: Vector3) -> Vector3:
	if not point.is_finite():
		return point
	var bounds := gameplay_field.field_bounds if is_instance_valid(gameplay_field) else TestField.MAP_BOUNDS
	var inset := flight_body_radius + FLIGHT_SKIN
	return Vector3(clampf(point.x, bounds.position.x + inset, bounds.end.x - inset), flight_plane_y(), clampf(point.z, bounds.position.y + inset, bounds.end.y - inset))


func flight_destination_valid(point: Vector3) -> bool:
	if not point.is_finite() or not is_instance_valid(gameplay_field):
		return false
	var destination := flight_destination(point)
	if absf(point.x - destination.x) > 0.00001 or absf(point.z - destination.z) > 0.00001:
		return false
	# Inputs run outside physics too. Bounds are always authoritative; a static
	# volume is checked here when available and again on every physical step.
	if Engine.is_in_physics_frame() and _flight_query != null:
		_flight_query.transform = Transform3D(Basis.IDENTITY, destination)
		_flight_query.motion = Vector3.ZERO
		_flight_query.collision_mask = 1 | 4 | 8
		var blocked := not get_world_3d().direct_space_state.intersect_shape(_flight_query, 1).is_empty()
		_flight_query.collision_mask = FLIGHT_WORLD_MASK
		if blocked:
			return false
	return true


func flight_pursuit_destination(target: Node3D, attack_range: float, range_fraction: float) -> Vector3:
	var vertical := absf(flight_plane_y() - target.global_position.y)
	var horizontal := sqrt(maxf(0.0, attack_range * attack_range - vertical * vertical)) * clampf(range_fraction, 0.0, 0.95)
	var away := global_position - target.global_position
	away.y = 0.0
	if away.length_squared() < 0.000001:
		away = Vector3.BACK
	return flight_destination(target.global_position + away.normalized() * horizontal)


func move_to(destination: Vector3, combat_pursuit: bool = false, preserve_attack_move: bool = false) -> bool:
	if not is_alive() or not is_inside_tree() or is_queued_for_deletion() or not TeamRules.is_combat_member(gameplay_field, self):
		return false
	var flight_goal := flight_destination(destination)
	if not flight_destination_valid(flight_goal):
		return false
	var combat_version := -1
	if is_instance_valid(combat) and not combat_pursuit:
		combat_version = combat.prepare_order(CombatController.PlayerCommand.MOVE, preserve_attack_move)
	order_version += 1
	var moving_order := order_version
	assigned_destination = flight_goal
	next_waypoint = flight_goal
	velocity = Vector3.ZERO
	command_elapsed = 0.0
	stalled_for = 0.0
	recovery_attempts = 0
	recovery_active = false
	moving = true
	destination_indicator.global_position = flight_goal
	destination_indicator.visible = show_destination and movement_debug
	_set_state(MovementState.TRAVELLING)
	if is_instance_valid(self) and is_instance_valid(combat) and combat_version >= 0 and order_version == moving_order:
		combat.publish_state(combat_version)
	return true


func retarget_pursuit(destination: Vector3) -> bool:
	if not moving or not is_alive() or not TeamRules.is_combat_member(gameplay_field, self):
		return false
	var flight_goal := flight_destination(destination)
	if not flight_destination_valid(flight_goal):
		return false
	assigned_destination = flight_goal
	next_waypoint = flight_goal
	destination_indicator.global_position = flight_goal
	return true


func halt_motion() -> void:
	# Stop replaces pending travel but cannot cancel a collision-safe climb.
	if not is_inside_tree():
		return
	order_version += 1
	assigned_destination = flight_destination(global_position)
	next_waypoint = assigned_destination
	command_elapsed = 0.0
	recovery_attempts = 0
	_finish_move()


func _finish_move(final_state: MovementState = MovementState.ARRIVED) -> void:
	moving = false
	velocity = Vector3.ZERO
	stalled_for = 0.0
	recovery_active = false
	next_waypoint = global_position
	_set_state(final_state)


func suspend_navigation() -> void:
	# Construction changes only the ground mesh; flight never waits on its bake.
	pass


func resume_navigation() -> void:
	pass


func _remaining_path_length() -> float:
	return global_position.distance_to(assigned_destination)


func face_toward(point: Vector3, radians_per_second: float, delta: float) -> void:
	var direction := point - global_position
	direction.y = 0.0
	if direction.length_squared() > 0.000001:
		_visual.rotation.y = rotate_toward(_visual.rotation.y, atan2(-direction.x, -direction.z), minf(horizontal_turn_speed, radians_per_second) * delta)


func facing_error(point: Vector3) -> float:
	var direction := point - global_position
	direction.y = 0.0
	if direction.length_squared() <= 0.000001:
		return 0.0
	return absf(angle_difference(_visual.rotation.y, atan2(-direction.x, -direction.z)))


func _physics_process(delta: float) -> void:
	if not TeamRules.is_combat_member(gameplay_field, self) or not is_alive():
		return
	if is_instance_valid(_rotor):
		_rotor.rotation.y = fmod(_rotor.rotation.y + delta * 32.0, TAU)
	_ground_marker.global_position = Vector3(global_position.x, ground_datum + 0.065, global_position.z)
	if _taking_off:
		_process_takeoff(delta)
		return
	if not moving:
		velocity = Vector3.ZERO
		_update_debug(delta)
		return
	command_elapsed += delta
	if command_elapsed >= command_timeout:
		_finish_move(MovementState.FAILED)
		return
	var direction := assigned_destination - global_position
	direction.y = 0.0
	var remaining := direction.length()
	if remaining <= stopping_distance:
		_finish_move()
		return
	var version := order_version
	var desired := _spaced_velocity(direction.normalized(), remaining, delta)
	var next := flight_destination(global_position + desired * delta)
	next.y = global_position.y # Only the takeoff responsibility changes altitude.
	# This path changes the actual body transform, never just its visual mesh.
	var moved := _swept_step(next - global_position)
	velocity = moved / delta
	if moved.length_squared() > 0.000001:
		face_toward(global_position + moved, horizontal_turn_speed, delta)
		stalled_for = 0.0
	else:
		stalled_for += delta
		_set_state(MovementState.CONGESTED)
		if not is_instance_valid(self) or version != order_version:
			return
	_update_debug(delta)


func _process_takeoff(delta: float) -> void:
	var remaining := flight_plane_y() - global_position.y
	if remaining > 0.00001:
		var step := Vector3.UP * minf(remaining, maxf(0.0, takeoff_speed) * delta)
		var moved := _swept_step(step)
		velocity = moved / delta
		takeoff_blocked = moved.y + 0.00001 < step.y
		return
	velocity = Vector3.ZERO
	takeoff_blocked = false
	_taking_off = false
	# No writes after callbacks: a clearance listener can replace the order,
	# destroy the producer, retire the aircraft, or end the whole match.
	takeoff_cleared.emit()


func _spaced_velocity(forward: Vector3, remaining: float, delta: float) -> Vector3:
	var desired := forward
	var lookahead := maxf(local_spacing, flight_body_radius * 2.0 + movement_speed * spacing_lookahead)
	for other in gameplay_field.units:
		if other == self or not is_instance_valid(other) or not other is AttackHelicopter or not other.is_alive():
			continue
		var offset := other.global_position - global_position
		if absf(offset.y) >= flight_body_radius + other.flight_body_radius:
			continue
		offset.y = 0.0
		var distance := offset.length()
		if distance >= lookahead or distance <= 0.00001:
			continue
		var ahead := offset.dot(forward)
		var lateral := (offset - forward * ahead).length()
		if ahead > 0.0 and lateral < maxf(local_spacing, flight_body_radius + other.flight_body_radius + FLIGHT_SKIN):
			# A stable right-hand bias lets a small group pass a parked peer;
			# reciprocal headings choose opposite world sides. No parked drift.
			var right := Vector3(-forward.z, 0, forward.x)
			desired += right * (1.0 - distance / lookahead) * 2.5
		if distance < local_spacing:
			desired -= offset.normalized() * (1.0 - distance / local_spacing)
	return desired.normalized() * minf(movement_speed, remaining / delta)


func _swept_step(motion: Vector3) -> Vector3:
	if motion.length_squared() <= 0.000000000001 or not Engine.is_in_physics_frame():
		return Vector3.ZERO
	var start := global_position
	_flight_query.transform = Transform3D(Basis.IDENTITY, start)
	_flight_query.motion = Vector3.ZERO
	_flight_query.collision_mask = FLIGHT_WORLD_MASK
	var space := get_world_3d().direct_space_state
	# Godot cast_motion ignores already overlapping shapes; always probe first.
	if not space.intersect_shape(_flight_query, 1).is_empty():
		return Vector3.ZERO
	_flight_query.motion = motion
	var fractions := space.cast_motion(_flight_query)
	if fractions.size() != 2:
		return Vector3.ZERO
	var fraction := fractions[0]
	# Registry transforms close the broad-phase's same-tick update window.
	for other in gameplay_field.units:
		if other == self or not is_instance_valid(other) or not other is AttackHelicopter or not other.is_alive():
			continue
		fraction = minf(fraction, _peer_safe_fraction(start, motion, other.global_position, flight_body_radius + other.flight_body_radius + FLIGHT_SKIN * 2.0))
	var accepted := motion * maxf(0.0, fraction - (FLIGHT_SKIN / motion.length() if fraction < 1.0 else 0.0))
	_flight_query.motion = Vector3.ZERO
	_flight_query.transform.origin = start + accepted
	if not space.intersect_shape(_flight_query, 1).is_empty():
		return Vector3.ZERO
	global_position = start + accepted
	return accepted


static func _peer_safe_fraction(start: Vector3, motion: Vector3, center: Vector3, radius: float) -> float:
	var offset := start - center
	var a := motion.length_squared()
	var b := 2.0 * offset.dot(motion)
	var c := offset.length_squared() - radius * radius
	if c <= 0.0:
		return 1.0 if b >= 0.0 else 0.0
	var discriminant := b * b - 4.0 * a * c
	if discriminant < 0.0:
		return 1.0
	var contact := (-b - sqrt(discriminant)) / (2.0 * a)
	return contact if contact >= 0.0 and contact <= 1.0 else 1.0
