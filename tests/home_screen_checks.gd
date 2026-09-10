extends SceneTree
## Real viewport navigation; result injection is only a finished-menu fixture.

var checks: int = 0
var failures: int = 0
var _started: int = Time.get_ticks_msec()


func _initialize() -> void:
	_run.call_deferred()


func _process(_delta: float) -> bool:
	if Time.get_ticks_msec() - _started > 90000:
		print("FAIL: home-screen internal watchdog")
		quit(1)
	return false


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: " + message)


func _frames(count: int = 5) -> void:
	for _frame in count:
		await process_frame


func _until_scene(path: String) -> bool:
	for _frame in 600:
		await process_frame
		if is_instance_valid(current_scene) and current_scene.scene_file_path == path:
			await _frames()
			_check(true, "scene became " + path)
			return true
	_check(false, "scene did not become " + path)
	return false


func _click(button: Button) -> void:
	var point := button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	root.push_input(motion, true)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		root.push_input(event, true)
	await _frames()


func _key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		root.push_input(event, true)
	await _frames()


func _capture(label: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var directory := "res://validation-output/home-screen/screenshots"
	DirAccess.make_dir_recursive_absolute(directory)
	_check(root.get_texture().get_image().save_png(directory + "/" + label + ".png") == OK, "saved actual viewport " + label)


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	var logger := EngineErrorProbe.new()
	OS.add_logger(logger)
	var configured: String = ProjectSettings.get_setting("application/run/main_scene")
	_check(configured == "res://scenes/home_screen.tscn", "F5/default launch opens Home")
	_check(change_scene_to_file(configured) == OK, "configured startup scene loads")
	if not await _until_scene("res://scenes/home_screen.tscn"):
		quit(1)
		return
	await _home_layout()
	await _library_round_trip()
	await _match_round_trip()
	await _result_round_trip()
	if is_instance_valid(current_scene):
		current_scene.queue_free()
	await _frames(8)
	_check(not paused and root.get_children().is_empty(), "home, preview, library and match nodes release at teardown")
	_check(get_nodes_in_group("combat_projectiles").is_empty(), "return-home loops leave no projectiles")
	OS.remove_logger(logger)
	_check(logger.error_count() == 0, "home and scene navigation have no native errors or warnings")
	print("HOME_SCREEN_CHECKS: %d checks, %d failures; native_errors=%d" % [checks, failures, logger.error_count()])
	quit(0 if failures == 0 else 1)


func _home_layout() -> void:
	var home := current_scene as RTSHomeScreen
	_check(root.gui_get_focus_owner() == home.play_button, "Play receives initial keyboard focus")
	_check(home.skirmish_button.disabled and home.manual_map_button.disabled and home.ai_map_button.disabled, "unfinished original skirmish and manual/AI map tools cannot launch a substitute")
	_check(home.preview.own_world_3d and home.preview.find_children("*", "MeshInstance3D", true, false).size() > 2, "home preview owns actual imported geometry in its own world")
	for dimensions in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		root.size = dimensions
		await _frames(8)
		for button in [home.play_button, home.library_button, home.skirmish_button, home.manual_map_button, home.ai_map_button, home.quit_button]:
			_check(button.is_visible_in_tree() and root.get_visible_rect().encloses(button.get_global_rect()), "home action fits viewport at %s: %s" % [dimensions, button.text])
		await _capture("home_%dx%d" % [dimensions.x, dimensions.y])
	root.size = Vector2i(1280, 720)
	await _frames()


func _library_round_trip() -> void:
	var home_ref: WeakRef = weakref(current_scene)
	await _key(KEY_TAB)
	_check(root.gui_get_focus_owner() == current_scene.library_button, "Tab navigates from Play to Object Library")
	await _key(KEY_ENTER)
	if not await _until_scene("res://scenes/generals_asset_browser.tscn"):
		return
	_check(home_ref.get_ref() == null, "opening the library releases the home preview")
	var library = current_scene
	_check(library.entries.size() > 0 and library.selected_name == "avconstdoz_a", "library opens its existing catalog and Dozer selection")
	_check(root.get_visible_rect().encloses(library.home_button.get_global_rect()), "library Home action fits viewport")
	_check(root.get_visible_rect().encloses(library.list.get_global_rect()) and root.get_visible_rect().encloses(library.details.get_global_rect()), "library list and details fit after adding Home")
	if "--home-library-preview" in OS.get_cmdline_user_args():
		_check(is_instance_valid(library.model), "local full-data check renders the selected Dozer")
		await _capture("library_home_dozer")
	var library_ref: WeakRef = weakref(library)
	await _click(library.home_button)
	if not await _until_scene("res://scenes/home_screen.tscn"):
		return
	_check(library_ref.get_ref() == null, "Home button releases library resources")
	await _click(current_scene.library_button)
	if not await _until_scene("res://scenes/generals_asset_browser.tscn"):
		return
	await _key(KEY_ESCAPE)
	await _until_scene("res://scenes/home_screen.tscn")
	_check(not paused, "library Escape returns home with an awake tree")


func _start_match() -> bool:
	await _click(current_scene.play_button)
	if not await _until_scene("res://scenes/fortified_assault.tscn"):
		return false
	var battle = current_scene
	for _frame in 600:
		if not battle.construction.navigation.blocked:
			break
		await process_frame
	_check(not battle.construction.navigation.blocked and battle.gameplay_enabled and not paused, "Play starts a live match with synchronized navigation")
	battle.camera_rig.edge_scrolling_enabled = false
	return true


func _match_round_trip() -> void:
	if not await _start_match():
		return
	var battle = current_scene
	_check(not battle.return_to_home(), "a running unpaused match cannot leave without opening Pause")
	await _key(KEY_ESCAPE)
	var menu = battle.pause_menu
	_check(paused and menu.overlay.visible, "Escape opens existing Pause from a home-launched match")
	root.size = Vector2i(1280, 720)
	await _frames()
	_check(root.get_visible_rect().encloses(menu.home_button.get_global_rect()), "Pause Return to Home fits 720p")
	await _capture("pause_return_home")
	await _click(menu.home_button)
	_check(paused and current_scene == battle and menu.confirmation == RTSPauseMenu.Confirmation.HOME, "Return to Home requires confirmation and preserves the paused match")
	await _key(KEY_ESCAPE)
	_check(paused and menu.confirmation == RTSPauseMenu.Confirmation.NONE and menu.menu_panel.visible, "Escape cancels the Home confirmation")
	await _key(KEY_ESCAPE)
	_check(not paused and current_scene == battle and not battle.manual_pause_active, "Resume after cancelled Home keeps the same match")
	var field_ref: WeakRef = weakref(battle)
	var navigation = battle.construction.navigation
	var navigation_ref: WeakRef = weakref(navigation)
	await _key(KEY_ESCAPE)
	await _click(menu.home_button)
	await _capture("home_confirmation")
	await _click(menu.confirm_button)
	if not await _until_scene("res://scenes/home_screen.tscn"):
		return
	_check(not paused and field_ref.get_ref() == null, "confirmed Home removes the match and clears tree Pause")
	_check(navigation.closed and navigation.field() == null and navigation._deferred_synchronizations.is_empty() and navigation.synchronized.get_connections().is_empty(), "Home closes navigation, clears deferred callbacks and disconnects listeners")
	navigation = null
	_check(navigation_ref.get_ref() == null, "closed navigation is no longer retained by the home screen")


func _result_round_trip() -> void:
	if not await _start_match():
		return
	var battle = current_scene
	# Fixture-only lethal damage reaches the existing result resolver; this is not
	# a combat acceptance or earned victory test.
	battle.enemy_headquarters.health.apply_damage(100000)
	for _frame in 300:
		if battle.result != BaseAssaultField.Result.RUNNING:
			break
		await process_frame
	_check(battle.result == BaseAssaultField.Result.VICTORY and battle.result_overlay.visible, "fixture reaches the finished-match screen")
	await _capture("result_return_home")
	var field_ref: WeakRef = weakref(battle)
	await _click(battle.home_button)
	await _until_scene("res://scenes/home_screen.tscn")
	_check(not paused and field_ref.get_ref() == null, "finished-match Home returns without retaining the completed match")
