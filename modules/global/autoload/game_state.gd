extends Node
## Global run state shared by every system (score, wave, health, scene refs).
## Autoloaded as `Game`.

signal score_changed(value: int)
signal wave_changed(value: int)
signal wave_cleared(wave_index: int, bonus: int)
signal health_changed(current: int, maximum: int)
signal overdrive_changed(active: bool, seconds: float)
signal run_started
signal run_ended(final_score: int, best_score: int)

const SAVE_PATH := "user://neon_rust.cfg"
const ARENA_SIZE := Vector2(1600.0, 1000.0)

var arena := Rect2(Vector2.ZERO, ARENA_SIZE)

var best_score := 0
var score := 0
var wave := 0
var health := 100
var max_health := 100
var running := false

## Screen shake request, consumed and decayed by the camera rig.
var shake := 0.0

# Scene references wired up by main.gd once the level is ready.
var player: Node2D = null
var bullets_root: Node2D = null
var enemies_root: Node2D = null
var pickups_root: Node2D = null
var fx_root: Node2D = null
var spawner: Node = null
var camera: Camera2D = null


func _ready() -> void:
	best_score = _load_best()


func reset_run() -> void:
	score = 0
	wave = 0
	health = max_health
	running = true
	score_changed.emit(score)
	health_changed.emit(health, max_health)
	overdrive_changed.emit(false, 0.0)
	run_started.emit()


## Dropped by the app shell whenever a screen is torn down, so stale references
## to freed nodes never outlive the stage.
func clear_scene_refs() -> void:
	player = null
	bullets_root = null
	enemies_root = null
	pickups_root = null
	fx_root = null
	spawner = null
	camera = null


func add_score(amount: int) -> void:
	if not running or amount == 0:
		return
	score += amount
	score_changed.emit(score)


func set_wave(index: int) -> void:
	wave = index
	wave_changed.emit(index)


func set_health(current: int, maximum: int) -> void:
	health = clampi(current, 0, maximum)
	max_health = maximum
	health_changed.emit(health, maximum)


func is_muted() -> bool:
	return AudioServer.is_bus_mute(0)


func toggle_mute() -> bool:
	var muted := not AudioServer.is_bus_mute(0)
	AudioServer.set_bus_mute(0, muted)
	return muted


func is_fullscreen() -> bool:
	var mode := get_window().mode
	return mode == Window.MODE_FULLSCREEN or mode == Window.MODE_EXCLUSIVE_FULLSCREEN


func toggle_fullscreen() -> bool:
	var window := get_window()
	if is_fullscreen():
		window.mode = Window.MODE_WINDOWED
	else:
		window.mode = Window.MODE_FULLSCREEN
	return is_fullscreen()


func add_shake(amount: float) -> void:
	shake = maxf(shake, amount)


func end_run() -> void:
	if not running:
		return
	running = false
	if score > best_score:
		best_score = score
		_save_best()
	run_ended.emit(score, best_score)


func _load_best() -> int:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		return int(cfg.get_value("scores", "best", 0))
	return 0


func _save_best() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("scores", "best", best_score)
	cfg.save(SAVE_PATH)
