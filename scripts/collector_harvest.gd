class_name CollectorHarvest
extends RefCounted
## Small per-collector order and inventory. Weak node references let a transfer
## finish reporting its committed value even when a synchronous listener frees nodes.

enum State { IDLE, TO_SUPPLIES, LOADING, RETURNING, UNLOADING, BLOCKED }
signal changed
signal transferred(result: HarvestTransfer)

var cargo: int = 0
var state: State = State.IDLE
var generation: int = 0
var automatic: bool = false
var reason: String = "Idle"
var last_rejection: String = ""
var last_transfer: HarvestTransfer
var _unit: WeakRef
var _field: WeakRef
var _cache: WeakRef
var _hq: WeakRef
var _owner: int
var _access: Dictionary = {}
var _elapsed: float = 0.0
var _advancing: bool = false
var _transferring: bool = false
var _closed: bool = false


func _init(unit: CollectorTruck) -> void:
	_unit = weakref(unit)


func unit_node() -> CollectorTruck:
	return _unit.get_ref() as CollectorTruck


func field_node() -> HarvestField:
	return _field.get_ref() as HarvestField if _field != null else null


func cache_node() -> SupplyCache:
	return _cache.get_ref() as SupplyCache if _cache != null else null


func headquarters_node() -> RTSBuilding:
	return _hq.get_ref() as RTSBuilding if _hq != null else null


func _live() -> bool:
	var unit := unit_node()
	var field := field_node()
	return not _closed and is_instance_valid(field) and field.harvest_member(unit) and unit.owner_id == _owner


func _configured(unit: CollectorTruck) -> bool:
	return unit.cargo_capacity > 0 and unit.loading_amount > 0 and is_finite(unit.loading_interval) and unit.loading_interval > 0.0 and is_finite(unit.unloading_duration) and unit.unloading_duration > 0.0 and is_finite(unit.interaction_distance) and unit.interaction_distance >= unit.stopping_distance and unit.interaction_distance <= 0.5


func can_order(target: Node3D, loop: bool) -> bool:
	var unit := unit_node()
	if _closed or not is_instance_valid(unit) or not unit.gameplay_field is HarvestField:
		return false
	var field := unit.gameplay_field as HarvestField
	if not field.harvest_member(unit) or not _configured(unit) or not is_instance_valid(target):
		return false
	var hq := field.headquarters_for_owner(unit.owner_id) if loop else target as RTSBuilding
	if not is_instance_valid(hq) or not field.valid_dropoff(hq, unit.owner_id):
		last_rejection = "No owned headquarters"
		return false
	if loop and (not target is SupplyCache or not field.contains_cache(target as SupplyCache) or (target as SupplyCache).depleted):
		last_rejection = "Supply unavailable or depleted"
		return false
	if not loop and cargo <= 0:
		last_rejection = "No cargo to deposit"
		return false
	var trip_target: Node3D = hq if not loop or cargo >= unit.cargo_capacity else target
	if field.plan_access(unit, trip_target).is_empty():
		last_rejection = "No reachable access position"
		return false
	return true


func issue(target: Node3D, loop: bool) -> bool:
	if not can_order(target, loop):
		return false
	var unit := unit_node()
	var field := unit.gameplay_field as HarvestField
	interrupt()
	_field = weakref(field)
	_owner = unit.owner_id
	_cache = weakref(target) if loop else null
	_hq = weakref(field.headquarters_for_owner(unit.owner_id) if loop else target)
	automatic = loop
	last_rejection = ""
	_begin_trip(not loop or cargo >= unit.cargo_capacity)
	return true # Historical acceptance survives synchronous replacements/deletion.


func interrupt() -> int:
	generation += 1
	var field := field_node()
	var unit := unit_node()
	if is_instance_valid(field) and is_instance_valid(unit):
		field.release_access(unit)
	_field = null
	_cache = null
	_hq = null
	_access = {}
	_elapsed = 0.0
	automatic = false
	state = State.IDLE
	reason = "Idle"
	last_rejection = ""
	return generation


func publish(version: int) -> void:
	if not _closed and version == generation:
		changed.emit()


func _stop_work(message: String, blocked: bool = false) -> void:
	var version := interrupt()
	reason = message
	state = State.BLOCKED if blocked else State.IDLE
	var unit := unit_node()
	if is_instance_valid(unit) and unit.is_inside_tree():
		unit.halt_motion()
	publish(version)


func on_availability_changed() -> void:
	var unit := unit_node()
	if not is_instance_valid(unit) or not unit.is_alive():
		cargo = 0 # Death discards undeposited cargo; no wallet operation.
	if not _live():
		_stop_work("Order cancelled · collector unavailable")


func _begin_trip(returning: bool) -> void:
	if not _live():
		return
	var unit := unit_node()
	var field := field_node()
	if not field.valid_dropoff(headquarters_node(), _owner):
		_stop_work("No owned headquarters · cargo retained", true)
		return
	var target: Node3D = headquarters_node() if returning else cache_node()
	if not is_instance_valid(target):
		_stop_work("Destination unavailable", true)
		return
	var access := field.plan_access(unit, target)
	if access.is_empty():
		_stop_work("Blocked · no reachable access", true)
		return
	field.release_access(unit)
	_access = access
	field.claim_access(unit, access)
	_elapsed = 0.0
	state = State.RETURNING if returning else State.TO_SUPPLIES
	reason = "Returning to HQ" if returning else "Travelling to supply"
	var version := generation
	var accepted := unit.harvest_move(access["point"])
	if version != generation or not _live():
		return
	if not accepted:
		_stop_work("Blocked · movement rejected", true)
	else:
		publish(version)


func advance(delta: float) -> void:
	if _closed or _advancing or _transferring or not is_finite(delta) or delta <= 0.0 or state == State.IDLE or state == State.BLOCKED:
		return
	_advancing = true
	_tick(delta)
	_advancing = false


func _tick(delta: float) -> void:
	if not _live():
		on_availability_changed()
		return
	var unit := unit_node()
	var field := field_node()
	var hq := headquarters_node()
	if not field.valid_dropoff(hq, _owner):
		_stop_work("No owned headquarters · cargo retained", true)
		return
	if state == State.TO_SUPPLIES or state == State.LOADING:
		var cache := cache_node()
		if not field.contains_cache(cache) or cache.depleted:
			if cargo > 0:
				_begin_trip(true)
			else:
				_stop_work("Supply depleted or unavailable")
			return
	if state == State.TO_SUPPLIES or state == State.RETURNING:
		if unit.movement_state == RTSUnit.MovementState.FAILED:
			# Preserve the mover's exhausted recovery history for diagnosis.
			var version := interrupt()
			state = State.BLOCKED
			reason = "Blocked route · cargo retained"
			publish(version)
			return
		if not unit.moving:
			var target: Node3D = cache_node() if state == State.TO_SUPPLIES else hq
			if not field.can_interact(unit, target, _access):
				_stop_work("Blocked interaction · cargo retained", true)
				return
			state = State.LOADING if state == State.TO_SUPPLIES else State.UNLOADING
			reason = "Loading" if state == State.LOADING else "Unloading"
			_elapsed = 0.0
			publish(generation)
		return # Arrival tick never contributes to loading/unloading time.
	_elapsed += delta
	if state == State.LOADING and _elapsed + 0.000001 >= unit.loading_interval:
		complete_loading()
	elif state == State.UNLOADING and _elapsed + 0.000001 >= unit.unloading_duration:
		complete_deposit()


func _result(kind: HarvestTransfer.Kind, amount: int, target_id: int) -> HarvestTransfer:
	var result := HarvestTransfer.new()
	result.kind = kind
	result.amount = amount
	result.collector_id = unit_node().unit_id
	result.owner_id = _owner
	result.target_id = target_id
	result.generation = generation
	last_transfer = result
	return result


func complete_loading() -> HarvestTransfer:
	var empty := HarvestTransfer.new()
	if _transferring or not _live() or state != State.LOADING:
		return empty
	var unit := unit_node()
	var field := field_node()
	var cache := cache_node()
	if _elapsed + 0.000001 < unit.loading_interval:
		return empty
	if not field.valid_dropoff(headquarters_node(), _owner) or not field.contains_cache(cache) or not field.can_interact(unit, cache, _access):
		_stop_work("Loading unavailable · cargo retained", true)
		return empty
	_transferring = true
	_elapsed = 0.0 # Consume this completed interval before any notification.
	var amount := cache.take_silent(mini(unit.loading_amount, maxi(0, unit.cargo_capacity - cargo)))
	cargo += amount
	var result := _result(HarvestTransfer.Kind.LOAD, amount, cache.cache_id)
	var version := generation
	var notifications := cache.notifications
	cache.refresh_presentation()
	# Both sides have committed. The event reports value, never a later balance delta.
	if amount > 0:
		transferred.emit(result)
	notifications.changed.emit()
	_transferring = false
	if version == generation and _live():
		publish(version)
	if version == generation and _live():
		if cargo >= unit_node().cargo_capacity or not field_node().contains_cache(cache_node()) or cache_node().depleted:
			if cargo > 0:
				_begin_trip(true)
			else:
				_stop_work("Supply depleted")
	return result


func complete_deposit() -> HarvestTransfer:
	var empty := HarvestTransfer.new()
	empty.kind = HarvestTransfer.Kind.DEPOSIT
	if _transferring or not _live() or state != State.UNLOADING or cargo <= 0:
		return empty
	var unit := unit_node()
	var field := field_node()
	var hq := headquarters_node()
	if _elapsed + 0.000001 < unit.unloading_duration:
		return empty
	if not field.valid_dropoff(hq, _owner) or not field.can_interact(unit, hq, _access):
		_stop_work("Deposit unavailable · cargo retained", true)
		return empty
	var wallet := field.credits
	var amount := cargo
	if not wallet.credit(_owner, amount):
		_stop_work("Deposit rejected · cargo retained", true)
		return empty
	# Exactly one silent wallet credit and cargo removal precede all callbacks.
	_transferring = true
	cargo = 0
	_elapsed = 0.0
	var result := _result(HarvestTransfer.Kind.DEPOSIT, amount, hq.get_instance_id())
	var version := generation
	transferred.emit(result)
	wallet.publish(result.owner_id)
	_transferring = false
	if version == generation and _live():
		var cache := cache_node()
		if automatic and field_node().contains_cache(cache) and not cache.depleted:
			_begin_trip(false)
		else:
			_stop_work("Supply depleted" if automatic else "Deposit complete")
	return result


func close() -> void:
	interrupt()
	_closed = true
	for event in [changed, transferred]:
		for connection in event.get_connections():
			event.disconnect(connection["callable"])
