class_name RTSHelpPanel
extends PanelContainer
## Local pointer surface; Escape is captured before the world's gesture observer.

var field: BaseAssaultField
var help_button: Button
var help_content: VBoxContainer


func _ready() -> void:
	position = Vector2(20, 20)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_force_pass_scroll_events = false
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.045, 0.085, 0.11, 0.96)
	style.border_color = Color("4a767d")
	style.set_border_width_all(1)
	style.set_content_margin_all(12)
	add_theme_stylebox_override("panel", style)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 12)
	add_child(column)
	var header := HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_theme_constant_override("separation", 12)
	column.add_child(header)
	help_button = Button.new()
	help_button.text = "Help"
	help_button.focus_mode = Control.FOCUS_NONE
	header.add_child(help_button)
	help_button.pressed.connect(toggle)
	_label(header, "F1 Help · F3 Debug", Color("a7ecdf"))
	help_content = VBoxContainer.new()
	help_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	help_content.add_theme_constant_override("separation", 10)
	column.add_child(help_content)
	_label(help_content, "FIELDWORK / COMBINED ARMS", Color("a7ecdf"))
	_label(help_content, "WASD / arrows / edges · Pan    Wheel · Zoom\nClick / drag · Select units    Shift · Toggle / add\nClick owned building · Select building\nRight-click ground · Move    X · Stop\nRight-click hostile · Attack with combat units")
	_label(help_content, "Collectors + right-click supply · Harvest\nLoaded collectors + right-click owned HQ · Deposit\nHQ · Build Barracks or Vehicle Factory\nProducer · Train / Cancel    Right-click ground · Rally\nPlacement · Left-click to build; right-click / Esc to cancel\nGreen boundary · Build area    Gold · Protected access")
	_label(help_content, "Minimap · Left-click to center; right-click to Move\nCtrl + 1–9 · Assign group    1–9 · Recall\nDouble-tap same number · Recall and center\nEsc · Close Help / cancel drag    F3 · Diagnostics")
	_label(help_content, "Destroy enemy HQ · Protect your HQ\nHarvest → build production → train → attack\nMint · Your team    Coral · Enemy    Walls block fire", Color("ffce78"))
	set_open(false)


func _label(parent: Node, value: String, color: Color = Color.WHITE) -> void:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)


func is_open() -> bool:
	return help_content.visible


func toggle() -> void:
	if field.gameplay_enabled:
		set_open(not is_open())


func set_open(opened: bool) -> void:
	help_content.visible = opened
	help_button.text = "Close Help" if opened else "Help"
	# Containers otherwise retain their expanded size and catch unseen clicks.
	size = Vector2.ZERO
	reset_size.call_deferred()


func _input(event: InputEvent) -> void:
	if not field.gameplay_enabled or not is_open():
		return
	var focus := get_viewport().gui_get_focus_owner()
	if focus != null and not is_ancestor_of(focus):
		return
	if event.is_action_pressed("cancel_selection") and not event.is_echo():
		set_open(false)
		get_viewport().set_input_as_handled()


func _unhandled_key_input(event: InputEvent) -> void:
	if field.gameplay_enabled and event.is_action_pressed("toggle_help") and not event.is_echo():
		toggle()
		get_viewport().set_input_as_handled()
