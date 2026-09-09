class_name GroundDefenseBattery
extends ConstructionBuilding
## Shared stationary defense body; weapon data chooses ground or air threats.
## The existing emitter owns every shot, cooldown and authoritative damage check.

const RANGE_COLOR := Color("ffce78")
const AIR_RANGE_COLOR := Color("99ddff")

signal status_changed

var weapon: WeaponEmitter
var turret: Node3D
var range_indicator: MeshInstance3D
var acquisition_scans: int = 0
var authority_generation: int = 0
var attack_range: float:
	get:
		return definition.weapon_data.attack_range if definition != null and definition.weapon_data != null else 0.0

var _muzzle: Marker3D
var _target: WeakRef
var _scan_wait: float = 0.0
var _status: String = "Ready"
var _field_ref: WeakRef
var _grid: PowerGrid


func _init() -> void:
	definition = load("res://construction/ground_defense_battery.tres") as ConstructionDefinition
	kind = Kind.GROUND_DEFENSE_BATTERY
	recipe = null
	footprint = definition.footprint
	building_height = definition.height


func _ready() -> void:
	super._ready()
	# Keep the ordinary building identity above this subclass's raised turret.
	_identity_label.position.y = building_height + 1.4
	turret = Node3D.new()
	turret.name = "Turret"
	turret.position.y = building_height + 0.42
	add_child(turret)
	if _air_defense():
		_turret_box(Vector3(1.5, 0.75, 1.5), Vector3.ZERO, Color("34446b"))
		_turret_box(Vector3(1.8, 0.16, 1.2), Vector3(0, 0.46, 0), AIR_RANGE_COLOR)
		for side in [-1.0, 1.0]:
			_turret_box(Vector3(0.28, 0.3, 1.8), Vector3(side * 0.58, 0.12, -1.1), Color("c7e8ff"))
	else:
		_turret_box(Vector3(2.2, 0.65, 1.8), Vector3.ZERO, Color("263c49"))
		_turret_box(Vector3(1.65, 0.14, 1.35), Vector3(0, 0.39, 0), RANGE_COLOR)
		_turret_box(Vector3(0.35, 0.28, 1.45), Vector3(0, 0.15, -1.18), Color("b2d0c0"))
	_muzzle = Marker3D.new()
	_muzzle.name = "Muzzle"
	_muzzle.position = Vector3(0, 0.15, -1.91)
	turret.add_child(_muzzle)
	_build_range_indicator()
	weapon = WeaponEmitter.new()
	weapon.name = "Weapon"
	weapon.unit = self
	weapon.definition = definition.weapon_data
	add_child(weapon)
	availability_changed.connect(_on_own_availability_changed)
	refresh_construction()


func _turret_box(size: Vector3, offset: Vector3, color: Color) -> void:
	var visual := _mesh(size, offset, color)
	visual.reparent(turret, false)


func _air_defense() -> bool:
	return definition != null and definition.weapon_data != null and definition.weapon_data.target_domain == TeamRules.TargetDomain.AIR


func _range_color() -> Color:
	return AIR_RANGE_COLOR if _air_defense() else RANGE_COLOR


func _build_range_indicator() -> void:
	range_indicator = MeshInstance3D.new()
	range_indicator.name = "SelectedRange"
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for index in 96:
		for endpoint in [index, index + 1]:
			var angle := TAU * float(endpoint) / 96.0
			mesh.surface_add_vertex(Vector3(cos(angle) * attack_range, 0.07, sin(angle) * attack_range))
	mesh.surface_end()
	range_indicator.mesh = mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = _range_color()
	range_indicator.material_override = material
	add_child(range_indicator)
	range_indicator.hide()


func set_selected(selected: bool) -> void:
	super.set_selected(selected)
	if is_instance_valid(range_indicator):
		range_indicator.visible = selected and operational and is_alive()


func enable_damage(maximum: float) -> void:
	super.enable_damage(maximum)
	if is_instance_valid(health_bar):
		health_bar.position.y = building_height + 2.05
	if is_instance_valid(health_label):
		health_label.position.y = building_height + 2.8


func refresh_construction() -> void:
	super.refresh_construction()
	if is_instance_valid(turret):
		turret.visible = operational
	if is_instance_valid(range_indicator):
		# Construction recolors ordinary meshes; range retains its readable cue.
		(range_indicator.material_override as StandardMaterial3D).albedo_color = _range_color()
		range_indicator.visible = operational and selection_indicator.visible and is_alive()
	activate_defense()


func activate_defense() -> void:
	# Registration and construction completion may both call this. Neither can
	# create another emitter, contribute demand twice or scan immediately.
	if not is_instance_valid(gameplay_field) or not gameplay_field.contains_building(self):
		return
	var previous := _field_ref.get_ref() as ProductionField if _field_ref != null else null
	if previous != gameplay_field or _grid != gameplay_field.power_grid:
		_unbind_field()
		authority_generation += 1
		_clear_target()
		_field_ref = weakref(gameplay_field)
		_grid = gameplay_field.power_grid
		_scan_wait = definition.acquisition_interval
		if _grid != null:
			_grid.changed.connect(_on_power_changed)
		# Observe the existing optional match signal without retaining a concrete
		# derived field script through this building's construction ancestry.
		if gameplay_field.has_signal("match_finished"):
			gameplay_field.match_finished.connect(_on_match_finished)


func target_actor() -> RTSUnit:
	return _target.get_ref() as RTSUnit if _target != null else null


func status_text() -> String:
	return _status


func _base_available() -> bool:
	return is_inside_tree() and not is_queued_for_deletion() and operational and is_alive() and is_instance_valid(health) and health.is_alive() and is_instance_valid(gameplay_field) and gameplay_field.gameplay_enabled and not gameplay_field._closing and gameplay_field.contains_building(self) and definition != null and definition.is_valid() and is_instance_valid(weapon) and weapon.definition == definition.weapon_data and _origin_available()


func _origin_available() -> bool:
	return is_instance_valid(turret) and turret.is_inside_tree() and not turret.is_queued_for_deletion() and is_ancestor_of(turret) and is_instance_valid(_muzzle) and _muzzle.is_inside_tree() and not _muzzle.is_queued_for_deletion() and turret.is_ancestor_of(_muzzle) and _muzzle.global_position.is_finite() and turret.global_position.is_finite()


func source_authorized(notify_power: bool = true) -> bool:
	if not _base_available():
		return false
	var field := gameplay_field
	var owner := owner_id
	var version := authority_generation
	var permitted := field.defense_firing_allowed(self, notify_power)
	# The power grid publishes synchronous changes; its listeners may remove the
	# field/source, change ownership twice or reparent back into this same field.
	return permitted and is_instance_valid(self) and _base_available() and gameplay_field == field and owner_id == owner and authority_generation == version


func target_available(target: Variant) -> bool:
	return _base_available() and TeamRules.weapon_can_target(gameplay_field, owner_id, target, definition.weapon_data.target_domain, definition.weapon_data.ground_mobile_only) and target is RTSUnit and global_position.distance_squared_to(target.global_position) <= attack_range * attack_range


func weapon_origin() -> Vector3:
	return _muzzle.global_position if _origin_available() else Vector3(INF, INF, INF)


func weapon_attachment() -> Vector3:
	return turret.global_position if _origin_available() else Vector3(INF, INF, INF)


func face_toward(point: Vector3, radians_per_second: float, delta: float) -> void:
	if not source_authorized() or not is_instance_valid(self):
		return
	var direction := point - global_position
	if _air_defense():
		direction = point - turret.global_position
	if direction.length_squared() > 0.000001:
		turret.rotation.y = rotate_toward(turret.rotation.y, atan2(-direction.x, -direction.z) - global_rotation.y, radians_per_second * delta)
		if _air_defense():
			var horizontal := Vector2(direction.x, direction.z).length()
			var elevation := atan2(direction.y, horizontal)
			turret.rotation.x = rotate_toward(turret.rotation.x, elevation, radians_per_second * delta)


func facing_error(point: Vector3) -> float:
	if _air_defense():
		var direction := point - turret.global_position
		if direction.length_squared() <= 0.000001:
			return 0.0
		return acos(clampf((-turret.global_basis.z).normalized().dot(direction.normalized()), -1.0, 1.0))
	var direction := point - global_position
	return absf(angle_difference(turret.global_rotation.y, atan2(-direction.x, -direction.z)))


func _physics_process(delta: float) -> void:
	if is_inside_tree() and get_tree().paused:
		return # Preserve acquired target as well as scan/cooldown progress.
	activate_defense()
	if not _base_available():
		_clear_target()
		return
	# Active simulated time cools a committed shot even during a shortage.
	weapon.advance(delta)
	if not source_authorized():
		if is_instance_valid(self):
			_clear_target()
			_publish_status("No power")
		return
	var version := authority_generation
	_scan_wait = maxf(0.0, _scan_wait - delta)
	var scan_due := _scan_wait <= 0.000001
	if scan_due:
		_scan_wait = definition.acquisition_interval # Preserve cadence while retaining a target.
	var target := target_actor()
	if target != null:
		if not target_available(target):
			_clear_target()
			_publish_status("Ready")
			return
		var line := gameplay_field.fire_query.weapon_clearance(self, target, weapon.definition)
		if not is_instance_valid(self) or authority_generation != version or not source_authorized() or not is_instance_valid(self):
			return
		if not target_available(target) or not line.is_clear():
			_clear_target()
			_publish_status("Obstructed" if line.blocked else "Ready")
			return
	elif scan_due:
		# One scan maximum; no catch-up bursts after a long physics step.
		_scan()
		if not is_instance_valid(self) or authority_generation != version or not source_authorized() or not is_instance_valid(self):
			return
		target = target_actor()
	if target == null:
		return
	face_toward(target.global_position, definition.turret_turn_speed, delta)
	if not is_instance_valid(self) or authority_generation != version or not source_authorized() or not is_instance_valid(self) or not target_available(target):
		return
	weapon.try_fire(target)
	if is_instance_valid(self) and _base_available():
		if source_authorized(false):
			_publish_status("Engaging" if target_actor() != null else "Ready")
		else:
			_clear_target()
			_publish_status("No power")


func _scan() -> void:
	if not source_authorized() or not is_instance_valid(self):
		return
	acquisition_scans += 1
	var field := gameplay_field
	var version := authority_generation
	var owner := owner_id
	var nearest: RTSUnit
	var best_distance := attack_range * attack_range
	var obstructed := false
	# A snapshot tolerates removal during a query; identity remains a WeakRef when
	# retained, so a restarted unit_id can never reconnect an obsolete reference.
	for candidate in field.units.duplicate():
		if not is_instance_valid(nearest):
			nearest = null
			best_distance = attack_range * attack_range
		if not target_available(candidate):
			continue
		var distance := global_position.distance_squared_to(candidate.global_position)
		if distance > best_distance or (nearest != null and is_equal_approx(distance, best_distance) and not _identity_precedes(candidate, nearest)):
			continue # Domain/owner/lifetime/range filters precede geometry queries.
		var line := field.fire_query.weapon_clearance(self, candidate, weapon.definition)
		if not is_instance_valid(self) or authority_generation != version or gameplay_field != field or owner_id != owner or not source_authorized() or not is_instance_valid(self):
			return
		if not is_instance_valid(nearest):
			nearest = null
			best_distance = attack_range * attack_range
		if not target_available(candidate):
			continue
		if not line.is_clear():
			obstructed = obstructed or line.blocked
			continue
		nearest = candidate
		best_distance = distance
	if is_instance_valid(nearest) and target_available(nearest):
		_target = weakref(nearest)
		nearest.availability_changed.connect(_on_target_availability_changed)
		_publish_status("Engaging")
	else:
		_publish_status("Obstructed" if obstructed else "Ready")


static func _identity_precedes(candidate: RTSUnit, previous: RTSUnit) -> bool:
	return candidate.unit_id < previous.unit_id or (candidate.unit_id == previous.unit_id and candidate.get_instance_id() < previous.get_instance_id())


func _clear_target() -> void:
	var target := target_actor()
	if is_instance_valid(target) and target.availability_changed.is_connected(_on_target_availability_changed):
		target.availability_changed.disconnect(_on_target_availability_changed)
	_target = null


func _on_target_availability_changed() -> void:
	authority_generation += 1
	_clear_target()
	_publish_status("Ready")


func _on_own_availability_changed() -> void:
	authority_generation += 1
	_clear_target()


func _on_power_changed() -> void:
	if not _base_available():
		return
	if not source_authorized() and is_instance_valid(self):
		_clear_target()
		_publish_status("No power")
	elif is_instance_valid(self) and _status == "No power":
		_scan_wait = definition.acquisition_interval
		_publish_status("Ready")


func _on_match_finished(_result: int) -> void:
	authority_generation += 1
	_clear_target()


func _publish_status(value: String) -> void:
	if _status == value:
		return
	_status = value
	status_changed.emit() # No writes after observers that can delete the building.


func _unbind_field() -> void:
	if _grid != null and _grid.changed.is_connected(_on_power_changed):
		_grid.changed.disconnect(_on_power_changed)
	var field := _field_ref.get_ref() as ProductionField if _field_ref != null else null
	if is_instance_valid(field) and field.has_signal("match_finished") and field.match_finished.is_connected(_on_match_finished):
		field.match_finished.disconnect(_on_match_finished)
	_grid = null
	_field_ref = null


func _exit_tree() -> void:
	authority_generation += 1
	_clear_target()
	_unbind_field()
	super._exit_tree()
