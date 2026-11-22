extends Node
## Verifies the language module: both tables cover every key, the switch
## re-renders the title, HUD, options page and draft cards live, and the
## choice survives a reload of the config file (restored afterwards, so
## running the suite never changes the player's saved language).
##
##   /Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
##       res://tests/l10n_test.tscn

const SAVE_PATH := "user://neon_rust.cfg"

var _failures: Array[String] = []
var _had_language := false
var _saved_language := ""


func _ready() -> void:
	L10n.set_locale("en", false)
	_record_saved_language()
	_run()


func _run() -> void:
	await get_tree().process_frame
	_check_tables()

	# Persistence: flip to zh, reload the file, then put the old value back.
	L10n.set_locale("zh", true)
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		_fail("language change did not write the config")
	elif String(cfg.get_value("settings", "language", "")) != "zh":
		_fail("config did not store the new language")

	# --- title: switch from its own language row --------------------------
	var shell: Node = (load("res://main.tscn") as PackedScene).instantiate()
	add_child(shell)
	await get_tree().process_frame
	var title: TitleScreen = shell.get_node("Title") as TitleScreen
	if title.prompt.text != L10n.t("title.prompt"):
		_fail("title did not render the current language")
	title.lang_button.pressed.emit()
	await get_tree().process_frame
	if L10n.locale != "en":
		_fail("title language row did not cycle the locale")
	if title.prompt.text != ">   PRESS   START":
		_fail("title copy did not switch back to English")
	title.lang_button.pressed.emit()
	await get_tree().process_frame
	if title.prompt.text != ">  按 开始":
		_fail("title copy did not switch to Chinese")

	# --- stage: HUD, pause menu and options follow the switch ------------
	await get_tree().create_timer(0.6).timeout
	await _send_action("restart")
	await get_tree().create_timer(0.3).timeout
	var stage: Node = shell.get_node("Stage")
	if stage == null:
		_fail("stage did not boot for the language test")
		_report()
		return
	var hud := stage.get_node("UI") as GameHud
	if hud.btn_resume.text != "继续":
		_fail("pause list did not localize")
	if not hud.hull_label.text.begins_with("装甲"):
		_fail("hull readout did not localize")
	await _send_action("pause")
	await get_tree().process_frame
	if hud.pause_title.text != "已暂停":
		_fail("pause title did not localize")
	hud.btn_options.pressed.emit()
	await get_tree().process_frame
	if hud.options_title.text != "设置":
		_fail("options title did not localize")
	if not hud.btn_language.text.begins_with("语言"):
		_fail("language row did not localize")
	# One press flips to English; the whole page must follow immediately.
	hud.btn_language.pressed.emit()
	await get_tree().process_frame
	if L10n.locale != "en" or hud.btn_resume.text != "RESUME":
		_fail("options language row did not switch the page to English")
	if not hud.btn_language.text.begins_with("LANGUAGE"):
		_fail("language row did not re-label in English")
	hud.btn_language.pressed.emit()
	await get_tree().process_frame
	if L10n.locale != "zh" or hud.btn_language.text != "语言 中文":
		_fail("second press did not return to Chinese")
	hud.btn_back.pressed.emit()
	hud.btn_resume.pressed.emit()
	await get_tree().process_frame

	# --- draft: header, subtitle, hint and cards -------------------------
	Game.wave_cleared.emit(3, 70)
	await get_tree().process_frame
	await get_tree().process_frame
	var draft := stage.get_node("BuffSelect") as BuffSelect
	if draft.header.text != "第 03 波已清空":
		_fail("draft header did not localize")
	if not draft.sub.text.begins_with("+70 奖励"):
		_fail("draft bonus line did not localize")
	if not draft.hint.text.begins_with("1 / 2 / 3  或"):
		_fail("draft hint did not localize")
	var card_title := (draft.cards_box.get_child(0).get_node("Body/Title") as Label).text
	var known := false
	for def in BuffPool.all():
		if card_title == L10n.t("buff.%s.name" % def.id):
			known = true
	# And the pick still lands in the run state.
	var stacks_before := 0
	for id in Game.buff_order:
		stacks_before += Game.buff_stacks(id)
	(draft.cards_box.get_child(0) as Button).pressed.emit()
	await get_tree().process_frame
	var stacks_after := 0
	for id in Game.buff_order:
		stacks_after += Game.buff_stacks(id)
	if not known:
		_fail("card title was not drawn from the Chinese table")
	if stacks_after != stacks_before + 1:
		_fail("picking a localized card did not grant the buff")
	if get_tree().paused:
		_fail("draft left the tree paused")

	# --- missing keys fall back to English, then to the key -------------
	if L10n.t("does.not.exist") != "does.not.exist":
		_fail("unknown key did not fall back to itself")

	_report()


func _check_tables() -> void:
	var en := L10n.table("en")
	var zh := L10n.table("zh")
	for key in en.keys():
		if not zh.has(key):
			_fail("zh table is missing %s" % key)
			break
	var aim := 0
	for def in BuffPool.all():
		for code in ["en", "zh"]:
			if not L10n.table(code).has("buff.%s.name" % def.id):
				aim += 1
			if not L10n.table(code).has("buff.%s.desc" % def.id):
				aim += 1
	if aim > 0:
		_fail("%d buff strings are missing from the tables" % aim)
	# Placeholders must survive translation: every "%" must match in count.
	for key in en.keys():
		var a := String(en[key]).count("%")
		var b := String(zh.get(key, "")).count("%")
		if a != b:
			_fail("placeholder count differs for %s (en %d / zh %d)" % [key, a, b])
			break


func _record_saved_language() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	_had_language = cfg.has_section_key("settings", "language")
	if _had_language:
		_saved_language = String(cfg.get_value("settings", "language", ""))


func _restore_saved_language() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)
	if _had_language:
		cfg.set_value("settings", "language", _saved_language)
	else:
		cfg.erase_section_key("settings", "language")
	cfg.save(SAVE_PATH)
	if _had_language:
		L10n.set_locale(_saved_language, false)
	else:
		L10n.set_locale("en", false)


func _send_action(action: String) -> void:
	var pressed := InputEventAction.new()
	pressed.action = action
	pressed.pressed = true
	Input.parse_input_event(pressed)
	await get_tree().process_frame
	var released := InputEventAction.new()
	released.action = action
	released.pressed = false
	Input.parse_input_event(released)
	await get_tree().process_frame


func _fail(message: String) -> void:
	_failures.append(message)
	print("FAIL: ", message)


func _report() -> void:
	get_tree().paused = false
	_restore_saved_language()
	if _failures.is_empty():
		print("L10N TEST: PASS")
		get_tree().quit(0)
	else:
		print("L10N TEST: FAIL (", _failures.size(), " checks)")
		get_tree().quit(1)
