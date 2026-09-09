class_name BuildingPlacement
extends Node
## GUI receives inputs first; all world validation and confirmations run in physics.

var field: ConstructionField
var active: bool = false
var preview: MeshInstance3D
var range_indicator: MeshInstance3D
var status: Label
var reason: String = ""
var point := Vector3.ZERO
var valid: bool = false
var last_result: ConstructionResult
var definition: ConstructionDefinition
var _source: WeakRef
var _owner: int = 0
var _pointer := Vector2.ZERO
var _pending: Array[Vector2] = []
var _generation: int = 0
var _cooldown: float = 0.0
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
	_pending.clear()
	field.selection.cancel_gesture()
	field.selection._pending_picks.clear()
	field.selection.placement_active = true
	_cooldown = 0.0
	status.show()
	field.update_placement_guides_visibility()
	return true


func cancel() -> void:
	_generation += 1
	active = false
	valid = false
	_pending.clear()
	if is_instance_valid(field) and is_instance_valid(field.selection):
		field.selection.placement_active = false
		field.update_placement_guides_visibility()
	if is_instance_valid(preview):
		preview.hide()
	if is_instance_valid(range_indicator):
		range_indicator.hide()
	if is_instance_valid(status):
		status.hide()


func _input(event: InputEvent) -> void:
	# Preview cancellation owns right-click before pointer-only HUD surfaces
	# (including the minimap) can consume it. Escape still gives Help first refusal.
	if active and field.builder_construction_enabled and event is InputEventMouseButton and event.is_action_pressed("placement_cancel"):
		cancel()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseMotion:
		_pointer = event.position


func _unhandled_input(event: InputEvent) -> void:
	if not active:
		return
	if event.is_action_pressed("placement_cancel") and not event.is_echo():
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
			reason = "Point at flat ground inside the green boundary"
			continue
		var manager := field.construction
		var result := manager.place(_owner, source, definition, hit["position"])
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
		return
	var hit := _ground(_pointer)
	preview.visible = not hit.is_empty() and not field.camera_rig.pointer_over_interface()
	range_indicator.visible = preview.visible and definition.kind in [RTSBuilding.Kind.GROUND_DEFENSE_BATTERY, RTSBuilding.Kind.AIR_DEFENSE_BATTERY]
	if not hit.is_empty():
		point = hit["position"]
		preview.position = point + Vector3.UP * definition.height / 2.0
		range_indicator.position = point + Vector3.UP * 0.08
	if _cooldown <= 0.0:
		_cooldown = 0.1
		reason = field.construction.validate(_owner, source, definition, point) if not hit.is_empty() else "Point at flat ground inside the green boundary"
		valid = reason.is_empty()
		_material.albedo_color = Color(0.35, 1, 0.65, 0.35) if valid else Color(1, 0.25, 0.2, 0.4)
		status.text = ("Valid · %d credits · left click to build" % definition.credit_cost if valid else "Cannot build · " + reason) + "\nRight click / Escape · Cancel placement"


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
	if is_instance_valid(status) and not status.is_queued_for_deletion():
		status.queue_free()
