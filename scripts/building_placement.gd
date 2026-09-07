class_name BuildingPlacement
extends Node
## GUI receives inputs first; all world validation and confirmations run in physics.

var field: ConstructionField
var active: bool = false
var preview: MeshInstance3D
var status: Label
var reason: String = ""
var point := Vector3.ZERO
var valid: bool = false
var last_result: ConstructionResult
var definition: ConstructionDefinition
var _headquarters: WeakRef
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
	status = Label.new()
	status.position = Vector2(430, 20)
	status.size = Vector2(460, 70)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	field.get_node("ControlsFeedback").add_child(status)
	status.hide()


func begin(headquarters: Variant, choice: ConstructionDefinition = null) -> bool:
	var owner := field.selection.friendly_owner_id
	var requested := choice if choice != null else field.construction_definition
	reason = field.construction.can_begin(owner, headquarters, requested)
	if not reason.is_empty():
		return false
	definition = requested
	(preview.mesh as BoxMesh).size = Vector3(definition.footprint.x, definition.height, definition.footprint.y)
	_generation += 1
	_owner = owner
	_headquarters = weakref(headquarters)
	active = true
	valid = false
	_pending.clear()
	field.selection.cancel_gesture()
	field.selection._pending_picks.clear()
	field.selection.placement_active = true
	_cooldown = 0.0
	status.show()
	return true


func cancel() -> void:
	_generation += 1
	active = false
	valid = false
	_pending.clear()
	if is_instance_valid(field) and is_instance_valid(field.selection):
		field.selection.placement_active = false
	if is_instance_valid(preview):
		preview.hide()
	if is_instance_valid(status):
		status.hide()


func _input(event: InputEvent) -> void:
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
	var headquarters := _headquarters.get_ref() as RTSBuilding
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
		var result := manager.place(_owner, headquarters, definition, hit["position"])
		if not is_instance_valid(self) or not is_instance_valid(field):
			return
		last_result = result
		if version != _generation:
			return
		reason = last_result.reason
		if last_result.accepted:
			var site := manager.sites.get(last_result.site_id) as ConstructionSite
			cancel()
			if site != null and is_instance_valid(site.building()) and field.contains_building(site.building()) and field.selection.selected_building() == headquarters:
				field.selection.select_building(site.building())
			return
	_cooldown -= delta
	var hit := _ground(_pointer)
	preview.visible = not hit.is_empty() and not field.camera_rig.pointer_over_interface()
	if not hit.is_empty():
		point = hit["position"]
		preview.position = point + Vector3.UP * definition.height / 2.0
	if _cooldown <= 0.0:
		_cooldown = 0.1
		reason = field.construction.validate(_owner, headquarters, definition, point) if not hit.is_empty() else "Point at flat ground inside the green boundary"
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
	if is_instance_valid(status) and not status.is_queued_for_deletion():
		status.queue_free()
