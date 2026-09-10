extends Node3D
## Standalone local art browser. Run scenes/generals_asset_browser.tscn with F6.

var entries: Array = []
var filtered: Array = []
var list: ItemList
var search: LineEdit
var details: Label
var count_label: Label
var show_sources: CheckBox
var camera: Camera3D
var model: Node3D
var yaw: float = -0.55
var pitch: float = 0.32
var distance: float = 6.0
var dragging: bool = false
var target := Vector3(0, 0.8, 0)
var selected_name: String = ""


func _ready() -> void:
	get_window().title = "Generals — Object Library"
	get_window().size = Vector2i(1280, 800)
	get_window().move_to_center()
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("101d28")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("d9efff")
	environment.environment.ambient_light_energy = 0.6
	add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-48, -35, 0)
	light.light_energy = 1.2
	light.shadow_enabled = true
	add_child(light)
	camera = Camera3D.new()
	camera.fov = 36
	camera.h_offset = -1.0
	add_child(camera)
	camera.current = true
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(200, 200)
	floor_mesh.mesh = plane
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("1d303c")
	material.roughness = 1.0
	floor_mesh.material_override = material
	add_child(floor_mesh)
	_build_ui()
	var catalog = JSON.parse_string(FileAccess.get_file_as_string("res://assets/generals_library/catalog.json"))
	if catalog is Dictionary:
		entries = catalog.models
	_filter("")
	select_model("avconstdoz_a")
	_update_camera()
	get_window().grab_focus()
	if "--library-capture" in OS.get_cmdline_user_args():
		_capture_examples.call_deferred()


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(16, 16)
	panel.size = Vector2(350, 768)
	layer.add_child(panel)
	var margin := MarginContainer.new()
	for edge in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 14)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)
	var title := Label.new()
	title.text = "GENERALS OBJECT LIBRARY"
	title.add_theme_font_size_override("font_size", 20)
	column.add_child(title)
	search = LineEdit.new()
	search.placeholder_text = "Search objects or model names…"
	search.text_changed.connect(_filter)
	column.add_child(search)
	show_sources = CheckBox.new()
	show_sources.text = "Include animation and source-only files"
	show_sources.toggled.connect(func(_value: bool) -> void: _filter(search.text))
	column.add_child(show_sources)
	count_label = Label.new()
	column.add_child(count_label)
	list = ItemList.new()
	list.custom_minimum_size = Vector2(320, 330)
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list.item_selected.connect(_selected)
	column.add_child(list)
	details = Label.new()
	details.custom_minimum_size = Vector2(320, 165)
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.add_theme_font_size_override("font_size", 14)
	column.add_child(details)
	var controls := Label.new()
	controls.text = "Drag model to orbit · Scroll to zoom\nEsc to close"
	controls.position = Vector2(405, 735)
	controls.add_theme_font_size_override("font_size", 18)
	layer.add_child(controls)


func _filter(query: String) -> void:
	filtered.clear()
	list.clear()
	var needle := query.to_lower()
	for entry in entries:
		if not show_sources.button_pressed and entry.status != "preview":
			continue
		var objects := ", ".join(entry.objects)
		if not needle.is_empty() and not (str(entry.name) + " " + objects).to_lower().contains(needle):
			continue
		filtered.append(entry)
		var label: String = entry.name
		if not objects.is_empty():
			label += "  ·  " + objects
		list.add_item(label)
		list.set_item_tooltip(list.item_count - 1, label)
	count_label.text = "%d files · Static model previews" % filtered.size()


func select_model(name: String) -> bool:
	for index in filtered.size():
		if filtered[index].name == name:
			list.select(index)
			list.ensure_current_is_visible.call_deferred()
			_selected(index)
			return true
	return false


func _selected(index: int) -> void:
	if is_instance_valid(model):
		model.free()
	model = null
	var entry: Dictionary = filtered[index]
	selected_name = entry.name
	details.tooltip_text = ""
	details.text = str(entry.name).to_upper() + "\n" + ", ".join(entry.objects).left(70)
	if entry.status != "preview":
		details.text += "\n\nOriginal %s file copied. This file has no standalone 3D preview." % entry.type
		return
	var path := "res://" + str(entry.preview)
	if not FileAccess.file_exists(path):
		details.text += "\n\nLocal library data is missing. Run the asset copy and import tools described in docs/generals-assets.md."
		return
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var error := document.append_from_file(path, state)
	if error != OK:
		details.text += "\n\nCould not load this preview (%d)." % error
		return
	model = Node3D.new()
	model.add_child(document.generate_scene(state))
	GeneralsVisuals.apply_team(model, 1)
	GeneralsVisuals.fit(model, Vector3(3.8, 3.0, 4.0))
	add_child(model)
	var box := GeneralsVisuals.bounds(model)
	target = Vector3(0, box.get_center().y, 0)
	distance = 7.0
	_update_camera()
	details.text += "\n\n%d triangles · %s\n" % [entry.triangles, "Zero Hour" if entry.edition == "zero_hour" else "Generals"]
	if not entry.get("warnings", []).is_empty():
		details.tooltip_text = "\n".join(entry.warnings)
		details.text += "\n" + str(entry.warnings[0]).left(80)
		if entry.warnings.size() > 1:
			details.text += "\n+ %d import notes (hover)" % (entry.warnings.size() - 1)


func _update_camera() -> void:
	camera.position = target + Vector3(sin(yaw) * cos(pitch), sin(pitch), -cos(yaw) * cos(pitch)) * distance
	camera.look_at(target)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_tree().quit()
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			dragging = event.pressed
		if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			distance = maxf(2.5, distance - 0.35)
		if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			distance = minf(20.0, distance + 0.35)
		_update_camera()
	if event is InputEventMouseMotion and dragging:
		yaw -= event.relative.x * 0.008
		pitch = clampf(pitch + event.relative.y * 0.006, 0.06, 1.3)
		_update_camera()


func _capture_examples() -> void:
	DirAccess.make_dir_recursive_absolute("res://validation-output/generals-library/screenshots")
	for name in ["avconstdoz_a", "airngr_skn", "abbtcmdhq", "avcomanche", "abwarfact", "ubpalace", "nbpcenter"]:
		var selected := select_model(name)
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var error := get_viewport().get_texture().get_image().save_png("res://validation-output/generals-library/screenshots/%s.png" % name)
		print("LIBRARY_CAPTURE: %s loaded=%s saved=%s" % [name, selected and selected_name == name and is_instance_valid(model), error == OK])
	get_tree().quit()
