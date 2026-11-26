extends Node
## Progression test: kills pay gold + XP, gold auto-buys the cheapest item,
## XP auto-levels a passive, the hero shoots an arrow, a manual shot roots the
## hero, and the force staff shoves him a fixed distance.
##
##   Godot --headless --path . res://tests/progress_test.tscn

var _failures: Array[String] = []


func _ready() -> void:
	L10n.set_locale("en", false)
	await _run()


func _run() -> void:
	await get_tree().process_frame
	var level_scene: PackedScene = load("res://modules/stage/stage.tscn")
	var level: Node = level_scene.instantiate()
	add_child(level)
	await get_tree().process_frame
	await get_tree().process_frame

	var player := Game.player as PlayerUnit
	if player == null:
		_fail("player was not wired")
		_report()
		return
	var prog := player.progress
	if prog == null:
		_fail("hero has no HeroProgress")
		_report()
		return

	# --- starting state ---------------------------------------------------
	if prog.level != 1:
		_fail("hero should start at level 1, got %d" % prog.level)
	# Starting gold is spent before the first wave: 603 - 450 = 153 left and
	# Slippers already on.
	if not prog.items.has("slippers"):
		_fail("starting gold should have auto-bought Slippers, items = " + str(prog.items))
	if prog.gold != HeroProgress.START_GOLD - 450:
		_fail("starting gold should leave %d after Slippers, got %d" % [HeroProgress.START_GOLD - 450, prog.gold])

	var base_max := player.max_health
	var base_interval := player.fire_interval

	# --- one melee kill: 43 gold, 62 XP --------------------------------
	var gold_before_kill := prog.gold
	Game.register_kill(43, 62)
	if prog.gold != gold_before_kill + 43:
		_fail("a melee kill should pay 43 gold, gold = %d" % prog.gold)
	if prog.xp != 62:
		_fail("a melee kill should pay 62 XP, xp = %d" % prog.xp)
	if prog.level != 1:
		_fail("62 XP should not level the hero yet, level = %d" % prog.level)

	# --- enough XP for level 2 (200) -> 4 kills total -------------------
	Game.register_kill(0, 140)
	if prog.level != 2:
		_fail("202 XP should reach level 2, level = %d" % prog.level)
	if prog.skill_level("frost_arrows") < 1:
		_fail("the first level-up should put a point into the first passive")

	# --- items ------------------------------------------------------------
	if player._damage_min <= 44.0:
		_fail("Slippers should raise the damage floor above 44, got %.1f" % player._damage_min)

	# The shop buys cheapest-first: 500 gold goes to the Ring of Regeneration
	# (350g) before Boots, and the ring is what keeps the hero alive between waves.
	var gold_before := prog.gold
	Game.register_kill(500, 0)
	if not prog.items.has("ring_of_regen"):
		_fail("500 more gold should have bought the Ring of Regeneration, items = " + str(prog.items))
	if player.hp_regen <= float(player._base.regen) + 0.1:
		_fail("the ring should lift regen above the sheet's %.2f, got %.2f" % [float(player._base.regen), player.hp_regen])
	# Another 500 clears Boots.
	Game.register_kill(500, 0)
	if not prog.items.has("boots"):
		_fail("Boots should be the next purchase, items = " + str(prog.items))
	if player.move_speed <= 300.0:
		_fail("Boots should raise move speed above 300, got %.0f" % player.move_speed)
	if prog.gold >= gold_before + 1000:
		_fail("buying items must spend the gold")

	# --- arrow projectile -------------------------------------------------
	var enemy_scene: PackedScene = load("res://modules/enemies/enemy.tscn")
	var target := enemy_scene.instantiate() as Enemy
	target.configure(Enemy.Kind.CHASER, 1)
	target.lane_active = false
	target.position = player.global_position + Vector2(220.0, 0.0)
	Game.enemies_root.add_child(target)
	await get_tree().physics_frame

	var hp_before := target.health
	for i in 8:
		await get_tree().create_timer(0.5).timeout
		if target.health < hp_before:
			break
	if target.health >= hp_before:
		_fail("the auto-attack arrow never damaged the creep in front")
	var arrow_pool := 0
	for node in Game.bullets_root.get_children():
		if node is Arrow:
			arrow_pool += 1
	if arrow_pool == 0 and target.health < hp_before:
		pass

	# --- manual shot roots the hero ---------------------------------------
	# Input plumbing is asserted through the map, the root itself through the
	# unit: pressing a key in a headless run is not the thing under test.
	if not InputMap.has_action("fire") or not InputMap.has_action("force_staff"):
		_fail("fire / force_staff actions are missing from the input map")
	var fire_keys := false
	for event in InputMap.action_get_events("fire"):
		if event is InputEventKey and (event as InputEventKey).physical_keycode == KEY_X:
			fire_keys = true
	if not fire_keys:
		_fail("X should be bound to fire")

	player.auto_aim = false
	player._root_left = 0.0
	player._shoot(true)
	if player._root_left <= 0.0:
		_fail("a manual shot should set the root timer, root = %.2f" % player._root_left)

	var at := player.global_position
	Input.action_press("move_down")
	player._move(0.1)
	if player.global_position.distance_to(at) > 0.5:
		_fail("a rooted hero must not move while the bow is drawn")
	player._root_left = 0.0
	player._move(0.1)
	Input.action_release("move_down")
	if player.global_position.distance_to(at) <= 0.5:
		_fail("an un-rooted hero should still move with input")

	# --- force staff -------------------------------------------------------
	await get_tree().create_timer(PlayerUnit.ROOT_TIME + 0.05).timeout
	var before := player.global_position
	var dir := Vector2(0.0, -1.0)
	player.push_self(dir)
	var after := player.global_position
	if after.distance_to(before) < player.force_push * 0.55:
		_fail("force staff should shove ~%.0f px, moved %.0f" % [player.force_push, after.distance_to(before)])
	if player.is_force_ready():
		_fail("force staff should go on cooldown after a push")
	if not is_equal_approx(player.force_ratio(), 0.0):
		_fail("force staff ratio should start at 0 after a push")

	# --- stats recompute is not compounding --------------------------------
	var dmg_after := player._damage_max
	player.refresh_stats()
	player.refresh_stats()
	if not is_equal_approx(player._damage_max, dmg_after):
		_fail("refresh_stats must be idempotent, %.2f -> %.2f" % [dmg_after, player._damage_max])
	if player.max_health < base_max:
		_fail("item health must never lower max HP, %d < %d" % [player.max_health, base_max])
	if player.fire_interval > base_interval + 0.01:
		_fail("items must not slow the attack interval")

	_report()


func _fail(message: String) -> void:
	_failures.append(message)


func _report() -> void:
	if _failures.is_empty():
		print("PROGRESS TEST: PASS")
	else:
		for message in _failures:
			print("PROGRESS TEST: FAIL  ", message)
	get_tree().quit(0 if _failures.is_empty() else 1)
