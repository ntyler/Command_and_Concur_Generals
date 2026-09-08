extends "res://tests/base_assault_checks.gd"
## Focused real viewport key routing, weak membership and callback checks.

var groups: ControlGroups

class KeySink extends Control:
	var presses: int = 0
	func _gui_input(event: InputEvent) -> void:
		if event is InputEventKey and event.pressed:
			presses += 1
			accept_event()


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var logger := EngineErrorProbe.new()
	OS.add_logger(logger)
	await _fresh_groups()
	await _membership_checks()
	await _keyboard_checks()
	await _lifecycle_checks()
	await _callback_checks()
	await _restart_checks()
	if is_instance_valid(battle): battle.queue_free()
	await _frames(5)
	_check(root.get_children().is_empty(), "control group teardown removes all fields, members and UI")
	OS.remove_logger(logger)
	_check(logger.error_count() == 0, "group input, synchronous callbacks and teardown have no native errors or warnings")
	print("CONTROL_GROUP_CHECKS: %d checks, %d failures; native_errors=%d" % [checks, failures, logger.error_count()])
	quit(0 if failures == 0 else 1)


func _fresh_groups() -> void:
	await _fresh_assault(1000)
	groups = ControlGroups.new()
	groups.field = battle
	battle.add_child(groups)
	_check(is_equal_approx(groups.double_tap_interval, 0.3), "double-tap defaults to 0.3 wall-clock seconds")


func _group_key(index: int, ctrl: bool = false, echo: bool = false, modifier: String = "") -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_0 + index
	event.keycode = KEY_0 + index
	event.pressed = true
	event.ctrl_pressed = ctrl
	event.echo = echo
	event.shift_pressed = modifier == "shift"
	event.alt_pressed = modifier == "alt"
	event.meta_pressed = modifier == "meta"
	root.push_input(event, true)
	event = event.duplicate() as InputEventKey
	event.pressed = false
	event.echo = false
	root.push_input(event, true)


func _membership_checks() -> void:
	var a := battle.units[0]
	var b := battle.units[1]
	var enemy := battle.units[3]
	var notifications: Array[int] = []
	var listener := func(count: int) -> void: notifications.append(count)
	battle.selection.selection_changed.connect(listener)
	battle.selection.replace_units([a, b, a, enemy])
	_check(battle.selection.selected_units() == [a, b] and notifications == [2], "atomic selection filters ownership and duplicates before one coherent callback")
	notifications.clear()
	await physics_frame
	var command := battle.issue_move(Vector3(-10, 0, 14))
	_check(command.accepted_ids.size() == 2, "ordinary accepted Move establishes orders before group operations")
	var versions := [a.order_version, b.order_version, a.combat.order_version, b.combat.order_version]
	var destinations := [a.assigned_destination, b.assigned_destination]
	_group_key(1, true)
	_check(groups.group_members(1) == [a, b] and battle.selection.selected_units() == [a, b] and notifications.is_empty(), "Ctrl+1 assigns selected members once without recall or selection mutation")
	_check(versions == [a.order_version, b.order_version, a.combat.order_version, b.combat.order_version] and destinations == [a.assigned_destination, b.assigned_destination], "assignment preserves movement and combat orders")
	battle.selection.replace_units([b])
	_group_key(1, true)
	_check(groups.group_members(1) == [b], "assignment replaces previous group membership")
	battle.selection.select_building(battle.headquarters)
	_group_key(1)
	_check(battle.selection.selected_units() == [b] and battle.selection.selected_building() == null, "populated number recall replaces building with eligible units")
	_check(versions == [a.order_version, b.order_version, a.combat.order_version, b.combat.order_version] and destinations == [a.assigned_destination, b.assigned_destination], "recall does not mutate movement or combat orders")
	battle.selection.select_building(battle.headquarters)
	_group_key(9)
	_check(battle.selection.selected_building() == battle.headquarters and battle.selection.selected_units().is_empty(), "empty group recall is harmless and preserves selected building")
	_group_key(1, true)
	_check(groups.group_members(1).is_empty() and battle.selection.selected_building() == battle.headquarters, "Ctrl assignment with no mobile units clears group and preserves building")
	_check(not groups.assign_group(0) and not groups.recall_group(10), "unsupported group indices reject safely")
	for index in range(1, 10):
		battle.selection.replace_units([a, b])
		_group_key(index, true)
		_check(groups.group_members(index) == [a, b], "named keyboard action assigns group %d" % index)
	battle.selection.selection_changed.disconnect(listener)
	groups.clear_groups()
	_check(groups._members.is_empty() and groups.group_members(1).is_empty() and groups._last_group == 0, "clearing groups disconnects all tracked weak members and resets tap state")
	await physics_frame
	battle.selection.replace_units([a, b])
	battle.issue_stop()


func _keyboard_checks() -> void:
	var a := battle.units[0]
	var b := battle.units[1]
	battle.selection.replace_units([a])
	_group_key(1, true)
	battle.selection.replace_units([b])
	_group_key(2, true)
	var camera := battle.camera_rig
	var angle := camera.camera.rotation
	var zoom := camera.zoom
	var target_zoom := camera.target_zoom
	camera.center_on_ground(Vector3.ZERO)
	_group_key(1)
	_check(camera.position == Vector3.ZERO and battle.selection.selected_units() == [a], "first number tap recalls without moving camera")
	_group_key(1)
	_check(Vector2(camera.position.x, camera.position.z).distance_to(Vector2(a.position.x, a.position.z)) < 0.001, "double-tap viewport input centers camera on valid group")
	_check(camera.camera.rotation == angle and camera.zoom == zoom and camera.target_zoom == target_zoom, "group camera centering preserves camera angle and zoom")
	camera.center_on_ground(Vector3.ZERO)
	_group_key(1, false, true)
	_check(camera.position == Vector3.ZERO, "keyboard-repeat number events cannot cause camera jumps")
	battle.selection.replace_units([b])
	_group_key(1, true, true)
	_check(groups.group_members(1) == [a] and battle.selection.selected_units() == [b], "keyboard-repeat Ctrl assignment is ignored")
	_group_key(2)
	_group_key(1)
	_check(camera.position == Vector3.ZERO, "different group number breaks double-tap sequence")
	groups.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	groups.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	_group_key(1)
	_check(camera.position == Vector3.ZERO, "focus loss clears pending tap before application returns")
	var start := Time.get_ticks_usec()
	while Time.get_ticks_usec() - start <= 330000:
		await process_frame
	_group_key(1)
	_check(camera.position == Vector3.ZERO, "expired wall-clock interval prevents double-tap despite accelerated fixed-FPS simulation")
	for modifier in ["shift", "alt", "meta"]:
		battle.selection.replace_units([b])
		_group_key(1, false, false, modifier)
		_group_key(1, true, false, modifier)
		_check(battle.selection.selected_units() == [b] and groups.group_members(1) == [a], "unsupported %s combinations neither recall nor assign" % modifier)
	var sink := KeySink.new()
	sink.focus_mode = Control.FOCUS_ALL
	sink.size = Vector2(30, 30)
	battle.get_node("ControlsFeedback").add_child(sink)
	sink.grab_focus()
	_group_key(1)
	_group_key(1, true)
	_check(sink.presses == 2 and battle.selection.selected_units() == [b] and groups.group_members(1) == [a], "focused GUI consumption prevents both assignment and recall")
	sink.release_focus()
	_group_key(1)
	sink.grab_focus()
	_group_key(2)
	sink.release_focus()
	_group_key(1)
	_check(camera.position == Vector3.ZERO, "a different group key consumed by focused UI breaks pending double-tap sequence")
	sink.queue_free()
	battle.selection.select_building(battle.headquarters)
	_check(battle.placement.begin(battle.headquarters), "ordinary building placement begins for keyboard isolation fixture")
	_group_key(1)
	_group_key(1, true)
	_check(battle.placement.active and battle.selection.selected_building() == battle.headquarters and groups.group_members(1) == [a], "placement owns workflow and blocks group assignment and recall")
	battle.placement.cancel()
	battle.gameplay_enabled = false
	battle.selection.replace_units([b])
	_group_key(1)
	_group_key(1, true)
	_check(battle.selection.selected_units() == [b] and groups.group_members(1) == [a], "frozen gameplay blocks group keyboard mutation")
	battle.gameplay_enabled = true
	# The existing X action is still delivered through the normal selection queue.
	await physics_frame
	battle.issue_move(Vector3(-10, 0, 14))
	var event := InputEventKey.new()
	event.physical_keycode = KEY_X
	event.pressed = true
	root.push_input(event, true)
	await _frames(2)
	_check(not b.moving and b.combat.player_command == CombatController.PlayerCommand.STOP, "X Stop remains available beside group shortcuts")


func _lifecycle_checks() -> void:
	await _fresh_groups()
	var a := battle.units[0]
	var b := battle.units[1]
	battle.selection.replace_units([a, b])
	_group_key(1, true)
	var container := Node3D.new()
	battle.add_child(container)
	a.reparent(container)
	_check(groups.group_members(1) == [a, b], "same-field reparent remains recallable immediately after operation")
	await _frames(2)
	_check(groups.group_members(1) == [a, b], "deferred lifecycle reconciliation preserves same-field reparent")
	container.remove_child(a)
	_check(groups.group_members(1) == [b], "detached member is ineligible immediately")
	await _frames(2)
	battle.add_child(a)
	await _frames(2)
	_check(groups.group_members(1) == [b], "permanent departure removes membership even when same node later returns")
	b.owner_id = 2
	_check(groups.group_members(1).is_empty(), "ownership change removes group membership immediately")
	b.owner_id = 1
	_check(groups.group_members(1).is_empty(), "returning ownership does not automatically restore membership")
	battle.selection.replace_units([a])
	_group_key(1, true)
	var numeric_id := a.unit_id
	a.queue_free()
	_check(groups.group_members(1).is_empty(), "queue_free member is immediately excluded before deletion")
	await _frames(2)
	_check(groups._members.is_empty(), "freed member leaves no unsafe tracked node reference")
	var newcomer := RTSUnit.new()
	newcomer.unit_id = numeric_id
	newcomer.position = Vector3(-20, 0, 19)
	battle.add_child(newcomer)
	battle.register_unit(newcomer)
	_check(groups.group_members(1).is_empty(), "new registration with reused numeric identity never joins automatically")
	battle.selection.replace_units([b])
	_group_key(2, true)
	b.combat.health.apply_damage(10000, null)
	_check(groups.group_members(2).is_empty(), "ordinary health death immediately invalidates group member")
	await _frames(2)
	_check(groups._members.is_empty(), "death lifecycle releases all member hooks")
	var pending := battle.units[0]
	battle.selection.replace_units([pending])
	_group_key(4, true)
	pending.reparent(container)
	container.queue_free()
	battle.selection.select_building(battle.headquarters)
	_group_key(4)
	_check(groups.group_members(4).is_empty() and battle.selection.selected_building() == battle.headquarters, "queued ancestor makes descendant group member immediately ineligible for recall")
	await _frames(2)
	var other := TestField.new()
	root.add_child(other)
	other.camera_rig.edge_scrolling_enabled = false
	battle.selection.replace_units([newcomer])
	_group_key(3, true)
	newcomer.reparent(other)
	other.register_unit(newcomer)
	_check(groups.group_members(3).is_empty(), "cross-field reparent cannot recall a departed mobile unit")
	await _frames(2)
	_check(groups._members.is_empty(), "cross-field departure permanently drops scoped weak identity")
	other.queue_free()
	await _frames(3)


func _callback_checks() -> void:
	await _fresh_groups()
	var a := battle.units[0]
	var b := battle.units[1]
	battle.selection.replace_units([a, b])
	groups.assign_group(1)
	battle.selection.select_building(battle.headquarters)
	var observe := {"coherent": false, "done": false}
	var remove_member := func(_count: int) -> void:
		if observe["done"]: return
		observe["done"] = true
		observe["coherent"] = battle.selection.selected_units() == [a, b] and battle.selection.selected_building() == null
		b.free()
	battle.selection.selection_changed.connect(remove_member)
	groups.recall_group(1, true)
	battle.selection.selection_changed.disconnect(remove_member)
	_check(observe["coherent"] and battle.selection.selected_units() == [a] and groups.group_members(1) == [a], "recall callback sees atomic selection and can synchronously free another member safely")
	_check(Vector2(battle.camera_rig.position.x, battle.camera_rig.position.z).distance_to(Vector2(a.position.x, a.position.z)) < 0.001, "double-tap re-resolves surviving group after synchronous deletion")
	var c := battle.units[1]
	battle.selection.replace_units([c])
	groups.assign_group(2)
	battle.camera_rig.center_on_ground(Vector3.ZERO)
	var nested := {"done": false}
	var redirect := func(_count: int) -> void:
		if nested["done"]: return
		nested["done"] = true
		groups.recall_group(2)
	battle.selection.selection_changed.connect(redirect)
	groups.recall_group(1, true)
	battle.selection.selection_changed.disconnect(redirect)
	_check(battle.selection.selected_units() == [c] and battle.camera_rig.position == Vector3.ZERO, "nested recall keeps newer selection and suppresses stale outer camera jump")
	var cleared := {"done": false}
	var clear_after_selection := func(_count: int) -> void:
		if cleared["done"]: return
		cleared["done"] = true
		groups.clear_groups()
	battle.selection.selection_changed.connect(clear_after_selection)
	groups.recall_group(1, true)
	battle.selection.selection_changed.disconnect(clear_after_selection)
	_check(groups._members.is_empty() and battle.camera_rig.position == Vector3.ZERO, "synchronous clear invalidates remaining outer recall work")
	# selected_units() may prune and notify during assignment. Nested assignment wins.
	battle.selection.replace_units([a, c])
	a.owner_id = 2
	var reassigned := {"done": false}
	var assign_during_prune := func(_count: int) -> void:
		if reassigned["done"]: return
		reassigned["done"] = true
		groups.assign_group(1)
	battle.selection.selection_changed.connect(assign_during_prune)
	var accepted := groups.assign_group(2)
	battle.selection.selection_changed.disconnect(assign_during_prune)
	_check(not accepted and groups.group_members(1) == [c] and groups.group_members(2).is_empty(), "selection-prune callback assignment supersedes stale outer assignment")
	var free_controller := func(_count: int) -> void: groups.queue_free()
	battle.selection.selection_changed.connect(free_controller, CONNECT_ONE_SHOT)
	groups.recall_group(1, true)
	_check(groups.is_queued_for_deletion() and battle.camera_rig.position == Vector3.ZERO, "selection listener can queue controller deletion and suppress remaining camera work")
	await _frames(2)
	_check(not is_instance_valid(groups), "queued controller teardown leaves no stale accesses")


func _restart_checks() -> void:
	await _fresh_groups()
	var a := battle.units[0]
	var id := a.unit_id
	battle.selection.replace_units([a])
	_group_key(1, true)
	_group_key(1)
	var old_groups: WeakRef = weakref(groups)
	var old_unit: WeakRef = weakref(a)
	battle.enemy_headquarters.health.apply_damage(10000, null)
	await _frames(3)
	_check(battle.result == BaseAssaultField.Result.VICTORY and not battle.gameplay_enabled, "ordinary HQ damage reaches actual frozen match result")
	var before := battle.selection.selected_units()
	_group_key(1, true)
	_group_key(1)
	_check(battle.selection.selected_units() == before and groups.group_members(1) == [a], "match-result shortcuts cannot alter membership or selection")
	_check(battle.restart_match(), "existing Restart changes scene normally")
	await _frames(6)
	battle = current_scene as BaseAssaultField
	field = battle
	world = battle
	harvest = battle
	groups = ControlGroups.new()
	groups.field = battle
	battle.add_child(groups)
	battle.camera_rig.edge_scrolling_enabled = false
	_check(old_groups.get_ref() == null and old_unit.get_ref() == null and groups.group_members(1).is_empty() and groups._last_group == 0, "Restart frees old controller/unit and replacement starts with no groups or tap state")
	_check(battle.units[0].unit_id == id and battle.selection.selected_building() == battle.headquarters, "fresh match safely reuses numeric unit ID with default HQ selection")
	_group_key(1)
	_check(battle.selection.selected_building() == battle.headquarters and battle.camera_rig.position == Vector3.ZERO, "old group key cannot restore reused identity or center fresh match")
