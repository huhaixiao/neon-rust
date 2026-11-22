extends Node
## Headless smoke test scene: boots the level, checks wiring, then exercises
## damage, bullet collision, pickups and the end-of-run path directly.
##
##   /Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
##       res://tests/smoke_test.tscn

var _failures: Array[String] = []


func _ready() -> void:
	L10n.set_locale("en", false)
	_run()


func _run() -> void:
	await get_tree().process_frame
	var level_scene: PackedScene = load("res://modules/stage/stage.tscn")
	if level_scene == null:
		_fail("stage.tscn did not load")
		_report()
		return
	var level: Node = level_scene.instantiate()
	add_child(level)
	await get_tree().process_frame
	await get_tree().process_frame

	if not is_instance_valid(Game.player):
		_fail("Game.player was not wired by stage.gd")
	if not is_instance_valid(Game.bullets_root):
		_fail("Game.bullets_root was not wired")
	if not is_instance_valid(Game.spawner):
		_fail("Game.spawner was not wired")

	var player := Game.player as PlayerUnit
	if player != null and player.health != player.max_health:
		_fail("player did not start at full health")

	# Freeze the director so the test stays deterministic.
	if Game.spawner != null:
		Game.spawner.set_process(false)
	for entry in get_tree().get_nodes_in_group("enemies"):
		entry.queue_free()
	await get_tree().physics_frame

	# --- direct damage -------------------------------------------------
	if player != null:
		var before: int = player.health
		player.take_damage(25.0)
		if player.health >= before:
			_fail("take_damage did not reduce health")

	# --- bullet -> enemy collision -------------------------------------
	var enemy_scene: PackedScene = load("res://modules/enemies/enemy.tscn")
	var enemy := enemy_scene.instantiate() as Enemy
	enemy.configure(Enemy.Kind.CHASER, 1)
	enemy.position = Vector2(1000.0, 500.0)
	Game.enemies_root.add_child(enemy)
	await get_tree().physics_frame

	var bullet_scene: PackedScene = load("res://modules/projectiles/bullet.tscn")
	var bullet := bullet_scene.instantiate()
	bullet.setup(Vector2.RIGHT, 200.0, 900.0, true, Color.WHITE)
	bullet.position = Vector2(900.0, 500.0)
	Game.bullets_root.add_child(bullet)
	for i in 25:
		await get_tree().physics_frame
	if is_instance_valid(enemy) and not enemy.is_queued_for_deletion() and enemy.health > 0.0:
		_fail("player bullet did not damage the enemy")

	# --- right stick release keeps the last heading ----------------------
	if player != null:
		player.aim = Vector2.LEFT
		player.aim = player.resolve_aim(Vector2.RIGHT, Vector2(-10.0, -10.0))
		if player.aim.distance_to(Vector2.RIGHT) > 0.01:
			_fail("right stick did not set aim to the right")
		player.aim = player.resolve_aim(Vector2.ZERO, Vector2(-10.0, -10.0))
		if player.aim.distance_to(Vector2.RIGHT) > 0.01:
			_fail("aim snapped away after the right stick was released")
		player._aim_from_stick = false
		var mouse_aim := player.resolve_aim(Vector2.ZERO, Vector2(0.0, -10.0))
		if mouse_aim.distance_to(Vector2.UP) > 0.01:
			_fail("mouse did not take over aim after a real move")
		player.aim = Vector2.RIGHT

	# --- special pulse clears nearby enemies -----------------------------
	if player != null:
		var nova_scene: PackedScene = load("res://modules/enemies/enemy.tscn")
		var nova_target := nova_scene.instantiate() as Enemy
		nova_target.configure(Enemy.Kind.CHASER, 1)
		nova_target.position = player.global_position + Vector2(90.0, 0.0)
		Game.enemies_root.add_child(nova_target)
		await get_tree().physics_frame
		player.fire_special()
		await get_tree().physics_frame
		if is_instance_valid(nova_target) and not nova_target.is_queued_for_deletion() and not nova_target.dead:
			_fail("special pulse did not damage the enemy inside its radius")
		if player.is_special_ready():
			_fail("special pulse did not start its cooldown")

	# --- pickup ---------------------------------------------------------
	if player != null:
		player.health = 40
		Game.set_health(player.health, player.max_health)
		var pickup_scene: PackedScene = load("res://modules/pickups/pickup.tscn")
		var pickup := pickup_scene.instantiate() as Pickup
		pickup.setup(Pickup.Kind.HEALTH)
		pickup.position = player.global_position + Vector2(40.0, 0.0)
		Game.pickups_root.add_child(pickup)
		for i in 40:
			await get_tree().physics_frame
		if player.health <= 40:
			_fail("health pickup did not heal the player")

	# --- end of run -----------------------------------------------------
	Game.add_score(123)
	if Game.running:
		Game.end_run()
	if Game.running:
		_fail("end_run left running = true")
	if Game.score <= 0:
		_fail("score was not accumulated")

	# --- input must survive the pause ------------------------------------
	await get_tree().process_frame
	if not level.can_process():
		_fail("level cannot process input while paused: R / Esc would be dead")

	_report()


func _fail(message: String) -> void:
	_failures.append(message)
	print("FAIL: ", message)


func _report() -> void:
	if _failures.is_empty():
		print("SMOKE TEST: PASS")
		get_tree().quit(0)
	else:
		print("SMOKE TEST: FAIL (", _failures.size(), " checks)")
		get_tree().quit(1)
