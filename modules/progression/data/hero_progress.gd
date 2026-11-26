class_name HeroProgress
extends RefCounted
## DotA1-style hero growth, hands-off: killing creeps pays gold and XP, the gold
## spends itself on the cheapest item still missing, and every level spends its
## point on the passive that is currently lowest. The player never opens a shop.
##
## The numbers follow the DotA1 reference in `modules/heroes/data/dota1/`:
##   - XP to next level: the standard 200 / 200 / 240 / 320 ... ladder
##   - creep bounty: 43 melee / 48 ranged / 73 siege, XP 62 / 41 / 88
##   - items keep their DotA1 names and prices, stats are folded to the handful
##     this build actually has (flat damage, attack speed, armour, HP, move)

signal changed
signal leveled_up(level: int)
signal item_purchased(item_id: String)
signal skill_leveled(skill_id: String, level: int)

const START_GOLD := 603
const MAX_LEVEL := 25
## XP required to go from level N to N+1, indexed from level 1.
const XP_TABLE: Array = [
	200, 200, 240, 320, 400, 480, 560, 640, 720,
	810, 900, 990, 1080, 1170, 1260, 1350,
	1440, 1530, 1620, 1710, 1800, 1890, 1980, 2070,
]

## Cheapest-first, so "auto buy" is just "walk the list and take what is
## affordable". Every entry maps to the four stats the hero actually has.
const ITEMS: Array = [
	{"id": "slippers", "name_zh": "敏捷便鞋", "name_en": "Slippers of Agility",
		"cost": 450, "damage": 3.0, "attack_speed": 0.03},
	{"id": "boots", "name_zh": "速度之靴", "name_en": "Boots of Speed",
		"cost": 500, "move": 50.0},
	{"id": "gloves", "name_zh": "急速手套", "name_en": "Gloves of Haste",
		"cost": 500, "attack_speed": 0.15},
	{"id": "blades", "name_zh": "攻击之爪", "name_en": "Blades of Attack",
		"cost": 500, "damage": 9.0},
	{"id": "chainmail", "name_zh": "锁子甲", "name_en": "Chainmail",
		"cost": 550, "armor": 5.0},
	{"id": "quarterstaff", "name_zh": "短棍", "name_en": "Quarterstaff",
		"cost": 900, "damage": 10.0},
	{"id": "platemail", "name_zh": "板甲", "name_en": "Plate Mail",
		"cost": 1400, "armor": 10.0},
	{"id": "mithril", "name_zh": "秘银锤", "name_en": "Mithril Hammer",
		"cost": 1600, "damage": 24.0},
	{"id": "orb", "name_zh": "精气之球", "name_en": "Ultimate Orb",
		"cost": 2100, "damage": 10.0, "health": 100.0, "armor": 2.0},
	{"id": "crystalys", "name_zh": "水晶剑", "name_en": "Crystalys",
		"cost": 2150, "damage": 35.0, "attack_speed": 0.12},
	{"id": "buriza", "name_zh": "大炮", "name_en": "Buriza-do Kyanon",
		"cost": 5150, "damage": 75.0},
	{"id": "butterfly", "name_zh": "蝴蝶", "name_en": "Butterfly",
		"cost": 6000, "damage": 30.0, "attack_speed": 0.30, "armor": 3.0},
	{"id": "satanic", "name_zh": "撒旦之邪力", "name_en": "Satanic",
		"cost": 6150, "damage": 50.0, "health": 300.0},
]

## Three passives, four levels each - the DotA1 Drow Ranger kit folded into the
## only verbs this game has (shoot an arrow, tank a creep, kite).
const SKILLS: Array = [
	{"id": "frost_arrows", "name_zh": "冰霜箭", "name_en": "Frost Arrows",
		"max": 4, "desc_zh": "每级 +15% 减速", "desc_en": "+15% slow per level",
		"slow": 0.15},
	{"id": "precision", "name_zh": "精准光环", "name_en": "Precision Aura",
		"max": 4, "desc_zh": "每级 +8% 伤害", "desc_en": "+8% damage per level",
		"damage_pct": 0.08},
	{"id": "marksmanship", "name_zh": "射手天赋", "name_en": "Marksmanship",
		"max": 4, "desc_zh": "每级 +1 护甲 / +4% 攻速", "desc_en": "+1 armour / +4% IAS per level",
		"armor": 1.0, "attack_speed": 0.04},
]

var level := 1
var xp := 0
var gold := START_GOLD
var items: Array[String] = []
var skills: Dictionary = {}          # skill id -> level
var _points_unspent := 0


func _init() -> void:
	for def in SKILLS:
		skills[def.id] = 0
	# DotA1 starts you with 603 gold and the internal shop spends it before the
	# first wave: a run opens with Slippers on, not with an empty bag.
	_buy_what_fits()


## --- gains ---------------------------------------------------------------

func add_kill(bounty_gold: int, bounty_xp: int) -> void:
	var before_level := level
	gold += int(round(float(bounty_gold) * Game.buff_bounty_mult))
	xp += bounty_xp
	_absorb_xp()
	_buy_what_fits()
	if level != before_level:
		leveled_up.emit(level)
	changed.emit()


func xp_needed() -> int:
	if level >= MAX_LEVEL:
		return 0
	return int(XP_TABLE[mini(level - 1, XP_TABLE.size() - 1)])


func xp_ratio() -> float:
	var need := xp_needed()
	if need <= 0:
		return 1.0
	return clampf(float(xp) / float(need), 0.0, 1.0)


## --- internals -----------------------------------------------------------

func _absorb_xp() -> void:
	while level < MAX_LEVEL:
		var need := xp_needed()
		if need <= 0 or xp < need:
			break
		xp -= need
		level += 1
		_points_unspent += 1
		_spend_points()
	if level >= MAX_LEVEL:
		xp = 0


func _spend_points() -> void:
	# One point per level, always into the passive with the lowest level, left
	# to right on a tie - deterministic, so a run's skill order never drifts.
	while _points_unspent > 0:
		var pick := ""
		var pick_level := 99
		for def in SKILLS:
			var have: int = skills[def.id]
			if have >= int(def.max):
				continue
			if have < pick_level:
				pick_level = have
				pick = def.id
		if pick == "":
			_points_unspent = 0
			return
		skills[pick] = int(skills[pick]) + 1
		_points_unspent -= 1
		skill_leveled.emit(pick, int(skills[pick]))


func _buy_what_fits() -> void:
	# Loop, because one kill can fund two cheap items at once.
	var bought := true
	while bought:
		bought = false
		for def in ITEMS:
			var id := String(def.id)
			if items.has(id):
				continue
			if gold < int(def.cost):
				continue
			gold -= int(def.cost)
			items.append(id)
			item_purchased.emit(id)
			bought = true
			break


## --- read-out ------------------------------------------------------------

func skill_level(skill_id: String) -> int:
	return int(skills.get(skill_id, 0))


## Everything the player unit needs to fold onto its base hero sheet.
func bonus() -> Dictionary:
	var out := {
		"damage": 0.0, "damage_pct": 0.0, "attack_speed": 0.0,
		"armor": 0.0, "health": 0.0, "move": 0.0, "slow": 0.0,
	}
	for id in items:
		var def := _find(ITEMS, id)
		if def.is_empty():
			continue
		out.damage += float(def.get("damage", 0.0))
		out.attack_speed += float(def.get("attack_speed", 0.0))
		out.armor += float(def.get("armor", 0.0))
		out.health += float(def.get("health", 0.0))
		out.move += float(def.get("move", 0.0))
	for def in SKILLS:
		var have := skill_level(String(def.id))
		if have <= 0:
			continue
		for field in ["damage_pct", "attack_speed", "armor", "slow"]:
			out[field] = float(out[field]) + float(def.get(field, 0.0)) * float(have)
	return out


func _find(table: Array, id: String) -> Dictionary:
	for def in table:
		if String(def.get("id", "")) == id:
			return def
	return {}


static func item_by_id(id: String) -> Dictionary:
	for def in ITEMS:
		if String(def.get("id", "")) == id:
			return def
	return {}


static func skill_by_id(id: String) -> Dictionary:
	for def in SKILLS:
		if String(def.get("id", "")) == id:
			return def
	return {}


## Bilingual labels live next to the numbers so a new item is one row, not a
## row plus two l10n files.
static func label(def: Dictionary) -> String:
	return String(def.get("name_zh", "") if L10n.locale == "zh" else def.get("name_en", ""))


static func describe(def: Dictionary) -> String:
	if def.has("desc_zh"):
		return String(def.get("desc_zh", "") if L10n.locale == "zh" else def.get("desc_en", ""))
	return ""
