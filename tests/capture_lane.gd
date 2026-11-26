extends Node
## Visual check for the middle-lane build: boots the stage, lets wave 01
## march in, and grabs three frames (lane entry / mid-lane fight / late wave).
##
##   xvfb-run -a Godot --path . res://tests/capture_lane.tscn
##   shots land in /tmp/neon_rust_lane/

const SHOT_DIR := "/tmp/neon_rust_lane"


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(SHOT_DIR)
	L10n.set_locale("en", false)
	await _run()


func _run() -> void:
	await get_tree().process_frame
	var stage: PackedScene = load("res://modules/stage/stage.tscn")
	var level := stage.instantiate()
	add_child(level)
	# Let wave 01 start immediately instead of waiting out the intro.
	await get_tree().create_timer(2.2).timeout
	await _shot("lane_01_entry")

	await get_tree().create_timer(3.0).timeout
	await _shot("lane_02_fight")

	await get_tree().create_timer(4.0).timeout
	await _shot("lane_03_late")

	L10n.set_locale("zh", false)
	await get_tree().create_timer(0.6).timeout
	await _shot("lane_04_zh")
	get_tree().quit(0)


func _shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := "%s/%s.png" % [SHOT_DIR, label]
	var err := image.save_png(path)
	print("capture ", path, " ", image.get_size(), " err=", err)
	print("  tree=", Game.tree_health, "/", Game.max_tree_health,
		"  wave=", Game.wave,
		"  enemies=", Game.enemies_root.get_child_count() if is_instance_valid(Game.enemies_root) else -1)
	var player := Game.player as PlayerUnit
	if player != null:
		var t: Enemy = player.target
		print("  player=", player.global_position, " aim=", player.aim,
			" target=", "none" if t == null else str(t.global_position),
			" hull=", player.health, "/", player.max_health)
