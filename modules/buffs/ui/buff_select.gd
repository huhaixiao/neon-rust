class_name BuffSelect
extends CanvasLayer
## Wave-clear draft: three cards, one pick. The stage pauses the tree while
## this is up, so the next wave cannot start until something is chosen.

signal chosen(def: BuffDef)

const CARD_SCENE := preload("res://modules/buffs/ui/buff_card.tscn")

@onready var header: Label = $Root/Header
@onready var sub: Label = $Root/Sub
@onready var cards_box: HBoxContainer = $Root/Cards

var _choices: Array[BuffDef] = []
var _closed := true


func offer(choices: Array[BuffDef], wave: int, bonus: int) -> void:
	_choices = choices
	_closed = false
	header.text = "WAVE %02d CLEARED" % wave
	sub.text = "+%d BONUS    //    PICK ONE MODULE" % bonus
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
