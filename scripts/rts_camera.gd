class_name RTSCamera
extends Node3D
## Fixed-angle perspective camera. Pan bounds constrain the ground focus.

@export var pan_speed: float = 23.0
@export var edge_scroll_speed: float = 19.0
@export var edge_margin: float = 18.0
@export var zoom_speed: float = 3.5
@export var minimum_zoom: float = 20.0
@export var maximum_zoom: float = 60.0
@export var smoothing: float = 12.0
@export var map_bounds: Rect2 = Rect2(-29.0, -23.0, 58.0, 46.0)
@export var edge_scrolling_enabled: bool = true

var camera: Camera3D
var zoom: float = 52.0
var target_zoom: float = 52.0
var pan_velocity: Vector2 = Vector2.ZERO
var gesture_active: bool = false
var _pointer: Vector2 = Vector2.ZERO
var _pointer_inside: bool = false
var _focused: bool = true


func _ready() -> void:
	camera = Camera3D.new()
	camera.name = "Camera3D"
	camera.fov = 55.0
	camera.far = 220.0
	add_child(camera)
	camera.current = true
	_apply_zoom()
	get_window().mouse_exited.connect(_on_mouse_exited)
	get_window().mouse_entered.connect(_on_mouse_entered)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_pointer = event.position
		_pointer_inside = get_viewport().get_visible_rect().has_point(_pointer)


func _unhandled_input(event: InputEvent) -> void:
	if pointer_over_interface() or not _focused:
		return
	if event.is_action_pressed("camera_zoom_in"):
		target_zoom = clampf(target_zoom - zoom_speed, minimum_zoom, maximum_zoom)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("camera_zoom_out"):
		target_zoom = clampf(target_zoom + zoom_speed, minimum_zoom, maximum_zoom)
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not _focused or pointer_over_interface():
		pan_velocity = Vector2.ZERO
		return
	var keyboard := Input.get_vector("camera_left", "camera_right", "camera_forward", "camera_back")
	var edge := Vector2.ZERO
	if edge_scrolling_enabled and _pointer_inside and not gesture_active:
		edge = edge_direction(_pointer, get_viewport().get_visible_rect())
	var desired := (keyboard * pan_speed + edge * edge_scroll_speed).limit_length(maxf(pan_speed, edge_scroll_speed))
	advance(delta, desired)


func advance(delta: float, desired_velocity: Vector2) -> void:
	# Exact integration of exponential velocity smoothing is independent of FPS.
	var weight := 1.0 - exp(-smoothing * delta)
	var displacement := desired_velocity * delta + (pan_velocity - desired_velocity) * weight / smoothing
	pan_velocity = pan_velocity.lerp(desired_velocity, weight)
	position.x = clampf(position.x + displacement.x, map_bounds.position.x, map_bounds.end.x)
	position.z = clampf(position.z + displacement.y, map_bounds.position.y, map_bounds.end.y)
	zoom = lerpf(zoom, target_zoom, weight)
	_apply_zoom()


func edge_direction(pointer: Vector2, viewport_rect: Rect2) -> Vector2:
	if not viewport_rect.has_point(pointer):
		return Vector2.ZERO
	var direction := Vector2.ZERO
	if pointer.x < viewport_rect.position.x + edge_margin:
		direction.x -= 1.0
	if pointer.x > viewport_rect.end.x - edge_margin:
		direction.x += 1.0
	if pointer.y < viewport_rect.position.y + edge_margin:
		direction.y -= 1.0
	if pointer.y > viewport_rect.end.y - edge_margin:
		direction.y += 1.0
	return direction.normalized()


func pointer_over_interface() -> bool:
	var hovered := get_viewport().gui_get_hovered_control()
	while hovered != null:
		if hovered.mouse_filter == Control.MOUSE_FILTER_STOP:
			return true
		hovered = hovered.get_parent_control()
	return get_viewport().gui_get_focus_owner() != null


func _apply_zoom() -> void:
	camera.position = Vector3(0.0, 0.8, 0.6) * zoom
	camera.rotation = Vector3(-atan2(0.8, 0.6), 0.0, 0.0)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_focused = false
		pan_velocity = Vector2.ZERO
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_focused = true


func _on_mouse_exited() -> void:
	_pointer_inside = false


func _on_mouse_entered() -> void:
	_pointer_inside = true
	_pointer = get_viewport().get_mouse_position()
