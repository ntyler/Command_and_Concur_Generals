class_name SelectionController
extends Node

signal selection_changed(count: int)
signal move_requested(destination: Vector3)
signal attack_requested(target: RTSUnit)
signal stop_requested

@export var friendly_owner_id: int = 1
@export var drag_threshold: float = 6.0

var camera_rig: RTSCamera
var gameplay_field: TestField
var selection_box: ReferenceRect
var _selected: Array[RTSUnit] = []
var _press_position: Vector2
var _current_position: Vector2
var _pressed: bool = false
var _dragging: bool = false
var _additive: bool = false
var _pending_picks: Array[Dictionary] = []


func _ready() -> void:
	get_window().mouse_exited.connect(cancel_gesture)


func selected_units() -> Array[RTSUnit]:
	_prune_selection()
	return _selected.duplicate()


func _input(event: InputEvent) -> void:
	# _input observes cancellation even when GUI consumes the eventual release.
	if event.is_action_pressed("cancel_selection"):
		cancel_gesture()
		_pending_picks.clear()
	if not _pressed:
		return
	if event is InputEventMouseMotion:
		_current_position = event.position
		if not _dragging and _press_position.distance_to(_current_position) >= drag_threshold:
			_dragging = true
		if _dragging:
			_update_rectangle()
	if event.is_action_released("select_units") and camera_rig.pointer_over_interface():
		cancel_gesture()


func _unhandled_input(event: InputEvent) -> void:
	# GUI gets first refusal. Pointer hover filters mouse commands, not an
	# otherwise unhandled keyboard Stop (a focused control can still consume it).
	if event.is_action_pressed("unit_stop") and not event.is_echo():
		cancel_gesture()
		_pending_picks.append({"kind": "stop"})
		get_viewport().set_input_as_handled()
		return
	if camera_rig.pointer_over_interface():
		return
	if event.is_action_pressed("select_units"):
		_pressed = true
		_dragging = false
		_press_position = (event as InputEventMouseButton).position
		_current_position = _press_position
		_additive = Input.is_action_pressed("selection_modifier") or (event as InputEventMouseButton).shift_pressed
		camera_rig.gesture_active = true
		get_viewport().set_input_as_handled()
	elif event.is_action_released("select_units") and _pressed:
		_current_position = (event as InputEventMouseButton).position
		# Also cover a release whose final motion event was coalesced by the OS.
		_dragging = _dragging or _press_position.distance_to(_current_position) >= drag_threshold
		if _dragging:
			select_rectangle(Rect2(_press_position, _current_position - _press_position).abs(), _additive)
		else:
			_pending_picks.append({"kind": "select", "position": _current_position, "additive": _additive})
		cancel_gesture()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("command_move"):
		cancel_gesture()
		_pending_picks.append({"kind": "move", "position": (event as InputEventMouseButton).position})
		get_viewport().set_input_as_handled()


func _physics_process(_delta: float) -> void:
	_prune_selection()
	# Ray queries belong to the physics tick; queued input keeps selection/command order.
	for request in _pending_picks:
		if request["kind"] == "stop":
			stop_requested.emit()
			continue
		var point: Vector2 = request["position"]
		if request["kind"] == "select":
			var hit := _raycast(point, 1 | 2 | 4)
			var unit: RTSUnit = hit.get("collider") as RTSUnit
			select_clicked(unit, request["additive"])
		elif not _selected.is_empty():
			var hit := _raycast(point, 1 | 2 | 4)
			if not hit.is_empty():
				var target := hit["collider"] as RTSUnit
				if target != null:
					if TeamRules.is_hostile_target(gameplay_field, friendly_owner_id, target):
						attack_requested.emit(target)
				elif (hit["collider"] as CollisionObject3D).collision_layer & 1:
					move_requested.emit(hit["position"])
	_pending_picks.clear()


func select_clicked(unit: RTSUnit, additive: bool) -> void:
	_prune_selection()
	if not _can_select(unit):
		if not additive:
			_clear()
	elif additive and _selected.has(unit):
		_selected.erase(unit)
		unit.set_selected(false)
	else:
		if not additive:
			_clear()
		_add(unit)
	selection_changed.emit(_selected.size())


func select_rectangle(rectangle: Rect2, additive: bool) -> void:
	if not additive:
		_clear()
	var normalized := rectangle.abs()
	for unit in gameplay_field.units:
		if not _can_select(unit):
			continue
		var anchor := unit.selection_anchor.global_position
		if camera_rig.camera.is_position_behind(anchor):
			continue
		var point := camera_rig.camera.unproject_position(anchor)
		if normalized.has_point(point):
			_add(unit)
	selection_changed.emit(_selected.size())


func cancel_gesture() -> void:
	_pressed = false
	_dragging = false
	if is_instance_valid(selection_box):
		selection_box.hide()
	if is_instance_valid(camera_rig):
		camera_rig.gesture_active = false


func _update_rectangle() -> void:
	var rectangle := Rect2(_press_position, _current_position - _press_position).abs()
	selection_box.position = rectangle.position
	selection_box.size = rectangle.size
	selection_box.show()


func _clear() -> void:
	for unit in _selected:
		if is_instance_valid(unit):
			unit.set_selected(false)
	_selected.clear()


func _add(unit: RTSUnit) -> void:
	if _can_select(unit) and not _selected.has(unit):
		_selected.append(unit)
		unit.set_selected(true)


func _can_select(unit: RTSUnit) -> bool:
	return TeamRules.is_controlled(gameplay_field, unit, friendly_owner_id)


func forget_unit(unit: RTSUnit) -> void:
	if _selected.has(unit):
		_selected.erase(unit)
		if is_instance_valid(unit):
			unit.set_selected(false)
		selection_changed.emit(_selected.size())


func _prune_selection() -> void:
	var count := _selected.size()
	for i in range(_selected.size() - 1, -1, -1):
		if not _can_select(_selected[i]):
			if is_instance_valid(_selected[i]):
				_selected[i].set_selected(false)
			_selected.remove_at(i)
	if count != _selected.size():
		selection_changed.emit(_selected.size())


func _raycast(point: Vector2, mask: int) -> Dictionary:
	var camera := camera_rig.camera
	var origin := camera.project_ray_origin(point)
	var query := PhysicsRayQueryParameters3D.create(origin, origin + camera.project_ray_normal(point) * 250.0, mask)
	return camera.get_world_3d().direct_space_state.intersect_ray(query)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		cancel_gesture()
		_pending_picks.clear()
