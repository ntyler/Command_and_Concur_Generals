extends "res://tests/construction_checks.gd"
## Separately exercise cancellation restoration failure, not preparation failure.
## Injection changes only mesh preparation; refund/cancellation/timeout stay real.


func _run() -> void:
	root.size = Vector2i(1280, 800)
	var logger := EngineErrorProbe.new()
	OS.add_logger(logger)
	for stale in [false, true]:
		await _cleanup_failure(stale)
	if is_instance_valid(world):
		world.queue_free()
	await _frames(5)
	_check(root.get_children().is_empty(), "cleanup diagnostic leaves no scene nodes")
	OS.remove_logger(logger)
	_check(logger.error_count() == 0, "cleanup diagnostic has no native errors or warnings")
	print("CONSTRUCTION_CLEANUP_CHECKS: %d checks, %d failures; native_errors=%d" % [checks, failures, logger.error_count()])
	quit(0 if failures == 0 else 1)


func _cleanup_failure(stale: bool) -> void:
	if is_instance_valid(world):
		world.queue_free()
		await _frames(4)
	world = UnsynchronizedConstructionField.new() if stale else FailingConstructionField.new()
	if stale:
		(world as UnsynchronizedConstructionField).stale_mesh = false
	else:
		(world as FailingConstructionField).refuse_mesh = false
	field = world
	harvest = world
	root.add_child(world)
	current_scene = world
	world.camera_rig.edge_scrolling_enabled = false
	await _frames(5)
	var manager := world.construction
	var site := await _ready_site(await _place())
	if site == null:
		return
	_check(not world._nav_point(FIRST) and world.credits.balance(1) == 600, "ordinary paid site first synchronizes a real navigation hole")
	var old_ready := site.nav_generation
	var body := site.building()
	if stale:
		(world as UnsynchronizedConstructionField).stale_mesh = true
	else:
		(world as FailingConstructionField).refuse_mesh = true
	var started := Engine.get_physics_frames()
	var result := manager.cancel(1, site.site_id)
	_check(result.accepted and site.refunded and world.credits.balance(1) == 1000, "cancellation commits one original-cost refund before restoration")
	_check(body.collision_layer == 0 and not body.operational and world._producers.is_empty() and world.obstacles.size() == 5, "cancellation immediately removes collider eligibility, producer and authoritative footprint")
	var cancellation_generation := site.nav_generation
	_check(cancellation_generation > old_ready, "cleanup owns a fresh navigation generation")
	await _until(func() -> bool: return not manager.navigation.busy and manager.navigation.blocked, 5.5, "restoration reaches bounded blocked fallback")
	var elapsed := float(Engine.get_physics_frames() - started) / Engine.physics_ticks_per_second
	print("CLEANUP_FAILURE: stale_mesh=%s elapsed=%.6f reason=%s" % [stale, elapsed, site.reason])
	_check(not stale or elapsed >= world.navigation_timeout, "synchronization failure obeys the unchanged five-second deadline")
	_check(not is_instance_valid(body) and not world._nav_point(FIRST), "failed restoration leaves old navigation hole but no building body")
	await physics_frame
	var ray := PhysicsRayQueryParameters3D.create(FIRST + Vector3(-4, 1, 0), FIRST + Vector3(4, 1, 0), 4 | 8)
	_check(world.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(), "removed footprint no longer blocks physical or weapon ray")
	_check(site.state == ConstructionSite.State.CANCELLING and manager.unfinished_id == site.site_id and manager.navigation.blocked, "fallback intentionally retains slot and blocks navigation")
	var suspended := true
	for unit in world.units:
		suspended = suspended and unit.navigation_suspended
	_check(suspended, "units cannot silently continue on inconsistent navigation")
	_check(not manager.cancel(1, site.site_id).accepted and world.credits.balance(1) == 1000, "repeated cancellation cannot refund twice")
	manager._navigation_ready(old_ready) # Deliberately deliver obsolete preparation notification.
	_check(site.state == ConstructionSite.State.CANCELLING and site.nav_generation == cancellation_generation, "obsolete preparation callback cannot restore cancelled work")
	var rejected := await _place(SECOND)
	_check(not rejected.accepted and rejected.reason.contains("Reload") and world.credits.balance(1) == 1000, "further construction rejects with explicit reload reason without spending")
	world.selection.select_building(world.headquarters)
	await _frames(2)
	var panel := world.production_panel as ConstructionPanel
	_check(panel.build_button.disabled and panel.feedback.visible and panel.feedback.text.contains("Reload"), "selected HQ exposes disabled build and written reload-required feedback")
	var submissions := manager.navigation.submissions
	await _frames(120)
	_check(manager.navigation.submissions == submissions and world.credits.balance(1) == 1000 and manager.unfinished_id == site.site_id, "fallback neither retries nor unlocks or charges later")
	var old_nav := manager.navigation
	var old_wallet := world.credits
	await _fresh_construction()
	_check(manager.closed and manager.sites.is_empty() and old_nav.ready.get_connections().is_empty() and old_nav.failed.get_connections().is_empty() and not old_wallet.active, "reload closes old wallet, sites and navigation signals")
	manager._navigation_ready(cancellation_generation)
	old_nav.advance(10)
	_check(world.credits.balance(1) == 1000 and world.construction.unfinished_id == 0 and not world.construction.navigation.blocked and world._nav_point(FIRST), "replacement scene is clean and ignores old cleanup callbacks")
