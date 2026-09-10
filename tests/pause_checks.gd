extends "res://tests/fixtures/fortification_harness.gd"
## Focused viewport pause regression, with live ordinary enemy economy and real
## paid builder work. Free completed bodies and an aircraft are explicit timing
## fixtures only. No shared definition or gameplay timing is modified.
## The SceneTree runner and process-always wall observer remain awake on pause.

class PauseKeySink extends Control:
	var presses: int = 0
	func _gui_input(event: InputEvent) -> void:
		if event is InputEventKey and event.pressed:
			presses += 1
			accept_event()

var _pause_observer_ticks: int = 0


func _process(delta: float) -> bool:
	_pause_observer_ticks += 1
	return super._process(delta)


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1280, 720)
	var logger := EngineErrorProbe.new()
	OS.add_logger(logger)
	var chosen := "all"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--pause-case="): chosen = argument.trim_prefix("--pause-case=")
	var cases := ["input", "freeze", "lifecycle", "teardown"]
	_check(chosen == "all" or cases.has(chosen), "recognized focused pause case")
	for case in cases:
		if chosen != "all" and chosen != case: continue
		var before := checks
		var failed := failures
		match case:
			"input": await _pause_input()
			"freeze": await _pause_freeze()
			"lifecycle": await _pause_lifecycle()
			"teardown": await _pause_teardown()
		print("PAUSE_CASE: %s checks=%d failures=%d" % [case, checks - before, failures - failed])
		if paused and is_instance_valid(battle): battle.resume_match()
	if is_instance_valid(field): field.queue_free()
	await _frames(6)
	_check(not paused and root.get_children().is_empty() and get_nodes_in_group("combat_projectiles").is_empty(), "pause teardown leaves no paused tree, field, UI, or projectile")
	OS.remove_logger(logger)
	_check(logger.error_count() == 0, "pause viewport, timers and lifecycle have no native errors or warnings")
	print("PAUSE_CHECKS: %d checks, %d failures; native_errors=%d" % [checks, failures, logger.error_count()])
	quit(0 if failures == 0 else 1)


func _pause_key(code: Key, echo: bool = false) -> void:
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


func _pause_wall_hold(milliseconds: int) -> void:
	var started := Time.get_ticks_msec()
	var observer := _pause_observer_ticks
	var timer := create_timer(0.05, true, false, true)
	var observed := {"fired": false}
	timer.timeout.connect(func() -> void: observed.fired = true)
	while Time.get_ticks_msec() - started < milliseconds:
		await process_frame
		OS.delay_msec(2)
	_check(Time.get_ticks_msec() - started >= milliseconds and _pause_observer_ticks > observer and observed.fired, "real wall time passes while runner watchdog and process-always timeout remain awake")
	print("PAUSE_WALL_OBSERVATION: wall_ms=%d observer_ticks=%d tree_paused=%s" % [Time.get_ticks_msec() - started, _pause_observer_ticks - observer, paused])


func _pause_capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://validation-output/build-area-pause/screenshots")
	var picture := root.get_texture().get_image()
	_check(picture.save_png("res://validation-output/build-area-pause/screenshots/%s.png" % label) == OK and picture.get_size() == root.size, "saved actual pause viewport " + label)


func _pause_input() -> void:
	await _fresh_fort(2000)
	var source := battle.units[0]
	await _click(_screen(source), MOUSE_BUTTON_LEFT)
	_check(battle.selection.selected_units() == [source], "actual viewport selects starting Rifle")
	await physics_frame
	_check(battle.issue_move(Vector3(-12, 0, 17)).has_acceptance(), "ordinary accepted movement precedes pause")
	var version := source.order_version
	await _pause_key(KEY_ESCAPE)
	_check(paused and battle.manual_pause_active and battle.pause_menu.overlay.visible and source.order_version == version and source.moving, "one Escape opens engine Pause and preserves accepted movement")
	await _pause_key(KEY_ESCAPE, true)
	_check(paused and battle.manual_pause_active, "repeated Escape cannot close Pause")
	for dimensions in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		root.size = dimensions
		await _frames(8)
		var menu := battle.pause_menu
		_check(root.get_visible_rect().encloses(menu.overlay.get_global_rect()) and menu.overlay.get_global_rect().size == Vector2(dimensions), "Pause blocks entire actual viewport at %s" % dimensions)
		for button in [menu.resume_button, menu.restart_button, menu.quit_button]:
			_check(button.visible and root.get_visible_rect().encloses(button.get_global_rect()), "Pause action fits viewport at %s" % dimensions)
		await _pause_capture("pause_%dx%d" % [dimensions.x, dimensions.y])
	root.size = Vector2i(1280, 720)
	await _frames(5)
	var camera := battle.camera_rig.position
	var selected := battle.selection.selected_units()
	await _click(Vector2(30, 300), MOUSE_BUTTON_LEFT)
	await _click(_minimap_point(Vector3(15, 0, 16)), MOUSE_BUTTON_RIGHT)
	await _pause_key(KEY_Q)
	await _pause_key(KEY_X)
	await _pause_key(KEY_F1)
	await _tactical_key(4, true)
	_check(paused and source.order_version == version and source.moving and battle.selection.selected_units() == selected and battle.camera_rig.position == camera and not battle.selection.attack_move_targeting and not battle.help_panel.is_open() and battle.control_groups.group_members(4).is_empty(), "paused backdrop, minimap, Q/X/F1 and group input cannot click through or issue orders")
	await _click(battle.pause_menu.resume_button.get_global_rect().get_center(), MOUSE_BUTTON_LEFT)
	_check(not paused and not battle.manual_pause_active and source.order_version == version, "viewport Resume resumes existing order without replacing it")
	await _pause_key(KEY_ESCAPE, true)
	_check(not paused, "repeated Escape cannot open Pause")
	var sink := PauseKeySink.new()
	sink.focus_mode = Control.FOCUS_ALL
	sink.position = Vector2(700, 300)
	sink.size = Vector2(40, 40)
	battle.get_node("ControlsFeedback").add_child(sink)
	sink.grab_focus()
	await _pause_key(KEY_ESCAPE)
	_check(sink.presses == 1 and not paused, "focused unrelated GUI retains consumed Escape")
	sink.release_focus()
	sink.queue_free()
	await _frames(2)
	await _pause_key(KEY_Q)
	_check(battle.selection.attack_move_targeting, "viewport Q enters pending targeting")
	await _click(Vector2(600, 300), MOUSE_BUTTON_RIGHT)
	_check(not battle.selection.attack_move_targeting and not paused and source.order_version == version, "right-click cancels targeting without Pause or replacing accepted order")
	await _pause_key(KEY_Q)
	await _pause_key(KEY_F1)
	_check(battle.selection.attack_move_targeting and battle.help_panel.is_open(), "targeting and Help are both active before Escape")
	await _pause_key(KEY_ESCAPE)
	_check(paused and not battle.selection.attack_move_targeting and not battle.help_panel.is_open() and source.order_version == version, "same Escape cancels targeting, closes Help and opens Pause with accepted order retained")
	await _pause_key(KEY_ESCAPE)
	_check(not paused, "Escape on Pause resumes exactly once")
	var builder := _player_builders()[0]
	await _click(_screen(builder), MOUSE_BUTTON_LEFT)
	await _frames(2)
	var funds := battle.credits.balance(1)
	await _click((battle.production_panel as ConstructionPanel).depot_button.get_global_rect().get_center(), MOUSE_BUTTON_LEFT)
	_check(battle.placement.active, "viewport Depot button starts uncommitted builder placement")
	await _pause_key(KEY_ESCAPE)
	_check(paused and not battle.placement.active and battle.construction.sites.is_empty() and battle.credits.balance(1) == funds and builder.assigned_site_id == 0, "placement Escape opens Pause without spending, creating a site or assigning builder")
	await _pause_key(KEY_ESCAPE)
	await _click((battle.production_panel as ConstructionPanel).depot_button.get_global_rect().get_center(), MOUSE_BUTTON_LEFT)
	await _click(Vector2(600, 300), MOUSE_BUTTON_RIGHT)
	_check(not paused and not battle.placement.active and battle.credits.balance(1) == funds, "right-click cancels building preview without Pause or spending")


func _pause_snapshot() -> Dictionary:
	var snapshot := {"elapsed": battle.elapsed, "assault": [battle.assault_issued, battle.assault_acceptances], "camera": [battle.camera_rig.position, battle.camera_rig.zoom, battle.camera_rig.target_zoom], "funds": [battle.credits.balance(1), battle.credits.balance(2)], "units": [], "sites": [], "queues": [], "caches": [], "projectiles": [], "gates": [], "enemy": []}
	for actor in battle.units:
		var data: Array = [actor.unit_id, actor.global_position, actor.rotation, actor.velocity, actor.order_version, actor.moving, actor.assigned_destination, actor.combat.health.current]
		if actor.combat.weapon != null: data.append([actor.combat.weapon.cooldown_remaining, actor.combat.weapon.shots_fired])
		if actor is CollectorTruck: data.append([actor.harvesting.state, actor.harvesting.cargo, actor.harvesting._elapsed, actor.harvesting.generation])
		if actor is Bulldozer: data.append(actor.assigned_site_id)
		if actor is AttackHelicopter: data.append(actor.is_taking_off())
		snapshot.units.append(data)
	for site in battle.construction.sites.values(): snapshot.sites.append([site.site_id, site.state, site.elapsed, site.work_order_version, site.assignment_generation, site.refunded])
	for body in battle.registered_buildings():
		if body.production != null: snapshot.queues.append([body.get_instance_id(), body.production.jobs()])
		if body is BarrierBuilding: snapshot.gates.append([body.physical_open, body.requested_open, body.navigation_pending, body.transition_generation, body.nav_generation])
		if body is GroundDefenseBattery: snapshot.queues.append([body.health.current, body.weapon.cooldown_remaining, body.weapon.shots_fired])
	for cache in battle.caches: snapshot.caches.append(cache.remaining)
	for projectile in get_nodes_in_group("combat_projectiles"): snapshot.projectiles.append([projectile.get_instance_id(), projectile.global_position, projectile.age, projectile.spent])
	var enemy := fort.enemy_controller
	snapshot.enemy = [enemy._clock, enemy._breach_clock, enemy.plans, enemy.accepted_jobs, enemy.deployments, enemy.launches, enemy.harvest_assignments]
	return snapshot


func _pause_freeze() -> void:
	await _fresh_fort(6000, true, true)
	var gate := _fort_fixture(GATE, FORT_GATE_POINT)
	await _until(func() -> bool: return not fort.construction.navigation.blocked, 3, "timing fixture gate navigation synchronizes")
	var builder := _player_builders()[0]
	var site := await _builder_arrival(await _builder_place(builder, DEPOT, DEPOT_POINT))
	if site == null: return
	await _frames(20)
	var producer := _power_fixture_building(POWER_BARRACKS, 1, SECOND).production
	_check(producer.enqueue(1, POWER_RIFLE).accepted, "timing fixture purchases ordinary Rifle queue at normal cost and duration")
	var aircraft := load("res://scenes/attack_helicopter.tscn").instantiate() as AttackHelicopter
	aircraft.unit_id = 901
	aircraft.owner_id = 1
	aircraft.position = Vector3(-20, 2.08, 3)
	fort.add_child(aircraft)
	fort.register_unit(aircraft)
	aircraft.begin_takeoff()
	await physics_frame
	_check(aircraft.move_to(Vector3(-20, 0, 18)), "explicit aircraft fixture accepts move while taking off")
	var source := battle.units[0]
	battle.selection.replace_units([source])
	_check(battle.issue_move(Vector3(-12, 0, 17)).has_acceptance(), "starting ground actor has real accepted move during builder work")
	# Existing projectile implementation with its normal recipe isolates in-flight
	# pause retention without waiting for unrelated battle positioning.
	var target := _defense_mobile(Vector3(-15, 0, 18), 2)
	var projectile := GuidedProjectile.new()
	projectile.configure(battle, aircraft, target, load("res://weapons/helicopter_rocket.tres"))
	battle.add_child(projectile)
	projectile.global_position = Vector3(-22, 8, 18)
	source.combat.weapon.cooldown_remaining = 0.8
	await _pause_key(KEY_ESCAPE)
	_check(paused and site.state == ConstructionSite.State.CONSTRUCTING and site.elapsed > 0 and builder.assigned_site_id == site.site_id and source.moving and aircraft.is_taking_off() and producer.count() == 1 and not projectile.spent, "Pause retains paid site, working builder, accepted ground/air orders, production and live projectile")
	_check(fort.enemy_controller.is_physics_processing() and fort.enemy_controller.plans > 0 and fort.collectors.any(func(truck: CollectorTruck) -> bool: return truck.harvesting.state != CollectorHarvest.State.IDLE), "ordinary live enemy planner and actual collector work participate in freeze snapshot")
	var before := _pause_snapshot()
	await _pause_wall_hold(1200)
	_check(_pause_snapshot() == before, "all ground/air motion, takeoff, health/cooldowns/projectiles, harvesting/deposits, production/construction, enemy clocks, gates and camera stay bit-identical over real wall time")
	await physics_frame
	var funds := battle.credits.balance(1)
	_check(not battle.construction.cancel(1, site.site_id).accepted and not producer.cancel(1, producer.jobs()[0].id).accepted and not producer.enqueue(1, POWER_RIFLE).accepted and not gate.request_gate(1, true).accepted, "paused cancellation/purchase/gate callbacks cannot refund sites, cancel jobs, spend or operate gates")
	_check(not battle.issue_move(Vector3(-8, 0, 18)).has_acceptance(), "direct paused world order cannot replace accepted command")
	battle.construction.advance(10.0)
	producer.advance(10.0)
	fort.enemy_controller.plan()
	fort.enemy_controller._physics_process(10.0)
	source._physics_process(10.0)
	source._on_avoidance_velocity(Vector3(100, 0, 100))
	source.combat.health.apply_damage(20.0, target)
	source.combat.weapon.advance(10.0)
	aircraft._physics_process(10.0)
	projectile._physics_process(10.0)
	for truck in fort.collectors: truck.harvesting.advance(10.0)
	await _frames(2)
	_check(_pause_snapshot() == before and battle.credits.balance(1) == funds, "direct late gameplay callbacks remain inert without erasing accepted state")
	var elapsed := battle.elapsed
	var progress := site.elapsed
	var altitude := aircraft.global_position.y
	await _pause_key(KEY_ESCAPE)
	await _frames(6)
	_check(not paused and battle.elapsed > elapsed and battle.elapsed - elapsed < 0.2 and site.elapsed > progress and site.elapsed - progress < 0.2 and aircraft.global_position.y > altitude and aircraft.global_position.y - altitude < 1.0, "Resume continues retained work and takeoff by ordinary simulation ticks without wall-time catch-up")
	_check(builder.assigned_site_id == site.site_id and not site.refunded and producer.count() == 1, "Resume preserves builder assignment, original paid site and queued purchase")
	# Real lifecycle deletion must still detach/refund its existing paid site;
	# only the navigation work waits for Resume.
	await _pause_key(KEY_ESCAPE)
	funds = battle.credits.balance(1)
	site.building().queue_free()
	await _frames(3)
	_check(paused and site.refunded and site.state == ConstructionSite.State.CANCELLING and builder.assigned_site_id == 0 and battle.credits.balance(1) == funds + site.paid and battle.construction.navigation.blocked, "actual paid-site deletion while paused reconciles refund and releases builder while topology waits")
	var generation := battle.construction.navigation.generation
	var submissions := battle.construction.navigation.submissions
	await _pause_wall_hold(300)
	_check(site.state == ConstructionSite.State.CANCELLING and battle.construction.navigation.generation == generation and battle.construction.navigation.submissions == submissions and battle.credits.balance(1) == funds + site.paid, "paused lifecycle cleanup cannot submit navigation or refund twice while wall time passes")
	await _pause_key(KEY_ESCAPE)
	if not await _until(func() -> bool: return not battle.construction.navigation.blocked and battle.construction.unfinished_id == 0, 3, "Resume finishes retained paid-site deletion and restores terrain"): return
	var sync_pause := {"fired": false, "notifications": 0}
	var pause_during_sync := func(_generation: int) -> void:
		sync_pause.notifications += 1
		if not sync_pause.fired:
			sync_pause.fired = true
			battle.pause_match()
	battle.construction.navigation.synchronized.connect(pause_during_sync)
	await physics_frame
	_check(gate.request_gate(1, true).accepted and gate.navigation_pending and gate.requested_open and not gate.physical_open, "ordinary gate opening commits a pending operation before Pause")
	await _pause_key(KEY_ESCAPE)
	generation = battle.construction.navigation.generation
	submissions = battle.construction.navigation.submissions
	var transition := gate.transition_generation
	await physics_frame
	battle.construction.navigation.advance(10.0)
	gate._navigation_synchronized(gate.nav_generation)
	await _pause_wall_hold(300)
	_check(paused and gate.navigation_pending and gate.requested_open and not gate.physical_open and gate.transition_generation == transition and battle.construction.navigation.generation == generation and battle.construction.navigation.submissions == submissions, "pending gate transition and direct late topology callback remain frozen through Pause")
	await _pause_key(KEY_ESCAPE)
	if not await _until(func() -> bool: return paused and sync_pause.fired, 3, "synchronous navigation listener opens Pause before gate physical commit"): return
	_check(gate.navigation_pending and not gate.physical_open and battle.construction.navigation.blocked and battle.construction.navigation._resume_generation == generation, "pause during synchronization retains witnessed generation and defers collider commit")
	await _pause_wall_hold(300)
	_check(gate.navigation_pending and not gate.physical_open, "synchronously paused gate stays unchanged through subsequent wall time")
	await _pause_key(KEY_ESCAPE)
	await _until(func() -> bool: return _fort_gate_ready(gate, true), 3, "Resume completes the original accepted gate operation without replacing it")
	_check(sync_pause.notifications == 1 and battle.construction.navigation._deferred_synchronizations.is_empty(), "Resume delivers synchronization once and drains only the deferred gate callback")
	battle.construction.navigation.synchronized.disconnect(pause_during_sync)


func _pause_lifecycle() -> void:
	await _fresh_fort(2000)
	await _pause_key(KEY_ESCAPE)
	for action in [battle.pause_menu.restart_button, battle.pause_menu.quit_button]:
		await _click(action.get_global_rect().get_center(), MOUSE_BUTTON_LEFT)
		_check(paused and battle.pause_menu.confirmation != 0 and battle.pause_menu.confirmation_panel.visible and current_scene == battle, "Restart/Quit opens confirmation while preserving paused match")
		await _pause_capture("pause_confirmation_%s" % action.text.to_lower().replace(" ", "_"))
		await _pause_key(KEY_ESCAPE)
		_check(paused and battle.pause_menu.confirmation == 0 and battle.pause_menu.resume_button.visible, "Escape cancels confirmation and keeps Pause open")
	await _click(battle.pause_menu.restart_button.get_global_rect().get_center(), MOUSE_BUTTON_LEFT)
	await _click(battle.pause_menu.cancel_button.get_global_rect().get_center(), MOUSE_BUTTON_LEFT)
	_check(paused and battle.pause_menu.confirmation == 0, "confirmation Cancel button keeps match paused")
	var old_field: WeakRef = weakref(battle)
	var old_menu: WeakRef = weakref(battle.pause_menu)
	var old_selection: WeakRef = weakref(battle.selection)
	await _click(battle.pause_menu.restart_button.get_global_rect().get_center(), MOUSE_BUTTON_LEFT)
	await _click(battle.pause_menu.confirm_button.get_global_rect().get_center(), MOUSE_BUTTON_LEFT)
	await _frames(8)
	_adopt_fort(current_scene as FortifiedAssaultField)
	if fort == null:
		_check(false, "confirmed paused Restart loads playable Fortified Assault")
		return
	fort.camera_rig.edge_scrolling_enabled = false
	_check(old_field.get_ref() == null and old_menu.get_ref() == null and old_selection.get_ref() == null, "confirmed Restart disposes old field, pause input owner and selection")
	_check(not paused and not fort.manual_pause_active and fort.gameplay_enabled and fort.result == BaseAssaultField.Result.RUNNING and fort.scene_file_path == "res://scenes/fortified_assault.tscn" and fort.credits.balance(1) == 1000 and fort.elapsed < 1 and fort.construction.sites.is_empty(), "paused Restart creates fresh unpaused ordinary match with original wallet and no sites")
	_check(not fort.placement.active and not fort.selection.attack_move_targeting and fort.selection._pending_picks.is_empty() and not fort.help_panel.is_open(), "fresh match has no old placement, targeting, picks or Help")
	await _pause_key(KEY_ESCAPE)
	_check(paused, "first Escape in restarted match opens exactly one Pause")
	await _pause_key(KEY_ESCAPE)
	await physics_frame
	TeamRules.damage_target(fort, 1, fort.enemy_headquarters, 10000, fort.units[0])
	await _frames(3)
	_check(fort.result == BaseAssaultField.Result.VICTORY and fort.result_overlay.visible and not fort.gameplay_enabled, "actual HQ defeat enters ordinary frozen result screen")
	var elapsed := fort.elapsed
	await _pause_key(KEY_ESCAPE)
	await _pause_key(KEY_ESCAPE)
	await _frames(15)
	_check(not fort.manual_pause_active and not fort.pause_menu.overlay.visible and not fort.gameplay_enabled and fort.result_overlay.visible and fort.elapsed == elapsed, "Escape cannot open Pause or resume simulation through finished result")
	await _click(fort.restart_button.get_global_rect().get_center(), MOUSE_BUTTON_LEFT)
	await _frames(8)
	_adopt_fort(current_scene as FortifiedAssaultField)
	_check(fort != null and not paused and fort.result == BaseAssaultField.Result.RUNNING and fort.gameplay_enabled and fort.credits.balance(1) == 1000, "existing result-screen Restart remains clean and usable")


func _pause_teardown() -> void:
	for pause_before_exit in [false, true]:
		await _fresh_fort(2000)
		var manager := fort.construction
		var navigation := manager.navigation
		var producer := fort.headquarters.production
		_check(producer.enqueue(1, BUILDER_RECIPE).accepted, "teardown fixture retains a normally paid HQ production job")
		var result := await _builder_place(_player_builders()[0], DEPOT, DEPOT_POINT)
		_check(result.accepted and navigation.blocked, "teardown fixture retains paid construction and pending navigation")
		if pause_before_exit: await _pause_key(KEY_ESCAPE)
		var references: Array[WeakRef] = [weakref(fort), weakref(fort.pause_menu), weakref(fort.selection)]
		for actor in fort.units: references.append(weakref(actor))
		fort.queue_free()
		await _frames(6)
		_check(not paused and root.get_children().is_empty() and references.all(func(reference: WeakRef) -> bool: return reference.get_ref() == null), "normal/paused teardown frees field, menu, selection and all units: paused=%s" % pause_before_exit)
		_check(manager.closed and manager.sites.is_empty() and navigation.closed and navigation._deferred_synchronizations.is_empty() and navigation.ready.get_connections().is_empty() and navigation.synchronized.get_connections().is_empty() and producer._closed and producer.count() == 0, "normal/paused teardown closes pending work and removes listeners: paused=%s" % pause_before_exit)
		var submissions := navigation.submissions
		await _pause_wall_hold(100)
		navigation.advance(10.0)
		producer.advance(10.0)
		_check(root.get_children().is_empty() and navigation.submissions == submissions and producer.count() == 0, "late callbacks cannot recreate or reactivate an exited match")
	await _pause_deferred_gate_teardown()


func _pause_deferred_gate_teardown() -> void:
	for detach_gate in [false, true]:
		await _fresh_fort(2000)
		var navigation := fort.construction.navigation
		var gate := _fort_fixture(GATE, FORT_GATE_POINT)
		if not await _until(func() -> bool: return not navigation.blocked, 3, "deferred teardown fixture gate navigation synchronizes"): return
		var notices := {"synchronized": 0, "ready": 0, "pause": false}
		# Connect before request_gate binds the gate, so Pause happens before its
		# collider callback. The same observer first witnesses an ordinary opening.
		var observe_sync := func(_generation: int) -> void:
			notices.synchronized += 1
			if notices.pause: fort.pause_match()
		navigation.synchronized.connect(observe_sync)
		navigation.ready.connect(func(_generation: int) -> void: notices.ready += 1)
		await physics_frame
		_check(gate.request_gate(1, true).accepted, "unpaused control accepts ordinary gate opening")
		if not await _until(func() -> bool: return _fort_gate_ready(gate, true), 3, "unpaused control commits collider and resumes navigation"): return
		_check(notices.synchronized == 1 and notices.ready == 1 and navigation._deferred_synchronizations.is_empty(), "unpaused gate emits synchronization and ready exactly once without deferred callbacks")
		notices.pause = true
		await physics_frame
		_check(gate.request_gate(1, false).accepted, "deferred teardown accepts gate closing before Pause")
		if not await _until(func() -> bool: return paused, 3, "deferred teardown pauses inside synchronization before collider commit"): return
		var callback := gate._navigation_synchronized
		var generation := gate.nav_generation
		_check(notices.synchronized == 2 and notices.ready == 1 and gate.physical_open and gate.navigation_pending and navigation.blocked and navigation._resume_generation == generation and navigation._deferred_synchronizations.get(callback, 0) == generation, "teardown starts with an actual deferred gate callback and no closing collider commit")
		var field_reference: WeakRef = weakref(fort)
		var gate_reference: WeakRef = weakref(gate)
		if detach_gate:
			# Keep this removed Node alive only to deliver a real matching late
			# callback after its match exits; it is explicitly freed below.
			fort.remove_child(gate)
			_check(navigation._deferred_synchronizations.is_empty() and not navigation.synchronized.is_connected(callback), "gate departure forgets its populated deferred callback and disconnects its listener")
		fort.queue_free()
		await _frames(6)
		_check(not paused and field_reference.get_ref() == null and navigation.closed and navigation._deferred_synchronizations.is_empty() and navigation.synchronized.get_connections().is_empty() and navigation.ready.get_connections().is_empty(), "paused match teardown clears retained synchronization and listeners: detached_gate=%s" % detach_gate)
		var submissions := navigation.submissions
		if detach_gate:
			var state := [gate.physical_open, gate.requested_open, gate.navigation_pending, gate.transition_generation]
			callback.call(generation)
			gate._navigation_ready(generation)
			_check([gate.physical_open, gate.requested_open, gate.navigation_pending, gate.transition_generation] == state and gate._navigation == null, "matching late gate synchronization and ready callbacks cannot mutate an exited match")
			gate.free()
		navigation.advance(10.0)
		_check(root.get_children().is_empty() and gate_reference.get_ref() == null and not callback.is_valid() and navigation.submissions == submissions and notices.synchronized == 2 and notices.ready == 1, "closed navigation cannot replay synchronization, emit ready, or retain the exited gate")
