class_name HarvestPanel
extends PanelContainer
## Contextual cargo only; the existing production panel remains the credit UI.

var field: HarvestField
var label: Label
var _selected: Array[WeakRef] = []
var _elapsed: float = 0.0


func _ready() -> void:
	position = Vector2(930, 300)
	custom_minimum_size = Vector2(330, 0)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_force_pass_scroll_events = false
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.045, 0.085, 0.11, 0.96)
	style.set_content_margin_all(14)
	add_theme_stylebox_override("panel", style)
	label = Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 300
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	field.selection.selection_changed.connect(_selection_changed)
	_selection_changed(0)


func _selection_changed(_count: int) -> void:
	_selected.clear()
	for unit in field.selection.selected_units():
		if unit is CollectorTruck:
			_selected.append(weakref(unit))
	_refresh()


func _process(delta: float) -> void:
	if _selected.is_empty():
		return
	_elapsed += delta
	if _elapsed >= 0.1:
		_elapsed = 0.0
		_refresh()


func _refresh() -> void:
	var lines := PackedStringArray()
	for reference in _selected:
		var unit := reference.get_ref() as CollectorTruck
		if not is_instance_valid(unit) or not field.harvest_member(unit):
			continue
		var work := unit.harvesting
		lines.append("Collector %d · Cargo %d / %d\n%s" % [unit.unit_id, work.cargo, unit.cargo_capacity, work.reason])
		var cache := work.cache_node()
		if is_instance_valid(cache) and field.contains_cache(cache):
			lines.append("Supply %d · %d remaining" % [cache.cache_id, cache.remaining])
		if not work.last_rejection.is_empty():
			lines.append(work.last_rejection)
	visible = not lines.is_empty()
	label.text = "\n".join(lines)
