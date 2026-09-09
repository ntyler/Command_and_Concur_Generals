class_name ProductionPanel
extends PanelContainer
## Selection owns context; health, work and queues remain gameplay authorities.

var field: ProductionField
var credit_label: Label
var power_label: Label
var power_warning: Label
var identity_label: Label
var selection_details: Label
var context_content: VBoxContainer
var train_button: Button
var attack_move_button: Button
var attack_move_hint: Label
var progress_bar: ProgressBar
var feedback: Label
var rows: GridContainer
var cancel_buttons: Dictionary[int, Button] = {}
var _observed: UnitProduction
var _observed_actor: WeakRef
var _context_connections: Array[Dictionary] = []
var _closing: bool = false
var _refresh_revision: int = 0
var _observed_grid: PowerGrid


func _ready() -> void:
	custom_minimum_size = Vector2(350, 0)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_force_pass_scroll_events = false
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.045, 0.085, 0.11, 0.96)
	style.border_color = Color("4a767d")
	style.set_border_width_all(1)
	style.set_content_margin_all(10)
	add_theme_stylebox_override("panel", style)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 5)
	add_child(column)
	credit_label = _label(column, "")
	credit_label.add_theme_color_override("font_color", Color("ffce78"))
	power_label = _label(column, "")
	power_label.add_theme_font_size_override("font_size", 14)
	power_warning = _label(column, "LOW POWER · Barracks/Factory production %d%%" % roundi(PowerGrid.LOW_POWER_RATE * 100.0))
	power_warning.add_theme_font_size_override("font_size", 14)
	power_warning.add_theme_color_override("font_color", Color("ffce78"))
	power_warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	identity_label = _label(column, "")
	identity_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	context_content = VBoxContainer.new()
	context_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	context_content.add_theme_constant_override("separation", 4)
	column.add_child(context_content)
	selection_details = _label(context_content, "")
	selection_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	selection_details.add_theme_font_size_override("font_size", 14)
	attack_move_button = Button.new()
	attack_move_button.text = "Attack Move · Q"
	attack_move_button.focus_mode = Control.FOCUS_NONE
	attack_move_button.add_theme_font_size_override("font_size", 14)
	column.add_child(attack_move_button)
	attack_move_button.pressed.connect(_attack_move)
	attack_move_hint = _label(column, "")
	attack_move_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	attack_move_hint.add_theme_font_size_override("font_size", 14)
	attack_move_hint.add_theme_color_override("font_color", Color("ffce78"))
	train_button = Button.new()
	train_button.focus_mode = Control.FOCUS_NONE
	train_button.add_theme_font_size_override("font_size", 14)
	column.add_child(train_button)
	train_button.pressed.connect(_train)
	progress_bar = ProgressBar.new()
	progress_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(progress_bar)
	rows = GridContainer.new()
	rows.columns = 2
	rows.add_theme_constant_override("h_separation", 8)
	rows.add_theme_constant_override("v_separation", 3)
	rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(rows)
	feedback = _label(column, "")
	feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feedback.add_theme_font_size_override("font_size", 14)
	field.selection.selection_changed.connect(_selection_changed)
	field.selection.attack_move_targeting_changed.connect(_refresh)
	field.credits.changed.connect(_credits_changed)
	if field.power_enabled:
		_observed_grid = field.power_grid
		_observed_grid.changed.connect(_refresh)
	get_viewport().size_changed.connect(_layout)
	minimum_size_changed.connect(_layout)
	_refresh()
	_layout()


func _layout() -> void:
	if _closing or not is_inside_tree() or is_queued_for_deletion():
		return
	# Containers grow automatically; explicitly release the old height when a
	# queue or selection becomes smaller so empty HUD space never catches clicks.
	size = get_combined_minimum_size()
	position = Vector2(get_viewport_rect().size.x - size.x - 20, 20)


func _process(_delta: float) -> void:
	# One scalar read; no queue copies/rebuilding at frame rate.
	if _observed != null:
		progress_bar.value = _observed.progress() * 100.0


func _selection_changed(_count: int) -> void:
	_refresh()


func _credits_changed(_owner: int) -> void:
	_refresh()


func _refresh() -> void:
	if not _context_active():
		return
	_refresh_revision += 1
	var revision := _refresh_revision
	var snapshot: Dictionary = field.power_snapshot(field.selection.friendly_owner_id) if field.power_enabled else {}
	# Eligibility pruning may notify synchronously, change selection, or remove
	# this field. A nested refresh already owns the newer display in that case.
	if not _refresh_current(revision):
		return
	var building := field.selection.selected_building()
	var units := field.selection.selected_units()
	# Pruning can synchronously notify a departing field before returning.
	if not _refresh_current(revision):
		return
	_observe_context(building if building != null else (units[0] if units.size() == 1 else null))
	var producer: UnitProduction = building.production if building != null else null
	if producer != _observed:
		if _observed != null and _observed.changed.is_connected(_refresh):
			_observed.changed.disconnect(_refresh)
		_observed = producer
		if _observed != null:
			_observed.changed.connect(_refresh)
	credit_label.text = "Credits  %d" % field.credits.balance(field.selection.friendly_owner_id)
	power_label.visible = field.power_enabled
	power_warning.visible = field.power_enabled and bool(snapshot.get("low_power", false))
	if field.power_enabled:
		power_label.text = "Power: %d generated / %d required" % [snapshot.generated, snapshot.required]
	_show_selection(building, units)
	if building != null and field.power_enabled and building.definition != null:
		if building.kind == RTSBuilding.Kind.POWER_PLANT:
			var contribution := field.power_grid.contribution(building)
			selection_details.text += ("" if selection_details.text.is_empty() else "\n") + "Generation: %d power" % contribution.generated
		elif building.definition.power_required > 0:
			selection_details.text += "\nPower required: %d · Production rate: %d%%" % [building.definition.power_required, roundi(float(snapshot.multiplier) * 100.0)]
		selection_details.visible = not selection_details.text.is_empty()
	attack_move_button.visible = field.selection.has_attack_move_selection()
	attack_move_button.disabled = field.selection.attack_move_targeting
	attack_move_hint.visible = field.selection.attack_move_targeting
	attack_move_hint.text = "Attack Move · " + field.selection.attack_move_feedback + "\nRight-click / Esc · Cancel"
	if field.selection.attack_move_targeting:
		feedback.text = "" # Pending right-click cancels; ordinary command hints resume afterward.
	train_button.visible = producer != null
	progress_bar.visible = producer != null
	for row in rows.get_children():
		rows.remove_child(row)
		row.queue_free()
	cancel_buttons.clear()
	if building != null:
		feedback.text = "Headquarters" if building.kind == RTSBuilding.Kind.HEADQUARTERS else ""
	if producer == null:
		_layout.call_deferred()
		return
	var recipe := building.recipe
	var duration_label := "%s s" % str(recipe.training_duration) if recipe != null else ""
	if field.power_enabled and building.definition != null and building.definition.power_required > 0:
		duration_label += " base"
	train_button.text = "Train %s · %d cr · %s" % [recipe.display_name, recipe.credit_cost, duration_label] if recipe != null else "No recipe"
	train_button.disabled = not producer.is_available() or recipe == null or producer.count() >= building.queue_capacity or field.credits.balance(building.owner_id) < recipe.credit_cost
	feedback.text = producer.message
	if producer.count() >= building.queue_capacity:
		feedback.text += "\nQueue full"
	elif recipe != null and field.credits.balance(building.owner_id) < recipe.credit_cost:
		feedback.text += "\nInsufficient credits"
	if feedback.text.is_empty():
		feedback.text = "Right-click ground to set rally."
	for job in producer.jobs():
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_theme_constant_override("separation", 3)
		rows.add_child(row)
		var compact_name := str(job["name"]).replace("Rifle Unit", "Rifle").replace("Rocket Vehicle", "Rocket").replace("Collector Truck", "Collector")
		var label := _label(row, "#%d %s" % [job["id"], compact_name])
		label.add_theme_font_size_override("font_size", 14)
		label.clip_text = true
		label.custom_minimum_size.x = 80
		label.tooltip_text = "#%d %s" % [job["id"], job["name"]]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var cancel := Button.new()
		cancel.text = "Cancel"
		cancel.focus_mode = Control.FOCUS_NONE
		cancel.add_theme_font_size_override("font_size", 14)
		cancel.tooltip_text = "Cancel #%d · %s" % [job["id"], job["name"]]
		row.add_child(cancel)
		# Bind both queue and stable ID, so a delayed old row cannot cancel a
		# similarly positioned job in a newly selected producer.
		cancel.pressed.connect(_cancel.bind(producer, job["id"]))
		cancel_buttons[job["id"]] = cancel
	_layout.call_deferred()


func _show_selection(building: RTSBuilding, units: Array[RTSUnit]) -> void:
	selection_details.text = ""
	feedback.text = ""
	if building != null:
		identity_label.text = "%s · Owner %d" % [building.display_name(), building.owner_id]
		if is_instance_valid(building.health):
			selection_details.text = _health_text(building.health)
	elif units.is_empty():
		identity_label.text = "Select units or a building."
	elif units.size() == 1:
		var unit := units[0]
		identity_label.text = "%s · #%d" % [_unit_name(unit), unit.unit_id]
		if is_instance_valid(unit.combat) and is_instance_valid(unit.combat.health):
			selection_details.text = _health_text(unit.combat.health)
		if not unit is CollectorTruck:
			selection_details.text += (" · " if not selection_details.text.is_empty() else "") + _unit_status(unit)
		feedback.text = _commands(units)
	else:
		identity_label.text = "%d units selected" % units.size()
		var counts: Dictionary[String, int] = {}
		for unit in units:
			var kind := _unit_name(unit).replace("Rifle Unit", "Rifle")
			counts[kind] = counts.get(kind, 0) + 1
		var names: Array[String] = counts.keys()
		names.sort()
		var types := PackedStringArray()
		for kind in names:
			types.append("%d %s" % [counts[kind], kind])
		selection_details.text = " · ".join(types)
		feedback.text = _commands(units)
	selection_details.visible = not selection_details.text.is_empty()
	feedback.visible = not feedback.text.is_empty() or building != null


func _unit_name(unit: RTSUnit) -> String:
	return unit.combat_weapon.display_name if unit.combat_weapon != null else unit.unit_display_name


func _health_text(health: UnitHealth) -> String:
	return "%d / %d HP" % [ceili(health.current), ceili(health.maximum)]


func _unit_status(unit: RTSUnit) -> String:
	if is_instance_valid(unit.attack_move) and unit.attack_move.active:
		return "Engaging" if is_instance_valid(unit.attack_move.target_actor()) else "Attack-moving"
	if is_instance_valid(unit.combat):
		match unit.combat.state:
			CombatController.State.PURSUING: return "Pursuing target"
			CombatController.State.FACING: return "Facing target"
			CombatController.State.ATTACKING: return "Attacking"
			CombatController.State.BLOCKED: return "Fire blocked"
			CombatController.State.TARGET_INVALIDATED: return unit.combat.end_reason.replace("_", " ").capitalize()
	match unit.movement_state:
		RTSUnit.MovementState.TRAVELLING: return "Moving"
		RTSUnit.MovementState.CONGESTED: return "Route congested"
		RTSUnit.MovementState.RECOVERING: return "Recovering route"
		RTSUnit.MovementState.FAILED: return "Movement failed"
	return "Idle"


func _commands(units: Array[RTSUnit]) -> String:
	var armed := false
	var collecting := false
	for unit in units:
		armed = armed or unit.combat_weapon != null
		collecting = collecting or unit is CollectorTruck
	var commands := "Right-click ground · Move    X · Stop"
	if armed:
		commands += "\nRight-click hostile · Attack"
	if collecting:
		var dropoffs := field.dropoff_command_hint()
		commands += "\nCollector + right-click supply / %s · Harvest / deposit" % dropoffs
	return commands


func _observe_context(actor: Node) -> void:
	var old: Object = _observed_actor.get_ref() if _observed_actor != null else null
	if old == actor and (actor != null or _context_connections.is_empty()):
		return
	_disconnect_context()
	if actor == null:
		return
	_observed_actor = weakref(actor)
	_watch(actor, &"availability_changed")
	if actor is RTSUnit:
		var unit := actor as RTSUnit
		_watch(unit, &"movement_state_changed", 1)
		if is_instance_valid(unit.attack_move):
			_watch(unit.attack_move, &"changed")
		if is_instance_valid(unit.combat):
			_watch(unit.combat, &"state_changed", 1)
			_watch(unit.combat.health, &"damaged", 2)
	elif actor is RTSBuilding and is_instance_valid((actor as RTSBuilding).health):
		_watch((actor as RTSBuilding).health, &"damaged", 2)


func _watch(emitter: Object, event: StringName, arguments: int = 0) -> void:
	var callback := _refresh.unbind(arguments) if arguments > 0 else _refresh
	emitter.connect(event, callback)
	_context_connections.append({"emitter": weakref(emitter), "event": event, "callback": callback})


func _disconnect_context() -> void:
	for connection in _context_connections:
		var emitter: Object = connection["emitter"].get_ref()
		if is_instance_valid(emitter) and emitter.is_connected(connection["event"], connection["callback"]):
			emitter.disconnect(connection["event"], connection["callback"])
	_context_connections.clear()
	_observed_actor = null


func _train() -> void:
	if not _context_active() or not field.gameplay_enabled:
		return
	var building := field.selection.selected_building()
	if building == null or building.production == null:
		_refresh()
		return
	var result := building.production.enqueue(field.selection.friendly_owner_id, building.recipe)
	if is_instance_valid(self) and not result.accepted:
		feedback.text = result.reason


func _attack_move() -> void:
	if _context_active():
		field.selection.begin_attack_move()


func _cancel(producer: UnitProduction, job_id: int) -> void:
	if not _context_active() or not field.gameplay_enabled:
		return
	var building := field.selection.selected_building()
	if building == null or building.production != producer:
		_refresh()
		return
	var result := producer.cancel(field.selection.friendly_owner_id, job_id)
	if is_instance_valid(self) and not result.accepted:
		feedback.text = result.reason


func _label(parent: Node, text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label


func _context_active() -> bool:
	return not _closing and is_inside_tree() and not is_queued_for_deletion() and is_instance_valid(field) and field.is_inside_tree() and not field.is_queued_for_deletion() and is_instance_valid(field.selection) and field.selection.is_inside_tree()


func _refresh_current(revision: int) -> bool:
	return _context_active() and revision == _refresh_revision


func _exit_tree() -> void:
	# Deferred layouts may outlive tree membership. Detach the long-lived
	# viewport as well as model signals before child teardown emits more changes.
	_closing = true
	_refresh_revision += 1
	if _observed_grid != null and _observed_grid.changed.is_connected(_refresh):
		_observed_grid.changed.disconnect(_refresh)
	_observed_grid = null
	if get_viewport().size_changed.is_connected(_layout):
		get_viewport().size_changed.disconnect(_layout)
	if minimum_size_changed.is_connected(_layout):
		minimum_size_changed.disconnect(_layout)
	_disconnect_context()
	if _observed != null and _observed.changed.is_connected(_refresh):
		_observed.changed.disconnect(_refresh)
	_observed = null
	if is_instance_valid(field):
		if field.credits.changed.is_connected(_credits_changed):
			field.credits.changed.disconnect(_credits_changed)
		if is_instance_valid(field.selection) and field.selection.selection_changed.is_connected(_selection_changed):
			field.selection.selection_changed.disconnect(_selection_changed)
		if is_instance_valid(field.selection) and field.selection.attack_move_targeting_changed.is_connected(_refresh):
			field.selection.attack_move_targeting_changed.disconnect(_refresh)
	field = null
