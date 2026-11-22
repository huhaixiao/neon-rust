extends Node
## Registers the input map at runtime so the bindings live in code and are
## obvious to change. Keyboard/mouse first, gamepad second.
## Autoloaded as `InputSetup`.

func _enter_tree() -> void:
	_add("move_left", [KEY_A, KEY_LEFT], [], [], [[JOY_AXIS_LEFT_X, -1.0]])
	_add("move_right", [KEY_D, KEY_RIGHT], [], [], [[JOY_AXIS_LEFT_X, 1.0]])
	_add("move_up", [KEY_W, KEY_UP], [], [], [[JOY_AXIS_LEFT_Y, -1.0]])
	_add("move_down", [KEY_S, KEY_DOWN], [], [], [[JOY_AXIS_LEFT_Y, 1.0]])
	_add("fire", [], [MOUSE_BUTTON_LEFT], [JOY_BUTTON_RIGHT_SHOULDER], [[JOY_AXIS_TRIGGER_RIGHT, 1.0]])
	_add("dash", [KEY_SPACE], [], [JOY_BUTTON_B, JOY_BUTTON_LEFT_SHOULDER], [])
	_add("pause", [KEY_ESCAPE], [], [JOY_BUTTON_START, JOY_BUTTON_BACK], [])
	_add("restart", [KEY_R, KEY_ENTER], [], [JOY_BUTTON_A], [])
	_add("mute", [KEY_M], [], [], [])
	_add("fullscreen", [KEY_F11], [], [], [])
	_add("debug", [KEY_F3], [], [JOY_BUTTON_RIGHT_STICK], [])


func _add(
	action: String,
	keys: Array,
	mouse_buttons: Array,
	joy_buttons: Array,
	joy_axes: Array
) -> void:
	# Leave a hand-authored binding alone if one already exists in the editor.
	if InputMap.has_action(action) and not InputMap.action_get_events(action).is_empty():
		return
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.15)
	for code in keys:
		var key := InputEventKey.new()
		key.physical_keycode = code
		InputMap.action_add_event(action, key)
	for button in mouse_buttons:
		var mouse := InputEventMouseButton.new()
		mouse.button_index = button
		InputMap.action_add_event(action, mouse)
	for button in joy_buttons:
		var pad := InputEventJoypadButton.new()
		pad.button_index = button
		InputMap.action_add_event(action, pad)
	for pair in joy_axes:
		var axis := InputEventJoypadMotion.new()
		axis.axis = pair[0]
		axis.axis_value = pair[1]
		InputMap.action_add_event(action, axis)
