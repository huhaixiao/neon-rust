extends Node
## 平衡探针：跑真实的关卡（双兵线 + 一塔），每 5 秒打一行战况。
##   Godot --headless --fixed-fps 60 --path . --quit-after 6000 res://tests/lane_balance.tscn

func _ready() -> void:
	get_tree().paused = false
	var level: Node = (load("res://modules/stage/stage.tscn") as PackedScene).instantiate()
	add_child(level)
	await get_tree().process_frame
	await get_tree().process_frame
	var spawner := Game.spawner as WaveDirector
	var player := Game.player as PlayerUnit
	print("start wave=", spawner.wave, " hero=", player.health, " tower=", (Game.tower as LaneTower).health, " tree=", Game.tree_health)
	for step in 96:
		await get_tree().create_timer(5.0).timeout
		get_tree().paused = false
		var dire := 0
		var radiant := 0
		for node in get_tree().get_nodes_in_group("enemies"):
			var c := node as Enemy
			if c == null or c.dead:
				continue
			if c.team == Enemy.Team.DIRE:
				dire += 1
			else:
				radiant += 1
		print("t=%3ds wave=%d dire=%d radiant=%d hero=%d/%d tower=%.0f tree=%d gold=%d lvl=%d xp=%d" % [
			(step + 1) * 5, spawner.wave, dire, radiant, player.health, player.max_health,
			(Game.tower as LaneTower).health, Game.tree_health,
			player.progress.gold if player.progress != null else -1,
			player.progress.level if player.progress != null else -1,
			player.progress.xp if player.progress != null else -1,
		])
		if not Game.running:
			print("RUN OVER at t=", (step + 1) * 5, "s")
			break
	print("BALANCE PROBE DONE")
	get_tree().quit(0)
