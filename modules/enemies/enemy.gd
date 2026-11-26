class_name Enemy
extends ShipBody
## CHASER = fast/fragile, BRUTE = slow tank, SPITTER = keeps range and shoots.

signal died(kind: int, at: Vector2)

enum Kind { CHASER, BRUTE, SPITTER }

const TEX_CHASER := preload("res://modules/enemies/assets/sprites/enemy_chaser.png")
const TEX_BRUTE := preload("res://modules/enemies/assets/sprites/enemy_brute.png")
const TEX_SPITTER := preload("res://modules/enemies/assets/sprites/enemy_spitter.png")
const BULLET_SCENE := preload("res://modules/projectiles/bullet.tscn")

@export var kind: Kind = Kind.CHASER

var health := 30.0
var health_max := 30.0
var speed := 235.0
var contact_damage := 12.0
var score_value := 10
var radius := 17.0
var body_scale := 0.82
var base_color := Color(1.0, 0.25, 0.5)

## Lane duty. A creep with `lane_active` walks toward `lane_end` (the World
## Tree) and only breaks off to fight when the hero comes within `engage_range`.
var lane_active := false
var lane_end := Vector2.ZERO
var engage_range := 250.0

var slow_mult := 1.0
var slow_left := 0.0

var _hit_cd := 0.0
var _shoot_cd := 0.0
var _orbit := 1.0

@onready var sprite: Sprite2D = $Sprite
@onready var hitbox: CollisionShape2D = $Hitbox
@onready var sfx_die: AudioStreamPlayer = $SfxDie
@onready var sfx_shoot: AudioStreamPlayer = $SfxShoot


func configure(kind_value, wave_index: int) -> void:
	kind = kind_value
	var hp_ramp := 1.0 + 0.16 * float(maxi(0, wave_index - 1))
	var speed_ramp := 1.0 + 0.03 * float(maxi(0, wave_index - 1))
	match kind:
		Kind.CHASER:
			health_max = 30.0 * hp_ramp
			speed = 235.0 * speed_ramp
			contact_damage = 12.0
			score_value = 10
			radius = 17.0
			body_scale = 0.82
			base_color = Color(1.0, 0.25, 0.5)
		Kind.BRUTE:
			health_max = 130.0 * hp_ramp
			speed = 118.0 * speed_ramp
			contact_damage = 26.0
			score_value = 45
			radius = 32.0
			body_scale = 0.92
			base_color = Color(1.0, 0.55, 0.15)
		Kind.SPITTER:
			health_max = 48.0 * hp_ramp
			speed = 150.0 * speed_ramp
			contact_damage = 10.0
			score_value = 30
			radius = 19.0
			body_scale = 0.85
			base_color = Color(0.75, 1.0, 0.25)
	health = health_max
	_orbit = 1.0 if randf() < 0.5 else -1.0


func _ready() -> void:
	add_to_group("enemies")
	_apply_look()
	sprite.scale = Vector2.ONE * 0.15
	var pop := create_tween()
	pop.tween_property(sprite, "scale", Vector2(body_scale, body_scale), 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _apply_look() -> void:
	var texture: Texture2D = TEX_CHASER
	if kind == Kind.BRUTE:
		texture = TEX_BRUTE
	elif kind == Kind.SPITTER:
		texture = TEX_SPITTER
	sprite.texture = texture
	sprite.scale = Vector2(body_scale, body_scale)
	var shape := hitbox.shape.duplicate() as CircleShape2D
	if shape != null:
		shape.radius = radius
		hitbox.shape = shape


func _process(delta: float) -> void:
	tick_hit_flash(delta)
	sprite.modulate = Color(2.0, 2.0, 2.0, 1.0) if flash_left > 0.0 else Color.WHITE


func _physics_process(delta: float) -> void:
	if dead:
		return
	_hit_cd = maxf(0.0, _hit_cd - delta)
	_shoot_cd = maxf(0.0, _shoot_cd - delta)
	_tick_slow(delta)
	if not Game.running:
		return
	var player := Game.player as PlayerUnit
	if player != null and not player.dead:
		var to_player: Vector2 = player.global_position - global_position
		var distance := to_player.length()
		var direction := to_player.normalized() if distance > 0.001 else Vector2.RIGHT
		# On lane duty the hero has to come to the creep; otherwise the whole
		# wave would peel off and chase one target around the map.
		if not lane_active or distance <= engage_range:
			_steer(direction, distance, delta)
			velocity += _separation()
			position += velocity * delta
			clamp_to_arena(radius + 4.0)
			_face(delta, direction)
			_touch_player(distance, player)
			_try_shoot(distance, player)
			return
	if lane_active:
		_march_lane(delta)


## Walks the middle lane toward the tree. Going through `lane_end` counts as a
## leak: the creep chips the tree and is removed, so a wave that gets past the
## hero still costs something.
func _march_lane(delta: float) -> void:
	var to_end: Vector2 = lane_end - global_position
	var distance := to_end.length()
	if distance <= radius + 26.0:
		_leak()
		return
	var direction := to_end.normalized() if distance > 0.001 else Vector2.DOWN
	velocity = velocity.lerp(direction * speed * slow_mult, minf(1.0, delta * 4.0))
	velocity += _separation()
	position += velocity * delta
	clamp_to_arena(radius + 4.0)
	_face(delta, direction)


func _leak() -> void:
	Game.damage_tree(int(round(contact_damage * 1.6)))
	Fx.burst(global_position, Color(1.0, 0.6, 0.3), 16, 260.0, 0.8)
	Fx.flash(global_position, Color(1.0, 0.55, 0.35))
	Fx.sfx(Fx.SFX_HIT, -4.0, 0.8)
	queue_free()


func apply_slow(factor: float, duration: float) -> void:
	# Strongest slow wins and the timer refreshes on every frost arrow; a
	# creep never stacks itself down to a standstill.
	slow_mult = minf(slow_mult, clampf(1.0 - factor, 0.15, 1.0))
	slow_left = maxf(slow_left, duration)


func _tick_slow(delta: float) -> void:
	if slow_left <= 0.0:
		return
	slow_left = maxf(0.0, slow_left - delta)
	if slow_left <= 0.0:
		slow_mult = 1.0


func _steer(direction: Vector2, distance: float, delta: float) -> void:
	match kind:
		Kind.CHASER:
			velocity = velocity.lerp(direction * speed, minf(1.0, delta * 6.0))
		Kind.BRUTE:
			velocity = velocity.lerp(direction * speed, minf(1.0, delta * 3.0))
		Kind.SPITTER:
			var tangent := Vector2(-direction.y, direction.x) * _orbit
			if distance < 320.0:
				velocity = velocity.lerp(-direction * speed, minf(1.0, delta * 5.0))
			elif distance > 640.0:
				velocity = velocity.lerp(direction * speed, minf(1.0, delta * 5.0))
			else:
				velocity = velocity.lerp(tangent * speed * 0.7, minf(1.0, delta * 3.0))


func _separation() -> Vector2:
	var push := Vector2.ZERO
	for other in get_tree().get_nodes_in_group("enemies"):
		var neighbour := other as Enemy
		if neighbour == null or neighbour == self:
			continue
		var offset: Vector2 = global_position - neighbour.global_position
		var gap := offset.length()
		var limit: float = radius + neighbour.radius
		if gap > 0.01 and gap < limit:
			push += offset / gap * (limit - gap) * 5.0
	return push


func _face(delta: float, direction: Vector2) -> void:
	if kind == Kind.SPITTER:
		rotation = lerp_angle(rotation, direction.angle(), minf(1.0, delta * 5.0))
	elif velocity.length() > 4.0:
		rotation = lerp_angle(rotation, velocity.angle(), minf(1.0, delta * 9.0))


func _touch_player(distance: float, player: PlayerUnit) -> void:
	if distance >= radius + 20.0 or _hit_cd > 0.0:
		return
	_hit_cd = 0.8
	player.take_damage(contact_damage, global_position)
	Fx.burst(global_position, base_color, 6, 150.0, 0.6)


func _try_shoot(distance: float, player: PlayerUnit) -> void:
	if kind != Kind.SPITTER or _shoot_cd > 0.0 or distance > 760.0:
		return
	if Game.bullets_root == null:
		return
	_shoot_cd = 2.3
	var lead: float = distance / 900.0
	var target: Vector2 = player.global_position + player.velocity * lead * 0.6
	var direction := (target - global_position).normalized()
	var bullet := BULLET_SCENE.instantiate()
	bullet.setup(direction, 14.0, 620.0, false, Color(1.0, 0.4, 0.45))
	bullet.position = global_position + direction * (radius + 8.0)
	Game.bullets_root.add_child(bullet)
	sfx_shoot.pitch_scale = randf_range(0.82, 0.98)
	sfx_shoot.play()


func take_damage(amount: float, hit_at: Vector2) -> void:
	if dead:
		return
	health -= amount
	start_hit_flash(0.1)
	knock_back(hit_at, 3.0)
	Fx.burst(hit_at, base_color, 4, 130.0, 0.5)
	if health <= 0.0:
		_die()


func _die() -> void:
	dead = true
	died.emit(kind, global_position)
	Fx.burst(global_position, base_color, 22, 360.0, 1.0)
	Fx.flash(global_position, base_color)
	Fx.sfx(Fx.SFX_DIE, -4.0, randf_range(0.9, 1.2))
	Game.add_shake(0.3 if kind == Kind.CHASER else 0.6)
	queue_free()
