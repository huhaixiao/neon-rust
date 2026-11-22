class_name BuffDef
extends Resource
## One selectable module. Percent fields are the delta applied per pick, so a
## buff that says +25% damage literally adds 0.25 to Game.buff_damage_mult.
## Keeping the numbers here (not in the player) means balance is one table.

enum Tag { OFFENSE, DEFENSE, MOBILITY, UTILITY }

@export var id := ""
@export var title := ""
## Shown on the card; keep it short enough for two lines at 12px.
@export var desc := ""
@export var tag: Tag = Tag.OFFENSE
@export var max_stacks := 3

@export var damage_pct := 0.0
@export var fire_rate_pct := 0.0
@export var extra_shots := 0
@export var pierce := 0
@export var health_add := 0
@export var heal_on_kill := 0.0
@export var dash_cd_pct := 0.0
@export var move_pct := 0.0
@export var magnet := 0.0
@export var drop_pct := 0.0
@export var bounty_pct := 0.0


static func make(p_id: String, p_title: String, p_desc: String, p_tag: Tag, p_max: int) -> BuffDef:
	var def := BuffDef.new()
	def.id = p_id
	def.title = p_title
	def.desc = p_desc
	def.tag = p_tag
	def.max_stacks = p_max
	return def


func tag_label() -> String:
	match tag:
		Tag.OFFENSE:
			return "OFFENSE"
		Tag.DEFENSE:
			return "DEFENSE"
		Tag.MOBILITY:
			return "MOBILITY"
		_:
			return "UTILITY"


func tag_color() -> Color:
	match tag:
		Tag.OFFENSE:
			return Color(1.0, 0.56, 0.6)
		Tag.DEFENSE:
			return Color(0.45, 1.0, 0.7)
		Tag.MOBILITY:
			return Color(0.52, 0.84, 1.0)
		_:
			return Color(1.0, 0.82, 0.4)
