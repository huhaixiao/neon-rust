class_name DotaPanel
extends Control
## The bottom bar, DotA1 style: hero portrait on the left, HP / XP bars beside
## it, gold and level under the name, six item slots and three passive skill
## buttons on the right. Read-only - the shop and the skill picker are the
## hero's own `HeroProgress`, the player never clicks anything here.
##
## Painting is `_draw`, text is a handful of Labels on top: cheap, and it scales
## with the HUD's theme (which is how the CJK font gets in).

const BAR_H := 92.0
const SLOT := 30.0
const SKILL_SIZE := 34.0

var _p: PlayerUnit = null
var _name: Label
var _level: Label
var _gold: Label
var _hp_text: Label
var _xp_text: Label
var _hint: Label
var _item_labels: Array[Label] = []
var _skill_labels: Array[Label] = []
var _dirty := true


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_name = _make_label(15)
	_level = _make_label(15)
	_gold = _make_label(18)
	_hp_text = _make_label(12)
	_xp_text = _make_label(12)
	for i in 6:
		_item_labels.append(_make_label(10))
	for i in 3:
		_skill_labels.append(_make_label(10))
	_dirty = true


func _make_label(font_size: int) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label


func _process(_delta: float) -> void:
	if not is_instance_valid(_p) or _p.dead:
		_p = Game.player as PlayerUnit
	queue_redraw()
	_layout()
	_paint_text()


func _panel_size() -> Vector2:
	# The control is laid out full-rect, but during the first frame (or in a
	# headless run) the parent may still report zero - fall back to the viewport
	# so the bar always paints.
	var s := size
	if s.x < 2.0 or s.y < 2.0:
		s = get_viewport_rect().size
	return s


func _bar_top() -> float:
	return _panel_size().y - BAR_H


func _layout() -> void:
	if _p == null:
		_name.text = ""
		return
	var top := _bar_top()
	_name.position = Vector2(100.0, top + 8.0)
	_name.text = L10n.t("hero.%s.name" % _p.hero_id)
	_level.position = Vector2(100.0, top + 26.0)
	_level.text = L10n.t("hud.level") % _p.progress.level if _p.progress != null else ""
	_gold.position = Vector2(120.0, top + 66.0)
	_hp_text.position = Vector2(408.0, top + 38.0)
	_xp_text.position = Vector2(408.0, top + 56.0)
	# Portrait sits left of the text block.
	for i in _item_labels.size():
		_item_labels[i].position = Vector2(700.0 + float(i) * (SLOT + 6.0) + 2.0, top + 40.0)
	for i in _skill_labels.size():
		_skill_labels[i].position = Vector2(960.0 + float(i) * (SKILL_SIZE + 8.0) + 2.0, top + 40.0)


func _paint_text() -> void:
	if _p == null or _p.progress == null:
		return
	var prog := _p.progress
	_gold.text = "%d" % prog.gold
	_hp_text.text = "%d / %d" % [int(_p.health), _p.max_health]
	_xp_text.text = "XP %d / %d" % [prog.xp, prog.xp_needed()] if prog.level < HeroProgress.MAX_LEVEL else "XP MAX"
	# Items: first letter of the English name doubles as the icon glyph, and
	# the slot background tells you it is filled.
	for i in _item_labels.size():
		if i < prog.items.size():
			var def := HeroProgress.item_by_id(prog.items[i])
			_item_labels[i].text = String(def.get("name_en", "?")).substr(0, 1)
		else:
			_item_labels[i].text = ""
	for i in _skill_labels.size():
		var def: Dictionary = HeroProgress.SKILLS[i]
		var have := prog.skill_level(String(def.id))
		_skill_labels[i].text = "%d" % have if have > 0 else "-"


func _draw() -> void:
	var top := _bar_top()
	var w := _panel_size().x
	# Stone bar.
	draw_rect(Rect2(Vector2(0.0, top), Vector2(w, BAR_H)), Color(0.12, 0.10, 0.08, 0.96))
	draw_rect(Rect2(Vector2(0.0, top), Vector2(w, 3.0)), Color(0.55, 0.44, 0.24))
	draw_rect(Rect2(Vector2(0.0, top + 3.0), Vector2(w, 1.0)), Color(0.32, 0.26, 0.16))
	if _p == null:
		return
	var prog := _p.progress
	# --- portrait ---------------------------------------------------------
	var portrait := Rect2(Vector2(16.0, top + 10.0), Vector2(72.0, 72.0))
	draw_rect(portrait.grow(3.0), Color(0.30, 0.24, 0.14))
	draw_rect(portrait, Color(0.17, 0.23, 0.17))
	_paint_portrait(portrait)
	# --- bars -------------------------------------------------------------
	var bar_x := 100.0
	var hp_rect := Rect2(Vector2(bar_x, top + 38.0), Vector2(300.0, 16.0))
	draw_rect(hp_rect.grow(1.0), Color(0.05, 0.05, 0.05))
	var hp_ratio := clampf(float(_p.health) / float(maxi(1, _p.max_health)), 0.0, 1.0)
	draw_rect(Rect2(hp_rect.position, Vector2(hp_rect.size.x * hp_ratio, hp_rect.size.y)),
		Color(0.30, 0.72, 0.26) if hp_ratio > 0.35 else Color(0.78, 0.24, 0.20))
	draw_rect(hp_rect, Color(0.42, 0.52, 0.34, 1.0), false, 1.0)
	# XP bar: the blue strip a DotA1 player watches between last hits.
	var xp_rect := Rect2(Vector2(bar_x, top + 58.0), Vector2(300.0, 9.0))
	draw_rect(xp_rect, Color(0.06, 0.09, 0.14))
	if prog != null:
		draw_rect(Rect2(xp_rect.position, Vector2(xp_rect.size.x * prog.xp_ratio(), xp_rect.size.y)),
			Color(0.34, 0.55, 0.86))
	draw_rect(xp_rect, Color(0.24, 0.36, 0.56), false, 1.0)
	# --- gold -------------------------------------------------------------
	draw_circle(Vector2(108.0, top + 76.0), 6.0, Color(0.86, 0.72, 0.28))
	draw_circle(Vector2(108.0, top + 76.0), 3.0, Color(0.62, 0.48, 0.14))
	# --- items ------------------------------------------------------------
	for i in 6:
		var slot := Rect2(Vector2(700.0 + float(i) * (SLOT + 6.0), top + 36.0), Vector2(SLOT, SLOT))
		draw_rect(slot, Color(0.09, 0.08, 0.07))
		draw_rect(slot, Color(0.34, 0.28, 0.16), false, 1.0)
		if prog != null and i < prog.items.size():
			draw_rect(slot.grow(-3.0), _item_color(prog.items[i]))
	# --- skills -----------------------------------------------------------
	for i in 3:
		var box := Rect2(Vector2(960.0 + float(i) * (SKILL_SIZE + 8.0), top + 36.0), Vector2(SKILL_SIZE, SKILL_SIZE))
		var have := 0
		if prog != null:
			have = prog.skill_level(String(HeroProgress.SKILLS[i].id))
		draw_rect(box, Color(0.10, 0.11, 0.14) if have > 0 else Color(0.07, 0.07, 0.08))
		draw_rect(box, Color(0.36, 0.34, 0.22) if have > 0 else Color(0.20, 0.18, 0.14), false, 1.0)
		_skill_glyph(i, box.get_center(), have > 0)
		# Level pips under the icon.
		for pip in 4:
			var pip_rect := Rect2(Vector2(box.position.x + 3.0 + float(pip) * 7.5, box.end.y + 3.0), Vector2(5.0, 5.0))
			draw_rect(pip_rect, Color(0.85, 0.78, 0.30) if pip < have else Color(0.22, 0.20, 0.16))
	# --- labels for the active item names ---------------------------------
	if prog != null and not prog.items.is_empty():
		var last_id: String = prog.items[prog.items.size() - 1]
		var def := HeroProgress.item_by_id(last_id)
		var text := HeroProgress.label(def)
		var font := get_theme_default_font()
		var font_size := 12
		draw_string(font, Vector2(700.0, top + 26.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size,
			Color(0.86, 0.80, 0.58))


func _paint_portrait(rect: Rect2) -> void:
	# Mini archer: hood, face, bow. Same silhouette as the unit, quarter scale.
	var c := rect.get_center() + Vector2(-2.0, 4.0)
	draw_colored_polygon(PackedVector2Array([
		c + Vector2(-11.0, -9.0), c + Vector2(7.0, -11.0), c + Vector2(11.0, 2.0),
		c + Vector2(7.0, 16.0), c + Vector2(-11.0, 15.0)
	]), Color(0.16, 0.30, 0.22))
	draw_circle(c + Vector2(2.0, -12.0), 8.0, Color(0.16, 0.30, 0.22))
	draw_circle(c + Vector2(5.0, -12.0), 5.5, Color(0.80, 0.66, 0.50))
	draw_circle(c + Vector2(7.0, -12.0), 1.4, Color(0.12, 0.12, 0.12))
	draw_arc(c + Vector2(14.0, 2.0), 13.0, -1.2, 1.2, 16, Color(0.44, 0.30, 0.16), 2.5, true)


func _skill_glyph(index: int, centre: Vector2, lit: bool) -> void:
	var ink := Color(0.86, 0.92, 0.95) if lit else Color(0.34, 0.36, 0.36)
	match index:
		0:  # Frost Arrows: a chevron pointing up-right.
			draw_line(centre + Vector2(-7.0, 7.0), centre + Vector2(7.0, -7.0), ink, 2.0)
			draw_line(centre + Vector2(7.0, -7.0), centre + Vector2(1.0, -6.0), ink, 2.0)
			draw_line(centre + Vector2(7.0, -7.0), centre + Vector2(6.0, -1.0), ink, 2.0)
		1:  # Precision Aura: a four-point star.
			for dir in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
				draw_line(centre, centre + dir * 8.0, ink, 1.6)
			draw_circle(centre, 1.6, ink)
		_:  # Marksmanship: an eye.
			draw_arc(centre, 8.0, 0.0, TAU, 18, ink, 1.6, true)
			draw_circle(centre, 3.2, ink)


func _item_color(id: String) -> Color:
	match id:
		"slippers", "boots", "gloves":
			return Color(0.36, 0.46, 0.32)
		"blades", "quarterstaff", "mithril", "buriza":
			return Color(0.44, 0.38, 0.26)
		"chainmail", "platemail":
			return Color(0.34, 0.38, 0.44)
		"crystalys", "butterfly":
			return Color(0.36, 0.40, 0.52)
		"orb", "satanic":
			return Color(0.44, 0.28, 0.40)
		_:
			return Color(0.30, 0.30, 0.30)
