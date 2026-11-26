class_name CreepHealthBar
extends Node2D
## The little striped bar that floats over a lane creep. Top-level so it stays
## upright while the creep body turns to face its target, the way DotA1 draws
## creep HP.

var ratio := 1.0
var bar_width := 30.0


func set_ratio(value: float) -> void:
	var clamped := clampf(value, 0.0, 1.0)
	if absf(clamped - ratio) < 0.001:
		return
	ratio = clamped
	queue_redraw()


func _ready() -> void:
	z_index = 8
	queue_redraw()


func _draw() -> void:
	var w := bar_width
	var h := 4.0
	draw_rect(Rect2(Vector2(-w * 0.5 - 1.0, -h - 1.0), Vector2(w + 2.0, h + 2.0)), Color(0.05, 0.05, 0.05, 0.85))
	var fill := Color(0.36, 0.78, 0.26) if ratio > 0.5 else (Color(0.88, 0.76, 0.22) if ratio > 0.22 else Color(0.84, 0.26, 0.20))
	draw_rect(Rect2(Vector2(-w * 0.5, -h), Vector2(w * ratio, h)), fill)
	draw_rect(Rect2(Vector2(-w * 0.5, -h), Vector2(w, h)), Color(0.62, 0.62, 0.58, 0.55), false, 1.0)
