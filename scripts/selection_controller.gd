class_name SelectionController
extends Node

signal selection_changed(count: int)
signal move_requested(destination: Vector3)
signal attack_requested(target: Node3D)
signal stop_requested
signal harvest_requested(cache: SupplyCache)
signal deposit_requested(headquarters: RTSBuilding)
signal attack_move_targeting_changed

@export var friendly_owner_id: int = 1
@export var drag_threshold: float = 6.0
@export var attack_move_enabled: bool = false

var camera_rig: RTSCamera
var gameplay_field: TestField
var selection_box: ReferenceRect
var _selected: Array[RTSUnit] = []
var _selected_building: RTSBuilding
var _press_position: Vector2
var _current_position: Vector2
var _pressed: bool = false
var _dragging: bool = false
var _additive: bool = false
var _pending_picks: Array[Dictionary] = []
var placement_active: bool = false:
	set(value):
		placement_active = value
		if value and attack_move_targeting:
			cancel_attack_move_targeting()
		if value and is_instance_valid(tempest_targeting) and tempest_targeting.active:
			tempest_targeting.cancel()
var tempest_targeting: TempestTargeting
var attack_move_targeting: bool = false
var attack_move_feedback: String = ""
var _targeting_revision: int = 0
var _focused: bool = true


func _ready() -> void:
	get_window().mouse_exited.connect(cancel_gesture)
	get_window().focus_exited.connect(cancel_attack_move_targeting)
	selection_changed.connect(_attack_move_selection_changed)


func _attack_move_available() -> bool:
	if is_instance_valid(tempest_targeting) and tempest_targeting.active:
		return false
	return attack_move_enabled and _focused and is_inside_tree() and not is_queued_for_deletion() and is_instance_valid(gameplay_field) and gameplay_field.is_inside_tree() and not gameplay_field.is_queued_for_deletion() and gameplay_field.gameplay_enabled and not placement_active


func has_attack_move_selection() -> bool:
	if not _attack_move_available():
		return false
	for unit in _selected:
		if gameplay_field.can_attack_move(unit):
			return true
	return false


func begin_attack_move() -> bool:
	if not _attack_move_available():
		return false
	var revision := _targeting_revision
	_prune_selection()
	if not is_instance_valid(self) or revision != _targeting_revision or not has_attack_move_selection():
		return false
	_targeting_revision += 1
	attack_move_targeting = true
	attack_move_feedback = "Choose ground or minimap destination."
	cancel_gesture()
	_pending_picks.clear()
	attack_move_targeting_changed.emit() # Commit before synchronous listeners.
	return true


func cancel_attack_move_targeting() -> void:
	_targeting_revision += 1
	var changed := attack_move_targeting or not attack_move_feedback.is_empty()
	attack_move_targeting = false
	attack_move_feedback = ""
	for index in range(_pending_picks.size() - 1, -1, -1):
		if str(_pending_picks[index].get("kind", "")).begins_with("attack_move_"):
			_pending_picks.remove_at(index)
	if changed:
		attack_move_targeting_changed.emit()


func queue_attack_move_destination(destination: Vector3) -> bool:
	if not attack_move_targeting or not _attack_move_available():
		return false
	_pending_picks.append({"kind": "attack_move_ground", "destination": destination, "revision": _targeting_revision})
	return true


func _attack_move_selection_changed(_count: int) -> void:
	if attack_move_targeting and not has_attack_move_selection():
		cancel_attack_move_targeting()


func _reject_attack_move_destination() -> void:
	attack_move_feedback = "Invalid destination. Choose reachable clear ground."
	attack_move_targeting_changed.emit()


func _dispatch_attack_move(destination: Vector3, revision: int) -> void:
	if not attack_move_targeting or revision != _targeting_revision or not _attack_move_available():
		return
	var result := gameplay_field.issue_attack_move(destination)
	if not is_instance_valid(self) or revision != _targeting_revision or not _attack_move_available():
		return
	if result.has_acceptance():
		cancel_attack_move_targeting()
	else:
		_reject_attack_move_destination()


func _unhandled_key_input(event: InputEvent) -> void:
	if not _gameplay_input_enabled() or event.is_echo():
		return
	# Match Escape belongs to RTSPauseMenu; legacy fields retain cancellation.
	if not gameplay_field is BaseAssaultField and attack_move_targeting and event.is_action_pressed("cancel_selection"):
		cancel_attack_move_targeting()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("attack_move"):
		var key := event as InputEventKey
		if key != null and not key.ctrl_pressed and not key.alt_pressed and not key.meta_pressed and not key.shift_pressed and begin_attack_move():
			get_viewport().set_input_as_handled()


func selected_units() -> Array[RTSUnit]:
	_prune_selection()
	if not is_instance_valid(self):
		return []
	return _selected.duplicate()


func selected_builder() -> Bulldozer:
	# Construction never chooses a random builder from a mixed/control-group
	# selection. TeamRules supplies the same live ownership/registration boundary
	# used by ordinary selection and movement commands.
	if _selected.size() != 1 or not is_instance_valid(_selected[0]) or not _selected[0] is Bulldozer or not _can_select(_selected[0]):
		return null
	return _selected[0] as Bulldozer


func has_selected_builder() -> bool:
	for unit in _selected:
		if is_instance_valid(unit) and unit is Bulldozer and _can_select(unit):
			return true
	return false


func request_builder_assignment(building: RTSBuilding) -> bool:
	var world := gameplay_field as ConstructionField
	var builder := selected_builder()
	if world == null or not world.builder_construction_enabled or builder == null or not is_instance_valid(building) or not building is ConstructionBuilding or not world.contains_building(building) or building.owner_id != friendly_owner_id:
		return false
	var site := (building as ConstructionBuilding).site
	return site != null and world.construction.assign_builder(builder, site.site_id)


func replace_units(candidates: Array) -> void:
	# Commit all membership before notifying listeners. Callers such as control
	# groups share the normal ownership checks and never build parallel selection.
	var accepted: Array[RTSUnit] = []
	for candidate in candidates:
		if is_instance_valid(candidate) and candidate is RTSUnit and _can_select(candidate) and not accepted.has(candidate):
			accepted.append(candidate)
	cancel_gesture()
	_pending_picks.clear()
	_clear()
	for unit in accepted:
		_add(unit)
	selection_changed.emit(_selected.size()) # No writes after synchronous callbacks.


func _input(event: InputEvent) -> void:
	if not _gameplay_input_enabled():
		return
	# Cancellation owns right-click even over the minimap or another UI surface.
	# It cannot fall through to ordinary Move or explicit Attack.
	if attack_move_targeting and event.is_action_pressed("command_move"):
		cancel_attack_move_targeting()
		get_viewport().set_input_as_handled()
		return
	# _input observes cancellation even when GUI consumes the eventual release.
	if not gameplay_field is BaseAssaultField and event.is_action_pressed("cancel_selection"):
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
	if not _gameplay_input_enabled():
		return
	if is_instance_valid(tempest_targeting) and tempest_targeting.active:
		return
	# GUI gets first refusal. Pointer hover filters mouse commands, not an
	# otherwise unhandled keyboard Stop (a focused control can still consume it).
	if event.is_action_pressed("unit_stop") and not event.is_echo():
		cancel_gesture()
		_pending_picks.append({"kind": "stop"})
		get_viewport().set_input_as_handled()
		return
	if placement_active or camera_rig.pointer_over_interface():
		return
	if attack_move_targeting:
		if event.is_action_pressed("select_units"):
			cancel_gesture()
			_pending_picks.append({"kind": "attack_move_screen", "position": (event as InputEventMouseButton).position, "revision": _targeting_revision})
			get_viewport().set_input_as_handled()
		elif event.is_action_released("select_units"):
			get_viewport().set_input_as_handled()
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
	if not _gameplay_input_enabled():
		return
	_prune_selection()
	if not is_instance_valid(self):
		return
	if attack_move_targeting and not has_attack_move_selection():
		cancel_attack_move_targeting()
	if not is_instance_valid(self):
		return
	# Ray queries belong to the physics tick; queued input keeps selection/command order.
	var pending := _pending_picks.duplicate()
	_pending_picks.clear()
	for request in pending:
		if not is_instance_valid(self) or not is_instance_valid(gameplay_field) or not gameplay_field.gameplay_enabled:
			return
		if request["kind"] == "stop":
			stop_requested.emit()
			continue
		if request["kind"] == "attack_move_ground":
			_dispatch_attack_move(request["destination"], request["revision"])
			continue
		if request["kind"] == "attack_move_screen":
			if not attack_move_targeting or request["revision"] != _targeting_revision or not _attack_move_available():
				continue
			var hit := _raycast(request["position"], 1 | 2 | 4)
			var collider := hit.get("collider") as CollisionObject3D
			if is_instance_valid(collider) and collider.collision_layer & 1:
				_dispatch_attack_move(hit["position"], request["revision"])
			else:
				_reject_attack_move_destination()
			continue
		var point: Vector2 = request["position"]
		if request["kind"] == "select":
			var hit := _raycast(point, 1 | 2 | 4)
			var building := hit.get("collider") as RTSBuilding
			if _can_select_building(building):
				select_building(building)
			else:
				var unit: RTSUnit = hit.get("collider") as RTSUnit
				select_clicked(unit, request["additive"])
		elif selected_building() != null:
			var building := selected_building()
			var hit := _raycast(point, 1 | 2 | 4)
			if building.production != null and not hit.is_empty() and (hit["collider"] as CollisionObject3D).collision_layer & 1:
				building.production.set_rally(friendly_owner_id, hit["position"])
		elif not _selected.is_empty():
			var hit := _raycast(point, 1 | 2 | 4)
			if not hit.is_empty():
				var target := hit["collider"] as RTSUnit
				if target != null:
					if TeamRules.is_hostile_target(gameplay_field, friendly_owner_id, target):
						attack_requested.emit(target)
				elif hit["collider"] is SupplyCache:
					harvest_requested.emit(hit["collider"] as SupplyCache)
				elif hit["collider"] is RTSBuilding:
					var building := hit["collider"] as RTSBuilding
					if gameplay_field is ConstructionField and (gameplay_field as ConstructionField).builder_construction_enabled and has_selected_builder() and building is ConstructionBuilding and building.owner_id == friendly_owner_id and not building.operational:
						# A rejected resume preserves current work and never falls
						# through to Move, deposit, attack, or another builder's job.
						request_builder_assignment(building)
					elif TeamRules.is_hostile_target(gameplay_field, friendly_owner_id, building):
						attack_requested.emit(building)
					else:
						deposit_requested.emit(building)
				elif (hit["collider"] as CollisionObject3D).collision_layer & 1:
					move_requested.emit(hit["position"])


func select_clicked(unit: RTSUnit, additive: bool) -> void:
	_prune_selection()
	if _can_select(unit):
		_clear_building()
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
	_clear_building()
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


func _gameplay_input_enabled() -> bool:
	return is_instance_valid(gameplay_field) and gameplay_field.gameplay_enabled and is_inside_tree() and not is_queued_for_deletion()


func _update_rectangle() -> void:
	var rectangle := Rect2(_press_position, _current_position - _press_position).abs()
	selection_box.position = rectangle.position
	selection_box.size = rectangle.size
	selection_box.show()


func _clear() -> void:
	_clear_building()
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
	var building_changed := _selected_building != null and (not is_instance_valid(_selected_building) or not _can_select_building(_selected_building))
	if building_changed:
		_clear_building()
	for i in range(_selected.size() - 1, -1, -1):
		if not _can_select(_selected[i]):
			if is_instance_valid(_selected[i]):
				_selected[i].set_selected(false)
			_selected.remove_at(i)
	if count != _selected.size() or building_changed:
		selection_changed.emit(_selected.size())


func selected_building() -> RTSBuilding:
	return _selected_building if is_instance_valid(_selected_building) and _can_select_building(_selected_building) else null


func select_building(building: RTSBuilding) -> void:
	if not _can_select_building(building):
		return
	_clear()
	_selected_building = building
	building.set_selected(true)
	# Unit and building state is already coherent when existing listeners run.
	selection_changed.emit(0)


func _can_select_building(building: RTSBuilding) -> bool:
	return is_instance_valid(building) and gameplay_field is ProductionField and (gameplay_field as ProductionField).contains_building(building) and building.owner_id == friendly_owner_id


func _clear_building() -> void:
	if is_instance_valid(_selected_building):
		_selected_building.set_selected(false)
	_selected_building = null


func prune_building() -> void:
	if _selected_building != null and (not is_instance_valid(_selected_building) or not _can_select_building(_selected_building)):
		_clear_building()
		selection_changed.emit(_selected.size())


func _raycast(point: Vector2, mask: int) -> Dictionary:
	var camera := camera_rig.camera
	var origin := camera.project_ray_origin(point)
	var query := PhysicsRayQueryParameters3D.create(origin, origin + camera.project_ray_normal(point) * 250.0, mask)
	return camera.get_world_3d().direct_space_state.intersect_ray(query)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_focused = false
		cancel_gesture()
		_pending_picks.clear()
		cancel_attack_move_targeting()
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_focused = true


func _exit_tree() -> void:
	_pending_picks.clear()
	cancel_gesture()
	cancel_attack_move_targeting()
	if get_window().mouse_exited.is_connected(cancel_gesture):
		get_window().mouse_exited.disconnect(cancel_gesture)
	if get_window().focus_exited.is_connected(cancel_attack_move_targeting):
		get_window().focus_exited.disconnect(cancel_attack_move_targeting)
	gameplay_field = null
