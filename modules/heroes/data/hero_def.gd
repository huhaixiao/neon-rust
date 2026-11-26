class_name HeroDef
extends Resource
## One playable hero. Everything a hero changes about the player unit lives
## in this resource, so adding a hero is a data change - no new scene, no
## duplicated script. Art is referenced by folder name only
## (`modules/heroes/assets/heroes/<id>/`), which keeps the door open for
## swapping the look without touching gameplay.

@export var id := ""
@export var name_key := ""
## Longest distance at which the hero still shoots on its own.
@export var attack_range := 460.0
@export var damage := 24.0
@export var attack_interval := 0.62
@export var bullet_speed := 1150.0
@export var move_speed := 330.0
@export var health := 130
@export var bullet_color := Color(0.55, 0.85, 1.0)
## Frost-arrow style slow applied to whatever a bolt hits.
@export var slow_factor := 0.0
@export var slow_time := 0.0
## Arena survivors aim by hand; a lane hero fires at whatever is closest.
@export var auto_attack := true
