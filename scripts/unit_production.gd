class_name UnitProduction
extends RefCounted
## Barracks-local state survives its node long enough for departure reconciliation.
## Weak node references prevent cycles; no persistent/global production state.

signal changed
signal deployed(job_id: int, unit_id: int, rally_accepted: bool)

class Job extends RefCounted:
	var id: int
	var payer: int
	var paid: int
	var scene: PackedScene
	var label: String
	var duration: float
	var elapsed: float = 0.0
	var retry_left: float = 0.0

var has_rally: bool = false
var rally_point := Vector3.ZERO
var message: String = ""
var last_deployment: Dictionary = {}
var _field_ref: WeakRef
var _building_ref: WeakRef
var _wallet: PlayerCredits
var _jobs: Array[Job] = []
var _closed: bool = false
var _advancing: bool = false


func _init(field: ProductionField, building: RTSBuilding, wallet: PlayerCredits) -> void:
	_field_ref = weakref(field)
	_building_ref = weakref(building)
	_wallet = wallet


func building() -> RTSBuilding:
	return _building_ref.get_ref() as RTSBuilding


func is_available() -> bool:
	var field := _field_ref.get_ref() as ProductionField
	var producer := building()
	return not _closed and is_instance_valid(field) and field.gameplay_enabled and is_instance_valid(producer) and producer.operational and field.contains_building(producer) and producer.production == self


func jobs() -> Array[Dictionary]:
	# UI/callers receive values, never the mutable queue or live job objects.
	var result: Array[Dictionary] = []
	for job in _jobs:
		result.append({"id": job.id, "payer": job.payer, "paid": job.paid, "name": job.label, "duration": job.duration, "elapsed": job.elapsed})
	return result


func count() -> int:
	return _jobs.size()


func progress() -> float:
	return 0.0 if _jobs.is_empty() else _jobs[0].elapsed / _jobs[0].duration


func enqueue(requester: int, definition: ProductionDefinition) -> ProductionResult:
	if not is_available():
		return ProductionResult.reject("Producer unavailable")
	var producer := building()
	if requester != producer.owner_id:
		return ProductionResult.reject("Producer not controlled")
	if definition == null or definition != producer.recipe or not definition.is_valid():
		return ProductionResult.reject("Unsupported or invalid recipe")
	if _jobs.size() >= producer.queue_capacity:
		return ProductionResult.reject("Queue full")
	if not is_finite(producer.spawn_retry_interval) or producer.spawn_retry_interval <= 0.0:
		return ProductionResult.reject("Invalid spawn retry interval")
	var job := Job.new()
	job.payer = requester
	job.paid = definition.credit_cost
	job.duration = definition.training_duration
	job.scene = definition.unit_scene
	job.label = definition.display_name
	if not _wallet.spend(requester, job.paid):
		return ProductionResult.reject("Insufficient credits")
	var field := _field_ref.get_ref() as ProductionField
	job.id = field.next_job_id()
	_jobs.append(job)
	var result := ProductionResult.accept(job.id)
	# Both sides are committed. Recursive listeners see the current coherent state.
	_wallet.publish(requester)
	_publish()
	return result


func cancel(requester: int, job_id: int) -> ProductionResult:
	if not is_available():
		return ProductionResult.reject("Producer unavailable")
	if requester != building().owner_id:
		return ProductionResult.reject("Producer not controlled")
	for i in _jobs.size():
		var job := _jobs[i]
		if job.id != job_id:
			continue
		_jobs.remove_at(i)
		if i == 0:
			message = ""
		_wallet.refund(job.payer, job.paid)
		var result := ProductionResult.accept(job.id)
		_wallet.publish(job.payer)
		_publish()
		return result
	return ProductionResult.reject("Job no longer cancellable")


func set_rally(requester: int, point: Vector3) -> ProductionResult:
	if not is_available():
		return ProductionResult.reject("Producer unavailable")
	var producer := building()
	if requester != producer.owner_id:
		return ProductionResult.reject("Producer not controlled")
	var field := _field_ref.get_ref() as ProductionField
	if not field.valid_rally(producer.exit_position(), point):
		return ProductionResult.reject("Invalid rally point")
	has_rally = true
	rally_point = point
	producer.set_selected(producer.selection_indicator.visible)
	_publish()
	return ProductionResult.accept(0)


func advance(delta: float) -> void:
	if _advancing or not Engine.is_in_physics_frame() or not is_available() or _jobs.is_empty():
		return
	_advancing = true
	_advance_head(delta)
	_advancing = false


func _advance_head(delta: float) -> void:
	var job := _jobs[0]
	if job.elapsed < job.duration:
		job.elapsed = minf(job.duration, job.elapsed + delta)
		if job.elapsed < job.duration:
			return
		# A 100% notification is still BEFORE deployment: cancellation may win here.
		_publish()
		if not _still_head(job):
			return
	job.retry_left -= delta
	if job.retry_left > 0.0:
		return
	job.retry_left = maxf(0.01, building().spawn_retry_interval)
	var field := _field_ref.get_ref() as ProductionField
	var candidate := field.find_spawn(building())
	if candidate.is_empty():
		_set_message("Exit blocked")
		return
	var unit := field.prepare_deployment(job.scene, job.payer, candidate[0])
	# add_child/registration can invoke external tree callbacks. No paid unit may
	# escape if cancellation/removal won before this point.
	if not _still_head(job) or not is_instance_valid(unit) or not is_instance_valid(field) or not field.contains_unit(unit):
		if is_instance_valid(unit):
			if is_instance_valid(field):
				field.unregister_unit(unit)
			if is_instance_valid(unit):
				unit.queue_free()
		if _still_head(job):
			_set_message("Deployment unavailable; retrying")
		return
	var use_rally := has_rally
	var destination := rally_point
	var identity := unit.unit_id
	# DEPLOYMENT COMMIT: initialized registered unit exists; remove the head before
	# rally, UI or completion notifications can call back. No refund after here.
	_jobs.pop_front()
	message = ""
	unit.show()
	# Visibility callbacks may remove the just-committed unit as well.
	var rally_ok := not use_rally
	if use_rally and is_instance_valid(unit) and is_instance_valid(field):
		rally_ok = field.order_deployed_unit(unit, destination)
	last_deployment = {"job_id": job.id, "unit_id": identity, "rally": destination, "rally_accepted": rally_ok}
	if not rally_ok:
		message = "Deployed; rally rejected (unit idle)"
	_publish()
	# Value identities remain valid even if a prior callback freed the unit/building.
	if _wallet.active:
		deployed.emit(job.id, identity, rally_ok)


func _still_head(job: Job) -> bool:
	return is_available() and not _jobs.is_empty() and _jobs[0] == job


func _set_message(value: String) -> void:
	if message != value:
		message = value
		_publish()


func _publish() -> void:
	if _wallet.active:
		changed.emit()


func close(refund_jobs: bool) -> void:
	if _closed:
		return
	_closed = true
	var payers: Dictionary[int, bool] = {}
	if refund_jobs:
		for job in _jobs:
			_wallet.refund(job.payer, job.paid)
			payers[job.payer] = true
	_jobs.clear()
	message = "Producer unavailable"
	# Remove ALL jobs and return ALL funds before the first removal notification.
	for payer in payers:
		_wallet.publish(payer)
	_publish()
	# Terminal producers will never publish again. Also break client lambdas that
	# captured this RefCounted queue while subscribing to its signals.
	for connection in changed.get_connections():
		changed.disconnect(connection["callable"])
	for connection in deployed.get_connections():
		deployed.disconnect(connection["callable"])
