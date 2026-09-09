extends "res://tests/fixtures/fortification_harness.gd"
## Original1000-credit opening, ordinary paid Depot/Collector and finite deposits.
## Three walls plus one gate take total spending beyond starting funds. All work
## and movement are physical. Only this instance's first wave/sortie defer to600s;
## enemy economy, defenses, ground/air rules and gameplay values remain live.


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1280, 720)
	var logger := EngineErrorProbe.new()
	OS.add_logger(logger)
	await _earned_fortifications()
	if is_instance_valid(field): field.queue_free()
	await _frames(6)
	_check(root.get_children().is_empty() and get_nodes_in_group("combat_projectiles").is_empty(), "earned fortification teardown clears actors, gates, navigation and projectiles")
	OS.remove_logger(logger)
	_check(logger.error_count() == 0, "earned barrier construction and traversal produce no native errors")
	print("FORTIFICATION_INTEGRATION_CHECKS: %d checks, %d failures; native_errors=%d" % [checks, failures, logger.error_count()])
	quit(0 if failures == 0 else 1)


func _earned_fortifications() -> void:
	await _fresh_fort(1000, true, true)
	var builder := _player_builders()[0]
	var cache := _depot_player_cache()
	_check(cache != null and cache.remaining == 2000 and fort.enemy_controller.is_physics_processing() and fort.enemy_air_defense.is_physics_processing(), "earned opening retains real finite supplies and live enemy paid economy/AA")
	if cache == null: return
	var depot := await _power_build(builder, DEPOT, DEPOT_POINT)
	if depot == null: return
	_check(fort.credits.balance(1) == 700 and fort.valid_dropoff(depot, 1), "original builder pays300 and physically completes working Supply Depot")
	await physics_frame
	_check(builder.move_to(Vector3(-14.5, 0, -1.5)), "builder accepts ordinary Move clearing Collector production access")
	if not await _until(func() -> bool: return not builder.moving, 10, "builder physically clears Depot production face"): return
	depot.production.set_rally(1, Vector3(-5, 0, 2))
	_check(depot.production.enqueue(1, COLLECTOR_RECIPE).accepted and fort.credits.balance(1) == 500, "normal paid Collector production spends200 without grants")
	if not await _until(func() -> bool: return not depot.production.last_deployment.is_empty(), 7, "paid Collector completes ordinary training and safe deployment"): return
	var truck := _last_unit(depot.production) as CollectorTruck
	if truck == null: return
	if not await _until(func() -> bool: return not truck.moving, 12, "paid Collector physically reaches rally"): return
	var ledger := {"loaded": 0, "deposited": 0, "spent": 500, "conserved": true, "owner_correct": true}
	truck.harvesting.transferred.connect(func(transfer: HarvestTransfer) -> void:
		ledger.owner_correct = ledger.owner_correct and transfer.owner_id == 1 and transfer.collector_id == truck.unit_id
		if transfer.kind == HarvestTransfer.Kind.LOAD: ledger.loaded += transfer.amount
		else: ledger.deposited += transfer.amount
		ledger.conserved = ledger.conserved and cache.remaining + truck.harvesting.cargo + ledger.deposited == 2000
	)
	await physics_frame
	_check(truck.harvesting.issue(cache, true), "ordinary Collector begins finite loading and automatic real credit deposits")
	if not await _until(func() -> bool: return ledger.deposited >= 100, 35, "real loading and deposits earn the funds needed beyond original starting credits"): return
	var gate := await _fort_build(builder, GATE)
	if gate == null: return
	ledger.spent += GATE.credit_cost
	_check(_fort_gate_ready(gate, false) and gate.health.current == 700, "paid gate completes CLOSED with700HP and synchronized blocking")
	var left_wall := await _fort_build(builder, WALL, FORT_WALL_POINT)
	if left_wall == null: return
	ledger.spent += WALL.credit_cost
	var right_wall := await _fort_build(builder, WALL, Vector3(-8, 0, 15))
	if right_wall == null: return
	ledger.spent += WALL.credit_cost
	var rotated := await _fort_build(builder, WALL, Vector3(-25, 0, 17), 90)
	if rotated == null: return
	ledger.spent += WALL.credit_cost
	_check(left_wall.footprint == Vector2(4, 0.6) and rotated.footprint == Vector2(0.6, 4) and rotated.orientation_degrees == 90, "same paid builder completes both axis-aligned wall orientations")
	_check(is_equal_approx(left_wall.global_position.x + 2, gate.global_position.x - 4) and is_equal_approx(right_wall.global_position.x - 2, gate.global_position.x + 4), "ordinary paid placement joins wall ends exactly to both outer gate supports")
	_check(ledger.spent == 1050 and ledger.deposited >= 100 and fort.credits.balance(1) == 1000 + ledger.deposited - ledger.spent and ledger.conserved and ledger.owner_correct, "real earned deposits fund1050 total spending with exact owner wallet conservation")
	_check(_grid_is(1, 0, 0) and _grid_is(2, 10, 8) and fort.enemy_controller.accepted_jobs > 0, "completed barriers need no power and preserve live paid enemy production")
	await physics_frame
	_check(builder.move_to(Vector3(-22, 0, 20)), "builder accepts normal movement away from completed defensive line")
	if not await _until(func() -> bool: return not builder.moving, 12, "builder physically exits its final work position without trapping or teleport"): return
	await physics_frame
	_check(truck.move_to(Vector3(-14, 0, 20)), "earned Collector suspends harvesting through ordinary Move to approach closed defensive line")
	var closed_travel := {"crossed_line": false, "entered_door": false}
	if not await _until(func() -> bool:
		var point := truck.global_position
		if absf(point.z - 15) < 0.5:
			closed_travel.crossed_line = true
			if absf(point.x + 14) < 3: closed_travel.entered_door = true
		return not truck.moving,
		25, "earned Collector physically reaches outer gate approach using existing navigation"): return
	await physics_frame
	_check(closed_travel.crossed_line and not closed_travel.entered_door and not fort._nav_point(FORT_GATE_POINT) and not gate._door_collider.disabled, "actual Collector detours around the closed defensive line and never passes through its solid doorway")
	_check(_length(_path(Vector3(-14, 0, 20), Vector3(-14, 0, 9))) > 13, "closed barrier forces a genuine navigation detour beyond the direct eleven-unit crossing")
	_check(gate.request_gate(1, true).accepted, "owner opens completed earned gate through authoritative gate command")
	if not await _until(func() -> bool: return _fort_gate_ready(gate, true), 3, "earned gate waits for actual synchronized opening"): return
	await physics_frame
	_check(fort._nav_point(FORT_GATE_POINT) and truck.move_to(Vector3(-14, 0, 9)), "ready open doorway becomes an ordinary navigable Collector route")
	var crossed := {"door": false, "ground": true}
	for tick in 900:
		await _frames(1)
		var point := truck.global_position
		if absf(point.z - 15) < 0.5 and absf(point.x + 14) < 2.5: crossed.door = true
		crossed.ground = crossed.ground and absf(point.y) < 0.15
		if not truck.moving: break
	_check(crossed.door and crossed.ground and not truck.moving and truck.global_position.distance_to(Vector3(-14, 0, 9)) <= 0.6, "actual paid Collector physically crosses the open doorway at normal ground clearance and reaches goal")
	fort.selection.select_building(gate)
	fort.camera_rig.center_on_ground(Vector3(-14, 0, 15))
	await _frames(4)
	await _fort_capture("fortification_earned_collector_passage_1280x720")
	await physics_frame
	_check(gate.request_gate(1, false).accepted, "clear earned gate accepts explicit manual Close after Collector passage")
	if not await _until(func() -> bool: return _fort_gate_ready(gate, false), 3, "closed gate restores synchronized route protection"): return
	await physics_frame
	_check(not fort._nav_point(FORT_GATE_POINT) and not gate._door_collider.disabled and _length(_path(Vector3(-14, 0, 20), Vector3(-14, 0, 9))) > 13, "closed gate again blocks the direct ground route without changing Collector capabilities")
	var rifle: RTSUnit
	for actor in fort.units:
		if actor.owner_id == 1 and not actor is Bulldozer and not actor is CollectorTruck:
			rifle = actor
			break
	_check(rifle != null and fort.contains_unit(fort.enemy_helicopter), "existing original army and declared aircraft survive earned construction sequence")
	if rifle != null:
		fort.selection.replace_units([rifle])
		_check(fort.issue_move(Vector3(-12, 0, 6)).has_acceptance(), "original army retains ordinary controllable ground command dispatch")
	var economy := {"starting_funds": 1000, "loaded": ledger.loaded, "deposited": ledger.deposited, "spending": {"supply_depot": 300, "collector": 200, "walls": 300, "gate": 250}, "total_spent": ledger.spent, "final_balance": fort.credits.balance(1), "cargo": truck.harvesting.cargo, "remaining_supply": cache.remaining, "conserved": ledger.conserved, "owner_correct": ledger.owner_correct, "actual_open_doorway_crossed": crossed.door}
	print("FORTIFICATION_EARNED_LEDGER: " + JSON.stringify(economy))
	DirAccess.make_dir_recursive_absolute("res://validation-output/m16")
	var output := FileAccess.open("res://validation-output/m16/earned-ledger.json", FileAccess.WRITE)
	_check(output != null, "earned fortification saves exact paid construction and real deposit ledger")
	if output != null: output.store_string(JSON.stringify(economy, "\t"))
