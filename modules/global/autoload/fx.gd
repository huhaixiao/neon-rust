extends Node
## Juice helpers: particle bursts, additive flashes, dash ghosts and a small
## pooled SFX player. Everything spawns into Game.fx_root so the scene owns the
## lifetime. Autoloaded as `Fx`.

const PARTICLE_TEX := preload("res://modules/global/assets/sprites/fx/particle.png")
const FLASH_TEX := preload("res://modules/global/assets/sprites/fx/flash.png")

const SFX_SHOOT := preload("res://modules/global/assets/audio/sfx/shoot.wav")
const SFX_HIT := preload("res://modules/global/assets/audio/sfx/hit.wav")
const SFX_DIE := preload("res://modules/global/assets/audio/sfx/die.wav")
const SFX_HURT := preload("res://modules/global/assets/audio/sfx/player_hit.wav")
const SFX_DASH := preload("res://modules/global/assets/audio/sfx/dash.wav")
const SFX_PICKUP := preload("res://modules/global/assets/audio/sfx/pickup.wav")
const SFX_WAVE := preload("res://modules/global/assets/audio/sfx/wave.wav")
const SFX_GAMEOVER := preload("res://modules/global/assets/audio/sfx/gameover.wav")

const MAX_LIVE_PARTICLES := 140
const MAX_PLAYERS := 12

var _live_particles := 0
var _players: Array[AudioStreamPlayer] = []
var _player_cursor := 0


## One-shot radial burst. Colours are additive-looking neon because the sprite
## set already carries its own halo.
func burst(pos: Vector2, color: Color, amount := 16, speed := 320.0, size_mul := 1.0) -> void:
	var parent := _fx_root()
	if parent == null or _live_particles >= MAX_LIVE_PARTICLES:
		return
	var particles := CPUParticles2D.new()
	particles.texture = PARTICLE_TEX
	particles.amount = clampi(amount, 2, 48)
	particles.lifetime = 0.55
	particles.one_shot = true
	particles.explosiveness = 0.9
	particles.spread = 180.0
	particles.gravity = Vector2.ZERO
	particles.initial_velocity_min = speed * 0.3
	particles.initial_velocity_max = speed
	particles.scale_amount_min = 0.22 * size_mul
	particles.scale_amount_max = 0.9 * size_mul
	particles.color = color
	particles.z_index = 6
	particles.position = pos
	parent.add_child(particles)
	particles.emitting = true
	_live_particles += 1
	_after(particles.lifetime + 0.3, func() -> void:
		_live_particles = maxi(0, _live_particles - 1)
		if is_instance_valid(particles):
			particles.queue_free()
	)


## Quick additive starburst that scales up and fades out.
func flash(pos: Vector2, color: Color, size_mul := 1.0) -> void:
	var parent := _fx_root()
	if parent == null:
		return
	var sprite := Sprite2D.new()
	sprite.texture = FLASH_TEX
	sprite.position = pos
	sprite.modulate = color
	sprite.scale = Vector2(0.45, 0.45) * size_mul
	sprite.z_index = 7
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	sprite.material = mat
	parent.add_child(sprite)
	var tween := sprite.create_tween()
	tween.set_parallel(true)
	tween.tween_property(sprite, "scale", Vector2(1.2, 1.2) * size_mul, 0.18)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.18)
	tween.finished.connect(sprite.queue_free)


## Fading copy of the player ship, used for the dash trail.
func ghost(source: Node2D) -> void:
	var parent := _fx_root()
	if parent == null:
		return
	var body := source.get_node_or_null("Body") as Sprite2D
	if body == null:
		return
	var copy := Sprite2D.new()
	copy.texture = body.texture
	copy.scale = body.scale
	copy.modulate = Color(0.35, 1.0, 1.0, 0.65)
	copy.z_index = 3
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	copy.material = mat
	parent.add_child(copy)
	copy.global_position = body.global_position
	copy.global_rotation = body.global_rotation
	var tween := copy.create_tween()
	tween.set_parallel(true)
	tween.tween_property(copy, "modulate:a", 0.0, 0.3)
	tween.tween_property(copy, "scale", body.scale * 0.55, 0.3)
	tween.finished.connect(copy.queue_free)


## Round-robin SFX pool so overlapping shots do not cut each other off.
func sfx(stream: AudioStream, volume_db := 0.0, pitch := 1.0) -> void:
	var parent := _fx_root()
	if parent == null or stream == null:
		return
	_drop_dead_players()
	var chosen: AudioStreamPlayer = null
	var size := _players.size()
	for i in size:
		var index := (_player_cursor + i) % size
		var candidate := _players[index]
		if not candidate.playing:
			chosen = candidate
			_player_cursor = (index + 1) % size
			break
	if chosen == null and _players.size() < MAX_PLAYERS:
		chosen = AudioStreamPlayer.new()
		parent.add_child(chosen)
		_players.append(chosen)
		_player_cursor = _players.size() % MAX_PLAYERS
	if chosen == null:
		if _players.is_empty():
			return
		chosen = _players[_player_cursor]
		_player_cursor = (_player_cursor + 1) % _players.size()
		if not is_instance_valid(chosen):
			return
	chosen.stream = stream
	chosen.volume_db = volume_db
	chosen.pitch_scale = pitch
	chosen.play()


func _drop_dead_players() -> void:
	for index in range(_players.size() - 1, -1, -1):
		if not is_instance_valid(_players[index]):
			_players.remove_at(index)
	if _player_cursor >= _players.size():
		_player_cursor = 0


func _fx_root() -> Node:
	if is_instance_valid(Game.fx_root):
		return Game.fx_root
	if is_instance_valid(get_tree().current_scene):
		return get_tree().current_scene
	return null


func _after(seconds: float, callback: Callable) -> void:
	var timer := get_tree().create_timer(seconds)
	timer.timeout.connect(callback)
