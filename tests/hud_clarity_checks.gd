extends "res://tests/tactical_interface_checks.gd"
## Focused M8.1 rendered/viewport checks. Isolated context fixtures grant 4000
## credits, extend their instance assault to 600s, and add one original Rocket
## actor for mixed-selection presentation. Shared scenes/resources stay untouched.

class HUDKeySink extends Control:
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
		if argument.begins_with("--hud-case="):
			chosen = argument.trim_prefix("--hud-case=")
	var cases := ["help", "context", "production", "labels", "panel_lifetime", "lifecycle"]
	_check(chosen == "all" or cases.has(chosen), "recognized HUD clarity case")
	for case in cases:
		if chosen != "all" and chosen != case: continue
		var before := checks
		var failed := failures
		match case:
			"help": await _hud_help()
			"context": await _hud_context()
			"production": await _hud_production()
			"labels": await _hud_labels()
			"panel_lifetime": await _hud_panel_lifetime()
			"lifecycle": await _hud_lifecycle()
		print("HUD_CASE: %s; checks=%d failures=%d" % [case, checks - before, failures - failed])
	if is_instance_valid(battle): battle.queue_free()
	await _frames(5)
	_check(root.get_children().is_empty(), "HUD teardown removes fields, panels and actor fixtures")
	OS.remove_logger(logger)
	_check(logger.error_count() == 0, "HUD interactions and teardown have no native errors or warnings")
	print("HUD_CLARITY_CHECKS: %d checks, %d failures; native_errors=%d" % [checks, failures, logger.error_count()])
	quit(0 if failures == 0 else 1)


func _hud_capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://validation-output/m8.1/screenshots")
	var picture := root.get_texture().get_image()
	var result := picture.save_png("res://validation-output/m8.1/screenshots/%s.png" % label)
	_check(result == OK and picture.get_size() == root.size, "saved actual %s rendered viewport: %s" % [root.size, label])


func _hud_key(code: Key, control: bool = false) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.ctrl_pressed = control
	event.pressed = true
	root.push_input(event, true)
	event = event.duplicate() as InputEventKey
	event.pressed = false
	root.push_input(event, true)
	await _frames(2)


func _hud_pick_unit(unit: RTSUnit, shift: bool = false) -> void:
	await _click(_screen(unit), MOUSE_BUTTON_LEFT, shift)
	_check(battle.selection.selected_units().has(unit), "viewport selects mobile actor #%d" % unit.unit_id)


func _hud_pick_building(building: RTSBuilding) -> void:
	await _click(_world_screen(building.global_position + Vector3.UP * building.building_height * 0.6), MOUSE_BUTTON_LEFT)
	_check(battle.selection.selected_building() == building, "viewport selects %s" % building.display_name())


func _hud_layout(dimensions: Vector2i) -> void:
	root.size = dimensions
	await _frames(8)
	var map_rect := battle.tactical_minimap.get_global_rect()
	var context_rect := battle.production_panel.get_global_rect()
	var help_rect := battle.help_panel.get_global_rect()
	var objective_rect := (battle.objective_label.get_parent() as Control).get_global_rect()
	var viewport := root.get_visible_rect()
	_check(viewport.encloses(map_rect) and viewport.encloses(context_rect) and viewport.encloses(help_rect) and viewport.encloses(objective_rect), "all HUD panels fit actual viewport %s" % dimensions)
	_check(not map_rect.intersects(context_rect) and not map_rect.intersects(help_rect) and not map_rect.intersects(objective_rect), "minimap is unobscured at %s" % dimensions)
	_check(not help_rect.intersects(context_rect) and not help_rect.intersects(objective_rect) and not context_rect.intersects(objective_rect), "help, context and objective panels do not overlap at %s" % dimensions)
	for button in battle.production_panel.cancel_buttons.values():
		_check(viewport.encloses(button.get_global_rect()) and not button.get_global_rect().intersects(map_rect), "queue cancellation remains accessible at %s" % dimensions)


func _hud_help() -> void:
	await _fresh_combined()
	_check(not battle.help_panel.is_open() and not battle.help_panel.help_content.visible and battle.help_panel.help_button.visible, "normal combined scene launches with compact Help closed")
	_check(battle.assault_delay == 90 and battle.objective_label.text.contains("Enemy assault in 90s"), "ordinary initial HUD countdown uses configured 90 simulated seconds")
	await _hud_layout(Vector2i(1280, 720))
	await _hud_capture("initial_1280x720")
	var selected := battle.selection.selected_building()
	var batch := battle.last_command_result
	var clock_before := battle.elapsed
	await _click(battle.help_panel.help_button.get_global_rect().get_center(), MOUSE_BUTTON_LEFT)
	_check(battle.help_panel.is_open() and battle.help_panel.help_content.visible, "viewport Help button opens the instructions")
	_check(battle.selection.selected_building() == selected and battle.last_command_result == batch and battle.elapsed > clock_before, "Help preserves selection/orders and simulation continues")
	await _hud_layout(Vector2i(1280, 720))
	await _hud_capture("help_1280x720")
	var expanded_rect := battle.help_panel.get_global_rect()
	var inside := battle.help_panel.help_content.get_global_rect().get_center()
	await _click(inside, MOUSE_BUTTON_LEFT)
	await _click(inside, MOUSE_BUTTON_RIGHT)
	_check(battle.selection.selected_building() == selected and battle.last_command_result == batch and battle.selection._pending_picks.is_empty(), "Help body consumes both mouse buttons without underlying world picks")
	await _hud_key(KEY_F1)
	_check(not battle.help_panel.is_open(), "viewport F1 returns Help to compact view")
	var first := battle.units[0]
	await _hud_pick_unit(first)
	var headquarters_pixel := _world_screen(battle.headquarters.global_position + Vector3.UP * battle.headquarters.building_height * 0.6)
	_check(expanded_rect.has_point(headquarters_pixel) and not battle.help_panel.get_global_rect().has_point(headquarters_pixel), "closed Help releases the battlefield area previously covered by instructions")
	await _hud_pick_building(battle.headquarters)
	await _hud_pick_unit(first)
	await _hud_key(KEY_F1)
	await _click(_minimap_point(Vector3(-10, 0, 15)), MOUSE_BUTTON_RIGHT)
	_check(first.moving and battle.last_command_result != batch, "open Help leaves unrelated minimap/world command region interactive")
	await _hud_key(KEY_ESCAPE)
	_check(not battle.help_panel.is_open() and battle.selection.selected_units() == [first], "Escape closes owned Help interaction while preserving selection")
	await _hud_pick_building(battle.headquarters)
	var panel := battle.production_panel as ConstructionPanel
	await _click(panel.build_button.get_global_rect().get_center(), MOUSE_BUTTON_LEFT)
	_check(battle.placement.active, "viewport HQ construction begins placement before Help priority check")
	_motion(_world_screen(FIRST))
	await _frames(8)
	await _hud_key(KEY_F1)
	_check(battle.help_panel.is_open() and battle.placement.active, "F1 can open Help without cancelling placement")
	var placement_rect := battle.placement.status.get_global_rect()
	_check(battle.placement.status.visible and root.get_visible_rect().encloses(placement_rect) and not placement_rect.intersects(battle.help_panel.get_global_rect()) and not placement_rect.intersects(panel.get_global_rect()), "placement instructions remain readable beside expanded Help and HQ controls")
	await _hud_capture("help_placement_1280x720")
	await _hud_key(KEY_ESCAPE)
	_check(not battle.help_panel.is_open() and battle.placement.active, "first Escape closes Help without also cancelling unrelated placement")
	await _hud_key(KEY_ESCAPE)
	_check(not battle.placement.active, "second Escape retains ordinary placement cancellation")
	var sink := HUDKeySink.new()
	sink.focus_mode = Control.FOCUS_ALL
	sink.position = Vector2(700, 300)
	sink.size = Vector2(40, 40)
	battle.get_node("ControlsFeedback").add_child(sink)
	sink.grab_focus()
	await _hud_key(KEY_F1)
	await _hud_key(KEY_F3)
	_check(sink.presses == 2 and not battle.help_panel.is_open() and not battle.movement_debug, "focused GUI consumes F1/F3 without toggling Help/debug")
	sink.release_focus()
	sink.queue_free()
	await _hud_layout(Vector2i(1920, 1080))
	await _hud_capture("initial_1920x1080")
	await _hud_key(KEY_F1)
	await _hud_layout(Vector2i(1920, 1080))
	await _hud_capture("help_1920x1080")
	await _hud_key(KEY_F1)
	root.size = Vector2i(1280, 720)


func _hud_rocket() -> RTSUnit:
	var rocket := RTSUnit.new()
	rocket.unit_id = 81
	rocket.owner_id = 1
	rocket.combat_weapon = CombatField.ROCKET
	rocket.position = Vector3(-12, 0, 12)
	battle.add_child(rocket)
	battle.register_unit(rocket)
	await _frames(3)
	return rocket


func _hud_context() -> void:
	await _fresh_combined(4000, 600)
	var panel := battle.production_panel
	await _click(_world_screen(Vector3(-5, 0, 7)), MOUSE_BUTTON_LEFT)
	_check(battle.selection.selected_units().is_empty() and battle.selection.selected_building() == null and panel.identity_label.text == "Select units or a building." and not panel.feedback.text.contains("Train at"), "viewport ground deselection shows neutral contextual panel")
	var rifle := battle.units[0]
	await _hud_pick_unit(rifle)
	_check(panel.identity_label.text.contains("Rifle") and panel.selection_details.text.contains("100 / 100") and panel.feedback.text.contains("Stop"), "single Rifle context shows exact identity/HP and existing Stop instruction")
	await _click(_minimap_point(Vector3(-12, 0, 17)), MOUSE_BUTTON_RIGHT)
	_check(rifle.moving and panel.selection_details.text.contains("Mov"), "selected unit status follows its accepted movement")
	_motion(panel.identity_label.get_global_rect().get_center())
	await _hud_key(KEY_X)
	_check(not rifle.moving and panel.selection_details.text.contains("Idle"), "viewport X Stop works over passive context and updates status")
	var rocket := await _hud_rocket()
	await _hud_pick_unit(rocket, true)
	_check(battle.selection.selected_units().size() == 2 and panel.identity_label.text.contains("2 units") and panel.selection_details.text.contains("1 Rifle") and panel.selection_details.text.contains("1 Rocket") and not panel.selection_details.text.contains("HP"), "mixed selected count/type counts come from two actual members without combined HP")
	await _hud_key(KEY_3, true)
	_check(battle.control_groups.group_members(3).size() == 2 and battle.tactical_minimap._group_text.contains("Group 3") and battle.tactical_minimap._group_text.contains("2 units"), "assigned group feedback spells out actual group and unit count")
	await _hud_layout(Vector2i(1280, 720))
	await _hud_capture("mixed_1280x720")
	await _hud_pick_building(battle.headquarters)
	await _hud_key(KEY_3)
	_check(battle.selection.selected_units().size() == 2 and panel.identity_label.text.contains("2 units"), "viewport group recall refreshes contextual selection")
	await _hud_key(KEY_3)
	var center := (rifle.position + rocket.position) * 0.5
	_check(Vector2(battle.camera_rig.position.x, battle.camera_rig.position.z).distance_to(Vector2(center.x, center.z)) < 0.05, "viewport double-tap group recall centers actual selected members")
	battle.camera_rig.center_on_ground(Vector3.ZERO)
	await _frames(3)
	var truck := battle.collectors[0]
	await _hud_pick_unit(truck)
	_check(panel.identity_label.text.contains("Collector") and battle.harvest_panel.is_visible_in_tree() and battle.harvest_panel.label.text.contains("0 / 100"), "collector selection shows identity and cargo/capacity in contextual panel")
	await _click(_world_screen(battle.caches[0].global_position + Vector3.UP), MOUSE_BUTTON_RIGHT)
	await _frames(8)
	_check(truck.harvesting.automatic and battle.harvest_panel.label.text.contains("Supply") and battle.harvest_panel.label.text.contains("2000"), "viewport supply assignment exposes existing collector activity and remaining cache context")
	await _hud_key(KEY_X)
	await _hud_pick_unit(rifle)
	await physics_frame
	rifle.combat.health.apply_damage(10000, battle.units[3])
	await _frames(4)
	_check(battle.selection.selected_units().is_empty() and panel.identity_label.text == "Select units or a building.", "selected combat death clears stale contextual identity and details")
	_check(battle.control_groups.group_members(3) == [rocket] and battle.tactical_minimap._group_text.contains("1 unit"), "group feedback excludes a departed member")
	await _hud_pick_unit(rocket)
	for number in range(1, 10):
		await _hud_key((KEY_0 + number) as Key, true)
	_check(battle.tactical_minimap._group_counts.size() == 9 and battle.tactical_minimap.tooltip_text.split("\n").size() == 9, "nine viewport assignments expose nine numbered groups with full readable tooltip context")
	for dimensions in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		await _hud_layout(dimensions)
		_check(battle.tactical_minimap.size.x <= 300 and battle.tactical_minimap.mapping.content_rect.end.y < battle.tactical_minimap.size.y - 31, "all nine chips fit the existing reserved footer without enlarging or covering minimap content at %s" % dimensions)
		await _hud_capture("nine_groups_%dx%d" % [dimensions.x, dimensions.y])
	root.size = Vector2i(1280, 720)


func _hud_production() -> void:
	await _fresh_combined(4000, 600)
	var panel := battle.production_panel as ConstructionPanel
	var initial_guides := battle.placement_guides.mesh.get_instance_id()
	await _hud_pick_building(battle.headquarters)
	_check(panel.build_button.visible and panel.factory_button.visible and panel.selection_details.text.contains("1200 / 1200"), "HQ context retains both construction choices and exact selected HP")
	await _click(panel.build_button.get_global_rect().get_center(), MOUSE_BUTTON_LEFT)
	_motion(_world_screen(FIRST))
	await _frames(8)
	await _click(_world_screen(FIRST), MOUSE_BUTTON_LEFT)
	var site := await _ready_site(battle.placement.last_result)
	if site == null: return
	await _hud_pick_building(site.building())
	_check(panel.cancel_site_button.visible and panel.site_progress.visible and not panel.train_button.visible, "viewport construction site selection exposes progress/Cancel and hides production")
	var balance := battle.credits.balance(1)
	await _click(panel.cancel_site_button.get_global_rect().get_center(), MOUSE_BUTTON_LEFT)
	_check(battle.credits.balance(1) == balance + 400, "viewport construction Cancel returns original payment")
	if not await _until(func() -> bool: return battle.construction.sites.is_empty(), 8, "cancelled site removes after ordinary navigation cleanup"): return
	_check(battle.selection.selected_building() == null and panel.identity_label.text == "Select units or a building.", "site cancellation clears stale contextual action target")
	# Build through the viewport and wait ordinary configured production-building times.
	await _hud_pick_building(battle.headquarters)
	await _click(panel.build_button.get_global_rect().get_center(), MOUSE_BUTTON_LEFT)
	_motion(_world_screen(FIRST))
	await _frames(8)
	await _click(_world_screen(FIRST), MOUSE_BUTTON_LEFT)
	site = await _ready_site(battle.placement.last_result)
	if site == null or not await _complete_site(site): return
	var barracks := site.building()
	_check(battle.placement_guides.mesh.get_instance_id() != initial_guides, "construction lifecycle refreshes the retained access-guide mesh for committed producer exits")
	await _hud_pick_building(barracks)
	_check(panel.train_button.visible and panel.train_button.text.contains("Rifle") and panel.train_button.text.contains("100"), "Barracks context preserves priced Rifle training")
	balance = battle.credits.balance(1)
	await _click(panel.train_button.get_global_rect().get_center(), MOUSE_BUTTON_LEFT)
	_check(barracks.production.count() == 1 and battle.credits.balance(1) == balance - 100 and panel.cancel_buttons.size() == 1, "viewport Rifle enqueue pays once and displays accessible queue cancellation")
	await _click(panel.cancel_buttons.values()[0].get_global_rect().get_center(), MOUSE_BUTTON_LEFT)
	_check(barracks.production.count() == 0 and battle.credits.balance(1) == balance, "viewport Rifle Cancel removes job and refunds once")
	await _hud_pick_building(battle.headquarters)
	await _click(panel.factory_button.get_global_rect().get_center(), MOUSE_BUTTON_LEFT)
	_motion(_world_screen(SECOND))
	await _frames(8)
	await _click(_world_screen(SECOND), MOUSE_BUTTON_LEFT)
	site = await _ready_site(battle.placement.last_result)
	if site == null or not await _complete_site(site): return
	var factory := site.building()
	await _hud_pick_building(factory)
	_check(panel.train_button.visible and panel.train_button.text.contains("Rocket") and panel.train_button.text.contains("250"), "Factory context preserves priced Rocket training")
	balance = battle.credits.balance(1)
	for job in 5:
		await _click(panel.train_button.get_global_rect().get_center(), MOUSE_BUTTON_LEFT)
	_check(factory.production.count() == 5 and panel.cancel_buttons.size() == 5 and battle.credits.balance(1) == balance - 1250 and panel.train_button.disabled, "viewport full Rocket queue preserves costs, all Cancel rows and capacity feedback")
	for dimensions in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		await _hud_layout(dimensions)
		await _hud_capture("production_%dx%d" % [dimensions.x, dimensions.y])
	await _click(panel.cancel_buttons.values()[2].get_global_rect().get_center(), MOUSE_BUTTON_LEFT)
	_check(factory.production.count() == 4 and panel.cancel_buttons.size() == 4 and battle.credits.balance(1) == balance - 1000, "viewport Rocket cancellation refunds the selected undeployed job")
	root.size = Vector2i(1280, 720)
	await _frames(5)
	await physics_frame
	TeamRules.damage_target(battle, 2, factory, 10000, battle.units[3])
	await _frames(5)
	_check(battle.selection.selected_building() == null and not panel.train_button.visible and panel.cancel_buttons.is_empty(), "selected producer destruction disconnects queue and clears actionable UI")
	_check(panel._observed == null and panel._context_connections.is_empty() and not panel.build_button.visible and not panel.cancel_site_button.visible, "departed selected building releases its queue and actor observers plus all stale construction actions")


func _hud_labels() -> void:
	await _fresh_combined()
	var rifle := battle.units[0]
	var feedback := rifle.combat.feedback
	_check(not feedback.health_label.visible and not feedback.health_bar.visible, "healthy unselected mobile has no permanent floating name/HP or health bar")
	_check(not battle.enemy_headquarters.health_label.visible and not battle.enemy_headquarters.health_bar.visible and battle.enemy_headquarters._identity_label.visible, "healthy unselected building retains compact identity without exact HP")
	_check(not battle.placement_guides.visible, "access/placement diagnostic outlines are hidden in normal play")
	await _hud_pick_unit(rifle)
	_check(feedback.health_bar.visible and not feedback.health_label.visible and rifle.selection_indicator.visible, "selected mobile retains indicator and compact health bar without numerical world paragraph")
	await physics_frame
	rifle.combat.health.apply_damage(10, battle.units[3])
	await _frames(2)
	await _hud_pick_building(battle.headquarters)
	_check(feedback.health_bar.visible and not feedback.health_label.visible, "damaged deselected mobile retains compact health feedback")
	_check(battle.headquarters.health_bar.visible and not battle.headquarters.health_label.visible, "selected building shows health bar while exact HP stays in context")
	var nodes := get_node_count()
	var units := battle.units.size()
	var balance := battle.credits.balance(1)
	for cycle in 3:
		await _hud_key(KEY_F3)
		_check(battle.movement_debug and feedback.health_label.visible and feedback.health_label.text.contains("90 / 100") and battle.headquarters.health_label.visible and battle.placement_guides.visible, "F3 reveals existing exact-health and access diagnostics, cycle %d" % cycle)
		await _hud_key(KEY_F3)
		_check(not battle.movement_debug and not feedback.health_label.visible and not battle.headquarters.health_label.visible and not battle.placement_guides.visible, "F3 returns all diagnostics to normal visibility, cycle %d" % cycle)
	_check(get_node_count() == nodes and battle.units.size() == units and battle.credits.balance(1) == balance and rifle.combat.health.current == 90, "repeated debug toggles do not leak nodes or alter units, economy or health")
	var panel := battle.production_panel as ConstructionPanel
	await _click(panel.build_button.get_global_rect().get_center(), MOUSE_BUTTON_LEFT)
	_check(battle.placement.active and battle.placement_guides.visible, "placement shows its real clearance/access outlines when relevant")
	await _hud_key(KEY_ESCAPE)
	_check(not battle.placement_guides.visible, "ending placement hides its outlines again")


func _hud_observer_count(emitter: Object, event: StringName, observer: Object) -> int:
	var count := 0
	for connection in emitter.get_signal_connection_list(event):
		var callback: Callable = connection["callable"]
		if callback.get_object() == observer:
			count += 1
	return count


func _hud_panel_lifetime() -> void:
	await _fresh_combined(4000, 600)
	var panel := battle.production_panel as ConstructionPanel
	var cargo_panel := battle.harvest_panel
	var rifle := battle.units[0]
	for cycle in 4:
		battle.selection.select_building(battle.headquarters)
		battle.selection.select_clicked(rifle, false)
		battle.selection.select_clicked(rifle, false)
	_check(_hud_observer_count(battle.selection, &"selection_changed", panel) == 1 and _hud_observer_count(rifle, &"availability_changed", panel) == 1 and _hud_observer_count(rifle, &"movement_state_changed", panel) == 1 and _hud_observer_count(rifle.combat, &"state_changed", panel) == 1 and _hud_observer_count(rifle.combat.health, &"damaged", panel) == 1, "repeated selection owns exactly one panel connection to each live unit notification")
	_check(_hud_observer_count(battle.headquarters.health, &"damaged", panel) == 0, "previous building health observer disconnects when unit selection takes ownership")
	await physics_frame
	rifle.combat.health.apply_damage(10, battle.units[3])
	_check(panel.selection_details.text.contains("90 / 100"), "active selected health damage updates context synchronously")
	_check(_complete(battle.issue_move(Vector3(-12, 0, 17))) and panel.selection_details.text.contains("Mov"), "active selected movement notification updates context after an accepted order")
	_check(_complete(battle.issue_stop()) and panel.selection_details.text.contains("Idle"), "active selected Stop notification still updates context")
	rifle.queue_free()
	await _frames(4)
	_check(battle.selection.selected_units().is_empty() and panel.identity_label.text == "Select units or a building." and panel._context_connections.is_empty() and not panel.train_button.visible and not panel.build_button.visible, "selected unit departure releases observers and clears stale contextual actions")
	var truck := battle.collectors[0]
	for cycle in 4:
		battle.selection.select_clicked(truck, false)
	_check(_hud_observer_count(battle.selection, &"selection_changed", cargo_panel) == 1 and _hud_observer_count(truck.harvesting, &"changed", cargo_panel) == 1 and _hud_observer_count(truck, &"movement_state_changed", cargo_panel) == 1, "repeated collector selection retains one cargo observer per source")
	await physics_frame
	_check(_complete(battle.issue_harvest(battle.caches[0])) and cargo_panel.label.text.contains("Supply") and not cargo_panel.label.text.ends_with("Idle"), "active collector work notification updates contextual activity and cache")
	# Retain nodes after removal so implicit object destruction cannot conceal a
	# missing disconnect, and so already-queued callbacks can be exercised.
	cargo_panel._refresh.call_deferred()
	cargo_panel.get_parent().remove_child(cargo_panel)
	var cargo_text := cargo_panel.label.text
	_check(_hud_observer_count(battle.selection, &"selection_changed", cargo_panel) == 0 and _hud_observer_count(truck.harvesting, &"changed", cargo_panel) == 0 and cargo_panel._connections.is_empty() and cargo_panel._rejection_observers.is_empty(), "detached retained collector panel disconnects selection, work and rejection observers")
	truck.stop()
	truck.harvesting.changed.emit()
	battle.selection.select_building(battle.headquarters)
	await _frames(2)
	_check(cargo_panel.label.text == cargo_text, "pending refresh and subsequent old collector signals do not refresh a detached panel")
	var site := await _ready_site(await _place())
	if site == null or not await _complete_site(site):
		cargo_panel.free()
		return
	var building := site.building()
	var producer := building.production
	for cycle in 4:
		battle.selection.select_building(battle.headquarters)
		battle.selection.select_building(building)
		battle.selection.select_building(building)
	_check(_hud_observer_count(producer, &"changed", panel) == 1 and _hud_observer_count(building.health, &"damaged", panel) == 1 and _hud_observer_count(truck, &"movement_state_changed", panel) == 0, "repeated producer selection owns one queue/health observer and releases former unit observers")
	var balance := battle.credits.balance(1)
	var queued := producer.enqueue(1, building.recipe)
	_check(queued.accepted and producer.count() == 1 and panel.cancel_buttons.size() == 1 and panel.credit_label.text.contains(str(balance - building.recipe.credit_cost)), "active queue and credit signals display exactly one paid job")
	var job_id: int = producer.jobs()[0]["id"]
	_check(producer.cancel(1, job_id).accepted and panel.cancel_buttons.is_empty() and battle.credits.balance(1) == balance, "active queue cancellation clears its row and reports the ordinary refund")
	queued = producer.enqueue(1, building.recipe)
	_check(queued.accepted and panel.cancel_buttons.size() == 1, "retained callback fixture has a real paid producer job")
	job_id = producer.jobs()[0]["id"]
	var old_cancel: Callable = panel.cancel_buttons[job_id].pressed.get_connections()[0]["callable"]
	panel._layout.call_deferred()
	panel.get_parent().remove_child(panel)
	_check(_hud_observer_count(battle.selection, &"selection_changed", panel) == 0 and _hud_observer_count(battle.credits, &"changed", panel) == 0 and _hud_observer_count(battle.construction, &"changed", panel) == 0 and _hud_observer_count(producer, &"changed", panel) == 0 and panel._context_connections.is_empty(), "detached retained construction panel disconnects selection, credit, construction, queue and actor sources")
	_check(_hud_observer_count(root, &"size_changed", panel) == 0 and _hud_observer_count(panel, &"minimum_size_changed", panel) == 0, "detached panel also releases viewport and minimum-size layout notifications")
	var identity := panel.identity_label.text
	var feedback_text := panel.feedback.text
	var build_visible := panel.build_button.visible
	var credit_text := panel.credit_label.text
	var panel_position := panel.position
	battle.selection.select_building(battle.headquarters)
	battle.credits.publish(1)
	battle.construction.changed.emit(site.site_id)
	panel._refresh.call_deferred()
	panel.refresh_construction.call_deferred()
	panel.minimum_size_changed.emit()
	root.size = Vector2i(1920, 1080)
	await _frames(2)
	_check(panel.identity_label.text == identity and panel.feedback.text == feedback_text and panel.build_button.visible == build_visible and panel.credit_label.text == credit_text and panel.position == panel_position, "detached base and derived refreshes plus pending/viewport layout cannot mutate retained UI")
	panel._begin.call_deferred()
	panel._begin_factory.call_deferred()
	await _frames(2)
	_check(not battle.placement.active, "deferred old construction buttons cannot begin placement after their panel leaves")
	battle.placement.cancel()
	battle.selection.select_building(building)
	balance = battle.credits.balance(1)
	panel._train.call_deferred()
	await _frames(2)
	_check(producer.count() == 1 and battle.credits.balance(1) == balance, "deferred old Train cannot buy a job after panel removal")
	old_cancel.call_deferred()
	await _frames(2)
	_check(producer.count() == 1 and battle.credits.balance(1) == balance, "retained old queue-row callback cannot cancel or refund after panel removal")
	var pending := await _ready_site(await _place(SECOND))
	if pending != null:
		battle.selection.select_building(pending.building())
		balance = battle.credits.balance(1)
		panel._cancel_site.call_deferred()
		await _frames(2)
		_check(pending.state == ConstructionSite.State.CONSTRUCTING and battle.credits.balance(1) == balance, "deferred old site Cancel cannot mutate paid construction after panel removal")
	# Replacing the field leaves these old panels deliberately alive with departed
	# field references; normal Restart UI and defaults are covered separately below.
	await _fresh_combined()
	balance = battle.credits.balance(1)
	var new_identity := battle.production_panel.identity_label.text
	panel._refresh.call_deferred()
	panel.refresh_construction.call_deferred()
	panel._layout.call_deferred()
	panel._train.call_deferred()
	panel._begin.call_deferred()
	panel._begin_factory.call_deferred()
	panel._cancel_site.call_deferred()
	old_cancel.call_deferred()
	cargo_panel._refresh.call_deferred()
	await _frames(3)
	_check(battle.credits.balance(1) == balance and battle._producers.is_empty() and battle.construction.sites.is_empty() and not battle.placement.active and battle.selection.selected_building() == battle.headquarters and battle.production_panel.identity_label.text == new_identity, "old retained refresh/layout/action callbacks cannot mutate the replacement match")
	panel.free()
	cargo_panel.free()
	root.size = Vector2i(1280, 720)
	await _hud_reentrant_panel_departure(false)
	await _hud_reentrant_panel_departure(true)


func _hud_reentrant_panel_departure(cargo_context: bool) -> void:
	await _fresh_combined(4000, 600)
	var old_field := battle
	var panel := old_field.production_panel
	var cargo_panel := old_field.harvest_panel
	var rifle := old_field.units[0]
	# A mixed selection observes the collector's work but no individual Rifle.
	# Changing that Rifle's ownership leaves membership to the normal getter's
	# pruning, without blocking signals or directly editing selection state.
	old_field.selection.replace_units([rifle, old_field.units[1], old_field.collectors[0]])
	rifle.owner_id = 2
	var kind := "collector" if cargo_context else "production"
	_check(old_field.selection._selected.has(rifle) and not TeamRules.is_controlled(old_field, rifle, 1), "%s refresh fixture reaches a real pending ownership prune" % kind)
	var departed := {"called": false, "identity": "", "cargo": "", "visible": false}
	var leave_during_prune := func(_count: int) -> void:
		if departed["called"]: return
		departed["called"] = true
		# Keep the whole former field alive after removal so an outer refresh
		# cannot rely on object deletion to hide writes made after tree exit.
		root.remove_child(old_field)
		departed["identity"] = panel.identity_label.text
		departed["cargo"] = cargo_panel.label.text
		departed["visible"] = cargo_panel.visible
	old_field.selection.selection_changed.connect(leave_during_prune, CONNECT_ONE_SHOT)
	if cargo_context:
		cargo_panel._refresh()
	else:
		panel._refresh()
	_check(departed["called"] and not old_field.is_inside_tree() and panel.field == null and cargo_panel.field == null, "%s refresh selection prune synchronously removes its owning field" % kind)
	_check(panel.identity_label.text == departed["identity"] and cargo_panel.label.text == departed["cargo"] and cargo_panel.visible == departed["visible"], "%s outer refresh cannot mutate retained panels after its selection callback departs" % kind)
	_check(panel._context_connections.is_empty() and panel._observed == null and cargo_panel._connections.is_empty() and cargo_panel._rejection_observers.is_empty(), "%s outer refresh does not reconnect departed model observers" % kind)
	panel._refresh.call_deferred()
	cargo_panel._refresh.call_deferred()
	await _frames(2)
	_check(panel.identity_label.text == departed["identity"] and cargo_panel.label.text == departed["cargo"], "%s departed refresh remains inert when deferred again" % kind)
	old_field.free()
	await _frames(2)


func _hud_lifecycle() -> void:
	# Verify the actual ordinary scene schedule, without the feature fixtures' 600s.
	await _fresh_combined()
	var definition := load("res://scenes/combined_arms_assault.tscn").instantiate() as BaseAssaultField
	_check(definition.assault_delay == 90, "fresh shared playable scene still defaults to 90 after 600-second test instances")
	definition.free()
	await _hud_key(KEY_F1)
	await _frames(60)
	_check(battle.objective_label.text.ends_with("Enemy assault in %ds" % ceili(maxf(0, battle.assault_delay - battle.elapsed))), "visible countdown derives from configured delay minus the same elapsed simulation clock")
	await _hud_key(KEY_F1)
	await _frames(5200)
	_check(not battle.assault_issued and battle.elapsed < 90, "real ordinary default schedule has no enemy assault before 90 simulated seconds")
	if not await _until(func() -> bool: return battle.assault_issued, 4, "real ordinary enemy assault starts from the displayed schedule"): return
	_check(battle.assault_acceptances == 3 and battle.elapsed >= 90 and battle.elapsed < 90.1 and battle.objective_label.text.ends_with("Enemy assault underway"), "display and all three ordinary enemy orders share the 90-second threshold")
	await _hud_pick_unit(battle.units[0])
	await _hud_key(KEY_4, true)
	await _hud_key(KEY_F1)
	await physics_frame
	TeamRules.damage_target(battle, 1, battle.enemy_headquarters, 1200, battle.units[0])
	await _frames(4)
	_check(battle.result == BaseAssaultField.Result.VICTORY and battle.result_overlay.visible and not battle.production_panel.visible, "actual HQ loss exposes result and freezes ordinary HUD actions")
	var frozen := battle.elapsed
	var version := battle.units[0].order_version
	await _hud_key(KEY_F1)
	await _hud_key(KEY_ESCAPE)
	await _click(_minimap_point(Vector3(-5, 0, 5)), MOUSE_BUTTON_RIGHT)
	await _frames(10)
	_check(battle.elapsed == frozen and battle.units[0].order_version == version and battle.result_overlay.visible, "result overlay preserves frozen simulation/input priority with Help and minimap input")
	_check(root.get_visible_rect().encloses(battle.restart_button.get_global_rect()), "Restart remains accessible in the result layout")
	await _hud_capture("victory_1280x720")
	await _click(battle.restart_button.get_global_rect().get_center(), MOUSE_BUTTON_LEFT)
	await _frames(8)
	battle = current_scene as BaseAssaultField
	field = battle
	world = battle
	harvest = battle
	if battle == null:
		_check(false, "viewport Restart loads combined arms")
		return
	battle.camera_rig.edge_scrolling_enabled = false
	_check(battle.scene_file_path == "res://scenes/combined_arms_assault.tscn" and battle.result == BaseAssaultField.Result.RUNNING and battle.credits.balance(1) == 1000 and battle.units.size() == 8 and battle._producers.is_empty(), "viewport Restart restores normal scene, economy, force and production defaults")
	_check(not battle.help_panel.is_open() and not battle.help_panel.help_content.visible and not battle.movement_debug and battle.control_groups.group_members(4).is_empty(), "Restart clears Help, debug visibility and previous group memberships")
	_check(battle.assault_delay == 90 and battle.elapsed < 1 and not battle.assault_issued and battle.objective_label.text.contains("Enemy assault in 90s"), "Restart resets actual and displayed assault schedule consistently to ordinary 90 seconds")
	_check(battle.selection.selected_building() == battle.headquarters and battle.production_panel.identity_label.text.contains("Headquarters"), "Restart shows fresh authoritative HQ context")
	await _hud_capture("restarted_1280x720")
