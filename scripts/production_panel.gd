class_name ProductionPanel
extends PanelContainer
## Read-only presentation plus explicit production API requests. No queue ownership.

var field: ProductionField
var credit_label: Label
var identity_label: Label
var train_button: Button
var progress_bar: ProgressBar
var feedback: Label
var rows: VBoxContainer
var cancel_buttons: Dictionary[int, Button] = {}
var _observed: UnitProduction


func _ready() -> void:
	position = Vector2(930, 20)
	custom_minimum_size = Vector2(330, 0)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_force_pass_scroll_events = false
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.045, 0.085, 0.11, 0.96)
	style.border_color = Color("4a767d")
	style.set_border_width_all(1)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	add_theme_stylebox_override("panel", style)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 8)
	add_child(column)
	credit_label = _label(column, "")
	credit_label.add_theme_color_override("font_color", Color("ffce78"))
	identity_label = _label(column, "")
	train_button = Button.new()
	train_button.focus_mode = Control.FOCUS_NONE
	column.add_child(train_button)
	train_button.pressed.connect(_train)
	progress_bar = ProgressBar.new()
	progress_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(progress_bar)
	rows = VBoxContainer.new()
	rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(rows)
	feedback = _label(column, "")
	feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	field.selection.selection_changed.connect(_selection_changed)
	field.credits.changed.connect(_credits_changed)
	_refresh()


func _process(_delta: float) -> void:
	# One scalar read; no queue copies/rebuilding at frame rate.
	if _observed != null:
		progress_bar.value = _observed.progress() * 100.0


func _selection_changed(_count: int) -> void:
	_refresh()


func _credits_changed(_owner: int) -> void:
	_refresh()


func _refresh() -> void:
	if not is_instance_valid(field) or not is_inside_tree():
		return
	var building := field.selection.selected_building()
	var producer: UnitProduction = building.production if building != null else null
	if producer != _observed:
		if _observed != null and _observed.changed.is_connected(_refresh):
			_observed.changed.disconnect(_refresh)
		_observed = producer
		if _observed != null:
			_observed.changed.connect(_refresh)
	credit_label.text = "Credits  %d" % field.credits.balance(field.selection.friendly_owner_id)
	identity_label.text = "%s · Owner %d" % [building.display_name(), building.owner_id] if building != null else "Select an owned building"
	train_button.visible = producer != null
	progress_bar.visible = producer != null
	for row in rows.get_children():
		rows.remove_child(row)
		row.queue_free()
	cancel_buttons.clear()
	feedback.text = "Fixed headquarters" if building != null else "Train at your barracks."
	if producer == null:
		return
	var recipe := building.recipe
	train_button.text = "Train %s · %d credits · %s s" % [recipe.display_name, recipe.credit_cost, str(recipe.training_duration)] if recipe != null else "No recipe"
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
		rows.add_child(row)
		var label := _label(row, "#%d  %s" % [job["id"], job["name"]])
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var cancel := Button.new()
		cancel.text = "Cancel"
		cancel.focus_mode = Control.FOCUS_NONE
		row.add_child(cancel)
		# Bind both queue and stable ID, so a delayed old row cannot cancel a
		# similarly positioned job in a newly selected producer.
		cancel.pressed.connect(_cancel.bind(producer, job["id"]))
		cancel_buttons[job["id"]] = cancel


func _train() -> void:
	var building := field.selection.selected_building()
	if building == null or building.production == null:
		_refresh()
		return
	var result := building.production.enqueue(field.selection.friendly_owner_id, building.recipe)
	if is_instance_valid(self) and not result.accepted:
		feedback.text = result.reason


func _cancel(producer: UnitProduction, job_id: int) -> void:
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


func _exit_tree() -> void:
	if _observed != null and _observed.changed.is_connected(_refresh):
		_observed.changed.disconnect(_refresh)
	if is_instance_valid(field):
		if field.credits.changed.is_connected(_credits_changed):
			field.credits.changed.disconnect(_credits_changed)
		if is_instance_valid(field.selection) and field.selection.selection_changed.is_connected(_selection_changed):
			field.selection.selection_changed.disconnect(_selection_changed)
