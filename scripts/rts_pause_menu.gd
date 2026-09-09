class_name RTSPauseMenu
extends CanvasLayer
## Sole match Escape owner. GUI-consumed keys retain their existing owner.

enum Confirmation { NONE, RESTART, QUIT }

var field: BaseAssaultField
var overlay: ColorRect
var menu_panel: VBoxContainer
var confirmation_panel: VBoxContainer
var confirmation: Confirmation = Confirmation.NONE
var confirmation_label: Label
var resume_button: Button
var restart_button: Button
var quit_button: Button
var confirm_button: Button
var cancel_button: Button


func _ready() -> void:
	name = "PauseHUD"
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	overlay = ColorRect.new()
	overlay.name = "PauseOverlay"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.025, 0.05, 0.075, 0.90)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.mouse_force_pass_scroll_events = false
	add_child(overlay)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(center)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(420, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("0b2029")
	style.border_color = Color("4a767d")
	style.set_border_width_all(1)
	style.set_content_margin_all(28)
	card.add_theme_stylebox_override("panel", style)
	center.add_child(card)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 20)
	card.add_child(column)
	var title := Label.new()
	title.text = "PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 38)
	title.add_theme_color_override("font_color", Color("ffce78"))
	column.add_child(title)
	menu_panel = VBoxContainer.new()
	menu_panel.add_theme_constant_override("separation", 12)
	column.add_child(menu_panel)
	resume_button = _button(menu_panel, "Resume · Esc", field.resume_match)
	restart_button = _button(menu_panel, "Restart Match…", request_confirmation.bind(Confirmation.RESTART))
	quit_button = _button(menu_panel, "Quit to Desktop…", request_confirmation.bind(Confirmation.QUIT))
	confirmation_panel = VBoxContainer.new()
	confirmation_panel.add_theme_constant_override("separation", 14)
	column.add_child(confirmation_panel)
	confirmation_label = Label.new()
	confirmation_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	confirmation_label.custom_minimum_size = Vector2(360, 62)
	confirmation_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	confirmation_panel.add_child(confirmation_label)
	confirm_button = _button(confirmation_panel, "Confirm", confirm_action)
	cancel_button = _button(confirmation_panel, "Back · Esc", cancel_confirmation)
	close()


func _button(parent: Node, title: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = title
	button.custom_minimum_size = Vector2(360, 48)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func open() -> void:
	confirmation = Confirmation.NONE
	menu_panel.show()
	confirmation_panel.hide()
	overlay.show()
	resume_button.grab_focus()


func close() -> void:
	confirmation = Confirmation.NONE
	confirmation_panel.hide()
	overlay.hide()
	var focus := get_viewport().gui_get_focus_owner()
	if focus != null and is_ancestor_of(focus):
		focus.release_focus()


func request_confirmation(kind: Confirmation) -> void:
	if not is_instance_valid(field) or not field.manual_pause_active or kind == Confirmation.NONE:
		return
	confirmation = kind
	confirmation_label.text = "Restart this match?\nYour current match will be lost." if kind == Confirmation.RESTART else "Quit to Desktop?\nYour current match will be lost."
	confirm_button.text = "Restart Match" if kind == Confirmation.RESTART else "Quit to Desktop"
	menu_panel.hide()
	confirmation_panel.show()
	cancel_button.grab_focus()


func cancel_confirmation() -> void:
	if not is_instance_valid(field) or not field.manual_pause_active:
		return
	open()


func confirm_action() -> void:
	if not is_instance_valid(field) or not field.manual_pause_active:
		return
	if confirmation == Confirmation.RESTART:
		if not field.restart_match():
			confirmation_label.text = "Restart could not load the match.\nGo back to resume or try again."
	elif confirmation == Confirmation.QUIT:
		get_tree().quit()


func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_action("cancel_selection") or not is_instance_valid(field) or field.is_queued_for_deletion():
		return
	# Consume the whole key sequence, including OS repeats, before any gameplay
	# unhandled hook. A repeated press can never toggle the newly opened menu.
	get_viewport().set_input_as_handled()
	if not event.is_pressed() or event.is_echo() or field.result != BaseAssaultField.Result.RUNNING:
		return
	if field.manual_pause_active:
		if confirmation != Confirmation.NONE:
			cancel_confirmation()
		else:
			field.resume_match()
	else:
		field.pause_match()
