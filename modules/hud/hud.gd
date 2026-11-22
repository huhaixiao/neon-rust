class_name GameHud
extends CanvasLayer
## Heads-up display: hull bar, wave/score, announcements, pause and game over.
## Runs while the tree is paused so overlays keep rendering.

const BAR_WIDTH := 296.0

## Pause menu requests; the stage owns what they actually do.
signal resume_requested
signal restart_requested
signal title_requested

@onready var hull_label: Label = $Root/HullLabel
@onready var health_fill: ColorRect = $Root/HealthBack/HealthFill
@onready var weapon_label: Label = $Root/WeaponLabel
@onready var wave_label: Label = $Root/WaveLabel
@onready var score_label: Label = $Root/ScoreLabel
@onready var best_label: Label = $Root/BestLabel
@onready var banner: Label = $Root/Banner
@onready var banner_sub: Label = $Root/BannerSub
@onready var pause_layer: Control = $Root/PauseLayer
@onready var game_over: Control = $Root/GameOver
@onready var over_score: Label = $Root/GameOver/ScoreValue
@onready var over_best: Label = $Root/GameOver/BestValue
@onready var control_hint: Label = $Root/ControlHint
@onready var pause_hint: Label = $Root/PauseLayer/Panel/PauseHint
@onready var over_hint: Label = $Root/GameOver/Hint
@onready var debug_label: Label = $Root/DebugLabel
@onready var buff_list: Label = $Root/BuffList
@onready var options_layer: Control = $Root/OptionsLayer
@onready var btn_resume: Button = $Root/PauseLayer/Panel/BtnResume
@onready var btn_restart: Button = $Root/PauseLayer/Panel/BtnRestart
@onready var btn_options: Button = $Root/PauseLayer/Panel/BtnOptions
@onready var btn_quit: Button = $Root/PauseLayer/Panel/BtnQuit
@onready var btn_fullscreen: Button = $Root/OptionsLayer/Panel/BtnFullscreen
@onready var btn_sound: Button = $Root/OptionsLayer/Panel/BtnSound
@onready var btn_back: Button = $Root/OptionsLayer/Panel/BtnBack
@onready var btn_redeploy: Button = $Root/GameOver/Actions/BtnRedeploy
@onready var btn_title: Button = $Root/GameOver/Actions/BtnTitle

var _banner_tween: Tween = null
var _pad_mode := false
var _debug_on := false
var _recent_inputs: Array[String] = []


func _ready() -> void:
	Game.score_changed.connect(_on_score)
	Game.health_changed.connect(_on_health)
	Game.wave_changed.connect(_on_wave)
	Game.wave_cleared.connect(_on_wave_cleared)
	Game.buff_changed.connect(_on_buff_changed)
	Game.run_started.connect(_on_run_started)
	Game.run_ended.connect(_on_run_ended)
	_on_score(Game.score)
	_on_health(Game.health, Game.max_health)
	_reset_best()
	game_over.visible = false
	pause_layer.visible = false
	banner.modulate.a = 0.0
	banner_sub.modulate.a = 0.0
	if not Input.joy_connection_changed.is_connected(_on_joypad_changed):
		Input.joy_connection_changed.connect(_on_joypad_changed)
	_refresh_input_copy()
	debug_label.visible = false
	options_layer.visible = false
	_wire_menu()
	_refresh_options()
	_refresh_buffs()


func _process(_delta: float) -> void:
	var player := Game.player as PlayerUnit
	if player == null or player.dead or not Game.running:
		return
	if player.overdrive_left > 0.0:
		weapon_label.text = "OVERDRIVE  %.1fs" % player.overdrive_left
		weapon_label.modulate = Color(1.0, 0.82, 0.35, 1.0)
	elif player.is_dash_ready():
		weapon_label.text = "PULSE  //  DASH READY  [%s]" % _dash_key()
		weapon_label.modulate = Color(0.55, 0.95, 1.0, 1.0)
	else:
		weapon_label.text = "PULSE  //  DASH %.0f%%" % (player.dash_ratio() * 100.0)
		weapon_label.modulate = Color(0.45, 0.72, 0.82, 1.0)
	if _debug_on:
		_update_debug(player)


func toggle_debug() -> void:
	# Only debug builds expose the overlay, so a release build stays clean.
	if not OS.is_debug_build():
		return
	_debug_on = not _debug_on
	debug_label.visible = _debug_on
	if _debug_on:
		_update_debug(Game.player as PlayerUnit)


func note_input(line: String) -> void:
	# Kept even while the overlay is hidden so the first F3/R3 press shows history.
	_recent_inputs.push_front(line)
	if _recent_inputs.size() > 3:
		_recent_inputs.resize(3)
	if _debug_on:
		_update_debug(Game.player as PlayerUnit)


func _update_debug(player: PlayerUnit) -> void:
	var enemies := 0
	var bullets := 0
	if is_instance_valid(Game.enemies_root):
		enemies = Game.enemies_root.get_child_count()
	if is_instance_valid(Game.bullets_root):
		bullets = Game.bullets_root.get_child_count()
	var hull := 0
	var dash := 0.0
	var od := 0.0
	var pos := Vector2.ZERO
	if player != null:
		hull = int(player.health)
		dash = player.dash_ratio() * 100.0
		od = player.overdrive_left
		pos = player.global_position
	debug_label.text = "FPS %d  %.1fms\nWAVE %02d  ENEMY %d  BULLET %d\nHULL %d  DASH %.0f%%  OD %.1fs\nPOS %.0f, %.0f" % [
		Engine.get_frames_per_second(), get_process_delta_time() * 1000.0,
		Game.wave, enemies, bullets,
		hull, dash, od, pos.x, pos.y]
	if not _recent_inputs.is_empty():
		debug_label.text += "\n" + "\n".join(_recent_inputs)


func _wire_menu() -> void:
	btn_resume.pressed.connect(func() -> void: resume_requested.emit())
	btn_restart.pressed.connect(func() -> void: restart_requested.emit())
	btn_options.pressed.connect(show_options)
	btn_quit.pressed.connect(func() -> void: title_requested.emit())
	btn_back.pressed.connect(hide_options)
	btn_fullscreen.pressed.connect(_on_fullscreen_pressed)
	btn_sound.pressed.connect(_on_sound_pressed)
	btn_redeploy.pressed.connect(func() -> void: restart_requested.emit())
	btn_title.pressed.connect(func() -> void: title_requested.emit())


func show_options() -> void:
	# Options replaces the pause list rather than stacking on it, so there is
	# only ever one focused control at a time (pad navigation stays sane).
	pause_layer.visible = false
	options_layer.visible = true
	_clear_focus()
	_refresh_options()
	btn_fullscreen.grab_focus()


func hide_options() -> void:
	options_layer.visible = false
	pause_layer.visible = true
	_clear_focus()
	btn_options.grab_focus()


func _clear_focus() -> void:
	var focused := get_viewport().gui_get_focus_owner()
	if focused != null:
		focused.release_focus()


func _on_fullscreen_pressed() -> void:
	Game.toggle_fullscreen()
	_refresh_options()


func _on_sound_pressed() -> void:
	Game.toggle_mute()
	_refresh_options()


func _refresh_options() -> void:
	btn_fullscreen.text = "FULLSCREEN    %s" % ("ON" if Game.is_fullscreen() else "OFF")
	btn_sound.text = "SOUND    %s" % ("OFF" if Game.is_muted() else "ON")


func _unhandled_input(event: InputEvent) -> void:
	# Esc / START closes the options page; the stage only sees Esc when the
	# pause list itself is on screen.
	if not options_layer.visible:
		return
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		hide_options()


func show_pause(paused: bool) -> void:
	pause_layer.visible = paused
	options_layer.visible = false
	control_hint.visible = not paused and not game_over.visible
	if paused:
		clear_banner()
		btn_resume.grab_focus()


func _dash_key() -> String:
	return "B" if _pad_mode else "SPACE"


func _on_joypad_changed(_device: int, _connected: bool) -> void:
	_refresh_input_copy()


func _refresh_input_copy() -> void:
	_pad_mode = Input.get_connected_joypads().size() > 0
	if _pad_mode:
		control_hint.text = "LSTICK  MOVE     RSTICK  AIM     RT  FIRE     B  DASH"
		pause_hint.text = "DPAD  SELECT     A  CONFIRM     START  RESUME"
		over_hint.text = "A  REDEPLOY        START  TITLE"
	else:
		control_hint.text = "WASD  MOVE     MOUSE  AIM     LMB  FIRE     SPACE  DASH"
		pause_hint.text = "UP / DOWN  SELECT     ENTER  CONFIRM     ESC  RESUME"
		over_hint.text = "R  REDEPLOY        ESC  TITLE"


func _on_score(value: int) -> void:
	score_label.text = "%06d" % value


func _on_health(current: int, maximum: int) -> void:
	var ratio := clampf(float(current) / float(maxi(1, maximum)), 0.0, 1.0)
	health_fill.size = Vector2(BAR_WIDTH * ratio, health_fill.size.y)
	if ratio < 0.3:
		health_fill.color = Color(1.0, 0.28, 0.35, 1.0)
	elif ratio < 0.6:
		health_fill.color = Color(1.0, 0.78, 0.25, 1.0)
	else:
		health_fill.color = Color(0.28, 1.0, 0.62, 1.0)
	hull_label.text = "HULL  %03d" % current


func _on_wave(index: int) -> void:
	wave_label.text = "WAVE %02d" % index
	_announce("WAVE %02d" % index, "INCOMING")


func _on_wave_cleared(index: int, bonus: int) -> void:
	_announce("WAVE %02d CLEARED" % index, "+%d BONUS" % bonus)
	_reset_best()


func clear_banner() -> void:
	if _banner_tween != null and _banner_tween.is_valid():
		_banner_tween.kill()
	banner.modulate.a = 0.0
	banner_sub.modulate.a = 0.0


func announce_buff(def: BuffDef) -> void:
	_announce(def.title, "%s  //  %s" % [def.tag_label(), def.desc])


func _on_buff_changed(_def: BuffDef, _stacks: int) -> void:
	_refresh_buffs()


func _refresh_buffs() -> void:
	var lines: Array[String] = ["MODULES  %02d" % Game.buff_order.size()]
	var by_id := {}
	for def in BuffPool.all():
		by_id[def.id] = def
	var shown := 0
	for id in Game.buff_order:
		if shown >= 4:
			break
		var def: BuffDef = by_id.get(id)
		if def == null:
			continue
		lines.append("%s  x%d" % [def.title, Game.buff_stacks(id)])
		shown += 1
	if Game.buff_order.size() > shown:
		lines.append("+%d MORE" % (Game.buff_order.size() - shown))
	buff_list.text = "\n".join(lines)


func _on_run_started() -> void:
	game_over.visible = false
	pause_layer.visible = false
	_refresh_input_copy()
	control_hint.visible = true
	_reset_best()
	_refresh_buffs()
	_announce("NEON RUST", "SURVIVE THE WAVES")


func _on_run_ended(final_score: int, best: int) -> void:
	over_score.text = "%06d" % final_score
	over_best.text = "BEST  %06d" % best
	best_label.text = "BEST  %06d" % best
	game_over.visible = true
	control_hint.visible = false
	btn_redeploy.grab_focus()
	game_over.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(game_over, "modulate:a", 1.0, 0.35)


func _reset_best() -> void:
	best_label.text = "BEST  %06d" % Game.best_score


func _announce(title: String, subtitle: String) -> void:
	banner.text = title
	banner_sub.text = subtitle
	if _banner_tween != null and _banner_tween.is_valid():
		_banner_tween.kill()
	banner.modulate.a = 0.0
	banner_sub.modulate.a = 0.0
	if not Input.joy_connection_changed.is_connected(_on_joypad_changed):
		Input.joy_connection_changed.connect(_on_joypad_changed)
	_refresh_input_copy()
	_banner_tween = create_tween()
	_banner_tween.set_parallel(true)
	_banner_tween.tween_property(banner, "modulate:a", 1.0, 0.16)
	_banner_tween.tween_property(banner_sub, "modulate:a", 1.0, 0.22)
	_banner_tween.chain().tween_interval(0.85)
	_banner_tween.chain().tween_property(banner, "modulate:a", 0.0, 0.4)
	_banner_tween.parallel().tween_property(banner_sub, "modulate:a", 0.0, 0.4)
