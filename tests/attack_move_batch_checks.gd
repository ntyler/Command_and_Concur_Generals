extends "res://tests/base_assault_checks.gd"
## Actual field commands exercise partial acceptance and synchronous authority.


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var logger := EngineErrorProbe.new()
	OS.add_logger(logger)
	await _batch_mixed()
	await _batch_replacements()
	await _batch_departure()
	await _batch_pruning()
	await _batch_reservations()
	await _batch_combat_callbacks()
	if is_instance_valid(battle): battle.queue_free()
	await _frames(5)
	_check(root.get_children().is_empty(), "attack-move batch teardown removes every field and listener")
	OS.remove_logger(logger)
	_check(logger.error_count() == 0, "batch acceptance, callbacks and teardown have no native errors or warnings")
	print("ATTACK_MOVE_BATCH_CHECKS: %d checks, %d failures; native_errors=%d" % [checks, failures, logger.error_count()])
	quit(0 if failures == 0 else 1)


func _batch_fresh() -> void:
	await _fresh_assault(600)
	var map := battle.get_world_3d().get_navigation_map()
	await _until(func() -> bool:
		return NavigationServer3D.map_get_closest_point_owner(map, battle.units[0].global_position) == battle.navigation_region.get_rid() and NavigationServer3D.map_get_closest_point_owner(map, battle.collectors[0].global_position) == battle.navigation_region.get_rid(),
		1, "new batch fixture owns combat and collector navigation before commands")


func _batch_mixed() -> void:
	await _batch_fresh()
	var soldier := battle.units[0]
	var collector := battle.collectors[0]
	battle.selection.replace_units([collector])
	_check(battle.issue_harvest(battle.caches[0]).is_complete(), "collector begins real harvesting before mixed attack-move")
	if not await _until(func() -> bool: return collector.harvesting.cargo > 0, 20, "collector actually loads supplies before command isolation check"): return
	var cargo := collector.harvesting.cargo
	var harvest_generation := collector.harvesting.generation
	var movement_version := collector.order_version
	var cache := collector.harvesting.cache_node()
	battle.selection.replace_units([collector, soldier])
	var destination := Vector3(-12, 0, 18)
	var result := battle.issue_attack_move(destination)
	_check(result.acceptance == CommandBatchResult.Acceptance.PARTIAL and not result.superseded, "mixed attack-move reports partial unsuperseded acceptance")
	_check(result.intended_ids == [soldier.unit_id, collector.unit_id] and result.accepted_ids == [soldier.unit_id], "intended identities include collector while accepted identities include only combat unit")
	_check(result.assignments.size() == 1 and result.assignments.has(soldier.unit_id) and soldier.attack_move.final_slot == result.assignments[soldier.unit_id], "only participating combat unit receives a final slot")
	_check(collector.harvesting.cargo == cargo and collector.harvesting.generation == harvest_generation and collector.harvesting.cache_node() == cache and collector.order_version == movement_version, "mixed command preserves cargo, harvesting assignment and movement version")
	_check(soldier.attack_move.final_destination == destination and soldier.attack_move.parent_order_id == result.generation, "parent stores clicked destination and batch identity")
	var parent := soldier.attack_move.parent_order_id
	var slot := soldier.attack_move.final_slot
	var command := battle.last_command_result
	battle.selection.replace_units([soldier])
	for invalid in [Vector3(NAN, 0, 0), Vector3(1000, 0, 1000), battle.headquarters.global_position]:
		var rejected := battle.issue_attack_move(invalid)
		_check(rejected.acceptance == CommandBatchResult.Acceptance.NONE and soldier.attack_move.active and soldier.attack_move.parent_order_id == parent and soldier.attack_move.final_slot == slot and battle.last_command_result == command, "invalid attack-move destination preserves prior parent and diagnostic command snapshot")
	_check(not battle.issue_attack(battle.headquarters).has_acceptance() and soldier.attack_move.parent_order_id == parent and soldier.attack_move.active, "rejected friendly explicit Attack preserves active attack-move")
	battle.selection.replace_units([collector])
	var rejected := battle.issue_attack_move(destination)
	_check(rejected.acceptance == CommandBatchResult.Acceptance.NONE and rejected.intended_ids == [collector.unit_id] and rejected.assignments.is_empty(), "collector-only attack-move rejects with accurate identities")
	_check(collector.harvesting.generation == harvest_generation and collector.harvesting.cargo == cargo, "ineligible-only rejection leaves collector work intact")
	battle.selection.select_building(battle.headquarters)
	_check(not battle.issue_attack_move(destination).has_acceptance(), "building-only selection cannot receive attack-move")
	battle.selection.replace_units([soldier, battle.units[1]])
	var complete := battle.issue_attack_move(Vector3(-10, 0, 20))
	_check(complete.is_complete() and not complete.superseded and complete.assignments.size() == 2, "all-combat selection reports complete accepted batch with two slots")
	_check(complete.assignments[soldier.unit_id].distance_to(complete.assignments[battle.units[1].unit_id]) >= battle.destinations.slot_spacing - 0.001, "batch assignments are distinct at existing formation spacing")


func _batch_replacements() -> void:
	for command in ["move", "stop", "attack", "attack_move"]:
		await _batch_fresh()
		var first := battle.units[0]
		var second := battle.units[1]
		var enemy := battle.units[3]
		battle.selection.replace_units([first, second])
		var observed := {"once": false, "result": null}
		var replace := func(next: RTSUnit.MovementState) -> void:
			if next != RTSUnit.MovementState.TRAVELLING or observed["once"]: return
			observed["once"] = true
			match command:
				"move": observed["result"] = battle.issue_move(Vector3(-23, 0, 20))
				"stop": observed["result"] = battle.issue_stop()
				"attack": observed["result"] = battle.issue_attack(enemy)
				"attack_move": observed["result"] = battle.issue_attack_move(Vector3(-23, 0, 20))
		first.movement_state_changed.connect(replace)
		var older := battle.issue_attack_move(Vector3(-10, 0, 18))
		first.movement_state_changed.disconnect(replace)
		var newer := observed["result"] as CommandBatchResult
		_check(observed["once"] and newer != null and newer.is_complete() and not newer.superseded, "synchronous newer %s accepts the whole group" % command)
		_check(older.superseded and older.acceptance == CommandBatchResult.Acceptance.PARTIAL and older.accepted_ids == [first.unit_id], "older attack-move retains historical first acceptance and stops dispatch after %s replacement" % command)
		_check(battle.last_command_result == newer, "older dispatch cannot overwrite newer %s reporting" % command)
		await _frames(8)
		for unit in [first, second]:
			if command == "attack_move":
				_check(unit.attack_move.active and unit.attack_move.parent_order_id == newer.generation and unit.attack_move.final_destination == Vector3(-23, 0, 20), "replacement parent survives old return and deferred ticks")
			else:
				_check(not unit.attack_move.active, "%s cancels retained intent without delayed resume" % command)
				if command == "stop": _check(not unit.moving and unit.combat.target_actor() == null, "Stop remains authoritative after old dispatch returns")
				if command == "attack": _check(unit.combat.target_actor() == enemy, "explicit Attack remains authoritative after old dispatch returns")


func _batch_departure() -> void:
	await _batch_fresh()
	var first := battle.units[0]
	var second := battle.units[1]
	var first_id := first.unit_id
	var second_id := second.unit_id
	battle.selection.replace_units([first, second])
	var observed := {"once": false}
	var depart := func(next: RTSUnit.MovementState) -> void:
		if next == RTSUnit.MovementState.TRAVELLING and not observed["once"]:
			observed["once"] = true
			second.free()
	first.movement_state_changed.connect(depart)
	var result := battle.issue_attack_move(Vector3(-12, 0, 18))
	first.movement_state_changed.disconnect(depart)
	_check(observed["once"] and result.intended_ids == [first_id, second_id] and result.accepted_ids == [first_id] and result.acceptance == CommandBatchResult.Acceptance.PARTIAL and not result.superseded, "freed later member is skipped while historical intended identity survives")
	_check(result.assignments.size() == 1 and first.attack_move.active, "surviving accepted member retains only its original assigned slot")
	await _batch_fresh()
	first = battle.units[0]
	battle.selection.replace_units([first])
	observed = {"once": false}
	var retained := battle
	var detach_field := func(next: RTSUnit.MovementState) -> void:
		if next == RTSUnit.MovementState.TRAVELLING and not observed["once"]:
			observed["once"] = true
			root.remove_child(retained)
	first.movement_state_changed.connect(detach_field)
	result = battle.issue_attack_move(Vector3(-12, 0, 18))
	_check(observed["once"] and result.superseded and not first.attack_move.active, "field departure during dispatch clears parent and suppresses stale reporting")
	retained.free()
	await _frames(3)


func _batch_pruning() -> void:
	await _batch_fresh()
	var first := battle.units[0]
	var second := battle.units[1]
	battle.selection.replace_units([first, second])
	first.owner_id = 2
	var observed := {"once": false, "result": null}
	var prune := func(_count: int) -> void:
		if not observed["once"]:
			observed["once"] = true
			observed["result"] = battle.issue_stop()
	battle.selection.selection_changed.connect(prune)
	var old := battle.issue_attack_move(Vector3(-12, 0, 18))
	battle.selection.selection_changed.disconnect(prune)
	_check(observed["once"] and old.superseded and not old.has_acceptance(), "newer command accepted while selection prunes supersedes attack-move before dispatch")
	_check(battle.last_command_result == observed["result"] and not second.attack_move.active and second.combat.player_command == CombatController.PlayerCommand.STOP, "selection-query callback owns final command state and reporting")


func _batch_reservations() -> void:
	await _batch_fresh()
	var source := battle.units[0]
	var other := battle.units[1]
	battle.selection.replace_units([source])
	var result := battle.issue_attack_move(Vector3(12, 0, 0))
	_check(result.is_complete(), "reservation case accepts reachable cross-field attack-move")
	if not await _until(func() -> bool: return source.attack_move.target_actor() != null, 18, "reservation case reaches and automatically engages a real hostile"): return
	var retained := source.attack_move.final_slot
	battle.selection.replace_units([other])
	var move := battle.issue_move(retained)
	_check(move.is_complete() and move.assignments[other.unit_id].distance_to(retained) >= battle.destinations.slot_spacing - 0.001, "ordinary group Move reserves unselected attack-mover's final slot during engagement")
	_check(source.attack_move.final_slot == retained and source.attack_move.parent_order_id == result.generation, "selection and another unit's Move leave parent identity and final slot unchanged")


func _batch_combat_callbacks() -> void:
	for trigger in [CombatController.State.PURSUING, CombatController.State.ATTACKING]:
		for operation in ["move", "attack_move", "source_free", "target_free"]:
			await _batch_fresh()
			var source := battle.units[0]
			var target := battle.units[3]
			source.position = Vector3(10, 0, 16)
			target.position = Vector3(20, 0, 16)
			source.halt_motion()
			target.halt_motion()
			await _frames(3)
			battle.selection.replace_units([source])
			var observed := {"once": false, "coherent": false, "replacement": null}
			var source_ref: WeakRef = weakref(source)
			var target_ref: WeakRef = weakref(target)
			var listener := func(next: CombatController.State) -> void:
				if next != trigger or observed["once"]: return
				var actor := source_ref.get_ref() as RTSUnit
				var enemy := target_ref.get_ref() as RTSUnit
				observed["once"] = true
				observed["coherent"] = actor.attack_move.active and actor.attack_move.target_actor() == enemy and actor.combat.target_actor() == enemy
				match operation:
					"move": observed["replacement"] = battle.issue_move(Vector3(10, 0, 22))
					"attack_move": observed["replacement"] = battle.issue_attack_move(Vector3(10, 0, 22))
					"source_free": actor.free()
					"target_free": enemy.free()
			source.combat.state_changed.connect(listener)
			var original := battle.issue_attack_move(Vector3(26, 0, 20))
			_check(original.has_acceptance(), "combat callback case accepts original parent")
			await _until(func() -> bool: return observed["once"], 3, "%s callback executes actual %s during automatic engagement" % [CombatController.State.keys()[trigger], operation])
			if is_instance_valid(source): source.combat.state_changed.disconnect(listener)
			_check(observed["coherent"], "automatic combat callback observes coherent parent and temporary target")
			await _frames(8)
			if operation in ["move", "attack_move"]:
				var replacement := observed["replacement"] as CommandBatchResult
				_check(replacement != null and replacement.is_complete() and battle.last_command_result == replacement, "combat callback replacement retains authoritative batch reporting")
				if operation == "move":
					_check(not source.attack_move.active and source.combat.target_actor() == null, "combat callback's manual Move cannot be undone by obsolete automatic engagement")
				else:
					_check(source.attack_move.parent_order_id == replacement.generation and source.attack_move.final_destination == Vector3(10, 0, 22), "combat callback's new attack-move parent survives obsolete engagement return")
			elif operation == "source_free":
				_check(not is_instance_valid(source), "immediate attacker free from combat notification leaves no live actor to resume")
			else:
				_check(not is_instance_valid(target) and source.attack_move.active and source.attack_move.final_slot == original.assignments[source.unit_id] and source.moving, "immediate target free from combat notification resumes original accepted final leg")
