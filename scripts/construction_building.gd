class_name ConstructionBuilding
extends RTSBuilding

var site: ConstructionSite
var site_label: Label3D


func display_name() -> String:
	return "Barracks site %d" % site.site_id if site != null and not operational else "Barracks"


func _ready() -> void:
	super._ready()
	for child in get_children():
		if child is Label3D:
			site_label = child as Label3D
	refresh_construction()


func refresh_construction() -> void:
	if not is_instance_valid(site_label):
		return
	site_label.text = "%s · %d" % [display_name(), owner_id]
	for child in get_children():
		if child is MeshInstance3D and child != selection_indicator and child != rally_indicator:
			var material := child.material_override as StandardMaterial3D
			if material != null:
				material.albedo_color = Color("547c83") if operational else Color("b99557")
