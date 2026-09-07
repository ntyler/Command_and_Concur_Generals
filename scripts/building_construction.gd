class_name BuildingConstruction
extends RefCounted
## Construction owns site/accounting transitions; ordinary UnitProduction owns
## all queues. Notifications follow commits and may synchronously destroy nodes.

signal changed(site_id: int)

var navigation: ConstructionNavigation
var sites: Dictionary[int, ConstructionSite] = {}
var unfinished_id: int = 0
var closed: bool = false
var _next_id: int = 0
var _field_ref: WeakRef


func _init(owner: ConstructionField) -> void:
	_field_ref = weakref(owner)
	navigation = ConstructionNavigation.new(owner)
	navigation.ready.connect(_navigation_ready)
	navigation.failed.connect(_navigation_failed)


func field() -> ConstructionField:
	var value := _field_ref.get_ref() as ConstructionField
	return value if not closed and is_instance_valid(value) and value.is_inside_tree() and value.gameplay_enabled and not value._closing and not value.is_queued_for_deletion() else null


func can_begin(requester: int, headquarters: Variant, definition: ConstructionDefinition) -> String:
	var owner := field()
	if owner == null or not is_instance_valid(headquarters) or not headquarters is RTSBuilding or not owner.contains_building(headquarters) or headquarters.kind != RTSBuilding.Kind.HEADQUARTERS or headquarters.owner_id != requester:
		return "Select a live owned headquarters"
	if definition == null or definition != owner.construction_definition or not definition.is_valid():
		return "Unsupported barracks definition"
	if unfinished_id != 0:
		var pending := sites.get(unfinished_id) as ConstructionSite
		if pending != null and pending.state == ConstructionSite.State.CANCELLING:
			return pending.reason
		return "Finish or cancel the current site; cleanup must complete"
	if navigation.blocked:
		return "Navigation is not ready"
	if owner.credits.balance(requester) < definition.credit_cost:
		return "Insufficient credits: barracks costs %d" % definition.credit_cost
	return ""


func validate(requester: int, headquarters: Variant, definition: ConstructionDefinition, point: Vector3) -> String:
	var reason := can_begin(requester, headquarters, definition)
	if not reason.is_empty():
		return reason
	if not Engine.is_in_physics_frame():
		return "Placement requires a physics tick"
	return field().placement_geometry(point, definition)


func place(requester: int, headquarters: Variant, definition: ConstructionDefinition, point: Vector3) -> ConstructionResult:
	var reason := validate(requester, headquarters, definition, point)
	if not reason.is_empty():
		return ConstructionResult.reject(reason)
	var owner := field()
	var wallet := owner.credits
	var site := ConstructionSite.new()
	_next_id += 1
	site.site_id = _next_id
	site.owner_id = requester
	site.paid = definition.credit_cost
	site.duration = definition.duration
	site.rectangle = Rect2(Vector2(point.x, point.z) - definition.footprint / 2.0, definition.footprint)
	if not wallet.spend(requester, site.paid):
		return ConstructionResult.reject("Insufficient credits")
	sites[site.site_id] = site
	unfinished_id = site.site_id
	var body := ConstructionBuilding.new()
	body.site = site
	body.operational = false
	body.owner_id = requester
	body.kind = RTSBuilding.Kind.BARRACKS
	body.footprint = definition.footprint
	body.building_height = definition.height
	body.name = "BuiltBarracks%d" % site.site_id
	body.position = point
	site.body_ref = weakref(body)
	body.tree_exiting.connect(_departed.bind(site.site_id))
	owner.add_child(body)
	if field() != null and is_instance_valid(body):
		owner.register_building(body)
	if field() != null:
		if not is_instance_valid(body) or not owner.contains_building(body):
			cancel(requester, site.site_id)
		elif site.state == ConstructionSite.State.PREPARING:
			site.nav_generation = _request_navigation()
	# Historical acceptance survives a listener cancelling this committed site.
	var result := ConstructionResult.accept(site.site_id, site.paid, "Barracks site accepted")
	wallet.publish(requester)
	if field() != null:
		changed.emit(site.site_id)
	return result


func cancel(requester: int, site_id: int) -> ConstructionResult:
	var site := sites.get(site_id) as ConstructionSite
	if field() == null or site == null or requester != site.owner_id or not site.cancellable():
		return ConstructionResult.reject("Only an owned unfinished site can be cancelled")
	var wallet := field().credits
	site.state = ConstructionSite.State.CANCELLING
	site.reason = "Cancelled and refunded; restoring navigation"
	if not site.refunded:
		site.refunded = true
		wallet.refund(site.owner_id, site.paid)
	var body := site.building()
	var producer: UnitProduction
	# Eligibility, registration, collision and footprint are removed before any
	# selection or wallet notification. The slot stays owned until map readiness.
	if is_instance_valid(body):
		body.operational = false
		body.collision_layer = 0
		var body_id := body.get_instance_id()
		field()._buildings.erase(body_id)
		field()._producers.erase(body_id)
		producer = body.production
		body.queue_free()
	site.nav_generation = _request_navigation()
	# close() itself publishes producer.changed. It belongs AFTER the complete
	# cancellation commit; its listeners may immediately free body or field.
	if producer != null:
		producer.close(false)
	if field() != null and is_instance_valid(field().selection):
		field().selection.prune_building()
	wallet.publish(site.owner_id)
	if field() != null:
		changed.emit(site_id)
	return ConstructionResult.accept(site_id, site.paid, "Construction refunded once; cleanup pending")


func _request_navigation() -> int:
	if field() == null:
		return 0
	var rectangles: Array[Rect2] = field().static_footprints.duplicate()
	for site in sites.values():
		if site.state not in [ConstructionSite.State.CANCELLING, ConstructionSite.State.CANCELLED]:
			rectangles.append(site.rectangle)
	field().obstacles = rectangles
	var generation := navigation.request(rectangles)
	var pending := sites.get(unfinished_id) as ConstructionSite
	if pending != null and pending.state in [ConstructionSite.State.PREPARING, ConstructionSite.State.CANCELLING]:
		pending.nav_generation = generation
	return generation


func advance(delta: float) -> void:
	if field() == null:
		return
	navigation.advance(delta)
	if field() == null:
		return
	var site := sites.get(unfinished_id) as ConstructionSite
	if site == null or site.state != ConstructionSite.State.CONSTRUCTING or Engine.get_physics_frames() <= site.started_frame:
		return
	var body := site.building()
	if not is_instance_valid(body) or not field().contains_building(body):
		cancel(site.owner_id, site.site_id)
		return
	site.elapsed = minf(site.duration, site.elapsed + delta)
	if site.elapsed < site.duration:
		return
	# The first transition to OPERATIONAL is the precise completion boundary.
	# Subsequent cancellation is rejected; no geometry update occurs here.
	site.state = ConstructionSite.State.OPERATIONAL
	site.reason = "Operational"
	body.operational = true
	unfinished_id = 0
	var rally := body.exit_position() + Vector3.RIGHT * 3.0
	if field().valid_rally(body.exit_position(), rally):
		body.production.has_rally = true
		body.production.rally_point = rally
	(body as ConstructionBuilding).refresh_construction()
	changed.emit(site.site_id)


func _navigation_ready(generation: int) -> void:
	if field() == null:
		return
	var site := sites.get(unfinished_id) as ConstructionSite
	if site == null or site.nav_generation != generation:
		return
	if site.state == ConstructionSite.State.PREPARING:
		site.state = ConstructionSite.State.CONSTRUCTING
		site.reason = "Constructing"
		site.started_frame = Engine.get_physics_frames()
	elif site.state == ConstructionSite.State.CANCELLING:
		site.state = ConstructionSite.State.CANCELLED
		site.reason = "Cancelled; terrain restored"
		sites.erase(site.site_id)
		unfinished_id = 0
	changed.emit(site.site_id)


func _navigation_failed(generation: int, reason: String) -> void:
	if field() == null:
		return
	var site := sites.get(unfinished_id) as ConstructionSite
	if site == null or site.nav_generation != generation:
		return
	if site.state == ConstructionSite.State.PREPARING:
		site.state = ConstructionSite.State.FAILED
		site.reason = reason
	else:
		site.reason = "Cleanup failed; refunded once. Reload this field to reset navigation."
	changed.emit(site.site_id)


func _departed(site_id: int) -> void:
	_reconcile_departure.call_deferred(site_id)


func _reconcile_departure(site_id: int) -> void:
	if field() == null:
		return
	var site := sites.get(site_id) as ConstructionSite
	if site == null:
		return
	var body := site.building()
	if is_instance_valid(body) and field().contains_building(body):
		return # Same-field reparent kept its identity.
	if site.cancellable():
		cancel(site.owner_id, site_id)
	elif site.state == ConstructionSite.State.OPERATIONAL:
		# Lifecycle removal is not player selling. No construction refund.
		sites.erase(site_id)
		_request_navigation()


func close() -> void:
	closed = true
	navigation.close()
	if navigation.ready.is_connected(_navigation_ready):
		navigation.ready.disconnect(_navigation_ready)
		navigation.failed.disconnect(_navigation_failed)
	sites.clear()
	unfinished_id = 0
	for connection in changed.get_connections():
		changed.disconnect(connection["callable"])
