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
			# Long range and a frost arrow: she clears a lane from behind it
			# rather than standing in it.
			def.attack_range = 470.0
			def.damage = 26.0
			def.attack_interval = 0.58
			def.bullet_speed = 1200.0
			def.move_speed = 330.0
			def.health = 140
			def.bullet_color = Color(0.62, 0.9, 1.0)
			def.slow_factor = 0.4
			def.slow_time = 1.4
			def.auto_attack = true
		_:
			def.id = "unknown"
			def.name_key = "hero.unknown.name"
	return def
