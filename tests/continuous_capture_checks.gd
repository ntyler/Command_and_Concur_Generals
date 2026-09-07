extends "res://tests/milestone_checks.gd"
## Validation ONLY. No cluster goal dispatch and no mechanism mode exist here.
const ContinuousField = preload("res://tests/continuous_capture_field.gd")
const ContinuousRecorder = preload("res://tests/continuous_capture_recorder.gd")
const FIXTURE_HASH := "d56be378d165d2c5fbf65e1391e8e9d41f0b5d82c77f648e87db8b93d7c55307"
var observation: RefCounted
var output_prefix := ""
var validation_mode := ""
var validation_inputs := ""
var failed_capture := false


func _run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--continuous-prefix="):
			output_prefix = argument.trim_prefix("--continuous-prefix=")
		elif argument.begins_with("--continuous-mode="):
			validation_mode = argument.trim_prefix("--continuous-mode=")
		elif argument.begins_with("--continuous-inputs="):
			validation_inputs = argument.trim_prefix("--continuous-inputs=")
	# Nothing below creates a field until all external input/output checks pass.
	if validation_mode not in ["contract", "parked"] or output_prefix.is_empty() or not FileAccess.file_exists(validation_inputs):
		push_error("CONTINUOUS_PREFLIGHT: invalid mode/prefix/missing inputs; no field created")
		quit(2)
		return
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(validation_inputs)) != OK or not json.data is Dictionary:
		push_error("CONTINUOUS_PREFLIGHT: invalid input JSON; no field created")
		quit(2)
		return
	var inputs: Dictionary = json.data
	if inputs.get("fixture_sha256") != FIXTURE_HASH or FileAccess.get_sha256("res://tests/fixtures/unit13_predeadlock.json") != FIXTURE_HASH:
		push_error("CONTINUOUS_PREFLIGHT: fixture identity mismatch; no field created")
		quit(2)
		return
	var canonical: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/unit13_predeadlock.json"))
	if validation_mode == "parked" and inputs.get("fixture") != canonical:
		push_error("CONTINUOUS_PREFLIGHT: prepared fixture differs from exact canonical input; no field created")
		quit(2)
		return
	if validation_mode == "contract":
		if not inputs.get("frames") is Array or inputs.frames.size() != 3:
			quit(2)
			return
		for index in range(3):
			if not inputs.frames[index] is Dictionary:
				quit(2)
				return
			var prepared: Dictionary = inputs.frames[index]
			if int(prepared.get("frame", -1)) != 653 + index or not prepared.get("rows") is Array or prepared.rows.size() != 50:
				quit(2)
				return
			for row_index in range(50):
				if not prepared.rows[row_index] is Dictionary:
					quit(2)
					return
				var row: Dictionary = prepared.rows[row_index]
				if int(row.get("id", -1)) != row_index + 1 or not row.get("state") is Dictionary or not row.get("callbacks") is Array or not row.get("direct_movements") is Array:
					quit(2)
					return
	observation = ContinuousRecorder.new()
	observation.run_id = output_prefix.get_file()
	observation.source_id = FileAccess.get_sha256("res://scripts/rts_unit.gd")
	observation.capture_failed.connect(_capture_failed)
	var first_frame: int = 653 if validation_mode == "contract" else Engine.get_physics_frames()
	if not observation.open_stream(output_prefix + ".jsonl", "synthetic_contract" if validation_mode == "contract" else "parked_wiring", FIXTURE_HASH, first_frame):
		push_error("CONTINUOUS_PREFLIGHT: output unavailable; no field created")
		quit(2)
		return
	if validation_mode == "contract":
		_contract(inputs)
	else:
		await _parked(inputs)


func _contract(inputs: Dictionary) -> void:
	if not inputs.get("frames") is Array or inputs.frames.size() != 3:
		_capture_failed("synthetic contract requires three prepared frames")
		return
	for frame in inputs.frames:
		_check(observation.contract_frame(int(frame.frame), frame.rows), "continuous contract: serializer accepts complete50-row frame%d" % int(frame.frame))
		if failed_capture:
			return
	var footer: Dictionary = observation.finish_stream()
	_check(bool(footer.complete) and footer.frames == 3 and footer.pending_delegates == 0, "continuous contract: complete footer after three frames")
	_check(field == null, "continuous contract: no live field or actor was created")
	# Exercise real writer limits with synthetic dictionaries only. Expected
	# incomplete artifacts are preserved separately from the positive stream.
	var limited: RefCounted = ContinuousRecorder.new()
	limited.run_id = observation.run_id + "-capacity"
	limited.source_id = observation.source_id
	limited.max_frames = 1
	_check(limited.open_stream(output_prefix + "-capacity.jsonl", "synthetic_contract", FIXTURE_HASH, 653), "continuous contract: capacity writer opens")
	_check(limited.contract_frame(653, inputs.frames[0].rows) and limited.contract_frame(654, inputs.frames[1].rows), "continuous contract: capacity writer retains first frame")
	_check(not limited.contract_frame(655, inputs.frames[2].rows), "continuous contract: capacity exhaustion rejects continuation")
	var limited_footer: Dictionary = limited.finish_stream()
	_check(not limited_footer.complete and limited_footer.frames == 1, "continuous contract: capacity exhaustion closes incomplete without eviction")
	var byte_limited: RefCounted = ContinuousRecorder.new()
	byte_limited.max_bytes = 1
	_check(not byte_limited.open_stream(output_prefix + "-byte-limit.jsonl", "synthetic_contract", FIXTURE_HASH, 653), "continuous contract: byte limit rejects header write")
	_check(not bool(byte_limited.finish_stream().complete), "continuous contract: failed header cannot produce complete capture")
	var unavailable: RefCounted = ContinuousRecorder.new()
	_check(not unavailable.open_stream(output_prefix + "-absent-directory/stream.jsonl", "synthetic_contract", FIXTURE_HASH, 653), "continuous contract: unavailable output fails closed")
	_check(not bool(unavailable.finish_stream().complete), "continuous contract: unopened stream finalizes safely")
	_finish_validation(footer)


func _parked(inputs: Dictionary) -> void:
	var fixture: Dictionary = inputs.get("fixture", {})
	if not fixture.get("units") is Array or fixture.units.size() != 50:
		_capture_failed("parked validation requires prepared all50 fixture")
		return
	field = load("res://scenes/movement_stress.tscn").instantiate() as TestField
	field.set_script(ContinuousField)
	field.stress_layout = true
	field.stress_unit_count = 50
	field.fixture_units = fixture.units
	field.recorder = observation
	observation.field = field
	root.add_child(field)
	current_scene = field
	_check(observation.begin_continuous(), "continuous parked: all50 watched before first physics")
	await _frames(5)
	if failed_capture:
		return
	var accepted := true
	for index in field.units.size():
		var unit: RTSUnit = field.units[index]
		var goal: Array = fixture.units[index].parking_goal
		accepted = unit.move_to(Vector3(goal[0], goal[1], goal[2])) and accepted
	_check(accepted, "continuous parked: all original parking commands publicly accepted")
	await _frames(3)
	if failed_capture:
		return
	var stable := await _sample_stationary(field.units, 180)
	# The inherited sampler returns before the final tick's unit physics callbacks.
	await process_frame
	if failed_capture:
		return
	_check(stable.stable, "continuous parked: original180tick parked settling passes")
	var unchanged := true
	for index in field.units.size():
		var unit: RTSUnit = field.units[index]
		var position: Array = fixture.units[index].position
		unchanged = unchanged and unit.order_version == 1 and not unit.moving and unit.recovery_attempts == 0
		unchanged = unchanged and unit.global_position.distance_to(Vector3(position[0], position[1], position[2])) < 0.001
	_check(unchanged and observation.cluster_commands == 0, "continuous parked: no cluster command, live movement or recovery")
	# Synchronously remove the parked field BEFORE serialization/result assertions.
	field.free()
	field = null
	current_scene = null
	var footer: Dictionary = observation.finish_stream(true)
	_check(bool(footer.complete), "continuous parked: every frame/participant captured with closed delegates")
	_check(observation.connections.is_empty() and observation._units.is_empty(), "continuous parked: all listeners/units removed before final result")
	_finish_validation(footer)


func _capture_failed(message: String) -> void:
	failed_capture = true
	push_error("CONTINUOUS_CAPTURE_INCOMPLETE: " + message)
	# Exit the validation process; never leave a live simulation continuing silently.
	quit(2)


func _finish_validation(footer: Dictionary) -> void:
	if failed_capture:
		quit(2)
		return
	var file := FileAccess.open(output_prefix + "-result.json", FileAccess.WRITE)
	if file == null:
		_capture_failed("result output unavailable")
		return
	file.store_string(JSON.stringify({"mode": validation_mode, "checks": checks, "failures": failures,
		"footer": footer, "cluster_commands": observation.cluster_commands, "live_field": field != null}, "\t"))
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		_capture_failed("result write failed")
		return
	print("CONTINUOUS_CHECKS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _finalize() -> void:
	if is_instance_valid(field):
		field.free()
		field = null
	if observation != null and not observation.stream_finished and observation.stream_path != "":
		observation.finish_stream(false)
