class_name StageLevel
extends Node2D
## Level owner: wires globals to the scene graph, starts the run, and handles
## pause / restart / mouse capture. Instantiated by main.gd, the app shell -
## this scene never boots on its own.

signal restart_requested
signal title_requested

const BUFF_SELECT_SCENE := preload("res://modules/buffs/ui/buff_select.tscn")

@onready var hud: GameHud = $UI as GameHud
@onready var spawner: WaveDirector = $Spawner as WaveDirector
@onready var camera: Camera2D = $Camera2D
@onready var crosshair: Sprite2D = $Crosshair

var _paused := false
var _buff_select: BuffSelect = null
var _choosing_buff := false


func _ready() -> void:
	# Death and pause both pause the whole tree, and a pausable node stops
	# receiving input while paused - which would silently kill R and Esc.
	process_mode = Node.PROCESS_MODE_ALWAYS
	Game.bullets_root = $Bullets
	Game.enemies_root = $Enemies
	Game.pickups_root = $Pickups
	Game.fx_root = $FX
	Game.spawner = $Spawner
	# The tower's spot comes from LaneSpec, so the scene file and the lane art
	# can never disagree about where the一塔 stands.
	var tower := get_node_or_null("Tower") as Node2D
	if tower != null:
		tower.global_position = LaneSpec.tower_pos()
	hud.resume_requested.connect(_on_hud_resume)
	hud.restart_requested.connect(_restart)
	hud.title_requested.connect(_leave_to_title)
	Game.wave_cleared.connect(_on_wave_cleared)
	_buff_select = BUFF_SELECT_SCENE.instantiate()
	add_child(_buff_select)
	_buff_select.chosen.connect(_on_buff_chosen)
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
	for path in ["Player", "Enemies", "Bullets", "Pickups", "FX", "Spawner", "Camera2D", "WorldTree", "Tower"]:
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
	# so the aim line from the stick takes over instead. A lane hero aims
	# itself, so there is nothing for a reticle to show either.
	var pad_aim := not Input.get_connected_joypads().is_empty()
	var self_aim := Game.player is PlayerUnit and (Game.player as PlayerUnit).auto_aim
	crosshair.visible = Game.running and not _paused and not pad_aim and not self_aim


func _unhandled_input(event: InputEvent) -> void:
	if _choosing_buff:
		# The draft owns input until a card is picked; Esc must not resume play.
		return
	if OS.is_debug_build():
		_log_pad_event(event)
	if event.is_action_pressed("pause"):
		if Game.running:
			_toggle_pause()
		else:
			# Run is over: the same key / pad button becomes "back to title".
			get_viewport().set_input_as_handled()
			_leave_to_title()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("restart") and _paused and event is InputEventKey:
		# R while the pause list is up restarts without leaving the screen.
		get_viewport().set_input_as_handled()
		_restart()
	elif event.is_action_pressed("restart") and not Game.running:
		# Mark the event handled BEFORE handing back to the shell: the shell
		# frees this node, and the viewport lookup would then be null.
		get_viewport().set_input_as_handled()
		_restart()
		return
	elif event.is_action_pressed("debug"):
		hud.toggle_debug()


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
	for action in ["pause", "restart", "mute", "dash", "fire", "force_staff", "special", "debug", "fullscreen"]:
		if event.is_action(action):
			line += "  [" + action + "]"
	hud.note_input(line)


func _toggle_pause() -> void:
	if not Game.running:
		return
	_paused = not _paused
	get_tree().paused = _paused
	hud.show_pause(_paused)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE if _paused else Input.MOUSE_MODE_HIDDEN)


func _on_wave_cleared(wave_index: int, bonus: int) -> void:
	if not Game.running or _choosing_buff:
		return
	var choices := Game.roll_buffs(3)
	if choices.is_empty():
		return
	_choosing_buff = true
	_paused = false
	hud.show_pause(false)
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	hud.clear_banner()
	_buff_select.offer(choices, wave_index, bonus)


func _on_buff_chosen(def: BuffDef) -> void:
	if not _choosing_buff:
		return
	_choosing_buff = false
	Game.add_buff(def)
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	hud.announce_buff(def)


func _on_hud_resume() -> void:
	if _paused:
		_toggle_pause()


func _leave_to_title() -> void:
	_paused = false
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	# Deferred: the quit button lives in the HUD this call is tearing down.
	call_deferred("emit_signal", "title_requested")


func _on_run_ended(_final_score: int, _best: int) -> void:
	_paused = false
	hud.show_pause(false)
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _restart() -> void:
	_paused = false
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	# Deferred so the shell never tears this node down from inside its own
	# input handler.
	call_deferred("emit_signal", "restart_requested")


func _exit_tree() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
