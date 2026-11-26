extends Node
## 临时探针：不做断言，只把「DotA1 数值 + 单中小黑」的真实战斗节奏打出来。
##   Godot --headless --path . res://tests/lane_probe.tscn

const ENEMY_SCENE := preload("res://modules/enemies/enemy.tscn")


func _ready() -> void:
	$"/root".get_tree().paused = false
	var level: Node = (load("res://modules/stage/stage.tscn") as PackedScene).instantiate()
	add_child(level)
	await get_tree().process_frame
	await get_tree().process_frame
	var spawner := Game.spawner as WaveDirector
	spawner.set_process(false)
	var player := Game.player as PlayerUnit
	player.set_process(false)   # 先关掉，稍后手动开
	await get_tree().physics_frame
	player.set_process(true)
	for entry in get_tree().get_nodes_in_group("enemies"):
		entry.queue_free()
	await get_tree().physics_frame

	# 一波 DotA1 兵：3 近战 + 1 远程，从 y=110 走进来
	var kinds := [Enemy.Kind.CHASER, Enemy.Kind.CHASER, Enemy.Kind.CHASER, Enemy.Kind.SPITTER]
	for i in kinds.size():
		var creep := ENEMY_SCENE.instantiate() as Enemy
		creep.configure(kinds[i], 1)
		creep.lane_active = true
		creep.lane_end = Vector2(800.0, 858.0)
		creep.engage_range = 250.0
		creep.position = Vector2(800.0 + (i - 1.5) * 34.0, 110.0)
		Game.enemies_root.add_child(creep)
	await get_tree().physics_frame

	print("t=0  hero=", player.health, "/", player.max_health, " tree=", Game.tree_health)
	for step in 18:
		await get_tree().create_timer(5.0).timeout
		var hp := []
		for node in get_tree().get_nodes_in_group("enemies"):
			hp.append(int((node as Enemy).health))
		var dist := -1.0
		if player.target != null and is_instance_valid(player.target):
			dist = player.global_position.distance_to(player.target.global_position)
		print("t=%2d  hp=%s hero=%d shots=%d dist=%.0f aim=%s rot=%.0f" % [
			(step + 1) * 5, str(hp), player.health, player.shots_fired, dist,
			str(player.aim.round()), rad_to_deg(player.rotation)
		])
		if not Game.running or hp.size() == 0 or player.dead:
			break
	print("PROBE DONE")
	get_tree().quit(0)
