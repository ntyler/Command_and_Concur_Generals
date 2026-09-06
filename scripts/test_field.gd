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

var units: Array[RTSUnit] = []
var camera_rig: RTSCamera
var selection: SelectionController
var destinations: GroupDestinations
var navigation_region: NavigationRegion3D
var status_label: Label
var info_panel: PanelContainer
var last_command_slots := PackedVector3Array()


func _ready() -> void:
	_build_field()
	_build_navigation()
	for row in range(3):
		for column in range(4):
			var unit := RTSUnit.new()
			unit.unit_id = row * 4 + column + 1
			unit.name = "Unit%02d" % unit.unit_id
			unit.position = Vector3(-18 + column * 2.5, 0, 10 + row * 2.5)
			add_child(unit)
			units.append(unit)
	camera_rig = RTSCamera.new()
	camera_rig.name = "CameraRig"
	add_child(camera_rig)
	destinations = GroupDestinations.new()
	destinations.name = "GroupDestinations"
	add_child(destinations)
	selection = SelectionController.new()
	selection.name = "SelectionController"
	selection.camera_rig = camera_rig
	_build_feedback()
	add_child(selection)
	selection.selection_changed.connect(_on_selection_changed)
	selection.move_requested.connect(issue_move)
	print("FIELD_READY: 12 friendly units, 3 obstacles; Godot ", Engine.get_version_info()["string"])


func issue_move(clicked: Vector3) -> void:
	var selected := selection.selected_units()
	if selected.is_empty():
		return
	selected.sort_custom(func(a: RTSUnit, b: RTSUnit) -> bool: return a.unit_id < b.unit_id)
	var map := get_world_3d().get_navigation_map()
	var slots := destinations.generate_slots(map, clicked, selected.size())
	if slots.size() != selected.size():
		status_label.text = "%02d selected  /  No room for destinations" % selected.size()
		return
	var assigned := destinations.assign_slots(selected, slots)
	# Reject an unreachable command atomically; keep the previous order intact.
	for i in selected.size():
		var path := NavigationServer3D.map_get_path(map, selected[i].global_position, assigned[i], true)
		if path.is_empty() or path[path.size() - 1].distance_to(assigned[i]) > 0.1:
			status_label.text = "%02d selected  /  Destination unreachable" % selected.size()
			return
	last_command_slots = assigned
	for i in selected.size():
		selected[i].move_to(assigned[i])
	status_label.text = "%02d selected  /  Move order issued" % selected.size()


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
	_box(Vector3(60, 0.3, 48), Vector3(0, -0.15, 0), Color("344b50"), 1)
	for x in range(-28, 30, 4):
		_box(Vector3(0.035, 0.012, 47), Vector3(x, 0.008, 0), Color("466166"))
	for z in range(-20, 24, 4):
		_box(Vector3(59, 0.012, 0.035), Vector3(0, 0.008, z), Color("466166"))
	_box(Vector3(60.5, 0.5, 0.35), Vector3(0, 0.1, -24), Color("d1b777"), 4)
	_box(Vector3(60.5, 0.5, 0.35), Vector3(0, 0.1, 24), Color("d1b777"), 4)
	_box(Vector3(0.35, 0.5, 48), Vector3(-30, 0.1, 0), Color("d1b777"), 4)
	_box(Vector3(0.35, 0.5, 48), Vector3(30, 0.1, 0), Color("d1b777"), 4)
	for i in OBSTACLES.size():
		var rectangle := OBSTACLES[i]
		var center := rectangle.get_center()
		var height := 1.8 + i * 0.4
		_box(Vector3(rectangle.size.x, height, rectangle.size.y), Vector3(center.x, height / 2.0, center.y), Color("8b7866"), 4)
		_box(Vector3(rectangle.size.x - 0.3, 0.08, rectangle.size.y - 0.3), Vector3(center.x, height + 0.04, center.y), Color("c4a17a"))


func _build_navigation() -> void:
	# Partition a flat mesh at every expanded obstacle edge. Shared vertices make
	# connected convex polygons, with explicit holes and repeatable agent clearance.
	var bounds := MAP_BOUNDS.grow(-CLEARANCE)
	var xs: Array[float] = [bounds.position.x, bounds.end.x]
	var zs: Array[float] = [bounds.position.y, bounds.end.y]
	var blocked: Array[Rect2] = []
	for obstacle in OBSTACLES:
		var expanded := obstacle.grow(CLEARANCE)
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
	title.text = "FIELDWORK  /  CONTROLS LAB"
	title.add_theme_color_override("font_color", Color("a7ecdf"))
	title.add_theme_font_size_override("font_size", 18)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(title)
	var controls := Label.new()
	controls.text = "WASD / arrows / screen edges  ·  Pan\nMouse wheel  ·  Zoom\nLeft click / drag  ·  Select\nShift + click  ·  Toggle    Shift + drag  ·  Add\nRight click  ·  Move    Esc  ·  Cancel drag"
	controls.add_theme_font_size_override("font_size", 14)
	controls.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(controls)
	status_label = Label.new()
	status_label.text = "00 selected  /  12 friendly units"
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
	status_label.text = "%02d selected  /  12 friendly units" % count
