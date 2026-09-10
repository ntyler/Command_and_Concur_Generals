extends "res://tests/fixtures/fortification_harness.gd"
## No match is instantiated. The external runner must also find zero shutdown
## warnings/resources: inherited compile-time fixture preloads used to leak
## the gameplay script graph even when this runner performed no gameplay.


func _run() -> void:
	_check(root.get_children().is_empty(), "fixture resource loading creates no runtime match nodes")
	print("FIXTURE_RESOURCE_CHECKS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
