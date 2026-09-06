class_name RTSUnit
extends CharacterBody3D
## Identity and motion live here; selection membership belongs to SelectionController.

@export var unit_id: int = 0
@export var owner_id: int = 1:
	set(value):
		if owner_id != value:
			owner_id = value
			availability_changed.emit()
@export var movement_speed: float = 5.0
@export var stopping_distance: float = 0.22
@export var show_destination: bool = true

signal availability_changed
@export_group("Combat (optional)")
@export var combat_weapon: WeaponDefinition
@export var maximum_health: float = 100.0
@export var retaliation_enabled: bool = false
var combat: CombatController
var gameplay_field: TestField

enum MovementState { ARRIVED, TRAVELLING, CONGESTED, RECOVERING, FAILED }
signal movement_state_changed(state: MovementState)

@export_group("Crowd")
@export var crowd_enabled: bool = true:
	set(enabled):
		if crowd_enabled == enabled:
			return
		crowd_enabled = enabled
		if is_instance_valid(agent):
			_sync_crowd_mode()
@export_range(0.2, 0.8, 0.01) var avoidance_radius: float = 0.36
@export var neighbor_distance: float = 3.0
@export_range(1, 24) var max_neighbors: int = 10
@export var avoidance_horizon: float = 0.25
@export var settling_distance: float = 8.0
@export_range(0.2, 0.4, 0.01) var settling_radius: float = 0.24
@export var parked_radius: float = 0.34
@export_group("Progress and recovery")
@export var progress_window: float = 0.75
@export var meaningful_progress: float = 0.3
@export var stuck_after: float = 2.25
@export var recovery_interval: float = 2.5
@export var recovery_duration: float = 2.0
@export var recovery_radius: float = 2.2
@export var recovery_projection_slack: float = 0.35
@export var recovery_path_factor: float = 1.8
@export var recovery_waypoint_tolerance: float = 0.3
@export var recovery_priority: float = 0.65
@export_range(4, 24) var recovery_candidates: int = 12
@export_range(1, 16) var maximum_recoveries: int = 8
@export var command_timeout: float = 90.0

var agent: NavigationAgent3D
var selection_indicator: MeshInstance3D
var destination_indicator: MeshInstance3D
var selection_anchor: Marker3D
var assigned_destination: Vector3
var moving: bool = false
var movement_state: MovementState = MovementState.ARRIVED
var order_version: int = 0
var recovery_attempts: int = 0
var recovery_active: bool = false
var recovery_target: Vector3
var stalled_for: float = 0.0
var command_elapsed: float = 0.0
var last_recovery_time: float = -INF
var next_waypoint: Vector3
var movement_debug: bool = false
var waypoint_indicator: MeshInstance3D
var debug_label: Label3D
var _progress_elapsed: float = 0.0
var _progress_remaining: float = INF
var _recovery_elapsed: float = 0.0
var _submitted_order: int = -1
var _last_movement_frame: int = -1
var _debug_elapsed: float = 0.0
var _occupancy_query: PhysicsShapeQueryParameters3D
var _visual: Node3D


func _ready() -> void:
	add_to_group("controllable_units")
	collision_layer = 2
	collision_mask = 4
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	var collider := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.43
	shape.height = 1.3
	collider.shape = shape
	collider.position.y = 0.65
	add_child(collider)
	_visual = Node3D.new()
	add_child(_visual)
	_add_box(Vector3(0.85, 0.45, 1.1), Vector3(0, 0.52, 0), Color("42c5cc"))
	_add_box(Vector3(0.55, 0.22, 0.55), Vector3(0, 0.85, 0.1), Color("b3e7df"))
	_add_box(Vector3(0.22, 0.32, 1.25), Vector3(-0.5, 0.28, 0), Color("263c49"))
	_add_box(Vector3(0.22, 0.32, 1.25), Vector3(0.5, 0.28, 0), Color("263c49"))
	_add_box(Vector3(0.48, 0.09, 0.15), Vector3(0, 0.8, -0.42), Color("ffd680"))
	selection_anchor = Marker3D.new()
	selection_anchor.position.y = 0.6
	add_child(selection_anchor)
	selection_indicator = _ring(0.85, 0.98, Color("86ffcb"))
	selection_indicator.position.y = 0.045
	add_child(selection_indicator)
	selection_indicator.hide()
	destination_indicator = _ring(0.2, 0.29, Color("ffce78"))
	add_child(destination_indicator)
	destination_indicator.top_level = true
	destination_indicator.hide()
	agent = NavigationAgent3D.new()
	agent.name = "NavigationAgent3D"
	agent.path_desired_distance = 0.3
	agent.target_desired_distance = stopping_distance
	agent.path_max_distance = 2.0
	agent.radius = avoidance_radius
	agent.height = 1.2
	agent.max_speed = 0.0
	agent.neighbor_distance = neighbor_distance
	agent.max_neighbors = max_neighbors
	agent.time_horizon_agents = avoidance_horizon
	agent.avoidance_priority = 1.0
	add_child(agent)
	agent.velocity_computed.connect(_on_avoidance_velocity)
	_sync_crowd_mode()
	assigned_destination = global_position
	next_waypoint = global_position
	_occupancy_query = PhysicsShapeQueryParameters3D.new()
	var occupancy_shape := SphereShape3D.new()
	occupancy_shape.radius = settling_radius
	_occupancy_query.shape = occupancy_shape
	_occupancy_query.collision_mask = 2
	_occupancy_query.exclude = [get_rid()]
	waypoint_indicator = _ring(0.1, 0.19, Color("8ac7ff"))
	add_child(waypoint_indicator)
	waypoint_indicator.top_level = true
	debug_label = Label3D.new()
	debug_label.position.y = 1.7
	debug_label.font_size = 24
	debug_label.pixel_size = 0.012
	debug_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	debug_label.no_depth_test = true
	add_child(debug_label)
	set_movement_debug(false)
	if combat_weapon != null:
		combat = CombatController.new()
		combat.unit = self
		combat.retaliation_enabled = retaliation_enabled
		add_child(combat)
		if combat_weapon.mode == WeaponDefinition.Mode.HITSCAN:
			_visual.scale = Vector3(0.65, 1.2, 0.65)


func set_selected(selected: bool) -> void:
	selection_indicator.visible = selected


func _sync_crowd_mode() -> void:
	# One public property owns both movement paths, including live Inspector edits.
	_submitted_order = -1
	velocity = Vector3.ZERO
	agent.velocity = Vector3.ZERO
	agent.set_velocity_forced(Vector3.ZERO)
	agent.avoidance_enabled = crowd_enabled


func is_alive() -> bool:
	return combat == null or (is_instance_valid(combat.health) and combat.health.is_alive())


func move_to(destination: Vector3, combat_pursuit: bool = false) -> bool:
	if not is_alive() or not is_inside_tree() or is_queued_for_deletion():
		return false
	if combat != null and not TeamRules.is_combat_member(gameplay_field, self):
		return false
	var combat_version: int = -1
	if combat != null and not combat_pursuit:
		combat_version = combat.prepare_order(CombatController.PlayerCommand.MOVE)
	order_version += 1
	var moving_order := order_version
	_submitted_order = -1
	velocity = Vector3.ZERO
	agent.velocity = Vector3.ZERO
	agent.set_velocity_forced(Vector3.ZERO)
	recovery_attempts = 0
	recovery_active = false
	recovery_target = Vector3.ZERO
	_recovery_elapsed = 0.0
	stalled_for = 0.0
	command_elapsed = 0.0
	last_recovery_time = -INF
	_progress_elapsed = 0.0
	assigned_destination = destination
	_progress_remaining = _remaining_path_length()
	agent.target_desired_distance = stopping_distance
	agent.max_speed = movement_speed
	agent.avoidance_priority = 0.5
	agent.radius = settling_radius if global_position.distance_to(destination) < settling_distance else avoidance_radius
	agent.target_position = destination
	next_waypoint = global_position
	moving = true
	destination_indicator.global_position = destination + Vector3.UP * 0.055
	destination_indicator.visible = show_destination and movement_debug
	# Listeners may synchronously replace this order. Do not write after emission.
	_set_state(MovementState.TRAVELLING)
	if combat_version >= 0 and order_version == moving_order:
		combat.publish_state(combat_version)
	return true


func retarget_pursuit(destination: Vector3) -> bool:
	# Refresh one existing movement order; player orders still use move_to().
	if not moving or not is_inside_tree() or is_queued_for_deletion() or not is_alive():
		return false
	if not TeamRules.is_combat_member(gameplay_field, self):
		return false
	# Carry signed progress/debt across the changed distance metric. Both path
	# queries use this same position, so target movement itself earns no progress.
	# Keeping debt also prevents back-and-forth motion resetting the stall clock.
	var old_remaining := _remaining_path_length()
	var progress := _progress_remaining - old_remaining if is_finite(_progress_remaining) and is_finite(old_remaining) else 0.0
	var was_repath := recovery_active and recovery_target == assigned_destination
	assigned_destination = destination
	_progress_remaining = _remaining_path_length() + progress
	_submitted_order = -1
	# A genuine detour retains its waypoint, priority and expiry. A fallback
	# repath follows the refreshed destination without becoming a new attempt.
	if was_repath:
		recovery_target = destination
	if not recovery_active or was_repath:
		agent.target_position = destination
		next_waypoint = global_position
	destination_indicator.global_position = destination + Vector3.UP * 0.055
	return true


func halt_motion() -> void:
	# Internal stop at the current navigable position, also used for death cleanup.
	if not is_inside_tree() or not is_instance_valid(agent):
		return
	order_version += 1
	assigned_destination = global_position
	recovery_attempts = 0
	command_elapsed = 0.0
	last_recovery_time = -INF
	_progress_remaining = 0.0
	agent.set_velocity_forced(Vector3.ZERO)
	if destination_indicator.is_inside_tree():
		destination_indicator.global_position = assigned_destination + Vector3.UP * 0.055
	_finish_move()


func stop() -> bool:
	if not is_alive() or not is_inside_tree() or is_queued_for_deletion():
		return false
	if combat != null:
		return combat.issue_stop()
	halt_motion()
	return true


func face_toward(point: Vector3, radians_per_second: float, delta: float) -> void:
	var direction := point - global_position
	if direction.length_squared() > 0.000001:
		_visual.rotation.y = rotate_toward(_visual.rotation.y, atan2(-direction.x, -direction.z), radians_per_second * delta)


func facing_error(point: Vector3) -> float:
	var direction := point - global_position
	return absf(angle_difference(_visual.rotation.y, atan2(-direction.x, -direction.z)))


func _physics_process(delta: float) -> void:
	if NavigationServer3D.map_get_iteration_id(agent.get_navigation_map()) == 0:
		return
	if not moving:
		agent.velocity = Vector3.ZERO
		_update_debug(delta)
		return
	var processing_order := order_version
	command_elapsed += delta
	if command_elapsed >= command_timeout:
		_fail_move()
		return
	var remaining := global_position.distance_to(assigned_destination)
	# Permit brief shoulder contact when threading between already parked peers.
	# Final slots never move, and the larger idle radius is restored at arrival.
	agent.radius = settling_radius if remaining < settling_distance or stalled_for >= progress_window or recovery_active else avoidance_radius
	if remaining <= stopping_distance:
		_finish_move()
		return
	_update_progress(delta)
	if not moving or order_version != processing_order:
		return
	if recovery_active:
		_recovery_elapsed += delta
		if global_position.distance_to(recovery_target) <= recovery_waypoint_tolerance or _recovery_elapsed >= recovery_duration:
			_clear_recovery()
			if not moving or order_version != processing_order:
				return
	next_waypoint = agent.get_next_path_position()
	# A finished path alone is not proof of arrival at the assigned final slot.
	var direction := next_waypoint - global_position
	direction.y = 0.0
	# Limit each step to its waypoint and target to prevent overshoot at low FPS.
	var speed := minf(movement_speed, minf(direction.length(), remaining) / delta)
	var desired := direction.normalized() * speed
	if crowd_enabled:
		_submitted_order = order_version
		agent.velocity = desired
	else:
		_move_on_navigation(desired, delta)
	_update_debug(delta)


func _on_avoidance_velocity(safe_velocity: Vector3) -> void:
	if crowd_enabled and agent.avoidance_enabled and moving and _submitted_order == order_version:
		_move_on_navigation(safe_velocity.limit_length(movement_speed), get_physics_process_delta_time())


func _move_on_navigation(desired_velocity: Vector3, delta: float) -> void:
	# A mode change after an avoidance callback must not move again in this tick.
	var frame := Engine.get_physics_frames()
	if _last_movement_frame == frame:
		return
	_last_movement_frame = frame
	# Keep every step on the clearance mesh, including turns at polygon corners.
	var proposed := global_position + desired_velocity * delta
	var navigable := NavigationServer3D.map_get_closest_point(agent.get_navigation_map(), proposed)
	velocity = (navigable - global_position) / delta
	velocity.y = 0.0
	move_and_slide()
	# This deterministic field is flat. Physical walls plus mesh clearance protect obstacles.
	global_position.y = 0.0
	if velocity.length_squared() > 0.05:
		_visual.rotation.y = lerp_angle(_visual.rotation.y, atan2(-velocity.x, -velocity.z), 0.25)


func _finish_move(final_state: MovementState = MovementState.ARRIVED) -> void:
	moving = false
	velocity = Vector3.ZERO
	_submitted_order = -1
	recovery_active = false
	recovery_target = Vector3.ZERO
	_recovery_elapsed = 0.0
	_progress_elapsed = 0.0
	stalled_for = 0.0
	agent.velocity = Vector3.ZERO
	agent.max_speed = 0.0
	agent.radius = parked_radius
	agent.avoidance_priority = 1.0
	agent.target_position = assigned_destination
	next_waypoint = global_position
	_set_state(final_state)


func _update_progress(delta: float) -> void:
	_progress_elapsed += delta
	if _progress_elapsed < progress_window:
		return
	# Displacement alone mistakes crowd oscillation for progress. Sample remaining
	# navigable distance to the immutable final slot, including obstacle detours.
	var remaining := _remaining_path_length()
	var progress := _progress_remaining - remaining
	var sample_elapsed := _progress_elapsed
	_progress_elapsed = 0.0
	if progress >= meaningful_progress:
		_progress_remaining = remaining
		stalled_for = 0.0
		if recovery_active:
			_clear_recovery()
		else:
			_set_state(MovementState.TRAVELLING)
		return
	stalled_for += sample_elapsed
	var sampled_order := order_version
	if not recovery_active:
		_set_state(MovementState.CONGESTED)
		if order_version != sampled_order or not moving:
			return
	if stalled_for >= stuck_after and command_elapsed - last_recovery_time >= recovery_interval:
		if recovery_attempts >= maximum_recoveries:
			_fail_move()
		else:
			_recover()


func _remaining_path_length() -> float:
	var path := NavigationServer3D.map_get_path(agent.get_navigation_map(), global_position, assigned_destination, true)
	if path.is_empty():
		return INF
	var length: float = 0.0
	for segment in range(1, path.size()):
		length += path[segment - 1].distance_to(path[segment])
	return length


func _recover() -> void:
	var recovering_order := order_version
	recovery_attempts += 1
	last_recovery_time = command_elapsed
	recovery_active = true
	_recovery_elapsed = 0.0
	agent.avoidance_priority = recovery_priority
	var map := agent.get_navigation_map()
	var forward := (assigned_destination - global_position).normalized()
	var best := global_position
	var best_score: float = INF
	# A bounded local detour query, only on recovery. Never teleport: the same
	# NavigationAgent and collision-constrained movement travel to this waypoint.
	for index in recovery_candidates:
		var angle := TAU * float(index) / recovery_candidates
		var proposed := global_position + forward.rotated(Vector3.UP, angle) * recovery_radius
		var candidate := NavigationServer3D.map_get_closest_point(map, proposed)
		if candidate.distance_to(proposed) > recovery_projection_slack or candidate.distance_to(global_position) < recovery_radius * 0.6:
			continue
		_occupancy_query.transform.origin = candidate + Vector3.UP * 0.6
		if not get_world_3d().direct_space_state.intersect_shape(_occupancy_query, 1).is_empty():
			continue
		var ray := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 0.6, candidate + Vector3.UP * 0.6, 2 | 4, [get_rid()])
		if not get_world_3d().direct_space_state.intersect_ray(ray).is_empty():
			continue
		var path := NavigationServer3D.map_get_path(map, global_position, candidate, true)
		if path.is_empty() or path[path.size() - 1].distance_to(candidate) > 0.1:
			continue
		var length: float = 0.0
		for segment in range(1, path.size()):
			length += path[segment - 1].distance_to(path[segment])
		if length > recovery_radius * recovery_path_factor:
			continue
		var score := candidate.distance_to(assigned_destination) + length * 0.2
		if score < best_score:
			best_score = score
			best = candidate
	# If no detour fits, a rate-limited repath/priority adjustment is still useful.
	recovery_target = assigned_destination if best == global_position else best
	agent.target_position = recovery_target
	next_waypoint = global_position
	_set_state(MovementState.RECOVERING)
	if order_version != recovering_order:
		return # A synchronous replacement owns all state from this point onward.


func _clear_recovery() -> void:
	recovery_active = false
	recovery_target = Vector3.ZERO
	_recovery_elapsed = 0.0
	agent.target_position = assigned_destination
	agent.avoidance_priority = 0.5
	next_waypoint = global_position
	_set_state(MovementState.TRAVELLING)


func _fail_move() -> void:
	_finish_move(MovementState.FAILED)


func _set_state(state: MovementState) -> void:
	if movement_state != state:
		movement_state = state
		movement_state_changed.emit(state)


func set_movement_debug(enabled: bool) -> void:
	movement_debug = enabled
	destination_indicator.visible = enabled and show_destination and order_version > 0
	waypoint_indicator.visible = enabled
	debug_label.visible = enabled
	_update_debug(1.0)


func _update_debug(delta: float) -> void:
	if not movement_debug:
		return
	_debug_elapsed += delta
	if _debug_elapsed < 0.1:
		return
	_debug_elapsed = 0.0
	waypoint_indicator.global_position = next_waypoint + Vector3.UP * 0.07
	debug_label.text = "%02d %s\nwait %.1f  retry %d/%d" % [unit_id, MovementState.keys()[movement_state], stalled_for, recovery_attempts, maximum_recoveries]


func _add_box(size: Vector3, offset: Vector3, color: Color) -> void:
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	visual.mesh = mesh
	visual.position = offset
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.85
	visual.material_override = material
	_visual.add_child(visual)


func _ring(inner: float, outer: float, color: Color) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner
	mesh.outer_radius = outer
	mesh.rings = 32
	mesh.ring_segments = 6
	visual.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	visual.material_override = material
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return visual
