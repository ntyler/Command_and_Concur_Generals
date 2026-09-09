extends "res://tests/fixtures/fortification_harness.gd"
## Automated viewport input and rendered layouts, never human playtesting.
## Normal opening is unchanged; paid UI/lifecycle fixtures declare extra initial
## funds and paused enemies. Direct HQ damage is only a labelled result trigger.


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1280, 720)
	var logger := EngineErrorProbe.new()
	OS.add_logger(logger)
	await _fort_normal_ui()
	await _fort_paid_ui()
	if is_instance_valid(field): field.queue_free()
	await _frames(6)
	_check(root.get_children().is_empty() and get_nodes_in_group("combat_projectiles").is_empty(), "fortification UI teardown clears gates, navigation and old controls")
	OS.remove_logger(logger)
	_check(logger.error_count() == 0, "fortification viewport controls and lifecycle have no native errors")
	print("FORTIFICATION_UI_CHECKS: %d checks, %d failures; native_errors=%d" % [checks, failures, logger.error_count()])
	quit(0 if failures == 0 else 1)


func _fort_layouts(label: String, include_help: bool = true) -> void:
	for dimensions in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		await _hud_layout(dimensions)
		await _fort_capture("%s_%dx%d" % [label, dimensions.x, dimensions.y])
		if include_help:
			await _hud_key(KEY_F1)
			_check(fort.help_panel.is_open(), "F1 opens fortification Help without replacing selection")
			await _hud_layout(dimensions)
			await _fort_capture("%s_help_%dx%d" % [label, dimensions.x, dimensions.y])
			await _hud_key(KEY_ESCAPE)
			_check(not fort.help_panel.is_open(), "Escape closes fortification Help without a world order")
	root.size = Vector2i(1280, 720)
	await _frames(4)


func _fort_normal_ui() -> void:
	await _fresh_fort(1000, true)
	var builder := _player_builders()[0]
	await _hud_pick_unit(builder)
	var panel := fort.production_panel as ConstructionPanel
	_check(panel.wall_button.visible and panel.gate_button.visible and panel.wall_button.text.contains("100") and panel.gate_button.text.contains("250"), "normal selected Bulldozer exposes correctly priced Wall and Gate choices")
	_check(panel.airfield_button.visible and panel.air_defense_button.visible and panel.depot_button.visible and fort.sortie_delay == 120 and fort.enemy_config.first_wave_time == 90, "fortification UI preserves prior air/economy choices and normal enemy timings")
	await _fort_layouts("fortification_normal_builder")
	await _click(panel.wall_button.get_global_rect().get_center(), MOUSE_BUTTON_LEFT)
	_motion(_world_screen(Vector3(-20.3, 0, 15.2)))
	await _frames(6)
	_check(fort.placement.active and fort.placement.definition == WALL and fort.placement.orientation_degrees == 0 and panel.orientation_button.visible, "viewport Wall choice starts unpaid preview with visible orientation control")
	await _hud_key(KEY_R)
	_check(fort.placement.orientation_degrees == 90 and panel.orientation_button.text.contains("90"), "unused R shortcut rotates barrier preview ninety degrees with readable control state")
	await _click(panel.orientation_button.get_global_rect().get_center(), MOUSE_BUTTON_LEFT)
	_check(fort.placement.orientation_degrees == 0 and fort.credits.balance(1) == 1000 and fort.construction.sites.is_empty(), "visible orientation button rotates back without paying or committing construction")
	await _fort_layouts("fortification_wall_preview", false)
	await _click(Vector2(600, 300), MOUSE_BUTTON_RIGHT)
	_check(not fort.placement.active and fort.credits.balance(1) == 1000 and fort.construction.sites.is_empty(), "normal right-click preview cancellation spends nothing")
	await _click(panel.gate_button.get_global_rect().get_center(), MOUSE_BUTTON_LEFT)
	_motion(_world_screen(FORT_GATE_POINT))
	await _frames(4)
	_check(fort.placement.active and fort.placement.definition == GATE, "Gate construction choice uses the same authoritative placement preview")
	await _hud_key(KEY_ESCAPE)
	_check(not fort.placement.active and fort.credits.balance(1) == 1000, "Escape cancels Gate placement without payment")


func _fort_pick_gate(gate: BarrierBuilding) -> void:
	# Always pick an actual retained support, including when doorway is open.
	var point := gate.global_position + Vector3(-3.5, 1.2, 0)
	await _click(_world_screen(point), MOUSE_BUTTON_LEFT)
	_check(fort.selection.selected_building() == gate, "viewport picks actual retained gate support in its current state")


func _fort_paid_ui() -> void:
	await _fresh_fort(6000) # Explicit extra-fund, paused-enemy UI fixture.
	var builder := _player_builders()[0]
	var gate := await _fort_build(builder, GATE)
	if gate == null: return
	var wall := await _fort_build(builder, WALL, FORT_WALL_POINT)
	if wall == null: return
	await physics_frame
	_check(builder.move_to(Vector3(-24, 0, 18)), "paid fixture builder moves out of gate inspection area")
	if not await _until(func() -> bool: return not builder.moving, 12, "builder physically clears completed barrier inspection area"): return
	fort.camera_rig.center_on_ground(FORT_GATE_POINT)
	await _frames(6)
	await _fort_pick_gate(gate)
	var panel := fort.production_panel as ConstructionPanel
	_check(panel.gate_action_button.visible and panel.gate_action_button.text.contains("Open") and panel.selection_details.text.contains("700 / 700") and not panel.train_button.visible, "selected closed owned gate exposes Open and700HP without production")
	fort.tactical_minimap.refresh_markers()
	_check(_marker(gate.get_instance_id()).get("kind") == "gate_closed" and _marker(wall.get_instance_id()).get("kind") == "wall", "minimap distinguishes intact wall and closed gate")
	await _fort_layouts("fortification_paid_closed_gate")
	await _click(panel.gate_action_button.get_global_rect().get_center(), MOUSE_BUTTON_LEFT)
	if not await _until(func() -> bool: return _fort_gate_ready(gate, true), 3, "viewport Open commits synchronized open doorway"): return
	await _fort_pick_gate(gate)
	_check(panel.gate_action_button.visible and panel.gate_action_button.text.contains("Close") and _grid_is(1, 0, 0), "open gate retains selectable support and Close action without a power prerequisite")
	fort.tactical_minimap.refresh_markers()
	_check(_marker(gate.get_instance_id()).get("kind") == "gate_open", "minimap marks effective open-gate state")
	await _fort_layouts("fortification_paid_open_gate")
	var rifle: RTSUnit
	for actor in fort.units:
		if actor.owner_id == 1 and not actor is Bulldozer:
			rifle = actor
			break
	if rifle == null:
		_check(false, "original army available for occupied-doorway viewport check")
		return
	await physics_frame
	_check(rifle.move_to(FORT_GATE_POINT), "original ground Rifle accepts the effective open doorway as ordinary destination")
	if not await _until(func() -> bool: return not rifle.moving, 10, "original Rifle physically enters open closing volume"): return
	var previous_position := rifle.global_position
	var previous_health := rifle.combat.health.current
	await _fort_pick_gate(gate)
	await _click(panel.gate_action_button.get_global_rect().get_center(), MOUSE_BUTTON_LEFT)
	await _frames(6)
	_check(gate.physical_open and not gate.navigation_pending and gate.gate_status().contains("Gate obstructed") and panel.gate_state_label.visible and panel.gate_state_label.text.contains("Gate obstructed"), "occupied Close is authoritatively rejected with readable Gate obstructed feedback")
	_check(rifle.global_position.distance_to(previous_position) < 0.01 and rifle.combat.health.current == previous_health, "occupied viewport Close causes no damage, displacement or queued closure")
	await _fort_capture("fortification_gate_obstructed_1280x720")
	await physics_frame
	_check(rifle.move_to(Vector3(-14, 0, 9)), "original Rifle accepts normal Move to clear occupied doorway")
	if not await _until(func() -> bool: return not rifle.moving, 10, "Rifle physically clears closing volume"): return
	await _frames(8)
	_check(gate.physical_open and not gate.navigation_pending, "clearing obstruction never triggers an automatic later closure")
	await _fort_pick_gate(gate)
	await _click(panel.gate_action_button.get_global_rect().get_center(), MOUSE_BUTTON_LEFT)
	if not await _until(func() -> bool: return _fort_gate_ready(gate, false), 3, "new explicit viewport Close succeeds after clearance"): return
	# Exercise unchanged ground selection/group/Q/X before labelled lifecycle result.
	await _hud_pick_unit(rifle)
	await _hud_key(KEY_3, true)
	fort.selection.replace_units([])
	await _hud_key(KEY_3)
	_check(fort.selection.selected_units() == [rifle] and fort.control_groups.group_members(3) == [rifle], "new barrier controls preserve original army control groups")
	await _hud_key(KEY_Q)
	_check(fort.selection.attack_move_targeting, "original Q still enters ground Attack Move targeting")
	await _hud_key(KEY_X)
	_check(not rifle.attack_move.active and not rifle.moving, "original X Stop remains functional alongside barrier controls")
	fort.selection.cancel_attack_move_targeting()
	await physics_frame
	_check(builder.move_to(Vector3(-22, 0, 20)), "lifecycle fixture builder accepts a clear approach outside the next rotated wall")
	if not await _until(func() -> bool: return not builder.moving, 10, "builder physically clears the pending rotated wall footprint"): return
	fort.selection.select_clicked(builder, false)
	await physics_frame
	var result := fort.construction.place(1, builder, WALL, Vector3(-25, 0, 17), 90)
	var site := await _builder_arrival(result)
	if site == null: return
	var old_gate: WeakRef = weakref(gate)
	var old_builder: WeakRef = weakref(builder)
	var old_grid := fort.power_grid
	var old_navigation := fort.construction.navigation
	await physics_frame
	_check(gate.request_gate(1, true).accepted, "labelled lifecycle fixture begins gate transition before match result")
	TeamRules.damage_target(fort, 1, fort.enemy_headquarters, 10000, rifle) # Isolated result trigger; combat/breach suites prove normal damage.
	fort.resolve_result()
	var progress := site.elapsed
	_check(fort.result == BaseAssaultField.Result.VICTORY and fort.restart_button.visible and not gate.request_gate(1, false).accepted, "result freezes match and rejects new gate operations through authority")
	await _frames(20)
	_check(site.elapsed == progress and not gate.physical_open and not gate.navigation_pending and not rifle.moving, "freeze stops real builder work and invalidates unfinished gate transition without opening")
	for dimensions in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		await _hud_layout(dimensions)
		await _fort_capture("fortification_result_%dx%d" % [dimensions.x, dimensions.y])
	await _click(fort.restart_button.get_global_rect().get_center(), MOUSE_BUTTON_LEFT)
	await _frames(12)
	_adopt_fort(current_scene as FortifiedAssaultField)
	_check(fort != null and old_gate.get_ref() == null and old_builder.get_ref() == null and old_navigation.closed and old_grid.changed.get_connections().is_empty(), "viewport Restart retires old gates/builders/navigation and owner-grid listeners")
	_check(fort.credits.balance(1) == 1000 and fort.construction.sites.is_empty() and _player_barriers().is_empty() and _player_builders().size() == 1 and fort.control_groups.group_members(3).is_empty() and not fort.sortie_issued, "Restart restores original wallet/force and clears barriers, transition requests, work and groups")
	_check(_grid_is(1, 0, 0) and _grid_is(2, 10, 8) and fort.enemy_config.first_wave_time == 90 and fort.sortie_delay == 120, "Restart restores inherited economy, power and ground/air timing")
	await _fort_layouts("fortification_normal_restart", false)
