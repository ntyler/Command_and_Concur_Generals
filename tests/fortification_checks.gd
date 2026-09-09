extends "res://tests/fixtures/fortification_harness.gd"
## Bounded isolated barrier authority, topology, actual traversal and lifecycle.
## The separate earned integration and paid-wave suite establish their economies.


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1280, 720)
	var logger := EngineErrorProbe.new()
	OS.add_logger(logger)
	var chosen := "all"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--fortification-case="):
			chosen = argument.trim_prefix("--fortification-case=")
	var cases := ["placement", "work", "gates", "late_close", "lifecycle"]
	_check(chosen == "all" or cases.has(chosen), "recognized fortification case")
	for case in cases:
		if chosen != "all" and chosen != case: continue
		var before := checks
		var failed := failures
		match case:
			"placement": await _fort_placement_checks()
			"work": await _fort_work_checks()
			"gates": await _fort_gate_checks()
			"late_close": await _fort_late_close_checks()
			"lifecycle": await _fort_lifecycle_checks()
		print("FORTIFICATION_CASE: %s checks=%d failures=%d" % [case, checks - before, failures - failed])
	if is_instance_valid(field): field.queue_free()
	await _frames(6)
	_check(root.get_children().is_empty() and get_nodes_in_group("combat_projectiles").is_empty(), "fortification teardown removes every field actor and old callback")
	OS.remove_logger(logger)
	_check(logger.error_count() == 0, "fortification physics and lifecycle have no native errors or warnings")
	print("FORTIFICATION_CHECKS: %d checks, %d failures; native_errors=%d" % [checks, failures, logger.error_count()])
	quit(0 if failures == 0 else 1)


func _fort_placement_checks() -> void:
	await _fresh_fort()
	_check(WALL.is_valid() and GATE.is_valid() and WALL.credit_cost == 100 and WALL.duration == 4 and WALL.maximum_health == 400 and WALL.footprint == Vector2(4, 0.6) and WALL.height == 2, "wall defaults are configurable exact 100 credits/four work seconds/400 HP/4 by 0.6 by 2")
	_check(GATE.credit_cost == 250 and GATE.duration == 8 and GATE.maximum_health == 700 and GATE.footprint == Vector2(8, 0.6) and GATE.gate_opening == 6 and GATE.height == 2, "gate defaults are configurable exact 250/eight/700 with eight span and six clear opening")
	_check(WALL.power_required == 0 and GATE.power_required == 0 and WALL.power_generated == 0 and GATE.power_generated == 0, "barriers never generate or require power")
	var builder := _player_builders()[0]
	fort.selection.select_clicked(builder, false)
	await physics_frame
	var balance := fort.credits.balance(1)
	var version := builder.order_version
	_check(not fort.construction.place(1, builder, GATE, FORT_GATE_POINT, 45).accepted and fort.credits.balance(1) == balance and builder.order_version == version, "unsupported orientation rejects without spending or replacing the builder order")
	var wall := await _fort_build(builder, WALL, FORT_WALL_POINT)
	if wall == null: return
	_check(fort.credits.balance(1) == balance - 100 and wall.production == null and wall.recipe == null and wall.footprint == Vector2(4, 0.6), "real paid wall preserves nonproduction and original orientation")
	fort.selection.select_clicked(builder, false)
	await physics_frame
	_check(fort.construction.validate(1, builder, GATE, FORT_GATE_POINT).is_empty(), "wall outer end can meet the gate support without a gap")
	_check(not fort.construction.validate(1, builder, WALL, FORT_WALL_POINT + Vector3.RIGHT).is_empty(), "actual barrier overlap remains rejected")
	_check(not fort.construction.validate(1, builder, WALL, fort.headquarters.global_position).is_empty(), "barrier cannot overlap unrelated headquarters")
	_check(not fort.construction.validate(1, builder, WALL, Vector3(-10, 0, -12)).is_empty(), "full thin barrier footprint still respects protected access corridors")
	var gate := await _fort_build(builder, GATE)
	if gate == null: return
	_check(gate.site.rectangle.position.x == wall.site.rectangle.end.x and gate.site.rectangle.get_center().y == wall.site.rectangle.get_center().y, "paid wall and gate footprints physically meet at the exact shared end")
	await physics_frame
	var seam := Vector3(wall.site.rectangle.end.x, 1, FORT_GATE_POINT.z)
	_check(not fort._nav_point(seam - Vector3.UP) and fort.fire_query.segment(fort.get_world_3d(), seam + Vector3.FORWARD * 2, seam + Vector3.BACK * 2).blocked, "aligned paid wall/gate join has no navigable or physical gap")
	_check(_fort_gate_ready(gate, false) and gate.health.current == 700 and gate.production == null, "normal completed paid gate starts closed and has no producer")
	fort.selection.select_clicked(builder, false)
	await physics_frame
	_check(not fort.construction.validate(1, builder, WALL, FORT_GATE_POINT).is_empty(), "wall cannot intrude into the gate's reserved doorway")
	var vertical := await _fort_build(builder, WALL, Vector3(-25, 0, 17), 90)
	if vertical == null: return
	_check(vertical.footprint == Vector2(0.6, 4) and vertical.orientation_degrees == 90 and vertical.site.orientation_degrees == 90, "paid vertical wall rotates its full physical and committed navigation footprint")
	_fort_precision_checks()
	_check(_grid_is(1, 0, 0), "three completed paid barriers preserve zero owner power demand")


func _fort_precision_checks() -> void:
	# Use the actual paid line and rotated wall together with scenario obstacles.
	# Record the unequal representations of nominally shared expanded edges.
	var rectangles: Array[Rect2] = fort.construction.navigation._submitted.duplicate()
	var original := rectangles.duplicate()
	var mesh := fort.create_navigation_mesh(rectangles)
	var bounds := fort.field_bounds.grow(-TestField.CLEARANCE)
	var raw: Array[Vector2] = []
	for rectangle in rectangles:
		var expanded := rectangle.grow(TestField.CLEARANCE).intersection(bounds)
		raw.append(expanded.position)
		raw.append(expanded.end)
	var shared := 0
	for axis in range(2):
		var edges: Array[float] = []
		for point in raw:
			if not edges.has(point[axis]): edges.append(point[axis])
		edges.sort()
		for index in range(1, edges.size()):
			var gap := edges[index] - edges[index - 1]
			if gap < 0.00001:
				shared += 1
				print("NAV_PRECISION: axis=%s a=%.12f b=%.12f gap=%.12f" % ["x" if axis == 0 else "z", edges[index - 1], edges[index], gap])
	_check(shared > 0 and rectangles == original, "actual mixed barrier fixture exposes unequal shared edges without changing input footprints")
	var smallest := INF
	var connections := 0
	var uses: Dictionary[Vector2i, int] = {}
	for index in range(mesh.get_polygon_count()):
		var polygon := mesh.get_polygon(index)
		for edge in range(polygon.size()):
			var a := polygon[edge]
			var b := polygon[(edge + 1) % polygon.size()]
			smallest = minf(smallest, mesh.vertices[a].distance_to(mesh.vertices[b]))
			var key := Vector2i(mini(a, b), maxi(a, b))
			uses[key] = uses.get(key, 0) + 1
	for count in uses.values():
		if count == 2: connections += 1
	_check(smallest > 0.001 and connections > 0 and uses.values().all(func(count: int) -> bool: return count <= 2), "paid mixed line has connected shared polygon edges with no degenerate strips or overoccupied edge")
	# A separately authored millimetre offset is far larger than float noise and
	# must survive partitioning; this does not claim a millimetre usable passage.
	var distinct: Array[Rect2] = [Rect2(-8, -2, 4, 0.6), Rect2(4, -1.999, 4, 0.6)]
	var distinct_mesh := fort.create_navigation_mesh(distinct)
	var first := distinct[0].grow(TestField.CLEARANCE).position.y
	var second := distinct[1].grow(TestField.CLEARANCE).position.y
	var distinct_vertices := Array(distinct_mesh.vertices)
	_check(first != second and distinct_vertices.any(func(point: Vector3) -> bool: return point.z == first) and distinct_vertices.any(func(point: Vector3) -> bool: return point.z == second), "distinct authored boundaries survive precision correction without blanket geometry rounding")


func _fort_work_checks() -> void:
	await _fresh_fort()
	var actor := _player_builders()[0]
	var wallet := fort.credits.balance(1)
	var result := await _builder_place(actor, WALL, FORT_WALL_POINT)
	var site := await _builder_arrival(result)
	if site == null: return
	await _frames(45)
	await physics_frame
	_check(_complete(fort.issue_stop()), "ordinary selected-builder Stop is accepted while working on a paid wall")
	await _frames(2)
	var paused := site.elapsed
	await _frames(30)
	_check(site.state == ConstructionSite.State.PAUSED and site.elapsed == paused and site.builder() == null and actor.assigned_site_id == 0, "Stop pauses real wall progress and releases its builder without spending again")
	fort.selection.select_clicked(actor, false)
	await physics_frame
	_check(fort.construction.assign_builder(actor, site.site_id), "same owned builder resumes the existing paid wall through ordinary assignment")
	await _until(func() -> bool: return site.state == ConstructionSite.State.CONSTRUCTING, 5, "resumed wall builder returns to a verified work position")
	await _frames(20)
	_check(site.elapsed > paused and site.elapsed < site.duration and fort.credits.balance(1) == wallet - 100, "resumed work retains exact previous progress and original single payment")
	await physics_frame
	_check(fort.construction.cancel(1, site.site_id).accepted and not fort.construction.cancel(1, site.site_id).accepted and fort.credits.balance(1) == wallet, "unfinished wall cancellation restores exactly its original 100 credits once")
	await _until(func() -> bool: return not fort.construction.navigation.blocked and fort.construction.unfinished_id == 0, 3, "cancelled wall cleanup restores the map and single-site slot")
	var gate := await _fort_build(actor, GATE, Vector3(-24, 0, 17), 90)
	if gate == null: return
	_check(gate.footprint == Vector2(0.6, 8) and gate.orientation_degrees == 90 and gate.site.elapsed == 8 and gate.physical_open == false, "paid 90-degree gate uses full rotated footprint and eight actual work seconds before closed completion")
	await physics_frame
	_check(gate.request_gate(1, true).accepted, "rotated completed gate uses the same authoritative opening command")
	await _until(func() -> bool: return _fort_gate_ready(gate, true), 3, "rotated gate opens synchronized six-unit doorway between retained supports")
	_check(fort._nav_point(gate.global_position) and not fort._nav_point(gate.global_position + Vector3.BACK * 3.5), "rotated gate center opens while rotated support stays blocked")
	await _fresh_fort()
	actor = _player_builders()[0]
	wallet = fort.credits.balance(1)
	result = await _builder_place(actor, WALL, FORT_WALL_POINT)
	site = await _builder_arrival(result)
	if site == null: return
	await _frames(20)
	await physics_frame
	var departure_progress := site.elapsed
	fort.remove_child(actor)
	await _frames(20)
	_check(site.state == ConstructionSite.State.PAUSED and site.elapsed == departure_progress and site.builder() == null and fort.credits.balance(1) == wallet - 100, "builder field departure pauses the committed wall without free work or automatic refund")
	actor.free()
	var departed_site := site.building()
	fort.remove_child(departed_site)
	await _until(func() -> bool: return not fort.construction.navigation.blocked and fort.construction.unfinished_id == 0, 3, "unfinished wall departure cancels and restores terrain through original site cleanup")
	_check(fort.credits.balance(1) == wallet and site.refunded and site.state == ConstructionSite.State.CANCELLED and fort._nav_point(FORT_WALL_POINT), "departed unfinished barrier returns original cost once and leaves usable ground")
	if is_instance_valid(departed_site): departed_site.free()


func _fort_gate_checks() -> void:
	await _fresh_fort()
	var gate := _fort_fixture(GATE)
	await _until(func() -> bool: return not fort.construction.navigation.blocked, 3, "closed gate fixture synchronizes authoritative footprint")
	await physics_frame
	var start := FORT_GATE_POINT + Vector3.FORWARD * 4
	var finish := FORT_GATE_POINT + Vector3.BACK * 4
	var closed_path := _path(start, finish)
	_check(not fort._nav_point(FORT_GATE_POINT) and _length(closed_path) > 10 and gate._door_collider.disabled == false, "closed gate obstructs actual ground path and retains solid doorway collider")
	for team in [1, 2]:
		var actor := _defense_mobile(start, team)
		actor.set_physics_process(true)
		await physics_frame
		_check(actor.move_to(finish), "closed gate allows ordinary detour command for team %d" % team)
		var crossing := {"outside": false, "inside": false}
		await _until(func() -> bool:
			if absf(actor.global_position.z - FORT_GATE_POINT.z) < 0.5:
				if absf(actor.global_position.x - FORT_GATE_POINT.x) < 4: crossing.inside = true
				else: crossing.outside = true
			return not actor.moving,
			12, "team %d physically detours around the closed gate" % team)
		_check(crossing.outside and not crossing.inside and actor.movement_state == RTSUnit.MovementState.ARRIVED, "closed gate blocks actual direct passage for team %d without trapping its detour" % team)
		actor.queue_free()
		await _frames(3)
	await physics_frame
	var before := fort.construction.navigation.generation
	_check(not gate.request_gate(2, true).accepted and gate.request_gate(1, false).accepted and fort.construction.navigation.generation == before, "foreign gate command rejects and repeated closed request causes no navigation work")
	_check(gate.request_gate(1, true).accepted and gate.navigation_pending and not gate.physical_open and not gate.effective_ready, "opening keeps the leaf solid and reports pending until synchronized navigation")
	_check(not gate.request_gate(1, false).accepted, "opposite rapid request cannot create a second transition")
	await _until(func() -> bool: return _fort_gate_ready(gate, true), 3, "opening publishes readiness only after actual doorway synchronization")
	await physics_frame
	_check(fort._nav_point(FORT_GATE_POINT) and absf(_length(_path(start, finish)) - 8) < 0.03 and gate._door_collider.disabled, "open gate offers actual direct route and physically disabled leaf")
	var builder := _player_builders()[0]
	fort.selection.select_clicked(builder, false)
	var balance := fort.credits.balance(1)
	var order := builder.order_version
	_check(not fort.construction.place(1, builder, WALL, FORT_GATE_POINT).accepted and fort.credits.balance(1) == balance and builder.order_version == order, "open gate still reserves its entire doorway against paid wall placement")
	var support := FORT_GATE_POINT + Vector3.LEFT * 3.5
	_check(not fort._nav_point(support) and gate.navigation_footprints().size() == 2, "both retained support footprints stay off the ground map")
	_check(fort.fire_query.segment(fort.get_world_3d(), start + Vector3.UP, finish + Vector3.UP).is_clear(), "shots pass through the real open doorway")
	_check(fort.fire_query.segment(fort.get_world_3d(), support + Vector3.FORWARD * 3 + Vector3.UP, support + Vector3.BACK * 3 + Vector3.UP).blocked, "open gate support still physically obstructs shots")
	for team in [1, 2]:
		var offset := Vector3.RIGHT * (1.5 if team == 2 else 0.0)
		var actor := _defense_mobile(start + offset, team)
		actor.set_physics_process(true)
		await physics_frame
		_check(actor.move_to(finish + offset), "open gate accepts ordinary ground traversal for team %d" % team)
		await _until(func() -> bool: return not actor.moving, 12, "team %d physically traverses the open doorway" % team)
		_check(actor.movement_state == RTSUnit.MovementState.ARRIVED and actor.global_position.distance_to(finish + offset) <= actor.stopping_distance + 0.02, "team %d arrives through the doorway with unchanged movement authority" % team)
		actor.queue_free()
		await _frames(3)
	await physics_frame
	_check(gate.request_gate(1, false).accepted and gate.physical_open and gate.navigation_pending, "close preparation preserves physical opening until final occupancy commitment")
	await _until(func() -> bool: return _fort_gate_ready(gate, false), 3, "clear close synchronizes the solid doorway")
	_check(not fort._nav_point(FORT_GATE_POINT) and not gate._door_collider.disabled and _grid_is(1, 0, 0), "closing restores blocking without a power prerequisite")


func _fort_late_close_checks() -> void:
	await _fresh_fort()
	var gate := _fort_fixture(GATE, FORT_GATE_POINT, 1, 0, true)
	await _until(func() -> bool: return not fort.construction.navigation.blocked, 3, "open late-close fixture synchronizes")
	var occupant := _defense_mobile(FORT_GATE_POINT, 2)
	await physics_frame
	var position := occupant.global_position
	var health := occupant.combat.health.current
	var generation := fort.construction.navigation.generation
	_check(not gate.request_gate(1, false).accepted and gate.gate_status() == "Gate obstructed" and gate.physical_open and generation == fort.construction.navigation.generation, "living enemy occupancy rejects close immediately with readable feedback and no navigation work")
	_check(occupant.global_position == position and occupant.combat.health.current == health, "occupied rejection neither displaces nor damages the ground unit")
	occupant.queue_free()
	await _frames(3)
	await physics_frame
	_check(gate.request_gate(1, false).accepted, "initially clear close starts one bounded preparation")
	# Explicit boundary fixture registers a living entrant after the click, before
	# the next serialized commit. This is not traversal or economy evidence.
	var late := _defense_mobile(FORT_GATE_POINT, 1)
	var late_position := late.global_position
	var late_health := late.combat.health.current
	await _until(func() -> bool: return _fort_gate_ready(gate, true), 3, "late entrant rejects actual close commitment and restores open navigation")
	_check(gate.gate_status() == "Gate obstructed" and late.global_position == late_position and late.combat.health.current == late_health and gate._door_collider.disabled, "late-close rollback leaves entrant and physical opening untouched")
	late.queue_free()
	await _frames(30)
	_check(_fort_gate_ready(gate, true), "occupied rejection never queues an automatic later closure")
	await physics_frame
	_check(gate.request_gate(1, false).accepted, "explicit later close is a fresh request")
	await _until(func() -> bool: return _fort_gate_ready(gate, false), 3, "explicit later clear close completes")
	var callback := {"issued": false, "accepted": false}
	gate.status_changed.connect(func() -> void:
		if gate.effective_ready and gate.physical_open and not callback.issued:
			callback.issued = true
			callback.accepted = gate.request_gate(1, false).accepted)
	await physics_frame
	_check(gate.request_gate(1, true).accepted, "callback fixture starts normal opening")
	await _until(func() -> bool: return callback.issued and _fort_gate_ready(gate, false), 4, "new close issued by synchronous ready callback remains authoritative")
	_check(callback.accepted and not gate.requested_open and not gate.navigation_pending, "obsolete opening completion cannot overwrite newer close")
	# Declared occupancy fixture uses the original paused AIR body at its unchanged
	# cruise height; this is a closure-domain assertion, not flight evidence.
	fort.enemy_helicopter.global_position = FORT_GATE_POINT + Vector3.UP * 8
	await physics_frame
	_check(not gate.closing_obstructed() and TeamRules.target_domain(fort.enemy_helicopter) == TeamRules.TargetDomain.AIR, "safely elevated AIR body over doorway is not a ground closing obstruction")
	_check(gate.request_gate(1, true).accepted, "ownership lifecycle fixture begins a normal opening")
	gate.owner_id = 2
	await _until(func() -> bool: return _fort_gate_ready(gate, false), 3, "ownership change invalidates old opening and synchronizes unchanged physical state")
	await physics_frame
	_check(not gate.request_gate(1, true).accepted and gate.request_gate(2, true).accepted, "old owner loses gate authority and current owner regains synchronized controls")
	await _until(func() -> bool: return _fort_gate_ready(gate, true), 3, "current owner opens its gate while aircraft remains above the doorway")
	await physics_frame
	_check(gate.request_gate(2, false).accepted, "safely elevated aircraft does not reject actual clear closing command")
	await _until(func() -> bool: return _fort_gate_ready(gate, false), 3, "gate closes below elevated aircraft without damage or displacement")
	_check(fort.enemy_helicopter.global_position == FORT_GATE_POINT + Vector3.UP * 8 and fort.enemy_helicopter.combat.health.current == fort.enemy_helicopter.maximum_health, "closing leaves elevated aircraft position and health unchanged")


func _fort_lifecycle_checks() -> void:
	await _fresh_fort()
	var gate := _fort_fixture(GATE)
	var neighbor := _fort_fixture(WALL, FORT_WALL_POINT)
	await _until(func() -> bool: return not fort.construction.navigation.blocked, 3, "adjacent lifecycle fixtures synchronize together")
	await physics_frame
	var wallet := fort.credits.balance(1)
	_check(gate.request_gate(1, true).accepted, "destruction fixture starts opening")
	_check(TeamRules.damage_target(fort, 2, gate, 700, fort.enemy_headquarters) == 700 and gate.destroyed and not gate.navigation_pending and not fort.contains_building(gate), "real lethal health damage retires the gate and its transition synchronously")
	await _until(func() -> bool: return not fort.construction.navigation.blocked, 3, "destroyed gate removes its physical and navigation doorway")
	_check(fort._nav_point(FORT_GATE_POINT) and not fort._nav_point(FORT_WALL_POINT) and fort.contains_building(neighbor), "destruction creates usable breach while neighboring intact wall remains blocked")
	_check(fort.credits.balance(1) == wallet and fort.result == BaseAssaultField.Result.RUNNING, "completed barrier destruction refunds nothing and does not finish the match")
	var reparented := _fort_fixture(GATE)
	await _until(func() -> bool: return not fort.construction.navigation.blocked, 3, "reparent gate fixture is synchronized")
	var container := Node3D.new()
	fort.add_child(container)
	await physics_frame
	_check(reparented.request_gate(1, true).accepted, "same-field reparent fixture starts opening")
	reparented.reparent(container)
	await _until(func() -> bool: return not fort.construction.navigation.blocked and not reparented.navigation_pending, 3, "same-field reparent cancels obsolete transition and synchronizes physical state")
	_check(fort.contains_building(reparented) and not reparented.physical_open and not fort._nav_point(FORT_GATE_POINT), "same-field identity and conservative closed footprint survive reparent")
	reparented.reparent(fort)
	await _frames(3)
	_check(_fort_gate_ready(reparented, false), "idle same-field reparent preserves effective readiness")
	reparented.reparent(container)
	container.remove_child(reparented)
	await _until(func() -> bool: return not fort.construction.navigation.blocked and fort._nav_point(FORT_GATE_POINT), 3, "field departure retires completed barrier navigation without refunds")
	reparented.free()
	_check(fort.credits.balance(1) == wallet, "completed departure cannot refund a fixture or player structure")
	var deleted := _fort_fixture(GATE)
	await _until(func() -> bool: return not fort.construction.navigation.blocked, 3, "pending-deletion fixture synchronizes closed gate")
	await physics_frame
	_check(deleted.request_gate(1, true).accepted, "deleted gate begins a normal pending opening")
	var deleted_ref: WeakRef = weakref(deleted)
	deleted.queue_free()
	await _until(func() -> bool: return deleted_ref.get_ref() == null and not fort.construction.navigation.blocked, 3, "deletion during navigation retires gate and pending callbacks")
	await _frames(30)
	await physics_frame
	_check(fort._nav_point(FORT_GATE_POINT) and fort._nav_point(FORT_GATE_POINT + Vector3.RIGHT * 3.5) and fort.fire_query.segment(fort.get_world_3d(), FORT_GATE_POINT + Vector3.UP + Vector3.FORWARD * 2, FORT_GATE_POINT + Vector3.UP + Vector3.BACK * 2).is_clear(), "stale callback cannot restore deleted doorway, support collision or navigation")
