class_name HeroCatalog
extends RefCounted
## Hero roster. One entry for now: 小黑, the long-range frost archer that
## defines the lane phase. Adding a hero means adding one branch here and one
## set of l10n keys - nothing else in the game needs to know about it.

const DROW := "drow"

static var _cache: Dictionary = {}


static func ids() -> Array[String]:
	var out: Array[String] = [DROW]
	return out


static func get_def(id: String) -> HeroDef:
	if _cache.has(id):
		return _cache[id] as HeroDef
	var def := _build(id)
	_cache[id] = def
	return def


static func _build(id: String) -> HeroDef:
	var def := HeroDef.new()
	match id:
		DROW:
			def.id = DROW
			def.name_key = "hero.drow.name"
			# DotA1 6.7x sheet, verbatim: 473 HP, 44-55 damage, 1.7 BAT,
			# 625 range, 300 move speed, 1 armour, Frost Arrows 45%/1.5s.
			def.attack_range = 625.0
			def.damage = 49.5
			def.damage_min = 44.0
			def.damage_max = 55.0
			def.attack_interval = 1.7
			def.bullet_speed = 1250.0
			def.move_speed = 300.0
			def.health = 473
			def.armor = 1.0
			def.bullet_color = Color(0.62, 0.9, 1.0)
			def.slow_factor = 0.45
			def.slow_time = 1.5
			def.auto_attack = true
		_:
			def.id = "unknown"
			def.name_key = "hero.unknown.name"
	return def
