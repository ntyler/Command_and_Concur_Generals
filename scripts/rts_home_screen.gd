class_name RTSHomeScreen
extends Control
## Application entry point. Available matches retain their existing rules.

const MATCH_SCENE := "res://scenes/fortified_assault.tscn"
const LIBRARY_SCENE := "res://scenes/generals_asset_browser.tscn"
const INK := Color("09151e")
const PANEL := Color("102630")
const EDGE := Color("33505b")
const MUTED := Color("a0b8bf")
const GOLD := Color("f0c577")

var play_button: Button
var library_button: Button
var skirmish_button: Button
var manual_map_button: Button
var ai_map_button: Button
var quit_button: Button
var error_label: Label
var preview: SubViewport
var _leaving: bool = false


func _ready() -> void:
	get_window().title = "Fieldwork — Home"
	get_window().min_size = Vector2i(960, 640)
	theme = Theme.new()
	theme.default_font_size = 16
	theme.set_color("font_color", "Label", Color("edf4ef"))
	var backdrop := ColorRect.new()
	backdrop.color = INK
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + edge, 40)
	for edge in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 28)
	add_child(margin)
	var page := _column(margin, 20)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 16)
	page.add_child(header)
	var brand := _label(header, "FIELDWORK", 30)
	brand.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label(header, "GENERALS / ZERO HOUR  ·  GODOT EDITION", 13, MUTED)
	var rule := ColorRect.new()
	rule.color = EDGE
	rule.custom_minimum_size.y = 1
	page.add_child(rule)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 40)
	page.add_child(body)
	_build_navigation(body)
	_build_feature(body)
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 16)
	page.add_child(footer)
	var status := _label(footer, "DEVELOPMENT BUILD  ·  Current matches use prototype rules.", 13, MUTED)
	status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label(footer, "TAB / ARROWS to navigate   ·   ENTER to select", 12, MUTED)
	play_button.grab_focus()
	print("HOME_READY: Play, Object Library and Quit available; original skirmish and map tools pending")


func _build_navigation(parent: Node) -> void:
	var navigation := _column(parent, 14)
	navigation.custom_minimum_size.x = 340
	navigation.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_label(navigation, "OPERATIONS", 13, GOLD)
	_label(navigation, "Take command.", 38)
	var intro := _label(navigation, "Build your base, command your units\nand defend your headquarters.", 16, MUTED)
	intro.custom_minimum_size.y = 58
	play_button = _button(navigation, "Play Fortified Assault", true)
	play_button.pressed.connect(_open_scene.bind(MATCH_SCENE))
	library_button = _button(navigation, "Object Library")
	library_button.pressed.connect(_open_scene.bind(LIBRARY_SCENE))
	library_button.tooltip_text = "Browse the Dozer, Battleship, Carrier and the rest of the imported collection."
	skirmish_button = _button(navigation, "Original skirmish · In development")
	skirmish_button.add_theme_font_size_override("font_size", 16)
	skirmish_button.disabled = true
	skirmish_button.tooltip_text = "Original rules, opponent AI and skirmish setup are still being ported."
	quit_button = _button(navigation, "Quit to Desktop")
	quit_button.pressed.connect(func() -> void: get_tree().quit())
	error_label = _label(navigation, "", 14, Color("ffad96"))
	error_label.custom_minimum_size.x = 340
	error_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	error_label.hide()


func _build_feature(parent: Node) -> void:
	var feature := _column(parent, 16)
	feature.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var operation := PanelContainer.new()
	operation.size_flags_vertical = Control.SIZE_EXPAND_FILL
	operation.add_theme_stylebox_override("panel", _box(PANEL, EDGE, 18))
	feature.add_child(operation)
	var column := _column(operation, 8)
	var heading := HBoxContainer.new()
	column.add_child(heading)
	var title := _label(heading, "FORTIFIED ASSAULT", 17)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label(heading, "PLAYABLE", 12, Color("a4dcc4"))
	var viewport_container := SubViewportContainer.new()
	viewport_container.stretch = true
	viewport_container.custom_minimum_size.y = 220
	viewport_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	viewport_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(viewport_container)
	preview = SubViewport.new()
	preview.own_world_3d = true
	preview.handle_input_locally = false
	preview.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport_container.add_child(preview)
	_build_preview()
	_label(column, "Build a base. Secure supplies. Hold the line.", 15, MUTED)
	var workshop := PanelContainer.new()
	workshop.add_theme_stylebox_override("panel", _box(Color("14232b"), EDGE, 18))
	feature.add_child(workshop)
	var maps := _column(workshop, 10)
	_label(maps, "MAP WORKSHOP", 15, GOLD)
	_label(maps, "Manual editing and AI-prompt maps are not available yet.", 14, MUTED)
	var choices := HBoxContainer.new()
	choices.add_theme_constant_override("separation", 12)
	maps.add_child(choices)
	manual_map_button = _button(choices, "Manual map builder")
	ai_map_button = _button(choices, "Generate map with AI")
	for button in [manual_map_button, ai_map_button]:
		button.disabled = true
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size.y = 44
		button.add_theme_font_size_override("font_size", 15)
		button.tooltip_text = "In development"


func _build_preview() -> void:
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("122b35")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("d5e5e2")
	environment.environment.ambient_light_energy = 0.65
	preview.add_child(environment)
	var sunlight := DirectionalLight3D.new()
	sunlight.rotation_degrees = Vector3(-48, -25, 0)
	sunlight.light_energy = 1.0
	sunlight.shadow_enabled = true
	preview.add_child(sunlight)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(200, 200)
	ground.mesh = plane
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("213c43")
	material.roughness = 1.0
	ground.material_override = material
	preview.add_child(ground)
	var grid := MeshInstance3D.new()
	var lines := ImmediateMesh.new()
	var grid_material := StandardMaterial3D.new()
	grid_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	grid_material.albedo_color = Color("37515a")
	lines.surface_begin(Mesh.PRIMITIVE_LINES, grid_material)
	for index in range(-20, 21, 2):
		lines.surface_add_vertex(Vector3(index, 0.01, -20))
		lines.surface_add_vertex(Vector3(index, 0.01, 20))
		lines.surface_add_vertex(Vector3(-20, 0.01, index))
		lines.surface_add_vertex(Vector3(20, 0.01, index))
	lines.surface_end()
	grid.mesh = lines
	preview.add_child(grid)
	var tank := GeneralsVisuals.create("tank", Vector3(4.2, 2.5, 5.0), 1, false, 0.4)
	preview.add_child(tank)
	var helicopter := GeneralsVisuals.create("helicopter", Vector3(3.0, 2.0, 4.0), 1, false, -0.6)
	helicopter.position += Vector3(-2.8, 2.3, -1.8)
	preview.add_child(helicopter)
	var camera := Camera3D.new()
	camera.position = Vector3(6, 4.5, 7)
	camera.fov = 32
	preview.add_child(camera)
	camera.look_at(Vector3(-0.5, 1.0, -0.6))
	camera.current = true


func _column(parent: Node, separation: int) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", separation)
	parent.add_child(column)
	return column


func _label(parent: Node, text: String, font_size: int, color: Color = Color("edf4ef")) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label


func _box(fill: Color, border: Color, padding: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_content_margin_all(padding)
	style.set_corner_radius_all(3)
	return style


func _button(parent: Node, text: String, primary: bool = false) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 62 if primary else 52
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 20)
	button.add_theme_color_override("font_color", INK if primary else Color("edf4ef"))
	button.add_theme_color_override("font_hover_color", INK if primary else Color.WHITE)
	button.add_theme_color_override("font_pressed_color", INK if primary else Color.WHITE)
	button.add_theme_color_override("font_focus_color", INK if primary else Color.WHITE)
	button.add_theme_color_override("font_disabled_color", Color("839ba2"))
	button.add_theme_stylebox_override("normal", _box(GOLD if primary else PANEL, GOLD if primary else EDGE, 12))
	button.add_theme_stylebox_override("hover", _box(Color("ffdb97") if primary else Color("21404c"), GOLD, 12))
	button.add_theme_stylebox_override("pressed", _box(Color("d3a95e") if primary else Color("0c1c24"), GOLD, 12))
	button.add_theme_stylebox_override("disabled", _box(Color("0e1e27"), Color("233943"), 12))
	var focus := _box(Color.TRANSPARENT, Color("e3f6f3"), 12)
	focus.set_border_width_all(2)
	button.add_theme_stylebox_override("focus", focus)
	parent.add_child(button)
	return button


func _open_scene(path: String) -> void:
	if _leaving:
		return
	_leaving = true
	var error := get_tree().change_scene_to_file(path)
	if error != OK:
		_leaving = false
		error_label.text = "This screen could not be opened. Please try again."
		error_label.show()
