extends "res://tests/pause_checks.gd"
## Separate bounded engine run because successful confirmation ends the process.
## Exit 0 after PAUSE_QUIT_DISPATCH confirms actual viewport Quit; continued
## frames instead produce an assertion and exit 1.


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1280, 720)
	var logger := EngineErrorProbe.new()
	OS.add_logger(logger)
	await _fresh_fort()
	await _pause_key(KEY_ESCAPE)
	await _click(battle.pause_menu.quit_button.get_global_rect().get_center(), MOUSE_BUTTON_LEFT)
	_check(paused and battle.pause_menu.confirmation == RTSPauseMenu.Confirmation.QUIT and battle.pause_menu.confirm_button.is_visible_in_tree() and current_scene == battle, "Quit first requires explicit visible confirmation and keeps original match paused")
	await _frames(6)
	_check(paused and battle.is_inside_tree(), "unconfirmed Quit leaves application and match alive")
	OS.remove_logger(logger)
	_check(logger.error_count() == 0, "Quit confirmation setup has no native errors or warnings")
	print("PAUSE_QUIT_CHECKS: %d checks, %d failures; native_errors=%d" % [checks, failures, logger.error_count()])
	if failures > 0:
		quit(1)
		return
	var point := battle.pause_menu.confirm_button.get_global_rect().get_center()
	_motion(point)
	print("PAUSE_QUIT_DISPATCH: sending actual viewport confirm click; successful exit must be 0")
	_button(point, MOUSE_BUTTON_LEFT, true)
	_button(point, MOUSE_BUTTON_LEFT, false)
	await _frames(6)
	_check(false, "confirmed Quit must stop the engine before six further frames")
	quit(1)
