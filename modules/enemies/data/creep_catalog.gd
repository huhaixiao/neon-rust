class_name CreepCatalog
extends RefCounted
## DotA1 lane creeps. Three base units, straight out of the 6.83d tables:
##
##   melee   550 hp / 2 armour / 19-23 damage / 100 range / 1.0s
##   ranged  300 hp / 0 armour / 21-26 damage / 500 range / 1.0s
##   siege   550 hp / 0 armour / 35-46 damage / 690 range / 2.7s
##
## DotA1 upgrades melee and ranged creeps every 7:30 of game time (+10 HP,
## +1/+2 damage). With 30s waves that is one cycle every 15 waves, which is how
## `cycles_for_wave` reads it - no wall clock needed, the wave counter is the
## clock.

const MELEE := "melee"
const RANGED := "ranged"
const SIEGE := "siege"

## DotA1: one upgrade cycle every 7 min 30 s, one wave every 30 s.
const WAVES_PER_CYCLE := 15

static var _cache: Dictionary = {}


static func ids() -> Array[String]:
	var out: Array[String] = [MELEE, RANGED, SIEGE]
	return out


static func cycles_for_wave(wave_index: int) -> int:
	return maxi(0, int((wave_index - 1) / float(WAVES_PER_CYCLE)))


static func get_def(id: String) -> CreepDef:
	if _cache.has(id):
		return _cache[id] as CreepDef
	var def := _build(id)
	_cache[id] = def
	return def


static func _build(id: String) -> CreepDef:
	var def := CreepDef.new()
	def.id = id
	match id:
		MELEE:
			def.name_key = "creep.melee.name"
			def.look = 0
			def.health = 550.0
			def.armor = 2.0
			def.damage_min = 19.0
			def.damage_max = 23.0
			def.attack_range = 100.0
			def.move_speed = 325.0
			def.bounty_gold = 43
			def.bounty_xp = 62
			def.vs_hero_pct = 0.75
			def.radius = 17.0
			def.body_scale = 0.82
			def.color = Color(1.0, 0.25, 0.5)
			def.hp_per_cycle = 10.0
			def.damage_per_cycle = 1.0
		RANGED:
			def.name_key = "creep.ranged.name"
			def.look = 1
			def.health = 300.0
			def.armor = 0.0
			def.damage_min = 21.0
			def.damage_max = 26.0
			def.attack_range = 500.0
			def.move_speed = 325.0
			def.projectile_speed = 900.0
			def.projectile_color = Color(0.75, 1.0, 0.35)
			def.bounty_gold = 48
			def.bounty_xp = 41
			def.vs_hero_pct = 0.5
			def.radius = 16.0
			def.body_scale = 0.72
			def.color = Color(0.75, 1.0, 0.3)
			def.hp_per_cycle = 10.0
			def.damage_per_cycle = 2.0
		SIEGE:
			def.name_key = "creep.siege.name"
			def.look = 2
			def.health = 550.0
			def.armor = 0.0
			def.damage_min = 35.0
			def.damage_max = 46.0
			def.attack_interval = 2.7
			def.attack_range = 690.0
			def.move_speed = 325.0
			def.projectile_speed = 700.0
			def.projectile_color = Color(1.0, 0.7, 0.3)
			def.bounty_gold = 73
			def.bounty_xp = 88
			def.vs_hero_pct = 1.0
			def.radius = 26.0
			def.body_scale = 0.95
			def.color = Color(1.0, 0.55, 0.15)
			# DotA1 siege units do not upgrade over time, only through rax.
			def.hp_per_cycle = 0.0
			def.damage_per_cycle = 0.0
		_:
			def.name_key = "creep.melee.name"
	return def
