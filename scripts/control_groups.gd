class_name ControlGroups
extends Node
## Match-local membership; numeric unit IDs are checked alongside weak instance
## identities, so a replacement field or a reused unit ID never restores a group.

signal changed

@export_range(0.05, 1.0, 0.01) var double_tap_interval: float = 0.3
var field: TestField
var _groups: Dictionary[int, Array] = {}
var _members: Dictionary[int, Dictionary] = {}
var _last_group: int = 0
var _last_tap_usec: int = 0
var _revision: int = 0
var _focused: bool = true


func _ready() -> void:
	get_window().focus_exited.connect(_clear_tap)


func _enabled() -> bool:
	return _focused and is_inside_tree() and not is_queued_for_deletion() and is_instance_valid(field) and field.is_inside_tree() and not field.is_queued_for_deletion() and field.gameplay_enabled and is_instance_valid(field.selection) and not field.selection.placement_active


func assign_group(index: int) -> bool:
	if index < 1 or index > 9 or not _enabled():
		return false
	_revision += 1
	var revision := _revision
	_clear_tap()
	# Pruning selection can synchronously replace groups, ownership or the field.
	var selected := field.selection.selected_units()
	if not is_instance_valid(self) or not _enabled() or revision != _revision:
		return false
	var identities: Array = []
	for unit in selected:
		if not is_instance_valid(unit) or not TeamRules.is_controlled(field, unit, field.selection.friendly_owner_id):
			continue
		var identity := unit.get_instance_id()
		if identities.has(identity):
			continue
		identities.append(identity)
		if not _members.has(identity):
			_members[identity] = {"unit": weakref(unit), "unit_id": unit.unit_id, "field_id": field.get_instance_id()}
			unit.availability_changed.connect(_availability_changed.bind(identity))
			unit.tree_exiting.connect(_member_exiting.bind(identity))
	_groups[index] = identities
	_release_unused()
	changed.emit() # State is committed before observers; no writes afterwards.
	return true


func group_members(index: int) -> Array[RTSUnit]:
	var result: Array[RTSUnit] = []
	if not is_instance_valid(field) or not is_instance_valid(field.selection):
		return result
	for identity in _groups.get(index, []):
		var unit := _resolve(identity)
		if is_instance_valid(unit) and TeamRules.is_controlled(field, unit, field.selection.friendly_owner_id):
			result.append(unit)
	return result


func recall_group(index: int, center: bool = false) -> bool:
	if index < 1 or index > 9 or not _enabled():
		return false
	_revision += 1
	var revision := _revision
	var members := group_members(index)
	if members.is_empty():
		return false # Preserve current units or building when a group is empty.
	field.selection.replace_units(members)
	if not is_instance_valid(self) or not _enabled() or revision != _revision:
		return true
	if center:
		# A selection listener can free/reparent members or choose another group.
		# Re-resolve weak membership and honor any replacement selection it made.
		members = group_members(index)
		var selected := field.selection.selected_units()
		if not is_instance_valid(self) or not _enabled() or revision != _revision or members.is_empty() or selected != members:
			return true
		var point := Vector3.ZERO
		var count := 0
		for unit in members:
			if is_instance_valid(unit) and TeamRules.is_controlled(field, unit, field.selection.friendly_owner_id):
				point += unit.global_position
				count += 1
		if count > 0 and is_instance_valid(field.camera_rig):
			field.camera_rig.center_on_ground(point / count)
	return true


func clear_groups() -> void:
	_revision += 1
	_groups.clear()
	_release_unused()
	_clear_tap()
	changed.emit()


func _resolve(identity: int) -> RTSUnit:
	if not is_instance_valid(field) or not _members.has(identity):
		return null
	var entry := _members[identity]
	var unit := (entry["unit"] as WeakRef).get_ref() as RTSUnit
	if not is_instance_valid(unit) or entry["field_id"] != field.get_instance_id() or unit.unit_id != entry["unit_id"] or not unit.is_alive() or unit.is_queued_for_deletion():
		return null
	return unit


func _availability_changed(identity: int) -> void:
	var unit := _resolve(identity)
	if not is_instance_valid(unit) or not is_instance_valid(field.selection) or unit.owner_id != field.selection.friendly_owner_id:
		_remove_identity(identity)
	else:
		# TestField unregisters on tree_exiting, including a same-field reparent.
		# Keep its weak entry until that synchronous operation has finished.
		_reconcile_departure.call_deferred(identity)


func _member_exiting(identity: int) -> void:
	_reconcile_departure.call_deferred(identity)


func _reconcile_departure(identity: int) -> void:
	if not _members.has(identity):
		return
	var unit := _resolve(identity)
	if not is_instance_valid(unit) or not is_instance_valid(field.selection) or not TeamRules.is_controlled(field, unit, field.selection.friendly_owner_id):
		_remove_identity(identity)


func _remove_identity(identity: int) -> void:
	if not _members.has(identity):
		return
	for index in _groups:
		_groups[index].erase(identity)
	_release_unused()
	changed.emit()


func _release_unused() -> void:
	for identity in _members.keys():
		var used := false
		for identities in _groups.values():
			if identities.has(identity):
				used = true
				break
		if used:
			continue
		var unit := (_members[identity]["unit"] as WeakRef).get_ref() as RTSUnit
		_members.erase(identity)
		if is_instance_valid(unit):
			var availability := _availability_changed.bind(identity)
			var exiting := _member_exiting.bind(identity)
			if unit.availability_changed.is_connected(availability):
				unit.availability_changed.disconnect(availability)
			if unit.tree_exiting.is_connected(exiting):
				unit.tree_exiting.disconnect(exiting)


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	for index in range(1, 10):
		if not key.is_action_pressed("control_group_%d" % index):
			continue
		if not _enabled() or key.alt_pressed or key.shift_pressed or key.meta_pressed:
			_clear_tap()
			return
		get_viewport().set_input_as_handled()
		if key.ctrl_pressed:
			assign_group(index)
		else:
			var now := Time.get_ticks_usec()
			var center := _last_group == index and now - _last_tap_usec <= int(double_tap_interval * 1000000.0)
			_last_group = index
			_last_tap_usec = now
			recall_group(index, center)
		return


func _clear_tap() -> void:
	_last_group = 0
	_last_tap_usec = 0


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_focused = false
		_clear_tap()
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_focused = true


func _exit_tree() -> void:
	_groups.clear()
	_release_unused()
	_clear_tap()
