class_name WorldHealthBar
extends Node3D
## Compact presentation only; callers supply an authoritative health ratio.

var bar_width: float = 1.8
var bar_height: float = 0.16
var fill: MeshInstance3D
var background: MeshInstance3D


func _ready() -> void:
	background = _quad(Vector2(bar_width + 0.12, bar_height + 0.12), Color("14272d"), 0)
	fill = _quad(Vector2(bar_width, bar_height), Color("91f4ad"), 1)


func update_ratio(ratio: float) -> void:
	var fraction := clampf(ratio, 0.0, 1.0)
	fill.scale.x = maxf(0.001, fraction)
	fill.position.x = -bar_width * (1.0 - fraction) * 0.5
	var material := fill.material_override as StandardMaterial3D
	material.albedo_color = Color("ff997f") if fraction <= 0.3 else Color("ffce78") if fraction <= 0.6 else Color("91f4ad")


func _quad(size: Vector2, color: Color, priority: int) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	var mesh := QuadMesh.new()
	mesh.size = size
	visual.mesh = mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = color
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.no_depth_test = true
	material.render_priority = priority
	visual.material_override = material
	add_child(visual)
	return visual
