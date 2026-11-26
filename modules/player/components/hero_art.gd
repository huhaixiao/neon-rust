class_name HeroArt
extends Node2D
## Drawn hero figure, facing +X so the parent's `rotation = aim` does the
## turning. No texture: a hooded archer built out of a few polygons, an
## elliptical bow and a nocked arrow. `pose` 0..1 pulls the string, which is
## what the shoot wind-up drives.

const CLOAK := Color(0.16, 0.30, 0.22)
const CLOAK_LIGHT := Color(0.24, 0.44, 0.30)
const TRIM := Color(0.72, 0.62, 0.34)
const SKIN := Color(0.80, 0.66, 0.50)
const WOOD := Color(0.44, 0.30, 0.16)

var pose := 0.0
var bob := 0.0

var _t := 0.0


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var breathe := sin(_t * 3.0) * 1.2
	var walk := sin(_t * 9.0) * bob

	# --- legs / boots ------------------------------------------------------
	draw_colored_polygon(PackedVector2Array([
		Vector2(-8.0, 4.0 + walk), Vector2(-1.0, 4.0 + walk),
		Vector2(-1.0, 15.0 + walk), Vector2(-8.0, 15.0 + walk)
	]), Color(0.12, 0.16, 0.14))
	draw_colored_polygon(PackedVector2Array([
		Vector2(-1.0, 4.0 - walk), Vector2(7.0, 4.0 - walk),
		Vector2(7.0, 15.0 - walk), Vector2(-1.0, 15.0 - walk)
	]), Color(0.12, 0.16, 0.14))

	# --- cloak / torso -----------------------------------------------------
	draw_colored_polygon(PackedVector2Array([
		Vector2(-10.0, -8.0 + breathe), Vector2(5.0, -11.0 + breathe),
		Vector2(9.0, 0.0), Vector2(5.0, 10.0 + breathe),
		Vector2(-10.0, 8.0 + breathe)
	]), CLOAK)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-3.0, -8.0 + breathe), Vector2(5.0, -9.0 + breathe),
		Vector2(7.0, 0.0), Vector2(5.0, 8.0 + breathe), Vector2(-3.0, 7.0 + breathe)
	]), CLOAK_LIGHT)
	# Belt.
	draw_line(Vector2(-4.0, 3.0), Vector2(6.0, 3.0), TRIM, 2.0)

	# --- hood + face -------------------------------------------------------
	draw_circle(Vector2(2.0, -8.0 + breathe), 6.5, CLOAK)
	draw_circle(Vector2(4.5, -8.0 + breathe), 4.2, SKIN)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-4.0, -13.0 + breathe), Vector2(6.0, -13.5 + breathe),
		Vector2(7.0, -10.0 + breathe), Vector2(-4.0, -9.0 + breathe)
	]), CLOAK)
	draw_circle(Vector2(6.0, -8.0 + breathe), 1.0, Color(0.1, 0.1, 0.1))

	# --- quiver ------------------------------------------------------------
	draw_line(Vector2(-11.0, -4.0), Vector2(-13.0, 8.0), Color(0.30, 0.22, 0.12), 3.0)
	for i in 3:
		draw_line(
			Vector2(-13.0 + float(i) * 1.6, 2.0),
			Vector2(-15.0 + float(i) * 1.6, -2.0),
			Color(0.86, 0.84, 0.76), 1.0
		)

	# --- bow ---------------------------------------------------------------
	var centre := Vector2(12.0, 0.0)
	var radius := 15.0
	draw_arc(centre, radius, -1.05, 1.05, 22, WOOD, 3.0, true)
	draw_arc(centre, radius - 1.5, -1.05, 1.05, 22, Color(0.62, 0.45, 0.24), 1.0, true)
	var top_tip := centre + Vector2(cos(-1.05), sin(-1.05)) * radius
	var bottom_tip := centre + Vector2(cos(1.05), sin(1.05)) * radius
	# String, pulled back by `pose`.
	var nock := centre + Vector2(-3.0 - 9.0 * pose, 0.0)
	draw_line(top_tip, nock, Color(0.9, 0.9, 0.86, 0.85), 1.0)
	draw_line(bottom_tip, nock, Color(0.9, 0.9, 0.86, 0.85), 1.0)
	if pose > 0.02:
		draw_line(nock, nock + Vector2(18.0, 0.0), Color(0.5, 0.36, 0.2), 2.0)
		draw_colored_polygon(PackedVector2Array([
			nock + Vector2(18.0, -2.5), nock + Vector2(24.0, 0.0), nock + Vector2(18.0, 2.5)
		]), Color(0.92, 1.0, 0.9))

	# --- hands ------------------------------------------------------------
	draw_circle(centre + Vector2(-2.0 - 7.0 * pose, 0.0), 2.2, SKIN)
	draw_circle(centre + Vector2(-1.0, 0.0), 2.0, SKIN)
