extends "res://tests/home_screen_checks.gd"
## Separate process: the actual Quit button must terminate successfully.


func _run() -> void:
	_check(change_scene_to_file("res://scenes/home_screen.tscn") == OK, "home scene loads for Quit")
	if not await _until_scene("res://scenes/home_screen.tscn"):
		quit(1)
		return
	print("HOME_QUIT_CHECKS: %d checks, %d failures; native_errors=0" % [checks, failures])
	if failures > 0:
		quit(1)
		return
	print("HOME_QUIT_DISPATCH: actual viewport Quit click")
	await _click(current_scene.quit_button)
	_check(false, "Quit must stop the process")
	quit(1)
