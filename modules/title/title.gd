class_name TitleScreen
extends Node2D
## Front door of the game: shows the logo, the saved best score and the
## controls, then waits for one deliberate press before the arena boots.
## Instantiated by main.gd, the app shell.
##
## The small LANGUAGE row in the top-left is the only setting reachable before
## a run; the full options page lives in the pause menu.

signal start_requested
signal quit_requested

## Keys are ignored for a moment after the screen appears, so the press that
## ended the previous run cannot skip straight past the title.
const ARM_DELAY := 0.35
const BLINK_SPEED := 3.2

@onready var ui: Control = $UI/Root
@onready var meta: Label = $UI/Root/Meta
@onready var best_value: Label = $UI/Root/BestValue
@onready var subtitle: Label = $UI/Root/Subtitle
@onready var prompt: Label = $UI/Root/Prompt
@onready var prompt_hint: Label = $UI/Root/PromptHint
@onready var keyboard_hint: Label = $UI/Root/KeyboardHint
@onready var pad_hint: Label = $UI/Root/PadHint
@onready var pad_hint_label: Label = $UI/Root/PadHintLabel
@onready var quit_hint: Label = $UI/Root/QuitHint
@onready var lang_button: Button = $UI/Root/LangButton

var _time := 0.0
var _armed := false
var _closed := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	L10n.locale_changed.connect(_on_locale_changed)
	lang_button.pressed.connect(_on_language_pressed)
	var has_pad := not Input.get_connected_joypads().is_empty()
	pad_hint.visible = has_pad
	pad_hint_label.visible = has_pad
	_refresh_text()
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


func _refresh_text() -> void:
	ui.theme = L10n.ui_theme()
	meta.text = L10n.t("title.meta")
	best_value.text = L10n.t("title.best") % Game.best_score
	subtitle.text = L10n.t("title.subtitle")
	prompt.text = L10n.t("title.prompt")
	prompt_hint.text = L10n.t("title.prompt_hint")
	keyboard_hint.text = L10n.t("title.keys.kb")
	pad_hint_label.text = L10n.t("title.keys.pad")
	pad_hint.text = L10n.t("title.pad")
	quit_hint.text = L10n.t("title.quit")
	lang_button.text = L10n.t("title.language") % L10n.language_label()


func _on_locale_changed(_code: String) -> void:
	_refresh_text()


func _on_language_pressed() -> void:
	L10n.cycle()


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
