class_name RTSBuilding
extends StaticBody3D
## Fixed primitive footprint. Combat health is opt-in; legacy buildings stay invulnerable.

enum Kind { HEADQUARTERS, BARRACKS }
@export var owner_id: int = 1
@export var kind: Kind = Kind.BARRACKS
@export var footprint: Vector2 = Vector2(6, 5)
@export var building_height: float = 2.6
@export var recipe: ProductionDefinition
@export var queue_capacity: int = 5
@export var spawn_retry_interval: float = 0.25

var production: UnitProduction
signal availability_changed
var gameplay_field: ProductionField
var health: UnitHealth
var health_label: Label3D
var _identity_label: Label3D
var destroyed: bool = false
var _departing: bool = false
var operational: bool = true:
	set(value):
		operational = value
		if is_instance_valid(health):
			health.damage_enabled = value and not destroyed and is_instance_valid(gameplay_field) and gameplay_field.gameplay_enabled
			_refresh_health()
var selection_indicator: MeshInstance3D
var rally_indicator: MeshInstance3D


func _init() -> void:
	recipe = load("res://production/rifle.tres") as ProductionDefinition


func display_name() -> String:
	return "Headquarters" if kind == Kind.HEADQUARTERS else "Barracks"


func _ready() -> void:
	collision_layer = 4 | LineOfFire.BLOCKER_MASK
	collision_mask = 0
	var box := BoxShape3D.new()
	box.size = Vector3(footprint.x, building_height, footprint.y)
	var collider := CollisionShape3D.new()
	collider.shape = box
	collider.position.y = building_height / 2.0
	add_child(collider)
	_mesh(box.size, collider.position, Color("547c83") if owner_id == 1 else Color("aa655f"))
	_mesh(Vector3(footprint.x - 0.4, 0.12, footprint.y - 0.4), Vector3(0, building_height + 0.06, 0), Color("adc9ba"))
	# Painted door and trim stay inside the solid's footprint.
	_mesh(Vector3(0.02, 1.4, 1.5), Vector3(footprint.x / 2.0 + 0.005, 0.7, 0), Color("263c49"))
	var label := Label3D.new()
	_identity_label = label
	label.text = "%s · %d" % [display_name(), owner_id]
	label.position.y = building_height + 0.6
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 40
	label.pixel_size = 0.027
	add_child(label)
	selection_indicator = _mesh(Vector3(footprint.x + 0.25, 0.02, footprint.y + 0.25), Vector3(0, 0.035, 0), Color("86ffcb"))
	selection_indicator.hide()
	rally_indicator = MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.35
	ring.outer_radius = 0.5
	rally_indicator.mesh = ring
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("ffce78")
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rally_indicator.material_override = material
	add_child(rally_indicator)
	rally_indicator.top_level = true
	rally_indicator.hide()


func _physics_process(delta: float) -> void:
	if production != null:
		production.advance(delta)


func set_selected(selected: bool) -> void:
	if is_instance_valid(selection_indicator):
		selection_indicator.visible = selected
	if is_instance_valid(rally_indicator):
		rally_indicator.visible = selected and production != null and production.has_rally
		if rally_indicator.visible:
			rally_indicator.global_position = production.rally_point + Vector3.UP * 0.1


func enable_damage(maximum: float) -> void:
	if health != null or destroyed:
		return
	health = UnitHealth.new()
	health.maximum = maximum
	health.damage_enabled = operational
	add_child(health)
	health.damaged.connect(_on_damage)
	health.died.connect(_on_died)
	health_label = Label3D.new()
	health_label.position.y = building_height + 1.0
	health_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	health_label.font_size = 38
	health_label.pixel_size = 0.025
	add_child(health_label)
	_refresh_health()


func is_alive() -> bool:
	return not destroyed and not _departing and (health == null or health.is_alive())


func can_take_damage() -> bool:
	return operational and health != null and health.damage_enabled and is_alive()


func _refresh_health() -> void:
	if is_instance_valid(health_label):
		_identity_label.visible = not operational and is_alive()
		health_label.visible = operational and is_alive()
		health_label.text = "%s · %d\n%d / %d HP" % [display_name(), owner_id, ceili(health.current), ceili(health.maximum)]
		health_label.modulate = Color("86ffcb") if owner_id == 1 else Color("ffa18c")


func _on_damage(_amount: float, _source: Node) -> void:
	_refresh_health()


func _on_died(_source: Node) -> void:
	if destroyed:
		return
	destroyed = true
	operational = false
	collision_layer = 0
	set_physics_process(false)
	hide()
	queue_free() # All subsequent commands already reject this body.
	if is_instance_valid(gameplay_field):
		gameplay_field.destroy_building(self)
	if is_instance_valid(self):
		availability_changed.emit()


func _enter_tree() -> void:
	_departing = false


func _exit_tree() -> void:
	_departing = true
	availability_changed.emit()


func exit_position() -> Vector3:
	return global_position + Vector3(footprint.x / 2.0 + 1.3, 0, 0)


func _mesh(size: Vector3, offset: Vector3, color: Color) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	visual.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	visual.material_override = material
	visual.position = offset
	add_child(visual)
	return visual
