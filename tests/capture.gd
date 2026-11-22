extends Node
## Boots the title screen, presses start, then renders the level for a few
## seconds, drives synthetic input, and saves
## viewport captures so the visuals can be reviewed without a human at the keys.
##
##   /Applications/Godot.app/Contents/MacOS/Godot --path . res://tests/capture.tscn

const SHOT_DIR := "/tmp/neon_rust_shots"


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(SHOT_DIR)
	# Watchdog: a stuck capture must not leave a dead window on screen forever.
	get_tree().create_timer(45.0).timeout.connect(func() -> void:
		push_warning("capture timed out")
		get_tree().quit(2)
	)
	_run()


func _run() -> void:
	var shell: Node = load("res://main.tscn").instantiate()
	add_child(shell)
	await get_tree().create_timer(0.6).timeout
	await _shot("00_title")

	# Same path a player takes: press start on the title screen.
	var start := InputEventAction.new()
	start.action = "restart"
	start.pressed = true
	Input.parse_input_event(start)
	await get_tree().create_timer(0.3).timeout
	if shell.get_node_or_null("Stage") == null:
		push_warning("stage did not start from the title screen")
		get_tree().quit(2)
		return
	await get_tree().create_timer(0.9).timeout
	Input.warp_mouse(Vector2(760, 300))
	await _shot("01_intro")

	# Stage a readable fight: a chaser line, a brute and a spitter.
	await get_tree().create_timer(2.2).timeout
	var enemy_scene: PackedScene = load("res://modules/enemies/enemy.tscn")
	var player := Game.player as PlayerUnit
	var origin := player.global_position if player != null else Vector2(800, 500)
	var placements := [
		[Enemy.Kind.CHASER, Vector2(180, -120)],
		[Enemy.Kind.CHASER, Vector2(240, 40)],
		[Enemy.Kind.CHASER, Vector2(160, 150)],
		[Enemy.Kind.BRUTE, Vector2(330, -30)],
		[Enemy.Kind.SPITTER, Vector2(300, 210)],
	]
	for entry in placements:
		var enemy := enemy_scene.instantiate() as Enemy
		enemy.configure(entry[0], 3)
		enemy.position = origin + (entry[1] as Vector2)
		Game.enemies_root.add_child(enemy)

	Input.action_press("fire")
	Input.warp_mouse(Vector2(900, 260))
	await get_tree().create_timer(0.55).timeout
	await _shot("02_combat")

	Input.action_press("move_right")
	await get_tree().create_timer(0.6).timeout
	Input.action_release("move_right")
	await get_tree().create_timer(0.35).timeout
	await _shot("03_dash_in")
	Input.action_release("fire")

	# Drop a pickup in front of the player for a clean read of the sprite set.
	var pickup_scene: PackedScene = load("res://modules/pickups/pickup.tscn")
	var pickup := pickup_scene.instantiate() as Pickup
	pickup.setup(Pickup.Kind.OVERDRIVE)
	pickup.position = origin + Vector2(120, -90)
	Game.pickups_root.add_child(pickup)
	await get_tree().create_timer(0.4).timeout
	await _shot("04_pickup")

	# Wave-clear draft: force a clear so the card screen is in the shot set.
	Game.wave_cleared.emit(2, 65)
	await get_tree().create_timer(0.55).timeout
	await _shot("05_draft")
	var draft := shell.get_node("Stage").get_node("BuffSelect") as BuffSelect
	(draft.cards_box.get_child(0) as Button).pressed.emit()
	await get_tree().create_timer(0.55).timeout

	# Pause list, then the options page, so the menus are in the shot set too.
	var pause := InputEventAction.new()
	pause.action = "pause"
	pause.pressed = true
	Input.parse_input_event(pause)
	await get_tree().create_timer(0.45).timeout
	await _shot("06_pause")
	(shell.get_node("Stage").get_node("UI") as GameHud).btn_options.pressed.emit()
	await get_tree().create_timer(0.3).timeout
	await _shot("07_options")

	# Game-over panel with its buttons.
	(shell.get_node("Stage").get_node("UI") as GameHud).hide_options()
	Game.end_run()
	await get_tree().create_timer(0.4).timeout
	await _shot("08_gameover")

	get_tree().quit(0)


func _shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := "%s/%s.png" % [SHOT_DIR, label]
	var err := image.save_png(path)
	print("capture ", path, " ", image.get_size(), " err=", err)
	var cam := get_viewport().get_camera_2d()
	if cam != null:
		print("  cam=", cam.global_position, " player=", Game.player.global_position if is_instance_valid(Game.player) else Vector2.INF)
