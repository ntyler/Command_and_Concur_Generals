extends "res://tests/fixtures/defense_harness.gd"
## Normal configured scene: original1000 credits, normal90/60 enemy schedule,
## real selected-Bulldozer700-credit battery placement/work, no prebuilt player
## defense or hidden generation. Viewport input is automated, not human play.
## Only the result-overlay trigger is an explicitly labelled direct HQ death.


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1280, 720)
	var logger := EngineErrorProbe.new()
	OS.add_logger(logger)
	await _defense_ui_normal()
	if is_instance_valid(field): field.queue_free()
	await _frames(6)
	_check(root.get_children().is_empty() and get_nodes_in_group("combat_projectiles").is_empty(), "defense UI teardown removes fields, controls and markers")
	OS.remove_logger(logger)
	_check(logger.error_count() == 0, "defense normal viewport input/layout/Restart produce no native errors or warnings")
	print("DEFENSE_UI_CHECKS: %d checks, %d failures; native_errors=%d" % [checks, failures, logger.error_count()])
	quit(0 if failures == 0 else 1)


func _defense_ui_layouts(label: String) -> void:
	for dimensions in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		await _hud_layout(dimensions)
		await _defense_capture("%s_%dx%d" % [label, dimensions.x, dimensions.y])
		await _hud_key(KEY_F1)
		_check(defended.help_panel.is_open(), "normal defense viewport F1 opens expanded Help")
		await _hud_layout(dimensions)
		await _defense_capture("%s_help_%dx%d" % [label, dimensions.x, dimensions.y])
		await _hud_key(KEY_ESCAPE)
		_check(not defended.help_panel.is_open(), "Escape closes defense Help while retaining selection")
	root.size = Vector2i(1280, 720)
	await _frames(5)


func _defense_ui_normal() -> void:
	await _fresh_defense(1000, true)
	var panel := defended.production_panel as ConstructionPanel
	var actor := _player_builders()[0]
	_check(defended.enemy_controller.is_physics_processing() and defended.enemy_config.first_wave_time == 90 and defended.enemy_config.wave_interval == 60, "screenshots inspect normal live playable scene with original90/60 schedule")
	await _hud_pick_building(defended.headquarters)
	_check(not panel.defense_button.visible and panel.train_button.visible and panel.train_button.text.contains("Bulldozer"), "HQ remains builder producer without direct defense construction")
	await _hud_pick_unit(actor)
	_check(panel.defense_button.visible and not panel.defense_button.disabled and panel.defense_button.text.contains("700") and panel.defense_button.text.contains("12") and panel.defense_button.tooltip_text.contains("3 power"), "selected original Bulldozer exposes priced12-second3-power defense choice")
	await _defense_ui_layouts("defense_normal_builder")
	var help := ""
	for child in defended.help_panel.help_content.get_children():
		if child is Label: help += child.text + "\n"
	_check(help.to_lower().contains("defense") and help.contains("3") and help.to_lower().contains("power"), "compact Help explains the added defense and power requirement")
	await _hud_key(KEY_2, true)
	await _hud_key(KEY_Q)
	_check(not defended.selection.attack_move_targeting and defended.control_groups.group_members(2) == [actor], "normal builder retains group assignment and cannot use combat-only Q")
	await _click(panel.defense_button.get_global_rect().get_center(), MOUSE_BUTTON_LEFT)
	_motion(_world_screen(FIRST))
	await _frames(8)
	_check(defended.placement.active and defended.placement.valid and defended.placement.definition == DEFENSE and defended.placement.range_indicator.visible and defended.credits.balance(1) == 1000 and _grid_is(1, 0, 0), "free actual defense preview shows relevant range without cost or demand")
	await _defense_ui_layouts("defense_normal_preview")
	_check(defended.placement.active, "Help and layout preserve uncommitted defense placement")
	await _click(panel.credit_label.get_global_rect().get_center(), MOUSE_BUTTON_LEFT)
	_check(defended.construction.sites.is_empty() and defended.credits.balance(1) == 1000, "context panel clicks cannot leak into defense placement")
	_motion(_world_screen(FIRST))
	await _frames(3)
	await _click(_world_screen(FIRST), MOUSE_BUTTON_LEFT)
	var result := defended.placement.last_result
	if result == null:
		_check(false, "viewport defense placement reports its committed result")
		return
	_check(result.accepted and result.paid == 700 and defended.credits.balance(1) == 300 and not defended.placement.active and not defended.placement.range_indicator.visible, "normal viewport placement commits700 once and clears free preview/range")
	var site := await _builder_arrival(result)
	if site == null: return
	var battery := site.building() as GroundDefenseBattery
	await _hud_key(KEY_2)
	await _hud_key(KEY_X)
	await _hud_pick_building(battery)
	_check(site.state == ConstructionSite.State.PAUSED and panel.identity_label.text.contains("Ground Defense") and panel.site_status.text.to_lower().contains("paused") and panel.cancel_site_button.visible and not panel.train_button.visible and _grid_is(1, 0, 0), "viewport X pauses actual unfinished defense and site panel offers existing cancellation without production")
	await _hud_key(KEY_2)
	await _click(_world_screen(battery.global_position + Vector3.UP), MOUSE_BUTTON_RIGHT)
	_check(site.builder() == actor and actor.assigned_site_id == site.site_id, "viewport group recall and right-click resume same defense with original builder")
	if not await _builder_complete(site): return
	await _hud_pick_building(battery)
	_check(panel.identity_label.text.contains("Ground Defense Battery") and panel.selection_details.text.contains("600 / 600 HP") and panel.selection_details.text.contains("Power required: 3") and panel.selection_details.text.contains("No power"), "selected completed normal battery shows name/health/nominal demand/no-power status")
	_check(panel.power_label.text == "Power: 0 generated / 3 required" and panel.power_warning.visible and panel.power_warning.text.contains("cannot fire") and not panel.train_button.visible and panel.cancel_buttons.is_empty() and not panel.cancel_site_button.visible and not panel.defense_button.visible, "normal shortage feedback explains fire inhibition and completed defense has no queue/build/sell controls")
	_check(battery.range_indicator.visible and not defended.enemy_battery.range_indicator.visible and not battery.rally_indicator.visible, "range is visible only for selected battery with no rally and no permanent enemy range")
	defended.tactical_minimap.refresh_markers()
	_check(_marker(battery.get_instance_id()).get("kind") == "ground_defense_battery" and _marker_count("ground_defense_battery") == 2, "normal map distinctly marks completed player and enemy batteries")
	await _defense_ui_layouts("defense_normal_selected_no_power")
	var position := battery.global_transform
	await _hud_key(KEY_Q)
	await _hud_key(KEY_3, true)
	await _click(_minimap_point(Vector3(-6, 0, 16)), MOUSE_BUTTON_RIGHT)
	_check(not defended.selection.attack_move_targeting and defended.control_groups.group_members(3).is_empty() and battery.global_transform == position and not battery.rally_indicator.visible, "battery selection cannot issue Q/mobile groups/minimap Move/rally")
	var rifle := defended.units[0]
	await _hud_pick_unit(rifle)
	_check(not battery.range_indicator.visible and not panel.defense_button.visible, "army selection clears battery range and contextual build controls")
	await _hud_key(KEY_3, true)
	await _hud_key(KEY_Q)
	_check(defended.selection.attack_move_targeting, "normal army selection still enters Q Attack Move after defense panel")
	await _click(_minimap_point(Vector3(-8, 0, 14)), MOUSE_BUTTON_LEFT)
	_check(rifle.attack_move.active, "normal minimap dispatches selected Rifle Attack Move")
	await _hud_key(KEY_X)
	await _hud_key(KEY_2)
	await _hud_key(KEY_3)
	_check(not rifle.attack_move.active and defended.selection.selected_units() == [rifle] and defended.control_groups.group_members(2) == [actor], "X and separate builder/army group recalls remain usable after battery selection")
	var old_battery: WeakRef = weakref(battery)
	var old_grid := defended.power_grid
	await physics_frame
	TeamRules.damage_target(defended, 1, defended.enemy_headquarters, 10000, rifle) # Labelled UI result trigger only; earned suite uses real weapons.
	defended.resolve_result()
	_check(defended.result == BaseAssaultField.Result.VICTORY and defended.restart_button.visible, "normal HQ result leaves Restart usable after battery selection")
	for dimensions in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		root.size = dimensions
		await _frames(8)
		_check(root.get_visible_rect().encloses(defended.restart_button.get_global_rect()), "normal Restart button fits viewport %s" % dimensions)
		await _defense_capture("defense_normal_result_%dx%d" % [dimensions.x, dimensions.y])
	await _click(defended.restart_button.get_global_rect().get_center(), MOUSE_BUTTON_LEFT)
	await _frames(10)
	_adopt_defense(current_scene as DefenseAssaultField)
	if defended == null:
		_check(false, "viewport Restart reloads defense scenario")
		return
	defended.camera_rig.edge_scrolling_enabled = false
	panel = defended.production_panel as ConstructionPanel
	_check(old_battery.get_ref() == null and old_grid.changed.get_connections().is_empty() and defended.power_grid != old_grid and defended.credits.balance(1) == 1000 and _grid_is(1, 0, 0) and _grid_is(2, 10, 5), "normal viewport Restart removes old battery/listeners and restores configured starting power/wallet")
	_check(not panel.power_warning.visible and not defended.help_panel.is_open() and defended.control_groups.group_members(2).is_empty() and defended.control_groups.group_members(3).is_empty() and not defended.enemy_battery.range_indicator.visible, "Restart clears stale shortage, Help, groups and range state")
	await _hud_pick_unit(_player_builders()[0])
	await _defense_ui_layouts("defense_normal_restart")
