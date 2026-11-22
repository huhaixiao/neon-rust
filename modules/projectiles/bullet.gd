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

var _spent := false

@onready var sprite: Sprite2D = $Sprite
@onready var trail: Line2D = $Trail


func setup(dir: Vector2, dmg: float, spd: float, is_friendly: bool, color: Color) -> void:
	direction = dir.normalized()
	damage = dmg
	speed = spd
	friendly = is_friendly
	tint = color


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
		if enemy == null:
			return
		_spent = true
		enemy.take_damage(damage, global_position)
		Fx.burst(global_position, tint, 4, 130.0, 0.5)
		queue_free()
	else:
		var player := body as PlayerUnit
		if player == null:
			return
		_spent = true
		player.take_damage(damage, global_position)
		Fx.burst(global_position, tint, 6, 140.0, 0.6)
		queue_free()
