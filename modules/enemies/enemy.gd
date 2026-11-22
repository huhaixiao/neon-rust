class_name Enemy
extends CharacterBody2D
## CHASER = fast/fragile, BRUTE = slow tank, SPITTER = keeps range and shoots.

signal died(kind: int, at: Vector2)

enum Kind { CHASER, BRUTE, SPITTER }

const TEX_CHASER := preload("res://assets/sprites/enemy_chaser.png")
const TEX_BRUTE := preload("res://assets/sprites/enemy_brute.png")
const TEX_SPITTER := preload("res://assets/sprites/enemy_spitter.png")
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

var _dead := false
var _hit_cd := 0.0
var _shoot_cd := 0.0
var _flash := 0.0
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
	_flash = maxf(0.0, _flash - delta)
	sprite.modulate = Color(2.0, 2.0, 2.0, 1.0) if _flash > 0.0 else Color.WHITE


func _physics_process(delta: float) -> void:
	if _dead:
		return
	_hit_cd = maxf(0.0, _hit_cd - delta)
	_shoot_cd = maxf(0.0, _shoot_cd - delta)
	if not Game.running:
		return
	var player := Game.player as PlayerUnit
	if player == null or player.dead:
		velocity = Vector2.ZERO
		return
	var to_player: Vector2 = player.global_position - global_position
	var distance := to_player.length()
	var direction := to_player.normalized() if distance > 0.001 else Vector2.RIGHT
	_steer(direction, distance, delta)
	velocity += _separation()
	position += velocity * delta
	var bounds := Game.arena.grow(-radius - 4.0)
	global_position = global_position.clamp(bounds.position, bounds.end)
	_face(delta, direction)
	_touch_player(distance, player)
	_try_shoot(distance, player)


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
	if _dead:
		return
	health -= amount
	_flash = 0.1
	var push := global_position - hit_at
	if push.length() > 0.01:
		global_position += push.normalized() * 3.0
	Fx.burst(hit_at, base_color, 4, 130.0, 0.5)
	if health <= 0.0:
		_die()


func _die() -> void:
	_dead = true
	died.emit(kind, global_position)
	Fx.burst(global_position, base_color, 22, 360.0, 1.0)
	Fx.flash(global_position, base_color)
	Fx.sfx(Fx.SFX_DIE, -4.0, randf_range(0.9, 1.2))
	Game.add_shake(0.3 if kind == Kind.CHASER else 0.6)
	queue_free()
