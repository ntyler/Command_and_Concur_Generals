extends SceneTree
## Dependency-free integration checks using real scene, input, physics and navigation.
## Run with --headless --fixed-fps 60 --script res://tests/milestone_checks.gd.

var field: TestField
var failures: int = 0
var checks: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1280, 800)
	field = load("res://scenes/test_field.tscn").instantiate() as TestField
	root.add_child(field)
	current_scene = field
	field.camera_rig.edge_scrolling_enabled = false
	await _frames(5)
	await _capture("initial")
	_check(field.units.size() == 12, "12 friendly units instantiated")
	var ids: Array[int] = []
	for unit in field.units:
		ids.append(unit.unit_id)
		_check(unit.owner_id == 1 and ids.count(unit.unit_id) == 1, "unique friendly identity %02d" % unit.unit_id)
		_check(not field.camera_rig.camera.is_position_behind(unit.global_position) and root.get_visible_rect().has_point(_screen(unit)), "unit %02d in initial camera view" % unit.unit_id)
	await _selection_checks()
	await _camera_checks()
	await _movement_checks()
	print("MILESTONE_CHECKS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _selection_checks() -> void:
	var first := field.units[0]
	var second := field.units[1]
	await _click(_screen(first), MOUSE_BUTTON_LEFT)
	_check(field.selection.selected_units() == [first], "click selects one unit")
	_check(first.selection_indicator.visible and not first.moving, "selection ring visible; click does not move")
	await _click(_screen(second), MOUSE_BUTTON_LEFT)
	_check(field.selection.selected_units() == [second] and not first.selection_indicator.visible, "another click replaces selection and hides old ring")
	await _click(_screen(first), MOUSE_BUTTON_LEFT, true)
	_check(field.selection.selected_units().size() == 2, "Shift-click adds")
	await _click(_screen(first), MOUSE_BUTTON_LEFT, true)
	_check(field.selection.selected_units() == [second], "Shift-click toggles off")
	await _click(_world_screen(Vector3(-20, 0, -10)), MOUSE_BUTTON_LEFT)
	_check(field.selection.selected_units().is_empty(), "empty ground clears")
	await _click(_world_screen(Vector3(0, 0, 15)), MOUSE_BUTTON_RIGHT)
	_check(field.last_command_slots.is_empty(), "right-click without selection does nothing")
	var rectangle := Rect2(_screen(first), Vector2.ONE)
	for unit in field.units:
		rectangle = rectangle.expand(_screen(unit))
	rectangle = rectangle.grow(12)
	var corners: Array[Vector2] = [rectangle.position, Vector2(rectangle.end.x, rectangle.position.y), rectangle.end, Vector2(rectangle.position.x, rectangle.end.y)]
	for direction in range(4):
		await _drag(corners[direction], corners[(direction + 2) % 4])
		_check(field.selection.selected_units().size() == 12, "drag direction %d selects all 12" % direction)
		_check(not field.selection.selection_box.visible, "drag rectangle disappears immediately")
	for unit in field.units:
		_check(unit.selection_indicator.visible, "selected unit %02d ring visible" % unit.unit_id)
	await _capture("selected")
	await _click(_screen(first), MOUSE_BUTTON_LEFT)
	await _drag(_screen(second) - Vector2(9, 9), _screen(second) + Vector2(9, 9), true)
	_check(field.selection.selected_units().size() == 2 and field.selection.selected_units().has(first), "Shift-drag adds and preserves outside selection")
	await _drag(_screen(second) - Vector2(9, 9), _screen(second) + Vector2(9, 9), true)
	_check(field.selection.selected_units().size() == 2, "repeated Shift-drag never duplicates references")
	_button(_screen(first), MOUSE_BUTTON_LEFT, true)
	_motion(_screen(first) + Vector2(5, 0))
	_check(not field.selection.selection_box.visible, "five-pixel movement remains a click")
	_motion(_screen(first) + Vector2(6, 0))
	_check(field.selection.selection_box.visible, "six-pixel movement begins a drag")
	var escape := InputEventKey.new()
	escape.physical_keycode = KEY_ESCAPE
	escape.pressed = true
	root.push_input(escape, true)
	_check(not field.selection.selection_box.visible and not field.camera_rig.gesture_active, "Escape cancels immediately")
	_button(_screen(first), MOUSE_BUTTON_LEFT, false)
	_button(_screen(first), MOUSE_BUTTON_LEFT, true)
	_motion(_screen(second))
	field.selection.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	_check(not field.selection.selection_box.visible, "focus loss cancels drag")
	_button(_screen(first), MOUSE_BUTTON_LEFT, false)
	var before := field.selection.selected_units()
	await _click(Vector2(50, 60), MOUSE_BUTTON_LEFT)
	_check(field.selection.selected_units() == before, "interface click is consumed")
	_button(_screen(first), MOUSE_BUTTON_LEFT, true)
	_motion(Vector2(50, 60))
	_button(Vector2(50, 60), MOUSE_BUTTON_LEFT, false)
	_check(not field.selection.selection_box.visible and not field.camera_rig.gesture_active, "release over interface cancels drag")
	_motion(Vector2(700, 650))
	# Ownership is checked independently of picking geometry.
	second.owner_id = 2
	await _click(_screen(second), MOUSE_BUTTON_LEFT)
	_check(field.selection.selected_units().is_empty(), "non-friendly unit cannot be selected")
	second.owner_id = 1


func _camera_checks() -> void:
	var rig := field.camera_rig
	_motion(Vector2(700, 650))
	for key in [KEY_W, KEY_A, KEY_S, KEY_D, KEY_UP, KEY_LEFT, KEY_DOWN, KEY_RIGHT]:
		rig.position = Vector3.ZERO
		rig.pan_velocity = Vector2.ZERO
		var event := InputEventKey.new()
		event.physical_keycode = key
		event.pressed = true
		Input.parse_input_event(event)
		await _frames(15)
		event.pressed = false
		Input.parse_input_event(event)
		var direction := Vector3.ZERO
		if key in [KEY_W, KEY_UP]: direction.z = -1
		if key in [KEY_S, KEY_DOWN]: direction.z = 1
		if key in [KEY_A, KEY_LEFT]: direction.x = -1
		if key in [KEY_D, KEY_RIGHT]: direction.x = 1
		_check(rig.position.dot(direction) > 0.5, "camera key %s moves correct direction" % OS.get_keycode_string(key))
	rig.position = Vector3.ZERO
	rig.pan_velocity = Vector2.ZERO
	rig.edge_scrolling_enabled = true
	_motion(Vector2(1276, 400))
	await _frames(20)
	_check(rig.position.x > 1, "right-edge input scrolls camera")
	rig.edge_scrolling_enabled = false
	_motion(Vector2(700, 650))
	var initial_zoom := rig.target_zoom
	await _click(Vector2(700, 650), MOUSE_BUTTON_WHEEL_UP)
	_check(rig.target_zoom < initial_zoom, "wheel zooms in")
	for i in range(30):
		_button(Vector2(700, 650), MOUSE_BUTTON_WHEEL_UP, true)
	_check(is_equal_approx(rig.target_zoom, rig.minimum_zoom), "minimum zoom clamp")
	for i in range(50):
		_button(Vector2(700, 650), MOUSE_BUTTON_WHEEL_DOWN, true)
	_check(is_equal_approx(rig.target_zoom, rig.maximum_zoom), "maximum zoom clamp")
	var before_zoom := rig.target_zoom
	await _click(Vector2(50, 60), MOUSE_BUTTON_WHEEL_UP)
	_check(rig.target_zoom == before_zoom, "interface consumes wheel")
	rig.pan_velocity = Vector2(10, 10)
	var before_position := rig.position
	Input.action_press("camera_right")
	await _frames(10)
	Input.action_release("camera_right")
	_check(rig.position.is_equal_approx(before_position), "hovered interface blocks camera keys and inertia")
	_motion(Vector2(700, 650))
	rig.advance(100, Vector2(23, 23))
	_check(rig.position.x <= rig.map_bounds.end.x and rig.position.z <= rig.map_bounds.end.y, "positive camera bounds")
	rig.advance(100, Vector2(-23, -23))
	_check(rig.position.x >= rig.map_bounds.position.x and rig.position.z >= rig.map_bounds.position.y, "negative camera bounds")
	var positions: Array[Vector3] = []
	for fps in [30, 60, 144]:
		rig.position = Vector3.ZERO
		rig.pan_velocity = Vector2.ZERO
		for frame in range(fps):
			rig.advance(1.0 / fps, Vector2(12, 0))
		positions.append(rig.position)
	_check(positions[0].distance_to(positions[1]) < 0.001 and positions[1].distance_to(positions[2]) < 0.001, "camera integration agrees at 30/60/144 FPS")
	rig.position = Vector3.ZERO
	rig.pan_velocity = Vector2.ZERO
	rig.target_zoom = 52
	rig.zoom = 52
	rig.advance(0, Vector2.ZERO)
	await _frames(3)


func _movement_checks() -> void:
	var map := field.get_world_3d().get_navigation_map()
	_check(NavigationServer3D.map_get_iteration_id(map) > 0, "navigation synchronized")
	for obstacle in TestField.OBSTACLES:
		var center := obstacle.get_center()
		var projected := NavigationServer3D.map_get_closest_point(map, Vector3(center.x, 0, center.y))
		_check(not obstacle.has_point(Vector2(projected.x, projected.z)), "obstacle excluded from navigation")
	for point in [Vector3.ZERO, Vector3(29.9, 0, 23.9), Vector3(-8, 0, -1), Vector3(200, 0, 200)]:
		var slots := field.destinations.generate_slots(map, point, 12)
		_check(slots.size() == 12, "12 slots generated at %s" % point)
		var valid := true
		for a in slots.size():
			valid = valid and slots[a].distance_to(NavigationServer3D.map_get_closest_point(map, slots[a])) < 0.01
			for b in range(a + 1, slots.size()):
				valid = valid and slots[a].distance_to(slots[b]) >= field.destinations.slot_spacing - 0.001
		_check(valid, "slots remain navigable and separated after projection")
		_check(slots == field.destinations.generate_slots(map, point, 12), "slot generation is deterministic")
	field.selection.select_rectangle(Rect2(Vector2.ZERO, Vector2(1280, 800)), false)
	await _click(_world_screen(Vector3(-8, 0, -16)), MOUSE_BUTTON_RIGHT)
	_check(field.last_command_slots.size() == 12, "terrain raycast issues 12 distinct assignments")
	var original := field.units[0].assigned_destination
	await _frames(90)
	await _capture("moving")
	await _click(_world_screen(Vector3(-8, 0, -13)), MOUSE_BUTTON_RIGHT)
	_check(field.units[0].assigned_destination.distance_to(original) > 0.5 and field.units[0].moving, "replacement order interrupts active move")
	var crossed_obstacle := false
	for frame in range(1800):
		await physics_frame
		var still_moving := false
		for unit in field.units:
			still_moving = still_moving or unit.moving
			for obstacle in TestField.OBSTACLES:
				if obstacle.grow(0.35).has_point(Vector2(unit.global_position.x, unit.global_position.z)):
					crossed_obstacle = true
		if not still_moving:
			break
	_check(not crossed_obstacle, "all moving units route around obstacles without penetration")
	var arrived := true
	for unit in field.units:
		var distance := unit.global_position.distance_to(unit.assigned_destination)
		if unit.moving or distance > unit.stopping_distance + 0.01:
			print("ARRIVAL_DETAIL: id=", unit.unit_id, " position=", unit.global_position, " target=", unit.assigned_destination, " moving=", unit.moving, " velocity=", unit.velocity, " path=", unit.agent.get_current_navigation_path())
		_check(not unit.moving and distance <= unit.stopping_distance + 0.01, "unit %02d arrives within stop distance (%.3f)" % [unit.unit_id, distance])
		arrived = arrived and not unit.moving
	var parked: Array[Vector3] = []
	for unit in field.units:
		parked.append(unit.global_position)
	await _frames(180)
	var stable := arrived
	for i in field.units.size():
		stable = stable and field.units[i].global_position.distance_to(parked[i]) < 0.001
	_check(stable, "arrived group remains still for three seconds")
	var previous := field.last_command_slots.duplicate()
	await _click(_world_screen(Vector3(-8, 2, -1)), MOUSE_BUTTON_RIGHT)
	_check(field.last_command_slots == previous, "clicking obstacle fails safely")
	await _click(Vector2(1278, 2), MOUSE_BUTTON_RIGHT)
	_check(field.last_command_slots == previous, "click outside ground fails safely")
	# A second long route exercises the other side of the map and both eastern obstacles.
	field.issue_move(Vector3(18, 0, 15))
	for frame in range(1800):
		await physics_frame
		var still_moving := false
		for unit in field.units:
			still_moving = still_moving or unit.moving
			for obstacle in TestField.OBSTACLES:
				if obstacle.grow(0.35).has_point(Vector2(unit.global_position.x, unit.global_position.z)):
					crossed_obstacle = true
		if not still_moving:
			break
	var second_arrival := true
	for unit in field.units:
		second_arrival = second_arrival and not unit.moving and unit.global_position.distance_to(unit.assigned_destination) <= unit.stopping_distance + 0.01
		if unit.moving or unit.global_position.distance_to(unit.assigned_destination) > unit.stopping_distance + 0.01:
			print("SECOND_ROUTE_DETAIL: id=", unit.unit_id, " position=", unit.global_position, " target=", unit.assigned_destination, " moving=", unit.moving, " velocity=", unit.velocity, " path=", unit.agent.get_current_navigation_path())
	_check(second_arrival and not crossed_obstacle, "group completes second route around eastern obstacles")
	await _capture("arrived")
	# Remove a selected unit to validate reference cleanup without adding a game system.
	field.units[11].queue_free()
	await _frames(3)
	_check(field.selection.selected_units().size() == 11, "freed selected unit is pruned safely")


func _frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame


func _capture(label: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://validation-output")
	var result := root.get_texture().get_image().save_png("res://validation-output/%s.png" % label)
	_check(result == OK, "rendered %s screenshot saved" % label)


func _screen(unit: RTSUnit) -> Vector2:
	return _world_screen(unit.selection_anchor.global_position)


func _world_screen(point: Vector3) -> Vector2:
	return field.camera_rig.camera.unproject_position(point)


func _motion(point: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	root.push_input(event, true)


func _button(point: Vector2, button: MouseButton, pressed: bool, shift: bool = false) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = button
	event.pressed = pressed
	event.shift_pressed = shift
	root.push_input(event, true)


func _click(point: Vector2, button: MouseButton, shift: bool = false) -> void:
	_motion(point)
	_button(point, button, true, shift)
	_button(point, button, false, shift)
	await _frames(2)


func _drag(start: Vector2, finish: Vector2, shift: bool = false) -> void:
	_motion(start)
	_button(start, MOUSE_BUTTON_LEFT, true, shift)
	_motion(finish)
	_check(field.selection.selection_box.visible, "rectangle visible while dragging")
	_button(finish, MOUSE_BUTTON_LEFT, false, shift)
	_check(not field.selection.selection_box.visible, "rectangle hidden on release before next frame")
	await _frames(2)


func _check(condition: bool, description: String) -> void:
	checks += 1
	if condition:
		print("PASS: ", description)
	else:
		failures += 1
		push_error("FAIL: " + description)
