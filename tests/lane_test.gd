extends Node
## Lane-mode test: the middle lane, the auto-attacking hero, frost slow, and
## tree leaks. Runs headless, no input events.
##
##   Godot --headless --path . res://tests/lane_test.tscn

var _failures: Array[String] = []


func _ready() -> void:
	L10n.set_locale("en", false)
	await _run()


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

	var player := Game.player as PlayerUnit
	if player == null:
		_fail("player was not wired")
		_report()
		return

	# --- hero sheet -------------------------------------------------------
	if player.hero_id != HeroCatalog.DROW:
		_fail("player is not playing 小黑, hero_id = " + player.hero_id)
	if not is_equal_approx(player.attack_range, 470.0):
		_fail("hero attack_range did not come from the hero sheet: %.1f" % player.attack_range)
	if not player.auto_aim:
		_fail("lane hero should aim itself")

	# --- single middle lane ----------------------------------------------
	var spawner := Game.spawner as WaveDirector
	if spawner == null:
		_fail("spawner was not wired")
	else:
		spawner.set_process(false)
		if spawner.lane_end.distance_to(Vector2(800.0, 858.0)) > 0.01:
			_fail("lane should end at the tree, got %s" % str(spawner.lane_end))
		for i in 12:
			var point: Vector2 = spawner._spawn_point()
			if absf(point.x - 800.0) > 40.0:
				_fail("creep spawned off the middle lane at x=%.1f" % point.x)
			if point.y > 140.0:
				_fail("creep should enter from the top of the lane, y=%.1f" % point.y)
	for entry in get_tree().get_nodes_in_group("enemies"):
		entry.queue_free()
	await get_tree().physics_frame

	# --- the tree exists and takes leaks ---------------------------------
	var tree := Game.tree
	if not is_instance_valid(tree):
		_fail("WorldTree was not registered with Game")
	var tree_before := Game.tree_health

	# --- auto attack: no fire input, creep in range dies anyway -----------
	var enemy_scene: PackedScene = load("res://modules/enemies/enemy.tscn")
	var near := enemy_scene.instantiate() as Enemy
	near.configure(Enemy.Kind.CHASER, 1)
	near.lane_active = true
	near.lane_end = Vector2(800.0, 858.0)
	near.engage_range = 2000.0
	near.position = player.global_position + Vector2(210.0, 0.0)
	Game.enemies_root.add_child(near)
	await get_tree().physics_frame
	if player.target != near:
		_fail("auto aim did not pick the creep in range")
	for i in 100:
		await get_tree().physics_frame
	if is_instance_valid(near) and not near.is_queued_for_deletion() and near.health > 0.0:
		_fail("auto attack did not kill a creep inside range (hp %.0f)" % near.health)

	# --- out of range: hero holds fire -----------------------------------
	for entry in get_tree().get_nodes_in_group("enemies"):
		entry.queue_free()
	await get_tree().physics_frame
	var bullets_before := Game.bullets_root.get_child_count()
	var far := enemy_scene.instantiate() as Enemy
	far.configure(Enemy.Kind.CHASER, 1)
	far.lane_active = true
	far.engage_range = 10.0
	far.speed = 0.0
	far.position = player.global_position + Vector2(640.0, 0.0)
	far.lane_end = far.position + Vector2(0.0, -400.0)
	Game.enemies_root.add_child(far)
	await get_tree().physics_frame
	for i in 30:
		await get_tree().physics_frame
	if Game.bullets_root.get_child_count() > bullets_before:
		_fail("hero fired at a creep %.0f px away, past its range" % 640.0)
	if is_instance_valid(far) and far.slow_mult < 1.0:
		_fail("far creep should not have been slowed")

	# --- frost arrows slow what they hit ---------------------------------
	var chilled := enemy_scene.instantiate() as Enemy
	chilled.configure(Enemy.Kind.CHASER, 1)
	chilled.lane_active = true
	chilled.engage_range = 10.0
	# Parked outside the hero's range: this check is about the slow timer, not
	# about the hero shooting it.
	chilled.speed = 0.0
	chilled.position = player.global_position + Vector2(900.0, 0.0)
	chilled.lane_end = chilled.position + Vector2(0.0, -400.0)
	Game.enemies_root.add_child(chilled)
	await get_tree().physics_frame
	chilled.apply_slow(0.4, 1.4)
	if chilled.slow_mult > 0.7:
		_fail("frost slow did not reduce creep speed: %.2f" % chilled.slow_mult)
	for i in 100:
		await get_tree().physics_frame
	if chilled.slow_mult < 1.0:
		_fail("slow did not wear off after its duration")

	# --- a creep that reaches the tree chips it ---------------------------
	var leaker := enemy_scene.instantiate() as Enemy
	leaker.configure(Enemy.Kind.CHASER, 1)
	leaker.lane_active = true
	leaker.lane_end = Vector2(800.0, 858.0)
	leaker.engage_range = 10.0
	leaker.position = Vector2(800.0, 800.0)
	leaker.speed = 400.0
	Game.enemies_root.add_child(leaker)
	for i in 40:
		await get_tree().physics_frame
	if Game.tree_health >= tree_before:
		_fail("creep walking into the tree did not damage it")

	# --- tree at zero ends the run ---------------------------------------
	Game.tree_health = 5
	Game.damage_tree(50)
	if Game.tree_health != 0:
		_fail("tree health did not clamp at zero")
	if Game.running:
		_fail("tree reaching zero did not end the run")

	_report()


func _fail(message: String) -> void:
	_failures.append(message)
	print("FAIL: ", message)


func _report() -> void:
	if _failures.is_empty():
		print("LANE TEST: PASS")
		get_tree().quit(0)
	else:
		print("LANE TEST: FAIL (", _failures.size(), " checks)")
		get_tree().quit(1)
