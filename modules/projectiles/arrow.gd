class_name Arrow
extends Area2D
## The hero's arrow. Same `setup()` signature as `Projectile` so the shooting
## code can swap scenes, but the look is DotA1: a drawn shaft with a glinting
## head and a fletched tail, plus a faked arc - the arrow lifts off the ground
## line and drops back onto it, which is how a bowshot reads from above.

var direction := Vector2.RIGHT
var speed := 1250.0
var damage := 45.0
var friendly := true
var tint := Color(0.9, 1.0, 0.85)
var life := 1.4
var pierce := 0
var slow := 0.0
var slow_time := 0.0

var _spent := false
var _left := 0
var _hit_bodies: Array[Node] = []
var _flight := 0.0
var _elapsed := 0.0


func setup(dir: Vector2, dmg: float, spd: float, is_friendly: bool, color: Color, extra_pierce := 0, slow_amount := 0.0, slow_secs := 0.0) -> void:
	direction = dir.normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT
	damage = dmg
	speed = spd
	friendly = is_friendly
	tint = color
	pierce = extra_pierce
	_left = extra_pierce
	slow = slow_amount
	slow_time = slow_secs
	_flight = clampf(life, 0.05, 1.2)


func _ready() -> void:
	rotation = direction.angle()
	if friendly:
		collision_layer = 4
		collision_mask = 2
	else:
		collision_layer = 8
		collision_mask = 1
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	life -= delta
	_elapsed += delta
	if life <= 0.0:
		queue_free()
		return
	position += direction * speed * delta
	if not Game.arena.grow(90.0).has_point(global_position):
		queue_free()
		return
	# Only the flicker needs a redraw; everything else is static geometry.
	queue_redraw()


func _draw() -> void:
	var t := clampf(_elapsed / _flight, 0.0, 1.0)
	# Fake height: the arrow rises to mid-flight and settles back down, so the
	# shot reads as an arc instead of a laser.
	var lift := -sin(t * PI) * 9.0
	draw_set_transform(Vector2(0.0, lift))
	# Ground shadow, pinned to the true travel line.
	draw_set_transform(Vector2(-2.0, 0.0))
	draw_circle(Vector2(-18.0, 4.0), 2.4, Color(0.0, 0.0, 0.0, 0.28))
	# Shaft.
	draw_line(Vector2(-20.0, 0.0), Vector2(12.0, 0.0), Color(0.42, 0.30, 0.16, 1.0), 2.0)
	draw_line(Vector2(-20.0, -1.0), Vector2(12.0, -1.0), Color(0.72, 0.56, 0.30, 0.9), 1.0)
	# Head.
	draw_colored_polygon(PackedVector2Array([
		Vector2(12.0, -3.0), Vector2(21.0, 0.0), Vector2(12.0, 3.0)
	]), tint)
	draw_line(Vector2(12.0, 0.0), Vector2(20.0, 0.0), Color(1.0, 1.0, 1.0, 0.85), 1.0)
	# Fletching: two swept feathers at the tail, tinted with the payload
	# (frost arrows come out pale blue, plain arrows bone white).
	draw_colored_polygon(PackedVector2Array([
		Vector2(-20.0, 0.0), Vector2(-13.0, -5.0), Vector2(-15.0, 0.0)
	]), tint)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-20.0, 0.0), Vector2(-13.0, 5.0), Vector2(-15.0, 0.0)
	]), tint)
	# In-flight sparkle so a long shot still reads against the grass.
	if t < 0.85:
		draw_circle(Vector2(13.0, 0.0), 1.6, Color(1.0, 1.0, 1.0, 0.5))


func _on_body_entered(body: Node2D) -> void:
	if _spent:
		return
	if friendly:
		var enemy := body as Enemy
		if enemy == null or _hit_bodies.has(body):
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
