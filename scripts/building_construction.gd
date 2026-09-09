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


func eligible_builder(builder: Variant, requester: int) -> bool:
	var owner := field()
	return owner != null and owner.builder_construction_enabled and is_instance_valid(builder) and builder is Bulldozer and builder.owner_id == requester and builder.gameplay_field == owner and owner.contains_unit(builder) and builder.is_alive() and builder.combat_weapon == null and builder.combat != null and builder.combat.weapon == null and is_finite(builder.work_tolerance) and builder.work_tolerance >= builder.stopping_distance and builder.work_tolerance <= 0.5


func selected_builder(builder: Variant, requester: int) -> bool:
	if not eligible_builder(builder, requester) or requester != field().selection.friendly_owner_id:
		return false
	var selected := field().selection.selected_units()
	return selected.size() == 1 and selected[0] == builder


func assign_builder(builder: Bulldozer, site_id: int) -> bool:
	if not is_instance_valid(builder) or not selected_builder(builder, builder.owner_id) or not Engine.is_in_physics_frame():
		return false
	var site := sites.get(site_id) as ConstructionSite
	if site == null or not site.builder_required or not site.cancellable() or site.state == ConstructionSite.State.FAILED or site.owner_id != builder.owner_id:
		return false
	var body := site.building()
	if not is_instance_valid(body) or not field().contains_building(body) or body.owner_id != site.owner_id:
		return false
	var occupant := site.builder()
	if eligible_builder(occupant, site.owner_id) and occupant.assigned_site_id == site_id:
		return false # Including a duplicate request; it cannot reset recovery.
	if navigation.blocked and site.state != ConstructionSite.State.PREPARING:
		return false
	if not navigation.blocked and field().plan_builder_access(builder, site.rectangle).is_empty():
		return false # Rejection preserves the builder's previous valid order.
	_claim(site, builder)
	if field() != null and site.builder() == builder and builder.assigned_site_id == site_id and site.state != ConstructionSite.State.PREPARING:
		_dispatch_builder(site)
	if field() != null:
		changed.emit(site_id)
	return true # The accepted claim may already have been replaced by a callback.


func _claim(site: ConstructionSite, builder: Bulldozer) -> void:
	if not eligible_builder(builder, site.owner_id) or not site.cancellable():
		return
	var previous := sites.get(builder.assigned_site_id) as ConstructionSite
	if previous != null and previous != site:
		_detach(previous, false)
		_pause_state(previous)
	site.assignment_generation += 1
	site.builder_ref = weakref(builder)
	site.work_access = {}
	builder.assigned_site_id = site.site_id
	site.work_order_version = builder.order_version + 1
	site.reason = "Preparing site" if site.state == ConstructionSite.State.PREPARING else "Builder travelling"
	# Accepting the paid site replaces the old order now; only final approach waits
	# for map readiness. Claim state is fully committed before movement listeners.
	builder.halt_motion()


func _pause_state(site: ConstructionSite, reason: String = "Paused — needs builder") -> void:
	if site.state == ConstructionSite.State.PREPARING:
		site.reason = "Preparing site · needs builder"
	elif site.cancellable() and site.state != ConstructionSite.State.FAILED:
		site.state = ConstructionSite.State.PAUSED
		site.reason = reason


func _detach(site: ConstructionSite, stop_obsolete: bool, clear_unit: bool = true) -> void:
	var builder := site.builder()
	site.assignment_generation += 1
	site.builder_ref = null
	site.work_access = {}
	site.work_order_version = -1
	if clear_unit and is_instance_valid(builder) and builder.assigned_site_id == site.site_id:
		builder.clear_construction(site.site_id, stop_obsolete)


func release_builder(builder: Bulldozer, stop_obsolete: bool = false) -> void:
	if not is_instance_valid(builder):
		return
	var identity := builder.assigned_site_id
	var site := sites.get(identity) as ConstructionSite
	if site != null and site.builder() == builder:
		_pause_state(site)
		_detach(site, stop_obsolete)
	else:
		builder.clear_construction(identity, stop_obsolete)
	if field() != null and site != null:
		changed.emit(identity)


func _dispatch_builder(site: ConstructionSite) -> void:
	var builder := site.builder()
	if field() == null or not site.cancellable():
		return
	if not eligible_builder(builder, site.owner_id) or builder.assigned_site_id != site.site_id:
		site.state = ConstructionSite.State.PAUSED
		_pause_state(site)
		_detach(site, true)
		return
	var access := field().plan_builder_access(builder, site.rectangle)
	if access.is_empty():
		site.state = ConstructionSite.State.PAUSED
		_pause_state(site, "Paused — no clear reachable work position")
		_detach(site, true)
		return
	site.work_access = access
	builder.work_point = access["point"]
	site.state = ConstructionSite.State.TRAVELLING
	site.reason = "Builder travelling"
	site.work_order_version = builder.order_version + 1
	var assignment := site.assignment_generation
	if not builder.construction_move(access["point"]) and site.assignment_generation == assignment:
		_pause_state(site, "Paused — approach rejected")
		_detach(site, true)


func _advance_builder(site: ConstructionSite) -> void:
	if site.builder_ref == null:
		return
	var builder := site.builder()
	if not eligible_builder(builder, site.owner_id) or builder.assigned_site_id != site.site_id or builder.order_version != site.work_order_version or site.building().owner_id != site.owner_id:
		_pause_state(site)
		_detach(site, true)
		return
	if site.state in [ConstructionSite.State.PREPARING, ConstructionSite.State.FAILED] or navigation.blocked:
		return
	if builder.movement_state == RTSUnit.MovementState.FAILED:
		_pause_state(site, "Paused — builder approach failed")
		_detach(site, false) # Preserve terminal recovery evidence; next command is fresh.
		changed.emit(site.site_id)
		return
	if field().builder_can_work(builder, site):
		if site.state != ConstructionSite.State.CONSTRUCTING:
			site.state = ConstructionSite.State.CONSTRUCTING
			site.reason = "Constructing"
			site.started_frame = Engine.get_physics_frames()
			changed.emit(site.site_id)
	elif not builder.moving:
		_pause_state(site, "Paused — builder is out of position or obstructed")
		_detach(site, true)
		if field() != null:
			changed.emit(site.site_id)
	else:
		site.state = ConstructionSite.State.TRAVELLING
		site.reason = "Builder travelling"


func pause_all() -> void:
	# Freeze and teardown use this even after gameplay_enabled becomes false.
	var owner := navigation.field()
	if owner != null:
		for building in owner.registered_buildings():
			if building is BarrierBuilding:
				building.freeze_gate()
	for site in sites.values():
		if site.builder_required:
			_pause_state(site)
			_detach(site, false)


func can_begin(requester: int, headquarters: Variant, definition: ConstructionDefinition) -> String:
	var owner := field()
	if owner == null:
		return "Construction unavailable"
	if owner.builder_construction_enabled:
		if not selected_builder(headquarters, requester):
			return "Select exactly one owned Bulldozer to build"
	elif not is_instance_valid(headquarters) or not headquarters is RTSBuilding or not owner.contains_building(headquarters) or headquarters.kind != RTSBuilding.Kind.HEADQUARTERS or headquarters.owner_id != requester:
		return "Select a live owned headquarters"
	if not owner.supports_construction(definition) or not definition.is_valid():
		return "Unsupported building definition"
	if unfinished_id != 0:
		var pending := sites.get(unfinished_id) as ConstructionSite
		if pending != null and pending.state == ConstructionSite.State.CANCELLING:
			return pending.reason
		return "Finish or cancel the current site; cleanup must complete"
	if navigation.blocked:
		return "Navigation is not ready"
	if owner.credits.balance(requester) < definition.credit_cost:
		return "Insufficient credits: %s costs %d" % [definition.display_name(), definition.credit_cost]
	return ""


func validate(requester: int, headquarters: Variant, definition: ConstructionDefinition, point: Vector3, orientation: int = 0) -> String:
	var reason := can_begin(requester, headquarters, definition)
	if not reason.is_empty():
		return reason
	if not Engine.is_in_physics_frame():
		return "Placement requires a physics tick"
	if orientation not in [0, 90] or (not definition.is_barrier() and orientation != 0):
		return "Unsupported building orientation"
	point = field().construction_point(point, definition)
	reason = field().placement_geometry(point, definition, orientation)
	if reason.is_empty() and field().builder_construction_enabled:
		var footprint := definition.oriented_footprint(orientation)
		var rectangle := Rect2(Vector2(point.x, point.z) - footprint / 2.0, footprint)
		if field().plan_builder_access(headquarters as Bulldozer, rectangle).is_empty():
			return "No reachable clear builder work position"
	return reason


func place(requester: int, headquarters: Variant, definition: ConstructionDefinition, point: Vector3, orientation: int = 0) -> ConstructionResult:
	var reason := validate(requester, headquarters, definition, point, orientation)
	if not reason.is_empty():
		return ConstructionResult.reject(reason)
	var owner := field()
	point = owner.construction_point(point, definition)
	var wallet := owner.credits
	var initial_builder := headquarters as Bulldozer if owner.builder_construction_enabled else null
	var initial_order := initial_builder.order_version if initial_builder != null else -1
	var site := ConstructionSite.new()
	_next_id += 1
	site.site_id = _next_id
	site.owner_id = requester
	site.paid = definition.credit_cost
	site.duration = definition.duration
	site.builder_required = owner.builder_construction_enabled
	var footprint := definition.oriented_footprint(orientation)
	site.rectangle = Rect2(Vector2(point.x, point.z) - footprint / 2.0, footprint)
	site.orientation_degrees = orientation
	if not wallet.spend(requester, site.paid):
		return ConstructionResult.reject("Insufficient credits")
	sites[site.site_id] = site
	unfinished_id = site.site_id
	var body: ConstructionBuilding = GroundDefenseBattery.new() if definition.kind in [RTSBuilding.Kind.GROUND_DEFENSE_BATTERY, RTSBuilding.Kind.AIR_DEFENSE_BATTERY] else ConstructionBuilding.new()
	if definition.is_barrier():
		body.free()
		body = BarrierBuilding.new()
		(body as BarrierBuilding).orientation_degrees = orientation
	body.site = site
	body.operational = false
	body.owner_id = requester
	body.kind = definition.kind
	body.definition = definition
	body.recipe = load("res://production/rocket_vehicle.tres") if body.kind == RTSBuilding.Kind.VEHICLE_FACTORY else load("res://production/rifle.tres")
	if body.kind == RTSBuilding.Kind.SUPPLY_DEPOT:
		body.recipe = load("res://production/collector_truck.tres")
	elif body.kind == RTSBuilding.Kind.AIRFIELD:
		body.recipe = load("res://production/attack_helicopter.tres")
	elif body.kind in [RTSBuilding.Kind.POWER_PLANT, RTSBuilding.Kind.GROUND_DEFENSE_BATTERY, RTSBuilding.Kind.AIR_DEFENSE_BATTERY, RTSBuilding.Kind.WALL, RTSBuilding.Kind.GATE]:
		body.recipe = null
	body.footprint = footprint
	body.building_height = definition.height
	body.name = "Built%s%d" % [definition.display_name().replace(" ", ""), site.site_id]
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
			if site.builder_required and eligible_builder(initial_builder, requester) and initial_builder.order_version == initial_order and site.builder() == null:
				_claim(site, initial_builder)
			# Holding the accepted builder order can synchronously cancel/remove it.
			if field() != null and site.state == ConstructionSite.State.PREPARING:
				_request_navigation()
	# Historical acceptance survives a listener cancelling this committed site.
	var result := ConstructionResult.accept(site.site_id, site.paid, "%s site accepted" % definition.display_name())
	wallet.publish(requester)
	if field() != null:
		changed.emit(site.site_id)
	return result


func cancel(requester: int, site_id: int) -> ConstructionResult:
	return _cancel(requester, site_id, field())


func _cancel(requester: int, site_id: int, owner: ConstructionField) -> ConstructionResult:
	var site := sites.get(site_id) as ConstructionSite
	if owner == null or site == null or requester != site.owner_id or not site.cancellable():
		return ConstructionResult.reject("Only an owned unfinished site can be cancelled")
	var wallet := owner.credits
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
		owner._buildings.erase(body_id)
		owner._producers.erase(body_id)
		producer = body.production
		body.queue_free()
	# Detach silently until body, wallet and cleanup generation are committed.
	var builder := site.builder()
	var assignment := site.site_id
	_detach(site, false, false)
	_request_navigation()
	if is_instance_valid(builder) and builder.assigned_site_id == assignment:
		builder.clear_construction(assignment, true)
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
	# Existing destruction cleanup must also synchronize during result freeze.
	var owner := navigation.field()
	if owner == null or closed:
		return 0
	var rectangles: Array[Rect2] = owner.static_footprints.duplicate()
	var included: Dictionary[int, bool] = {}
	for site in sites.values():
		if site.state not in [ConstructionSite.State.CANCELLING, ConstructionSite.State.CANCELLED]:
			var body: RTSBuilding = site.building()
			if body is BarrierBuilding:
				rectangles.append_array(body.navigation_footprints())
				included[body.get_instance_id()] = true
			else:
				rectangles.append(site.rectangle)
	for body in owner.registered_buildings():
		if body is BarrierBuilding and not included.has(body.get_instance_id()) and (body.site == null or body.site.state not in [ConstructionSite.State.CANCELLING, ConstructionSite.State.CANCELLED]):
			rectangles.append_array(body.navigation_footprints())
	owner.obstacles = rectangles
	var generation := navigation.request(rectangles)
	for body in owner.registered_buildings():
		if body is BarrierBuilding and (body.navigation_pending or not body.effective_ready):
			body.nav_generation = generation
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
	if site == null or not site.cancellable():
		return
	var body := site.building()
	if not is_instance_valid(body) or not field().contains_building(body):
		cancel(site.owner_id, site.site_id)
		return
	if site.builder_required:
		_advance_builder(site)
		if field() == null or site.state != ConstructionSite.State.CONSTRUCTING or not field().builder_can_work(site.builder(), site):
			return
	if site.state != ConstructionSite.State.CONSTRUCTING or navigation.blocked or Engine.get_physics_frames() <= site.started_frame:
		return
	site.elapsed = minf(site.duration, site.elapsed + delta)
	if site.elapsed < site.duration:
		return
	# The first transition to OPERATIONAL is the precise completion boundary.
	# Subsequent cancellation is rejected; no geometry update occurs here.
	site.state = ConstructionSite.State.OPERATIONAL
	site.reason = "Complete" if site.builder_required else "Operational"
	unfinished_id = 0
	body.operational = true
	var rally := body.exit_position() + Vector3.RIGHT * 3.0
	if body.production != null and field().valid_producer_rally(body, rally):
		body.production.has_rally = true
		body.production.rally_point = rally
	(body as ConstructionBuilding).refresh_construction()
	_detach(site, true)
	# Complete the site and builder transition before power listeners can react.
	if field() != null:
		field().refresh_power()
	if field() != null:
		changed.emit(site.site_id)


func _navigation_ready(generation: int) -> void:
	if field() == null:
		return
	var site := sites.get(unfinished_id) as ConstructionSite
	if site == null or site.nav_generation != generation:
		return
	if site.state == ConstructionSite.State.PREPARING:
		if site.builder_required:
			_dispatch_builder(site)
		else:
			site.state = ConstructionSite.State.CONSTRUCTING
			site.reason = "Constructing"
			site.started_frame = Engine.get_physics_frames()
	elif site.state == ConstructionSite.State.CANCELLING:
		site.state = ConstructionSite.State.CANCELLED
		site.reason = "Cancelled; terrain restored"
		sites.erase(site.site_id)
		unfinished_id = 0
	if field() != null:
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
		_detach(site, true)
	else:
		site.reason = "Cleanup failed; refunded once. Reload this field to reset navigation."
	if field() != null:
		changed.emit(site.site_id)


func _departed(site_id: int) -> void:
	_reconcile_departure.call_deferred(site_id)


func _reconcile_barrier_departure(identity: int) -> void:
	var owner := navigation.field()
	if owner == null or closed:
		return
	var reference: WeakRef = owner._buildings.get(identity)
	var body := reference.get_ref() as RTSBuilding if reference != null else null
	if is_instance_valid(body) and owner.contains_building(body):
		return # An idle same-field reparent preserves its synchronized footprint.
	_request_navigation()


func _reconcile_departure(site_id: int) -> void:
	# A real deletion/reparent still needs lifecycle cleanup during manual pause.
	# The player-facing cancel path remains gated by field(); topology waits for resume.
	var owner := navigation.field()
	if owner == null or not owner._match_gameplay_enabled:
		return
	var site := sites.get(site_id) as ConstructionSite
	if site == null:
		return
	var body := site.building()
	if is_instance_valid(body) and owner.contains_building(body):
		return # Same-field reparent kept its identity.
	if site.cancellable():
		_cancel(site.owner_id, site_id, owner)
	elif site.state == ConstructionSite.State.OPERATIONAL:
		# Lifecycle removal is not player selling. No construction refund.
		sites.erase(site_id)
		_request_navigation()


func close() -> void:
	closed = true
	pause_all()
	navigation.close()
	if navigation.ready.is_connected(_navigation_ready):
		navigation.ready.disconnect(_navigation_ready)
		navigation.failed.disconnect(_navigation_failed)
	sites.clear()
	unfinished_id = 0
	for connection in changed.get_connections():
		changed.disconnect(connection["callable"])
