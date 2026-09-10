extends "res://tests/hud_clarity_checks.gd"
## Load fixture assets per runner instance: compile-time preloads across this
## inherited harness retain the cyclic gameplay script graph at engine shutdown.
## M11 focused fixtures. Geometry/cargo injection is deliberately confined to
## routing, accounting and failure checks; the separate earned integration suite
## proves the complete economy using ordinary loading, building and production.
## Use the inherited 180-second watchdog and tools/run-godot.ps1 external timeout.

var DEPOT: ConstructionDefinition = load("res://construction/supply_depot.tres")
var COLLECTOR_RECIPE: ProductionDefinition = load("res://production/collector_truck.tres")
const DEPOT_POINT := Vector3(-10.1, 0, -6)

class RouteFixture extends HarvestField:
	func _build_field() -> void:
		# The central wall ends at z=15. A collector west of it must genuinely
		# navigate around its end to reach a geometrically nearer eastern depot.
		obstacles = [BASE_OBSTACLES[0], BASE_OBSTACLES[1], Rect2(-1, -20, 2, 35), BASE_OBSTACLES[3]]
		super._build_field()


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1280, 720)
	var logger := EngineErrorProbe.new()
	OS.add_logger(logger)
	var chosen := "all"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--depot-case="):
			chosen = argument.trim_prefix("--depot-case=")
	var cases := ["construction", "routing", "trips", "invalidation", "callbacks", "production", "freeze", "ui"]
	_check(chosen == "all" or cases.has(chosen), "recognized supply depot case")
	for case in cases:
		if chosen != "all" and chosen != case: continue
		var before := checks
		var failed := failures
		match case:
			"construction": await _depot_construction()
			"routing": await _depot_routing()
			"trips": await _depot_trips()
			"invalidation": await _depot_invalidation()
			"callbacks": await _depot_callbacks()
			"production": await _depot_production()
			"freeze": await _depot_freeze()
			"ui": await _depot_ui()
		print("DEPOT_CASE: %s checks=%d failures=%d" % [case, checks - before, failures - failed])
	if is_instance_valid(field): field.queue_free()
	await _frames(6)
	_check(root.get_children().is_empty() and get_nodes_in_group("combat_projectiles").is_empty(), "depot teardown removes fields, queues, access owners and controls")
	OS.remove_logger(logger)
	_check(logger.error_count() == 0, "depot checks and lifecycle callbacks have no native errors or warnings")
	print("SUPPLY_DEPOT_CHECKS: %d checks, %d failures; native_errors=%d" % [checks, failures, logger.error_count()])
	quit(0 if failures == 0 else 1)


func _fresh_depot(funds: int = 2000, supplies: int = 2000) -> void:
	if is_instance_valid(field):
		field.queue_free()
		await _frames(5)
	var economy := load("res://scenes/supply_depot_assault.tscn").instantiate() as EconomyAssaultField
	economy.starting_credits = funds
	economy.cache_supplies = supplies
	battle = economy
	world = economy
	harvest = economy
	field = economy
	root.add_child(economy)
	current_scene = economy
	economy.camera_rig.edge_scrolling_enabled = false
	# Isolate ordinary feature fixtures from combat/economy scheduling. This does
	# not alter any shared scenario resource; M10 suites exercise the live enemy.
	economy.enemy_controller.set_physics_process(false)
	for unit in economy.units:
		if unit.owner_id == 2:
			unit.stop()
			unit.set_physics_process(false)
	for tick in 60:
		await _frames(1)
		if _current_harvest_navigation(): break
	_check(_current_harvest_navigation() and battle.credits.balance(1) == funds and battle._access_claims.is_empty(), "fresh depot fixture has current-field navigation, configured wallet and no stale access")
	_check(battle.registered_buildings().filter(func(item: RTSBuilding) -> bool: return item.kind == RTSBuilding.Kind.SUPPLY_DEPOT).is_empty(), "new scenario begins without a prebuilt depot")
	_check(_depot_player_cache() != null and _depot_player_cache().cache_id == 1 and _depot_player_cache() != economy.enemy_cache and _depot_player_cache(1) != null and _depot_player_cache(1).cache_id == 2, "depot fixtures identify both player caches by declared footprint, independently of enemy registration order")


func _depot_player_cache(index: int = 0) -> SupplyCache:
	var center := HarvestField.CACHE_FOOTPRINTS[index].get_center()
	for cache in battle.registered_caches():
		if Vector2(cache.global_position.x, cache.global_position.z).is_equal_approx(center):
			return cache
	return null


func _place_depot(point: Vector3 = DEPOT_POINT) -> ConstructionResult:
	await physics_frame
	return battle.construction.place(1, battle.headquarters, DEPOT, point)


func _depot(point: Vector3 = DEPOT_POINT) -> RTSBuilding:
	var site := await _ready_site(await _place_depot(point))
	if site == null or not await _complete_site(site): return null
	return site.building()


func _depot_capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://validation-output/m11/screenshots")
	var picture := root.get_texture().get_image()
	_check(picture.save_png("res://validation-output/m11/screenshots/%s.png" % label) == OK and picture.get_size() == root.size, "saved actual M11 viewport " + label)


func _depot_construction() -> void:
	await _fresh_depot()
	_check(DEPOT.is_valid() and DEPOT.credit_cost == 300 and DEPOT.duration == 10 and DEPOT.footprint == Vector2(6, 5), "depot definition preserves specified 300-credit, ten-second footprint defaults")
	_check(COLLECTOR_RECIPE.is_valid() and COLLECTOR_RECIPE.credit_cost == 200 and COLLECTOR_RECIPE.training_duration == 6, "collector recipe validates exact existing scene and specified 200-credit/six-second defaults")
	var panel := battle.production_panel as ConstructionPanel
	_check(panel.depot_button.visible and panel.depot_button.text.contains("300") and panel.depot_button.text.contains("10"), "owned headquarters exposes priced depot construction")
	await physics_frame
	var broad_valid := true
	for point in [Vector3(-7, 0, 2.5), Vector3(-4, 0, 2.5), Vector3(-7, 0, 4.5), Vector3(-4, 0, 4.5), Vector3(-6, 0, 3)]:
		var rejection := battle.placement_geometry(point, DEPOT)
		print("DEPOT_PLACEMENT_NEIGHBORHOOD: point=%s result=%s" % [point, "valid" if rejection.is_empty() else rejection])
		broad_valid = broad_valid and rejection.is_empty()
	_check(broad_valid, "second-cache depot neighborhood exposes multiple ordinary valid full-footprint placements")
	var balance := battle.credits.balance(1)
	var site := await _ready_site(await _place_depot())
	if site == null: return
	var building := site.building()
	var truck := battle.collectors[0]
	truck.harvesting.cargo = 25 # Focused rejection fixture, not earned income.
	battle.selection.select_clicked(truck, false)
	_check(site.paid == 300 and site.duration == 10 and battle.credits.balance(1) == balance - 300 and not building.operational, "ordinary placement commits exactly 300 and creates unfinished ten-second site")
	_check(not battle.valid_dropoff(building, 1) and not battle.issue_deposit(building).has_acceptance() and not building.production.enqueue(1, COLLECTOR_RECIPE).accepted, "unfinished depot rejects manual deposit, eligibility and collector production")
	await physics_frame
	_check(not battle.construction.place(1, battle.headquarters, FACTORY, SECOND).accepted, "depot shares the existing one-unfinished-site concurrency limit")
	_check(not battle._nav_point(DEPOT_POINT) and battle.fire_query.segment(battle.get_world_3d(), DEPOT_POINT + Vector3(-4, 1, 0), DEPOT_POINT + Vector3(4, 1, 0)).blocked, "unfinished depot footprint blocks both navigation and weapons")
	await _frames(590)
	_check(not building.operational and site.elapsed < 10 and site.elapsed > 9.7, "depot cannot complete before the full ten simulated seconds")
	await _cleanup_site(site)
	_check(battle.credits.balance(1) == balance and not battle.construction.cancel(1, site.site_id).accepted and battle._nav_point(DEPOT_POINT), "cancellation refunds captured construction payment once and restores its navigation hole")
	building = await _depot()
	if building == null: return
	_check(building.kind == RTSBuilding.Kind.SUPPLY_DEPOT and building.operational and building.health.current == 450 and building.can_take_damage(), "completed depot is a damageable stationary producer with inherited 450 health")
	_check(battle.valid_dropoff(building, 1) and not battle.valid_dropoff(building, 2) and building.recipe == COLLECTOR_RECIPE and building.queue_capacity == 5, "completion enables only owner-correct delivery and five-job collector production")
	await physics_frame
	var slots := battle.access_positions(building)
	var separated := slots.size() >= 4
	for access in slots:
		for offset in ProductionField.SPAWN_OFFSETS:
			separated = separated and (access["point"] as Vector3).distance_to(building.exit_position() + offset) > RTSUnit.BODY_RADIUS * 2
	_check(separated, "depot has multiple delivery positions separated from all ordinary production samples")
	_check(not building.supports_recipe(load("res://production/rifle.tres")) and not building.supports_recipe(ROCKET_RECIPE), "depot rejects Rifle and Rocket recipes")
	var ordinary_factory := RTSBuilding.new()
	ordinary_factory.kind = RTSBuilding.Kind.VEHICLE_FACTORY
	_check(ordinary_factory.supports_recipe(ROCKET_RECIPE) and not ordinary_factory.supports_recipe(COLLECTOR_RECIPE), "vehicle factory remains Rocket-only and cannot inherit collector recipe admission")
	ordinary_factory.free()
	var legacy := load("res://scenes/combined_arms_assault.tscn").instantiate() as BaseAssaultField
	_check(legacy.supply_depot_definition == null and legacy.vehicle_factory_definition == FACTORY, "earlier combined-arms scene keeps its exact construction opt-in defaults")
	legacy.free()
	await _fresh_harvest(25, 0)
	field = harvest
	var old_truck := _select_collector()
	_check(harvest.valid_dropoff(harvest.headquarters, 1) and not harvest.valid_dropoff(harvest.barracks, 1) and not harvest.barracks.supports_recipe(COLLECTOR_RECIPE), "legacy HQ remains eligible while barracks keeps Rifle-only behavior")
	_check(_complete(harvest.issue_harvest(harvest.caches[0])), "earlier HQ-only harvesting accepts ordinary assignment")
	await _until(func() -> bool: return old_truck.harvesting.state == CollectorHarvest.State.WAITING and harvest.credits.balance(1) == 25, 22, "earlier HQ-only scene performs a real complete load and deposit before waiting")


func _route_depot(route: RouteFixture, point: Vector3) -> RTSBuilding:
	var building := RTSBuilding.new()
	building.kind = RTSBuilding.Kind.SUPPLY_DEPOT
	building.recipe = COLLECTOR_RECIPE
	building.position = point
	route.add_child(building)
	route.register_building(building)
	route.obstacles.append(Rect2(Vector2(point.x, point.z) - building.footprint / 2.0, building.footprint))
	return building


func _fresh_route() -> RouteFixture:
	if is_instance_valid(field):
		field.queue_free()
		await _frames(5)
	var route := RouteFixture.new()
	field = route
	harvest = route
	battle = null
	world = null
	root.add_child(route)
	current_scene = route
	route.camera_rig.edge_scrolling_enabled = false
	route.headquarters.operational = false
	for unit in route.units:
		unit.set_physics_process(false)
	await _frames(8)
	return route


func _depot_routing() -> void:
	var route := await _fresh_route()
	var near := _route_depot(route, Vector3(6, 0, 0))
	# Southwest is geometrically farther but its northern bays face the origin
	# across open ground, clear of the legacy western HQ and barracks footprints.
	var far := _route_depot(route, Vector3(-10, 0, 10))
	route.navigation_region.navigation_mesh = route.create_navigation_mesh(route.obstacles)
	var truck := route.collectors[0]
	truck.global_position = Vector3(-4, 0, 0)
	await _frames(8)
	await physics_frame
	var near_access := route.plan_access(truck, near)
	var far_access := route.plan_access(truck, far)
	_check(not near_access.is_empty() and not far_access.is_empty(), "wall fixture exposes real navigable access on both sides")
	if near_access.is_empty() or far_access.is_empty(): return
	_check(truck.position.distance_to(near.position) < truck.position.distance_to(far.position) and float(near_access["route_length"]) > float(far_access["route_length"]) + 10, "geometrically closer eastern depot has a demonstrably longer actual route around wall")
	var chosen := route.choose_dropoff(truck)
	_check(chosen.get("building") == far, "automatic selector chooses shortest navigable route rather than nearest building")
	print("DEPOT_ROUTE_INVERSION: geometric_near=%.3f geometric_far=%.3f navigable_near=%.3f navigable_far=%.3f" % [truck.position.distance_to(near.position), truck.position.distance_to(far.position), near_access["route_length"], far_access["route_length"]])
	far.owner_id = 2
	_check(not route.valid_dropoff(far, 1) and route.choose_dropoff(truck).get("building") == near, "enemy depot cannot win automatic owner-one routing")
	far.owner_id = 1
	far.operational = false
	_check(not route.valid_dropoff(far, 1) and route.choose_dropoff(truck).get("building") == near, "unfinished/nonoperational depot cannot win routing")
	far.operational = true
	var foreign := RTSBuilding.new()
	foreign.kind = RTSBuilding.Kind.SUPPLY_DEPOT
	_check(not route.valid_dropoff(foreign, 1), "unregistered depot capability alone cannot bypass active field membership")
	foreign.free()
	# An actual collision-only obstruction covers every valid interaction face.
	# Navigation still projects onto these points: projection alone must not pass.
	var blocker := StaticBody3D.new()
	blocker.collision_layer = 4 | LineOfFire.BLOCKER_MASK
	blocker.position = far.position + Vector3.UP
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(10, 3, 9)
	collision.shape = shape
	blocker.add_child(collision)
	route.add_child(blocker)
	await _frames(3)
	await physics_frame
	_check(route.plan_access(truck, far).is_empty() and route.choose_dropoff(truck).get("building") == near, "physically blocked access is rejected despite valid navigation projections")
	blocker.queue_free()
	await _frames(3)
	route.obstacles[2] = Rect2(-1, -24, 2, 48)
	route._box(Vector3(2, 2, 48), Vector3(0, 1, 0), Color("8b7866"), 4 | LineOfFire.BLOCKER_MASK)
	route.navigation_region.navigation_mesh = route.create_navigation_mesh(route.obstacles)
	await _frames(8)
	await physics_frame
	_check(route.access_positions(near).any(func(access: Dictionary) -> bool: return route._nav_point(access["point"])) and route.plan_access(truck, near).is_empty() and route.choose_dropoff(truck).get("building") == far, "disconnected eastern navigation island cannot receive cargo despite valid endpoint projections")
	# Independent symmetric fixture proves tie stability without relying on a
	# wall layout, instance creation race, or path-score mock.
	route = await _fresh_route()
	var first := _route_depot(route, Vector3(-10, 0, -7))
	var second := _route_depot(route, Vector3(-10, 0, 7))
	route.navigation_region.navigation_mesh = route.create_navigation_mesh(route.obstacles)
	truck = route.collectors[0]
	truck.position = Vector3(-10, 0, 0)
	await _frames(8)
	await physics_frame
	var first_access := route.plan_access(truck, first)
	var second_access := route.plan_access(truck, second)
	_check(not first_access.is_empty() and not second_access.is_empty(), "symmetric fixture exposes two independent depot approaches")
	if first_access.is_empty() or second_access.is_empty(): return
	_check(is_equal_approx(float(first_access["route_length"]), float(second_access["route_length"])), "symmetric depot alternatives have equal navigable cost")
	var expected := first if first.get_instance_id() < second.get_instance_id() else second
	_check(route.choose_dropoff(truck).get("building") == expected, "equal route costs choose stable building identity")
	route.remove_child(first)
	route.add_child(first)
	route.register_building(first)
	await _frames(3)
	await physics_frame
	var stable := true
	for attempt in 8:
		stable = stable and route.choose_dropoff(truck).get("building") == expected
	_check(stable, "equal-cost choice remains stable after real departure/re-entry changes registry insertion order")


func _depot_trips() -> void:
	await _fresh_depot()
	var truck := battle.collectors[0]
	# Focused trip-boundary setup: full cargo is injected, never counted as earned
	# end-to-end coverage. All subsequent return travel and unload timing is real.
	truck.harvesting.cargo = 100
	truck.position = Vector3(-7, 0, -12.2)
	await _frames(3)
	battle.selection.select_clicked(truck, false)
	_check(_complete(battle.issue_harvest(_depot_player_cache())) and truck.harvesting.dropoff_node() == battle.headquarters, "without depot automatic return retains the owned headquarters")
	var original_target := truck.harvesting.dropoff_node()
	var original_generation := truck.harvesting.generation
	var site := await _ready_site(await _place_depot())
	if site == null: return
	# Hold this collector's existing movement while construction completes, to
	# isolate destination stability from whether a short route already delivered.
	truck.suspend_navigation()
	truck.set_physics_process(false)
	if not await _complete_site(site): return
	var building := site.building()
	_check(truck.harvesting.dropoff_node() == original_target and truck.harvesting.generation == original_generation, "newly completed closer depot does not replace an active valid delivery")
	truck.resume_navigation()
	truck.set_physics_process(true)
	await _until(func() -> bool: return truck.harvesting.cargo == 0, 15, "existing trip actually completes at its retained headquarters")
	truck.stop()
	truck.position = Vector3(-7, 0, -12.2)
	truck.harvesting.cargo = 100
	await _frames(3)
	await physics_frame
	var hq_access := battle.plan_access(truck, battle.headquarters)
	var depot_access := battle.plan_access(truck, building)
	_check(not hq_access.is_empty() and not depot_access.is_empty(), "useful construction point has real usable HQ and depot routes from cache side")
	if hq_access.is_empty() or depot_access.is_empty(): return
	_check(float(depot_access["route_length"]) < float(hq_access["route_length"]), "constructed depot offers a shorter valid return route than headquarters")
	print("DEPOT_USEFUL_PLACEMENT: hq_route=%.3f depot_route=%.3f speed=%.1f capacity=%d unload_seconds=%.1f" % [hq_access["route_length"], depot_access["route_length"], truck.movement_speed, truck.cargo_capacity, truck.unloading_duration])
	_check(_complete(battle.issue_harvest(_depot_player_cache())) and truck.harvesting.dropoff_node() == building, "next delivery boundary adopts the newly completed shorter depot")
	var version := truck.harvesting.generation
	var traveled := 0.0
	var prior := truck.position
	var start_tick := Engine.get_physics_frames()
	var balance := battle.credits.balance(1)
	for tick in 900:
		await _frames(1)
		traveled += prior.distance_to(truck.position)
		prior = truck.position
		if truck.harvesting.cargo == 0: break
	_check(truck.harvesting.cargo == 0 and battle.credits.balance(1) == balance + 100 and truck.harvesting.generation == version, "controlled depot return deposits cargo once without repeatedly restarting its order")
	_check(truck.harvesting.cache_node() == _depot_player_cache() and truck.harvesting.automatic, "successful automatic depot delivery resumes its original live cache assignment")
	print("DEPOT_CONTROLLED_TRIP: actual_distance=%.3f ticks=%d route=%.3f; unobstructed single delivery, no universal congestion income claim" % [traveled, Engine.get_physics_frames() - start_tick, depot_access["route_length"]])
	truck.stop()


func _return_fixture(building: RTSBuilding, automatic: bool = false) -> CollectorTruck:
	var truck := battle.collectors[0]
	truck.stop()
	truck.harvesting.cargo = 100 if automatic else 25
	truck.position = Vector3(-7, 0, -12.2)
	await _frames(3)
	battle.selection.select_clicked(truck, false)
	var accepted := battle.issue_harvest(_depot_player_cache()) if automatic else battle.issue_deposit(building)
	_check(_complete(accepted) and truck.harvesting.dropoff_node() == building, "focused cargo fixture accepts intended %s depot return" % ("automatic" if automatic else "manual"))
	await _until(func() -> bool: return truck.harvesting.state == CollectorHarvest.State.UNLOADING, 15, "fixture navigates and arrives before starting the real unload interval")
	return truck


func _depot_invalidation() -> void:
	await _fresh_depot()
	var building := await _depot()
	if building == null: return
	var truck := await _return_fixture(building)
	var work := truck.harvesting
	var balance := battle.credits.balance(1)
	var rifle := battle.units[0]
	rifle.move_to(Vector3(-12, 0, 18))
	var rifle_order := rifle.order_version
	battle.selection.select_clicked(rifle, true)
	var mixed := battle.issue_deposit(building)
	_expect_batch(mixed, [truck.unit_id, rifle.unit_id], [truck.unit_id], CommandBatchResult.Acceptance.PARTIAL)
	_check(rifle.order_version == rifle_order and rifle.moving, "mixed depot return preserves an ineligible combat unit's active work")
	battle.selection.select_clicked(truck, false)
	var version := work.generation
	var target := work.dropoff_node()
	_check(not battle.issue_deposit(battle.enemy_headquarters).has_acceptance() and work.generation == version and work.dropoff_node() == target and work.cargo == 25, "rejected enemy return retains current valid depot work and cargo")
	await _until(func() -> bool: return work.state == CollectorHarvest.State.UNLOADING, 2, "mixed explicit return reaches its unchanged nearby deposit bay")
	await _frames(25)
	await physics_frame
	TeamRules.damage_target(battle, 2, building, 10000, battle.units[3])
	await _frames(90)
	_check(work.cargo == 25 and battle.credits.balance(1) == balance and not work.automatic and work.state in [CollectorHarvest.State.IDLE, CollectorHarvest.State.BLOCKED], "manual depot destruction before commit cancels safely with cargo and no substitute deposit")
	_check(_complete(battle.issue_deposit(battle.headquarters)), "manual invalidation still accepts a subsequent explicit headquarters command")
	await _until(func() -> bool: return work.cargo == 0 and work.state == CollectorHarvest.State.IDLE, 15, "player's replacement HQ command deposits once and becomes idle")
	_check(battle.credits.balance(1) == balance + 25, "replacement explicit delivery credits only actual retained cargo")
	await _fresh_depot()
	building = await _depot()
	if building == null: return
	truck = await _return_fixture(building, true)
	work = truck.harvesting
	balance = battle.credits.balance(1)
	await _frames(25)
	await physics_frame
	TeamRules.damage_target(battle, 2, building, 10000, battle.units[3])
	await _until(func() -> bool: return work.dropoff_node() == battle.headquarters, 6, "automatic precommit destruction chooses its surviving owned HQ alternative")
	_check(work.cargo == 100 and battle.credits.balance(1) == balance, "alternative selection cannot remotely deposit interrupted cargo")
	if not await _until(func() -> bool: return work.state == CollectorHarvest.State.UNLOADING, 15, "alternative must actually arrive before unloading restarts"): return
	await _frames(58)
	_check(work.cargo == 100 and battle.credits.balance(1) == balance, "alternative requires a fresh full unloading interval after arrival")
	await _until(func() -> bool: return work.cargo == 0, 1, "alternative commits its cargo after complete fresh interval")
	_check(battle.credits.balance(1) == balance + 100 and work.cache_node() == _depot_player_cache(), "automatic invalidation deposits once then preserves cache assignment")
	await _fresh_depot()
	building = await _depot()
	if building == null: return
	truck = battle.collectors[0]
	truck.harvesting.cargo = 100
	truck.position = Vector3(-7, 0, -12.2)
	await _frames(3)
	battle.selection.select_clicked(truck, false)
	_check(_complete(battle.issue_harvest(_depot_player_cache())), "bounded-failure fixture accepts initial depot return")
	work = truck.harvesting
	# Deterministic exhausted-mover result injection exercises the return policy,
	# independently of historical congestion/deadlock attribution.
	truck._fail_move()
	await _frames(1)
	_check(work.dropoff_node() == battle.headquarters and work._alternative_used and work._failed_dropoffs.size() == 1, "first exhausted return route consumes exactly one alternative evaluation")
	truck._fail_move()
	await _frames(1)
	var generation := work.generation
	var order := truck.order_version
	balance = battle.credits.balance(1)
	await _frames(180)
	_check(work.state == CollectorHarvest.State.BLOCKED and work.cargo == 100 and work.generation == generation and truck.order_version == order and battle.credits.balance(1) == balance, "second failed route remains safely blocked with retained cargo and no endless order reset")
	_check(_complete(battle.issue_stop()) and work.state == CollectorHarvest.State.IDLE and work.cargo == 100, "bounded failure accepts Stop without discarding cargo")
	_check(_complete(battle.issue_move(Vector3(-12, 0, -14))) and work.cargo == 100 and not work.automatic, "new player ground Move supersedes failed harvesting while retaining cargo")
	truck.stop()
	var second := battle.collectors[1]
	second.harvesting.cargo = 25
	battle.selection.select_clicked(truck, false)
	battle.selection.select_clicked(second, true)
	var observed := {"stopped": false}
	var stop_during_return := func() -> void:
		if not observed["stopped"] and work.state == CollectorHarvest.State.RETURNING:
			observed["stopped"] = true
			battle.issue_stop()
	work.changed.connect(stop_during_return)
	var superseded := battle.issue_deposit(building)
	work.changed.disconnect(stop_during_return)
	_expect_batch(superseded, [truck.unit_id, second.unit_id], [truck.unit_id], CommandBatchResult.Acceptance.PARTIAL, true)
	_check(observed["stopped"] and work.cargo == 100 and second.harvesting.cargo == 25 and work.state == CollectorHarvest.State.IDLE and second.harvesting.state == CollectorHarvest.State.IDLE, "synchronous newer Stop supersedes depot batch without dispatching its second collector or discarding cargo")


func _depot_callbacks() -> void:
	for callback_kind in ["spend", "remove_depot", "remove_collector", "replace", "finish"]:
		await _fresh_depot()
		var building := await _depot()
		if building == null: return
		var truck := await _return_fixture(building)
		var work := truck.harvesting
		var balance := battle.credits.balance(1)
		var enemy_balance := battle.credits.balance(2)
		var target_identity := building.get_instance_id()
		var observation := {"events": 0, "coherent": true, "acted": false}
		var producer := building.production
		work.transferred.connect(func(transfer: HarvestTransfer) -> void:
			if transfer.kind != HarvestTransfer.Kind.DEPOSIT: return
			observation["events"] += 1
			observation["coherent"] = observation["coherent"] and transfer.amount == 25 and transfer.owner_id == 1 and transfer.target_id == target_identity and work.cargo == 0 and battle.credits.balance(1) == balance + 25
			# Reentry at the authoritative notification must not replay transfer.
			observation["coherent"] = observation["coherent"] and work.complete_deposit().amount == 0
			match callback_kind:
				"spend": observation["acted"] = producer.enqueue(1, COLLECTOR_RECIPE).accepted
				"remove_depot":
					observation["acted"] = TeamRules.damage_target(battle, 2, building, 10000, battle.units[3])
				"remove_collector":
					truck.free()
					observation["acted"] = true
				"replace": observation["acted"] = _complete(battle.issue_harvest(_depot_player_cache(1)))
				"finish":
					TeamRules.damage_target(battle, 1, battle.enemy_headquarters, 10000, battle.units[0])
					battle.resolve_result()
					observation["acted"] = battle.result == BaseAssaultField.Result.VICTORY
		)
		await _until(func() -> bool: return observation["events"] > 0, 2, "deposit reaches synchronous %s callback" % callback_kind)
		await _frames(90)
		var expected := balance + 25 - (200 if callback_kind == "spend" else 0)
		_check(observation["events"] == 1 and observation["coherent"] and observation["acted"] and battle.credits.balance(1) == expected and battle.credits.balance(2) == enemy_balance, "%s callback sees coherent exactly-once owner wallet transfer and keeps committed income" % callback_kind)
		if callback_kind == "replace":
			_check(work.cache_node() == _depot_player_cache(1) and work.automatic, "accepted callback replacement survives outer deposit completion")
		elif callback_kind == "remove_depot":
			_check(work.cargo == 0 and battle.result == BaseAssaultField.Result.RUNNING, "postcommit depot destruction neither restores cargo nor ends match")
		elif callback_kind == "spend":
			_check(producer.count() == 1 and producer.jobs()[0]["paid"] == 200, "deposit notification can immediately spend the same existing wallet through production")


func _depot_production() -> void:
	await _fresh_depot(2500)
	var building := await _depot()
	if building == null: return
	var producer := building.production
	var balance := battle.credits.balance(1)
	_check(not producer.enqueue(2, COLLECTOR_RECIPE).accepted and not producer.enqueue(1, ROCKET_RECIPE).accepted and not producer.enqueue(1, load("res://production/rifle.tres")).accepted and battle.credits.balance(1) == balance, "collector queue rejects wrong owner and unsupported recipes without spending")
	var ids: Array[int] = []
	for index in 5: ids.append(producer.enqueue(1, COLLECTOR_RECIPE).job_id)
	_check(producer.count() == 5 and not producer.enqueue(1, COLLECTOR_RECIPE).accepted and battle.credits.balance(1) == balance - 1000, "five outstanding collector jobs debit 200 each and sixth rejects")
	await _frames(60)
	_check(producer.jobs()[0]["elapsed"] >= 0.99 and producer.jobs()[0]["elapsed"] < 1.1 and producer.jobs()[1]["elapsed"] == 0, "collector FIFO advances only the active head using fixed simulation time")
	_check(producer.cancel(1, ids[2]).accepted and not producer.cancel(1, ids[2]).accepted, "collector cancellation refunds a selected pending job only once")
	for job in producer.jobs(): producer.cancel(1, job["id"])
	_check(battle.credits.balance(1) == balance, "all undeployed collector cancellations refund captured payments")
	# Actual collector bodies occupy every ordinary exit sample. Their orders and
	# positions must survive production waiting; clearing is explicit test cleanup.
	var occupants: Array[CollectorTruck] = []
	for offset in ProductionField.SPAWN_OFFSETS:
		var actor := CollectorTruck.new()
		actor.unit_id = 100 + occupants.size()
		actor.position = building.exit_position() + offset
		battle.add_child(actor)
		battle.register_unit(actor)
		occupants.append(actor)
	await _frames(3)
	var initial_count := battle.units.filter(func(unit: RTSUnit) -> bool: return unit is CollectorTruck and battle.contains_unit(unit)).size()
	var paid := producer.enqueue(1, COLLECTOR_RECIPE)
	var deployed: Array[int] = []
	producer.deployed.connect(func(job: int, _unit: int, _rally: bool) -> void: deployed.append(job))
	await _frames(359)
	_check(deployed.is_empty() and producer.progress() < 1, "collector training cannot finish before six simulated seconds")
	await _frames(40)
	battle.selection.select_building(building)
	_check(producer.count() == 1 and producer.progress() == 1 and deployed.is_empty() and battle.production_panel.feedback.text.contains("Exit blocked"), "completed collector waits paid at a genuinely occupied exit with visible feedback")
	await _depot_capture("collector_exit_blocked_1280x720")
	var untouched := true
	for i in occupants.size(): untouched = untouched and occupants[i].position == building.exit_position() + ProductionField.SPAWN_OFFSETS[i] and not occupants[i].moving
	_check(untouched, "blocked production does not teleport or command delivery-sized collector occupants")
	_check(producer.set_rally(1, Vector3(-5, 0, 3)).accepted, "collector producer accepts ordinary ground rally")
	var observed := {"fresh": false, "clear": false}
	producer.deployed.connect(func(_job: int, identity: int, _rally: bool) -> void:
		var unit := _last_unit(producer) as CollectorTruck
		observed["fresh"] = unit != null and unit.unit_id == identity and unit.owner_id == 1 and battle.contains_unit(unit) and battle.collectors.has(unit) and unit.harvesting.cargo == 0 and unit.harvesting.cache_node() == null and unit.harvesting.dropoff_node() == null and not unit.harvesting.automatic and unit.harvesting._elapsed == 0 and unit.combat.weapon == null and unit.maximum_health == 150 and unit.combat.health.current == 150 and unit.movement_speed == 4 and unit.cargo_capacity == 100 and unit.loading_amount == 25 and unit.loading_interval == 1 and unit.unloading_duration == 1
		if unit == null: return
		var collider := unit.get_child(0) as CollisionShape3D
		var body := collider.shape as CapsuleShape3D
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = body
		query.transform = collider.global_transform
		query.exclude = [unit.get_rid()]
		query.collision_mask = 2 | 4 | LineOfFire.BLOCKER_MASK
		observed["clear"] = battle.get_world_3d().direct_space_state.intersect_shape(query).is_empty() and body.radius == (battle._spawn_query.shape as CapsuleShape3D).radius and body.height == (battle._spawn_query.shape as CapsuleShape3D).height
	)
	for occupant in occupants: occupant.queue_free()
	if not await _until(func() -> bool: return deployed.size() == 1, 1, "clearing blocked exit deploys the completed collector exactly once"): return
	var produced := _last_unit(producer) as CollectorTruck
	var live_collectors := battle.units.filter(func(unit: RTSUnit) -> bool: return unit is CollectorTruck and battle.contains_unit(unit)).size()
	_check(deployed == [paid.job_id] and producer.count() == 0 and observed["fresh"] and observed["clear"] and live_collectors == initial_count - occupants.size() + 1, "deployment is registered, collision-clear, fresh and exactly once with normal collector configuration")
	_check(producer.last_deployment["rally_accepted"] and produced.harvesting.state == CollectorHarvest.State.IDLE and produced.harvesting.cache_node() == null and produced.deployment_collection_pending() and not producer.cancel(1, paid.job_id).accepted, "ground rally defers automatic harvesting until arrival and deployed job cannot refund")
	var started_at: Array[Vector3] = []
	produced.harvesting.changed.connect(func() -> void:
		if produced.harvesting.automatic and started_at.is_empty(): started_at.append(produced.global_position)
	)
	await _until(func() -> bool: return not started_at.is_empty(), 12, "new collector completes normal rally movement then starts collection automatically")
	_check(not started_at.is_empty() and started_at[0].distance_to(producer.rally_point) < 0.4 and not produced.deployment_collection_pending(), "collector reaches its rally through existing movement before the one-time harvesting handoff")
	produced.stop() # Isolate the remaining queue payment/refund assertions.
	var rejected_rally_job := producer.enqueue(1, COLLECTOR_RECIPE)
	_check(rejected_rally_job.accepted and producer.set_rally(1, Vector3(-5, 0, 3)).accepted, "rejected-rally fixture starts with a paid collector and ordinarily accepted ground rally")
	# Isolated deployment-time fault: the formerly accepted ground destination
	# becomes unavailable. The real queue still runs its captured six seconds.
	producer.rally_point = Vector3(1000, 0, 1000)
	var paid_balance := battle.credits.balance(1)
	if not await _until(func() -> bool: return deployed.size() == 2, 7, "collector finishes actual training when its stored rally is no longer usable"): return
	var idle_collector := _last_unit(producer) as CollectorTruck
	_check(idle_collector != null and idle_collector != produced and battle.contains_unit(idle_collector) and idle_collector.harvesting.cargo == 0 and idle_collector.harvesting.state == CollectorHarvest.State.IDLE and idle_collector.harvesting.cache_node() == null and idle_collector.deployment_collection_pending() and not producer.last_deployment["rally_accepted"] and producer.count() == 0, "rejected rally leaves one fresh registered collector clearing its exit before automatic harvesting")
	_check(not producer.cancel(1, rejected_rally_job.job_id).accepted and battle.credits.balance(1) == paid_balance, "rejected collector rally cannot refund an already deployed paid job")
	await _until(func() -> bool: return idle_collector.harvesting.automatic, 8, "collector with an invalid rally safely clears production access then automatically harvests")
	idle_collector.stop()
	await _frames(90)
	_check(deployed == [paid.job_id, rejected_rally_job.job_id] and producer.count() == 0 and battle.credits.balance(1) == paid_balance and battle.contains_unit(idle_collector), "rejected rally neither duplicates deployment nor replays payment after subsequent frames")
	for index in 3: _check(producer.enqueue(1, COLLECTOR_RECIPE).accepted, "destruction fixture purchases a real pending collector")
	balance = battle.credits.balance(1)
	await physics_frame
	TeamRules.damage_target(battle, 2, building, 10000, battle.units[3])
	await _frames(5)
	_check(producer.count() == 0 and battle.credits.balance(1) == balance + 600 and not producer.enqueue(1, COLLECTOR_RECIPE).accepted, "depot destruction refunds all undeployed collector jobs through existing producer policy")
	_check(battle.contains_unit(produced) and battle.collectors.has(produced) and produced.harvesting.cargo == 0 and battle.result == BaseAssaultField.Result.RUNNING, "already deployed collector stays independent and depot is not a match objective")
	await _fresh_depot(499)
	building = await _depot()
	if building == null: return
	_check(battle.credits.balance(1) == 199 and not building.production.enqueue(1, COLLECTOR_RECIPE).accepted and building.production.count() == 0, "199 remaining credits cannot purchase a 200-credit collector")
	producer = building.production
	battle.remove_child(building)
	_check(not producer.enqueue(1, COLLECTOR_RECIPE).accepted and not battle.valid_dropoff(building, 1), "detached retained depot immediately rejects production and dropoff capability before deferred cleanup")
	await _frames(3)
	building.free()


func _depot_freeze() -> void:
	await _fresh_depot()
	var building := await _depot()
	if building == null: return
	var truck := await _return_fixture(building)
	var work := truck.harvesting
	var producer := building.production
	_check(producer.enqueue(1, COLLECTOR_RECIPE).accepted, "freeze fixture owns a real pending collector job")
	var site := await _ready_site(await _place(FIRST))
	if site == null: return
	# Construction synchronization may pause an unload; resume until the real
	# active delivery is at a valid authoritative boundary before finishing.
	if work.cargo == 0:
		truck = await _return_fixture(building)
		work = truck.harvesting
	var old_wallet := battle.credits
	var old_work := work
	var old_producer := producer
	await physics_frame
	TeamRules.damage_target(battle, 1, battle.enemy_headquarters, 10000, battle.units[0])
	battle.resolve_result()
	var balance := old_wallet.balance(1)
	var progress := producer.progress()
	var construction_elapsed := site.elapsed
	var cargo := work.cargo
	var generation := work.generation
	await _frames(180)
	_check(battle.result == BaseAssaultField.Result.VICTORY and old_wallet.balance(1) == balance and producer.progress() == progress and site.elapsed == construction_elapsed and work.cargo == cargo and work.generation == generation, "match result freezes production, construction, unloading, wallet and automatic routing")
	_check(not battle.issue_deposit(building).has_acceptance() and not producer.enqueue(1, COLLECTOR_RECIPE).accepted and work.complete_deposit().amount == 0, "frozen match rejects manual dispatch, purchases and stale transfer attempts")
	await _depot_capture("depot_match_result_1280x720")
	await _click(battle.restart_button.get_global_rect().get_center(), MOUSE_BUTTON_LEFT)
	await _frames(10)
	battle = current_scene as BaseAssaultField
	world = battle
	harvest = battle
	field = battle
	if battle == null:
		_check(false, "viewport Restart loads new depot assault scene")
		return
	battle.camera_rig.edge_scrolling_enabled = false
	_check(battle.scene_file_path == "res://scenes/supply_depot_assault.tscn" and battle.result == BaseAssaultField.Result.RUNNING and battle.credits.balance(1) == 1000 and battle.construction.sites.is_empty(), "Restart restores configured depot scene, initial wallet and no built depots")
	_check(battle.collectors.filter(func(unit: CollectorTruck) -> bool: return unit.owner_id == 1).size() == 2 and battle.collectors.filter(func(unit: CollectorTruck) -> bool: return unit.owner_id == 1).all(func(unit: CollectorTruck) -> bool: return unit.harvesting.cargo == 0 and unit.harvesting.dropoff_node() == null and unit.harvesting.cache_node() == null), "Restart restores initial player collectors with no prior dropoff or cache assignments")
	_check(not old_wallet.active and old_producer.count() == 0 and not old_producer.enqueue(1, COLLECTOR_RECIPE).accepted and old_work.complete_deposit().amount == 0, "old wallet, producer and transfer references cannot reconnect through reused match unit IDs")
	await _frames(3)
	_check(battle.credits.balance(1) == 1000, "old match references cannot cause stale new-match transfers")
	await _depot_capture("depot_restart_1280x720")


func _depot_ui() -> void:
	await _fresh_depot(2500)
	var panel := battle.production_panel as ConstructionPanel
	await _hud_pick_building(battle.headquarters)
	for dimensions in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		await _hud_layout(dimensions)
		_check(root.get_visible_rect().encloses(panel.depot_button.get_global_rect()) and not panel.depot_button.disabled, "depot construction choice is readable and actionable at %s" % dimensions)
		await _depot_capture("hq_%dx%d" % [dimensions.x, dimensions.y])
	root.size = Vector2i(1280, 720)
	await _frames(5)
	await _click(panel.depot_button.get_global_rect().get_center(), MOUSE_BUTTON_LEFT)
	_motion(_world_screen(DEPOT_POINT))
	await _frames(8)
	_check(battle.placement.active and battle.placement.definition == DEPOT and battle.placement.valid and battle.placement_guides.visible, "viewport Build Supply Depot selects correct real preview and protected access guides")
	await _depot_capture("depot_preview_1280x720")
	await _click(_world_screen(DEPOT_POINT), MOUSE_BUTTON_LEFT)
	var result := battle.placement.last_result
	if result == null or not result.accepted:
		_check(false, "viewport commits valid paid supply depot construction")
		return
	var site := await _ready_site(result)
	if site == null: return
	await _hud_pick_building(site.building())
	await _depot_capture("depot_construction_1280x720")
	if not await _complete_site(site): return
	var building := site.building()
	await _hud_pick_building(building)
	_check(panel.train_button.visible and panel.train_button.text.contains("Collector") and panel.train_button.text.contains("200") and panel.train_button.text.contains("6") and panel.selection_details.text.contains("450"), "selected depot context exposes health and correct collector production control")
	battle.tactical_minimap.refresh_markers()
	_check(battle.tactical_minimap.markers.any(func(marker: Dictionary) -> bool: return marker["identity"] == building.get_instance_id() and marker["kind"] == "supply_depot"), "normal registry refresh gives depot its distinct minimap marker")
	for index in 5: await _click(panel.train_button.get_global_rect().get_center(), MOUSE_BUTTON_LEFT)
	_check(building.production.count() == 5 and panel.cancel_buttons.size() == 5, "viewport production purchases full five-job collector queue")
	for dimensions in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		await _hud_layout(dimensions)
		await _depot_capture("depot_queue_%dx%d" % [dimensions.x, dimensions.y])
	var balance := battle.credits.balance(1)
	await _click(panel.cancel_buttons.values()[2].get_global_rect().get_center(), MOUSE_BUTTON_LEFT)
	_check(building.production.count() == 4 and battle.credits.balance(1) == balance + 200, "viewport collector cancellation refunds selected undeployed job")
	for job in building.production.jobs(): building.production.cancel(1, job["id"])
	root.size = Vector2i(1280, 720)
	await _frames(5)
	var truck := battle.collectors[0]
	truck.harvesting.cargo = 25 # Isolated viewport dispatch/accounting fixture.
	await _hud_pick_unit(truck)
	await _click(_world_screen(building.position + Vector3.UP), MOUSE_BUTTON_RIGHT)
	_check(truck.harvesting.dropoff_node() == building and not truck.harvesting.automatic and battle.harvest_panel.label.text.contains("Supply Depot"), "viewport right-click targets the explicit owned depot and shows its current dropoff name")
	await _depot_capture("collector_manual_return_1280x720")
	await _hud_key(KEY_X)
	_check(truck.harvesting.state == CollectorHarvest.State.IDLE and truck.harvesting.cargo == 25 and not truck.moving, "viewport X Stop interrupts depot return while retaining cargo")
	await _hud_key(KEY_2, true)
	await _hud_pick_unit(battle.units[0])
	await _hud_key(KEY_2)
	_check(battle.selection.selected_units() == [truck], "collector remains compatible with existing control-group assignment and recall")
	await _hud_pick_unit(battle.units[0])
	await _hud_key(KEY_Q)
	_check(battle.selection.attack_move_targeting, "existing Q combat attack-move targeting remains available")
	await _click(_world_screen(Vector3(-8, 0, 14)), MOUSE_BUTTON_LEFT)
	_check(battle.units[0].attack_move.active, "viewport combat attack-move still submits the existing combat order")
	await _hud_key(KEY_X)
	await _hud_key(KEY_F1)
	for dimensions in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		await _hud_layout(dimensions)
		await _depot_capture("depot_help_%dx%d" % [dimensions.x, dimensions.y])
	_check(battle.help_panel.is_open() and not battle.placement_guides.visible and not battle.movement_debug, "Help works while routine placement/access diagnostics remain hidden")
