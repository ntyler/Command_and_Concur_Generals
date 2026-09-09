class_name PowerGrid
extends RefCounted
## Match-local, derived from the existing weak building registry, never the tree.
## Signals carry no old snapshot: listeners read the latest committed owner state.

signal changed

const LOW_POWER_RATE: float = 0.5
var active: bool = true
var _field_ref: WeakRef
var _totals: Dictionary = {}
var _notifying: bool = false
var _pending: bool = false


func _init(field: ProductionField) -> void:
	_field_ref = weakref(field)


func field() -> ProductionField:
	var owner := _field_ref.get_ref() as ProductionField
	return owner if active and is_instance_valid(owner) and owner.is_inside_tree() and not owner._closing and not owner.is_queued_for_deletion() else null


func contribution(building: RTSBuilding) -> Dictionary:
	var owner := field()
	if owner == null or not owner.power_enabled or not is_instance_valid(building) or building.gameplay_field != owner or not building.operational or not owner.contains_building(building) or building.definition == null:
		return {"generated": 0, "required": 0}
	return {"generated": maxi(0, building.definition.power_generated), "required": maxi(0, building.definition.power_required)}


func _reconcile() -> void:
	var owner := field()
	if owner == null:
		close()
		return
	var next: Dictionary = {}
	if owner.power_enabled:
		for entry: WeakRef in owner._buildings.values():
			var building := entry.get_ref() as RTSBuilding
			var value := contribution(building)
			if value.generated == 0 and value.required == 0:
				continue
			var identity := building.owner_id
			if not next.has(identity):
				next[identity] = {"generated": 0, "required": 0}
			next[identity].generated += value.generated
			next[identity].required += value.required
	if next != _totals:
		_totals = next # Commit every owner together, before any user callback.
		_pending = true


func refresh() -> void:
	if not active:
		return
	_reconcile()
	if _notifying:
		return
	_notifying = true
	while _pending and active:
		_pending = false
		changed.emit()
		# Even the last listener can queue_free a generator without reading again.
		# Reconcile that eligibility now; never return its stale effective power.
		_reconcile()
	_notifying = false


func snapshot(owner_id: int) -> Dictionary:
	refresh()
	var value: Dictionary = _totals.get(owner_id, {"generated": 0, "required": 0})
	var low: bool = value.generated < value.required
	return {"generated": value.generated, "required": value.required, "low_power": low, "multiplier": LOW_POWER_RATE if low else 1.0}


func firing_eligible(owner_id: int, notify: bool = true) -> bool:
	# Defense is binary. The established producer slowdown never authorizes a shot.
	# The last shot boundary reconciles silently so no listener can invalidate
	# the muzzle geometry after its final clear-space query.
	if notify:
		refresh()
	else:
		_reconcile()
	var value: Dictionary = _totals.get(owner_id, {"generated": 0, "required": 0})
	return active and field() != null and value.generated >= value.required


func close() -> void:
	active = false
	_totals.clear()
	_pending = false
	for connection in changed.get_connections():
		changed.disconnect(connection.callable)
