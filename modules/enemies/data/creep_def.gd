class_name CreepDef
extends Resource
## One lane creep, in DotA1 numbers. The values here are copied verbatim
## from `modules/heroes/data/dota1/creeps.json`; the scaling that DotA1 applies
## over time (one upgrade cycle every 7:30 of game time) is layered on by
## `CreepCatalog` so the base sheet stays readable.

@export var id := ""
@export var name_key := ""
## Which of the three existing sprite sets to borrow. The art is placeholder;
## only the silhouette differs (small / thin / chunky).
@export var look := 0

@export var health := 550.0
@export var armor := 2.0
@export var damage_min := 19.0
@export var damage_max := 23.0
@export var attack_interval := 1.0
## Distance at which the creep stops and hits. 100 = melee contact range.
@export var attack_range := 100.0
@export var move_speed := 325.0
## Ranged creeps and siege units fire a bolt; melee creeps just touch.
@export var projectile_speed := 0.0
@export var projectile_color := Color(0.55, 1.0, 0.35)

@export var bounty_gold := 43
@export var bounty_xp := 62
@export var radius := 17.0
@export var body_scale := 0.82
@export var color := Color(1.0, 0.25, 0.5)
## DotA1 rewrites creep damage against heroes down to this fraction.
@export var vs_hero_pct := 0.75

## Per-upgrade-cycle growth (DotA1: +10 HP / +1 damage every 7:30).
@export var hp_per_cycle := 10.0
@export var damage_per_cycle := 1.0


func damage_at(cycles: int) -> float:
	return (damage_min + damage_max) * 0.5 + float(cycles) * damage_per_cycle


func health_at(cycles: int) -> float:
	return health + float(cycles) * hp_per_cycle
