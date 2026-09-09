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

var gameplay_enabled: bool = true # Scene-local match gate; legacy fields stay enabled.
var units: Array[RTSUnit] = []
var _registered: Dictionary[int, RTSUnit] = {}
var camera_rig: RTSCamera
var selection: SelectionController
var destinations: GroupDestinations
var fire_query := LineOfFire.new()
var navigation_region: NavigationRegion3D
var status_label: Label
var info_panel: PanelContainer
var last_command_slots := PackedVector3Array()
var last_command_result: CommandBatchResult
var _command_version: int = 0
var _next_command_generation: int = 0
var _owner_command_versions: Dictionary[int, int] = {}


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
	var count := _unit_count()
	for index in count:
		var unit := _create_unit(index)
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
	selection.attack_requested.connect(issue_attack)
	selection.stop_requested.connect(issue_stop)
	var unit_label := "combat units" if not units.is_empty() and units[0].combat != null else "friendly units"
	print("FIELD_READY: %d %s, %d obstacles; Godot %s" % [units.size(), unit_label, obstacles.size(), Engine.get_version_info()["string"]])


func _unit_count() -> int:
	return stress_unit_count if stress_layout else 12


func _create_unit(index: int) -> RTSUnit:
	var unit := RTSUnit.new()
	unit.unit_id = index + 1
	unit.name = "Unit%02d" % unit.unit_id
	if stress_layout:
		unit.position = Vector3(-29 + (index % 5) * 1.8, 0, 5 + (index / 5) * 1.8)
	else:
		unit.position = Vector3(-18 + (index % 4) * 2.5, 0, 10 + (index / 4) * 2.5)
	return unit


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
	return not is_queued_for_deletion() and is_instance_valid(unit) and unit.is_inside_tree() and not unit.is_queued_for_deletion() and unit.is_alive() and _registered.has(unit.get_instance_id()) and is_ancestor_of(unit)


func register_unit(unit: RTSUnit) -> void:
	if not is_instance_valid(unit) or not unit.is_inside_tree() or unit.is_queued_for_deletion() or not unit.is_alive() or not is_ancestor_of(unit):
		return
	if not _registered.has(unit.get_instance_id()):
		_registered[unit.get_instance_id()] = unit
		units.append(unit)
	unit.gameplay_field = self
	var exiting := _on_unit_exiting.bind(unit)
	if not unit.tree_exiting.is_connected(exiting):
		unit.tree_exiting.connect(exiting)
		# Keep the enter hook for reparenting/re-entry; the field owns no detached list.
		unit.tree_entered.connect(register_unit.bind(unit))


func _on_unit_exiting(unit: RTSUnit) -> void:
	unregister_unit(unit)


func unregister_unit(unit: RTSUnit) -> void:
	if not is_instance_valid(unit) or not _registered.has(unit.get_instance_id()):
		return
	_registered.erase(unit.get_instance_id())
	units.erase(unit)
	unit.gameplay_field = null
	if is_instance_valid(selection):
		selection.forget_unit(unit)
		_on_selection_changed(selection.selected_units().size())
	unit.availability_changed.emit()


func _new_batch() -> CommandBatchResult:
	_next_command_generation += 1
	var result := CommandBatchResult.new()
	result.generation = _next_command_generation
	return result


func _batch_selection(result: CommandBatchResult) -> Array[RTSUnit]:
	if not gameplay_enabled:
		return []
	# Selection pruning can synchronously accept a newer command. Capture its
	# authority before querying; rejected nested requests do not steal authority.
	var authority := _command_version
	var selected := selection.selected_units()
	for unit in selected:
		result.intended_ids.append(unit.unit_id)
	result.superseded = authority != _command_version
	return selected


func _finish_batch(result: CommandBatchResult, description: String) -> CommandBatchResult:
	result.superseded = result.generation != _command_version
	if not result.superseded:
		last_command_result = result
		status_label.text = "%02d/%02d accepted  /  %s" % [result.accepted_ids.size(), result.intended_ids.size(), description]
	return result


func issue_attack(target: Variant) -> CommandBatchResult:
	var result := _new_batch()
	var selected := _batch_selection(result)
	if result.superseded or selected.is_empty():
		return result
	var eligible := false
	for unit in selected:
		# Malformed armed members still reject the batch atomically. Valid weapons
		# with a different target domain simply retain their previous orders.
		if is_instance_valid(unit.combat) and is_instance_valid(unit.combat.weapon) and (unit.combat.weapon.definition == null or not unit.combat.weapon.definition.is_valid()):
			return result
		if TeamRules.can_attack(self, unit, target):
			eligible = true
	if not eligible:
		return result
	_command_version = result.generation
	for i in selected.size():
		if result.generation != _command_version:
			break
		var unit := selected[i]
		# A previous member's callback may have freed either reference. Check
		# validity before passing it into a typed method or reading its identity.
		if not is_instance_valid(unit) or not contains_unit(unit) or not is_instance_valid(target) or not TeamRules.can_attack(self, unit, target):
			continue
		if unit.combat.issue_attack(target):
			result.accepted_ids.append(result.intended_ids[i])
	return _finish_batch(result, "Attack order")


func issue_stop() -> CommandBatchResult:
	var result := _new_batch()
	var selected := _batch_selection(result)
	if result.superseded or selected.is_empty():
		return result
	_command_version = result.generation
	for i in selected.size():
		if result.generation != _command_version:
			break
		var unit := selected[i]
		if is_instance_valid(unit) and contains_unit(unit) and unit.stop():
			result.accepted_ids.append(result.intended_ids[i])
	return _finish_batch(result, "Stopped")


func issue_move(clicked: Vector3) -> CommandBatchResult:
	var result := _new_batch()
	var selected := _batch_selection(result)
	if result.superseded or selected.is_empty():
		return result
	selected.sort_custom(func(a: RTSUnit, b: RTSUnit) -> bool: return a.unit_id < b.unit_id)
	result.intended_ids.sort()
	var assigned := _movement_assignments(selected, clicked)
	if assigned.size() != selected.size():
		status_label.text = "%02d selected  /  No room for destinations" % selected.size()
		return result
	_command_version = result.generation
	for i in selected.size():
		if result.generation != _command_version:
			break
		var unit := selected[i]
		if not is_instance_valid(unit) or not contains_unit(unit):
			continue
		if unit.move_to(assigned[i]):
			var id := result.intended_ids[i]
			result.accepted_ids.append(id)
			result.assignments[id] = assigned[i]
	if result.generation == _command_version:
		last_command_slots.clear()
		for id in result.accepted_ids:
			last_command_slots.append(result.assignments[id])
	return _finish_batch(result, "Move order")


func _movement_assignments(selected: Array[RTSUnit], clicked: Vector3, strict_ground: bool = false) -> PackedVector3Array:
	# One batch retains authority; each locomotion domain validates its own slots.
	# Ground-only calls keep the original generator, spacing and path checks.
	if not clicked.is_finite():
		return PackedVector3Array()
	var map := get_world_3d().get_navigation_map()
	var assigned := PackedVector3Array()
	assigned.resize(selected.size())
	for domain in [TeamRules.TargetDomain.GROUND, TeamRules.TargetDomain.AIR]:
		var members: Array[RTSUnit] = []
		var indices: Array[int] = []
		for index in selected.size():
			if TeamRules.target_domain(selected[index]) == domain:
				members.append(selected[index])
				indices.append(index)
		if members.is_empty():
			continue
		var reserved := PackedVector3Array()
		for unit in units:
			if contains_unit(unit) and not members.has(unit) and TeamRules.target_domain(unit) == domain:
				reserved.append(_reserved_command_destination(unit))
		var slots := PackedVector3Array()
		if domain == TeamRules.TargetDomain.AIR:
			slots = _flight_slots(members, clicked, reserved)
		else:
			if strict_ground:
				if NavigationServer3D.map_get_iteration_id(map) == 0 or NavigationServer3D.map_get_closest_point(map, clicked).distance_to(clicked) > 0.1 or NavigationServer3D.map_get_closest_point_owner(map, clicked) != navigation_region.get_rid():
					return PackedVector3Array()
				for member in members:
					if member.navigation_suspended:
						return PackedVector3Array()
			slots = destinations.generate_slots(map, clicked, members.size(), reserved)
		if slots.size() != members.size():
			return PackedVector3Array()
		var domain_assignments := destinations.assign_slots(members, slots)
		for index in members.size():
			if domain == TeamRules.TargetDomain.GROUND:
				var path := NavigationServer3D.map_get_path(map, members[index].global_position, domain_assignments[index], true)
				if path.is_empty() or path[path.size() - 1].distance_to(domain_assignments[index]) > 0.1:
					return PackedVector3Array()
			assigned[indices[index]] = domain_assignments[index]
	return assigned


func _flight_slots(members: Array[RTSUnit], clicked: Vector3, reserved: PackedVector3Array) -> PackedVector3Array:
	var slots := PackedVector3Array()
	var offsets: Array[Vector2i] = []
	for x in range(-8, 9):
		for z in range(-8, 9):
			offsets.append(Vector2i(x, z))
	offsets.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		if a.length_squared() != b.length_squared(): return a.length_squared() < b.length_squared()
		return a.x < b.x or (a.x == b.x and a.y < b.y))
	for offset in offsets:
		var candidate: Vector3 = members[0].call("flight_destination", clicked + Vector3(offset.x * 1.5, 0, offset.y * 1.5))
		var clear := true
		for point in reserved:
			if candidate.distance_to(point) < 1.499: clear = false; break
		for point in slots:
			if candidate.distance_to(point) < 1.499: clear = false; break
		if not clear or not bool(members[0].call("flight_destination_valid", candidate)):
			continue
		slots.append(candidate)
		if slots.size() == members.size(): return slots
	return PackedVector3Array()


func _attack_move_context_active() -> bool:
	if not gameplay_enabled or not is_inside_tree() or not is_instance_valid(selection) or not selection.is_inside_tree():
		return false
	var ancestor: Node = self
	while ancestor != null:
		if ancestor.is_queued_for_deletion():
			return false
		ancestor = ancestor.get_parent()
	return true


func can_attack_move(unit: RTSUnit) -> bool:
	return is_instance_valid(selection) and can_attack_move_for(selection.friendly_owner_id, unit)


func can_attack_move_for(owner: int, unit: RTSUnit) -> bool:
	if not _attack_move_context_active() or not TeamRules.is_controlled(self, unit, owner):
		return false
	if not is_instance_valid(unit.combat) or not is_instance_valid(unit.combat.weapon) or not is_instance_valid(unit.attack_move):
		return false
	if not unit.combat.weapon.definition.is_valid():
		return false
	var ancestor: Node = unit
	while ancestor != null and ancestor != self:
		if ancestor.is_queued_for_deletion():
			return false
		ancestor = ancestor.get_parent()
	return ancestor == self


func _reserved_command_destination(unit: RTSUnit) -> Vector3:
	# Temporary pursuit/holding never releases a live parent order's final slot.
	if is_instance_valid(unit.attack_move) and unit.attack_move.active:
		return unit.attack_move.final_slot
	return unit.assigned_destination if unit.moving else unit.global_position


func issue_attack_move(clicked: Vector3) -> CommandBatchResult:
	var result := _new_batch()
	if not _attack_move_context_active():
		return result
	var selected := _batch_selection(result)
	# Selection pruning is a notification boundary, including field departure.
	if not is_instance_valid(self):
		result.superseded = true
		return result
	if result.superseded or not _attack_move_context_active() or selected.is_empty():
		return result
	return _dispatch_attack_move(result, selected, selection.friendly_owner_id, clicked)


func _owner_authority(owner: int) -> int:
	return _command_version if owner == selection.friendly_owner_id else _owner_command_versions.get(owner, 0)


func _commit_owner_command(owner: int, generation: int) -> void:
	if owner == selection.friendly_owner_id:
		_command_version = generation
	else:
		_owner_command_versions[owner] = generation


func _owner_feedback(owner: int, message: String) -> void:
	if owner == selection.friendly_owner_id:
		status_label.text = message


func _finish_owner_batch(owner: int, result: CommandBatchResult, description: String) -> CommandBatchResult:
	if owner == selection.friendly_owner_id:
		return _finish_batch(result, description)
	result.superseded = result.generation != _owner_authority(owner)
	return result


func _explicit_batch_selection(result: CommandBatchResult, candidates: Array) -> Array[RTSUnit]:
	var selected: Array[RTSUnit] = []
	if not _attack_move_context_active():
		return selected
	for candidate in candidates:
		if is_instance_valid(candidate) and candidate is RTSUnit and not result.intended_ids.has(candidate.unit_id):
			selected.append(candidate)
			result.intended_ids.append(candidate.unit_id)
	return selected


func issue_attack_move_for(owner: int, candidates: Array, clicked: Vector3) -> CommandBatchResult:
	var result := _new_batch()
	var selected := _explicit_batch_selection(result, candidates)
	if selected.is_empty():
		return result
	return _dispatch_attack_move(result, selected, owner, clicked)


func _dispatch_attack_move(result: CommandBatchResult, selected: Array[RTSUnit], owner: int, clicked: Vector3) -> CommandBatchResult:
	var participating: Array[RTSUnit] = []
	for unit in selected:
		if is_instance_valid(unit) and can_attack_move_for(owner, unit):
			participating.append(unit)
	if participating.is_empty():
		_owner_feedback(owner, "Attack Move rejected · select an armed mobile unit")
		return result
	participating.sort_custom(func(a: RTSUnit, b: RTSUnit) -> bool: return a.unit_id < b.unit_id)
	result.intended_ids.sort()
	if not clicked.is_finite() or not field_bounds.has_point(Vector2(clicked.x, clicked.z)):
		_owner_feedback(owner, "Attack Move rejected · choose navigable ground")
		return result
	var assigned := _movement_assignments(participating, clicked, true)
	if assigned.size() != participating.size():
		_owner_feedback(owner, "Attack Move rejected · no room for destinations")
		return result
	var identities: Array[int] = []
	for i in participating.size():
		var unit := participating[i]
		identities.append(unit.unit_id)
	# Validation above changes no orders; acceptance follows existing batch authority.
	_commit_owner_command(owner, result.generation)
	for i in participating.size():
		if not is_instance_valid(self) or not _attack_move_context_active() or result.generation != _owner_authority(owner):
			break
		var unit := participating[i]
		if not is_instance_valid(unit) or not can_attack_move_for(owner, unit):
			continue
		if unit.attack_move.issue(clicked, assigned[i], result.generation, owner):
			result.accepted_ids.append(identities[i])
			result.assignments[identities[i]] = assigned[i]
	if not is_instance_valid(self):
		result.superseded = true
		return result
	if not _attack_move_context_active():
		result.superseded = true
		return result
	if result.generation == _owner_authority(owner) and owner == selection.friendly_owner_id:
		last_command_slots.clear()
		for id in result.accepted_ids:
			last_command_slots.append(result.assignments[id])
	return _finish_owner_batch(owner, result, "Attack Move order")


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
		_build_obstacle(i, obstacles[i])


func _build_obstacle(index: int, rectangle: Rect2) -> void:
	var center := rectangle.get_center()
	var height := 1.8 + index * 0.4
	_box(Vector3(rectangle.size.x, height, rectangle.size.y), Vector3(center.x, height / 2.0, center.y), Color("8b7866"), 4 | LineOfFire.BLOCKER_MASK)
	var cap_size := Vector2(maxf(rectangle.size.x - 0.3, rectangle.size.x * 0.5), maxf(rectangle.size.y - 0.3, rectangle.size.y * 0.5))
	_box(Vector3(cap_size.x, 0.08, cap_size.y), Vector3(center.x, height + 0.04, center.y), Color("c4a17a"))


func _build_navigation() -> void:
	navigation_region = NavigationRegion3D.new()
	navigation_region.name = "NavigationRegion3D"
	navigation_region.navigation_mesh = create_navigation_mesh(obstacles)
	add_child(navigation_region)


func create_navigation_mesh(footprints: Array[Rect2]) -> NavigationMesh:
	# Partition a flat mesh at every expanded obstacle edge. Shared vertices make
	# connected convex polygons, with explicit holes and repeatable agent clearance.
	var bounds := field_bounds.grow(-CLEARANCE)
	var xs: Array[float] = [bounds.position.x, bounds.end.x]
	var zs: Array[float] = [bounds.position.y, bounds.end.y]
	var blocked: Array[Rect2] = []
	for obstacle in footprints:
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
	return mesh


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
	controls.text = "WASD / arrows / screen edges  ·  Pan\nMouse wheel  ·  Zoom\nLeft click / drag  ·  Select\nShift + click  ·  Toggle    Shift + drag  ·  Add\nRight click ground  ·  Move    X  ·  Stop\nEsc  ·  Cancel drag    F3  ·  Movement debug"
	if units.size() > 0 and units[0].combat != null:
		title.text = "FIELDWORK  /  COMBAT LAB"
		controls.text += "\nRight click hostile  ·  Attack\nAlpha: mint    Bravo: coral\nWalls block fire · BLOCKED units hold\nF3 also shows firing lines"
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
