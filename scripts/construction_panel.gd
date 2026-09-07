class_name ConstructionPanel
extends ProductionPanel

var build_button: Button
var site_status: Label
var site_progress: ProgressBar
var cancel_site_button: Button


func _ready() -> void:
	super._ready()
	var column := get_child(0) as VBoxContainer
	build_button = Button.new()
	build_button.focus_mode = Control.FOCUS_NONE
	column.add_child(build_button)
	build_button.pressed.connect(_begin)
	site_status = _label(column, "")
	site_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	site_progress = ProgressBar.new()
	site_progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(site_progress)
	cancel_site_button = Button.new()
	cancel_site_button.text = "Cancel construction · full refund"
	cancel_site_button.focus_mode = Control.FOCUS_NONE
	column.add_child(cancel_site_button)
	cancel_site_button.pressed.connect(_cancel_site)
	(field as ConstructionField).construction.changed.connect(_construction_changed)
	_refresh()


func _refresh() -> void:
	super._refresh()
	refresh_construction()


func refresh_construction() -> void:
	if not is_instance_valid(build_button) or not is_instance_valid(field):
		return
	var world := field as ConstructionField
	var building := field.selection.selected_building()
	build_button.visible = building != null and building.kind == RTSBuilding.Kind.HEADQUARTERS
	build_button.text = "Build Barracks · %d credits · %s s" % [world.construction_definition.credit_cost, str(world.construction_definition.duration)]
	if build_button.visible:
		var reason := world.construction.can_begin(field.selection.friendly_owner_id, building, world.construction_definition)
		build_button.disabled = not reason.is_empty()
		feedback.text = reason if not reason.is_empty() else "Green boundary · build area\nGold outlines · protected access"
	var site := (building as ConstructionBuilding).site if building is ConstructionBuilding else null
	var unfinished := site != null and site.state != ConstructionSite.State.OPERATIONAL
	site_status.visible = unfinished
	site_progress.visible = unfinished
	cancel_site_button.visible = unfinished
	if unfinished:
		train_button.hide()
		progress_bar.hide()
		rows.hide()
		feedback.text = "Paid %d credits · refundable until completion" % site.paid
		site_status.text = site.reason
		cancel_site_button.disabled = not site.cancellable()
	else:
		rows.show()


func _process(delta: float) -> void:
	super._process(delta)
	if is_instance_valid(site_progress) and site_progress.visible:
		var building := field.selection.selected_building() as ConstructionBuilding
		if building != null:
			site_progress.value = building.site.progress() * 100.0


func _construction_changed(_site_id: int) -> void:
	_refresh()


func _begin() -> void:
	var world := field as ConstructionField
	if is_instance_valid(world.placement):
		world.placement.begin(field.selection.selected_building())


func _cancel_site() -> void:
	var building := field.selection.selected_building() as ConstructionBuilding
	if building != null:
		(field as ConstructionField).construction.cancel(field.selection.friendly_owner_id, building.site.site_id)


func _exit_tree() -> void:
	if is_instance_valid(field) and (field as ConstructionField).construction.changed.is_connected(_construction_changed):
		(field as ConstructionField).construction.changed.disconnect(_construction_changed)
	super._exit_tree()
