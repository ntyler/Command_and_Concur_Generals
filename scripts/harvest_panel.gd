class_name HarvestPanel
extends PanelContainer
## Collector details nested in the shared selection panel. No selection authority.

var field: HarvestField
var label: Label
var _connections: Array[Dictionary] = []
var _refreshing: bool = false
var _rejection_observers: Array[Dictionary] = []
var _elapsed: float = 0.0
var _closing: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_force_pass_scroll_events = false
	add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	label = Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 14)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	field.selection.selection_changed.connect(_selection_changed)
	_selection_changed(0)


func _selection_changed(_count: int) -> void:
	_refresh()


func _process(delta: float) -> void:
	# Rejected can_order() writes last_rejection without a work.changed signal.
	# Retain the prior 10 Hz presentation update only for that scalar; ordinary
	# cargo, activity and membership changes use their existing lifecycle signals.
	if _rejection_observers.is_empty():
		return
	_elapsed += delta
	if _elapsed < 0.1:
		return
	_elapsed = 0.0
	for observation in _rejection_observers:
		var work := observation["work"].get_ref() as CollectorHarvest
		if work != null and work.last_rejection != observation["reason"]:
			_refresh()
			return


func _refresh() -> void:
	if _refreshing or not _context_active():
		return
	_refreshing = true
	_disconnect_observers()
	_rejection_observers.clear()
	var lines := PackedStringArray()
	var selected := field.selection.selected_units()
	# Pruning can notify listeners that remove this field before the getter returns.
	if not _context_active():
		_refreshing = false
		return
	for candidate in selected:
		var unit := candidate as CollectorTruck
		if unit == null or not field.harvest_member(unit):
			continue
		var work := unit.harvesting
		_rejection_observers.append({"work": weakref(work), "reason": work.last_rejection})
		_watch(work, &"changed")
		_watch(unit, &"movement_state_changed", 1)
		_watch(unit, &"availability_changed")
		var identity := "Collector #%d · " % unit.unit_id if selected.size() > 1 else ""
		var activity := work.reason
		if work.state == CollectorHarvest.State.IDLE and unit.moving:
			activity = "Moving"
		elif work.state == CollectorHarvest.State.IDLE and unit.movement_state == RTSUnit.MovementState.FAILED:
			activity = "Movement failed"
		lines.append("%sCargo %d / %d · %s" % [identity, work.cargo, unit.cargo_capacity, activity])
		var dropoff := work.dropoff_node()
		if is_instance_valid(dropoff) and field.valid_dropoff(dropoff, unit.owner_id):
			_watch(dropoff, &"availability_changed")
			lines.append("Drop-off · %s" % dropoff.display_name())
		var cache := work.cache_node()
		if is_instance_valid(cache) and field.contains_cache(cache):
			_watch(cache.notifications, &"changed")
			_watch(cache, &"tree_exiting")
			lines.append("Supply %d · %d remaining" % [cache.cache_id, cache.remaining])
		if not work.last_rejection.is_empty():
			lines.append(work.last_rejection)
	visible = not lines.is_empty()
	label.text = "\n".join(lines)
	_refreshing = false
	field.production_panel._layout.call_deferred()


func _context_active() -> bool:
	return not _closing and is_inside_tree() and not is_queued_for_deletion() and is_instance_valid(field) and field.is_inside_tree() and not field.is_queued_for_deletion() and is_instance_valid(field.selection) and field.selection.is_inside_tree()


func _watch(emitter: Object, event: StringName, arguments: int = 0) -> void:
	var callback := _refresh.unbind(arguments) if arguments > 0 else _refresh
	if emitter.is_connected(event, callback):
		return # Two selected collectors can share the same supply notification.
	emitter.connect(event, callback)
	_connections.append({"emitter": weakref(emitter), "event": event, "callback": callback})


func _disconnect_observers() -> void:
	for connection in _connections:
		var emitter: Object = connection["emitter"].get_ref()
		if is_instance_valid(emitter) and emitter.is_connected(connection["event"], connection["callback"]):
			emitter.disconnect(connection["event"], connection["callback"])
	_connections.clear()


func _exit_tree() -> void:
	_closing = true
	_disconnect_observers()
	_rejection_observers.clear()
	if is_instance_valid(field) and is_instance_valid(field.selection) and field.selection.selection_changed.is_connected(_selection_changed):
		field.selection.selection_changed.disconnect(_selection_changed)
	field = null
