extends Node
## Language service, autoloaded as `L10n`.
##
## The game ships two locales. Copy lives in `modules/l10n/data/strings_*.gd`
## as plain dictionaries instead of Godot's TranslationServer, because every
## other value in this project is defined in code and reviewed in the same diff
## as the UI that shows it.
##
## `t(key)` returns the current locale's string with its `%` placeholders intact;
## the caller fills them (`L10n.t("hud.best") % score`). A missing key falls back
## to English and then to the key itself, so a half-translated build never shows
## an empty label.

signal locale_changed(code: String)

const SAVE_PATH := "user://neon_rust.cfg"
const SUPPORTED := ["en", "zh"]

const EN := preload("res://modules/l10n/data/strings_en.gd")
const ZH := preload("res://modules/l10n/data/strings_zh.gd")

## The engine's built-in font has no CJK glyphs, and `SystemFont` returns an
## empty face on macOS in 4.x, so Chinese UI loads a system font file instead.
## Candidates cover macOS, Windows, SteamOS/Linux; if none exists the UI keeps
## the engine font (English still reads, Chinese would show tofu - no crash).
const FONT_CANDIDATES := [
	"/System/Library/Fonts/Hiragino Sans GB.ttc",
	"/System/Library/Fonts/STHeiti Light.ttc",
	"C:/Windows/Fonts/msyh.ttc",
	"C:/Windows/Fonts/simhei.ttf",
	"/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc",
	"/usr/share/fonts/truetype/noto/NotoSansCJK-Regular.ttc",
	"/usr/share/fonts/noto/NotoSansCJK-Regular.ttc",
	"/usr/share/fonts/truetype/wqy/wqy-microhei.ttc",
]

var locale := "en"

var _zh_theme: Theme = null


func _ready() -> void:
	# First boot follows the OS; after that the player's pick wins.
	var saved := _load_saved()
	locale = saved if SUPPORTED.has(saved) else _system_default()


func t(key: String) -> String:
	var table: Dictionary = ZH.STRINGS if locale == "zh" else EN.STRINGS
	if table.has(key):
		return String(table[key])
	return String(EN.STRINGS.get(key, key))


func set_locale(code: String, persist := true) -> void:
	if not SUPPORTED.has(code):
		return
	var changed := locale != code
	locale = code
	if persist:
		_save()
	if changed:
		locale_changed.emit(code)


## Flips to the next supported language and returns the new code.
func cycle() -> String:
	var next: String = SUPPORTED[(SUPPORTED.find(locale) + 1) % SUPPORTED.size()]
	set_locale(next)
	return locale


## Theme a UI root should use for the current locale (null = engine default).
func ui_theme() -> Theme:
	if locale != "zh":
		return null
	if _zh_theme == null:
		_zh_theme = _build_zh_theme()
	return _zh_theme


func _build_zh_theme() -> Theme:
	var font := FontFile.new()
	for path in FONT_CANDIDATES:
		if not FileAccess.file_exists(path):
			continue
		if font.load_dynamic_font(path) == OK and not font.get_font_name().is_empty():
			break
	if font.get_font_name().is_empty():
		return null
	var theme := Theme.new()
	theme.default_font = font
	theme.default_font_size = 15
	return theme


## Native name of a language, always written in that language.
func language_label(code := "") -> String:
	var target := locale if code.is_empty() else code
	return "中文" if target == "zh" else "ENGLISH"


## Read-only view for tests and tooling.
func table(code: String) -> Dictionary:
	return ZH.STRINGS if code == "zh" else EN.STRINGS


func _system_default() -> String:
	return "zh" if OS.get_locale_language().to_lower() == "zh" else "en"


func _load_saved() -> String:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return ""
	return String(cfg.get_value("settings", "language", ""))


func _save() -> void:
	# Load first so saving a language never wipes the best score.
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)
	cfg.set_value("settings", "language", locale)
	cfg.save(SAVE_PATH)
