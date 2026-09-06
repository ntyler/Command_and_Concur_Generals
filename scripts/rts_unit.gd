class_name RTSUnit
extends CharacterBody3D
## Identity and motion live here; selection membership belongs to SelectionController.

@export var unit_id: int = 0
@export var owner_id: int = 1
@export var movement_speed: float = 5.0
@export var stopping_distance: float = 0.22
@export var show_destination: bool = true

var agent: NavigationAgent3D
var selection_indicator: MeshInstance3D
var destination_indicator: MeshInstance3D
var selection_anchor: Marker3D
var assigned_destination: Vector3
var moving: bool = false
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
	agent.radius = 0.48
	agent.height = 1.2
	agent.max_speed = movement_speed
	# Units can pass one another. Solid crowd handling is separate from this
	# milestone's obstacle navigation and must not strand units behind parked peers.
	agent.avoidance_enabled = false
	add_child(agent)


func set_selected(selected: bool) -> void:
	selection_indicator.visible = selected


func move_to(destination: Vector3) -> void:
	assigned_destination = destination
	agent.target_desired_distance = stopping_distance
	agent.max_speed = movement_speed
	agent.target_position = destination
	moving = true
	destination_indicator.global_position = destination + Vector3.UP * 0.055
	destination_indicator.visible = show_destination and OS.is_debug_build()


func _physics_process(delta: float) -> void:
	if NavigationServer3D.map_get_iteration_id(agent.get_navigation_map()) == 0:
		return
	if not moving:
		return
	var remaining := global_position.distance_to(assigned_destination)
	if remaining <= stopping_distance:
		_finish_move()
		return
	var next_point := agent.get_next_path_position()
	if agent.is_navigation_finished():
		_finish_move()
		return
	var direction := next_point - global_position
	direction.y = 0.0
	# Limit each step to its waypoint and target to prevent overshoot at low FPS.
	var speed := minf(movement_speed, minf(direction.length(), remaining) / delta)
	_move_on_navigation(direction.normalized() * speed, delta)


func _move_on_navigation(desired_velocity: Vector3, delta: float) -> void:
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


func _finish_move() -> void:
	moving = false
	velocity = Vector3.ZERO
	# Keep the debug marker at the assigned slot after arrival for inspection.


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
