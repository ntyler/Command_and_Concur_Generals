class_name TempestStrikes
extends Node3D
## Match-local scheduled ground effects. Actors run first, this node at 500,
## and the existing end-of-physics result resolver runs at 1000.

signal strike_committed(strike_id: int)
signal strike_impacted(strike_id: int)
signal strikes_changed

# Anchor inclusion tolerance: 0.1 mm horizontally; no collider or cover query.
const RADIUS_EPSILON: float = 0.0001
const TIME_EPSILON: float = 0.0000001

var strikes: Dictionary[int, Dictionary] = {}
var impact_active: bool = false
# Damage callbacks receive this safe match-owned attribution node, never the
# launching building. These captured values identify the current damage batch.
var owner_id: int = 0
var current_strike_id: int = 0
var simulated_time: float = 0.0
var _field_ref: WeakRef
var _next_strike_id: int = 0
var _launching: bool = false
var _advancing: bool = false
var _closed: bool = false
var _last_frame: int = -1


func configure(active_field: BaseAssaultField) -> void:
	if _field_ref != null or not is_instance_valid(active_field):
		return
	_field_ref = weakref(active_field)
	active_field.match_finished.connect(_on_match_finished)
	process_physics_priority = 500


func _ready() -> void:
	process_physics_priority = 500


func field() -> BaseAssaultField:
	var active_field := _field_ref.get_ref() as BaseAssaultField if _field_ref != null else null
	if _closed or not is_inside_tree() or is_queued_for_deletion() or not is_instance_valid(active_field) or not active_field.is_inside_tree() or active_field.is_queued_for_deletion() or active_field._closing or not active_field.is_ancestor_of(self):
		return null
	var ancestor := get_parent()
	while ancestor != null and ancestor != active_field:
		if ancestor.is_queued_for_deletion():
			return null
		ancestor = ancestor.get_parent()
	return active_field


func _active_match() -> bool:
	var active_field := field()
	return active_field != null and active_field.gameplay_enabled and active_field.result == BaseAssaultField.Result.RUNNING and not active_field._restarting


func _source_reason(source: TempestArray, requester: int, notify_power: bool) -> String:
	if not _active_match():
		return "The match is not active"
	var active_field := field()
	if active_field.credits == null or not active_field.credits.active or not active_field.credits._balances.has(requester):
		return "Invalid owner"
	if not is_instance_valid(source) or source.owner_id != requester:
		return "Select an owned Tempest Array"
	if source.gameplay_field != active_field or not active_field.contains_building(source) or not source.base_available():
		return "Tempest Array is unavailable or unfinished"
	if not source.is_ready():
		return "Tempest Array is still charging"
	var generation := source.authority_generation
	var allowed := source.power_available(notify_power)
	if not is_instance_valid(self) or not _active_match() or field() != active_field:
		return "The match changed"
	if not is_instance_valid(source) or source.authority_generation != generation or source.owner_id != requester or source.gameplay_field != active_field or not source.base_available():
		return "Tempest Array changed during launch validation"
	if not source.is_ready():
		return "Tempest Array is still charging"
	return "" if allowed else "Tempest Array requires sufficient power"


func launch_reason(source: TempestArray, requester: int) -> String:
	return _source_reason(source, requester, true)


func target_reason(point: Vector3) -> String:
	var active_field := field()
	if active_field == null or not point.is_finite() or absf(point.y) > 0.05:
		return "Choose valid battlefield ground"
	var bounds := active_field.field_bounds
	# Unlike Rect2.has_point, both exact map edges are inclusive. Only the center
	# must fit; a radius crossing the map edge is an allowed target.
	if point.x < bounds.position.x or point.x > bounds.end.x or point.z < bounds.position.y or point.z > bounds.end.y:
		return "Target center must be inside the battlefield"
	return ""


func launch(source: TempestArray, requester: int, target: Vector3) -> Dictionary:
	if _launching:
		return _rejected("A launch is already being committed")
	_launching = true
	var active_field := field()
	var generation := source.authority_generation if is_instance_valid(source) else -1
	var reason := _source_reason(source, requester, true)
	if not is_instance_valid(self):
		return {"accepted": false, "reason": "The match changed", "strike_id": 0}
	if reason.is_empty() and (not is_instance_valid(source) or source.authority_generation != generation or field() != active_field):
		reason = "Tempest Array changed during launch validation"
	if reason.is_empty():
		reason = target_reason(target)
	if reason.is_empty():
		# Reconcile silently after all notifying callbacks. No callbacks occur
		# between this final authorization and the fully committed state below.
		reason = _source_reason(source, requester, false)
	if not reason.is_empty():
		_launching = false
		return _rejected(reason)
	_next_strike_id += 1
	var identity := _next_strike_id
	var duration: float = source.definition.strike_warning
	# Input can commit before this frame's priority-500 pass. Its warning starts
	# at that coherent completed boundary; this avoids charging the warning for
	# time preceding a priority-400 click in the same simulation frame.
	var committed_time := simulated_time
	if Engine.is_in_physics_frame() and Engine.get_physics_frames() > _last_frame:
		committed_time += get_physics_process_delta_time()
	var record: Dictionary = {
		"strike_id": identity, "owner_id": requester, "target": target,
		"radius": source.definition.strike_radius, "damage": source.definition.strike_damage,
		"warning_duration": duration, "elapsed": 0.0, "remaining": duration,
		"committed_time": committed_time, "impact_time": committed_time + duration,
		"committed_frame": Engine.get_physics_frames(), "state": "warning",
		"damage_applications": 0, "total_damage": 0.0
	}
	strikes[identity] = record
	source.consume_charge()
	# The marker is an ordinary child and receives no source reference. Creating
	# it after the charge/record commit also makes child-entered callbacks safe.
	_create_warning(record)
	if not is_instance_valid(self):
		return {"accepted": true, "reason": "Tempest strike committed", "strike_id": identity}
	_launching = false
	strike_committed.emit(identity)
	if is_instance_valid(self):
		strikes_changed.emit()
	return {"accepted": true, "reason": "Tempest strike committed · friendly fire", "strike_id": identity}


func _rejected(reason: String) -> Dictionary:
	return {"accepted": false, "reason": reason, "strike_id": 0}


func _physics_process(delta: float) -> void:
	advance(delta)


func advance(delta: float) -> void:
	if is_inside_tree() and get_tree().paused:
		return # Retain committed warnings; manual pause is not match completion.
	var frame := Engine.get_physics_frames()
	if _advancing or _last_frame == frame or not Engine.is_in_physics_frame() or not is_finite(delta) or delta <= 0.0:
		return
	_last_frame = frame
	if not _active_match():
		cancel_all()
		return
	_advancing = true
	simulated_time += delta
	var active_field := field()
	# The registry has one body per identity, and each body guards its own phase.
	for building in active_field.registered_buildings():
		if not is_instance_valid(self):
			return
		if not _active_match() or field() != active_field:
			_advancing = false
			cancel_all()
			return
		if is_instance_valid(building) and building is TempestArray:
			building.advance_charge(delta)
	if not is_instance_valid(self):
		return
	for identity in strikes.keys():
		if not _active_match() or field() != active_field:
			break
		var record: Dictionary = strikes[identity]
		if record.state != "warning" or frame <= record.committed_frame:
			continue
		record.elapsed = minf(record.warning_duration, record.elapsed + delta)
		record.remaining = maxf(0.0, record.warning_duration - record.elapsed)
		if record.remaining <= TIME_EPSILON:
			record.remaining = 0.0
			record.elapsed = record.warning_duration
			_impact(record)
		else:
			_update_warning(record)
		if not is_instance_valid(self):
			return
	_advancing = false
	if not _active_match():
		cancel_all()


func pending_count() -> int:
	return warning_markers().size()


func strike_snapshot(identity: int) -> Dictionary:
	if not strikes.has(identity):
		return {}
	var snapshot: Dictionary = strikes[identity].duplicate()
	snapshot.erase("warning_ref")
	snapshot.erase("label_ref")
	return snapshot


func warning_markers() -> Array[Dictionary]:
	var markers: Array[Dictionary] = []
	for identity in strikes:
		if strikes[identity].state == "warning":
			markers.append(strike_snapshot(identity))
	return markers


func _eligible_target(active_field: BaseAssaultField, target: Node3D) -> bool:
	if not is_instance_valid(target) or TeamRules.target_domain(target) != TeamRules.TargetDomain.GROUND:
		return false
	if target is RTSBuilding:
		return target.gameplay_field == active_field and active_field.contains_building(target) and target.can_take_damage()
	if target is RTSUnit:
		return TeamRules.is_combat_member(active_field, target) and is_instance_valid(target.combat.health) and target.combat.health.is_alive() and target.combat.health.damage_enabled
	return false


func _health_for(target: Node3D) -> UnitHealth:
	return target.health if target is RTSBuilding else target.combat.health


func _impact(record: Dictionary) -> void:
	if record.state != "warning" or not _active_match() or impact_active:
		return
	var active_field := field()
	# Terminal state precedes every callback, including visual-tree notifications.
	record.state = "impacted"
	impact_active = true
	owner_id = record.owner_id
	current_strike_id = record.strike_id
	var candidates: Array = active_field.units.duplicate()
	candidates.append_array(active_field.registered_buildings())
	var snapshot: Array[Dictionary] = []
	var included: Dictionary[int, bool] = {}
	var center := Vector2(record.target.x, record.target.z)
	var radius: float = record.radius + RADIUS_EPSILON
	for candidate in candidates:
		if not _eligible_target(active_field, candidate):
			continue
		var identity: int = candidate.get_instance_id()
		if included.has(identity):
			continue
		var anchor := LineOfFire.aim(candidate)
		if not anchor.is_finite() or Vector2(anchor.x, anchor.z).distance_squared_to(center) > radius * radius:
			continue
		included[identity] = true
		snapshot.append({"target": weakref(candidate), "health": weakref(_health_for(candidate))})
	for item in snapshot:
		if not is_instance_valid(self):
			return
		# Never transfer this batch into a replacement field or finished match.
		if not _active_match() or field() != active_field:
			break
		var target := (item.target as WeakRef).get_ref() as Node3D
		var health := (item.health as WeakRef).get_ref() as UnitHealth
		if not _eligible_target(active_field, target) or not is_instance_valid(health) or _health_for(target) != health:
			continue
		# Snapshot membership/anchor was fixed at impact, but callbacks may delete
		# later objects. Weak identity cannot substitute a reused unit_id/body.
		record.damage_applications += 1
		var applied := health.apply_damage(record.damage, self)
		record.total_damage += applied
		if not is_instance_valid(self):
			return
	impact_active = false
	_remove_warning(record)
	if is_instance_valid(self):
		strike_impacted.emit(record.strike_id)
	if is_instance_valid(self):
		strikes_changed.emit()


func _create_warning(record: Dictionary) -> void:
	var marker := Node3D.new()
	marker.name = "TempestWarning%d" % record.strike_id
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = maxf(0.01, record.radius - 0.10)
	torus.outer_radius = record.radius + 0.10
	torus.rings = 64
	torus.ring_segments = 8
	ring.mesh = torus
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("ffb957")
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring.material_override = material
	ring.position.y = 0.09
	marker.add_child(ring)
	var label := Label3D.new()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 42
	label.pixel_size = 0.022
	label.modulate = Color("ffd47d")
	label.position.y = 1.4
	marker.add_child(label)
	record.warning_ref = weakref(marker)
	record.label_ref = weakref(label)
	marker.position = record.target
	add_child(marker)
	if is_instance_valid(self):
		_update_warning(record)


func _update_warning(record: Dictionary) -> void:
	var label := (record.label_ref as WeakRef).get_ref() as Label3D if record.has("label_ref") else null
	if is_instance_valid(label):
		label.text = "TEMPEST · %ds\nGROUND BLAST · FRIENDLY FIRE" % ceili(record.remaining)


func _remove_warning(record: Dictionary) -> void:
	var marker := (record.warning_ref as WeakRef).get_ref() as Node3D if record.has("warning_ref") else null
	if is_instance_valid(marker):
		marker.hide()
		marker.queue_free()
	record.erase("warning_ref")
	record.erase("label_ref")


func cancel_all() -> void:
	var changed := false
	for record in strikes.values():
		if record.state == "warning":
			record.state = "cancelled"
			_remove_warning(record)
			changed = true
	if changed:
		strikes_changed.emit()


func _on_match_finished(_result: int) -> void:
	cancel_all()


func close() -> void:
	if _closed:
		return
	_closed = true
	var active_field := _field_ref.get_ref() as BaseAssaultField if _field_ref != null else null
	if is_instance_valid(active_field) and active_field.match_finished.is_connected(_on_match_finished):
		active_field.match_finished.disconnect(_on_match_finished)
	cancel_all()


func _exit_tree() -> void:
	close()
