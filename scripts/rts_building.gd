class_name RTSBuilding
extends StaticBody3D
## Fixed primitive footprint. Combat health is opt-in; legacy buildings stay invulnerable.

enum Kind { HEADQUARTERS, BARRACKS, VEHICLE_FACTORY, SUPPLY_DEPOT, POWER_PLANT, GROUND_DEFENSE_BATTERY, AIRFIELD, AIR_DEFENSE_BATTERY, WALL, GATE }
@export var owner_id: int = 1:
	set(value):
		if owner_id == value:
			return
		owner_id = value
		_schedule_power_refresh()
		availability_changed.emit() # Final: a listener may immediately remove this body.
@export var kind: Kind = Kind.BARRACKS
@export var definition: ConstructionDefinition
@export var footprint: Vector2 = Vector2(6, 5)
@export var building_height: float = 2.6
@export var recipe: ProductionDefinition
@export var queue_capacity: int = 5
@export var spawn_retry_interval: float = 0.25

var production: UnitProduction
signal availability_changed
var gameplay_field: ProductionField
var health: UnitHealth
var health_bar: WorldHealthBar
var health_label: Label3D
var _identity_label: Label3D
var movement_debug: bool = false
var destroyed: bool = false
var _departing: bool = false
var operational: bool = true:
	set(value):
		operational = value
		if is_instance_valid(health):
			health.damage_enabled = value and not destroyed and is_instance_valid(gameplay_field) and gameplay_field.gameplay_enabled
			_refresh_health()
		_schedule_power_refresh()
var selection_indicator: MeshInstance3D
var rally_indicator: MeshInstance3D


func _init() -> void:
	recipe = load("res://production/rifle.tres") as ProductionDefinition


func display_name() -> String:
	if kind == Kind.WALL:
		return "Wall"
	if kind == Kind.GATE:
		return "Gate"
	if kind == Kind.AIRFIELD:
		return "Airfield"
	if kind == Kind.AIR_DEFENSE_BATTERY:
		return "Air Defense Battery"
	if kind == Kind.GROUND_DEFENSE_BATTERY:
		return "Ground Defense Battery"
	if kind == Kind.POWER_PLANT:
		return "Power Plant"
	if kind == Kind.SUPPLY_DEPOT:
		return "Supply Depot"
	if kind == Kind.VEHICLE_FACTORY:
		return "Vehicle Factory"
	return "Headquarters" if kind == Kind.HEADQUARTERS else "Barracks"


func supports_recipe(definition: ProductionDefinition) -> bool:
	return definition != null and ((kind == Kind.HEADQUARTERS and definition.identifier == &"bulldozer") or (kind == Kind.BARRACKS and definition.identifier == &"rifle") or (kind == Kind.VEHICLE_FACTORY and definition.identifier == &"rocket_vehicle") or (kind == Kind.SUPPLY_DEPOT and definition.identifier == &"collector_truck") or (kind == Kind.AIRFIELD and definition.identifier == &"attack_helicopter"))


func is_drop_off() -> bool:
	# Capability only: the harvesting authority also checks operational state,
	# ownership, field membership, lifetime and valid interaction access.
	return kind in [Kind.HEADQUARTERS, Kind.SUPPLY_DEPOT]


func deposit_access_positions() -> Array[Dictionary]:
	return depot_access_layout(global_position, footprint, get_instance_id())


static func depot_access_layout(origin: Vector3, size: Vector2, identity: int = 0) -> Array[Dictionary]:
	var positions: Array[Dictionary] = []
	# Six delivery bays on the other three faces keep the east production exit
	# separate. Every point and docking face derives from the solid footprint.
	for axis in [Vector3.LEFT, Vector3.BACK, Vector3.FORWARD]:
		var side := Vector3(-axis.z, 0, axis.x)
		var extent := size.x / 2.0 if axis.x != 0 else size.y / 2.0
		for offset in [-1.0, 1.0]:
			var dock: Vector3 = origin + axis * (extent + 0.1) + side * offset
			positions.append({"point": dock + axis * 1.2, "dock": dock, "slot": positions.size(), "target": identity})
	return positions


func _ready() -> void:
	collision_layer = 4 | LineOfFire.BLOCKER_MASK
	collision_mask = 0
	_build_geometry()
	var label := Label3D.new()
	_identity_label = label
	label.text = "%s · %d" % [display_name(), owner_id]
	label.position.y = building_height + (1.25 if kind == Kind.POWER_PLANT else 0.6)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 32
	label.pixel_size = 0.025
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
	_refresh_health()


func _build_geometry() -> void:
	var box := BoxShape3D.new()
	box.size = Vector3(footprint.x, building_height, footprint.y)
	var collider := CollisionShape3D.new()
	collider.shape = box
	collider.position.y = building_height / 2.0
	add_child(collider)
	var keys := {Kind.HEADQUARTERS: "headquarters", Kind.BARRACKS: "barracks",
		Kind.VEHICLE_FACTORY: "vehicle_factory", Kind.SUPPLY_DEPOT: "supply_depot",
		Kind.POWER_PLANT: "power_plant", Kind.AIRFIELD: "airfield",
		Kind.GROUND_DEFENSE_BATTERY: "ground_defense", Kind.AIR_DEFENSE_BATTERY: "air_defense"}
	var included: Array[String] = []
	if kind == Kind.GROUND_DEFENSE_BATTERY:
		included = ["BASE", "HOUSECOLOR03", "HOUSECOLOR04"]
	elif kind == Kind.AIR_DEFENSE_BATTERY:
		included = ["CHASSIS", "HOUSECOLOR01"]
	var visual := GeneralsVisuals.create(keys.get(kind, "barracks"), box.size, owner_id, false, 0.0, not included.is_empty(), included)
	add_child(visual)


func _physics_process(delta: float) -> void:
	if production != null:
		production.advance(delta)


func _schedule_power_refresh() -> void:
	# These setters occur inside construction/death commits. Publish only after
	# those commits; an immediate consumer snapshot still rechecks eligibility.
	if is_instance_valid(gameplay_field) and gameplay_field.power_enabled and gameplay_field.power_grid != null:
		gameplay_field.power_grid.refresh.call_deferred()


func set_selected(selected: bool) -> void:
	if is_instance_valid(selection_indicator):
		selection_indicator.visible = selected
	if is_instance_valid(rally_indicator):
		rally_indicator.visible = selected and production != null and production.has_rally
		if rally_indicator.visible:
			rally_indicator.global_position = production.rally_point + Vector3.UP * 0.1
	_refresh_health()


func set_movement_debug(enabled: bool) -> void:
	movement_debug = enabled
	_refresh_health()


func enable_damage(maximum: float) -> void:
	if health != null or destroyed:
		return
	health = UnitHealth.new()
	health.maximum = maximum
	health.damage_enabled = operational
	add_child(health)
	health.damaged.connect(_on_damage)
	health.died.connect(_on_died)
	health_bar = WorldHealthBar.new()
	health_bar.bar_width = minf(3.8, footprint.x - 0.4)
	health_bar.position.y = building_height + (1.85 if kind == Kind.POWER_PLANT else 1.2)
	add_child(health_bar)
	health_label = Label3D.new()
	health_label.position.y = building_height + (2.5 if kind == Kind.POWER_PLANT else 1.85)
	health_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	health_label.font_size = 26
	health_label.pixel_size = 0.022
	add_child(health_label)
	_refresh_health()


func is_alive() -> bool:
	return not destroyed and not _departing and (health == null or health.is_alive())


func can_take_damage() -> bool:
	return operational and health != null and health.damage_enabled and is_alive()


func _refresh_health() -> void:
	if is_instance_valid(_identity_label):
		_identity_label.visible = is_alive()
		_identity_label.text = "%s · %d" % [display_name(), owner_id]
		_identity_label.modulate = Color("86ffcb") if owner_id == 1 else Color("ffa18c")
	if is_instance_valid(health_label):
		health_bar.update_ratio(health.current / health.maximum)
		health_bar.visible = operational and is_alive() and (selection_indicator.visible or health.current < health.maximum or movement_debug)
		health_label.visible = operational and is_alive() and movement_debug
		health_label.text = "%d / %d HP" % [ceili(health.current), ceili(health.maximum)]
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


func launch_position(radius: float = 0.5) -> Vector3:
	# Aircraft origin is its collision sphere center, above the visible pad.
	return global_position + Vector3.UP * (building_height + radius + 0.18)


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
