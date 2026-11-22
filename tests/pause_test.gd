extends Node
## Verifies that pausing the tree truly freezes gameplay while main.gd (the
## input owner) keeps running so START can unpause.
##
##   /Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
##       res://tests/pause_test.tscn

var _failures: Array[String] = []


func _ready() -> void:
	_run()


func _run() -> void:
	await get_tree().process_frame
	var level: Node = (load("res://modules/stage/stage.tscn") as PackedScene).instantiate()
	add_child(level)
	await get_tree().process_frame
	await get_tree().physics_frame

	var player := Game.player as PlayerUnit
	if player == null:
		_fail("player not wired")
		_report()
		return

	# --- control: movement actually works while unpaused ----------------
	Input.action_press("move_right")
	var start_x: float = player.global_position.x
	for i in 20:
		await get_tree().physics_frame
	var moving_dx: float = player.global_position.x - start_x
	if moving_dx <= 1.0:
		_fail("player did not move while unpaused (dx=%.2f)" % moving_dx)
	Input.action_release("move_right")

	# --- freeze one enemy + one bullet so we can watch them ------------
	var enemy := (load("res://modules/enemies/enemy.tscn") as PackedScene).instantiate() as Enemy
	enemy.configure(Enemy.Kind.CHASER, 1)
	enemy.position = Vector2(400.0, 300.0)
	Game.enemies_root.add_child(enemy)
	var bullet := (load("res://modules/projectiles/bullet.tscn") as PackedScene).instantiate()
	bullet.setup(Vector2.RIGHT, 100.0, 300.0, true, Color.WHITE)
	bullet.position = Vector2(500.0, 300.0)
	Game.bullets_root.add_child(bullet)
	await get_tree().physics_frame

	# --- pause ----------------------------------------------------------
	get_tree().paused = true
	await get_tree().process_frame

	var frozen_player: Vector2 = player.global_position
	var frozen_enemy: Vector2 = enemy.global_position
	var frozen_bullet: Vector2 = bullet.global_position
	Input.action_press("move_right")
	for i in 40:
		await get_tree().physics_frame
	Input.action_release("move_right")

	if player.global_position.distance_to(frozen_player) > 0.5:
		_fail("player still moved while paused: %.2f px" % player.global_position.distance_to(frozen_player) )
	if enemy.global_position.distance_to(frozen_enemy) > 0.5:
		_fail("enemy still moved while paused")
	if is_instance_valid(bullet) and bullet.global_position.distance_to(frozen_bullet) > 0.5:
		_fail("bullet still flew while paused")
	if not level.can_process():
		_fail("level cannot process while paused: START / Esc would be dead")

	# --- resume ---------------------------------------------------------
	get_tree().paused = false
	await get_tree().process_frame
	Input.action_press("move_right")
	var resume_x: float = player.global_position.x
	for i in 20:
		await get_tree().physics_frame
	Input.action_release("move_right")
	if player.global_position.x - resume_x <= 1.0:
		_fail("player did not resume after unpausing")

	_report()


func _fail(message: String) -> void:
	_failures.append(message)
	print("FAIL: ", message)


func _report() -> void:
	get_tree().paused = false
	if _failures.is_empty():
		print("PAUSE TEST: PASS")
		get_tree().quit(0)
	else:
		print("PAUSE TEST: FAIL (", _failures.size(), " checks)")
		get_tree().quit(1)
