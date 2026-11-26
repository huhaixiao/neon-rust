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
## DotA1 heroes roll their damage out of a min/max window; `damage` stays the
## average so anything that only needs one number keeps working.
@export var damage_min := 0.0
@export var damage_max := 0.0
@export var attack_interval := 0.62
@export var bullet_speed := 1150.0
@export var move_speed := 330.0
@export var health := 130
## Positive armour soaks incoming damage (DotA1 6.x formula).
@export var armor := 0.0
## HP per second, straight from the hero sheet. Without it every point of chip
## damage is permanent and a lane run can only ever end in a slow bleed-out.
@export var hp_regen := 0.0
@export var bullet_color := Color(0.55, 0.85, 1.0)
## Frost-arrow style slow applied to whatever a bolt hits.
@export var slow_factor := 0.0
@export var slow_time := 0.0
## Arena survivors aim by hand; a lane hero fires at whatever is closest.
@export var auto_attack := true
