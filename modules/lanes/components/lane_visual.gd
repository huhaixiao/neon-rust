class_name LaneVisual
extends Node2D
## The ground. One `_draw` builds the whole DotA1-looking battlefield: grass,
## a worn dirt lane running from the Dire entry in the top-right down to the
## World Tree in the bottom-left, a river crossing it, scrub and boulders beside
## the lane, and a stand of trees forming the map wall.
##
## Every coordinate comes from `LaneSpec`, so the lane art and the creeps that
## walk it can never drift apart. Everything is deterministic (`rng.seed` set
## once), so the map looks the same on every run.

const GRASS := Color(0.20, 0.32, 0.17)
const GRASS_DARK := Color(0.13, 0.24, 0.13)
const GRASS_LIGHT := Color(0.27, 0.40, 0.20)
const DIRT := Color(0.45, 0.35, 0.21)
const DIRT_DARK := Color(0.35, 0.27, 0.16)
const DIRT_LIGHT := Color(0.53, 0.42, 0.26)
const WATER := Color(0.16, 0.34, 0.42)
const WATER_LIGHT := Color(0.24, 0.46, 0.54)
const TREE_DARK := Color(0.10, 0.20, 0.10)
const TREE_MID := Color(0.14, 0.28, 0.13)
const TREE_LIGHT := Color(0.20, 0.36, 0.16)
const STONE := Color(0.34, 0.34, 0.32)

var rng := RandomNumberGenerator.new()


func _ready() -> void:
	rng.seed = 0x0D07A1
	queue_redraw()


func _draw() -> void:
	var field := Game.arena.grow(60.0)
	draw_rect(field, GRASS)
	_ground_mottle(field)
	_river()
	_lane_path()
	_scrub(field)
	_tree_wall(field)
	_rune_stones()


## Big soft blotches so the grass is not a flat rectangle.
func _ground_mottle(field: Rect2) -> void:
	for i in 150:
		var p := Vector2(
			rng.randf_range(field.position.x, field.end.x),
			rng.randf_range(field.position.y, field.end.y)
		)
		var r := rng.randf_range(28.0, 100.0)
		var tone := GRASS_DARK if rng.randf() < 0.55 else GRASS_LIGHT
		tone.a = rng.randf_range(0.10, 0.22)
		draw_circle(p, r, tone)
	# Grass tufts, short strokes scattered everywhere off-lane.
	for i in 460:
		var p := Vector2(
			rng.randf_range(field.position.x, field.end.x),
			rng.randf_range(field.position.y, field.end.y)
		)
		if absf(LaneSpec.lateral(p)) < LaneSpec.HALF_WIDTH * 0.7:
			continue
		var h := rng.randf_range(3.0, 7.0)
		var col := GRASS_LIGHT
		col.a = rng.randf_range(0.18, 0.34)
		draw_line(p, p + Vector2(rng.randf_range(-1.5, 1.5), -h), col, 1.0)


## The river crossing mid: a wide band perpendicular to the lane, so it reads
## as the map's diagonal river instead of a stripe painted through the lane.
func _river() -> void:
	var centre := LaneSpec.point(0.42)
	var axis := LaneSpec.normal()
	var across := axis * 1000.0
	var bank := 96.0
	var along := LaneSpec.direction()
	# Banks.
	draw_colored_polygon(PackedVector2Array([
		centre + across + along * bank, centre - across + along * bank,
		centre - across - along * bank, centre + across - along * bank
	]), Color(0.24, 0.28, 0.18))
	var water := 74.0
	draw_colored_polygon(PackedVector2Array([
		centre + across + along * water, centre - across + along * water,
		centre - across - along * water, centre + across - along * water
	]), WATER)
	# Current bands.
	for i in 7:
		var offset := float(i) - 3.0
		var a := centre + across + along * (offset * 18.0)
		var b := centre - across + along * (offset * 18.0)
		var col := WATER_LIGHT
		col.a = 0.10 + 0.03 * float(i % 3)
		draw_line(a, b, col, 3.0)
	# Shore foam dots along both banks.
	for i in 110:
		var t := rng.randf_range(-1.0, 1.0)
		var side := 1.0 if rng.randf() < 0.5 else -1.0
		var p: Vector2 = centre + across * t + along * (rng.randf_range(62.0, 88.0) * side)
		draw_circle(p, rng.randf_range(1.5, 3.5), Color(0.55, 0.72, 0.68, 0.25))


## The lane itself: dirt strip with ragged edges, cart ruts and scattered stones.
func _lane_path() -> void:
	var dir := LaneSpec.direction()
	var side := LaneSpec.normal()
	var steps := 72
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	for i in steps + 1:
		var t := float(i) / float(steps)
		var centre := LaneSpec.point(t)
		var wobble := sin(t * 9.0) * 6.0 + sin(t * 21.0) * 2.5
		left.append(centre + side * (-LaneSpec.HALF_WIDTH + wobble))
		right.append(centre + side * (LaneSpec.HALF_WIDTH + wobble))
	# Shoulder first, then the packed centre.
	var reversed_right := PackedVector2Array()
	for i in range(right.size() - 1, -1, -1):
		reversed_right.append(right[i])
	draw_colored_polygon(left + reversed_right, Color(0.33, 0.28, 0.18, 0.85))
	var inner := PackedVector2Array()
	for point in left + reversed_right:
		var centre_progress: float = LaneSpec.progress_of(point)
		var centre := LaneSpec.point(centre_progress)
		inner.append(centre + (point - centre) * 0.86)
	draw_colored_polygon(inner, DIRT)
	# Two cart ruts running the length of the lane.
	for offset in [-30.0, 30.0]:
		var travelled := 0.0
		var total := LaneSpec.length()
		while travelled < total:
			var t := travelled / total
			var wobble := sin(t * 9.0) * 6.0
			var at: Vector2 = LaneSpec.point(t) + side * (offset + wobble)
			draw_circle(at, 4.0, Color(DIRT_DARK.r, DIRT_DARK.g, DIRT_DARK.b, 0.5))
			travelled += 15.0
	# Pebbles and hoof marks.
	for i in 200:
		var t := rng.randf()
		var centre := LaneSpec.point(t)
		var at: Vector2 = centre + side * rng.randf_range(-LaneSpec.HALF_WIDTH * 0.14, LaneSpec.HALF_WIDTH * 0.14) * 3.3
		if rng.randf() < 0.6:
			draw_circle(at, rng.randf_range(1.0, 3.0), DIRT_LIGHT)
		else:
			draw_circle(at, rng.randf_range(1.5, 2.6), STONE.darkened(0.2))


## Boulders and bushes off the lane, so the eye has something beside the path.
func _scrub(field: Rect2) -> void:
	for i in 54:
		var p := Vector2(
			rng.randf_range(field.position.x + 40.0, field.end.x - 40.0),
			rng.randf_range(field.position.y + 40.0, field.end.y - 40.0)
		)
		if absf(LaneSpec.lateral(p)) < LaneSpec.HALF_WIDTH * 1.7:
			continue
		if p.distance_to(LaneSpec.TREE) < 210.0:
			continue
		var size := rng.randf_range(6.0, 15.0)
		if rng.randf() < 0.5:
			draw_circle(p + Vector2(0.0, size * 0.3), size * 0.8, Color(0.08, 0.12, 0.08, 0.35))
			draw_circle(p, size, STONE.darkened(rng.randf_range(0.1, 0.4)))
			draw_circle(p + Vector2(-size * 0.25, -size * 0.3), size * 0.5, STONE.lightened(0.15))
		else:
			draw_circle(p, size * 1.3, TREE_DARK)
			draw_circle(p + Vector2(-3.0, -2.0), size, TREE_MID)
			draw_circle(p + Vector2(-5.0, -5.0), size * 0.6, TREE_LIGHT)


## The trees that ring the map: a ragged wall on all four sides plus a few
## clusters inside, all kept clear of the lane corridor and the tree's plaza.
func _tree_wall(field: Rect2) -> void:
	var margin := 26.0
	for side in [field.position.x + margin, field.end.x - margin]:
		var y := field.position.y + margin
		while y < field.end.y - margin:
			_tree(Vector2(float(side) + rng.randf_range(-18.0, 18.0), y), rng.randf_range(26.0, 44.0))
			y += rng.randf_range(34.0, 52.0)
	for edge in [field.position.y + margin, field.end.y - margin]:
		var x := field.position.x + margin
		while x < field.end.x - margin:
			_tree(Vector2(x, float(edge) + rng.randf_range(-16.0, 16.0)), rng.randf_range(26.0, 46.0))
			x += rng.randf_range(36.0, 56.0)
	for i in 16:
		var p := Vector2(
			rng.randf_range(field.position.x + 80.0, field.end.x - 80.0),
			rng.randf_range(field.position.y + 80.0, field.end.y - 80.0)
		)
		if absf(LaneSpec.lateral(p)) < LaneSpec.HALF_WIDTH + 120.0:
			continue
		if p.distance_to(LaneSpec.TREE) < 240.0:
			continue
		_tree(p, rng.randf_range(24.0, 34.0))
		_tree(p + Vector2(rng.randf_range(-26.0, 26.0), rng.randf_range(-26.0, 26.0)), rng.randf_range(20.0, 30.0))


func _tree(at: Vector2, size: float) -> void:
	# Trunk shadow, then three stacked canopies for a chunky low-poly tree.
	draw_circle(at + Vector2(2.0, size * 0.55), size * 0.55, Color(0.05, 0.09, 0.05, 0.45))
	draw_rect(Rect2(at + Vector2(-3.0, size * 0.15), Vector2(6.0, size * 0.5)), Color(0.24, 0.18, 0.11))
	draw_circle(at + Vector2(0.0, size * 0.05), size, TREE_DARK)
	draw_circle(at + Vector2(-size * 0.22, -size * 0.18), size * 0.78, TREE_MID)
	draw_circle(at + Vector2(-size * 0.34, -size * 0.36), size * 0.48, TREE_LIGHT)


## Rune spots along the lane, decorative: a landmark at both ends of the walk.
func _rune_stones() -> void:
	for t in [0.28, 0.72]:
		var p := LaneSpec.point(t)
		draw_circle(p, 26.0, Color(0.16, 0.22, 0.16, 0.9))
		draw_arc(p, 26.0, 0.0, TAU, 32, Color(0.45, 0.55, 0.42, 0.6), 2.0)
		draw_arc(p, 16.0, 0.0, TAU, 24, Color(0.55, 0.68, 0.5, 0.45), 1.5)
		draw_circle(p, 6.0, Color(0.5, 0.75, 0.55, 0.35))
