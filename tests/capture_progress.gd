extends Node
## Screenshot pass for the growth systems: boots the stage, feeds the hero
## enough kills to level up and fill its item slots, then grabs one frame.
##
##   Godot --path . res://tests/capture_progress.tscn
##   shots land in /tmp/neon_rust_lane/

const SHOT_DIR := "/tmp/neon_rust_lane"


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(SHOT_DIR)
	L10n.set_locale("zh", false)
	await _run()


func _run() -> void:
	await get_tree().process_frame
	var stage: PackedScene = load("res://modules/stage/stage.tscn")
	var level := stage.instantiate()
	add_child(level)
	await get_tree().create_timer(1.2).timeout
	var player := Game.player as PlayerUnit
	# 26 melee kills: level ~9 and a deep item build, without waiting on waves.
	for i in 26:
		Game.register_kill(43, 62)
		await get_tree().process_frame
	await get_tree().create_timer(0.5).timeout
	print("hero=", player.progress.level, " gold=", player.progress.gold,
		" items=", player.progress.items, " skills=", player.progress.skills,
		" dmg=", player._damage_min, "-", player._damage_max,
		" interval=", player.fire_interval)
	await _shot("growth_01")
	L10n.set_locale("en", false)
	await get_tree().create_timer(0.4).timeout
	await _shot("growth_02_en")
	get_tree().quit(0)


func _shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := "%s/%s.png" % [SHOT_DIR, label]
	print("capture ", path, " ", image.get_size(), " err=", image.save_png(path))
