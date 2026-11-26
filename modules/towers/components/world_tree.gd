class_name WorldTree
extends Node2D
## The World Tree: the thing a lane run is actually defending.
##
## Drawn in code on purpose - no sprite sheet, no import step - so the whole
## tower defence layer can land before any art exists. Swapping in a real
## sprite later only touches `_draw`.

const TREE_HEIGHT := 168.0

var _pulse := 0.0
var _hit := 0.0


func _ready() -> void:
	Game.tree = self
	add_to_group("tree")


func _process(delta: float) -> void:
	_pulse += delta * 1.8
	_hit = maxf(0.0, _hit - delta * 4.0)
	queue_redraw()


## Called by `Game.damage_tree()` so the tree visibly reacts to a lane leak.
func on_hit() -> void:
	_hit = 1.0


func health_ratio() -> float:
	if Game.max_tree_health <= 0:
		return 1.0
	return clampf(float(Game.tree_health) / float(Game.max_tree_health), 0.0, 1.0)


func _draw() -> void:
	var ratio := health_ratio()
	# Healthy canopy is green; as it gets chipped it drifts toward ember red.
	# DotA1 foliage green rather than neon mint: a real tree, chipped toward
	# ember red as the lane leaks.
	var canopy := Color(0.30, 0.62, 0.26).lerp(Color(0.86, 0.36, 0.20), 1.0 - ratio)
	var breathe := 0.5 + 0.5 * sin(_pulse)

	# Ground shadow + glow.
	draw_circle(Vector2(0.0, 8.0), 92.0, Color(0.02, 0.08, 0.06, 0.55))
	draw_circle(Vector2(0.0, 4.0), 86.0, Color(canopy.r, canopy.g, canopy.b, 0.05 + 0.05 * breathe))

	# Roots: five low arcs spreading out from the base.
	for i in 5:
		var spread := -1.0 + 0.5 * float(i)
		var to := Vector2(spread * 56.0, 14.0 + absf(spread) * 8.0)
		draw_line(Vector2(0.0, -4.0), to, Color(0.18, 0.26, 0.2, 0.75), 5.0)

	# Trunk: dark core with a lit edge so it reads against the floor.
	draw_colored_polygon(PackedVector2Array([
		Vector2(-11.0, -18.0), Vector2(11.0, -18.0),
		Vector2(15.0, 22.0), Vector2(-15.0, 22.0),
	]), Color(0.2, 0.22, 0.18))
	draw_line(Vector2(-9.0, -18.0), Vector2(-12.0, 20.0), Color(0.42, 0.36, 0.26, 0.9), 2.0)

	# Canopy: a cluster of unequal masses, dark underside first so the top
	# reads as lit from above.
	var shade := Color(canopy.r * 0.32, canopy.g * 0.42, canopy.b * 0.34, 0.95)
	draw_circle(Vector2(0.0, -40.0), 58.0, shade)
	draw_circle(Vector2(-46.0, -58.0), 40.0, shade)
	draw_circle(Vector2(46.0, -58.0), 40.0, shade)
	var mass := Color(canopy.r, canopy.g, canopy.b, 0.72)
	draw_circle(Vector2(0.0, -66.0), 50.0, mass)
	draw_circle(Vector2(-38.0, -76.0), 34.0, mass)
	draw_circle(Vector2(38.0, -76.0), 34.0, mass)
	draw_circle(Vector2(0.0, -104.0), 40.0, mass)
	var light := Color(canopy.r, canopy.g, canopy.b, 0.95)
	draw_circle(Vector2(-8.0, -86.0), 24.0, light)
	draw_circle(Vector2(16.0, -100.0), 16.0, light)

	# A couple of drifting spores keep the centrepiece alive.
	for i in 3:
		var phase := _pulse * 0.6 + float(i) * 2.1
		var offset := Vector2(cos(phase) * (52.0 + float(i) * 8.0), sin(phase * 0.8) * 18.0 - 96.0)
		draw_circle(offset, 2.5, Color(0.9, 1.0, 0.8, 0.35 + 0.25 * breathe))

	# Health ring at the base: a leak reads even when the canopy is intact.
	var ring := Color(canopy.r, canopy.g, canopy.b, 0.45 + 0.2 * breathe)
	draw_arc(Vector2.ZERO, 66.0, 0.0, TAU, 56, ring, 2.5)
	if _hit > 0.0:
		draw_circle(Vector2(0.0, -40.0), 130.0, Color(1.0, 0.35, 0.3, 0.16 * _hit))
