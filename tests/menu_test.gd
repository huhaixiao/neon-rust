extends Node
## Verifies the app shell and the pause menu:
## boot lands on the title screen, a start press swaps in the stage, the pause
## list can resume / restart / open options / quit to title, and the game-over
## buttons redeploy or return to the title.
##
##   /Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
##       res://tests/menu_test.tscn

var _failures: Array[String] = []


func _ready() -> void:
	L10n.set_locale("en", false)
	_run()


func _run() -> void:
	await get_tree().process_frame
	var shell: Node = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(shell)
	await get_tree().process_frame

	# --- boot: title, and no arena behind it ----------------------------
	if shell.get_node_or_null("Title") == null:
		_fail("boot did not land on the title screen")
	if Game.running:
		_fail("boot started a run before the player asked for one")
	if is_instance_valid(Game.player):
		_fail("boot wired a player; the arena should not exist yet")

	# The title ignores input for a moment so a held key cannot skip it.
	await _wait(0.5)

	# --- start press -----------------------------------------------------
	await _send_action("restart")
	await _wait(0.25)
	if shell.get_node_or_null("Title") != null:
		_fail("title screen was not replaced after start")
	var stage: Node = shell.get_node_or_null("Stage")
	if stage == null:
		_fail("stage did not appear after start")
		_report()
		return
	if not Game.running:
		_fail("run did not start")
	if not is_instance_valid(Game.player):
		_fail("stage did not wire Game.player")

	# --- pause menu: resume ------------------------------------------------
	var hud := stage.get_node("UI") as GameHud
	await _send_action("pause")
	await get_tree().process_frame
	if not get_tree().paused:
		_fail("pause did not pause the tree")
	if not hud.pause_layer.visible:
		_fail("pause did not open the pause menu")
	if get_viewport().gui_get_focus_owner() != hud.btn_resume:
		_fail("pause menu did not focus RESUME (pad navigation would be lost)")
	hud.btn_resume.pressed.emit()
	await get_tree().process_frame
	if get_tree().paused:
		_fail("RESUME did not unpause")
	if hud.pause_layer.visible:
		_fail("RESUME left the pause menu on screen")

	# --- pause menu: options page -----------------------------------------
	await _send_action("pause")
	await get_tree().process_frame
	hud.btn_options.pressed.emit()
	await get_tree().process_frame
	if not hud.options_layer.visible or hud.pause_layer.visible:
		_fail("OPTIONS did not replace the pause list")
	if get_viewport().gui_get_focus_owner() != hud.btn_fullscreen:
		_fail("options did not focus the first row")
	hud.btn_sound.pressed.emit()
	if not Game.is_muted():
		_fail("SOUND button did not mute the bus")
	hud.btn_sound.pressed.emit()
	if Game.is_muted():
		_fail("SOUND button did not unmute the bus")
	# Fullscreen is only asserted as a no-crash toggle: headless windows ignore it.
	hud.btn_fullscreen.pressed.emit()
	hud.btn_back.pressed.emit()
	await get_tree().process_frame
	if hud.options_layer.visible or not hud.pause_layer.visible:
		_fail("BACK did not return to the pause list")
	if get_viewport().gui_get_focus_owner() != hud.btn_options:
		_fail("BACK did not restore focus")

	# --- pause menu: quit to title ----------------------------------------
	hud.btn_quit.pressed.emit()
	await _wait(0.25)
	if shell.get_node_or_null("Title") == null:
		_fail("QUIT TO TITLE did not show the title screen")
	if Game.running:
		_fail("title still reports a running game")
	if get_tree().paused:
		_fail("title was shown with the tree still paused")

	# --- redeploy from the game-over screen -------------------------------
	await _wait(0.4)
	await _send_action("restart")
	await _wait(0.25)
	stage = shell.get_node_or_null("Stage")
	if stage == null:
		_fail("could not start a second run")
		_report()
		return
	hud = stage.get_node("UI") as GameHud
	Game.end_run()
	await get_tree().process_frame
	if not hud.game_over.visible:
		_fail("game over panel did not open")
	if get_viewport().gui_get_focus_owner() != hud.btn_redeploy:
		_fail("game over did not focus REDEPLOY")
	var first_stage := stage
	hud.btn_redeploy.pressed.emit()
	await _wait(0.25)
	stage = shell.get_node_or_null("Stage")
	if stage == null or stage == first_stage:
		_fail("REDEPLOY did not build a fresh stage")
	if not Game.running or get_tree().paused:
		_fail("REDEPLOY did not resume a live run")

	# --- quit to title from the game-over screen -------------------------
	Game.end_run()
	await get_tree().process_frame
	(shell.get_node("Stage").get_node("UI") as GameHud).btn_title.pressed.emit()
	await _wait(0.25)
	if shell.get_node_or_null("Title") == null:
		_fail("game-over QUIT TO TITLE did not show the title")

	_report()


func _send_action(action: String) -> void:
	var pressed := InputEventAction.new()
	pressed.action = action
	pressed.pressed = true
	Input.parse_input_event(pressed)
	await get_tree().process_frame
	var released := InputEventAction.new()
	released.action = action
	released.pressed = false
	Input.parse_input_event(released)
	await get_tree().process_frame


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _fail(message: String) -> void:
	_failures.append(message)
	print("FAIL: ", message)


func _report() -> void:
	get_tree().paused = false
	if _failures.is_empty():
		print("MENU TEST: PASS")
		get_tree().quit(0)
	else:
		print("MENU TEST: FAIL (", _failures.size(), " checks)")
		get_tree().quit(1)
