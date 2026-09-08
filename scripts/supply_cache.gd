class_name SupplyCache
extends StaticBody3D
## Finite instance inventory. Empty caches retain their static/nav footprint.

class Notifications extends RefCounted:
	signal changed

# The emitter can outlive this collider. A listener may immediately free the
# cache; it must not execute inside a locked SupplyCache method call.
var notifications := Notifications.new()
var changed: Signal:
	get: return notifications.changed
@export var cache_id: int = 1
@export var initial_supplies: int = 2000
@export var footprint := Vector2(4, 3)
var remaining: int = 0
var depleted: bool:
	get: return remaining == 0
var _goods: MeshInstance3D
var _label: Label3D
var movement_debug: bool = false


func _ready() -> void:
	remaining = maxi(0, initial_supplies)
	collision_layer = 4 | LineOfFire.BLOCKER_MASK
	collision_mask = 0
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(footprint.x, 1.5, footprint.y)
	collider.shape = shape
	collider.position.y = 0.75
	add_child(collider)
	_box(Vector3(footprint.x, 0.3, footprint.y), Vector3(0, 0.15, 0), Color("677778"))
	_goods = _box(Vector3(footprint.x - 0.4, 1.2, footprint.y - 0.4), Vector3(0, 0.9, 0), Color("d6ad55"))
	_label = Label3D.new()
	_label.position.y = 2.4
	_label.font_size = 32
	_label.pixel_size = 0.025
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(_label)
	_refresh()


func take_silent(requested: int) -> int:
	var amount := mini(remaining, maxi(0, requested))
	remaining -= amount
	return amount


func refresh_presentation() -> void:
	_refresh()


func set_movement_debug(enabled: bool) -> void:
	movement_debug = enabled
	if is_instance_valid(_label):
		_refresh()


func _refresh() -> void:
	_goods.visible = not depleted
	_label.text = "Supply %d%s" % [cache_id, " · Empty" if depleted else ""]
	if movement_debug:
		_label.text += "\n%d remaining" % remaining


func _box(size: Vector3, center: Vector3, color: Color) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	instance.material_override = material
	instance.position = center
	add_child(instance)
	return instance
