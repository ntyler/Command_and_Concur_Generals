extends "res://tests/combat_repair_checks.gd"
## Observable production/viewport integration. All waits have fixed simulation
## budgets; inherited wall-clock watchdog plus the external wrapper bound runs.

class RefusingField extends ProductionField:
	var refuse_registration: bool = false
	var refuse_rally: bool = false
	func register_unit(unit: RTSUnit) -> void:
		if not refuse_registration:
			super.register_unit(unit)
	func order_deployed_unit(unit: RTSUnit, destination: Vector3) -> bool:
		return false if refuse_rally else super.order_deployed_unit(unit, destination)

class SharedExitBuilding extends RTSBuilding:
	# Isolated same-tick admission fixture: two queues propose the same clear exit.
	func exit_position() -> Vector3:
		return Vector3(-13.7, 0, 6.5)

var base: ProductionField


func _run() -> void:
	root.size = Vector2i(1280, 800)
	var logger := EngineErrorProbe.new()
	OS.add_logger(logger)
	for case in ["credits", "queue", "spawn", "rally", "ui", "lifecycle", "combat"]:
		var before := checks
		var failed := failures
		match case:
			"credits": await _credit_checks()
			"queue": await _queue_checks()
			"spawn": await _spawn_checks()
			"rally": await _rally_checks()
			"ui": await _production_ui_checks()
			"lifecycle": await _production_lifecycle_checks()
			"combat": await _produced_combat_checks()
		print("PRODUCTION_CASE: %s; checks=%d failures=%d" % [case, checks - before, failures - failed])
	if is_instance_valid(base):
		base.queue_free()
	await _frames(4)
	_check(root.get_children().size() == 0, "production tests leave no field, detached units or UI nodes")
	OS.remove_logger(logger)
	_check(logger.error_count() == 0, "no native errors or warnings through production and teardown")
	print("PRODUCTION_CHECKS: %d checks, %d failures; native_errors=%d" % [checks, failures, logger.error_count()])
	quit(0 if failures == 0 else 1)


func _fresh_production(special: bool = false, starting: int = 1000) -> void:
	if is_instance_valid(base):
		base.queue_free()
		await _frames(3)
	base = RefusingField.new() if special else load("res://scenes/production_test.tscn").instantiate() as ProductionField
	base.starting_credits = starting
	field = base
	root.add_child(base)
	current_scene = base
	base.camera_rig.edge_scrolling_enabled = false
	await _frames(5)
	_check(base.credits.balance(1) == starting and base.barracks.production.count() == 0, "fresh field restores configured funds and empty queue")
	_check(NavigationServer3D.map_get_iteration_id(base.get_world_3d().get_navigation_map()) > 0, "production navigation synchronized before test commands")


func _extra_barracks(owner_id: int, point: Vector3) -> RTSBuilding:
	# Isolated sharing/lifecycle fixture, not player construction. These API-only
	# producers never train/spawn; playable fixed geometry is tested separately.
	var building := RTSBuilding.new()
	building.owner_id = owner_id
	building.position = point
	base.add_child(building)
	base.register_building(building)
	building.set_physics_process(false)
	return building


func _credit_checks() -> void:
	await _fresh_production()
	var b := base.barracks
	var p := b.production
	_check(b.queue_capacity == 5 and b.spawn_retry_interval == 0.25 and b.recipe.credit_cost == 100 and b.recipe.training_duration == 5.0, "exact configurable production defaults")
	var first := p.enqueue(1, b.recipe)
	_check(first.accepted and first.job_id > 0 and base.credits.balance(1) == 900 and p.count() == 1, "accepted job has stable ID and deducts exactly 100")
	_check(not p.enqueue(2, b.recipe).accepted and base.credits.balance(2) == 1000, "unauthorized owner cannot spend through producer")
	_check(not p.enqueue(1, null).accepted and not p.enqueue(1, ProductionDefinition.new()).accepted, "null and unsupported definitions rejected")
	var original := b.recipe
	for invalid in ["cost", "zero", "negative", "nan", "infinity", "scene", "empty_scene", "wrong_root"]:
		var recipe := original.duplicate() as ProductionDefinition
		match invalid:
			"cost": recipe.credit_cost = -1
			"zero": recipe.training_duration = 0
			"negative": recipe.training_duration = -1
			"nan": recipe.training_duration = NAN
			"infinity": recipe.training_duration = INF
			"scene": recipe.unit_scene = null
			"empty_scene": recipe.unit_scene = PackedScene.new()
			"wrong_root":
				var wrong := Node3D.new()
				recipe.unit_scene = PackedScene.new()
				recipe.unit_scene.pack(wrong)
				wrong.free()
		b.recipe = recipe
		_check(not p.enqueue(1, recipe).accepted and p.count() == 1 and base.credits.balance(1) == 900, "invalid %s rejected without queue/wallet mutation" % invalid)
	b.recipe = original
	for i in 4:
		_check(p.enqueue(1, original).accepted, "queue accepts remaining capacity %d" % i)
	var full := p.enqueue(1, original)
	_check(not full.accepted and full.reason == "Queue full" and p.count() == 5 and base.credits.balance(1) == 500, "capacity includes active job; full rejection spends nothing")
	var second := _extra_barracks(1, Vector3(-10, 0, -17))
	_check(second.recipe == original and second.production.count() == 0, "shared recipe does not share mutable queue")
	for i in 5:
		_check(second.production.enqueue(1, original).accepted, "second producer spends the same owner wallet %d" % i)
	_check(base.credits.balance(1) == 0 and base.credits.balance(2) == 1000, "two barracks cannot overspend or touch other owner's funds")
	var third := _extra_barracks(1, Vector3(0, 0, -17))
	var poor := third.production.enqueue(1, third.recipe)
	_check(not poor.accepted and poor.reason == "Insufficient credits" and third.production.count() == 0, "insufficient funds rejected by API on a nonfull producer")
	var enemy := _extra_barracks(2, Vector3(10, 0, -17))
	_check(enemy.production.enqueue(2, enemy.recipe).accepted and base.credits.balance(2) == 900 and base.credits.balance(1) == 0, "different owner trains from independent balance")
	_check(not enemy.production.cancel(1, enemy.production.jobs()[0]["id"]).accepted, "foreign cancellation cannot refund another player's job")


func _queue_checks() -> void:
	await _fresh_production()
	var b := base.barracks
	var p := b.production
	var first := p.enqueue(1, b.recipe)
	var second := p.enqueue(1, b.recipe)
	var third := p.enqueue(1, b.recipe)
	await _frames(60)
	var rows := p.jobs()
	_check(rows[0]["elapsed"] > 0.95 and rows[0]["elapsed"] < 1.05 and rows[1]["elapsed"] == 0 and rows[2]["elapsed"] == 0, "one second advances only FIFO head using simulation time")
	_check(p.cancel(1, second.job_id).accepted and base.credits.balance(1) == 800, "waiting cancellation returns exact payment")
	_check(not p.cancel(1, second.job_id).accepted and base.credits.balance(1) == 800, "repeated waiting cancellation does not refund twice")
	_check(p.cancel(1, first.job_id).accepted and p.jobs()[0]["id"] == third.job_id and p.progress() == 0.0 and base.credits.balance(1) == 900, "active cancellation refunds and next job starts at zero")
	var original := b.recipe
	b.recipe = original.duplicate() as ProductionDefinition
	# Modify the SAME resource used to accept the next job, then restore it.
	var mutable := b.recipe
	var captured := p.enqueue(1, mutable)
	mutable.credit_cost = 275
	mutable.training_duration = 25.0
	_check(p.jobs()[-1]["paid"] == 100 and p.jobs()[-1]["duration"] == 5.0, "mutating accepted recipe resource cannot change job's price or time")
	_check(p.cancel(1, captured.job_id).accepted and base.credits.balance(1) == 900, "refund remains original after mutation of shared recipe")
	b.recipe = original.duplicate() as ProductionDefinition
	b.recipe.credit_cost = 350
	b.recipe.training_duration = 30
	_check(p.jobs()[0]["paid"] == 100 and p.jobs()[0]["duration"] == 5.0, "accepted job captures original paid cost and duration")
	_check(p.cancel(1, third.job_id).accepted and base.credits.balance(1) == 1000, "cancellation uses captured cost after recipe replacement")
	b.recipe = original
	var ids: Array[int] = []
	var times: Array[int] = []
	var began := Engine.get_physics_frames()
	p.deployed.connect(func(id: int, _unit: int, _rally: bool) -> void:
		ids.append(id)
		times.append(Engine.get_physics_frames() - began))
	first = p.enqueue(1, original)
	second = p.enqueue(1, original)
	var monotonic := true
	var previous := 0.0
	for i in 294:
		await _frames(1)
		monotonic = monotonic and p.progress() >= previous
		previous = p.progress()
	_check(ids.is_empty() and base.units.size() == 6 and monotonic and p.progress() > 0.97, "no early deployment through 4.9 seconds; progress is monotonic")
	await _frames(12)
	_check(ids == [first.job_id] and times[0] >= 300 and times[0] <= 302 and p.count() == 1, "first deployment occurs at configured five-second boundary")
	await _frames(305)
	_check(ids == [first.job_id, second.job_id] and times[1] - times[0] >= 300 and times[1] - times[0] <= 302, "second job completes FIFO after its own full training duration")
	_check(base.units.size() == 8 and base.credits.balance(1) == 800 and p.count() == 0, "two completions create exactly two paid units with no extra charge")
	_check(not p.cancel(1, first.job_id).accepted and base.credits.balance(1) == 800, "deployed job is no longer refundable")


func _exit_blockers() -> Array[RTSUnit]:
	# Explicit fixture grid covers the whole exit region, not an expected-value
	# reimplementation of the production candidate search.
	var blockers: Array[RTSUnit] = []
	for x in [-13.7, -12.6]:
		for z in [5.4, 6.5, 7.6]:
			var unit := RTSUnit.new()
			unit.unit_id = 100 + blockers.size()
			unit.position = Vector3(x, 0, z)
			base.add_child(unit)
			base.register_unit(unit)
			blockers.append(unit)
	return blockers


func _spawn_checks() -> void:
	await _fresh_production()
	var p := base.barracks.production
	var blockers := _exit_blockers()
	await _frames(3)
	var first := p.enqueue(1, base.barracks.recipe)
	var next := p.enqueue(1, base.barracks.recipe)
	var completed: Array[int] = []
	p.deployed.connect(func(id: int, _unit: int, _rally: bool) -> void: completed.append(id))
	await _frames(390)
	_check(completed.is_empty() and p.count() == 2 and p.progress() == 1.0 and p.message == "Exit blocked", "fully occupied exit holds completed head at 100 percent")
	_check(p.jobs()[1]["elapsed"] == 0 and base.credits.balance(1) == 800 and base.units.size() == 12, "blocked retries neither train following job nor spend nor duplicate")
	base.selection.select_building(base.barracks)
	var waiting: Array[int] = []
	for i in 3:
		waiting.append(p.enqueue(1, base.barracks.recipe).job_id)
	_check(p.count() == 5 and not p.enqueue(1, base.barracks.recipe).accepted and base.production_panel.feedback.text.contains("Queue full") and base.production_panel.feedback.text.contains("Exit blocked"), "completed blocked head counts toward full capacity and UI reports both conditions")
	for id in waiting:
		p.cancel(1, id)
	var spawn_observation := {"clear": false, "near": false}
	p.deployed.connect(func(_id: int, identity: int, _rally: bool) -> void:
		for deployed_unit in base.units:
			if deployed_unit.unit_id != identity:
				continue
			var capsule := deployed_unit.get_child(0) as CollisionShape3D
			var query := PhysicsShapeQueryParameters3D.new()
			query.shape = capsule.shape
			query.transform = capsule.global_transform
			query.collision_mask = 2 | 4 | 8
			query.exclude = [deployed_unit.get_rid()]
			spawn_observation["clear"] = base.get_world_3d().direct_space_state.intersect_shape(query).is_empty()
			spawn_observation["near"] = deployed_unit.global_position.distance_to(Vector3(-13.7, 0, 6.5)) < 1.6)
	# Clear just one slot: the other five live occupants must remain untouched.
	blockers[1].queue_free()
	await _frames(20)
	_check(completed == [first.job_id] and p.count() == 1 and base.units.size() == 12 and spawn_observation["clear"] and spawn_observation["near"], "clearing one exit slot deploys the same job once, locally, with actual capsule clear of remaining occupants")
	var unit := base.units[-1]
	_check(unit is RTSUnit and unit.unit_id > 6 and unit.owner_id == 1 and base.contains_unit(unit) and unit.combat.health.current == 100 and unit.combat.weapon.definition == CombatField.RIFLE, "deployment initializes normal registered Rifle identity, ownership, health and weapon")
	_check(unit.agent != null and unit.collision_layer == 2 and unit.collision_mask == 4, "produced Rifle retains normal navigation and collision policy")
	_check(p.cancel(1, next.job_id).accepted and base.credits.balance(1) == 900, "following job can be cancelled after blocked head deploys")
	for i in blockers.size():
		if i != 1:
			_check(blockers[i].global_position == Vector3(-13.7 if i < 3 else -12.6, 0, [5.4, 6.5, 7.6][i % 3]), "spawning does not move parked exit occupant %d" % i)
	await _fresh_production()
	p = base.barracks.production
	blockers = _exit_blockers()
	await _frames(3)
	first = p.enqueue(1, base.barracks.recipe)
	await _frames(320)
	_check(p.cancel(1, first.job_id).accepted and p.count() == 0 and base.credits.balance(1) == 1000, "completed blocked job refunds in full")
	_check(not p.cancel(1, first.job_id).accepted and base.credits.balance(1) == 1000, "completed blocked job refund happens once")
	await _fresh_production(true)
	var refusing := base as RefusingField
	refusing.refuse_registration = true
	p = base.barracks.production
	first = p.enqueue(1, base.barracks.recipe)
	await _frames(320)
	_check(base.units.size() == 6 and p.count() == 1 and p.progress() == 1.0 and p.message.begins_with("Deployment unavailable"), "registration failure retains paid job and removes unregistered orphan")
	_check(base.get_tree().get_nodes_in_group("controllable_units").size() == 6 and base.credits.balance(1) == 900, "failed creation leaves no hidden unit or extra charge")
	refusing.refuse_registration = false
	await _frames(20)
	_check(p.count() == 0 and base.units.size() == 7 and p.last_deployment["job_id"] == first.job_id, "registration recovery deploys original job once")
	await _spawn_geometry_checks()
	await _concurrent_spawn_checks()


func _concurrent_spawn_checks() -> void:
	await _fresh_production()
	var extra := SharedExitBuilding.new()
	extra.position = Vector3(-10, 0, -17)
	base.add_child(extra)
	base.register_building(extra)
	var p := base.barracks.production
	var q := extra.production
	var arrivals: Array[Vector3] = []
	var record := func(_job: int, identity: int, _rally: bool) -> void:
		for unit in base.units:
			if unit.unit_id == identity:
				arrivals.append(unit.global_position)
	p.deployed.connect(record)
	q.deployed.connect(record)
	p.enqueue(1, base.barracks.recipe)
	q.enqueue(1, extra.recipe)
	await _frames(306)
	_check(arrivals.size() == 2 and arrivals[0].distance_to(arrivals[1]) >= 0.86 and base.units.size() == 8 and base.credits.balance(1) == 800, "simultaneous producers sharing an exit deploy two distinct nonoverlapping paid units")
	_check(p.count() == 0 and q.count() == 0, "same-frame spawn admission completes each independent queue exactly once")


func _spawn_geometry_checks() -> void:
	await _fresh_production()
	var b := base.barracks
	# Full-volume collision proof: a low world box covers the exit, on otherwise
	# valid navigation. Navigation projection alone would allow these positions.
	base._box(Vector3(3.5, 0.3, 4), Vector3(-13, 0.15, 6.5), Color.GRAY, 4 | 8)
	await _frames(3)
	await physics_frame
	_check(base.find_spawn(b).is_empty(), "world shape on valid navigation rejects every spawn capsule")
	var original := b.position
	b.position = Vector3(28, 0, 0)
	await physics_frame
	_check(base.find_spawn(b).is_empty(), "out-of-bounds exit cannot project back inside map")
	b.position = base.headquarters.position - Vector3(4.3, 0, 0)
	await physics_frame
	_check(base.find_spawn(b).is_empty(), "exit inside headquarters footprint cannot project through it")
	b.position = original
	await physics_frame
	var trace := base.fire_query.segment(base.get_world_3d(), Vector3(-26, 0.9, -7), Vector3(-15, 0.9, -7))
	_check(trace.blocked and trace.collider_id == base.headquarters.get_instance_id(), "headquarters actual geometry blocks weapon query")
	trace = base.fire_query.segment(base.get_world_3d(), Vector3(-23, 0.9, 6.5), Vector3(-12, 0.9, 6.5))
	_check(trace.blocked and trace.collider_id == b.get_instance_id(), "barracks actual geometry blocks weapon query")


func _rally_checks() -> void:
	await _fresh_production()
	var b := base.barracks
	var p := b.production
	var selected := base.units[0]
	base.selection.select_clicked(selected, false)
	_check(base.issue_move(Vector3(-23, 0, 18)).is_complete(), "existing selected army has an ordinary move order")
	var order := selected.order_version
	var first := p.enqueue(1, b.recipe)
	var rally := Vector3(-9, 0, 1)
	_check(p.set_rally(1, rally).accepted, "valid rally accepted during training")
	for bad in [Vector3(100, 0, 0), b.global_position, Vector3(NAN, 0, 0), Vector3(0, 5, 0)]:
		_check(not p.set_rally(1, bad).accepted and p.rally_point == rally, "invalid rally preserves previous point")
	_check(not p.set_rally(2, Vector3(-8, 0, 2)).accepted and p.rally_point == rally, "unauthorized rally rejected")
	await _frames(306)
	var unit := base.units[-1]
	_check(p.last_deployment["job_id"] == first.job_id and p.last_deployment["rally"] == rally and unit.assigned_destination == rally and unit.moving, "current rally captured at deployment and sent through mover")
	_check(base.selection.selected_units() == [selected] and selected.order_version == order and selected.assigned_destination == Vector3(-23, 0, 18), "production preserves existing army selection and orders")
	var new_rally := Vector3(-8, 0, 10)
	_check(p.set_rally(1, new_rally).accepted and unit.assigned_destination == rally, "later rally change does not redirect deployed unit")
	p.enqueue(1, b.recipe)
	await _frames(306)
	_check(base.units[-1].assigned_destination == new_rally and unit.assigned_destination == rally, "changed rally applies only to future deployment")
	base.selection.select_clicked(unit, false)
	_check(base.issue_move(Vector3(-24, 0, 6.5)).is_complete(), "produced Rifle accepts selected movement around barracks")
	var safe := true
	var reached := false
	for i in 600:
		await _frames(1)
		safe = safe and not Rect2(-21, 4, 6, 5).grow(0.42).has_point(Vector2(unit.global_position.x, unit.global_position.z))
		if not unit.moving:
			reached = unit.global_position.distance_to(unit.assigned_destination) < 0.25
			break
	_check(safe and reached, "produced unit reaches far side while its capsule stays outside fixed footprint")
	await _fresh_production(true)
	(base as RefusingField).refuse_rally = true
	p = base.barracks.production
	first = p.enqueue(1, base.barracks.recipe)
	await _frames(320)
	unit = base.units[-1]
	_check(p.count() == 0 and base.units.size() == 7 and not unit.moving and unit.velocity.length() < 0.001 and not p.last_deployment["rally_accepted"], "rejected rally leaves committed produced unit safely idle")
	_check(base.credits.balance(1) == 900 and not p.cancel(1, first.job_id).accepted and p.message.contains("rally rejected"), "rally failure reports issue without refund or duplication")


func _production_ui_checks() -> void:
	await _fresh_production()
	var b := base.barracks
	var p := b.production
	var ui := base.production_panel
	var unit := base.units[0]
	await _click(_screen(unit), MOUSE_BUTTON_LEFT)
	_check(base.selection.selected_units() == [unit], "viewport click still selects an ordinary friendly unit")
	await _click(_world_screen(b.global_position + Vector3.UP), MOUSE_BUTTON_LEFT, true)
	_check(base.selection.selected_building() == b and base.selection.selected_units().is_empty() and b.selection_indicator.visible and b.rally_indicator.visible, "Shift-click building selects it alone with footprint and rally feedback")
	_check(ui.train_button.visible and ui.credit_label.text.contains("1000") and ui.identity_label.text.contains("Barracks"), "selected barracks panel shows identity, funds and training control")
	var rally := p.rally_point
	await _click(ui.train_button.get_global_rect().get_center(), MOUSE_BUTTON_LEFT)
	_check(p.count() == 1 and base.credits.balance(1) == 900, "one viewport Train activation creates one paid job")
	_check(base.selection.selected_building() == b and base.selection.selected_units().is_empty() and p.rally_point == rally, "GUI Train does not leak into world selection or rally")
	var id: int = p.jobs()[0]["id"]
	_check(ui.cancel_buttons.has(id), "queue UI exposes the accepted stable job identity")
	await _click(ui.cancel_buttons[id].get_global_rect().get_center(), MOUSE_BUTTON_LEFT)
	_check(p.count() == 0 and base.credits.balance(1) == 1000 and base.selection.selected_building() == b, "viewport Cancel refunds once without selecting world")
	await _click(_world_screen(Vector3(-10, 0, 1)), MOUSE_BUTTON_RIGHT)
	_check(p.rally_point.distance_to(Vector3(-10, 0, 1)) < 0.03 and b.rally_indicator.global_position.distance_to(p.rally_point + Vector3.UP * 0.1) < 0.001, "ground right-click sets validated rally and moves visible marker")
	rally = p.rally_point
	await _click(_screen(base.units[3]), MOUSE_BUTTON_RIGHT)
	_check(p.rally_point == rally and base.units[3].combat.health.current == 100, "right-click hostile while barracks selected causes no attack or rally")
	await _click(_world_screen(base.headquarters.global_position + Vector3.UP * 2), MOUSE_BUTTON_LEFT)
	_check(base.selection.selected_building() == base.headquarters and not ui.train_button.visible and ui.identity_label.text.contains("Headquarters"), "viewport headquarters selection has no working Train button")
	await _click(_world_screen(Vector3(-9, 0, 16)), MOUSE_BUTTON_LEFT)
	_check(base.selection.selected_building() == null, "normal empty-ground click clears building selection")
	base.selection.select_building(b)
	await _click(_screen(unit), MOUSE_BUTTON_LEFT, true)
	_check(base.selection.selected_building() == null and base.selection.selected_units() == [unit] and not b.rally_indicator.visible, "Shift-selecting unit clears building and rally display")
	base.selection.select_building(b)
	var anchor := _screen(unit)
	await _drag(anchor - Vector2(14, 14), anchor + Vector2(14, 14), true)
	_check(base.selection.selected_building() == null and base.selection.selected_units() == [unit], "drag selects only units and clears building selection")
	var enemy := _extra_barracks(2, Vector3(10, 0, 16))
	await _frames(3)
	await _click(_world_screen(enemy.global_position + Vector3.UP), MOUSE_BUTTON_LEFT)
	_check(base.selection.selected_building() == null and base.selection.selected_units().is_empty(), "hostile building cannot enter local selection")
	base.selection.select_clicked(unit, false)
	_check(base.issue_move(Vector3(-26, 0, 18)).is_complete(), "production UI Stop fixture has active selected movement")
	var queued := p.enqueue(1, b.recipe)
	_motion(ui.position + Vector2(10, 10))
	await _frames(1)
	_key_x()
	await _frames(2)
	_check(not unit.moving and p.count() == 1 and p.jobs()[0]["id"] == queued.job_id, "viewport X over passive production UI stops units without cancelling jobs")
	var consumer := StopConsumer.new()
	consumer.focus_mode = Control.FOCUS_ALL
	consumer.position = Vector2(600, 100)
	consumer.size = Vector2(180, 40)
	root.add_child(consumer)
	consumer.grab_focus()
	_check(base.issue_move(Vector3(-24, 0, 19)).is_complete(), "focused-control fixture has fresh movement")
	var version := unit.order_version
	_key_x()
	await _frames(2)
	_check(consumer.consumed == 1 and unit.moving and unit.order_version == version and p.count() == 1, "focused consumer retains X without gameplay or production side effect")
	consumer.release_focus()
	consumer.queue_free()
	await _frames(2)
	for i in 8:
		base.selection.select_building(b)
		base.selection.select_clicked(unit, false)
	_check(p.changed.get_connections().is_empty(), "switching away disconnects observed queue every time")
	base.selection.select_building(b)
	_check(p.changed.get_connections().size() == 1, "switching back attaches exactly one queue listener")
	await _capture("production_panel")
	# Stale panel still has a visible control before physics pruning. Its API must
	# check fresh ownership even before that control's disabled state catches up.
	b.owner_id = 2
	await _click(ui.train_button.get_global_rect().get_center(), MOUSE_BUTTON_LEFT)
	_check(p.count() == 1 and base.credits.balance(1) == 900 and base.credits.balance(2) == 1000, "stale unauthorized panel activation cannot spend either wallet")
	b.owner_id = 1
	base.selection.select_building(b)
	b.queue_free()
	await _click(ui.train_button.get_global_rect().get_center(), MOUSE_BUTTON_LEFT)
	await _frames(2)
	_check(not p.is_available() and p.count() == 0 and base.credits.balance(1) == 1000, "stale departed producer control cannot enqueue; departure refunds outstanding job")
	await _fresh_production(false, 100)
	b = base.barracks
	p = b.production
	ui = base.production_panel
	base.selection.select_building(b)
	await _click(ui.train_button.get_global_rect().get_center(), MOUSE_BUTTON_LEFT)
	_check(base.credits.balance(1) == 0 and ui.train_button.disabled and ui.feedback.text.contains("Insufficient credits"), "last affordable UI enqueue disables Train and reports insufficient credits")
	await _click(ui.cancel_buttons[p.jobs()[0]["id"]].get_global_rect().get_center(), MOUSE_BUTTON_LEFT)
	_check(base.credits.balance(1) == 100 and not ui.train_button.disabled, "viewport refund restores affordability and Train control")


func _production_lifecycle_checks() -> void:
	await _fresh_production()
	var b := base.barracks
	var p := b.production
	var nested := {"entered": false, "coherent": false, "accepted": false}
	var recipe := b.recipe
	var credits := base.credits
	var listener := func(_owner: int) -> void:
		if nested["entered"]:
			return
		nested["entered"] = true
		nested["coherent"] = credits.balance(1) == 900 and p.count() == 1
		var first_id: int = p.jobs()[0]["id"]
		nested["accepted"] = p.enqueue(1, recipe).accepted
		p.cancel(1, first_id)
	credits.changed.connect(listener)
	var result := p.enqueue(1, recipe)
	credits.changed.disconnect(listener)
	_check(result.accepted and nested["coherent"] and nested["accepted"] and p.count() == 1 and credits.balance(1) == 900 and p.jobs()[0]["id"] != result.job_id, "nested credit enqueue/cancel sees coherent state and preserves historical acceptance")
	var remaining: int = p.jobs()[0]["id"]
	var refund := {"calls": 0, "second_rejected": false}
	listener = func(_owner: int) -> void:
		refund["calls"] += 1
		refund["second_rejected"] = not p.cancel(1, remaining).accepted
	credits.changed.connect(listener)
	_check(p.cancel(1, remaining).accepted, "outer cancellation accepted during recursive refund listener")
	credits.changed.disconnect(listener)
	_check(refund["calls"] == 1 and refund["second_rejected"] and credits.balance(1) == 1000, "refund published only after job removal prevents recursive double refund")
	var queue_listener := func() -> void:
		if p.count() == 1:
			p.cancel(1, p.jobs()[0]["id"])
	p.changed.connect(queue_listener)
	result = p.enqueue(1, recipe)
	p.changed.disconnect(queue_listener)
	_check(result.accepted and p.count() == 0 and credits.balance(1) == 1000, "nested queue notification cancellation remains coherent")
	for removal in ["immediate", "deferred", "detach"]:
		await _fresh_production()
		b = base.barracks
		p = b.production
		credits = base.credits
		var once := {"done": false, "rejected": false}
		var saved_recipe := b.recipe
		var building_ref: WeakRef = weakref(b)
		listener = func(_owner: int) -> void:
			if once["done"]:
				return
			once["done"] = true
			var live := building_ref.get_ref() as RTSBuilding
			match removal:
				"immediate": live.free()
				"deferred": live.queue_free()
				"detach": live.get_parent().remove_child(live)
			once["rejected"] = not p.enqueue(1, saved_recipe).accepted
		credits.changed.connect(listener)
		result = p.enqueue(1, saved_recipe)
		await _frames(4)
		credits.changed.disconnect(listener)
		_check(result.accepted and once["rejected"] and not p.is_available() and p.count() == 0 and credits.balance(1) == 1000, "%s producer removal during wallet notification rejects new work and refunds once" % removal)
		p.close(true)
		_check(credits.balance(1) == 1000, "%s removal cleanup is idempotent" % removal)
		if is_instance_valid(b):
			b.free()
	await _fresh_production()
	b = base.barracks
	p = b.production
	result = p.enqueue(1, b.recipe)
	await _frames(30)
	var before := p.progress()
	var container := Node3D.new()
	base.add_child(container)
	b.reparent(container)
	await _frames(4)
	_check(p.is_available() and b.production == p and p.jobs()[0]["id"] == result.job_id and p.progress() >= before and base.credits.balance(1) == 900, "same-field reparent retains producer, job, progress and payment")
	container.queue_free()
	_check(not p.enqueue(1, b.recipe).accepted, "queued ancestor makes producer unavailable immediately")
	await _frames(4)
	_check(p.count() == 0 and base.credits.balance(1) == 1000, "removing reparented producer still refunds its job once")
	await _completion_boundary_checks()
	await _fresh_production()
	p = base.barracks.production
	p.enqueue(1, base.barracks.recipe)
	base.selection.select_building(base.barracks)
	credits = base.credits
	await _fresh_production()
	_check(not credits.active and p.count() == 0 and not p.is_available() and p.changed.get_connections().is_empty() and credits.changed.get_connections().is_empty(), "scene teardown closes retained queue handles and disconnects old wallet/UI")
	_check(base.credits != credits and base.credits.balance(1) == 1000 and base.units.size() == 6, "restart creates independent initial wallet, jobs and population")
	var paid := base.barracks.production.enqueue(1, base.barracks.recipe)
	base.barracks.owner_id = 2
	_check(base.barracks.production.cancel(2, paid.job_id).accepted and base.credits.balance(1) == 1000 and base.credits.balance(2) == 1000, "refund goes to captured payer even if fixture changes producer owner")
	for immediate in [false, true]:
		await _fresh_production()
		p = base.barracks.production
		credits = base.credits
		var field_ref: WeakRef = weakref(base)
		listener = func(_owner: int) -> void:
			var live := field_ref.get_ref() as ProductionField
			if immediate:
				live.free()
			else:
				live.queue_free()
		credits.changed.connect(listener, CONNECT_ONE_SHOT)
		result = p.enqueue(1, base.barracks.recipe)
		await _frames(4)
		_check(result.accepted and not is_instance_valid(base) and not credits.active and p.count() == 0 and not p.is_available(), "whole-field teardown during wallet notification is safe: immediate=%s" % immediate)


func _completion_boundary_checks() -> void:
	await _fresh_production()
	var p := base.barracks.production
	var result := p.enqueue(1, base.barracks.recipe)
	var cancelled := {"accepted": false}
	p.changed.connect(func() -> void:
		if p.progress() == 1.0:
			cancelled["accepted"] = p.cancel(1, result.job_id).accepted)
	await _frames(330)
	_check(cancelled["accepted"] and p.count() == 0 and base.units.size() == 6 and base.credits.balance(1) == 1000, "100 percent notification is precommit: cancellation prevents deployment and refunds")
	await _fresh_production()
	p = base.barracks.production
	result = p.enqueue(1, base.barracks.recipe)
	# A real SceneTree callback occurs during creation, before domain deployment.
	base.child_entered_tree.connect(func(node: Node) -> void:
		if node is RTSUnit and node.unit_id > 6:
			p.cancel(1, result.job_id))
	await _frames(330)
	_check(p.count() == 0 and base.units.size() == 6 and base.credits.balance(1) == 1000 and base.get_tree().get_nodes_in_group("controllable_units").size() == 6, "creation callback cancellation rolls back uncommitted unit without orphan")
	await _fresh_production()
	p = base.barracks.production
	result = p.enqueue(1, base.barracks.recipe)
	var completion := {"count": 0, "rejected": false, "coherent": false}
	p.deployed.connect(func(id: int, identity: int, _rally: bool) -> void:
		completion["count"] += 1
		completion["rejected"] = not p.cancel(1, id).accepted
		for unit in base.units.duplicate():
			if unit.unit_id == identity:
				completion["coherent"] = p.count() == 0 and base.contains_unit(unit) and unit.combat.health.current == 100
				unit.free()
		p.advance(5.0))
	await _frames(660)
	_check(completion["count"] == 1 and completion["rejected"] and completion["coherent"] and p.count() == 0 and base.units.size() == 6 and base.credits.balance(1) == 900, "postcommit callback sees initialized unit; freeing and reentering cannot redeploy or refund")
	await _fresh_production()
	var b := base.barracks
	p = b.production
	p.enqueue(1, b.recipe)
	p.enqueue(1, b.recipe)
	p.deployed.connect(func(_job: int, _unit: int, _rally: bool) -> void: b.free())
	await _frames(330)
	_check(p.count() == 0 and base.units.size() == 7 and base.credits.balance(1) == 900, "producer removal after deployment refunds only still-queued job")
	await _fresh_production()
	p = base.barracks.production
	var old_balance := base.credits.balance(1)
	base.child_entered_tree.connect(func(node: Node) -> void:
		if node is RTSUnit and node.unit_id > 6:
			var unit_ref: WeakRef = weakref(node)
			node.visibility_changed.connect(func() -> void:
				var live := unit_ref.get_ref() as RTSUnit
				if is_instance_valid(live) and live.visible:
					live.queue_free()))
	p.enqueue(1, base.barracks.recipe)
	await _frames(330)
	_check(p.count() == 0 and base.units.size() == 6 and base.credits.balance(1) == old_balance - 100, "visibility callback removing committed deployment cannot refund or repeat it")


func _produced_combat_checks() -> void:
	await _fresh_production()
	var p := base.barracks.production
	base.selection.select_building(base.barracks)
	_check(p.set_rally(1, Vector3(9, 0, 0)).accepted, "end-to-end rally uses a reachable approach to hostile group")
	await _click(base.production_panel.train_button.get_global_rect().get_center(), MOUSE_BUTTON_LEFT)
	_check(p.count() == 1 and base.credits.balance(1) == 900, "end-to-end starts by spending through viewport Train")
	await _frames(306)
	var unit := base.units[-1]
	_check(unit.unit_id > 6 and p.count() == 0 and unit.moving and unit.assigned_destination == Vector3(9, 0, 0), "end-to-end deploys a newly produced Rifle with rally movement")
	var arrived := false
	for i in 600:
		await _frames(1)
		if not unit.moving:
			arrived = unit.global_position.distance_to(Vector3(9, 0, 0)) < 0.25
			break
	_check(arrived, "produced Rifle actually reaches rally before engagement")
	await _click(_screen(unit), MOUSE_BUTTON_LEFT)
	_check(base.selection.selected_units() == [unit] and base.selection.selected_building() == null, "viewport selects the actually produced Rifle")
	var target := base.units[4]
	var health := target.combat.health.current
	await _click(_screen(target), MOUSE_BUTTON_RIGHT)
	_check(unit.combat.target_unit() == target and base.last_command_result.is_complete(), "contextual right-click issues normal accepted combat batch")
	var damaged := false
	for i in 240:
		await _frames(1)
		if is_instance_valid(target) and target.combat.health.current < health:
			damaged = true
			break
	_check(damaged and is_instance_valid(unit), "produced Rifle deals observed weapon damage in real engagement")
	_key_x()
	await _frames(2)
	_check(not unit.moving and unit.combat.target_unit() == null, "produced Rifle accepts normal viewport X Stop")
	var identity := unit.unit_id
	unit.combat.health.apply_damage(1000)
	_check(not base.contains_unit(unit) and base.selection.selected_units().is_empty(), "produced death immediately removes live membership and selection")
	await _frames(4)
	var absent := true
	for survivor in base.units:
		absent = absent and survivor.unit_id != identity
	_check(not is_instance_valid(unit) and absent and base.credits.balance(1) == 900, "produced unit death frees it and never refunds deployed payment")
