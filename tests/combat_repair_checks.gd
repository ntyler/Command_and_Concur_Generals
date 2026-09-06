extends "res://tests/combat_checks.gd"
## Corrective integration checks; run through tools/run-godot.ps1.

class StopConsumer extends Control:
	var consumed: int = 0
	func _gui_input(event: InputEvent) -> void:
		if event.is_action_pressed("unit_stop"):
			consumed += 1
			accept_event()


func _check(condition: bool, description: String) -> void:
	# Assertion failures and native engine errors are independent failure evidence.
	checks += 1
	if condition:
		print("PASS: ", description)
	else:
		failures += 1
		print("FAIL: ", description)


func _run() -> void:
	root.size = Vector2i(1280, 800)
	var logger := EngineErrorProbe.new()
	OS.add_logger(logger)
	var chosen := "all"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--repair-case="):
			chosen = argument.trim_prefix("--repair-case=")
	var cases := ["input", "pursuit", "accounting", "selection", "firing", "batch", "continuity"]
	_check(chosen == "all" or cases.has(chosen), "recognized corrective case")
	for repair_case in cases:
		if chosen != "all" and chosen != repair_case:
			continue
		var previous_checks := checks
		var previous_failures := failures
		match repair_case:
			"input": await _stop_input_checks()
			"pursuit": await _retarget_checks()
			"accounting": await _progress_accounting_checks()
			"selection": await _selection_entry_checks()
			"firing": await _destruction_checks()
			"batch": await _batch_checks()
			"continuity":
				await _rapid_replacement_checks()
				await _launch_ownership_checks()
		print("CORRECTIVE_CASE: %s; checks=%d; failures=%d" % [repair_case, checks - previous_checks, failures - previous_failures])
	if is_instance_valid(field):
		field.queue_free()
	await _frames(3)
	OS.remove_logger(logger)
	_check(logger.error_count() == 0, "no native errors or warnings through corrective teardown")
	print("COMBAT_REPAIR_CHECKS: %d checks, %d failures; native_errors=%d" % [checks, failures, logger.error_count()])
	quit(0 if failures == 0 else 1)


func _complete(result: CommandBatchResult) -> bool:
	return result.is_complete() and not result.superseded


func _expect_batch(result: CommandBatchResult, intended: Array[int], accepted: Array[int], outcome: CommandBatchResult.Acceptance, superseded: bool = false) -> void:
	_check(result.generation > 0 and result.intended_ids == intended, "batch identifies its generation and intended recipients")
	_check(result.accepted_ids == accepted and result.acceptance == outcome and result.superseded == superseded, "batch reports exact historical acceptance and supersession")
	var unique: Dictionary[int, bool] = {}
	for id in result.accepted_ids:
		unique[id] = true
	_check(unique.size() == result.accepted_ids.size(), "accepted recipient IDs contain no duplicates")


func _key_x() -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_X
	event.pressed = true
	root.push_input(event, true)
	event.pressed = false
	root.push_input(event, true)


func _stop_input_checks() -> void:
	var pair := await _pair(false, 20.0)
	var source := pair[0]
	var target := pair[1]
	field.selection.select_clicked(source, false)
	for hover in [true, false]:
		for pursuit in [false, true]:
			_check(_complete(field.issue_attack(target) if pursuit else field.issue_move(Vector3(-20, 0, 20))), "input fixture accepts a fresh order")
			await _frames(3)
			_check(source.moving and (not pursuit or source.combat.target_unit() == target), "input fixture has actual active movement/pursuit")
			_motion(field.info_panel.position + Vector2(10, 10) if hover else Vector2(600, 700))
			await _frames(1)
			_check(field.camera_rig.pointer_over_interface() == hover and root.gui_get_focus_owner() == null, "hover fixture has no keyboard focus owner")
			_key_x()
			await _frames(2)
			_check(not source.moving and source.combat.target_unit() == null, "viewport X stops movement/combat: hover=%s pursuit=%s" % [hover, pursuit])
	var version := source.combat.order_version
	await _click(field.info_panel.position + Vector2(10, 10), MOUSE_BUTTON_RIGHT)
	await _click(field.info_panel.position + Vector2(10, 10), MOUSE_BUTTON_LEFT)
	_check(source.combat.order_version == version and field.selection.selected_units() == [source], "panel still filters contextual mouse commands and selection")
	var consumer := StopConsumer.new()
	consumer.focus_mode = Control.FOCUS_ALL
	consumer.position = Vector2(500, 100)
	consumer.size = Vector2(160, 40)
	root.add_child(consumer)
	consumer.grab_focus()
	_check(_complete(field.issue_attack(target)), "focused-control fixture accepts pursuit")
	await _frames(3)
	version = source.combat.order_version
	_key_x()
	await _frames(2)
	_check(consumer.consumed == 1 and root.gui_get_focus_owner() == consumer, "focused UI control consumes X through GUI input")
	_check(source.moving and source.combat.target_unit() == target and source.combat.order_version == version, "consumed X does not also issue gameplay Stop")
	consumer.release_focus()
	consumer.queue_free()
	await _frames(2)


func _enclose(source: RTSUnit) -> Node3D:
	var enclosure := Node3D.new()
	field.add_child(enclosure)
	for direction in [Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK]:
		var wall := StaticBody3D.new()
		wall.position = source.global_position + direction * 0.65 + Vector3.UP
		wall.collision_layer = 4
		var collider := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(0.15, 2, 1.5) if direction.x != 0 else Vector3(1.5, 2, 0.15)
		collider.shape = shape
		wall.add_child(collider)
		enclosure.add_child(wall)
	return enclosure


func _retarget_checks() -> void:
	for mobile in [false, true]:
		var pair := await _pair(false, 20.0)
		var source := pair[0]
		var target := pair[1]
		var origin := source.global_position
		_enclose(source)
		await _frames(3)
		_check(source.maximum_recoveries == 8 and source.command_timeout == 90.0 and source.progress_window == 0.75, "enclosure retains unchanged gameplay budgets")
		if mobile:
			_check(target.move_to(Vector3(2, 0, -18)), "moving hostile uses ordinary navigation")
		_check(source.combat.issue_attack(target), "blocked attacker accepts attack")
		var max_stall := 0.0
		var max_attempts := 0
		var max_elapsed := 0.0
		var max_displacement := 0.0
		var max_updates := 0
		var histories_preserved := true
		var previous_updates := 0
		var previous_attempts := 0
		var previous_elapsed := 0.0
		var target_orders_accepted := true
		for frame in range(ceili(source.command_timeout * 60.0) + 2):
			await physics_frame
			max_stall = maxf(max_stall, source.stalled_for)
			max_attempts = maxi(max_attempts, source.recovery_attempts)
			max_elapsed = maxf(max_elapsed, source.combat.pursuit_elapsed)
			max_updates = maxi(max_updates, source.combat.pursuit_updates)
			max_displacement = maxf(max_displacement, source.global_position.distance_to(origin))
			if source.combat.target_unit() == null:
				break
			if mobile and not target.moving:
				var next_z := 16.0 if target.global_position.z < 0.0 else -18.0
				target_orders_accepted = target.move_to(Vector3(2, 0, next_z)) and target_orders_accepted
			if source.combat.pursuit_updates > previous_updates and previous_updates > 0:
				histories_preserved = histories_preserved and source.recovery_attempts >= previous_attempts and source.command_elapsed >= previous_elapsed
			previous_updates = source.combat.pursuit_updates
			previous_attempts = source.recovery_attempts
			previous_elapsed = source.command_elapsed
			if frame == 359:
				print("PURSUIT_AT_6S: mobile=%s updates=%d stall=%.3f recoveries=%d elapsed=%.3f displacement=%.4f" % [mobile, max_updates, max_stall, max_attempts, max_elapsed, max_displacement])
				_check(max_stall >= source.stuck_after and max_attempts > 0, "blocked attacker activates recovery by six seconds despite target refreshes")
		print("PURSUIT_BOUNDED: mobile=%s updates=%d recoveries=%d elapsed=%.3f displacement=%.4f reason=%s" % [mobile, max_updates, max_attempts, max_elapsed, max_displacement, source.combat.end_reason])
		_check(max_displacement < 0.3 and max_stall >= source.stuck_after, "attacker stays physically blocked while stalled detection activates")
		_check(target_orders_accepted and (not mobile or max_updates > 5), "moving target keeps navigating and causes repeated pursuit refreshes")
		_check(histories_preserved, "refreshes preserve accumulated movement time and recovery history")
		_check(max_attempts > 0 and max_attempts <= source.maximum_recoveries and max_elapsed <= source.command_timeout + 1.0 / 60.0, "pursuit recovery count and simulated duration remain bounded")
		_check(source.combat.target_unit() == null and source.combat.end_reason == "pursuit_budget_exhausted" and not source.moving and source.combat.weapon.shots_fired == 0, "exhausted pursuit stops safely without firing")
	# A progressing attacker must not inherit a permanent stall merely from retargeting.
	var pair := await _pair(false, 20.0)
	var source := pair[0]
	var target := pair[1]
	var origin := source.global_position
	target.move_to(Vector3(2, 0, -18))
	source.combat.issue_attack(target)
	await _frames(360)
	_check(source.global_position.distance_to(origin) > 10.0 and source.combat.pursuit_updates > 5 and source.movement_state != RTSUnit.MovementState.FAILED and source.combat.end_reason.is_empty(), "progressing attacker continues useful moving-target pursuit")
	# Actual player replacement while the movement system has an active recovery.
	pair = await _pair(false, 20.0)
	source = pair[0]
	target = pair[1]
	var enclosure := _enclose(source)
	await _frames(3)
	source.combat.issue_attack(target)
	for frame in range(300):
		await physics_frame
		if source.recovery_active:
			break
	_check(source.recovery_active and source.recovery_attempts > 0, "replacement fixture reaches actual recovery")
	field.selection.select_clicked(source, false)
	var replacement := Vector3(-24, 0, 16)
	_check(_complete(field.issue_move(replacement)), "new player move accepted during recovery")
	var version := source.order_version
	_check(source.combat.target_unit() == null and source.combat.pursuit_elapsed == 0.0 and source.combat.pursuit_recoveries == 0 and source.recovery_attempts == 0 and source.stalled_for == 0.0 and source._progress_elapsed == 0.0 and not source.recovery_active, "real replacement clears obsolete pursuit and recovery history")
	enclosure.queue_free()
	await _frames(180)
	_check(source.order_version == version and source.assigned_destination == replacement and source.combat.target_unit() == null and source.global_position.distance_to(replacement) <= source.stopping_distance + 0.01, "replacement remains authoritative and arrives after enclosure removal")
	# Stop, target invalidation and replacement attacks each clear an active detour.
	for replacement_kind in ["stop", "invalid", "attack"]:
		pair = await _pair(false, 20.0)
		source = pair[0]
		target = pair[1]
		_enclose(source)
		await _frames(3)
		source.combat.issue_attack(target)
		for frame in range(300):
			await physics_frame
			if source.recovery_active: break
		_check(source.recovery_active, replacement_kind + ": cleanup fixture has an active recovery")
		var next_target := field.units[7]
		match replacement_kind:
			"stop": _check(source.stop(), "Stop accepted during recovery")
			"invalid": target.owner_id = source.owner_id
			"attack": _check(source.combat.issue_attack(next_target), "new attack accepted during recovery")
		version = source.combat.order_version
		_check(not source.recovery_active and source.recovery_target == Vector3.ZERO and source.recovery_attempts == 0 and source.stalled_for == 0.0 and source.combat.pursuit_elapsed == 0.0 and source.combat.pursuit_recoveries == 0, replacement_kind + ": cleanup clears obsolete history and temporary waypoint")
		await _frames(3)
		_check(source.combat.order_version == version and (source.combat.target_unit() == next_target if replacement_kind == "attack" else source.combat.target_unit() == null), replacement_kind + ": old pursuit cannot resume on subsequent ticks")


func _progress_accounting_checks() -> void:
	var pair := await _pair(false, 20.0)
	var source := pair[0]
	# A controlled sampler fixture, like movement_repair_checks: actual path
	# queries/recovery, with physics paused to isolate which motion earns credit.
	source.set_physics_process(false)
	source.combat.set_physics_process(false)
	source.crowd_enabled = false
	var origin := source.global_position
	var target := origin + Vector3.RIGHT * 10.0
	for oscillate in [false, true]:
		source.global_position = origin
		source.move_to(target, true)
		var version := source.order_version
		var accepted := true
		for sample in range(12):
			if oscillate:
				source.global_position = origin + Vector3.BACK * (0.2 if sample % 2 == 0 else 0.0)
			accepted = source.retarget_pursuit(target + Vector3.RIGHT * (sample % 3)) and accepted
			source.command_elapsed += 0.25
			source._update_progress(0.25)
		_check(accepted and source.order_version == version and source.command_elapsed == 3.0 and source.stalled_for >= source.stuck_after and source.recovery_attempts > 0, "retargeting earns no artificial progress from target changes or oscillation: oscillate=" + str(oscillate))
	# Slow positive movement must accumulate; rebasing must not discard credit.
	source.global_position = origin
	source.move_to(target, true)
	for sample in range(3):
		source.global_position += Vector3.RIGHT * 0.12
		source.retarget_pursuit(target + Vector3.RIGHT * (sample % 2))
		source.command_elapsed += source.progress_window
		source._update_progress(source.progress_window)
	_check(source.stalled_for == 0.0 and source.recovery_attempts == 0 and source.movement_state == RTSUnit.MovementState.TRAVELLING, "small real advances accumulate across target rebasing without false recovery")
	# An actual local detour survives a destination update without extending expiry.
	source.global_position = origin
	source.move_to(target, true)
	source._recover()
	var waypoint := source.recovery_target
	var attempts := source.recovery_attempts
	var last_attempt := source.last_recovery_time
	source._recovery_elapsed = 0.5 # Observe a partly elapsed temporary waypoint.
	var new_target := target + Vector3.RIGHT * 2.0
	_check(source.recovery_active and waypoint != source.assigned_destination, "open fixture creates a real temporary detour")
	_check(source.retarget_pursuit(new_target), "active-detour retarget accepted")
	_check(source.recovery_active and source.recovery_target == waypoint and source.agent.target_position == waypoint and source._recovery_elapsed == 0.5 and source.recovery_attempts == attempts and source.last_recovery_time == last_attempt and is_equal_approx(source.agent.avoidance_priority, source.recovery_priority), "refresh retains detour, expiry, attempt history and avoidance priority")
	source.set_physics_process(true)
	await _frames(180)
	_check(not source.recovery_active and source.agent.target_position == new_target and source.assigned_destination == new_target, "temporary recovery ends toward the refreshed final destination")


func _selection_entry_checks() -> void:
	for outer in ["move", "attack", "stop"]:
		var pair := await _pair(false, 20.0)
		var source := pair[0]
		var target := pair[1]
		var other := field.units[1]
		field.selection.select_clicked(source, false)
		field.selection.select_clicked(other, true)
		other.owner_id = 2
		var observation := {"once": false, "replacement": null, "version": -1, "slots": PackedVector3Array(), "status": ""}
		var replace := func(_count: int) -> void:
			if observation["once"]:
				return
			observation["once"] = true
			observation["replacement"] = field.issue_move(Vector3(-24, 0, 16)) if outer == "attack" else field.issue_attack(target)
			observation["version"] = source.combat.order_version
			observation["slots"] = field.last_command_slots.duplicate()
			observation["status"] = field.status_label.text
		field.selection.selection_changed.connect(replace)
		var result: CommandBatchResult
		match outer:
			"move": result = field.issue_move(Vector3(-20, 0, 20))
			"attack": result = field.issue_attack(target)
			"stop": result = field.issue_stop()
		field.selection.selection_changed.disconnect(replace)
		_check(observation["once"] and _complete(observation["replacement"]), outer + ": pruning callback accepts replacement")
		_check(source.combat.order_version == observation["version"] and field.last_command_slots == observation["slots"] and field.status_label.text == observation["status"], outer + ": obsolete entry does not overwrite orders or reporting")
		_expect_batch(result, [source.unit_id], [], CommandBatchResult.Acceptance.NONE, true)
		_check(result.generation < observation["replacement"].generation and field.last_command_result == observation["replacement"], "entry supersession preserves newer shared batch result")
		await _frames(3)
		_check(source.combat.order_version == observation["version"] and source.moving and (source.combat.target_unit() == null if outer == "attack" else source.combat.target_unit() == target), outer + ": replacement remains active on subsequent physics ticks")


func _destruction_checks() -> void:
	for controller_path in [false, true]:
		for reaction in ["source_free", "source_death", "source_queue", "source_detach", "target_detach"]:
			var pair := await _pair()
			var source := pair[0]
			var target := pair[1]
			var health := target.combat.health
			var emitter := source.combat.weapon
			_align(source, target)
			var events := {"damage": 0, "fires": 0, "committed": false}
			emitter.fired.connect(func(_target: RTSUnit, _projectile: GuidedProjectile) -> void: events["fires"] += 1)
			var damage_callback := func(_amount: float, _source: Node) -> void:
				events["damage"] += 1
				events["committed"] = emitter.shots_fired == 1 and emitter.cooldown_remaining == 0.75
				match reaction:
					"source_free": source.free()
					"source_death": source.combat.health.apply_damage(1000.0)
					"source_queue": source.queue_free()
					"source_detach": field.remove_child(source)
					"target_detach": field.remove_child(target)
			health.damaged.connect(damage_callback, CONNECT_ONE_SHOT)
			if controller_path:
				_check(source.combat.issue_attack(target), "controller accepts attack before destruction callback")
				await _frames(3)
			else:
				source.combat.set_physics_process(false)
				await physics_frame
				var accepted := emitter.try_fire(target)
				_check(accepted, "committed hitscan returns true after " + reaction)
			_check(health.current == 88.0 and events["damage"] == 1 and events["committed"], "single damage and cooldown commitment: %s controller=%s" % [reaction, controller_path])
			_check(events["fires"] == (0 if reaction == "source_free" else 1), "surviving emitter keeps its notification; freed emitter is not required to emit")
			if reaction == "source_detach":
				source.free()
			elif reaction == "target_detach":
				target.free()


func _batch_checks() -> void:
	for kind in ["attack", "move", "stop"]:
		for deletion in [false, true]:
			var pair := await _pair(false, 20.0)
			var first := pair[0]
			var other := field.units[1]
			var target := pair[1]
			var ids: Array[int] = [first.unit_id, other.unit_id]
			if kind == "stop":
				first.combat.issue_attack(target)
				other.combat.issue_attack(target)
			field.selection.select_clicked(first, false)
			field.selection.select_clicked(other, true)
			var before := first.combat.order_version
			var other_version := other.combat.order_version
			var depart := func(_state: int) -> void:
				if deletion:
					other.free()
				else:
					field.remove_child(other)
			if kind == "move":
				first.movement_state_changed.connect(depart, CONNECT_ONE_SHOT)
			else:
				first.combat.state_changed.connect(depart, CONNECT_ONE_SHOT)
			var result: CommandBatchResult = _dispatch(kind, target)
			_check(first.combat.order_version == before + 1 and (first.combat.target_unit() == target if kind == "attack" else first.combat.target_unit() == null), kind + ": first member actually accepts its new order")
			_check(first.moving if kind == "move" else (not first.moving), kind + ": actual movement agrees with accepted order")
			_expect_batch(result, ids, [ids[0]], CommandBatchResult.Acceptance.PARTIAL)
			_check(field.last_command_result == result, "partial dispatch publishes its own accurate result")
			if kind == "move":
				_check(result.assignments.size() == 1 and result.assignments[ids[0]] == first.assigned_destination and not result.assignments.has(ids[1]), "partial movement captures only accepted destinations by stable ID")
			if not deletion:
				_check(other.combat.order_version == other_version + 1, "departure cleanup is not misreported as acceptance of the batch")
				other.free()
	# Complete acceptance and pre-dispatch rejection, including unchanged assignments.
	var pair := await _pair(false, 20.0)
	var first := pair[0]
	var other := field.units[1]
	field.selection.select_clicked(first, false)
	field.selection.select_clicked(other, true)
	var ids: Array[int] = [first.unit_id, other.unit_id]
	for kind in ["attack", "move", "stop"]:
		var versions: Array[int] = [first.combat.order_version, other.combat.order_version]
		var result: CommandBatchResult = _dispatch(kind, pair[1])
		_expect_batch(result, ids, ids, CommandBatchResult.Acceptance.COMPLETE)
		_check(first.combat.order_version == versions[0] + 1 and other.combat.order_version == versions[1] + 1, "complete " + kind + " proves a fresh accepted order per intended unit")
	var versions: Array[int] = [first.combat.order_version, other.combat.order_version]
	var slots := field.last_command_slots.duplicate()
	var rejected: CommandBatchResult = field.issue_attack(other)
	_expect_batch(rejected, ids, [], CommandBatchResult.Acceptance.NONE)
	_check(first.combat.order_version == versions[0] and other.combat.order_version == versions[1] and field.last_command_slots == slots, "pre-dispatch rejection leaves all previous orders and slots intact")
	# A member accepts A, then replaces it with B during A's notification.
	pair = await _pair(false, 20.0)
	first = pair[0]
	other = field.units[1]
	ids = [first.unit_id, other.unit_id]
	field.selection.select_clicked(first, false)
	field.selection.select_clicked(other, true)
	var observation := {"newer": null}
	first.combat.state_changed.connect(func(_state: int) -> void: observation["newer"] = field.issue_move(Vector3(-20, 0, 20)), CONNECT_ONE_SHOT)
	var historical: CommandBatchResult = field.issue_attack(pair[1])
	_expect_batch(historical, ids, [ids[0]], CommandBatchResult.Acceptance.PARTIAL, true)
	_check(_complete(observation["newer"]) and first.moving and other.moving and first.combat.target_unit() == null and other.combat.target_unit() == null, "nested movement supersedes attack without rollback")
	_check(historical.generation < observation["newer"].generation and field.last_command_result == observation["newer"], "historical acceptance does not replace newer reporting")
	# A later recipient's callback frees an earlier accepted recipient. Godot locks
	# a node during its own call/signal; this uses a valid immediate-free boundary.
	for kind in ["attack", "move", "stop"]:
		pair = await _pair(false, 20.0)
		first = pair[0]
		other = field.units[1]
		ids = [first.unit_id, other.unit_id]
		if kind == "stop":
			first.combat.issue_attack(pair[1])
			other.combat.issue_attack(pair[1])
		field.selection.select_clicked(first, false)
		field.selection.select_clicked(other, true)
		if kind == "move":
			other.movement_state_changed.connect(func(_state: int) -> void: first.free(), CONNECT_ONE_SHOT)
		else:
			other.combat.state_changed.connect(func(_state: int) -> void: first.free(), CONNECT_ONE_SHOT)
		var result: CommandBatchResult = _dispatch(kind, pair[1])
		_check(not is_instance_valid(first), kind + ": accepted recipient was immediately freed")
		_expect_batch(result, ids, ids, CommandBatchResult.Acceptance.COMPLETE)
		if kind == "move":
			_check(result.assignments.size() == 2 and result.assignments.has(ids[0]) and result.assignments[ids[1]] == other.assigned_destination, "captured movement assignments survive deletion of an accepted member")


func _dispatch(kind: String, target: RTSUnit) -> CommandBatchResult:
	match kind:
		"attack": return field.issue_attack(target)
		"move": return field.issue_move(Vector3(-20, 0, 20))
		_: return field.issue_stop()


func _rapid_replacement_checks() -> void:
	var pair := await _pair()
	var source := pair[0]
	var target := pair[1]
	_align(source, target)
	await physics_frame
	_check(source.combat.weapon.try_fire(target), "initial real hitscan shot accepted")
	field.selection.select_clicked(source, false)
	var bypassed := false
	var all_accepted := true
	for cycle in range(100):
		all_accepted = _complete(field.issue_move(Vector3(-24, 0, 16))) and all_accepted
		all_accepted = _complete(field.issue_stop()) and all_accepted
		all_accepted = _complete(field.issue_attack(target)) and all_accepted
		bypassed = source.combat.weapon.try_fire(target) or bypassed
	_check(all_accepted and not bypassed and source.combat.weapon.shots_fired == 1 and target.combat.health.current == 88.0 and source.combat.weapon.cooldown_remaining == 0.75, "100 accepted move/Stop/attack cycles cannot bypass committed cooldown")


func _launch_ownership_checks() -> void:
	for reaction in ["source_team", "source_unregistered"]:
		var pair := await _pair(true, 8.0)
		var source := pair[0]
		var target := pair[1]
		var projectile := await _launch(source, target)
		if projectile == null:
			continue
		var resolved := {"count": 0, "damage": 0.0}
		projectile.resolved.connect(func(damage: float) -> void:
			resolved["count"] += 1
			resolved["damage"] += damage)
		if reaction == "source_team": source.owner_id = target.owner_id
		else: field.unregister_unit(source)
		await _frames(90)
		_check(resolved["count"] == 1 and resolved["damage"] == 32.0 and target.combat.health.current == 68.0, "projectile preserves launch ownership and survives " + reaction)
