extends "res://tests/milestone_checks.gd"
## Isolated external-timeout fixture. Never loaded by a normal test suite.


func _run() -> void:
	if not OS.get_cmdline_user_args().has("--verify-external-timeout"):
		push_error("Blocking fixture requires --verify-external-timeout")
		quit(3)
		return
	print("BLOCKING_FIXTURE: main thread intentionally blocked; pid=", OS.get_process_id())
	_deadline_msec = Time.get_ticks_msec() + 50
	while true:
		OS.delay_msec(100) # No event-loop yield: the internal watchdog cannot run.
