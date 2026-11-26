class_name LaneVisual
extends Node2D
## Draws the middle lane on the floor: a faint band, a dashed centre line and
## two edge rails. Pure `_draw` so the lane can be re-shaped by changing three
## constants instead of a texture.

const LANE_X := 800.0
const START_Y := 100.0
const END_Y := 858.0
const WIDTH := 190.0


func _draw() -> void:
	var height := END_Y - START_Y
	var band := Rect2(Vector2(LANE_X - WIDTH * 0.5, START_Y), Vector2(WIDTH, height))
	draw_rect(band, Color(0.16, 0.48, 0.62, 0.10))
	# Soft inner glow so the lane reads even on a dark floor.
	draw_rect(Rect2(Vector2(LANE_X - 30.0, START_Y), Vector2(60.0, height)), Color(0.45, 0.9, 1.0, 0.03))
	# Edge rails.
	for side in [-1.0, 1.0]:
		var x: float = LANE_X + side * WIDTH * 0.5
		draw_line(Vector2(x, START_Y), Vector2(x, END_Y), Color(0.4, 0.85, 1.0, 0.22), 2.0)
	# Dashed centre line, telling you which way the creeps walk.
	var y := START_Y + 8.0
	while y < END_Y - 24.0:
		draw_rect(Rect2(Vector2(LANE_X - 2.0, y), Vector2(4.0, 26.0)), Color(0.55, 0.95, 1.0, 0.12))
		y += 56.0
