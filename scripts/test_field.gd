class_name TestField
extends Node3D
## One repeatable scene; geometry and navigation share the same obstacle definitions.

const MAP_BOUNDS := Rect2(-30, -24, 60, 48)
const CLEARANCE: float = 0.85
const OBSTACLES: Array[Rect2] = [
	Rect2(-11, -6, 6, 10),
	Rect2(4, -11, 8, 6),
	Rect2(4, 5, 6, 6),
]
const STRESS_OBSTACLES: Array[Rect2] = [
	Rect2(-2, -28, 4, 26.2), Rect2(-2, 1.8, 4, 26.2), # 3.6-wide gate.
	Rect2(12, -19, 4, 10), Rect2(12, -9, 13, 4), # L-shaped route.
	Rect2(14, 8, 4, 4), Rect2(23, 14, 4, 4), Rect2(22, 3, 4, 4), # Cluster.
]

@export var stress_layout: bool = false
@export_range(30, 50) var stress_unit_count: int = 30
@export var movement_debug: bool = false

var field_bounds: Rect2 = MAP_BOUNDS
var obstacles: Array[Rect2] = OBSTACLES.duplicate()

var units: Array[RTSUnit] = []
var camera_rig: RTSCamera
var selection: SelectionController
var destinations: GroupDestinations
var navigation_region: NavigationRegion3D
var status_label: Label
var info_panel: PanelContainer
var last_command_slots := PackedVector3Array()


func _ready() -> void:
	if stress_layout:
		field_bounds = Rect2(-36, -28, 72, 56)
		obstacles = STRESS_OBSTACLES.duplicate()
		for argument in OS.get_cmdline_user_args():
			if argument.begins_with("--units="):
				stress_unit_count = clampi(argument.trim_prefix("--units=").to_int(), 30, 50)
	movement_debug = movement_debug or OS.get_cmdline_user_args().has("--movement-debug")
	_build_field()
	_build_navigation()
	var count := stress_unit_count if stress_layout else 12
	for index in count:
		var unit := RTSUnit.new()
		unit.unit_id = index + 1
		unit.name = "Unit%02d" % unit.unit_id
		if stress_layout:
			unit.position = Vector3(-29 + (index % 5) * 1.8, 0, 5 + (index / 5) * 1.8)
		else:
			unit.position = Vector3(-18 + (index % 4) * 2.5, 0, 10 + (index / 4) * 2.5)
		add_child(unit)
		register_unit(unit)
		unit.set_movement_debug(movement_debug)
	camera_rig = RTSCamera.new()
	camera_rig.name = "CameraRig"
	if stress_layout:
		camera_rig.map_bounds = field_bounds.grow(-1.0)
		camera_rig.maximum_zoom = 80
		camera_rig.zoom = 62
		camera_rig.target_zoom = 62
	add_child(camera_rig)
	destinations = GroupDestinations.new()
	destinations.name = "GroupDestinations"
	add_child(destinations)
	selection = SelectionController.new()
	selection.name = "SelectionController"
	selection.gameplay_field = self
	selection.camera_rig = camera_rig
	_build_feedback()
	add_child(selection)
	selection.selection_changed.connect(_on_selection_changed)
	selection.move_requested.connect(issue_move)
	print("FIELD_READY: %d friendly units, %d obstacles; Godot %s" % [units.size(), obstacles.size(), Engine.get_version_info()["string"]])


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("movement_debug"):
		set_movement_debug(not movement_debug)
		get_viewport().set_input_as_handled()


func set_movement_debug(enabled: bool) -> void:
	movement_debug = enabled
	for unit in units:
		if contains_unit(unit):
			unit.set_movement_debug(enabled)


func contains_unit(unit: RTSUnit) -> bool:
	return is_instance_valid(unit) and unit.is_inside_tree() and not unit.is_queued_for_deletion() and is_ancestor_of(unit)


func register_unit(unit: RTSUnit) -> void:
	if not contains_unit(unit):
		return
	if not units.has(unit):
		units.append(unit)
	var exiting := _on_unit_exiting.bind(unit)
	if not unit.tree_exiting.is_connected(exiting):
		unit.tree_exiting.connect(exiting)
		# Keep the enter hook for reparenting/re-entry; the field owns no detached list.
		unit.tree_entered.connect(register_unit.bind(unit))


func _on_unit_exiting(unit: RTSUnit) -> void:
	units.erase(unit)
	if is_instance_valid(selection):
		selection.forget_unit(unit)


func issue_move(clicked: Vector3) -> bool:
	var selected := selection.selected_units()
	if selected.is_empty():
		return false
	selected.sort_custom(func(a: RTSUnit, b: RTSUnit) -> bool: return a.unit_id < b.unit_id)
	var map := get_world_3d().get_navigation_map()
	var selected_ids: Dictionary[int, bool] = {}
	for unit in selected:
		selected_ids[unit.unit_id] = true
	var reserved := PackedVector3Array()
	for unit in units:
		if contains_unit(unit) and not selected_ids.has(unit.unit_id):
			reserved.append(unit.assigned_destination if unit.moving else unit.global_position)
	var slots := destinations.generate_slots(map, clicked, selected.size(), reserved)
	if slots.size() != selected.size():
		status_label.text = "%02d selected  /  No room for destinations" % selected.size()
		return false
	var assigned := destinations.assign_slots(selected, slots)
	# Reject an unreachable command atomically; keep the previous order intact.
	for i in selected.size():
		var path := NavigationServer3D.map_get_path(map, selected[i].global_position, assigned[i], true)
		if path.is_empty() or path[path.size() - 1].distance_to(assigned[i]) > 0.1:
			status_label.text = "%02d selected  /  Destination unreachable" % selected.size()
			return false
	last_command_slots = assigned
	for i in selected.size():
		if not contains_unit(selected[i]):
			return false
		selected[i].move_to(assigned[i])
	status_label.text = "%02d selected  /  Move order issued" % selected.size()
	return true


func _build_field() -> void:
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("111d26")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("afc9d3")
	settings.ambient_light_energy = 0.45
	environment.environment = settings
	add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55, -30, 0)
	light.light_color = Color("fff0d9")
	light.light_energy = 0.95
	light.shadow_enabled = true
	light.directional_shadow_max_distance = 110.0
	add_child(light)
	var size := field_bounds.size
	_box(Vector3(size.x, 0.3, size.y), Vector3(0, -0.15, 0), Color("344b50"), 1)
	for x in range(int(field_bounds.position.x) + 2, int(field_bounds.end.x), 4):
		_box(Vector3(0.035, 0.012, size.y - 1), Vector3(x, 0.008, 0), Color("466166"))
	for z in range(int(field_bounds.position.y) + 4, int(field_bounds.end.y), 4):
		_box(Vector3(size.x - 1, 0.012, 0.035), Vector3(0, 0.008, z), Color("466166"))
	for z in [field_bounds.position.y, field_bounds.end.y]:
		_box(Vector3(size.x + 0.5, 0.5, 0.35), Vector3(0, 0.1, z), Color("d1b777"), 4)
	for x in [field_bounds.position.x, field_bounds.end.x]:
		_box(Vector3(0.35, 0.5, size.y), Vector3(x, 0.1, 0), Color("d1b777"), 4)
	for i in obstacles.size():
		var rectangle := obstacles[i]
		var center := rectangle.get_center()
		var height := 1.8 + i * 0.4
		_box(Vector3(rectangle.size.x, height, rectangle.size.y), Vector3(center.x, height / 2.0, center.y), Color("8b7866"), 4)
		_box(Vector3(rectangle.size.x - 0.3, 0.08, rectangle.size.y - 0.3), Vector3(center.x, height + 0.04, center.y), Color("c4a17a"))


func _build_navigation() -> void:
	# Partition a flat mesh at every expanded obstacle edge. Shared vertices make
	# connected convex polygons, with explicit holes and repeatable agent clearance.
	var bounds := field_bounds.grow(-CLEARANCE)
	var xs: Array[float] = [bounds.position.x, bounds.end.x]
	var zs: Array[float] = [bounds.position.y, bounds.end.y]
	var blocked: Array[Rect2] = []
	for obstacle in obstacles:
		var expanded := obstacle.grow(CLEARANCE).intersection(bounds)
		blocked.append(expanded)
		for x in [expanded.position.x, expanded.end.x]:
			if not xs.has(x):
				xs.append(x)
		for z in [expanded.position.y, expanded.end.y]:
			if not zs.has(z):
				zs.append(z)
	xs.sort()
	zs.sort()
	var vertices := PackedVector3Array()
	for z in zs:
		for x in xs:
			vertices.append(Vector3(x, 0, z))
	var mesh := NavigationMesh.new()
	mesh.vertices = vertices
	for z in range(zs.size() - 1):
		for x in range(xs.size() - 1):
			var midpoint := Vector2((xs[x] + xs[x + 1]) / 2, (zs[z] + zs[z + 1]) / 2)
			var walkable := true
			for obstacle in blocked:
				if obstacle.has_point(midpoint):
					walkable = false
					break
			if walkable:
				var a := z * xs.size() + x
				mesh.add_polygon(PackedInt32Array([a, a + 1, a + xs.size() + 1, a + xs.size()]))
	navigation_region = NavigationRegion3D.new()
	navigation_region.name = "NavigationRegion3D"
	navigation_region.navigation_mesh = mesh
	add_child(navigation_region)


func _box(size: Vector3, offset: Vector3, color: Color, layer: int = 0) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.92
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.material_override = material
	visual.position = offset
	add_child(visual)
	if layer != 0:
		var body := StaticBody3D.new()
		body.collision_layer = layer
		body.collision_mask = 0
		body.position = offset
		var collider := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collider.shape = shape
		body.add_child(collider)
		add_child(body)


func _build_feedback() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "ControlsFeedback"
	add_child(canvas)
	info_panel = PanelContainer.new()
	info_panel.position = Vector2(20, 20)
	info_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	info_panel.mouse_force_pass_scroll_events = false
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.045, 0.085, 0.11, 0.94)
	style.border_color = Color("4a767d")
	style.set_border_width_all(1)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	info_panel.add_theme_stylebox_override("panel", style)
	canvas.add_child(info_panel)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 6)
	info_panel.add_child(column)
	var title := Label.new()
	title.text = "FIELDWORK  /  STRESS LAB" if stress_layout else "FIELDWORK  /  CONTROLS LAB"
	title.add_theme_color_override("font_color", Color("a7ecdf"))
	title.add_theme_font_size_override("font_size", 18)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(title)
	var controls := Label.new()
	controls.text = "WASD / arrows / screen edges  ·  Pan\nMouse wheel  ·  Zoom\nLeft click / drag  ·  Select\nShift + click  ·  Toggle    Shift + drag  ·  Add\nRight click  ·  Move    Esc  ·  Cancel drag\nF3  ·  Movement debug"
	controls.add_theme_font_size_override("font_size", 14)
	controls.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(controls)
	status_label = Label.new()
	status_label.text = "00 selected  /  %d friendly units" % units.size()
	status_label.add_theme_color_override("font_color", Color("ffce78"))
	status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(status_label)
	selection.selection_box = ReferenceRect.new()
	selection.selection_box.editor_only = false
	selection.selection_box.border_color = Color("a1ffde")
	selection.selection_box.border_width = 2.0
	selection.selection_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(selection.selection_box)
	selection.selection_box.hide()


func _on_selection_changed(count: int) -> void:
	if is_instance_valid(status_label):
		status_label.text = "%02d selected  /  %d friendly units" % [count, units.size()]
