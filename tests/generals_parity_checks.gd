extends SceneTree
## Compare selected port routines against a compiled original-source oracle.

var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: " + message)


func _run() -> void:
	var probe := EngineErrorProbe.new()
	OS.add_logger(probe)
	_test_native_routines()
	_test_rules()
	_test_program()
	_test_clock()
	await process_frame
	_check(root.get_children().is_empty(), "port checks release their runtime nodes")
	OS.remove_logger(probe)
	_check(probe.error_count() == 0, "port checks have no native errors or warnings")
	print("GENERALS_PARITY_CHECKS: %d checks, %d failures; native_errors=%d" % [checks, failures, probe.error_count()])
	quit(0 if failures == 0 else 1)


func _test_native_routines() -> void:
	var reference: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/generals_native_reference.json"))
	for case_index in reference.timing.size():
		var row: Dictionary = reference.timing[case_index]
		var inputs: Array = row.input
		var scheduler := GeneralsAITiming.new()
		scheduler.ready = bool(inputs[2])
		scheduler.timer = int(inputs[3])
		scheduler.delay = int(inputs[4])
		var observed := {"queues": 0, "processes": 0, "events": ""}
		var queue := func() -> void:
			observed.queues += 1
			observed.events += "Q"
		var process := func() -> void:
			observed.processes += 1
			observed.events += "P"
			scheduler.ready = false
			scheduler.timer = int(inputs[5])
			scheduler.delay = int(inputs[6])
		for step_index in int(inputs[7]):
			observed.events = ""
			if int(inputs[0]) == 0:
				scheduler.step_base(bool(inputs[1]), process)
			else:
				scheduler.step_team(bool(inputs[1]), queue, process)
			var expected: Array = row.expected[step_index]
			var events: String = observed.events if not str(observed.events).is_empty() else "-"
			_check(scheduler.ready == bool(expected[0]) and scheduler.timer == int(expected[1]) and scheduler.delay == int(expected[2]) and observed.queues == int(expected[3]) and observed.processes == int(expected[4]) and events == expected[5], "native scheduler case %d step %d" % [case_index, step_index])
	for row in reference.durations:
		_check(GeneralsAITiming.duration_frames(int(row.input)) == int(row.expected), "original float32 duration rounding at %s ms" % row.input)
	for case_index in reference.guards.size():
		var row: Dictionary = reference.guards[case_index]
		var v: Array = row.input
		var target := Vector3(v[4], v[6], v[5])
		var owner := Vector3(v[7], v[9], v[8])
		var actual := GeneralsAITiming.guard_should_exit(bool(v[0]), int(v[1]), int(v[2]), int(v[3]), target, owner, float(v[10]), float(v[11]))
		_check(actual == bool(row.expected), "original guard exit predicate %d" % case_index)


func _test_rules() -> void:
	var rules := GeneralsRules.new()
	_check(rules.load_database(), "original rule syntax loads inside Godot")
	_check(rules.source_count == 67, "67 original rule files retained")
	var count := 0
	for kind in rules.definitions:
		count += rules.records(kind).size()
	_check(count == 4330, "4,330 source definitions retained")
	_check(rules.declared_playable_factions().size() == 13, "all original PlayableSide declarations including Boss General remain intact; menu eligibility is separate")
	for spec in [["AmericaVehicleDozer", "1000", "5.0"], ["AmericaInfantryRanger", "225", "5.0"], ["AmericaBarracks", "600", "10.0"], ["AmericaCommandCenter", "2000", "45.0"], ["AmericaSupplyCenter", "2000", "10.0"]]:
		var object := rules.find_definition("Object", spec[0])
		_check(GeneralsRules.value(object, "BuildCost") == spec[1] and GeneralsRules.value(object, "BuildTime") == spec[2], "%s original cost and duration preserved" % spec[0])
	var upgrade := rules.find_definition("Upgrade", "Upgrade_AmericaAdvancedTraining")
	_check(GeneralsRules.value(upgrade, "BuildCost") == "1500" and GeneralsRules.value(upgrade, "BuildTime") == "60.0", "original Advanced Training research data")
	var science := rules.find_definition("Science", "SCIENCE_PaladinTank")
	_check(GeneralsRules.value(science, "PrerequisiteSciences") == "SCIENCE_AMERICA SCIENCE_Rank1" and GeneralsRules.value(science, "SciencePurchasePointCost") == "1", "original generals-point prerequisites retained")
	_check(rules.global_value("AIData", "RebuildDelayTimeSeconds") == "30", "empty active AIData retains original default rebuild delay")
	_check(rules.global_value("AIData", "GuardChaseUnitsDuration") == "10000", "original AI guard chase duration remains in milliseconds")
	var sides := GeneralsRules.blocks(rules.records("AIData")[0], "SideInfo")
	var america: Dictionary = sides[0]
	var skill_set := GeneralsRules.blocks(america, "SkillSet1")[0]
	_check(GeneralsRules.values(skill_set, "Science").size() == 7, "repeated Science fields retain original purchase order")
	var slots := rules.command_slots("AmericaDozerCommandSet")
	_check(slots.size() == 12 and slots[0].slot == 1 and slots[-1].slot == 14, "original non-contiguous dozer command slots retained")
	_check(GeneralsRules.value(slots[2].definition, "Object") == "AmericaBarracks", "original construction command resolves to its original object")
	var carrier := rules.find_definition("Object", "AmericaAircraftCarrier")
	var flight_decks := GeneralsRules.blocks(carrier, "Behavior").filter(func(block: Dictionary) -> bool: return str(block.value).begins_with("FlightDeckBehavior "))
	_check(flight_decks.size() == 1 and GeneralsRules.value(flight_decks[0], "NumRunways") == "2" and GeneralsRules.value(flight_decks[0], "PayloadTemplate") == "AmericaJetAircraftCarrierRaptor", "original carrier flight-deck behavior declaration survives import")
	_check(rules.find_definition("Object", "MissingObject").is_empty(), "unknown objects do not become fabricated defaults")


func _test_program() -> void:
	var program := GeneralsAIProgram.new()
	_check(program.load_program(), "original skirmish strategy data loads in Godot")
	_check(program.scripts.size() == 3957 and program.teams.size() == 1340 and program.players.size() == 14, "all original Zero Hour scripts, teams and player slots retained")
	var missing := program.missing_operations({}, {})
	_check(missing.conditions.size() == 33 and missing.actions.size() == 56, "all required original AI operations are explicit dependencies")
	var conditions := {"CONDITION_TRUE": func() -> bool: return true}
	var actions := {"NO_OP": func() -> void: pass}
	missing = program.missing_operations(conditions, actions)
	_check(not "CONDITION_TRUE" in missing.conditions and not "NO_OP" in missing.actions and "BUILD_TEAM" in missing.actions, "supporting simple operations does not silently mark team-building AI implemented")
	missing = program.missing_operations({"CONDITION_TRUE": 1}, {"NO_OP": Callable()})
	_check("CONDITION_TRUE" in missing.conditions and "NO_OP" in missing.actions, "invalid operation handlers remain unsupported")
	_check(not program.load_program("res://missing-original-program.json") and program.scripts.is_empty(), "missing original program cannot fall back to the prototype AI")


func _test_clock() -> void:
	var clock := GeneralsLogicClock.new()
	var frames: Array[int] = []
	clock.logic_tick.connect(func(frame: int) -> void: frames.append(frame))
	for _step in 60:
		clock.advance(1.0 / 60.0)
	_check(clock.frame == 30 and frames.size() == 30, "60 render/physics intervals produce 30 original logic ticks")
	clock.paused = true
	clock.advance(50)
	_check(clock.frame == 30, "Pause does not advance original AI time")
	clock.paused = false
	clock.advance(1.0 / 30.0)
	_check(clock.frame == 31, "Resume does not accrue paused wall time")
	clock.close()
	clock.advance(10)
	_check(clock.frame == 31 and clock.logic_tick.get_connections().is_empty(), "closed logic clock cannot emit late match ticks")
	clock.free()
	var closing := GeneralsLogicClock.new()
	closing.logic_tick.connect(func(_frame: int) -> void: closing.close())
	closing.advance(1)
	_check(closing.frame == 1 and closing.closed, "synchronous teardown cancels the remaining catch-up ticks")
	closing.free()
