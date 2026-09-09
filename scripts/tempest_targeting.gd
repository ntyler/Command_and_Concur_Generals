class_name TempestTargeting
extends Node
## Input collects one request; priority 400 commits before strikes at 500 and
## result evaluation at 1000. Preview and cancellation never consume charge.

signal changed

var field: ConstructionField
var active: bool = false
var feedback: String = ""
var preview: MeshInstance3D
var last_result: Dictionary = {}
var _source: WeakRef
var _owner: int = 0
var _revision: int = 0
var _pending: Dictionary = {}
var _pointer := Vector2.ZERO
var _focused: bool = true


func configure(world: ConstructionField) -> void:
	field = world
	process_physics_priority = 400


func _ready() -> void:
	field.selection.tempest_targeting = self
	field.selection.selection_changed.connect(_selection_changed)
	field.power_grid.changed.connect(_validate_source)
	get_window().focus_exited.connect(cancel)
	preview = MeshInstance3D.new()
	preview.name = "TempestTargetRadius"
	var ring := TorusMesh.new()
	ring.inner_radius = 9.93
	ring.outer_radius = 10.07
	ring.rings = 64
	ring.ring_segments = 6
	preview.mesh = ring
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color("ffce78")
	preview.material_override = material
	preview.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	field.add_child(preview)
	preview.hide()


func _manager() -> TempestStrikes:
	return field.get("tempest_strikes") as TempestStrikes if _context_active() else null


func _context_active() -> bool:
	return is_instance_valid(field) and field.is_inside_tree() and not field.is_queued_for_deletion() and is_instance_valid(field.selection)


func source() -> TempestArray:
	return _source.get_ref() as TempestArray if _source != null else null


func begin(facility: TempestArray) -> bool:
	var manager := _manager()
	if manager == null or not _focused:
		return false
	var owner := field.selection.friendly_owner_id
	var reason := manager.launch_reason(facility, owner)
	if not is_instance_valid(self) or not _context_active():
		return false
	if not reason.is_empty() or field.selection.selected_building() != facility:
		feedback = reason if not reason.is_empty() else "Select your Tempest Array."
		changed.emit()
		return false
	field.placement.cancel()
	field.selection.cancel_attack_move_targeting()
	if not is_instance_valid(self) or not _context_active() or not is_instance_valid(facility) or field.selection.selected_building() != facility:
		return false
	field.selection.cancel_gesture()
	field.selection._pending_picks.clear()
	_revision += 1
	_source = weakref(facility)
	_owner = owner
	_pending.clear()
	active = true
	feedback = "Choose ground or minimap · Friendly fire\nRight-click · Cancel    Esc · Pause and cancel"
	changed.emit()
	return true


func cancel() -> void:
	_revision += 1
	active = false
	_source = null
	_pending.clear()
	feedback = ""
	if is_instance_valid(preview):
		preview.hide()
	changed.emit()


func reject_target() -> void:
	if active:
		feedback = "Invalid target · Choose ground inside the map.\nRight-click · Cancel    Esc · Pause and cancel"
		changed.emit()


func queue_target(point: Vector3) -> bool:
	if not _context_active() or not field.gameplay_enabled or not active or not _pending.is_empty():
		return false
	_pending = {"point": point, "revision": _revision}
	return true


func _input(event: InputEvent) -> void:
	if not _context_active() or not field.gameplay_enabled:
		return
	if event is InputEventMouseMotion:
		_pointer = event.position
	if active and (event.is_action_pressed("command_move") or (not field is BaseAssaultField and event.is_action_pressed("cancel_selection"))):
		cancel()
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if not _context_active() or not field.gameplay_enabled or not active:
		return
	if event.is_action_pressed("select_units") and not field.camera_rig.pointer_over_interface():
		if _pending.is_empty():
			_pending = {"screen": (event as InputEventMouseButton).position, "revision": _revision}
		get_viewport().set_input_as_handled()
	elif event.is_action_released("select_units") or event.is_action_pressed("attack_move") or event.is_action_pressed("unit_stop"):
		get_viewport().set_input_as_handled()


func _ground(screen: Vector2) -> Variant:
	var camera := field.camera_rig.camera
	var ground := Plane(Vector3.UP, field.global_position.y)
	return ground.intersects_ray(camera.project_ray_origin(screen), camera.project_ray_normal(screen))


func _inside(point: Vector3) -> bool:
	var bounds := field.field_bounds
	return point.is_finite() and point.x >= bounds.position.x and point.x <= bounds.end.x and point.z >= bounds.position.y and point.z <= bounds.end.y


func _physics_process(_delta: float) -> void:
	if not _context_active() or not field.gameplay_enabled:
		return
	_validate_source()
	if not active:
		return
	var request := _pending.duplicate()
	_pending.clear()
	if not request.is_empty() and request.revision == _revision:
		var point: Variant = request.get("point") if request.has("point") else _ground(request.screen)
		if point == null or not _inside(point):
			reject_target()
		else:
			var revision := _revision
			var manager := _manager()
			var result := manager.launch(source(), _owner, point)
			if not is_instance_valid(self) or not _context_active():
				return
			last_result = result
			if revision != _revision:
				return
			if result.accepted:
				cancel()
				feedback = "Strike committed · 6s warning · Ground only / friendly fire"
				changed.emit()
				return
			feedback = result.reason
			changed.emit()
	if not active or not _context_active():
		return
	var point: Variant = _ground(_pointer)
	preview.visible = point != null and _inside(point) and not field.camera_rig.pointer_over_interface()
	if preview.visible:
		preview.global_position = point + Vector3.UP * 0.1


func _validate_source() -> void:
	if not active:
		return
	var manager := _manager()
	var facility := source()
	if manager == null or not _focused or field.selection.placement_active or field.selection.selected_building() != facility:
		cancel()
		return
	var reason := manager.launch_reason(facility, _owner)
	if is_instance_valid(self) and active and not reason.is_empty():
		cancel()


func _selection_changed(_count: int) -> void:
	_validate_source()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_focused = false
		cancel()
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_focused = true


func _exit_tree() -> void:
	active = false
	_pending.clear()
	_source = null
	if get_window().focus_exited.is_connected(cancel):
		get_window().focus_exited.disconnect(cancel)
	if is_instance_valid(field):
		if is_instance_valid(field.selection):
			if field.selection.selection_changed.is_connected(_selection_changed):
				field.selection.selection_changed.disconnect(_selection_changed)
			if field.selection.tempest_targeting == self:
				field.selection.tempest_targeting = null
		if field.power_grid.changed.is_connected(_validate_source):
			field.power_grid.changed.disconnect(_validate_source)
	if is_instance_valid(preview):
		preview.queue_free()
	field = null
