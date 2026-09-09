extends "res://tests/power_checks.gd"
## Focused placement geometry and feedback regressions. The ordinary field owns
## the reservations; these tests do not alter navigation, resources, or unit motion.
## Native viewport acceptance is recorded separately from these input fixtures.

const FEEDBACK_DEPOT := Vector3(-10, 0, -6)
const FEEDBACK_BARRACKS := Vector3(-12, 0, 3)
const FEEDBACK_PLANT := Vector3(-21, 0, 3)
const HQ_DELIVERY_CONFLICT := Vector3(-20.5, 0, 1)


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1280, 720)
	var logger := EngineErrorProbe.new()
	OS.add_logger(logger)
	await _feedback_geometry()
	await _feedback_preview()
	await _feedback_lifecycle()
	if is_instance_valid(field): field.queue_free()
	await _frames(6)
	_check(root.get_children().is_empty(), "feedback teardown removes the field and all preview indicators")
	OS.remove_logger(logger)
	_check(logger.error_count() == 0, "placement feedback checks have no native errors or warnings")
	print("PLACEMENT_FEEDBACK_CHECKS: %d checks, %d failures; native_errors=%d" % [checks, failures, logger.error_count()])
	quit(0 if failures == 0 else 1)


func _owned_regions(owner_identity: int, reason_part: String = "") -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for region in powered.protected_regions():
		if region.owner_id == owner_identity and (reason_part.is_empty() or str(region.reason).to_lower().contains(reason_part)):
			found.append(region)
	return found


func _fresh_feedback() -> void:
	if is_instance_valid(field):
		field.queue_free()
		await _frames(5)
	powered = load("res://scenes/fortified_assault.tscn").instantiate() as PowerAssaultField
	powered.starting_credits = 4000 # Isolated accounting fixture; normal scene geometry.
	builders = powered
	battle = powered
	world = powered
	harvest = powered
	field = powered
	root.add_child(powered)
	current_scene = powered
	powered.camera_rig.edge_scrolling_enabled = false
	powered.enemy_controller.set_physics_process(false)
	for actor in powered.units:
		if actor.owner_id == 2:
			actor.stop()
			actor.set_physics_process(false)
	await _until(_builder_navigation_current, 2, "normal Fortified scene synchronizes real actor navigation starts")
	_check(powered.scene_file_path == "res://scenes/fortified_assault.tscn" and powered.construction.sites.is_empty(), "feedback fixture uses the normal playable scene with no existing player sites")


func _overlap_with(point: Vector3, identity: String) -> Dictionary:
	for region in powered.overlapping_protected_regions(point, POWER_PLANT):
		if region.id == identity: return region
	return {}


func _feedback_geometry() -> void:
	await _fresh_feedback()
	var identities: Dictionary = {}
	var metadata_valid := true
	for region in powered.protected_regions():
		metadata_valid = metadata_valid and not str(region.id).is_empty() and not identities.has(region.id)
		metadata_valid = metadata_valid and region.owner_id > 0 and not str(region.owner_name).is_empty() and not str(region.reason).is_empty()
		metadata_valid = metadata_valid and str(region.reason) != "Protected deposit, supply, exit or access corridor"
		identities[region.id] = true
	_check(metadata_valid and not identities.is_empty(), "reservations have unique identities, specific reasons and actual object owners")
	var delivery := _owned_regions(powered.headquarters.get_instance_id(), "delivery")
	_check(delivery.size() == powered.access_positions(powered.headquarters).size(), "HQ delivery reservations identify each real docking bay")
	var actual_bays: Array[Rect2] = []
	for access in powered.access_positions(powered.headquarters):
		var dock: Vector3 = access.dock
		var point: Vector3 = access.point
		actual_bays.append(Rect2(Vector2(point.x, point.z), Vector2(dock.x - point.x, dock.z - point.z)).abs().grow(0.7))
	_check(delivery.all(func(region: Dictionary) -> bool: return actual_bays.has(region.rectangle)), "HQ reservations follow actual docking geometry without shifted or oversized rectangles")
	if delivery.is_empty(): return
	var target: Dictionary = delivery[0]
	var reserved: Rect2 = target.rectangle
	var half_width := POWER_PLANT.footprint.x / 2.0
	var edge_point := Vector3(reserved.end.x + half_width - 0.15, 0, reserved.get_center().y)
	var edge := _overlap_with(edge_point, target.id)
	_check(not reserved.has_point(Vector2(edge_point.x, edge_point.z)) and not edge.is_empty(), "full footprint edge rejects overlap even though its preview center lies outside the reservation")
	if not edge.is_empty():
		_check(not edge.clearance_only and (edge.footprint as Rect2).intersects(reserved), "body overlap is distinguished from a clearance-only conflict")
	var margin_point := Vector3(reserved.end.x + half_width + ConstructionField.CLEARANCE / 2.0, 0, reserved.get_center().y)
	var margin := _overlap_with(margin_point, target.id)
	_check(not margin.is_empty(), "clearance margin detects an overlapping region even with the complete solid footprint outside")
	if not margin.is_empty():
		var footprint := Rect2(Vector2(margin_point.x, margin_point.z) - POWER_PLANT.footprint / 2.0, POWER_PLANT.footprint)
		_check(margin.clearance_only and margin.footprint == footprint and margin.clearance == footprint.grow(ConstructionField.CLEARANCE), "feedback retains full proposed footprint and exact ordinary clearance margin")
		_check(margin.overlap == footprint.grow(ConstructionField.CLEARANCE).intersection(reserved) and margin.owner_id == powered.headquarters.get_instance_id(), "highlight overlap is clipped to the exact reservation and identifies its HQ owner")
	var outside := Vector3(reserved.end.x + half_width + ConstructionField.CLEARANCE + 0.05, 0, reserved.get_center().y)
	_check(_overlap_with(outside, target.id).is_empty(), "moving beyond the complete clearance removes that reservation from current blockers")
	await physics_frame
	var denial := powered.placement_geometry(HQ_DELIVERY_CONFLICT, POWER_PLANT)
	var conflicts := powered.overlapping_protected_regions(HQ_DELIVERY_CONFLICT, POWER_PLANT)
	_check(denial == "Blocks HQ delivery access" and conflicts.any(func(region: Dictionary) -> bool: return region.owner_id == powered.headquarters.get_instance_id() and region.reason == denial), "ordinary HQ south-bay rejection names its actual delivery access owner")
	print("PLACEMENT_FEEDBACK_HQ: point=%s reason=%s blockers=%s" % [HQ_DELIVERY_CONFLICT, denial, conflicts])
	var corridor_point := Vector3(-11, 0, -6)
	var corridor := powered.overlapping_protected_regions(corridor_point, DEPOT)
	_check(corridor.size() == 1 and corridor[0].id == "map/access/1" and corridor[0].owner_id == powered.get_instance_id(), "west Depot preview identifies only the normal map-owned HQ approach corridor")
	if corridor.size() == 1:
		_check((corridor[0].overlap as Rect2).is_equal_approx(Rect2(-14.85, -9.35, 0.85, 5.05)) and powered.placement_geometry(corridor_point, DEPOT) == "Blocks HQ approach corridor", "HQ approach rejection reports the actual full-edge and clearance intersection")
	for candidate in [{"definition": DEPOT, "point": FEEDBACK_DEPOT}, {"definition": POWER_BARRACKS, "point": FEEDBACK_BARRACKS}, {"definition": POWER_PLANT, "point": FEEDBACK_PLANT}]:
		var definition: ConstructionDefinition = candidate.definition
		var position: Vector3 = candidate.point
		var reason := powered.placement_geometry(position, definition)
		_check(reason.is_empty() and powered.overlapping_protected_regions(position, definition).is_empty(), "%s has a genuinely open full footprint at %s: %s" % [definition.display_name(), position, reason])
		print("PLACEMENT_FEEDBACK_VALID: building=%s point=%s reason=%s" % [definition.display_name(), position, reason])
	_check(not powered.placement_geometry(powered.headquarters.global_position, POWER_PLANT).is_empty(), "specific access feedback retains physical building-overlap rejection")
	_check(not powered.placement_geometry(Vector3(-27, 0, 21), POWER_PLANT).is_empty(), "specific access feedback retains full-footprint build-boundary rejection")


func _feedback_preview() -> void:
	await _fresh_feedback()
	var actor := _player_builders()[0]
	powered.selection.select_clicked(actor, false)
	_check(powered.placement.begin(actor, POWER_PLANT), "selected ordinary builder can enter plant placement")
	_motion(_world_screen(HQ_DELIVERY_CONFLICT))
	await _frames(10)
	var preview := powered.placement
	_check(not preview.valid and preview.status.text.contains("Blocks HQ delivery access"), "viewport pointer input exposes an understandable HQ delivery rejection")
	_check(preview.conflict_indicator.visible and preview.clearance_indicator.visible and not preview.blocking_regions.is_empty(), "invalid preview displays its current conflicts and full clearance boundary")
	var guide_vertices: PackedVector3Array = powered.placement_guides.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	_check(preview.blocking_regions.size() < powered.protected_regions().size() and guide_vertices.size() == 8, "ordinary placement keeps the green build boundary but excludes unrelated protected-region guides")
	_check(preview.blocking_regions.all(func(region: Dictionary) -> bool: return (region.clearance as Rect2).intersects(region.rectangle, true)), "every highlighted region actually intersects the current full clearance")
	# Observe a normal advisory refresh; do not shorten or overwrite its cadence.
	await _until(func() -> bool: return preview._cooldown > 0.08, 0.3, "pointer regression starts just after an ordinary throttled advisory check")
	var previous_checked_point := preview._checked_point
	_motion(_world_screen(FEEDBACK_PLANT))
	await _frames(1)
	_check(preview.point.distance_to(FEEDBACK_PLANT) < 0.02 and preview._checked_point.is_equal_approx(previous_checked_point), "pointer updates the ghost before the next expensive placement validation")
	_check(not preview.valid and preview.status.text.begins_with("Checking placement") and preview.blocking_regions.is_empty() and not preview.conflict_indicator.visible, "moving before the advisory refresh shows neutral feedback without an old approval or conflict")
	var outline := preview.clearance_indicator.mesh.get_aabb()
	var outline_center := outline.get_center() + preview.clearance_indicator.position
	var expected_clearance := POWER_PLANT.footprint + Vector2.ONE * ConstructionField.CLEARANCE * 2.0
	_check(Vector2(outline_center.x, outline_center.z).distance_to(Vector2(preview.point.x, preview.point.z)) < 0.02 and Vector2(outline.size.x, outline.size.z).distance_to(expected_clearance) < 0.15, "neutral clearance outline follows the current complete footprint on the first moved tick")
	await _frames(10)
	_check(preview.valid and preview.status.text.begins_with("Valid") and preview.preview.visible and preview.clearance_indicator.visible, "moving into open ground restores clear valid feedback")
	_check(preview.blocking_regions.is_empty() and not preview.conflict_indicator.visible, "previous rejection cannot leave stale highlighted conflicts on valid ground")
	preview.cancel()
	_check(not preview.clearance_indicator.visible and not preview.conflict_indicator.visible and preview.blocking_regions.is_empty(), "cancelling the preview clears both placement indicators and current blockers")


func _feedback_lifecycle() -> void:
	await _fresh_feedback()
	var depot := _power_fixture_building(DEPOT, 1, FEEDBACK_DEPOT)
	var depot_id := depot.get_instance_id()
	_check(_owned_regions(depot_id, "delivery").size() == depot.deposit_access_positions().size(), "living registered Supply Depot reserves each actual delivery bay")
	var depot_conflict := Vector3(FEEDBACK_DEPOT.x, 0, 1.6)
	await physics_frame
	_check(powered.placement_geometry(depot_conflict, POWER_PLANT).contains("Supply Depot delivery"), "real Supply Depot delivery access still rejects a conflicting plant")
	depot.queue_free()
	_check(_owned_regions(depot_id).is_empty(), "queued-for-deletion depot cannot retain delivery or exit reservations")
	await _frames(4)
	var producer := await _power_build(_player_builders()[0], POWER_BARRACKS, FEEDBACK_BARRACKS)
	if producer == null: return
	var producer_id := producer.get_instance_id()
	var exits := _owned_regions(producer_id, "exit")
	_check(exits.size() == 1, "normally completed production building reserves its true deployment exit")
	await physics_frame
	_check(powered.placement_geometry(Vector3(-2.7, 0, 3), POWER_PLANT).contains("Barracks production exit"), "genuine Barracks deployment neighborhood remains protected from nearby construction")
	producer.health.apply_damage(10000)
	_check(_owned_regions(producer_id).is_empty(), "destroyed producer drops its reservation immediately")
	await _frames(4)
	for removal in ["cancel", "destroy", "detach"]:
		await _fresh_feedback()
		var actor := _player_builders()[0]
		var result := await _builder_place(actor, DEPOT, FEEDBACK_DEPOT)
		_check(result.accepted and result.paid == DEPOT.credit_cost, "ordinary paid Depot site commits for " + removal + " reservation cleanup")
		if not result.accepted: continue
		var site := _site(result)
		var body := site.building()
		var identity := body.get_instance_id()
		_check(not _owned_regions(identity, "delivery").is_empty() and not _owned_regions(identity, "exit").is_empty(), "unfinished depot immediately protects delivery access and production exit")
		if removal == "cancel":
			_check(powered.construction.cancel(1, site.site_id).accepted, "existing unfinished-site cancellation remains available")
		elif removal == "detach":
			body.reparent(root)
		else:
			body.queue_free()
		_check(_owned_regions(identity).is_empty(), removal + " excludes site-owned reservations before deferred navigation cleanup")
		if removal == "detach": body.queue_free()
		await _until(func() -> bool: return powered.construction.sites.is_empty() and not powered.construction.navigation.blocked, 6, removal + " finishes ordinary synchronized site cleanup")
		_check(_owned_regions(identity).is_empty() and powered.credits.balance(1) == 4000, removal + " leaves no stale owner records and preserves the existing captured-cost refund")
