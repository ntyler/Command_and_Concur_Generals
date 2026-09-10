extends "res://tests/supply_depot_checks.gd"
## Real paid Collector deployment with synchronous commands before the public
## deployed notification. Uses normal depot construction and six-second training.

const CALLBACK_RALLY := Vector3(-5, 0, 3)
const CALLBACK_MOVE := Vector3(-12, 0, -14)


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1280, 720)
	var logger := EngineErrorProbe.new()
	OS.add_logger(logger)
	for boundary in ["visibility", "rally"]:
		for command in ["stop", "move", "harvest"]:
			var before := checks
			var failed := failures
			await _deployment_override(boundary, command)
			print("AUTOMATIC_CALLBACK_CASE: %s/%s checks=%d failures=%d" % [boundary, command, checks - before, failures - failed])
	var before := checks
	var failed := failures
	await _visibility_source_loss()
	print("AUTOMATIC_CALLBACK_CASE: visibility/source_loss checks=%d failures=%d" % [checks - before, failures - failed])
	if is_instance_valid(field): field.queue_free()
	await _frames(6)
	_check(root.get_children().is_empty() and get_nodes_in_group("combat_projectiles").is_empty(), "automatic callback teardown removes fields, collectors and callbacks")
	OS.remove_logger(logger)
	_check(logger.error_count() == 0, "synchronous automatic deployment callbacks and teardown have no engine errors or warnings")
	print("AUTOMATIC_DEPLOYMENT_CALLBACK_CHECKS: %d checks, %d failures; native_errors=%d" % [checks, failures, logger.error_count()])
	quit(0 if failures == 0 else 1)


func _callback_command(unit_ref: WeakRef, command: String, observed: Dictionary) -> void:
	if observed["acted"]:
		return
	var truck := unit_ref.get_ref() as CollectorTruck
	if not is_instance_valid(truck) or not battle.contains_unit(truck):
		return
	observed["acted"] = true # Mark first, since replacement movement also signals.
	observed["events"].append("command")
	match command:
		"stop": observed["accepted"] = truck.stop()
		"move": observed["accepted"] = truck.move_to(CALLBACK_MOVE)
		"harvest": observed["accepted"] = _complete(battle.issue_harvest_for(1, [truck], _depot_player_cache(1)))
	observed["generation"] = truck.harvesting.generation
	observed["order"] = truck.order_version
	observed["position"] = truck.global_position
	observed["destination"] = truck.assigned_destination


func _deployment_override(boundary: String, command: String) -> void:
	await _fresh_depot()
	var building := await _depot()
	if building == null:
		return
	var producer := building.production
	_check(producer.set_rally(1, CALLBACK_RALLY).accepted, "%s/%s fixture accepts ordinary producer rally" % [boundary, command])
	var initial_units := battle.units.size()
	var balance := battle.credits.balance(1)
	var observed := {"acted": false, "accepted": false, "generation": -1, "order": -1, "events": [], "position": Vector3.ZERO, "destination": Vector3.ZERO, "truck": null}
	var attach_callback := func(node: Node) -> void:
		if not node is CollectorTruck:
			return
		var unit_ref: WeakRef = weakref(node)
		observed["truck"] = unit_ref
		if boundary == "visibility":
			node.visibility_changed.connect(func() -> void:
				var truck := unit_ref.get_ref() as CollectorTruck
				if is_instance_valid(truck) and truck.visible:
					_callback_command(unit_ref, command, observed)
			)
		else:
			node.movement_state_changed.connect(func(state: RTSUnit.MovementState) -> void:
				if state == RTSUnit.MovementState.TRAVELLING:
					_callback_command(unit_ref, command, observed)
			)
	battle.child_entered_tree.connect(attach_callback)
	var jobs: Array[int] = []
	producer.deployed.connect(func(job: int, _identity: int, _rally: bool) -> void:
		jobs.append(job)
		observed["events"].append("deployed")
	)
	var paid := producer.enqueue(1, COLLECTOR_RECIPE)
	_check(paid.accepted and battle.credits.balance(1) == balance - 200, "%s/%s fixture pays ordinary Collector price exactly once" % [boundary, command])
	if not await _until(func() -> bool: return not jobs.is_empty(), 7, "%s/%s completes real paid Collector training" % [boundary, command]):
		return
	battle.child_entered_tree.disconnect(attach_callback)
	var truck := (observed["truck"] as WeakRef).get_ref() as CollectorTruck if observed["truck"] != null else null
	_check(is_instance_valid(truck) and battle.contains_unit(truck), "%s/%s callback observes the actual live registered produced truck" % [boundary, command])
	if not is_instance_valid(truck):
		return
	_check(observed["acted"] and observed["accepted"] and observed["events"] == ["command", "deployed"], "%s/%s newer player command is accepted synchronously before deployed notification" % [boundary, command])
	_check(jobs == [paid.job_id] and producer.count() == 0 and battle.units.size() == initial_units + 1 and not producer.cancel(1, paid.job_id).accepted, "%s/%s callback neither repeats nor rolls back the committed deployment" % [boundary, command])
	_check(truck.harvesting.generation == observed["generation"] and truck.order_version == observed["order"] and not truck.deployment_collection_pending(), "%s/%s handoff cannot overwrite the callback's movement or harvest generation" % [boundary, command])
	if command == "harvest":
		_check(truck.harvesting.automatic and truck.harvesting.cache_node() == _depot_player_cache(1) and truck.harvesting.collection_origin == _depot_player_cache(1).global_position, "%s explicit harvesting retains its chosen cache and new collection area" % boundary)
	else:
		_check(not truck.harvesting.automatic and truck.harvesting.state == CollectorHarvest.State.IDLE and truck.assigned_destination == observed["destination"], "%s/%s owns the resulting idle harvest state and movement destination" % [boundary, command])
	await _frames(180)
	_check(truck.harvesting.generation == observed["generation"] and not truck.deployment_collection_pending() and jobs == [paid.job_id], "%s/%s override persists beyond the automatic retry interval without a duplicate deployment" % [boundary, command])
	if command == "stop":
		_check(not truck.moving and not truck.harvesting.automatic and truck.harvesting.state == CollectorHarvest.State.IDLE and truck.global_position.distance_to(observed["position"]) < 0.001, "%s Stop stays stopped without restarting exit clearance or harvesting" % boundary)
	elif command == "move":
		_check(not truck.harvesting.automatic and truck.assigned_destination == CALLBACK_MOVE and truck.global_position.distance_to(observed["position"]) > 0.5, "%s Move physically progresses toward the replacement destination without harvesting" % boundary)
	else:
		_check(truck.harvesting.automatic and truck.harvesting.cache_node() == _depot_player_cache(1) and truck.harvesting.collection_origin == _depot_player_cache(1).global_position, "%s explicit harvest remains assigned to its manually chosen cache" % boundary)
	_check(battle.credits.balance(1) == balance - 200, "%s/%s callback leaves the original deployment debit unchanged" % [boundary, command])


func _visibility_source_loss() -> void:
	await _fresh_depot()
	var building := await _depot()
	if building == null:
		return
	var producer := building.production
	var source_ref: WeakRef = weakref(building)
	var origin := building.global_position
	_check(producer.set_rally(1, CALLBACK_RALLY).accepted, "source-loss fixture accepts normal rally before paid production")
	var balance := battle.credits.balance(1)
	var observed := {"acted": false, "accepted": false, "truck": null}
	var attach_callback := func(node: Node) -> void:
		if not node is CollectorTruck:
			return
		var unit_ref: WeakRef = weakref(node)
		observed["truck"] = unit_ref
		node.visibility_changed.connect(func() -> void:
			var truck := unit_ref.get_ref() as CollectorTruck
			if observed["acted"] or not is_instance_valid(truck) or not truck.visible:
				return
			observed["acted"] = true
			var source := source_ref.get_ref() as RTSBuilding
			observed["accepted"] = is_instance_valid(source) and TeamRules.damage_target(battle, 2, source, 10000, battle.units[3]) > 0.0
		)
	battle.child_entered_tree.connect(attach_callback)
	var paid := producer.enqueue(1, COLLECTOR_RECIPE)
	_check(paid.accepted and battle.credits.balance(1) == balance - 200, "source-loss fixture pays ordinary Collector price once")
	if not await _until(func() -> bool: return observed["acted"], 7, "visible deployed truck synchronously destroys its source after production commit"):
		return
	battle.child_entered_tree.disconnect(attach_callback)
	var truck := (observed["truck"] as WeakRef).get_ref() as CollectorTruck
	_check(observed["accepted"] and battle.contains_unit(truck) and producer.count() == 0 and not producer.cancel(1, paid.job_id).accepted and battle.credits.balance(1) == balance - 200, "source destruction preserves the paid deployed collector without refund or duplicate job")
	_check(truck.deployment_collection_pending() and not truck.harvesting.automatic, "source destruction leaves the captured handoff pending until navigation and rally clearance")
	if not await _until(func() -> bool: return truck.harvesting.automatic, 12, "surviving truck completes synchronized navigation and begins automatic harvesting without its producer"):
		return
	_check(source_ref.get_ref() == null and not truck.navigation_suspended and truck.harvesting.collection_origin == origin and truck.harvesting.cache_node() == _depot_player_cache(), "automatic collection retains the destroyed depot's original local area and chooses a reachable cache")
	_check(battle.result == BaseAssaultField.Result.RUNNING and battle.credits.balance(1) == balance - 200, "depot loss neither ends the match nor changes the committed Collector payment")
