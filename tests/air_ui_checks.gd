extends "res://tests/fixtures/air_harness.gd"
## Normal opening UI plus labelled funded, paused-enemy paid-construction fixture.
## All input is automated viewport input; no human keyboard/mouse playtest.

func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1280, 720)
	var logger := EngineErrorProbe.new()
	OS.add_logger(logger)
	await _air_normal_ui()
	await _air_paid_ui()
	if is_instance_valid(field): field.queue_free()
	await _frames(6)
	_check(root.get_children().is_empty(), "air UI teardown clears old scene and controls")
	OS.remove_logger(logger)
	_check(logger.error_count() == 0, "air UI has no native errors or warnings")
	print("AIR_UI_CHECKS: %d checks, %d failures; native_errors=%d" % [checks, failures, logger.error_count()])
	quit(0 if failures == 0 else 1)


func _air_capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://validation-output/m15/screenshots")
	var picture := root.get_texture().get_image()
	_check(picture.save_png("res://validation-output/m15/screenshots/%s.png" % label) == OK, "saved air UI capture " + label)


func _air_layouts(label: String) -> void:
	for dimensions in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		await _hud_layout(dimensions)
		await _air_capture("%s_%dx%d" % [label, dimensions.x, dimensions.y])
		await _hud_key(KEY_F1)
		_check(air.help_panel.is_open(), "F1 opens compact air Help")
		await _hud_layout(dimensions)
		await _air_capture("%s_help_%dx%d" % [label, dimensions.x, dimensions.y])
		await _hud_key(KEY_ESCAPE)
		_check(not air.help_panel.is_open() and air.manual_pause_active, "Escape closes Help and pauses without a world command")
		await _hud_key(KEY_ESCAPE)
		_check(not air.manual_pause_active, "Escape resumes the air match")
	root.size = Vector2i(1280, 720)
	await _frames(4)


func _air_normal_ui() -> void:
	await _fresh_air(1000, true)
	var actor := _player_builders()[0]
	await _hud_pick_unit(actor)
	var panel := air.production_panel as ConstructionPanel
	_check(panel.airfield_button.visible and panel.air_defense_button.visible and panel.airfield_button.text.contains("1000") and panel.air_defense_button.text.contains("800"), "normal builder exposes priced Airfield and AA construction")
	_check(air.sortie_delay == 120 and not air.sortie_issued and air.enemy_config.first_wave_time == 90, "normal scene retains ground timing and single120-second air sortie")
	await _air_layouts("air_normal_builder")
	await _click(panel.air_defense_button.get_global_rect().get_center(), MOUSE_BUTTON_LEFT)
	_motion(_world_screen(FIRST))
	await _frames(8)
	_check(air.placement.active and air.placement.definition == AIR_DEFENSE and air.placement.range_indicator.visible and air.credits.balance(1) == 1000, "actual AA preview is visible without payment or demand")
	await _air_layouts("air_normal_preview")
	await _click(Vector2(600, 300), MOUSE_BUTTON_RIGHT)
	_check(not air.placement.active and air.construction.sites.is_empty(), "right click cancels air placement without committing a site")


func _air_paid_ui() -> void:
	await _fresh_air(6000) # Labelled UI fixture: extra starting funds and paused enemy.
	var builder := _player_builders()[0]
	var producer := await _power_build(builder, AIRFIELD, FIRST)
	if producer == null: return
	await _hud_pick_building(producer)
	var panel := air.production_panel as ConstructionPanel
	_check(panel.train_button.visible and panel.train_button.text.contains("Attack Helicopter") and panel.train_button.text.contains("600") and panel.power_warning.visible, "selected paid Airfield exposes helicopter queue and low-power slowdown")
	await _click(panel.train_button.get_global_rect().get_center(), MOUSE_BUTTON_LEFT)
	_check(producer.production.count() == 1, "viewport training control pays and queues one helicopter")
	for index in 4:
		await _click(panel.train_button.get_global_rect().get_center(), MOUSE_BUTTON_LEFT)
	_check(producer.production.count() == 5 and panel.train_button.disabled, "full five-job helicopter queue disables training")
	await _air_layouts("air_paid_production")
	var queued := producer.production.jobs()
	for index in range(1, queued.size()):
		await _click(panel.cancel_buttons[queued[index].id].get_global_rect().get_center(), MOUSE_BUTTON_LEFT)
	_check(producer.production.count() == 1 and air.credits.balance(1) == 4400, "visible stable-ID cancellations refund four queued aircraft once")
	if not await _until(func() -> bool: return not producer.production.last_deployment.is_empty(), 22, "paid low-power helicopter physically deploys after20 seconds"): return
	var helicopter := _last_unit(producer.production) as AttackHelicopter
	if helicopter == null:
		_check(false, "paid queue deployed actual helicopter")
		return
	if not await _until(func() -> bool: return not helicopter.is_taking_off(), 3, "actual paid aircraft finishes takeoff"): return
	await physics_frame
	air.selection.select_clicked(helicopter, false)
	_check(air.issue_move(Vector3(-8, 0, 16)).is_complete(), "paid aircraft moves to clear viewport inspection lane")
	if not await _until(func() -> bool: return not helicopter.moving, 6, "paid aircraft arrives at elevated inspection location"): return
	air.camera_rig.center_on_ground(Vector3(-8, 0, 12))
	await _frames(8)
	await _hud_pick_unit(helicopter)
	_check(helicopter.selection_indicator.visible and helicopter.selection_anchor.global_position.distance_to(helicopter.global_position) < 0.01 and panel.selection_details.text.contains("180 / 180") and panel.selection_details.text.contains("Hovering"), "elevated picking/selection anchor and contextual health/status agree")
	air.selection.replace_units([])
	var pixel := _screen(helicopter)
	air.selection.select_rectangle(Rect2(pixel - Vector2(10,10), Vector2(20,20)), false)
	_check(air.selection.selected_units() == [helicopter], "drag rectangle selects the actual elevated aircraft anchor")
	await _hud_key(KEY_4, true)
	air.selection.replace_units([])
	await _hud_key(KEY_4)
	_check(air.selection.selected_units() == [helicopter] and air.control_groups.group_members(4) == [helicopter], "Ctrl4 and4 use existing aircraft selection/group registry")
	air.tactical_minimap.refresh_markers()
	_check(_marker(helicopter.get_instance_id()).get("kind") == "aircraft" and _marker(producer.get_instance_id()).get("kind") == "airfield", "minimap gives real XZ aircraft and Airfield distinct shapes")
	await _air_layouts("air_paid_selected_helicopter")
	await _click(_minimap_point(Vector3(-10, 0, 15)), MOUSE_BUTTON_RIGHT)
	_check(air.last_command_result.has_acceptance() and helicopter.assigned_destination.y == 8, "minimap Move captures bounded flight assignment")
	await _hud_key(KEY_Q)
	_check(air.selection.attack_move_targeting, "Q enters aircraft Attack Move targeting")
	await _click(_minimap_point(Vector3(-12, 0, 16)), MOUSE_BUTTON_LEFT)
	_check(helicopter.attack_move.active and helicopter.attack_move.final_slot.y == 8, "minimap Q destination stays in flight domain")
	await _hud_key(KEY_X)
	_check(not helicopter.attack_move.active and not helicopter.moving, "X clears aircraft Attack Move and hovers")
	var rifle := air.units.filter(func(unit: RTSUnit) -> bool: return unit.owner_id == 1 and not unit is Bulldozer and not unit is AttackHelicopter)[0] as RTSUnit
	air.selection.replace_units([rifle, helicopter])
	await physics_frame
	var mixed := air.issue_move(Vector3(-10, 0, 16))
	_check(mixed.is_complete() and mixed.assignments[rifle.unit_id].y == 0 and mixed.assignments[helicopter.unit_id].y == 8, "mixed command captures ground and air destinations separately")
	var previous := helicopter.order_version
	var rejected := air.issue_attack(air.headquarters)
	_check(not rejected.has_acceptance() and helicopter.order_version == previous, "friendly explicit attack rejects without replacing mixed movement")
	await _hud_key(KEY_X)
	var aa := await _power_build(builder, AIR_DEFENSE, SECOND)
	if aa == null: return
	await _hud_pick_building(aa)
	_check(panel.identity_label.text.contains("Air Defense Battery") and panel.selection_details.text.contains("600 / 600") and panel.selection_details.text.contains("No power") and not panel.train_button.visible, "selected builder-created AA displays health and power without production controls")
	air.tactical_minimap.refresh_markers()
	_check(_marker(aa.get_instance_id()).get("kind") == "air_defense_battery", "AA has its own minimap glyph")
	await _air_layouts("air_paid_selected_aa")
	var old_aircraft: WeakRef = weakref(helicopter)
	var old_grid := air.power_grid
	await physics_frame
	TeamRules.damage_target(air, 1, air.enemy_headquarters, 10000, rifle) # Labelled UI result trigger; earned suite proves combat.
	air.resolve_result()
	_check(air.result == BaseAssaultField.Result.VICTORY and air.restart_button.visible, "result freezes aircraft and leaves Restart")
	var stopped := helicopter.global_position
	await _frames(20)
	_check(helicopter.global_position == stopped and not helicopter.move_to(Vector3.ZERO), "result blocks delayed flight movement")
	for dimensions in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		await _hud_layout(dimensions)
		await _air_capture("air_result_%dx%d" % [dimensions.x, dimensions.y])
	await _click(air.restart_button.get_global_rect().get_center(), MOUSE_BUTTON_LEFT)
	await _frames(12)
	air = current_scene as AirAssaultField
	_adopt_defense(air)
	_check(air != null and old_aircraft.get_ref() == null and old_grid.changed.get_connections().is_empty() and air.control_groups.group_members(4).is_empty() and not air.sortie_issued, "Restart removes old aircraft/listeners/groups and resets scripted sortie")
	_check(air.power_snapshot(1).required == 0 and air.power_snapshot(2).required == 8 and air.credits.balance(1) == 1000, "Restart rebuilds ordinary starting power and wallet")
	await _air_layouts("air_normal_restart")
