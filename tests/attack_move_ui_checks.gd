extends "res://tests/tactical_interface_checks.gd"
## M9 viewport routing and one paid production integration. Reuses existing
## combined scene and harness; does not replace or duplicate the playable mode.

class AttackKeySink extends Control:
	var presses: int = 0
	func _gui_input(event: InputEvent) -> void:
		if event is InputEventKey and event.pressed:
			presses += 1
			accept_event()


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1280, 720)
	var logger := EngineErrorProbe.new()
	OS.add_logger(logger)
	var chosen := "all"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--attack-move-ui-case="):
			chosen = argument.trim_prefix("--attack-move-ui-case=")
	var cases := ["input", "context", "lifecycle", "integration"]
	_check(chosen == "all" or cases.has(chosen), "recognized attack-move UI case")
	for case in cases:
		if chosen != "all" and chosen != case: continue
		var before := checks
		var failed := failures
		match case:
			"input": await _am_ui_input()
			"context": await _am_ui_context()
			"lifecycle": await _am_ui_lifecycle()
			"integration": await _am_ui_integration()
		print("ATTACK_MOVE_UI_CASE: %s; checks=%d failures=%d" % [case, checks - before, failures - failed])
	if is_instance_valid(battle): battle.queue_free()
	await _frames(5)
	_check(root.get_children().is_empty() and get_nodes_in_group("combat_projectiles").is_empty(), "attack-move UI teardown removes all scene/input/HUD/projectile references")
	OS.remove_logger(logger)
	_check(logger.error_count() == 0, "attack-move viewport/integration paths have no native errors or warnings")
	print("ATTACK_MOVE_UI_CHECKS: %d checks, %d failures; native_errors=%d" % [checks, failures, logger.error_count()])
	quit(0 if failures == 0 else 1)


func _am_ui_key(code: Key, echo: bool = false) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = true
	event.echo = echo
	root.push_input(event, true)
	event = event.duplicate() as InputEventKey
	event.pressed = false
	event.echo = false
	root.push_input(event, true)
	await _frames(2)


func _am_ui_select(source: RTSUnit, additive: bool = false) -> void:
	await _click(_screen(source), MOUSE_BUTTON_LEFT, additive)
	_check(battle.selection.selected_units().has(source), "viewport raycast selects actual combat actor")


func _am_ui_input() -> void:
	await _fresh_combined(1000, 600)
	var source := battle.units[0]
	await _am_ui_select(source)
	var panel := battle.production_panel
	_check(panel.attack_move_button.visible and panel.attack_move_button.text.contains("Q"), "eligible Rifle context exposes compact Attack Move button and Q shortcut")
	await physics_frame
	_check(_complete(battle.issue_move(Vector3(-12, 0, 12))), "input fixture establishes existing ordinary Move")
	var before := source.order_version
	await _click(panel.attack_move_button.get_global_rect().get_center(), MOUSE_BUTTON_LEFT)
	_check(battle.selection.attack_move_targeting and panel.attack_move_hint.visible and source.order_version == before and not source.attack_move.active, "viewport button arms readable targeting without cancelling existing Move")
	for dimensions in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		await _am_ui_pending_layout(dimensions)
	root.size = Vector2i(1280, 720)
	await _frames(8)
	var selected := battle.selection.selected_units()
	var batch := battle.last_command_result
	var funds := battle.credits.balance(1)
	await _click(panel.identity_label.get_global_rect().get_center(), MOUSE_BUTTON_LEFT)
	_check(battle.selection.attack_move_targeting and battle.last_command_result == batch and battle.selection.selected_units() == selected, "context panel click cannot confirm world terrain or change selected actors")
	await _click(_minimap_point(battle.headquarters.position), MOUSE_BUTTON_LEFT)
	_check(battle.selection.attack_move_targeting and battle.selection.attack_move_feedback.contains("Invalid") and source.order_version == before and battle.credits.balance(1) == funds, "invalid minimap building footprint rejects with readable feedback and preserves existing orders/funds")
	var destination := Vector3(-8, 0, 12)
	await _click(_world_screen(destination), MOUSE_BUTTON_LEFT)
	_check(source.attack_move.active and _complete(battle.last_command_result) and source.attack_move.final_destination.distance_to(destination) < 0.15, "battlefield left-click dispatches shared attack-move batch at real terrain position")
	_check(not battle.selection.attack_move_targeting and not panel.attack_move_hint.visible and battle.selection.selected_units() == selected and not battle.selection._pressed and not battle.selection._dragging, "accepted confirm leaves targeting without starting drag selection or changing selected units")
	_check(panel.selection_details.text.contains("Attack-moving"), "selected active parent reports concise Attack-moving activity")
	var parent: int = source.attack_move.parent_order_id
	await _am_ui_key(KEY_Q)
	await _click(_minimap_point(Vector3(-12, 0, 18)), MOUSE_BUTTON_RIGHT)
	_check(not battle.selection.attack_move_targeting and source.attack_move.active and source.attack_move.parent_order_id == parent, "right-click over minimap cancels pending targeting without issuing ordinary Move")
	await _am_ui_key(KEY_Q)
	await _am_ui_key(KEY_ESCAPE)
	_check(not battle.selection.attack_move_targeting and source.attack_move.parent_order_id == parent, "Escape cancels pending destination without changing active parent")
	await _am_ui_key(KEY_Q, true)
	_check(not battle.selection.attack_move_targeting, "key-repeat Q cannot activate targeting")
	await _am_ui_key(KEY_Q)
	var camera := battle.camera_rig.position
	destination = Vector3(-10, 0, 18)
	await _click(_minimap_point(destination), MOUSE_BUTTON_LEFT)
	_check(source.attack_move.active and source.attack_move.parent_order_id != parent and source.attack_move.final_destination.distance_to(destination) < 0.001 and battle.camera_rig.position == camera, "targeting minimap left-click dispatches mapped shared command without camera pan")
	parent = source.attack_move.parent_order_id
	await _click(_minimap_point(Vector3(10, 0, -5)), MOUSE_BUTTON_LEFT)
	_check(battle.camera_rig.position.distance_to(camera) > 1 and source.attack_move.parent_order_id == parent, "ordinary minimap left-click keeps camera behavior and does not replace attack-move")
	await _click(_minimap_point(Vector3(-8, 0, 18)), MOUSE_BUTTON_RIGHT)
	_check(not source.attack_move.active and source.moving, "ordinary minimap right-click remains Move and cancels accepted parent")
	battle.camera_rig.center_on_ground(Vector3.ZERO)
	await _frames(3)
	await _am_ui_key(KEY_Q)
	await _click(_minimap_point(Vector3(-10, 0, 18)), MOUSE_BUTTON_LEFT)
	await _am_ui_key(KEY_X)
	_check(not source.attack_move.active and not source.moving and source.combat.target_actor() == null, "viewport X Stop clears parent, engagement and movement")
	var pan_events := InputMap.action_get_events("camera_left")
	_check(pan_events.any(func(event: InputEvent) -> bool: return event is InputEventKey and event.physical_keycode == KEY_A), "A retains its existing camera pan binding")


func _am_ui_pending_layout(dimensions: Vector2i) -> void:
	root.size = dimensions
	await _frames(8)
	var panel := battle.production_panel
	var panel_rect := panel.get_global_rect()
	var minimap_rect := battle.tactical_minimap.get_global_rect()
	_check(battle.selection.attack_move_targeting and root.get_visible_rect().encloses(panel_rect) and panel_rect.encloses(panel.attack_move_hint.get_global_rect()) and panel_rect.encloses(panel.attack_move_button.get_global_rect()), "pending attack-move action/hint fit compact context at %s" % dimensions)
	_check(root.get_visible_rect().encloses(minimap_rect) and not panel_rect.intersects(minimap_rect) and not panel_rect.intersects(battle.help_panel.get_global_rect()), "pending context preserves unobstructed minimap and Help at %s" % dimensions)
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://validation-output/m9/screenshots")
	var screenshot := root.get_texture().get_image()
	var saved := screenshot.save_png("res://validation-output/m9/screenshots/targeting_%dx%d.png" % [dimensions.x, dimensions.y])
	_check(saved == OK and screenshot.get_size() == dimensions, "rendered new pending-target interface saved at %s" % dimensions)


func _am_ui_context() -> void:
	await _fresh_combined(1000, 600)
	var source := battle.units[0]
	await _am_ui_select(source)
	var sink := AttackKeySink.new()
	sink.focus_mode = Control.FOCUS_ALL
	sink.position = Vector2(700, 300)
	sink.size = Vector2(40, 40)
	battle.get_node("ControlsFeedback").add_child(sink)
	sink.grab_focus()
	await _am_ui_key(KEY_Q)
	_check(sink.presses == 1 and not battle.selection.attack_move_targeting, "focused GUI consumes Q before gameplay targeting")
	sink.release_focus()
	sink.queue_free()
	await _frames(2)
	await _am_ui_key(KEY_Q)
	battle.selection.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	_check(not battle.selection.attack_move_targeting and battle.selection._pending_picks.is_empty(), "focus loss clears pending targeting and queued confirmation")
	battle.selection.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	await _am_ui_key(KEY_Q)
	battle.selection.select_clicked(battle.collectors[0], false)
	await _frames(2)
	_check(not battle.selection.attack_move_targeting and not battle.production_panel.attack_move_button.visible, "ineligible collector selection cancels targeting and hides action")
	await _am_ui_key(KEY_Q)
	_check(not battle.selection.attack_move_targeting, "entirely ineligible selection cannot arm shortcut")
	battle.selection.select_building(battle.headquarters)
	var panel := battle.production_panel as ConstructionPanel
	await _click(panel.build_button.get_global_rect().get_center(), MOUSE_BUTTON_LEFT)
	_check(battle.placement.active, "ordinary build action enters placement")
	battle.selection.replace_units([source])
	await _am_ui_key(KEY_Q)
	_check(battle.placement.active and not battle.selection.attack_move_targeting, "building placement excludes attack-move targeting even with eligible selection")
	await _am_ui_key(KEY_ESCAPE)
	await _frames(2)
	_check(not battle.placement.active, "existing Escape placement cancellation survives new shortcut routing")
	await _am_ui_key(KEY_Q)
	var modal := AcceptDialog.new()
	modal.dialog_text = "Input isolation fixture"
	battle.add_child(modal)
	modal.popup_centered(Vector2i(320, 180))
	await _frames(3)
	var batch := battle.last_command_result
	await _click(_world_screen(Vector3(-8, 0, 12)), MOUSE_BUTTON_LEFT)
	_check(battle.last_command_result == batch and not source.attack_move.active, "open modal prevents underlying terrain confirmation")
	modal.hide()
	modal.queue_free()
	await _frames(2)
	battle.selection.cancel_attack_move_targeting()
	battle.selection.replace_units([source])
	await _tactical_key(3, true)
	await physics_frame
	_check(_complete(battle.issue_attack_move(Vector3(-8, 0, 12))), "group fixture begins accepted parent")
	var parent: int = source.attack_move.parent_order_id
	battle.selection.select_building(battle.headquarters)
	await _tactical_key(3)
	_check(battle.selection.selected_units() == [source] and source.attack_move.parent_order_id == parent and source.attack_move.active, "normal control-group recall selects without replacing existing attack-move")
	await _am_ui_key(KEY_F1)
	var help_text := ""
	for child in battle.help_panel.help_content.get_children():
		if child is Label: help_text += child.text + "\n"
	_check(battle.help_panel.is_open() and help_text.contains("Q / Attack Move") and help_text.contains("Ordinary Move only travels"), "F1 Help explains shortcut and Move/Attack Move distinction")
	await _am_ui_key(KEY_Q)
	var help_batch := battle.last_command_result
	await _click(battle.help_panel.help_content.get_global_rect().get_center(), MOUSE_BUTTON_LEFT)
	_check(battle.selection.attack_move_targeting and battle.last_command_result == help_batch and battle.selection._pending_picks.is_empty() and source.attack_move.parent_order_id == parent, "expanded Help body cannot confirm pending attack-move or queue a battlefield pick")
	await _click(battle.help_panel.help_button.get_global_rect().get_center(), MOUSE_BUTTON_LEFT)
	_check(not battle.help_panel.is_open() and battle.selection.attack_move_targeting and battle.last_command_result == help_batch and source.attack_move.parent_order_id == parent, "Close Help button preserves pending targeting and the original parent without confirmation")
	await _am_ui_key(KEY_F1)
	await _am_ui_key(KEY_ESCAPE)
	_check(not battle.help_panel.is_open() and battle.selection.attack_move_targeting and battle.last_command_result == help_batch and source.attack_move.parent_order_id == parent, "first Escape only closes Help while pending attack-move and original parent remain intact")
	await _am_ui_key(KEY_ESCAPE)
	_check(not battle.selection.attack_move_targeting and source.attack_move.parent_order_id == parent, "second Escape cancels targeting without replacing the original parent")
	await _am_ui_key(KEY_Q)
	_check(battle.selection.queue_attack_move_destination(Vector3(-10, 0, 18)), "pending-confirm fixture queues mapped destination")
	battle.selection.cancel_attack_move_targeting()
	await _frames(3)
	_check(source.attack_move.parent_order_id == parent, "cancelled queued confirmation cannot dispatch on the following physics tick")


func _am_ui_lifecycle() -> void:
	await _fresh_combined(1000, 600)
	var source := battle.units[0]
	var target := battle.units[3]
	# Isolated lifecycle fixture: close an actual temporary engagement, then create
	# local ignore state before result/Restart. No gameplay parameter is changed.
	source.position = Vector3(10, 0, 16)
	target.position = Vector3(18, 0, 16)
	source.halt_motion()
	target.halt_motion()
	await _frames(3)
	battle.selection.replace_units([source])
	await physics_frame
	_check(_complete(battle.issue_attack_move(Vector3(10, 0, 22))), "result lifecycle fixture accepts parent")
	if not await _until(func() -> bool: return source.attack_move.target_actor() == target, 0.6, "result lifecycle fixture creates actual temporary target"): return
	target.position = Vector3(27, 0, 18)
	await _frames(3)
	_check(source.attack_move.active and source.attack_move.is_ignoring(target), "leash release establishes actual local ignore state before Restart")
	await _am_ui_key(KEY_Q)
	_check(battle.selection.attack_move_targeting, "pending destination exists when match result occurs")
	var old_order: WeakRef = weakref(source.attack_move)
	var old_selection: WeakRef = weakref(battle.selection)
	var old_map: WeakRef = weakref(battle.tactical_minimap)
	await physics_frame
	TeamRules.damage_target(battle, 1, battle.enemy_headquarters, 10000, source)
	await _frames(3)
	_check(battle.result == BaseAssaultField.Result.VICTORY and not battle.gameplay_enabled and battle.result_overlay.visible and not battle.selection.attack_move_targeting and not source.attack_move.active, "ordinary result freezes active parent and cancels pending targeting")
	var scans: int = source.attack_move.scan_count
	var position := source.position
	var batch := battle.last_command_result
	await _am_ui_key(KEY_Q)
	await _click(_minimap_point(Vector3(-10, 0, 18)), MOUSE_BUTTON_LEFT)
	await _frames(30)
	_check(not battle.selection.attack_move_targeting and battle.last_command_result == batch and source.attack_move.scan_count == scans and source.position == position, "result overlay blocks targeting, dispatch, motion and scanning")
	await _click(battle.restart_button.get_global_rect().get_center(), MOUSE_BUTTON_LEFT)
	await _am_ui_rebind_restart()
	_check(old_order.get_ref() == null and old_selection.get_ref() == null and old_map.get_ref() == null, "Restart disposes old coordinator, input controller and minimap")
	_check(not battle.selection.attack_move_targeting and battle.selection._pending_picks.is_empty() and not battle.production_panel.attack_move_hint.visible, "Restart restores compact HUD with no old pending destination")
	var clean := true
	for unit in battle.units:
		if is_instance_valid(unit.attack_move):
			clean = clean and not unit.attack_move.active and unit.attack_move.target_actor() == null and unit.attack_move.scan_count == 0 and unit.attack_move.ignored_target_count() == 0
	_check(clean and battle.control_groups.group_members(3).is_empty(), "fresh actors contain no parent, temporary target, scan history, ignore entry or group membership")


func _am_ui_rebind_restart() -> void:
	await _frames(8)
	battle = current_scene as BaseAssaultField
	field = battle
	world = battle
	harvest = battle
	battle.camera_rig.edge_scrolling_enabled = false
	_check(battle.scene_file_path == "res://scenes/combined_arms_assault.tscn" and battle.result == BaseAssaultField.Result.RUNNING and battle.credits.balance(1) == 1000 and battle.units.size() == 8 and battle._producers.is_empty(), "Restart restores exact playable combined-arms defaults")


func _am_ui_integration() -> void:
	# Focused paid-production fixture: configured 2000 starting credits avoid
	# repeating the separately covered harvesting campaign. Costs/times are normal;
	# assault is delayed to 600s and all actors travel through ordinary navigation.
	await _fresh_combined(2000, 600)
	var escorts: Array[RTSUnit] = [battle.units[0], battle.units[1], battle.units[2]]
	battle.selection.replace_units(escorts)
	await _click(_minimap_point(Vector3(15, 0, 16)), MOUSE_BUTTON_RIGHT)
	_check(_complete(battle.last_command_result) and battle.last_command_result.accepted_ids.size() == 3, "existing three starting Rifles accept ordinary minimap Move to escort staging")
	var factory := await _factory()
	var site := await _ready_site(await _place(SECOND))
	if factory == null or site == null or not await _complete_site(site): return
	var barrack := site.building()
	var army: Array[RTSUnit] = []
	for building in [barrack, factory]:
		var producer: UnitProduction = building.production
		_check(producer.set_rally(1, Vector3(12, 0, 16 + army.size() * 2)).accepted, "integrated producer accepts ordinary southern staging rally")
		battle.selection.select_building(building)
		await _frames(2)
		await _click(battle.production_panel.train_button.get_global_rect().get_center(), MOUSE_BUTTON_LEFT)
		_check(producer.count() == 1, "viewport Train purchases actual " + building.recipe.display_name)
		if not await _until(func() -> bool: return producer.count() == 0, 9, "ordinary timed queue deploys " + building.recipe.display_name): return
		var unit := _last_unit(producer)
		if unit == null:
			_check(false, "produced army member remains registered")
			return
		army.append(unit)
	_check(army[0].combat_weapon == CombatField.RIFLE and army[1].combat_weapon == CombatField.ROCKET and battle.credits.balance(1) == 650, "normal factory/barracks construction and Rifle/Rocket queues spend exactly 1350 credits")
	var group: Array[RTSUnit] = army.duplicate()
	group.append_array(escorts)
	if not await _until(func() -> bool: return group.all(func(unit: Variant) -> bool: return is_instance_valid(unit) and not unit.moving and unit.movement_state == RTSUnit.MovementState.ARRIVED), 30, "produced Rifle/Rocket and existing escorts reach staging through actual movement"): return
	for unit in group:
		battle.camera_rig.center_on_ground(unit.position)
		await _frames(2)
		await _am_ui_select(unit, unit != army[0])
	await _tactical_key(3, true)
	battle.selection.select_building(factory)
	await _tactical_key(3)
	_check(battle.selection.selected_units() == group and battle.control_groups.group_members(3) == group, "normal viewport group assignment and recall selects both produced types with existing Rifle escorts")
	var damage := {"rifle": 0.0, "rocket": 0.0, "deaths": 0, "resumed": false}
	for hostile in battle.units:
		if hostile.owner_id != 2: continue
		hostile.combat.health.damaged.connect(func(amount: float, source: Node) -> void:
			if source is RTSUnit and army.has(source): damage["rocket" if source.combat_weapon == CombatField.ROCKET else "rifle"] += amount)
		hostile.combat.health.died.connect(func(_source: Node) -> void: damage["deaths"] += 1)
	await _click(battle.production_panel.attack_move_button.get_global_rect().get_center(), MOUSE_BUTTON_LEFT)
	_check(battle.selection.attack_move_targeting, "produced group arms attack-move through contextual HUD")
	await _click(_minimap_point(Vector3(24, 0, 8)), MOUSE_BUTTON_LEFT)
	var result := battle.last_command_result
	_check(_complete(result) and result.accepted_ids.size() == group.size() and result.assignments.size() == group.size(), "produced group with escorts confirms accurate attack-move through minimap")
	var slots := result.assignments.duplicate()
	var produced_travel: Dictionary[int, Dictionary] = {}
	for unit in army:
		produced_travel[unit.unit_id] = {"engaged": false, "resume_origin": null, "resumed_distance": 0.0}
	for tick in 3600:
		await _frames(1)
		if not army.all(func(unit: Variant) -> bool: return is_instance_valid(unit) and unit.is_alive()): break
		for unit in army:
			var travel: Dictionary = produced_travel[unit.unit_id]
			if unit.attack_move.target_actor() != null:
				travel["engaged"] = true
			if travel["engaged"] and unit.attack_move.active and unit.combat.target_actor() == null and unit.moving:
				if travel["resume_origin"] == null:
					travel["resume_origin"] = unit.position
				travel["resumed_distance"] = maxf(travel["resumed_distance"], unit.position.distance_to(travel["resume_origin"]))
			if damage["deaths"] > 0 and unit.attack_move.active and unit.combat.target_actor() == null and unit.moving: damage["resumed"] = true
		if army.all(func(unit: Variant) -> bool: return is_instance_valid(unit) and not unit.attack_move.active and unit.movement_state == RTSUnit.MovementState.ARRIVED): break
	var survived := army.all(func(unit: Variant) -> bool: return is_instance_valid(unit) and unit.is_alive())
	_check(damage["rifle"] > 0 and damage["rocket"] > 0 and damage["deaths"] > 0 and damage["resumed"], "paid produced army delivers both real damage types, destroys encountered enemy and resumes travel: %s" % damage)
	var arrived := survived and army.all(func(unit: Variant) -> bool: return is_instance_valid(unit) and not unit.attack_move.active and not unit.moving and unit.position.distance_to(slots[unit.unit_id]) <= unit.stopping_distance + 0.02)
	_check(arrived, "produced Rifle/Rocket arrive at original distinct minimap final slots after combat")
	_check(produced_travel.values().all(func(travel: Dictionary) -> bool: return travel["engaged"] and travel["resumed_distance"] > 0.5), "each produced unit engages and physically travels after release; escorts cannot satisfy either witness: %s" % produced_travel)
	_check(slots[army[0].unit_id].distance_to(slots[army[1].unit_id]) >= battle.destinations.slot_spacing - 0.001 if survived else false, "both produced units retain distinct final slots at normal formation spacing")
	var live_group: Array[RTSUnit] = []
	for actor in group:
		if not is_instance_valid(actor):
			print("ATTACK_MOVE_INTEGRATION_ACTOR: departed/freed group member")
			continue
		if battle.contains_unit(actor): live_group.append(actor)
		print("ATTACK_MOVE_INTEGRATION_ACTOR: id=%d produced=%s hp=%.1f position=%s slot=%s parent=%s movement=%s end=%s" % [actor.unit_id, army.has(actor), actor.combat.health.current, actor.position, slots.get(actor.unit_id), actor.attack_move.active, actor.movement_state, actor.attack_move.end_reason])
	if not survived: return
	_check(battle.result == BaseAssaultField.Result.RUNNING and battle.selection.selected_units() == live_group and battle.control_groups.group_members(3) == live_group and battle.production_panel.identity_label.text.contains("%d units" % live_group.size()), "completed attack-move preserves compact surviving-group HUD, control group and running match")
	if DisplayServer.get_name() != "headless":
		battle.camera_rig.center_on_ground(Vector3(24, 0, 8))
		await _frames(3)
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute("res://validation-output/m9/screenshots")
		_check(root.get_texture().get_image().save_png("res://validation-output/m9/screenshots/produced_army_1280x720.png") == OK, "rendered produced-army arrival and contextual group panel saved")
	# Normal result/Restart paths after the feature loop; full-health HQ combat is
	# covered by the existing source-matched tactical/base-assault regression suites.
	await physics_frame
	TeamRules.damage_target(battle, 1, battle.enemy_headquarters, 10000, army[0])
	await _frames(3)
	_check(battle.result == BaseAssaultField.Result.VICTORY and battle.result_overlay.visible, "existing objective destruction produces normal visible victory after attack-move loop")
	await _click(battle.restart_button.get_global_rect().get_center(), MOUSE_BUTTON_LEFT)
	await _am_ui_rebind_restart()
	_check(not battle.selection.attack_move_targeting and battle.control_groups.group_members(3).is_empty(), "integrated Restart clears pending input and produced group membership")
	print("ATTACK_MOVE_INTEGRATION: damage=%s produced_travel=%s final_slots=%s" % [damage, produced_travel, slots])
