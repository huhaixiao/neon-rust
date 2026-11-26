class_name Projectile
extends Area2D
## Shared bullet for both sides. `setup()` must be called before the node is
## added to the tree, because collision layers are applied in `_ready()`.

const TEX_FRIENDLY := preload("res://modules/projectiles/assets/sprites/bullet_player.png")
const TEX_HOSTILE := preload("res://modules/projectiles/assets/sprites/bullet_enemy.png")

var direction := Vector2.RIGHT
var speed := 1000.0
var damage := 18.0
var friendly := true
var tint := Color(0.5, 1.0, 1.0)
var life := 1.4
## Extra targets this round can pass through (PIERCING ROUNDS).
var pierce := 0
## Frost arrow payload: how hard and how long a hit creep is slowed.
var slow := 0.0
var slow_time := 0.0

var _spent := false
var _left := 0
var _hit_bodies: Array[Node] = []

@onready var sprite: Sprite2D = $Sprite
@onready var trail: Line2D = $Trail


func setup(dir: Vector2, dmg: float, spd: float, is_friendly: bool, color: Color, extra_pierce := 0, slow_amount := 0.0, slow_secs := 0.0) -> void:
	direction = dir.normalized()
	damage = dmg
	speed = spd
	friendly = is_friendly
	tint = color
	pierce = extra_pierce
	_left = extra_pierce
	slow = slow_amount
	slow_time = slow_secs


func _ready() -> void:
	rotation = direction.angle()
	sprite.texture = TEX_FRIENDLY if friendly else TEX_HOSTILE
	sprite.modulate = tint
	trail.default_color = tint
	trail.points = PackedVector2Array([Vector2.ZERO, Vector2(-26.0, 0.0)])
	if friendly:
		collision_layer = 4   # bit 3: player shots
		collision_mask = 2    # bit 2: enemies
	else:
		collision_layer = 8   # bit 4: enemy shots
		collision_mask = 1    # bit 1: player
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	position += direction * speed * delta
	if not Game.arena.grow(90.0).has_point(global_position):
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	if _spent:
		return
	if friendly:
		var enemy := body as Enemy
		if enemy == null or _hit_bodies.has(body):
			return
		if enemy.team != Enemy.Team.DIRE:
			return
		enemy.take_damage(damage, global_position)
		if slow > 0.0:
			enemy.apply_slow(slow, slow_time)
		var player := Game.player as PlayerUnit
		if player != null:
			player.on_damage_dealt(damage)
		Fx.burst(global_position, tint, 4, 130.0, 0.5)
		_hit_bodies.append(body)
		if _left > 0:
			_left -= 1
			return
		_spent = true
		queue_free()
	else:
		var player := body as PlayerUnit
		if player == null:
			return
		_spent = true
		player.take_damage(damage, global_position)
		Fx.burst(global_position, tint, 6, 140.0, 0.6)
		queue_free()
