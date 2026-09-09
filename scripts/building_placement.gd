class_name BuildingPlacement
extends Node
## GUI receives inputs first; all world validation and confirmations run in physics.

var field: ConstructionField
var active: bool = false
var preview: MeshInstance3D
var range_indicator: MeshInstance3D
var clearance_indicator: MeshInstance3D
var conflict_indicator: MeshInstance3D
var blocking_regions: Array[Dictionary] = []
var boundary_conflict: Dictionary = {}
var status: Label
var reason: String = ""
var point := Vector3.ZERO
var valid: bool = false
var last_result: ConstructionResult
var definition: ConstructionDefinition
var orientation_degrees: int = 0
var _source: WeakRef
var _owner: int = 0
var _pointer := Vector2.ZERO
var _pending: Array[Vector2] = []
var _generation: int = 0
var _cooldown: float = 0.0
var _checked_point := Vector3.INF
var _checked_orientation: int = -1
var _ray := PhysicsRayQueryParameters3D.new()
var _material := StandardMaterial3D.new()


func _ready() -> void:
	_ray.collision_mask = 1
	preview = MeshInstance3D.new()
	preview.name = "PlacementGhost"
	var box := BoxMesh.new()
	box.size = Vector3(field.construction_definition.footprint.x, field.construction_definition.height, field.construction_definition.footprint.y)
	preview.mesh = box
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.albedo_color = Color(0.4, 1.0, 0.7, 0.35)
	preview.material_override = _material
	preview.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	field.add_child(preview)
	preview.hide()
	range_indicator = MeshInstance3D.new()
	range_indicator.name = "DefensePlacementRange"
	range_indicator.material_override = _material
	range_indicator.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	field.add_child(range_indicator)
	range_indicator.hide()
	clearance_indicator = _guide_node("PlacementClearance")
	conflict_indicator = _guide_node("PlacementConflicts")
	status = Label.new()
	status.position = Vector2(430, 20)
	status.size = Vector2(460, 70)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	field.get_node("ControlsFeedback").add_child(status)
	status.hide()


func begin(source: Variant, choice: ConstructionDefinition = null) -> bool:
	var owner := field.selection.friendly_owner_id
	var requested := choice if choice != null else field.construction_definition
	reason = field.construction.can_begin(owner, source, requested)
	if not reason.is_empty():
		return false
	definition = requested
	orientation_degrees = 0
	(preview.mesh as BoxMesh).size = Vector3(definition.footprint.x, definition.height, definition.footprint.y)
	range_indicator.hide()
	if definition.kind in [RTSBuilding.Kind.GROUND_DEFENSE_BATTERY, RTSBuilding.Kind.AIR_DEFENSE_BATTERY] and definition.weapon_data != null:
		var ring := TorusMesh.new()
		ring.inner_radius = maxf(0.0, definition.weapon_data.attack_range - 0.06)
		ring.outer_radius = definition.weapon_data.attack_range + 0.06
		ring.rings = 64
		ring.ring_segments = 6
		range_indicator.mesh = ring
	_generation += 1
	_owner = owner
	# A preview has no gameplay side effects. The manager replaces the source's
	# earlier order only after authoritative placement has committed successfully.
	_source = weakref(source)
	active = true
	valid = false
	blocking_regions.clear()
	boundary_conflict.clear()
	_pending.clear()
	field.selection.cancel_gesture()
	field.selection._pending_picks.clear()
	field.selection.placement_active = true
	_cooldown = 0.0
	_checked_point = Vector3.INF
	status.show()
	field.update_placement_guides_visibility()
	return true


func cancel() -> void:
	_generation += 1
	active = false
	valid = false
	blocking_regions.clear()
	boundary_conflict.clear()
	_pending.clear()
	if is_instance_valid(field) and is_instance_valid(field.selection):
		field.selection.placement_active = false
		field.update_placement_guides_visibility()
	if is_instance_valid(preview):
		preview.hide()
	if is_instance_valid(range_indicator):
		range_indicator.hide()
	if is_instance_valid(clearance_indicator):
		clearance_indicator.hide()
	if is_instance_valid(conflict_indicator):
		conflict_indicator.hide()
	if is_instance_valid(status):
		status.hide()


func _input(event: InputEvent) -> void:
	# Preview cancellation owns right-click before pointer-only HUD surfaces
	# (including the minimap) can consume it. Active matches give Escape to Pause.
	if active and field.builder_construction_enabled and event is InputEventMouseButton and event.is_action_pressed("placement_cancel"):
		cancel()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseMotion:
		_pointer = event.position


func _unhandled_input(event: InputEvent) -> void:
	if not active:
		return
	if field is BaseAssaultField and event is InputEventKey and event.physical_keycode == KEY_ESCAPE:
		return # The match pause menu owns this key, including preview cancellation.
	if event is InputEventKey and event.pressed and not event.echo and not event.ctrl_pressed and not event.alt_pressed and not event.meta_pressed and event.physical_keycode == KEY_R and definition.is_barrier():
		rotate_orientation()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("placement_cancel") and not event.is_echo():
		cancel()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("placement_confirm") and not field.camera_rig.pointer_over_interface():
		_pending.append((event as InputEventMouseButton).position)
		get_viewport().set_input_as_handled()
	elif event.is_action_released("placement_confirm"):
		get_viewport().set_input_as_handled()


func _physics_process(delta: float) -> void:
	if not active:
		return
	var source := _source.get_ref() as Node3D if _source != null else null
	var version := _generation
	# Snapshot inputs: listener callbacks may cancel or start a new placement.
	var requests := _pending.duplicate()
	_pending.clear()
	for screen in requests:
		var hit := _ground(screen)
		if hit.is_empty():
			reason = "Point at supported flat terrain"
			continue
		var manager := field.construction
		var result := manager.place(_owner, source, definition, hit["position"], orientation_degrees)
		if not is_instance_valid(self) or not is_instance_valid(field):
			return
		last_result = result
		if version != _generation:
			return
		reason = last_result.reason
		if last_result.accepted:
			var site := manager.sites.get(last_result.site_id) as ConstructionSite
			cancel()
			# Legacy HQ placement selects its new site. Builder placement keeps the
			# builder selected so its travel/work state and X Stop remain contextual.
			if is_instance_valid(source) and source is RTSBuilding and site != null and is_instance_valid(site.building()) and field.contains_building(site.building()) and field.selection.selected_building() == source:
				field.selection.select_building(site.building())
			return
	_cooldown -= delta
	# Interactive HUD motion must not relocate the free preview behind the panel.
	if field.camera_rig.pointer_over_interface():
		preview.hide()
		range_indicator.hide()
		clearance_indicator.hide()
		conflict_indicator.hide()
		status.hide()
		return
	status.show()
	var hit := _ground(_pointer)
	preview.visible = not hit.is_empty() and not field.camera_rig.pointer_over_interface()
	range_indicator.visible = preview.visible and definition.kind in [RTSBuilding.Kind.GROUND_DEFENSE_BATTERY, RTSBuilding.Kind.AIR_DEFENSE_BATTERY]
	if not hit.is_empty():
		point = field.construction_point(hit["position"], definition)
		preview.position = point + Vector3.UP * definition.height / 2.0
		range_indicator.position = point + Vector3.UP * 0.08
	if _cooldown <= 0.0:
		_cooldown = 0.1
		_checked_point = point
		_checked_orientation = orientation_degrees
		reason = field.construction.validate(_owner, source, definition, point, orientation_degrees) if not hit.is_empty() else "Point at supported flat terrain"
		valid = reason.is_empty()
		blocking_regions.clear()
		boundary_conflict.clear()
		if not hit.is_empty():
			var boundary := field.placement_boundary_conflict(point, definition, orientation_degrees)
			if not boundary.is_empty() and reason == field._boundary_reason(boundary.kind):
				boundary_conflict = boundary
			var overlaps := field.overlapping_protected_regions(point, definition, orientation_degrees)
			# Do not blame an access region when another authoritative check rejected
			# first (funds, boundary, occupied geometry, or unavailable builder).
			if not overlaps.is_empty() and reason == overlaps[0]["reason"]:
				blocking_regions = overlaps
		_material.albedo_color = Color(0.35, 1, 0.65, 0.35) if valid else Color(1, 0.25, 0.2, 0.4)
		_refresh_feedback_geometry(not hit.is_empty())
		var explanation := reason
		if not blocking_regions.is_empty() and blocking_regions.all(func(region: Dictionary) -> bool: return region["clearance_only"]):
			explanation += " · clearance overlap"
		status.text = ("Valid · %d credits · left click to build" % definition.credit_cost if valid else "Cannot build · " + explanation) + "\n" + _controls_hint()
		if definition.is_barrier():
			status.text += "\n%s · %d° · R rotate · 1-unit grid" % [definition.display_name(), orientation_degrees]
	elif not point.is_equal_approx(_checked_point) or orientation_degrees != _checked_orientation:
		# Never show a previous location's approval or conflicts on a moving ghost.
		# Builder access queries retain their existing 10 Hz cadence.
		valid = false
		blocking_regions.clear()
		boundary_conflict.clear()
		reason = "Checking placement"
		_material.albedo_color = Color(0.75, 0.85, 0.85, 0.35)
		_refresh_feedback_geometry(not hit.is_empty(), true)
		status.text = "Checking placement…\n" + _controls_hint()
	clearance_indicator.visible = preview.visible
	conflict_indicator.visible = preview.visible and (not blocking_regions.is_empty() or not boundary_conflict.is_empty())


func _controls_hint() -> String:
	var boundary := "Green · supported map limit. " if field.builder_construction_enabled else "Green · construction boundary. "
	return boundary + "Outline · clearance.\nRight click · Cancel. " + ("Esc · Pause" if field is BaseAssaultField else "Esc · Cancel")


func _guide_node(identity: String) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = identity
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	field.add_child(node)
	node.hide()
	return node


func _guide_fill(mesh: ImmediateMesh, rectangle: Rect2, color: Color, elevation: float) -> void:
	mesh.surface_set_color(color)
	var corners := [rectangle.position, Vector2(rectangle.end.x, rectangle.position.y), rectangle.end, Vector2(rectangle.position.x, rectangle.end.y)]
	for index in [0, 1, 2, 0, 2, 3]:
		var corner: Vector2 = corners[index]
		mesh.surface_add_vertex(Vector3(corner.x, elevation, corner.y))


func _guide_outline(mesh: ImmediateMesh, rectangle: Rect2, color: Color) -> void:
	# Thin ribbons remain legible at game zoom; their centers follow exact bounds.
	const WIDTH := 0.08
	_guide_fill(mesh, Rect2(rectangle.position - Vector2.ONE * WIDTH / 2.0, Vector2(rectangle.size.x + WIDTH, WIDTH)), color, 0.07)
	_guide_fill(mesh, Rect2(Vector2(rectangle.position.x - WIDTH / 2.0, rectangle.end.y - WIDTH / 2.0), Vector2(rectangle.size.x + WIDTH, WIDTH)), color, 0.07)
	_guide_fill(mesh, Rect2(rectangle.position - Vector2.ONE * WIDTH / 2.0, Vector2(WIDTH, rectangle.size.y + WIDTH)), color, 0.07)
	_guide_fill(mesh, Rect2(Vector2(rectangle.end.x - WIDTH / 2.0, rectangle.position.y - WIDTH / 2.0), Vector2(WIDTH, rectangle.size.y + WIDTH)), color, 0.07)


func _refresh_feedback_geometry(has_ground: bool, checking: bool = false) -> void:
	if not has_ground:
		return
	var footprint := definition.oriented_footprint(orientation_degrees)
	var rectangle := Rect2(Vector2(point.x, point.z) - footprint / 2.0, footprint)
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var color := Color(0.8, 0.9, 0.9, 0.95) if checking else Color(0.35, 1, 0.65, 0.95) if valid else Color(1, 0.45, 0.3, 0.95)
	_guide_outline(mesh, rectangle.grow(field.CLEARANCE), color)
	mesh.surface_end()
	clearance_indicator.mesh = mesh
	if blocking_regions.is_empty() and boundary_conflict.is_empty():
		conflict_indicator.mesh = null
		return
	mesh = ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	if not boundary_conflict.is_empty():
		# The brighter red segments are only the unsupported parts of the exact
		# footprint/clearance, exit or delivery-access perimeter that was rejected.
		for edge in boundary_conflict.edges:
			var start: Vector2 = edge["from"]
			var end: Vector2 = edge["to"]
			_guide_fill(mesh, Rect2(start.min(end), (end - start).abs()).grow(0.09), Color(1, 0.08, 0.03, 1), 0.1)
	for region in blocking_regions:
		_guide_fill(mesh, region["rectangle"], Color(1, 0.5, 0.2, 0.22), 0.035)
		_guide_outline(mesh, region["rectangle"], Color(1, 0.5, 0.2, 1))
		if (region["overlap"] as Rect2).has_area():
			_guide_fill(mesh, region["overlap"], Color(1, 0.16, 0.1, 0.72), 0.05)
	mesh.surface_end()
	conflict_indicator.mesh = mesh


func rotate_orientation() -> void:
	if not active or not field.gameplay_enabled or definition == null or not definition.is_barrier():
		return
	# A queued click refers to the prior preview; rotating requires a new click.
	_pending.clear()
	orientation_degrees = 90 if orientation_degrees == 0 else 0
	var footprint := definition.oriented_footprint(orientation_degrees)
	(preview.mesh as BoxMesh).size = Vector3(footprint.x, definition.height, footprint.y)
	_cooldown = 0.0


func _ground(screen: Vector2) -> Dictionary:
	var camera := field.camera_rig.camera
	_ray.from = camera.project_ray_origin(screen)
	_ray.to = _ray.from + camera.project_ray_normal(screen) * 250.0
	return field.get_world_3d().direct_space_state.intersect_ray(_ray)


func _exit_tree() -> void:
	cancel()
	if is_instance_valid(preview) and not preview.is_queued_for_deletion():
		preview.queue_free()
	if is_instance_valid(range_indicator) and not range_indicator.is_queued_for_deletion():
		range_indicator.queue_free()
	if is_instance_valid(clearance_indicator) and not clearance_indicator.is_queued_for_deletion():
		clearance_indicator.queue_free()
	if is_instance_valid(conflict_indicator) and not conflict_indicator.is_queued_for_deletion():
		conflict_indicator.queue_free()
	if is_instance_valid(status) and not status.is_queued_for_deletion():
		status.queue_free()
