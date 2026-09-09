extends "res://tests/fixtures/tempest_harness.gd"
## Viewport and physics input checks. Completed facilities/two plants and a
## 0.2-second charge are explicit isolated UI fixtures, not earned integration.
## Warning remains six seconds. No result here represents human playtesting.


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1280, 720)
	var logger := EngineErrorProbe.new()
	OS.add_logger(logger)
	await _tempest_normal_ui()
	await _tempest_target_ui()
	await _tempest_lifecycle_ui()
	if is_instance_valid(field): field.queue_free()
	await _frames(6)
	_check(root.get_children().is_empty(), "Tempest UI teardown removes targets, warning visuals and old controls")
	OS.remove_logger(logger)
	_check(logger.error_count() == 0, "Tempest viewport controls and teardown have no native errors")
	print("TEMPEST_UI_CHECKS: %d checks, %d failures; native_errors=%d" % [checks, failures, logger.error_count()])
	quit(0 if failures == 0 else 1)


func _tempest_layouts(label: String, include_help: bool = true) -> void:
	for dimensions in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		await _hud_layout(dimensions)
		await _tempest_capture("%s_%dx%d" % [label, dimensions.x, dimensions.y])
		if include_help:
			await _hud_key(KEY_F1)
			_check(tempest.help_panel.is_open(), "F1 expands Tempest Help without changing selection")
			await _hud_layout(dimensions)
			await _tempest_capture("%s_help_%dx%d" % [label, dimensions.x, dimensions.y])
			await _hud_key(KEY_F1)
			_check(not tempest.help_panel.is_open(), "F1 restores compact Tempest Help")
	root.size = Vector2i(1280, 720)
	await _frames(8)


func _tempest_normal_ui() -> void:
	await _fresh_tempest(1000)
	await _hud_pick_unit(_player_builders()[0])
	var panel := tempest.production_panel as ConstructionPanel
	_check(panel.tempest_button.visible and panel.tempest_button.disabled and panel.tempest_button.text.contains("5000") and panel.tempest_button.text.contains("45"), "normal Bulldozer shows disabled correctly priced 45s Tempest choice")
	var reason := tempest.construction.can_begin(1, _player_builders()[0], tempest.tempest_definition)
	_check(not reason.is_empty() and panel.tempest_button.tooltip_text == reason, "Tempest button exposes the actual authoritative construction rejection")
	_check(panel.wall_button.visible and panel.gate_button.visible and panel.airfield_button.visible and panel.depot_button.visible, "Tempest choice preserves existing wall, gate, airfield and depot controls")
	var help := ""
	for child in tempest.help_panel.help_content.get_children():
		if child is Label: help += child.text + "\n"
	_check(help.contains("ground-only") and help.contains("FRIENDLY FIRE") and help.contains("180s") and help.contains("Factory or Airfield"), "Help declares ground-only friendly fire, real charge and producer prerequisite")
	await _tempest_layouts("tempest_normal_builder")


func _tempest_isolated_ready() -> TempestArray:
	await _fresh_tempest(1000)
	_tempest_power()
	var facility := _tempest_fixture(TEMPEST_POINT, 1, 0.2, 6.0)
	if not await _tempest_ready(facility): return null
	# UI fixture centers the ordinary camera, then projects against its actual
	# current transform after layout. No assumed smoothing completion is needed.
	tempest.camera_rig.center_on_ground(facility.global_position)
	await _frames(12)
	await _hud_pick_building(facility)
	return facility


func _tempest_target_ui() -> void:
	var facility := await _tempest_isolated_ready()
	if facility == null: return
	var panel := tempest.production_panel as ConstructionPanel
	var targeting := tempest.tempest_targeting
	_check(panel.tempest_launch_button.visible and not panel.tempest_launch_button.disabled and panel.selection_details.text.contains("1200 / 1200") and panel.selection_details.text.contains("8") and panel.tempest_status.text.contains("READY"), "selected ready facility shows authoritative HP, power, readiness and Launch")
	_check(not panel.train_button.visible and not panel.progress_bar.visible and not panel.rows.visible, "Tempest selection exposes no production recipes or queue")
	tempest.tactical_minimap.refresh_markers()
	_check(_marker(facility.get_instance_id()).get("kind") == "tempest_array", "minimap uses distinct completed Tempest facility marker")
	await _tempest_layouts("tempest_ready")
	var credits := tempest.credits.balance(1)
	var orders := tempest.last_command_result
	await _click(panel.tempest_launch_button.get_global_rect().get_center(), MOUSE_BUTTON_LEFT)
	_check(targeting.active and facility.is_ready() and tempest.tempest_strikes.warning_markers().is_empty() and not tempest.selection.placement_active and not tempest.selection.attack_move_targeting, "viewport Launch enters exclusive unpaid targeting without committing a strike")
	_motion(_world_screen(Vector3(-8, 0, 16)))
	await _frames(3)
	_check(targeting.preview.visible, "valid battlefield ground displays the radius preview")
	await _tempest_layouts("tempest_target_preview")
	await _click(panel.credit_label.get_global_rect().get_center(), MOUSE_BUTTON_LEFT)
	_check(targeting.active and facility.is_ready() and tempest.tempest_strikes.warning_markers().is_empty() and tempest.selection.selected_building() == facility, "HUD left-click cannot leak through and launch or change selection")
	await _hud_key(KEY_Q)
	_check(targeting.active and not tempest.selection.attack_move_targeting, "Q cannot overlap active Tempest targeting")
	await _click(_minimap_point(Vector3.ZERO), MOUSE_BUTTON_RIGHT)
	_check(not targeting.active and facility.is_ready() and tempest.last_command_result == orders, "right-click over minimap cancels without issuing a move or consuming charge")
	await _click(panel.tempest_launch_button.get_global_rect().get_center(), MOUSE_BUTTON_LEFT)
	await _hud_key(KEY_ESCAPE)
	_check(not targeting.active and facility.is_ready(), "Escape cancels Tempest targeting and preserves charge")
	await _click(panel.tempest_launch_button.get_global_rect().get_center(), MOUSE_BUTTON_LEFT)
	_check(targeting.queue_target(Vector3(999, 0, 999)), "invalid target request reaches the physics commit boundary")
	await _frames(2)
	_check(targeting.active and facility.is_ready() and targeting.feedback.contains("Invalid target") and tempest.tempest_strikes.warning_markers().is_empty(), "out-of-map target rejects with clear feedback and no mutation")
	await _click(tempest.tactical_minimap.global_position + Vector2(8, 8), MOUSE_BUTTON_LEFT)
	_check(targeting.active and facility.is_ready() and targeting.feedback.contains("Invalid target"), "minimap border rejects target without panning or consuming readiness")
	targeting.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	_check(not targeting.active and facility.is_ready(), "focus loss cancels pending Tempest targeting")
	targeting.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	await _click(panel.tempest_launch_button.get_global_rect().get_center(), MOUSE_BUTTON_LEFT)
	tempest.selection.select_clicked(_player_builders()[0], false)
	_check(not targeting.active and facility.is_ready(), "incompatible selection change cancels pending targeting")
	tempest.selection.select_building(facility)
	await _frames(2)
	await _click(panel.tempest_launch_button.get_global_rect().get_center(), MOUSE_BUTTON_LEFT)
	var target := Vector3(-8, 0, 16)
	await _click(_world_screen(target), MOUSE_BUTTON_LEFT)
	var warnings := tempest.tempest_strikes.warning_markers()
	_check(not targeting.active and warnings.size() == 1 and targeting.last_result.get("accepted", false), "battlefield left-click commits exactly one strike through physics authority")
	if warnings.size() == 1:
		_check(Vector2(warnings[0].target.x, warnings[0].target.z).distance_to(Vector2(target.x, target.z)) < 0.02 and warnings[0].remaining > 5.8, "battlefield ground center is fixed without silent retargeting and starts six-second warning")
	_check(tempest.credits.balance(1) == credits and tempest.last_command_result == orders, "strike launch takes no credits and creates no ordinary world order")
	tempest.tactical_minimap.refresh_markers()
	_check(_marker_count("tempest_strike") == 1, "minimap displays distinct committed radius/countdown strike marker")
	await _tempest_layouts("tempest_committed_warning")
	if not await _tempest_ready(facility): return
	await _click(panel.tempest_launch_button.get_global_rect().get_center(), MOUSE_BUTTON_LEFT)
	var camera_before := tempest.camera_rig.global_position
	var before_count := tempest.tempest_strikes.warning_markers().size()
	var edge := Vector3(tempest.field_bounds.position.x + 0.1, 0, tempest.field_bounds.end.y - 0.1)
	await _click(_minimap_point(edge), MOUSE_BUTTON_LEFT)
	warnings = tempest.tempest_strikes.warning_markers()
	_check(not targeting.active and warnings.size() == before_count + 1 and tempest.camera_rig.global_position.distance_to(camera_before) < 0.001, "minimap left-click commits a near-edge target rather than panning")
	_check(warnings.any(func(warning: Dictionary) -> bool: return warning.target.distance_to(edge) < 0.02), "target center inside bounds remains legal when radius extends beyond map")


func _tempest_lifecycle_ui() -> void:
	var facility := await _tempest_isolated_ready()
	if facility == null: return
	var panel := tempest.production_panel as ConstructionPanel
	var targeting := tempest.tempest_targeting
	await _click(panel.tempest_launch_button.get_global_rect().get_center(), MOUSE_BUTTON_LEFT)
	for building in tempest.registered_buildings():
		if building.owner_id == 1 and building.kind == RTSBuilding.Kind.POWER_PLANT:
			building.queue_free()
	await _frames(3)
	_check(not targeting.active and facility.is_ready() and panel.tempest_launch_button.disabled and panel.selection_details.text.to_lower().contains("power"), "losing power cancels ready targeting, retains charge and disables Launch")
	var remaining := facility.charge_remaining()
	await _frames(12)
	_check(facility.charge_remaining() == remaining, "unpowered authoritative UI countdown does not keep decreasing")
	_tempest_power()
	await _frames(3)
	await _click(panel.tempest_launch_button.get_global_rect().get_center(), MOUSE_BUTTON_LEFT)
	facility.queue_free()
	await _frames(4)
	_check(not targeting.active and not targeting.preview.visible and tempest.tempest_strikes.warning_markers().is_empty(), "source deletion cancels uncommitted preview without producing a strike")
	facility = _tempest_fixture(TEMPEST_POINT, 1, 0.2, 6.0)
	if not await _tempest_ready(facility): return
	tempest.selection.select_building(facility)
	await _frames(3)
	await _click(panel.tempest_launch_button.get_global_rect().get_center(), MOUSE_BUTTON_LEFT)
	await _click(_minimap_point(Vector3(-8, 0, 16)), MOUSE_BUTTON_LEFT)
	_check(tempest.tempest_strikes.warning_markers().size() == 1, "lifecycle fixture has one actual input-committed unresolved strike")
	var old_targeting := weakref(targeting)
	var old_source := weakref(facility)
	# Explicit isolated result trigger; combat and earned suites verify damage.
	await physics_frame
	TeamRules.damage_target(tempest, 1, tempest.enemy_headquarters, 10000, _player_builders()[0])
	tempest.resolve_result()
	await _frames(3)
	_check(not targeting.active and tempest.tempest_strikes.warning_markers().is_empty() and tempest.restart_button.visible and panel.tempest_launch_button.disabled, "result cancels unresolved strike work and disables launch controls")
	await _tempest_layouts("tempest_result", false)
	await _click(tempest.restart_button.get_global_rect().get_center(), MOUSE_BUTTON_LEFT)
	await _frames(12)
	_adopt_tempest(current_scene as SuperweaponAssaultField)
	_check(tempest != null and old_targeting.get_ref() == null and old_source.get_ref() == null, "viewport Restart releases old source and targeting listeners")
	_check(not tempest.tempest_targeting.active and tempest.tempest_strikes.warning_markers().is_empty() and tempest.construction.sites.is_empty() and tempest.credits.balance(1) == 1000, "Restart restores normal wallet with no inherited facilities, targets or impacts")
	await _frames(370)
	_check(tempest.tempest_strikes.warning_markers().is_empty() and tempest.headquarters.health.current == tempest.headquarters.health.maximum, "old committed warning cannot damage replacement match after its original deadline")
