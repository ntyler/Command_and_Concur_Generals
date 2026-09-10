class_name GeneralsVisuals
extends RefCounted
## Visual-only asset composition. No scripts, collision or gameplay from W3D.


static func create(key: String, size: Vector3, team: int = 1, centered: bool = false, yaw: float = 0.0, stretch: bool = false, include: Array[String] = []) -> Node3D:
	var wrapper := Node3D.new()
	wrapper.name = "OriginalModel"
	wrapper.set_meta("generals_visual", true)
	var model := load("res://assets/generals/%s.glb" % key).instantiate() as Node3D
	model.rotation.y = yaw
	wrapper.add_child(model)
	if not include.is_empty():
		for part in model.find_children("*", "MeshInstance3D", true, false):
			var keep := false
			for prefix in include:
				keep = keep or str(part.name).begins_with(prefix)
			if not keep:
				part.free()
	fit(wrapper, size, centered, stretch)
	apply_team(wrapper, team)
	return wrapper


static func bounds(node: Node3D, parent_transform: Transform3D = Transform3D.IDENTITY) -> AABB:
	var transform := parent_transform * node.transform
	var result := AABB()
	if node is MeshInstance3D and node.mesh != null:
		result = transform * node.get_aabb()
	for child in node.get_children():
		if child is Node3D:
			var child_box := bounds(child, transform)
			if child_box.size != Vector3.ZERO:
				result = child_box if result.size == Vector3.ZERO else result.merge(child_box)
	return result


static func fit(wrapper: Node3D, size: Vector3, centered: bool = false, stretch: bool = false) -> void:
	var box := bounds(wrapper)
	var factors := size / box.size.max(Vector3.ONE * 0.0001)
	if not stretch:
		factors = Vector3.ONE * minf(factors.x, minf(factors.y, factors.z))
	wrapper.scale = factors
	var anchor := box.get_center()
	if not centered:
		anchor.y = box.position.y
	wrapper.position = -anchor * factors


static func apply_team(node: Node3D, team: int) -> void:
	# The converter splits face materials into single-surface mesh parts.
	# Keep the instance override alive through immediate construction teardown.
	for part in node.find_children("*", "MeshInstance3D", true, false):
		var mesh := part as MeshInstance3D
		var source := mesh.get_active_material(0) as StandardMaterial3D
		if source != null and str(mesh.name).begins_with("AIRNGR-SKN"):
			var material := ShaderMaterial.new()
			material.shader = load("res://shaders/generals_team_mask.gdshader")
			material.set_shader_parameter("body_texture", source.albedo_texture)
			material.set_shader_parameter("team_color", TeamRules.team_color(team))
			mesh.material_override = material
			mesh.set_meta("generals_team_shader", true)
			continue
		if source != null and (source.resource_name.begins_with("HouseColor") or str(mesh.name).begins_with("HOUSECOLOR")):
			var material := source.duplicate() as StandardMaterial3D
			material.albedo_color = TeamRules.team_color(team)
			mesh.material_override = material


static func show_construction(node: Node3D, operational: bool) -> void:
	if node.has_meta("construction_operational") and node.get_meta("construction_operational") == operational:
		return
	node.set_meta("construction_operational", operational)
	for part in node.find_children("*", "MeshInstance3D", true, false):
		var mesh := part as MeshInstance3D
		var material := mesh.material_override as StandardMaterial3D
		if material == null:
			var source := mesh.get_active_material(0) as StandardMaterial3D
			if source == null:
				continue
			material = source.duplicate() as StandardMaterial3D
			mesh.material_override = material
		var base_color: Color = material.get_meta("original_albedo", material.albedo_color)
		material.set_meta("original_albedo", base_color)
		material.albedo_color = base_color if operational else Color("b99557")
