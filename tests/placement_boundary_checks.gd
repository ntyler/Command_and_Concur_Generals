extends "res://tests/placement_feedback_checks.gd"
## Focused automated viewport playback on the normal Fortified geometry.
## Configured accounting funds and disabled enemy orders isolate placement;
## terrain, obstacles, reservations, builder path validation and costs are real.

const FAR_SUPPORTED := Vector3(-24, 0, 18)


func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1280, 720)
	var logger := EngineErrorProbe.new()
	OS.add_logger(logger)
	await _boundary_geometry()
	for size in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		root.size = size
		await _frames(3)
		await _viewport_builds(size)
		await _viewport_edges(size)
	if is_instance_valid(field): field.queue_free()
	await _frames(6)
	_check(root.get_children().is_empty(), "boundary teardown removes field and previews")
	OS.remove_logger(logger)
	_check(logger.error_count() == 0, "boundary checks have no native errors or warnings")
	print("PLACEMENT_BOUNDARY_CHECKS: %d checks, %d failures; native_errors=%d" % [checks, failures, logger.error_count()])
	quit(0 if failures == 0 else 1)


func _boundary_geometry() -> void:
	await _fresh_feedback()
	var area := powered.construction_area()
	_check(area.is_equal_approx(Rect2(-29.15, -23.15, 58.3, 46.3)), "builder area follows supported physical terrain with the original edge safety inset")
	_check(area != powered.camera_rig.map_bounds and area != ConstructionField.BUILD_AREA and powered.field_bounds == TestField.MAP_BOUNDS, "construction, camera and physical bounds remain separate; no world enlargement")
	var vertices := powered.navigation_region.navigation_mesh.vertices
	var nav_bounds := Rect2(Vector2(vertices[0].x, vertices[0].z), Vector2.ZERO)
	for vertex in vertices: nav_bounds = nav_bounds.expand(Vector2(vertex.x, vertex.z))
	_check(nav_bounds.is_equal_approx(area), "existing supported navigation perimeter remains unchanged")
	var actor := _player_builders()[0]
	for definition in [DEPOT, POWER_BARRACKS, POWER_PLANT]:
		var rectangle := Rect2(Vector2(FAR_SUPPORTED.x, FAR_SUPPORTED.z) - definition.footprint / 2.0, definition.footprint)
		_check(not ConstructionField.BUILD_AREA.encloses(rectangle.grow(TestField.CLEARANCE)), definition.display_name() + " regression point exceeds the obsolete local prototype box")
		await physics_frame
		var reason := powered.construction.validate(1, actor, definition, FAR_SUPPORTED)
		_check(reason.is_empty(), definition.display_name() + " accepts supported distant terrain and a reachable real builder work position: " + reason)
	for point in [Vector3(-26, 0, 18), Vector3(26, 0, 18), Vector3(0, 0, -20), Vector3(0, 0, 20)]:
		await physics_frame
		var conflict := powered.placement_boundary_conflict(point, POWER_PLANT)
		_check(powered.placement_geometry(point, POWER_PLANT) == ConstructionField.MAP_EDGE_REASON and not conflict.is_empty() and not conflict.edges.is_empty(), "real map-edge rejection identifies offending perimeter at %s" % point)
		var segments_outside := true
		for edge in conflict.edges:
			var midpoint: Vector2 = (edge["from"] + edge["to"]) / 2.0
			segments_outside = segments_outside and not area.has_point(midpoint)
		_check(segments_outside, "highlighted segments exclude supported portions of partly crossing edges")
	for item in [{"definition": POWER_BARRACKS, "point": Vector3(25, 0, 4.5), "kind": "production exit"}, {"definition": DEPOT, "point": Vector3(-10, 0, 19), "kind": "delivery access"}]:
		await physics_frame
		var conflict := powered.placement_boundary_conflict(item.point, item.definition)
		var reason := powered.placement_geometry(item.point, item.definition)
		_check(not conflict.is_empty() and conflict.kind == item.kind and reason == powered._boundary_reason(item.kind), "map edge separately retains the complete %s: %s" % [item.kind, reason])
	await physics_frame
	_check(powered.placement_geometry(HQ_DELIVERY_CONFLICT, POWER_PLANT) == "Blocks HQ delivery access", "boundary extension keeps specific protected delivery rejection")
	_check(powered.placement_geometry(powered.headquarters.global_position, POWER_PLANT).contains("building, obstacle"), "boundary extension keeps physical overlap rejection")
	var legacy := ConstructionField.new()
	_check(legacy.construction_area() == ConstructionField.BUILD_AREA, "explicit legacy HQ prototype retains its authored local construction area")
	legacy.free()


func _show_preview(definition: ConstructionDefinition, point: Vector3) -> void:
	var panel := powered.production_panel as ConstructionPanel
	var button := panel.depot_button if definition == DEPOT else panel.power_plant_button if definition == POWER_PLANT else panel.build_button
	_check(powered.selection.selected_units() == [_player_builders()[0]], "ordinary opening selects the real starting builder")
	await _click(button.get_global_rect().get_center(), MOUSE_BUTTON_LEFT)
	_check(powered.placement.active and powered.placement.definition == definition, "viewport construction button opens " + definition.display_name())
	powered.camera_rig.center_on_ground(point)
	await _frames(5)
	var screen := _world_screen(point)
	_check(root.get_visible_rect().has_point(screen), "candidate projects inside the actual viewport")
	# Native resize/scene-window motion can arrive after our first injected event.
	# Keep replaying the intended pointer until a visible, current advisory sample
	# exists; never accept a retained point from a missing-ground or hidden ghost.
	var settled := false
	for tick in 60:
		_motion(_world_screen(point))
		await _frames(1)
		var preview := powered.placement
		if preview.preview.visible and preview.point.distance_to(point) < 0.025 and preview._checked_point.distance_to(point) < 0.025 and not preview.reason.begins_with("Checking"):
			settled = true
			break
	_check(settled, "preview validates the current visible viewport raycast")


func _viewport_builds(size: Vector2i) -> void:
	var cases := [{"definition": DEPOT, "point": FEEDBACK_DEPOT, "label": "depot_near"}, {"definition": POWER_BARRACKS, "point": FEEDBACK_BARRACKS, "label": "barracks_near"}, {"definition": POWER_PLANT, "point": FEEDBACK_PLANT, "label": "plant_near"}, {"definition": DEPOT, "point": FAR_SUPPORTED, "label": "depot_far"}, {"definition": POWER_BARRACKS, "point": FAR_SUPPORTED, "label": "barracks_far"}, {"definition": POWER_PLANT, "point": FAR_SUPPORTED, "label": "plant_far"}]
	for item in cases:
		await _fresh_feedback()
		await _show_preview(item.definition, item.point)
		var preview := powered.placement
		_check(preview.valid and preview.boundary_conflict.is_empty() and preview.blocking_regions.is_empty(), item.label + " valid with accurate feedback at %s: %s" % [size, preview.reason])
		await _capture("boundary_%dx%d_%s" % [size.x, size.y, item.label])
		var guide_vertices: PackedVector3Array = powered.placement_guides.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var bounds := powered.construction_area()
		_check(guide_vertices.size() == 8 and Vector2(guide_vertices[0].x, guide_vertices[0].z).is_equal_approx(bounds.position) and Vector2(guide_vertices[3].x, guide_vertices[3].z).is_equal_approx(bounds.end), "visible green outline is the exact effective validation rectangle")
		var wallet := powered.credits.balance(1)
		await _click(_world_screen(item.point), MOUSE_BUTTON_LEFT)
		var result := preview.last_result
		_check(result != null and result.accepted and result.paid == item.definition.credit_cost and powered.credits.balance(1) == wallet - item.definition.credit_cost, item.label + " viewport click commits the normal cost exactly once")
		if result == null or not result.accepted: continue
		var site := _site(result)
		await _until(func() -> bool: return site.state != ConstructionSite.State.PREPARING, 6, "paid site prepares against the unchanged real navigation map")
		_check(site.builder() == _player_builders()[0] and site.work_access.size() > 0 and site.state in [ConstructionSite.State.TRAVELLING, ConstructionSite.State.CONSTRUCTING], "paid placement dispatches its builder to a reachable work position")


func _viewport_edges(size: Vector2i) -> void:
	for item in [{"definition": POWER_PLANT, "point": Vector3(-26, 0, 18), "label": "clearance_edge"}, {"definition": POWER_PLANT, "point": Vector3(-28.5, 0, 18), "label": "footprint_edge"}, {"definition": POWER_BARRACKS, "point": Vector3(25, 0, 4.5), "label": "exit_edge"}, {"definition": DEPOT, "point": Vector3(-10, 0, 19), "label": "delivery_edge"}]:
		await _fresh_feedback()
		await _show_preview(item.definition, item.point)
		var preview := powered.placement
		_check(not preview.valid and preview.reason.begins_with(ConstructionField.MAP_EDGE_REASON) and preview.conflict_indicator.visible and not preview.boundary_conflict.is_empty() and preview.blocking_regions.is_empty(), item.label + " displays specific map-edge feedback and exact offending segments: " + preview.reason)
		await _capture("boundary_%dx%d_%s" % [size.x, size.y, item.label])
		var wallet := powered.credits.balance(1)
		await _click(_world_screen(item.point), MOUSE_BUTTON_LEFT)
		_check(preview.active and preview.last_result != null and not preview.last_result.accepted and powered.credits.balance(1) == wallet and powered.construction.sites.is_empty(), "invalid viewport edge click cannot spend or create a site")
		await _click(_world_screen(item.point), MOUSE_BUTTON_RIGHT)
		_check(not preview.active and not paused and preview.boundary_conflict.is_empty() and not preview.conflict_indicator.visible, "right-click cancels map-edge preview without pausing or leaving stale highlights")
