class_name TacticalMinimap
extends Control
## Registry-backed, fully revealed tactical view; commands use the field's API.

@export_range(0.01, 2.0) var marker_refresh_interval: float = 0.1
var field: TestField
var groups: ControlGroups
var mapping := MinimapMapping.new()
var markers: Array[Dictionary] = []
var footprint := PackedVector2Array()
var static_rectangles: Array[Rect2] = []
var static_rebuilds: int = 0
var _static_world: Array[Rect2] = []
var _static_content := Rect2()
var _static_bounds := Rect2()
var _next_refresh: int = 0
var _dirty: bool = true
var _pending_moves: Array[Vector3] = []
var _group_text: String = "Groups  —"
var _group_tail: String = ""
var _group_counts: Array[Vector2i] = []
var _style := StyleBoxFlat.new()


func _ready() -> void:
	name = "TacticalMinimap"
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_force_pass_scroll_events = false
	focus_mode = Control.FOCUS_NONE
	_style.bg_color = Color(0.045, 0.085, 0.11, 0.96)
	_style.border_color = Color("4a767d")
	_style.set_border_width_all(1)
	# Camera treats this control as pointer-only UI: keyboard pan stays available.
	set_meta("pointer_only_camera_block", true)
	get_viewport().size_changed.connect(_layout)
	field.selection.selection_changed.connect(_selection_changed)
	if field is ConstructionField:
		(field as ConstructionField).construction.changed.connect(_construction_changed)
	if groups != null:
		groups.changed.connect(_groups_changed)
	_layout()
	refresh_markers()
	_groups_changed()


func _layout() -> void:
	var viewport_size := get_viewport_rect().size
	var width := clampf(viewport_size.x * 0.205, 230.0, 300.0)
	size = Vector2(width, width * 0.8 + 68.0)
	position = viewport_size - size - Vector2(20, 20)
	mapping.configure(field.field_bounds, Rect2(Vector2(12, 30), size - Vector2(24, 64)), field.global_position.y)
	_dirty = true
	queue_redraw()


func _process(_delta: float) -> void:
	if not is_instance_valid(field) or field.is_queued_for_deletion():
		return
	if _dirty or Time.get_ticks_usec() >= _next_refresh:
		refresh_markers()
	if not is_instance_valid(self) or not is_instance_valid(field) or field.is_queued_for_deletion() or not is_instance_valid(field.camera_rig):
		return
	footprint = mapping.camera_footprint(field.camera_rig.camera, get_viewport_rect())
	queue_redraw()


func _physics_process(_delta: float) -> void:
	var pending := _pending_moves.duplicate()
	_pending_moves.clear()
	for point in pending:
		if not _interactive():
			return
		# No alternate selection, destination assignment or success indicator.
		# The ordinary API owns acceptance, supersession, cargo and feedback.
		field.issue_move(point)


func _interactive() -> bool:
	return is_instance_valid(field) and field.is_inside_tree() and not field.is_queued_for_deletion() and field.gameplay_enabled and not field.selection.placement_active


func _gui_input(event: InputEvent) -> void:
	if not event is InputEventMouse:
		return
	accept_event()
	if not event is InputEventMouseButton or not event.pressed or not _interactive():
		return
	if field.selection.attack_move_targeting and event.button_index == MOUSE_BUTTON_RIGHT:
		field.selection.cancel_attack_move_targeting()
		return
	var point: Variant = mapping.content_to_world(event.position)
	if point == null:
		if field.selection.attack_move_targeting and event.button_index == MOUSE_BUTTON_LEFT:
			field.selection._reject_attack_move_destination()
		return
	if event.button_index == MOUSE_BUTTON_LEFT:
		field.selection.cancel_gesture()
		if field.selection.attack_move_targeting:
			field.selection.queue_attack_move_destination(point)
		else:
			field.camera_rig.center_on_ground(point)
	elif event.button_index == MOUSE_BUTTON_RIGHT:
		field.selection.cancel_gesture()
		var selected := field.selection.selected_units()
		if is_instance_valid(self) and not selected.is_empty() and _interactive():
			_pending_moves.append(point)


func _exit_tree() -> void:
	_pending_moves.clear()
	if get_viewport().size_changed.is_connected(_layout):
		get_viewport().size_changed.disconnect(_layout)
	if is_instance_valid(field):
		if is_instance_valid(field.selection) and field.selection.selection_changed.is_connected(_selection_changed):
			field.selection.selection_changed.disconnect(_selection_changed)
		if field is ConstructionField and (field as ConstructionField).construction.changed.is_connected(_construction_changed):
			(field as ConstructionField).construction.changed.disconnect(_construction_changed)
	if is_instance_valid(groups) and groups.changed.is_connected(_groups_changed):
		groups.changed.disconnect(_groups_changed)
	field = null
	groups = null


func refresh_markers() -> void:
	_dirty = false
	_next_refresh = Time.get_ticks_usec() + int(maxf(0.01, marker_refresh_interval) * 1000000.0)
	markers.clear()
	if not is_instance_valid(field) or field.is_queued_for_deletion():
		return
	# This scene's ground is the field's flat Y plane; bounds are authoritative.
	mapping.configure(field.field_bounds, Rect2(Vector2(12, 30), size - Vector2(24, 64)), field.global_position.y)
	var selected_ids: Dictionary[int, bool] = {}
	for unit in field.selection.selected_units():
		if is_instance_valid(unit):
			selected_ids[unit.get_instance_id()] = true
	if not is_instance_valid(self) or not is_instance_valid(field) or field.is_queued_for_deletion():
		return
	for unit in field.units.duplicate():
		if not is_instance_valid(unit) or not field.contains_unit(unit):
			continue
		markers.append({"identity": unit.get_instance_id(), "kind": "unit", "position": unit.global_position, "owner": unit.owner_id, "selected": selected_ids.has(unit.get_instance_id()), "depleted": false})
		_watch(unit.availability_changed)
		_watch(unit.tree_exiting)
	var terrain := field.obstacles.duplicate()
	if field is ProductionField:
		for building in (field as ProductionField).registered_buildings():
			var rectangle := Rect2(Vector2(building.global_position.x, building.global_position.z) - building.footprint / 2.0, building.footprint)
			terrain.erase(rectangle)
			var kind: String = ["headquarters", "barracks", "vehicle_factory", "supply_depot", "power_plant", "ground_defense_battery"][building.kind]
			if building is ConstructionBuilding and not building.operational:
				kind = "site"
			markers.append({"identity": building.get_instance_id(), "kind": kind, "position": building.global_position, "owner": building.owner_id, "selected": false, "depleted": false, "rectangle": rectangle})
			_watch(building.availability_changed)
			_watch(building.tree_exiting)
	if field is HarvestField:
		for cache in (field as HarvestField).registered_caches():
			var rectangle := Rect2(Vector2(cache.global_position.x, cache.global_position.z) - cache.footprint / 2.0, cache.footprint)
			terrain.erase(rectangle)
			markers.append({"identity": cache.get_instance_id(), "kind": "supply", "position": cache.global_position, "owner": 0, "selected": false, "depleted": cache.depleted, "rectangle": rectangle})
			_watch(cache.changed)
			_watch(cache.tree_exiting)
	if terrain != _static_world or mapping.content_rect != _static_content or mapping.bounds != _static_bounds:
		_static_world.assign(terrain)
		_static_content = mapping.content_rect
		_static_bounds = mapping.bounds
		static_rectangles.clear()
		for rectangle in terrain:
			static_rectangles.append(mapping.world_rectangle(rectangle.intersection(field.field_bounds)))
		static_rebuilds += 1
	queue_redraw()


func _watch(notification: Signal) -> void:
	if not notification.is_connected(_mark_dirty):
		notification.connect(_mark_dirty)


func _mark_dirty() -> void:
	_dirty = true


func _selection_changed(_count: int) -> void:
	_mark_dirty()


func _construction_changed(_identity: int) -> void:
	_mark_dirty()


func _groups_changed() -> void:
	var labels := PackedStringArray()
	_group_counts.clear()
	if groups != null:
		for index in range(1, 10):
			var count := groups.group_members(index).size()
			if count > 0:
				labels.append("Group %d · %d %s" % [index, count, "unit" if count == 1 else "units"])
				_group_counts.append(Vector2i(index, count))
	_group_text = labels[0] if labels.size() == 1 else "Groups · none assigned"
	_group_tail = ""
	tooltip_text = "\n".join(labels) if not labels.is_empty() else "Ctrl + 1–9 · Assign selected units"
	queue_redraw()


func _draw() -> void:
	draw_style_box(_style, Rect2(Vector2.ZERO, size))
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(12, 20), "TACTICAL MAP  ·  −Z ↑", HORIZONTAL_ALIGNMENT_LEFT, size.x - 24, 13, Color("a7ecdf"))
	if not mapping.valid:
		return
	draw_rect(mapping.content_rect, Color("344b50"))
	for rectangle in static_rectangles:
		draw_rect(rectangle, Color("998871"))
	for marker in markers:
		var point := mapping.world_to_content(marker.position)
		if mapping.content_to_world(point) == null:
			continue
		var color := Color("a7ecdf") if marker.owner == field.selection.friendly_owner_id else Color("ee7865")
		if marker.kind == "unit":
			draw_circle(point, 2.8, color)
			if marker.selected:
				draw_arc(point, 5.0, 0, TAU, 16, Color.WHITE, 1.5, true)
		elif marker.kind == "supply":
			var diamond := PackedVector2Array([point + Vector2(0, -5), point + Vector2(5, 0), point + Vector2(0, 5), point + Vector2(-5, 0), point + Vector2(0, -5)])
			if not marker.depleted:
				draw_colored_polygon(diamond, Color("ffce78"))
			else:
				draw_polyline(diamond, Color("a59b7d"), 1.5, true)
		else:
			var rectangle := mapping.world_rectangle(marker.rectangle)
			draw_rect(rectangle, Color(color, 0.35))
			draw_rect(rectangle, color, false, 1.2)
			if marker.kind == "ground_defense_battery":
				draw_arc(point, 6.0, 0, TAU, 16, color, 1.2, true)
			var glyph: String = {"headquarters": "H", "barracks": "B", "vehicle_factory": "V", "supply_depot": "D", "power_plant": "P", "ground_defense_battery": "G", "site": "+"}[marker.kind]
			draw_string(font, point + Vector2(-4, 4), glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, color)
	if footprint.size() >= 3:
		var outline := footprint.duplicate()
		outline.append(outline[0])
		draw_polyline(outline, Color(1, 1, 1, 0.85), 1.25, true)
	draw_rect(mapping.content_rect.grow(1), Color("709294"), false, 1)
	if _group_counts.size() <= 1:
		draw_string(font, Vector2(12, size.y - 14), _group_text, HORIZONTAL_ALIGNMENT_LEFT, size.x - 24, 12, Color("ffce78"))
	else:
		# Numbered chips: gold group key, white valid unit count (u = units).
		# Two rows preserve the existing map dimensions and coordinate mapping.
		var chip_width := (size.x - 24) / 5.0
		for index in _group_counts.size():
			var entry := _group_counts[index]
			var origin := Vector2(12 + (index % 5) * chip_width, size.y - 31 + (index / 5) * 15)
			draw_style_box(_style, Rect2(origin, Vector2(chip_width - 3, 14)))
			draw_string(font, origin + Vector2(3, 11), str(entry.x), HORIZONTAL_ALIGNMENT_LEFT, 10, 11, Color("ffce78"))
			draw_string(font, origin + Vector2(15, 11), "%du" % entry.y, HORIZONTAL_ALIGNMENT_LEFT, chip_width - 18, 11, Color.WHITE)
