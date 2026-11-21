extends Camera2D
## Loose follow plus decaying trauma-based screen shake.

@export var follow_speed := 9.0
@export var shake_scale := 16.0

var _trauma := 0.0


func _ready() -> void:
	Game.camera = self
	position_smoothing_enabled = false
	# Keep the view inside the arena so the stage never shows empty space.
	limit_left = 0
	limit_top = 0
	limit_right = int(Game.ARENA_SIZE.x)
	limit_bottom = int(Game.ARENA_SIZE.y)


func _process(delta: float) -> void:
	var player := Game.player
	if is_instance_valid(player):
		global_position = global_position.lerp(player.global_position, clampf(delta * follow_speed, 0.0, 1.0))
	# Godot's limit_* only kicks in on certain updates, so clamp by hand:
	# the view edge must never leave the stage.
	var half_view := get_viewport_rect().size * 0.5 / zoom
	global_position = global_position.clamp(half_view, Game.ARENA_SIZE - half_view)
	if Game.shake > 0.0:
		_trauma = maxf(_trauma, Game.shake)
		Game.shake = maxf(0.0, Game.shake - delta * 2.4)
	var amplitude := _trauma * _trauma * shake_scale
	if amplitude > 0.05:
		offset = Vector2(randf_range(-amplitude, amplitude), randf_range(-amplitude, amplitude))
		_trauma = maxf(0.0, _trauma - delta * 3.0)
	else:
		offset = offset.lerp(Vector2.ZERO, minf(1.0, delta * 14.0))
