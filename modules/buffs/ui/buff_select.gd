class_name BuffSelect
extends CanvasLayer
## Wave-clear draft: three cards, one pick. The stage pauses the tree while
## this is up, so the next wave cannot start until something is chosen.

signal chosen(def: BuffDef)

const CARD_SCENE := preload("res://modules/buffs/ui/buff_card.tscn")

@onready var root: Control = $Root
@onready var header: Label = $Root/Header
@onready var sub: Label = $Root/Sub
@onready var hint: Label = $Root/Hint
@onready var cards_box: HBoxContainer = $Root/Cards

var _choices: Array[BuffDef] = []
var _closed := true
var _wave := 0
var _bonus := 0


func _ready() -> void:
	L10n.locale_changed.connect(_on_locale_changed)


func offer(choices: Array[BuffDef], wave: int, bonus: int) -> void:
	_choices = choices
	_wave = wave
	_bonus = bonus
	_closed = false
	_refresh_copy()
	for child in cards_box.get_children():
		cards_box.remove_child(child)
		child.queue_free()
	for i in choices.size():
		var card := CARD_SCENE.instantiate() as BuffCard
		cards_box.add_child(card)
		card.setup(choices[i], i)
		card.pressed.connect(_on_card_pressed.bind(i))
	visible = true
	# One frame so the buttons have a size before focus is grabbed.
	await get_tree().process_frame
	var first := cards_box.get_child(0) as Button
	if first != null:
		first.grab_focus()


## Re-renders the copy and the open cards after a language switch.
func _refresh_copy() -> void:
	root.theme = L10n.ui_theme()
	header.text = L10n.t("draft.header") % _wave
	sub.text = L10n.t("draft.sub") % _bonus
	hint.text = L10n.t("draft.hint")


func _on_locale_changed(_code: String) -> void:
	if not visible:
		return
	_refresh_copy()
	for i in _choices.size():
		var card := cards_box.get_child(i) as BuffCard
		if card != null:
			card.setup(_choices[i], i)


func _on_card_pressed(index: int) -> void:
	_pick(index)


func _pick(index: int) -> void:
	if _closed or index < 0 or index >= _choices.size():
		return
	_closed = true
	visible = false
	chosen.emit(_choices[index])


func _unhandled_input(event: InputEvent) -> void:
	if _closed or not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var key := event as InputEventKey
		match key.physical_keycode:
			KEY_1:
				get_viewport().set_input_as_handled()
				_pick(0)
			KEY_2:
				get_viewport().set_input_as_handled()
				_pick(1)
			KEY_3:
				get_viewport().set_input_as_handled()
				_pick(2)
