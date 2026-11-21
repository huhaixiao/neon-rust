class_name Pickup
extends Area2D
## Floating drop: health patch or temporary triple-shot overdrive.

enum Kind { HEALTH, OVERDRIVE }

const TEX_HEALTH := preload("res://assets/sprites/pickup_health.png")
const TEX_OVERDRIVE := preload("res://assets/sprites/pickup_overdrive.png")

var kind: Kind = Kind.HEALTH
var life := 16.0

var _bob := 0.0

@onready var sprite: Sprite2D = $Sprite


func setup(pickup_kind: Kind) -> void:
	kind = pickup_kind


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	if kind == Kind.HEALTH:
		sprite.texture = TEX_HEALTH
		sprite.modulate = Color(0.55, 1.0, 0.7, 1.0)
	else:
		sprite.texture = TEX_OVERDRIVE
		sprite.modulate = Color(1.0, 0.92, 0.55, 1.0)
	body_entered.connect(_on_body_entered)
	_bob = randf() * TAU


func _process(delta: float) -> void:
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	_bob += delta * 3.2
	sprite.position.y = sin(_bob) * 3.5
	sprite.rotation = sin(_bob * 0.5) * 0.12
	# Pull towards a nearby player so the pickup never feels like a chore.
	var player := Game.player as PlayerUnit
	if player != null and not player.dead:
		var to_player: Vector2 = player.global_position - global_position
		var distance := to_player.length()
		if distance < 150.0 and distance > 1.0:
			global_position += to_player / distance * 280.0 * delta
	if life < 3.0:
		sprite.modulate.a = 0.45 + 0.55 * absf(sin(life * 9.0))


func _on_body_entered(body: Node2D) -> void:
	var player := body as PlayerUnit
	if player == null:
		return
	if kind == Kind.HEALTH:
		player.heal(30)
	else:
		player.grant_overdrive(9.0)
	Fx.sfx(Fx.SFX_PICKUP, -2.0, randf_range(0.96, 1.06))
	Fx.burst(global_position, Color(0.5, 1.0, 0.65), 10, 170.0, 0.7)
	queue_free()
