class_name ConstructionBuilding
extends RTSBuilding

var site: ConstructionSite
var site_label: Label3D


func display_name() -> String:
	return "%s site %d" % [super.display_name(), site.site_id] if site != null and not operational else super.display_name()


func _ready() -> void:
	super._ready()
	site_label = _identity_label
	refresh_construction()


func refresh_construction() -> void:
	if not is_instance_valid(site_label):
		return
	_refresh_health()
	for child in get_children():
		if child is MeshInstance3D and child != selection_indicator and child != rally_indicator:
			var material := child.material_override as StandardMaterial3D
			if material != null:
				if not operational:
					material.albedo_color = Color("b99557")
				elif kind == Kind.VEHICLE_FACTORY:
					material.albedo_color = Color("c9a468") if child.position.y > building_height else Color("687b9b")
				else:
					material.albedo_color = Color("547c83")
