extends "res://tests/power_checks.gd"
## Focused M13 viewport input and layout. Extra fixture funds isolate interface
## coverage; every player structure still uses normal paid builder construction.
## The separate earned-opening suite supplies the affordability acceptance.


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1280, 720)
	var logger := EngineErrorProbe.new()
	OS.add_logger(logger)
	await _power_ui_play()
	if is_instance_valid(field): field.queue_free()
	await _frames(6)
	_check(root.get_children().is_empty() and get_nodes_in_group("combat_projectiles").is_empty(), "power UI teardown removes fields, model listeners, queues and controls")
	OS.remove_logger(logger)
	_check(logger.error_count() == 0, "power viewport input, layout, Restart and teardown have no native errors or warnings")
	print("POWER_UI_CHECKS: %d checks, %d failures; native_errors=%d" % [checks, failures, logger.error_count()])
	quit(0 if failures == 0 else 1)


func _power_ui_layouts(label: String) -> void:
	for dimensions in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		await _hud_layout(dimensions)
		await _power_capture("%s_%dx%d" % [label, dimensions.x, dimensions.y])
		await _hud_key(KEY_F1)
		_check(powered.help_panel.is_open(), "viewport F1 expands powered Help")
		await _hud_layout(dimensions)
		await _power_capture("%s_help_%dx%d" % [label, dimensions.x, dimensions.y])
		await _hud_key(KEY_ESCAPE)
		_check(not powered.help_panel.is_open(), "Escape closes powered Help without losing context")
	root.size = Vector2i(1280, 720)
	await _frames(5)


func _power_ui_place(button: Button, definition: ConstructionDefinition, point: Vector3) -> ConstructionSite:
	await _click(button.get_global_rect().get_center(), MOUSE_BUTTON_LEFT)
	_motion(_world_screen(point))
	await _frames(8)
	var ready := powered.placement.active and powered.placement.valid and powered.placement.definition == definition
	_check(ready, "viewport build button creates the expected authoritative valid preview")
	if not ready: return null
	var balance := powered.credits.balance(1)
	await _click(_world_screen(point), MOUSE_BUTTON_LEFT)
	var result := powered.placement.last_result
	if result == null:
		_check(false, "viewport placement reports a committed construction result")
		return null
	_check(result.accepted and powered.credits.balance(1) == balance - definition.credit_cost, "viewport placement spends the ordinary definition cost exactly once")
	return await _builder_arrival(result)


func _power_ui_play() -> void:
	await _fresh_power(4000)
	var panel := powered.production_panel as ConstructionPanel
	var actor := _player_builders()[0]
	_check(panel.power_label.visible and panel.power_label.text == "Power: 0 generated / 0 required" and not panel.power_warning.visible, "normal zero-demand opening displays owner-local power separately from credits")
	await _hud_pick_building(powered.headquarters)
	_check(panel.train_button.visible and panel.train_button.text.contains("Bulldozer") and not panel.power_plant_button.visible, "powered HQ retains Bulldozer production without direct Power Plant construction")
	await _hud_pick_unit(actor)
	_check(panel.power_plant_button.visible and not panel.power_plant_button.disabled and panel.power_plant_button.text.contains("500") and panel.power_plant_button.text.contains("10"), "selected owned Bulldozer exposes the priced ten-second Power Plant button")
	await _power_ui_layouts("power_builder_choices")
	var instructions := ""
	for child in powered.help_panel.help_content.get_children():
		if child is Label: instructions += child.text + "\n"
	_check(instructions.contains("Power Plant") and instructions.contains("50%") and instructions.contains("Barracks need 2") and instructions.contains("Factory needs 4"), "powered Help explains plant construction and exact consumer shortage rules")
	await _hud_key(KEY_Q)
	_check(not powered.selection.attack_move_targeting and actor.attack_move == null, "builder-only Q still rejects combat Attack Move")
	await _hud_key(KEY_2, true)
	var rifle := powered.units[0]
	await _hud_pick_unit(rifle)
	await _hud_key(KEY_2)
	_check(powered.selection.selected_units() == [actor] and powered.control_groups.group_members(2) == [actor], "powered construction context preserves ordinary group assignment and recall")
	await _hud_pick_unit(rifle, true)
	await _hud_key(KEY_Q)
	_check(powered.selection.attack_move_targeting and not panel.power_plant_button.visible, "mixed builder/combat context preserves Q and hides single-builder placement")
	await _click(_minimap_point(Vector3(-8, 0, 14)), MOUSE_BUTTON_LEFT)
	_check(rifle.attack_move.active and actor.attack_move == null, "powered minimap dispatches Attack Move only to the selected combat actor")
	await _hud_key(KEY_X)
	_check(not rifle.attack_move.active and not actor.moving, "viewport X Stop retains ordinary combat and builder behavior")
	await _hud_pick_unit(actor)
	var barracks_site := await _power_ui_place(panel.build_button, powered.construction_definition, FIRST)
	if barracks_site == null or not await _builder_complete(barracks_site): return
	var barracks := barracks_site.building()
	await _hud_pick_building(barracks)
	_check(panel.power_label.text == "Power: 0 generated / 2 required" and panel.power_warning.visible and panel.power_warning.text.contains("LOW POWER") and panel.power_warning.text.contains("50%"), "actual completed idle Barracks creates a clear text shortage warning")
	_check(panel.selection_details.text.contains("Power required: 2") and panel.selection_details.text.contains("Production rate: 50%") and panel.train_button.text.contains("base"), "selected consumer shows nominal demand and effective rate without a misleading remaining-time estimate")
	# The north work face is hidden behind the completed Barracks from this
	# camera. Recall the group assigned above and move into view through input;
	# clicking its occluded anchor correctly selects the intervening building.
	await _hud_key(KEY_2)
	_check(powered.selection.selected_units() == [actor], "viewport group recall retrieves the builder behind its completed Barracks")
	await _click(_world_screen(Vector3(-19, 0, 0)), MOUSE_BUTTON_RIGHT)
	if not await _until(func() -> bool: return actor.movement_state == RTSUnit.MovementState.ARRIVED and actor.global_position.distance_to(Vector3(-19, 0, 0)) < 0.5, 10, "recalled builder physically moves into unobscured viewport ground"): return
	await _hud_pick_building(barracks)
	await _hud_pick_unit(actor)
	await _power_ui_layouts("power_shortage_builder")
	await _click(panel.power_plant_button.get_global_rect().get_center(), MOUSE_BUTTON_LEFT)
	_motion(_world_screen(DEPOT_POINT))
	await _frames(8)
	_check(powered.placement.active and powered.placement.valid and powered.power_snapshot(1).generated == 0, "Power Plant preview is valid while short of power and grants no generation")
	await _hud_key(KEY_F1)
	await _hud_key(KEY_ESCAPE)
	_check(not powered.help_panel.is_open() and powered.placement.active, "Help Escape leaves the Power Plant preview active")
	await _hud_key(KEY_ESCAPE)
	_check(not powered.placement.active and powered.construction.unfinished_id == 0, "second Escape cancels the free Power Plant preview")
	var plant_site := await _power_ui_place(panel.power_plant_button, POWER_PLANT, DEPOT_POINT)
	if plant_site == null: return
	await _hud_pick_unit(actor)
	await _hud_key(KEY_X)
	var plant := plant_site.building()
	await _hud_pick_building(plant)
	_check(plant_site.state == ConstructionSite.State.PAUSED and panel.identity_label.text.contains("Power Plant") and panel.selection_details.text.contains("Generation: 0 power") and panel.site_status.text.to_lower().contains("paused"), "selected paused unfinished Power Plant shows name, zero generation and existing work status")
	_check(panel.cancel_site_button.visible and not panel.train_button.visible and not panel.progress_bar.visible and panel.cancel_buttons.is_empty(), "unfinished plant exposes construction cancellation and no unit recipes")
	await _power_capture("power_paused_plant_1280x720")
	await _hud_pick_building(barracks)
	var paid_before := powered.credits.balance(1)
	var deployments: Array[Dictionary] = []
	barracks.production.deployed.connect(func(job: int, unit: int, _rally: bool) -> void:
		deployments.append({"job": job, "unit": unit, "tick": Engine.get_physics_frames(), "plant_elapsed": plant_site.elapsed, "queue": barracks.production.jobs()})
	)
	for index in 5:
		await _click(panel.train_button.get_global_rect().get_center(), MOUSE_BUTTON_LEFT)
	_check(barracks.production.count() == 5 and powered.credits.balance(1) == paid_before - 500 and panel.cancel_buttons.size() == 5, "five viewport Train clicks use the normal paid FIFO queue during shortage")
	var original_job := barracks.production.jobs()[0]
	var next_job_id: int = barracks.production.jobs()[1].id
	await _frames(60)
	_check(barracks.production.progress() > 0.05 and barracks.production.progress() < 0.2 and panel.progress_bar.value > 0 and panel.selection_details.text.contains("50%"), "visible queued Rifle progress advances during low power with the effective rate shown")
	await _power_ui_layouts("power_shortage_queue")
	var last_job: int = barracks.production.jobs().back().id
	await _click(panel.cancel_buttons[last_job].get_global_rect().get_center(), MOUSE_BUTTON_LEFT)
	_check(barracks.production.count() == 4 and powered.credits.balance(1) == paid_before - 400, "viewport cancellation refunds the selected waiting job's captured payment during shortage")
	await _hud_pick_unit(actor)
	await _click(_world_screen(plant.global_position + Vector3.UP), MOUSE_BUTTON_RIGHT)
	_check(plant_site.builder() == actor and actor.assigned_site_id == plant_site.site_id, "viewport right-click resumes the same paused Power Plant with its builder")
	await _hud_pick_building(barracks)
	if not await _until(func() -> bool: return plant_site.elapsed >= 7.0, 15, "resumed builder performs actual work before the UI restoration observation"): return
	var active_job := barracks.production.jobs()[0]
	var observed_tick := Engine.get_physics_frames()
	_check(active_job.id == original_job.id and active_job.duration == 5.0 and active_job.paid == 100 and active_job.elapsed < active_job.duration, "continuity observation identifies the original paid five-second job still training")
	# Capture the committed grid notification before this tick's producer advance.
	# Follow stable IDs: the first job legitimately finishes before the plant.
	var transition := {}
	powered.power_grid.changed.connect(func() -> void:
		if transition.is_empty() and powered.power_snapshot(1).generated == 10:
			transition.merge({"tick": Engine.get_physics_frames(), "queue": barracks.production.jobs()})
	)
	if not await _until(func() -> bool: return plant_site.elapsed >= 9.0, 3, "builder reaches the pre-completion sampling boundary through real work"): return
	var continuing_job := barracks.production.jobs()[0]
	var low_tick := Engine.get_physics_frames()
	_check(deployments.size() == 1 and deployments[0].job == original_job.id and deployments[0].plant_elapsed < 10.0 and deployments[0].queue[0].id == next_job_id and deployments[0].queue[0].elapsed == 0.0, "original stable job deploys exactly once before power restoration and releases its untrained FIFO successor")
	_check(continuing_job.id == next_job_id and continuing_job.elapsed > 0.0 and continuing_job.elapsed < 1.0 and barracks.production.jobs().slice(1).all(func(job: Dictionary) -> bool: return job.elapsed == 0.0), "next paid job alone advances at half rate while later FIFO jobs remain untrained")
	if not deployments.is_empty():
		_check(absf(active_job.elapsed + (deployments[0].tick - observed_tick) / 60.0 * 0.5 - active_job.duration) <= 0.035, "original job completion time accounts for retained elapsed seconds and the actual half-rate interval")
	if not await _builder_complete(plant_site): return
	await _frames(3)
	_check(panel.power_label.text == "Power: 10 generated / 2 required" and not panel.power_warning.visible and panel.selection_details.text.contains("Production rate: 100%"), "actual builder completion updates the global grid and selected consumer to full rate")
	_check(not transition.is_empty() and transition.queue[0].id == continuing_job.id and transition.queue[0].elapsed >= continuing_job.elapsed and transition.queue[0].elapsed < continuing_job.duration, "grid restoration observes the same successor still training with retained progress")
	if transition.is_empty(): return
	var restored_job := barracks.production.jobs()[0]
	_check(absf(transition.queue[0].elapsed - continuing_job.elapsed - (transition.tick - low_tick - 1) / 60.0 * 0.5) <= 0.035, "same stable job earns half-rate work up to the documented pre-increment power boundary")
	_check(restored_job.id == continuing_job.id and absf(restored_job.elapsed - transition.queue[0].elapsed - (Engine.get_physics_frames() - transition.tick + 1) / 60.0) <= 0.035, "same active job immediately earns full-rate work after the committed power transition")
	await _frames(60)
	var full_rate_job := barracks.production.jobs()[0]
	_check(full_rate_job.id == continuing_job.id and full_rate_job.paid == 100 and full_rate_job.duration == 5.0 and absf(full_rate_job.elapsed - restored_job.elapsed - 1.0) <= 0.035 and panel.progress_bar.value > 0, "visible power restoration preserves identity/payment/duration and adds one full training second without restarting")
	_check(deployments.size() == 1 and not barracks.production.jobs().any(func(job: Dictionary) -> bool: return job.id == original_job.id) and powered.credits.balance(1) == paid_before - 400 and powered.units.any(func(unit: RTSUnit) -> bool: return unit.unit_id == deployments[0].unit and powered.contains_unit(unit)), "original job stays deployed exactly once with no transition charge/refund and its real unit remains registered")
	print("POWER_UI_CONTINUITY: original=%s observed_tick=%d deployment=%s transition=%s restored=%s full_rate=%s wallet=%d" % [active_job, observed_tick, deployments, transition, restored_job, full_rate_job, powered.credits.balance(1)])
	await _hud_pick_building(plant)
	_check(panel.selection_details.text.contains("450 / 450 HP") and panel.selection_details.text.contains("Generation: 10 power") and plant.production == null and plant.recipe == null and not panel.train_button.visible and panel.cancel_buttons.is_empty(), "completed Power Plant shows inherited health and generation without unit production controls")
	powered.tactical_minimap.refresh_markers()
	_check(_marker(plant.get_instance_id()).get("kind") == "power_plant" and _marker_count("power_plant") == 2, "registered completed player and enemy plants receive the distinct Power Plant minimap marker")
	await _power_capture("power_completed_plant_1280x720")
	await physics_frame
	var hostile: RTSUnit = null
	for unit in powered.units:
		if unit.owner_id == 2 and powered.contains_unit(unit):
			hostile = unit
			break
	_check(hostile != null and TeamRules.damage_target(powered, 2, plant, 10000, hostile) > 0, "ordinary hostile damage destroys the player's completed generator")
	await _frames(3)
	_check(powered.result == BaseAssaultField.Result.RUNNING and powered.selection.selected_building() == null and panel.power_warning.visible and panel.power_label.text == "Power: 0 generated / 2 required", "generator destruction leaves match running and shortage visible without a selected building")
	await _hud_pick_building(barracks)
	_check(panel.selection_details.text.contains("Production rate: 50%"), "remaining producer context updates after real generator destruction")
	await _power_capture("power_destroyed_shortage_1280x720")
	var old_grid := powered.power_grid
	await physics_frame
	TeamRules.damage_target(powered, 1, powered.enemy_headquarters, 10000, rifle)
	powered.resolve_result()
	_check(powered.result == BaseAssaultField.Result.VICTORY and powered.restart_button.visible, "normal headquarters objective still exposes result and Restart controls")
	await _click(powered.restart_button.get_global_rect().get_center(), MOUSE_BUTTON_LEFT)
	await _frames(10)
	powered = current_scene as PowerAssaultField
	builders = powered
	battle = powered
	world = powered
	harvest = powered
	field = powered
	if powered == null:
		_check(false, "viewport Restart reloads the powered scenario")
		return
	powered.camera_rig.edge_scrolling_enabled = false
	panel = powered.production_panel as ConstructionPanel
	_check(powered.scene_file_path == "res://scenes/power_assault.tscn" and powered.power_grid != old_grid and old_grid.changed.get_connections().is_empty(), "Restart creates a fresh power grid and disconnects old HUD listeners")
	old_grid.refresh()
	await _frames(3)
	_check(powered.credits.balance(1) == 1000 and panel.power_label.text == "Power: 0 generated / 0 required" and not panel.power_warning.visible and not powered.help_panel.is_open(), "Restart restores configured opening and clears stale shortage and Help state")
	await _power_capture("power_restart_1280x720")
	# This is the actual freshly reloaded scene with its configured wallet and
	# live enemy scheduler, without the isolated UI fixture's overrides.
	_check(powered.enemy_controller.is_physics_processing() and powered.enemy_config.first_wave_time == 90.0, "normal playable scene retains its live configured enemy schedule")
	await _hud_pick_unit(_player_builders()[0])
	_check(panel.power_plant_button.visible and not panel.power_plant_button.disabled, "normal 1000-credit opening offers Bulldozer Power Plant construction")
	await _power_ui_layouts("power_normal_opening")
