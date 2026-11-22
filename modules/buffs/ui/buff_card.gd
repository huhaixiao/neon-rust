class_name BuffCard
extends Button
## One offer card. All copy comes from the BuffDef so the pool table stays the
## single source of truth; this script only formats it.

@onready var tag_label: Label = $Body/Tag
@onready var title_label: Label = $Body/Title
@onready var desc_label: Label = $Body/Desc
@onready var footer_label: Label = $Body/Footer


func setup(def: BuffDef, index: int) -> void:
	var stacks := int(Game.buffs.get(def.id, 0)) + 1
	tag_label.text = "%s    //    %d" % [def.tag_label(), index + 1]
	tag_label.add_theme_color_override("font_color", def.tag_color())
	title_label.text = def.title
	desc_label.text = def.desc
	var note := "    MAX" if stacks >= def.max_stacks else ""
	footer_label.text = "STACK %d / %d%s    [%d]" % [stacks, def.max_stacks, note, index + 1]
