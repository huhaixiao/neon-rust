extends Node
## Verifies the buff system end to end: draft logic, stacking caps, the numbers
## the player actually uses, and the wave-clear draft overlay.
##
##   /Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
##       res://tests/buffs_test.tscn

var _failures: Array[String] = []


func _ready() -> void:
	L10n.set_locale("en", false)
	_run()


func _run() -> void:
	await get_tree().process_frame
	var stage: Node = (load("res://modules/stage/stage.tscn") as PackedScene).instantiate()
	add_child(stage)
	await get_tree().physics_frame
	await get_tree().physics_frame
	if not is_instance_valid(Game.player):
		_fail("stage did not wire a player")
		_report()
		return
	# Keep the arena deterministic: no spawner, no pre-existing enemies.
	Game.spawner.set_process(false)
	for entry in get_tree().get_nodes_in_group("enemies"):
		entry.queue_free()
	await get_tree().physics_frame

	# --- draft rolls three distinct cards, mixed categories ----------------
	var offer := Game.roll_buffs(3)
	if offer.size() != 3:
		_fail("roll_buffs(3) returned %d cards" % offer.size())
	var ids := {}
	for def in offer:
		ids[def.id] = true
	if ids.size() != offer.size():
		_fail("offer contained duplicate buff ids")
	var tags := {}
	for def in offer:
		tags[def.tag] = true
	if tags.size() < 2:
		_fail("offer was not category-mixed")

	# --- stacking: aggregates and caps -------------------------------------
	var overclock := BuffPool.find("overclock")
	var split := BuffPool.find("split")
	if overclock == null or split == null:
		_fail("BuffPool is missing a definition")
		_report()
		return
	Game.add_buff(overclock)
	Game.add_buff(overclock)
	if not is_equal_approx(Game.buff_damage_mult, 1.5):
		_fail("two OVERCLOCK stacks gave damage x%.2f, expected 1.50" % Game.buff_damage_mult)
	Game.add_buff(overclock)
	if Game.buff_stacks("overclock") != 3:
		_fail("OVERCLOCK did not stop at max stacks")
	var refused := not Game.add_buff(overclock)
	if not refused:
		_fail("OVERCLOCK kept stacking past its cap")
	Game.add_buff(split)
	if Game.buff_extra_shots != 1:
		_fail("SPLIT SHOT did not add an extra round")

	# --- the player actually uses those numbers ---------------------------
	var player := Game.player as PlayerUnit
	var bullets_before := Game.bullets_root.get_child_count()
	player._shoot()
	await get_tree().physics_frame
	var spawned := Game.bullets_root.get_child_count() - bullets_before
	if spawned != 1 + Game.buff_extra_shots:
		_fail("shot fired %d rounds, expected %d" % [spawned, 1 + Game.buff_extra_shots])
	var round_damage: float = player.bullet_damage * Game.buff_damage_mult * 0.72
	var last_bullet := Game.bullets_root.get_child(Game.bullets_root.get_child_count() - 1) as Projectile
	if last_bullet != null and not is_equal_approx(last_bullet.damage, round_damage):
		_fail("bullet damage %.1f did not include the OVERCLOCK multiplier" % last_bullet.damage)
	for child in Game.bullets_root.get_children():
		child.queue_free()

	# --- hull buff raises the cap and heals ------------------------------
	var higher := BuffPool.find("hull")
	var hull_before: int = player.max_health
	var health_before: int = player.health
	Game.add_buff(higher)
	if player.max_health != hull_before + 25:
		_fail("HULL PLATING did not raise max hull")
	if player.health < health_before:
		_fail("HULL PLATING did not heal on pickup")

	# --- repair drone heals per kill --------------------------------------
	Game.add_buff(BuffPool.find("repair"))
	player.health = 50
	Game.set_health(player.health, player.max_health)
	Game.enemy_killed.emit(Enemy.Kind.CHASER, player.global_position)
	if player.health != 53:
		_fail("REPAIR DRONE healed to %d, expected 53" % player.health)

	# --- magnet coil drags pickups in -------------------------------------
	Game.add_buff(BuffPool.find("magnet"))
	var pickup := (load("res://modules/pickups/pickup.tscn") as PackedScene).instantiate() as Pickup
	pickup.setup(Pickup.Kind.HEALTH)
	pickup.position = player.global_position + Vector2(400.0, 0.0)
	Game.pickups_root.add_child(pickup)
	var start_gap: float = pickup.global_position.distance_to(player.global_position)
	for i in 6:
		await get_tree().physics_frame
	if not is_instance_valid(pickup):
		pass
	elif pickup.global_position.distance_to(player.global_position) >= start_gap:
		_fail("MAGNET COIL did not pull the pickup")

	# --- wave clear opens the draft ---------------------------------------
	Game.wave_cleared.emit(1, 45)
	await get_tree().process_frame
	await get_tree().process_frame
	var draft := stage.get_node("BuffSelect") as BuffSelect
	if not draft.visible:
		_fail("wave clear did not open the draft")
	if not get_tree().paused:
		_fail("draft did not pause the tree")
	var stacks_before := _total_stacks()
	# Esc must not resume play while a card is pending.
	await _send_action("pause")
	if not get_tree().paused or not draft.visible:
		_fail("pause escaped the draft instead of being ignored")
	var card := draft.cards_box.get_child(0) as Button
	if card == null:
		_fail("draft has no card to press")
		_report()
		return
	card.pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	if draft.visible:
		_fail("draft stayed open after a pick")
	if get_tree().paused:
		_fail("draft left the tree paused after a pick")
	if _total_stacks() != stacks_before + 1:
		_fail("pick did not register a buff")

	# --- a fresh run clears everything ------------------------------------
	Game.reset_run()
	if not Game.buff_order.is_empty() or Game.buffs.size() > 0:
		_fail("reset_run kept buffs from the previous run")
	if not is_equal_approx(Game.buff_damage_mult, 1.0):
		_fail("reset_run kept damage multipliers")
	if Game.buff_extra_shots != 0 or Game.buff_pierce != 0:
		_fail("reset_run kept weapon modifiers")

	_report()


func _total_stacks() -> int:
	var total := 0
	for id in Game.buff_order:
		total += Game.buff_stacks(id)
	return total


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


func _fail(message: String) -> void:
	_failures.append(message)
	print("FAIL: ", message)


func _report() -> void:
	get_tree().paused = false
	if _failures.is_empty():
		print("BUFF TEST: PASS")
		get_tree().quit(0)
	else:
		print("BUFF TEST: FAIL (", _failures.size(), " checks)")
		get_tree().quit(1)
