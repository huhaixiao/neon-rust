class_name CreepArt
extends Node2D
## Drawn lane creep, facing +X (the parent turns it). Three silhouettes that map
## to the DotA1 roles: a club-wielding melee grunt, a hooded ranged archer and a
## wheeled siege engine. Drawn, not textured, so a recolour is one constant.

const SKIN := Color(0.42, 0.46, 0.36)
const SKIN_DARK := Color(0.26, 0.30, 0.24)
const BONE := Color(0.84, 0.82, 0.72)
const WOOD := Color(0.36, 0.26, 0.14)
const IRON := Color(0.52, 0.54, 0.58)

var kind := 0
var team := Color(0.62, 0.16, 0.20)

var _t := 0.0
var _walk := 0.0


func build(kind_value: int, team_color: Color) -> void:
	kind = kind_value
	team = team_color
	_t = randf() * 6.0
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	_walk = 1.0 if get_parent() is Enemy and (get_parent() as Enemy).velocity.length() > 20.0 else 0.0
	queue_redraw()


func _draw() -> void:
	var step := sin(_t * 8.0) * 3.0 * _walk
	var breathe := sin(_t * 2.4) * 0.8
	match kind:
		1:
			_draw_siege()
		2:
			_draw_ranged(step, breathe)
		_:
			_draw_melee(step, breathe)


func _draw_melee(step: float, breathe: float) -> void:
	# Legs.
	draw_line(Vector2(-4.0, 6.0), Vector2(-5.0, 15.0 + step), SKIN_DARK, 4.0)
	draw_line(Vector2(3.0, 6.0), Vector2(4.0, 15.0 - step), SKIN_DARK, 4.0)
	# Torso.
	draw_colored_polygon(PackedVector2Array([
		Vector2(-9.0, -6.0 + breathe), Vector2(4.0, -8.0 + breathe),
		Vector2(8.0, 0.0), Vector2(4.0, 8.0 + breathe), Vector2(-9.0, 7.0 + breathe)
	]), SKIN)
	# Team tabard.
	draw_colored_polygon(PackedVector2Array([
		Vector2(-7.0, -2.0 + breathe), Vector2(6.0, -3.0 + breathe),
		Vector2(7.0, 6.0 + breathe), Vector2(-7.0, 6.0 + breathe)
	]), team)
	# Head.
	draw_circle(Vector2(1.0, -10.0 + breathe), 5.0, SKIN_DARK)
	draw_circle(Vector2(3.0, -11.0 + breathe), 1.3, Color(0.95, 0.35, 0.30))
	# Horned helm.
	draw_colored_polygon(PackedVector2Array([
		Vector2(-4.0, -14.0 + breathe), Vector2(6.0, -14.0 + breathe),
		Vector2(5.0, -11.0 + breathe), Vector2(-4.0, -11.0 + breathe)
	]), IRON)
	draw_line(Vector2(-4.0, -14.0), Vector2(-8.0, -18.0), BONE, 2.0)
	draw_line(Vector2(6.0, -14.0), Vector2(10.0, -18.0), BONE, 2.0)
	# Club, swung with the walk cycle.
	var swing := sin(_t * 8.0) * 0.35 * _walk - 0.25
	var grip := Vector2(10.0, 0.0)
	var hand := grip + Vector2(cos(swing), sin(swing)) * 12.0
	draw_line(grip, hand, WOOD, 3.0)
	draw_circle(hand, 4.0, WOOD)
	draw_circle(hand + Vector2(3.0, 0.0).rotated(swing), 3.2, IRON)


func _draw_ranged(step: float, breathe: float) -> void:
	draw_line(Vector2(-3.0, 6.0), Vector2(-4.0, 14.0 + step), SKIN_DARK, 3.0)
	draw_line(Vector2(2.0, 6.0), Vector2(3.0, 14.0 - step), SKIN_DARK, 3.0)
	# Robe.
	draw_colored_polygon(PackedVector2Array([
		Vector2(-8.0, -6.0 + breathe), Vector2(3.0, -7.0 + breathe),
		Vector2(6.0, 8.0 + breathe), Vector2(-8.0, 8.0 + breathe)
	]), team.darkened(0.35))
	# Hood.
	draw_circle(Vector2(0.0, -9.0 + breathe), 5.0, team.darkened(0.55))
	draw_circle(Vector2(2.0, -9.0 + breathe), 2.6, BONE)
	draw_circle(Vector2(3.2, -9.0 + breathe), 1.0, Color(0.2, 0.9, 0.4))
	# Small bow, held out front.
	var bow := Vector2(10.0, -1.0)
	draw_arc(bow, 9.0, -1.15, 1.15, 14, WOOD, 2.0, true)
	var a := bow + Vector2(cos(-1.15), sin(-1.15)) * 9.0
	var b := bow + Vector2(cos(1.15), sin(1.15)) * 9.0
	draw_line(a, bow + Vector2(-4.0, 0.0), BONE, 1.0)
	draw_line(b, bow + Vector2(-4.0, 0.0), BONE, 1.0)


func _draw_siege() -> void:
	# Wheels.
	for x in [-8.0, 9.0]:
		draw_circle(Vector2(x, 12.0), 7.0, WOOD)
		draw_circle(Vector2(x, 12.0), 2.0, SKIN_DARK)
		draw_line(Vector2(x - 6.0, 12.0), Vector2(x + 6.0, 12.0), WOOD.lightened(0.2), 1.0)
	# Cart body.
	draw_colored_polygon(PackedVector2Array([
		Vector2(-13.0, -4.0), Vector2(11.0, -4.0), Vector2(9.0, 10.0), Vector2(-11.0, 10.0)
	]), WOOD)
	draw_line(Vector2(-13.0, 0.0), Vector2(11.0, 0.0), WOOD.darkened(0.3), 1.5)
	# Throwing arm, cocked back.
	draw_line(Vector2(-4.0, -4.0), Vector2(-12.0, -14.0), Color(0.5, 0.36, 0.2), 3.0)
	draw_circle(Vector2(-12.0, -14.0), 4.0, IRON)
	# Iron rim + team banner.
	draw_line(Vector2(-11.0, 9.0), Vector2(9.0, 9.0), IRON, 2.0)
	draw_colored_polygon(PackedVector2Array([
		Vector2(2.0, -4.0), Vector2(2.0, -16.0), Vector2(12.0, -12.0), Vector2(2.0, -8.0)
	]), team)
