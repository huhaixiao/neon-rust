class_name ShipBody
extends CharacterBody2D
## The part every flying body in the arena shares: the "dead" flag, arena
## clamping, the hit-flash timer, and impact knock-back.
##
## Movement, aiming, health and the death sequence deliberately stay in the
## subclasses — the player's hull lives in `Game`, enemies keep a local pool and
## drop score when they die, so a common health/death API would only hide that.
##
##   PlayerUnit ─┐
##               ├─ ShipBody ─ CharacterBody2D
##   Enemy      ─┘

## Margin from the arena edge used when a caller does not pass its own padding.
## Bodies with a radius should pass `radius + a few pixels` to clamp_to_arena().
@export var wall_padding := 20.0

var dead := false
## Seconds left on the hit flash. Subclasses choose the colour they paint.
var flash_left := 0.0


func clamp_to_arena(padding := -1.0) -> void:
	var margin := wall_padding if padding < 0.0 else padding
	var bounds := Game.arena.grow(-margin)
	global_position = global_position.clamp(bounds.position, bounds.end)


func start_hit_flash(seconds := 0.1) -> void:
	flash_left = maxf(flash_left, seconds)


func tick_hit_flash(delta: float) -> void:
	flash_left = maxf(0.0, flash_left - delta)


func knock_back(from: Vector2, distance: float) -> void:
	if from == Vector2.ZERO:
		return
	var push := global_position - from
	if push.length() > 0.01:
		global_position += push.normalized() * distance
