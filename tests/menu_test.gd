extends Node
## Verifies the app shell: boot lands on the title screen, a start press swaps
## in the stage, death swaps back to the title, and restart builds a fresh stage.
##
##   /Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
##       res://tests/menu_test.tscn

var _failures: Array[String] = []


func _ready() -> void:
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
	if is_instance_valid(Game.spawner):
		_fail("boot wired a spawner; the arena should not exist yet")

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

	# --- death pauses and offers redeploy -------------------------------
	Game.end_run()
	await get_tree().process_frame
	if not get_tree().paused:
		_fail("death did not pause the tree")

	# --- restart builds a fresh stage ------------------------------------
	var first_stage := stage
	await _send_action("restart")
	await _wait(0.25)
	stage = shell.get_node_or_null("Stage")
	if stage == null or stage == first_stage:
		_fail("restart did not build a fresh stage")
	if not Game.running:
		_fail("restart did not start a new run")
	if get_tree().paused:
		_fail("restart left the tree paused")
	if not is_instance_valid(Game.player):
		_fail("restart did not wire Game.player")

	# --- back to the title from the game-over screen ---------------------- 
	Game.end_run()
	await get_tree().process_frame
	await _send_action("pause")
	await _wait(0.25)
	if shell.get_node_or_null("Title") == null:
		_fail("game-over pause did not return to the title")
	if Game.running:
		_fail("title still reports a running game")
	if get_tree().paused:
		_fail("title was shown with the tree still paused")

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
