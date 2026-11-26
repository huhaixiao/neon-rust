extends Node
## Lane-mode test: DotA1 creep sheet, the single middle lane, the auto-attacking
## hero, frost slow, and creeps sieging the tree. Runs headless, no input.
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

	# --- hero sheet is the DotA1 sheet ------------------------------------
	if player.hero_id != HeroCatalog.DROW:
		_fail("player is not playing 小黑, hero_id = " + player.hero_id)
	if not is_equal_approx(player.attack_range, 625.0):
		_fail("hero attack_range did not come from the sheet: %.1f" % player.attack_range)
	if not is_equal_approx(player.max_health, 473.0):
		_fail("小黑 should have 473 HP, got %d" % player.max_health)
	# The effective interval is already boosted by the Slippers the starting gold
	# auto-bought, so the sheet check reads the base sheet.
	if not is_equal_approx(float(player._base.fire_interval), 1.7):
		_fail("小黑 BAT should be 1.7s, got %.2f" % float(player._base.fire_interval))
	if not is_equal_approx(player.move_speed, 300.0):
		_fail("小黑 move speed should be 300, got %.0f" % player.move_speed)
	if not is_equal_approx(float(player._base.damage_min), 44.0) or not is_equal_approx(float(player._base.damage_max), 55.0):
		_fail("小黑 damage window should be 44-55")
	if player._damage_min <= 44.0:
		_fail("starting items should already lift the damage window above 44")
	if not player.auto_aim:
		_fail("lane hero should aim itself")

	# --- DotA1 creep sheet ------------------------------------------------
	var enemy_scene: PackedScene = load("res://modules/enemies/enemy.tscn")
	var melee := enemy_scene.instantiate() as Enemy
	melee.configure(Enemy.Kind.CHASER, 1)
	if not is_equal_approx(melee.health_max, 550.0):
		_fail("melee creep HP should be 550, got %.0f" % melee.health_max)
	if not is_equal_approx(melee.armor, 2.0):
		_fail("melee creep armour should be 2, got %.1f" % melee.armor)
	if not is_equal_approx(melee.contact_damage, 21.0):
		_fail("melee creep damage should average 21, got %.1f" % melee.contact_damage)
	if not is_equal_approx(melee.speed, 325.0):
		_fail("melee creep move speed should be 325, got %.0f" % melee.speed)
	melee.free()

	var ranged := enemy_scene.instantiate() as Enemy
	ranged.configure(Enemy.Kind.SPITTER, 1)
	if not is_equal_approx(ranged.health_max, 300.0):
		_fail("ranged creep HP should be 300, got %.0f" % ranged.health_max)
	if not is_equal_approx(ranged.attack_range, 500.0):
		_fail("ranged creep range should be 500, got %.0f" % ranged.attack_range)
	if ranged.projectile_speed <= 0.0:
		_fail("ranged creep should shoot a bolt, not touch")
	ranged.free()

	var siege := enemy_scene.instantiate() as Enemy
	siege.configure(Enemy.Kind.BRUTE, 7)
	if not is_equal_approx(siege.attack_range, 690.0):
		_fail("siege range should be 690, got %.0f" % siege.attack_range)
	if not is_equal_approx(siege.attack_interval, 2.7):
		_fail("siege BAT should be 2.7s, got %.2f" % siege.attack_interval)
	# 6 cycles later (wave 91) a melee creep is 60 HP / 6 damage fatter.
	var late := enemy_scene.instantiate() as Enemy
	late.configure(Enemy.Kind.CHASER, 91)
	if not is_equal_approx(late.health_max, 610.0):
		_fail("melee creep upgrade cycle wrong: %.0f HP at wave 91" % late.health_max)
	late.free()

	# --- armour soaks damage the DotA1 way --------------------------------
	var tank := enemy_scene.instantiate() as Enemy
	tank.configure(Enemy.Kind.CHASER, 1)
	Game.enemies_root.add_child(tank)
	await get_tree().physics_frame
	tank.take_damage(100.0, tank.global_position)
	# 0.06*2/(1+0.06*2) = 10.7% reduction: 100 damage -> 89.3, so 550 -> 460.7.
	if tank.health < 460.0 or tank.health > 461.5:
		_fail("2 armour should turn 100 damage into 89, got %.1f HP of 550 left" % tank.health)
	tank.queue_free()
	await get_tree().physics_frame

	# --- single middle lane ----------------------------------------------
	var spawner := Game.spawner as WaveDirector
	if spawner == null:
		_fail("spawner was not wired")
	else:
		spawner.set_process(false)
		if spawner.lane_end.distance_to(LaneSpec.TREE) > 0.01:
			_fail("lane should end at the tree, got %s" % str(spawner.lane_end))
		# Creeps enter at the top-right corner and stay on the lane corridor.
		for i in 12:
			var point: Vector2 = spawner._spawn_point()
			if point.distance_to(LaneSpec.START) > 120.0:
				_fail("creep did not spawn at the Dire entry, got %s" % str(point))
			if absf(LaneSpec.lateral(point)) > 90.0:
				_fail("creep spawned off the lane corridor, lateral = %.1f" % LaneSpec.lateral(point))
		# Defend the bottom-left: the tree and hero both live there.
		if LaneSpec.TREE.x > 300.0 or LaneSpec.TREE.y < 700.0:
			_fail("the World Tree should sit in the bottom-left corner, got %s" % str(LaneSpec.TREE))
		if LaneSpec.START.x < 1200.0 or LaneSpec.START.y > 300.0:
			_fail("creeps should enter from the top-right corner, got %s" % str(LaneSpec.START))
		if player.global_position.distance_to(LaneSpec.hero_spawn()) > 6.0:
			_fail("the hero should spawn in front of the tree, got %s" % str(player.global_position))

		# --- DotA1 wave layout: 3 melee + 1 ranged, siege every 7th ------
		var plain := spawner.composition(1)
		if plain.size() != 4:
			_fail("wave 1 should be 4 creeps, got %d" % plain.size())
		var melee_count := 0
		var ranged_count := 0
		for kind in plain:
			if kind == Enemy.Kind.CHASER:
				melee_count += 1
			elif kind == Enemy.Kind.SPITTER:
				ranged_count += 1
		if melee_count != 3 or ranged_count != 1:
			_fail("wave 1 should be 3 melee + 1 ranged, got %d/%d" % [melee_count, ranged_count])
		var seventh := spawner.composition(7)
		if seventh.size() != 5:
			_fail("wave 7 should add a siege creep, got %d units" % seventh.size())
		if not seventh.has(Enemy.Kind.BRUTE):
			_fail("wave 7 did not include the siege creep")
		if spawner.composition(8).has(Enemy.Kind.BRUTE):
			_fail("wave 8 should not carry a siege creep")

	for entry in get_tree().get_nodes_in_group("enemies"):
		entry.queue_free()
	await get_tree().physics_frame

	# --- the tree exists at DotA1 ancient HP ------------------------------
	var tree := Game.tree
	if not is_instance_valid(tree):
		_fail("WorldTree was not registered with Game")
	if Game.max_tree_health != 4250:
		_fail("World Tree should have 4250 HP, got %d" % Game.max_tree_health)
	var tree_before := Game.tree_health

	# --- auto attack: no fire input, creep in range gets shot --------------
	var near := enemy_scene.instantiate() as Enemy
	near.configure(Enemy.Kind.CHASER, 1)
	near.lane_active = true
	near.lane_end = LaneSpec.TREE
	near.engage_range = 2000.0
	near.position = player.global_position + Vector2(210.0, 0.0)
	Game.enemies_root.add_child(near)
	await get_tree().physics_frame
	if player.target != near:
		_fail("auto aim did not pick the creep in range")
	# A 550 HP creep takes 12 arrows, which is correct but slow for a test;
	# this check is about the trigger, so drop it to one-shot HP.
	near.health = 40.0
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
	far.position = player.global_position + Vector2(660.0, 0.0)
	far.lane_end = far.position + Vector2(0.0, -400.0)
	Game.enemies_root.add_child(far)
	await get_tree().physics_frame
	for i in 30:
		await get_tree().physics_frame
	if Game.bullets_root.get_child_count() > bullets_before:
		_fail("hero fired at a creep %.0f px away, past its 625 range" % 660.0)
	if is_instance_valid(far) and far.slow_mult < 1.0:
		_fail("far creep should not have been slowed")

	# --- frost arrows slow what they hit ---------------------------------
	var chilled := enemy_scene.instantiate() as Enemy
	chilled.configure(Enemy.Kind.CHASER, 1)
	chilled.lane_active = true
	chilled.speed = 0.0
	chilled.position = player.global_position + Vector2(900.0, 0.0)
	chilled.lane_end = chilled.position + Vector2(0.0, -400.0)
	Game.enemies_root.add_child(chilled)
	await get_tree().physics_frame
	chilled.apply_slow(player._slow_factor, player._slow_time)
	if chilled.slow_mult > 0.7:
		_fail("frost slow did not reduce creep speed: %.2f" % chilled.slow_mult)
	for i in 100:
		await get_tree().physics_frame
	if chilled.slow_mult < 1.0:
		_fail("slow did not wear off after its duration")

	# --- a creep that reaches the tree sieges it -------------------------
	var leaker := enemy_scene.instantiate() as Enemy
	leaker.configure(Enemy.Kind.CHASER, 1)
	leaker.lane_active = true
	leaker.lane_end = LaneSpec.TREE
	# Parked close to the hero, so keep it from switching to a hero fight.
	leaker.engage_range = 10.0
	leaker.position = LaneSpec.TREE - LaneSpec.direction() * 70.0
	Game.enemies_root.add_child(leaker)
	for i in 40:
		await get_tree().physics_frame
	if Game.tree_health >= tree_before:
		_fail("creep walking into the tree did not damage it")
	if not is_instance_valid(leaker) or leaker.is_queued_for_deletion():
		_fail("a creep at the tree should keep sieging, not disappear")
	leaker.queue_free()

	# --- no intermission: a cleared wave starts the next one right away ---
	if spawner != null:
		spawner.wave = 3
		spawner._alive.clear()
		spawner._queue.clear()
		spawner._finish_wave()
		if spawner.wave != 4:
			_fail("cleared wave did not start wave 4 immediately, wave = %d" % spawner.wave)
		if spawner._queue.size() != 4:
			_fail("wave 4 should already be queued (4 creeps), got %d" % spawner._queue.size())
		# The draft that follows pauses the tree; release it again.
		get_tree().paused = false

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
