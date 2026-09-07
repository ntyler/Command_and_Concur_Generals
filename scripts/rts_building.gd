class_name RTSBuilding
extends StaticBody3D
## Fixed primitive footprint; deliberately has no health or combat controller.

enum Kind { HEADQUARTERS, BARRACKS }
@export var owner_id: int = 1
@export var kind: Kind = Kind.BARRACKS
@export var footprint: Vector2 = Vector2(6, 5)
@export var building_height: float = 2.6
@export var recipe: ProductionDefinition
@export var queue_capacity: int = 5
@export var spawn_retry_interval: float = 0.25

var production: UnitProduction
var operational: bool = true
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
