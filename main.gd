extends Node2D
## Level owner: wires globals to the scene graph, starts the run, and handles
## pause / restart / mouse capture.

@onready var hud: GameHud = $UI as GameHud
@onready var spawner: WaveDirector = $Spawner as WaveDirector
@onready var camera: Camera2D = $Camera2D
@onready var crosshair: Sprite2D = $Crosshair

var _paused := false


func _ready() -> void:
	# Death and pause both pause the whole tree, and a pausable node stops
	# receiving input while paused - which would silently kill R and Esc.
	process_mode = Node.PROCESS_MODE_ALWAYS
	Game.bullets_root = $Bullets
	Game.enemies_root = $Enemies
	Game.pickups_root = $Pickups
	Game.fx_root = $FX
	Game.spawner = $Spawner
	_freeze_gameplay_while_paused()
	_setup_camera()
	Game.run_ended.connect(_on_run_ended)
	Game.reset_run()
	spawner.start()
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)


func _freeze_gameplay_while_paused() -> void:
	# PROCESS_MODE_INHERIT propagates from the parent, so this node being
	# ALWAYS would drag every gameplay child along with it. Re-arm the
	# gameplay subtrees as PAUSABLE; only the input/HUD layer stays awake.
	for path in ["Player", "Enemies", "Bullets", "Pickups", "FX", "Spawner", "Camera2D"]:
		var node := get_node_or_null(path)
		if node != null:
			node.process_mode = Node.PROCESS_MODE_PAUSABLE


func _setup_camera() -> void:
	camera.limit_left = int(Game.arena.position.x)
	camera.limit_top = int(Game.arena.position.y)
	camera.limit_right = int(Game.arena.end.x)
	camera.limit_bottom = int(Game.arena.end.y)
	camera.global_position = Game.arena.get_center()


func _process(_delta: float) -> void:
	crosshair.global_position = get_global_mouse_position()
	# With a pad plugged in the reticle would just sit where the cursor was,
	# so the aim line from the stick takes over instead.
	var pad_aim := not Input.get_connected_joypads().is_empty()
	crosshair.visible = Game.running and not _paused and not pad_aim


func _unhandled_input(event: InputEvent) -> void:
	if OS.is_debug_build():
		_log_pad_event(event)
	if event.is_action_pressed("pause"):
		_toggle_pause()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("restart") and not Game.running:
		# Mark the event handled BEFORE reloading: the reload frees this node,
		# and the viewport lookup would then be null.
		get_viewport().set_input_as_handled()
		_restart()
		return
	elif event.is_action_pressed("fullscreen"):
		_toggle_fullscreen()
	elif event.is_action_pressed("debug"):
		hud.toggle_debug()
	elif event.is_action_pressed("mute"):
		AudioServer.set_bus_mute(0, not AudioServer.is_bus_mute(0))


func _log_pad_event(event: InputEvent) -> void:
	var line := ""
	if event is InputEventJoypadButton:
		var button := event as InputEventJoypadButton
		line = "PAD%d  BTN %d  %s" % [
			button.device, button.button_index, "DOWN" if button.pressed else "UP"]
	elif event is InputEventJoypadMotion:
		var motion := event as InputEventJoypadMotion
		if absf(motion.axis_value) < 0.7:
			return
		line = "PAD%d  AXIS %d  %+.2f" % [motion.device, motion.axis, motion.axis_value]
	else:
		return
	for action in ["pause", "restart", "mute", "dash", "fire", "debug", "fullscreen"]:
		if event.is_action(action):
			line += "  [" + action + "]"
	hud.note_input(line)


func _toggle_fullscreen() -> void:
	var window := get_window()
	if window.mode == Window.MODE_EXCLUSIVE_FULLSCREEN or window.mode == Window.MODE_FULLSCREEN:
		window.mode = Window.MODE_WINDOWED
	else:
		window.mode = Window.MODE_FULLSCREEN


func _toggle_pause() -> void:
	if not Game.running:
		return
	_paused = not _paused
	get_tree().paused = _paused
	hud.show_pause(_paused)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE if _paused else Input.MOUSE_MODE_HIDDEN)


func _on_run_ended(_final_score: int, _best: int) -> void:
	_paused = false
	hud.show_pause(false)
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _restart() -> void:
	_paused = false
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	# Deferred so the reload never tears this node down from inside its own
	# input handler.
	get_tree().call_deferred("reload_current_scene")


func _exit_tree() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
