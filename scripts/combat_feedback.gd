class_name CombatFeedback
extends Node3D
## Team, health and hit presentation only. No command or damage authority.

var unit: RTSUnit
var health: UnitHealth
var display_name: String
var health_bar: WorldHealthBar
var health_fill: MeshInstance3D
var health_label: Label3D
var flash_remaining: float = 0.0
var fire_blocked: bool = false
var _last_fire_line: LineOfFire.Trace
var _fire_segment: MeshInstance3D
var _fire_contact: MeshInstance3D
var _launch_volume: MeshInstance3D
var _body_materials: Array[StandardMaterial3D] = []


func _ready() -> void:
	for child in unit._visual.get_children(): # Construction only, never a physics search.
		if child is MeshInstance3D:
			_body_materials.append(child.material_override as StandardMaterial3D)
	health_bar = WorldHealthBar.new()
	health_bar.position.y = 1.65
	add_child(health_bar)
	health_fill = health_bar.fill
	health_label = Label3D.new()
	health_label.font_size = 28
	health_label.outline_size = 4
	health_label.pixel_size = 0.02
	health_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	health_label.position.y = 2.65
	add_child(health_label)
	health.damaged.connect(_on_damaged)
	unit.availability_changed.connect(_refresh_team)
	_refresh_team()
	_refresh_health()
	set_physics_process(false)


func _refresh_team() -> void:
	for material in _body_materials:
		material.albedo_color = TeamRules.team_color(unit.owner_id)


func _refresh_health() -> void:
	health_bar.update_ratio(health.current / health.maximum)
	health_label.text = "%s\n%d / %d" % [display_name, ceili(health.current), ceili(health.maximum)]
	if not unit.movement_debug and fire_blocked:
		health_label.text = "BLOCKED"
	elif fire_blocked:
		health_label.text += "\nBLOCKED"
	health_label.modulate = Color("ffce78") if fire_blocked else Color.WHITE
	refresh_visibility()


func refresh_visibility() -> void:
	var alive := health.is_alive()
	health_bar.visible = alive and (unit.selection_indicator.visible or health.current < health.maximum or unit.movement_debug)
	health_label.visible = alive and (unit.movement_debug or fire_blocked)


func refresh_debug() -> void:
	_refresh_health()
	refresh_fire_debug()


func _on_damaged(_amount: float, _source: Node) -> void:
	_refresh_health()
	flash_remaining = 0.12
	for material in _body_materials:
		material.albedo_color = Color.WHITE
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	flash_remaining = maxf(0.0, flash_remaining - delta)
	if flash_remaining == 0.0:
		_refresh_team()
		set_physics_process(false)


func show_tracer(muzzle: Vector3, aim: Vector3) -> void:
	world_tracer(unit.gameplay_field, muzzle, aim)


static func world_tracer(field: TestField, muzzle: Vector3, aim: Vector3, color: Color = Color("fff0a0"), width: float = 0.045) -> void:
	var trace := MeshInstance3D.new()
	trace.add_to_group("combat_tracers")
	var mesh := BoxMesh.new()
	mesh.size = Vector3(width, width, muzzle.distance_to(aim))
	trace.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	trace.material_override = material
	field.add_child(trace)
	trace.global_position = (muzzle + aim) * 0.5
	if not muzzle.is_equal_approx(aim):
		trace.look_at(aim)
	var tween := trace.create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_interval(0.12)
	tween.tween_callback(trace.queue_free)


func set_fire_blocked(blocked: bool) -> void:
	if fire_blocked == blocked:
		return
	fire_blocked = blocked
	_refresh_health()


func show_fire_line(result: LineOfFire.Trace) -> void:
	_last_fire_line = result
	refresh_fire_debug()


func refresh_fire_debug() -> void:
	if not unit.movement_debug or _last_fire_line == null:
		if is_instance_valid(_fire_segment):
			_fire_segment.hide()
			_fire_contact.hide()
		if is_instance_valid(_launch_volume):
			_launch_volume.hide()
		return
	if not is_instance_valid(_fire_segment):
		_fire_segment = MeshInstance3D.new()
		_fire_segment.mesh = ImmediateMesh.new()
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = Color("ffd27a")
		_fire_segment.material_override = material
		add_child(_fire_segment)
		_fire_contact = MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.12
		sphere.height = 0.24
		_fire_contact.mesh = sphere
		_fire_contact.material_override = material
		add_child(_fire_contact)
	var mesh := _fire_segment.mesh as ImmediateMesh
	mesh.clear_surfaces()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	mesh.surface_add_vertex(to_local(_last_fire_line.from_position))
	mesh.surface_add_vertex(to_local(_last_fire_line.to_position))
	mesh.surface_end()
	_fire_segment.show()
	_fire_contact.position = to_local(_last_fire_line.position)
	_fire_contact.visible = _last_fire_line.blocked
	if unit.combat.weapon.definition.mode == WeaponDefinition.Mode.GUIDED_PROJECTILE:
		if not is_instance_valid(_launch_volume):
			_launch_volume = MeshInstance3D.new()
			_launch_volume.mesh = SphereMesh.new()
			var material := StandardMaterial3D.new()
			material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			material.albedo_color = Color(0.3, 0.9, 1.0, 0.45)
			material.no_depth_test = true
			_launch_volume.material_override = material
			add_child(_launch_volume)
		var volume := _launch_volume.mesh as SphereMesh
		volume.radius = unit.combat.weapon.definition.projectile_collision_radius
		volume.height = volume.radius * 2.0
		_launch_volume.position = to_local(LineOfFire.muzzle(unit))
		_launch_volume.show()
	elif is_instance_valid(_launch_volume):
		_launch_volume.hide()


static func world_impact(field: TestField, contact: Vector3) -> void:
	var flash := MeshInstance3D.new()
	flash.add_to_group("combat_world_impacts")
	var mesh := SphereMesh.new()
	mesh.radius = 0.16
	mesh.height = 0.32
	flash.mesh = mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color("ff9a53")
	flash.material_override = material
	field.add_child(flash)
	flash.global_position = contact
	var tween := flash.create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_interval(0.18)
	tween.tween_callback(flash.queue_free)
