class_name TitleScreen
extends Node2D
## Front door of the game: shows the logo, the saved best score and the
## controls, then waits for one deliberate press before the arena boots.
## Instantiated by main.gd, the app shell.

signal start_requested
signal quit_requested

## Keys are ignored for a moment after the screen appears, so the press that
## ended the previous run cannot skip straight past the title.
const ARM_DELAY := 0.35
const BLINK_SPEED := 3.2

@onready var ui: Control = $UI/Root
@onready var prompt: Label = $UI/Root/Prompt
@onready var best_value: Label = $UI/Root/BestValue
@onready var pad_hint: Label = $UI/Root/PadHint
@onready var pad_hint_label: Label = $UI/Root/PadHintLabel

var _time := 0.0
var _armed := false
var _closed := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	best_value.text = "BEST  %06d" % Game.best_score
	var has_pad := not Input.get_connected_joypads().is_empty()
	pad_hint.visible = has_pad
	pad_hint_label.visible = has_pad
	ui.modulate.a = 0.0
	create_tween().tween_property(ui, "modulate:a", 1.0, 0.3)
	await get_tree().create_timer(ARM_DELAY).timeout
	_armed = true


func _process(delta: float) -> void:
	_time += delta
	# Slow breathing on the call to action - enough motion to read as "live",
	# quiet enough that it does not flicker on a handheld screen.
	prompt.modulate.a = 0.55 + 0.45 * sin(_time * BLINK_SPEED)
	if not _armed or _closed:
		return
	if Input.is_action_just_pressed("restart") or Input.is_action_just_pressed("ui_accept"):
		request_start()
	elif Input.is_action_just_pressed("pause"):
		request_quit()


func _unhandled_input(event: InputEvent) -> void:
	if not _armed or _closed:
		return
	if event is InputEventMouseButton:
		var click := event as InputEventMouseButton
		if click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
			get_viewport().set_input_as_handled()
			request_start()
			return
	# Action events reach here when a test drives the screen with
	# Input.parse_input_event; real keys/mouse/pad take the paths above.
	if event.is_action_pressed("restart") or event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		request_start()
	elif event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		request_quit()


func request_start() -> void:
	if _closed:
		return
	_closed = true
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	start_requested.emit()


func request_quit() -> void:
	if _closed:
		return
	_closed = true
	quit_requested.emit()
