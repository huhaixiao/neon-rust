extends Node
## Global run state shared by every system (score, wave, health, scene refs).
## Autoloaded as `Game`.

signal score_changed(value: int)
signal wave_changed(value: int)
signal wave_cleared(wave_index: int, bonus: int)
signal health_changed(current: int, maximum: int)
signal tree_health_changed(current: int, maximum: int)
signal overdrive_changed(active: bool, seconds: float)
signal run_started
signal run_ended(final_score: int, best_score: int)

## Buffs picked between waves. `Game` owns the aggregate so nothing else has to
## know which module contributed what.
signal buff_changed(def: BuffDef, stacks: int)
signal enemy_killed(kind: int, at: Vector2)

const SAVE_PATH := "user://neon_rust.cfg"
const ARENA_SIZE := Vector2(1600.0, 1000.0)

var arena := Rect2(Vector2.ZERO, ARENA_SIZE)

var best_score := 0
var score := 0
var wave := 0
var health := 100
var max_health := 100
## The World Tree is the actual lose condition in lane mode. The hero going
## down still ends the run, but leaking waves is what grinds you out.
## 4250 HP / 15 armour: the DotA1 ancient, straight out of the reference sheet.
var tree_health := 4250
var max_tree_health := 4250
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
var tree: Node2D = null

# --- run buffs -------------------------------------------------------------
var buffs: Dictionary = {}          # id -> stacks
var buff_order: Array[String] = []  # acquisition order, for the HUD list
var buff_damage_mult := 1.0
var buff_fire_rate_mult := 1.0
var buff_extra_shots := 0
var buff_pierce := 0
var buff_heal_on_kill := 0.0
var buff_dash_cd_mult := 1.0
var buff_move_mult := 1.0
var buff_magnet := 0.0
var buff_drop_mult := 1.0
var buff_bounty_mult := 1.0
var buff_lifesteal := 0.0
var buff_auto_attack := 0
var buff_special_damage_mult := 1.0
var buff_special_cd_mult := 1.0
var buff_special_radius_mult := 1.0


func _ready() -> void:
	best_score = _load_best()


func reset_run() -> void:
	_reset_buffs()
	score = 0
	wave = 0
	health = max_health
	tree_health = max_tree_health
	running = true
	score_changed.emit(score)
	health_changed.emit(health, max_health)
	tree_health_changed.emit(tree_health, max_tree_health)
	overdrive_changed.emit(false, 0.0)
	run_started.emit()


## Chipped by a creep that walked the lane. Reaching zero loses the run: the
## tree is what the player is actually defending.
func damage_tree(amount: int) -> void:
	if not running or amount <= 0:
		return
	tree_health = maxi(0, tree_health - amount)
	tree_health_changed.emit(tree_health, max_tree_health)
	if is_instance_valid(tree):
		tree.on_hit()
	add_shake(0.5)
	if tree_health <= 0:
		end_run()


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
	tree = null


func roll_buffs(count: int) -> Array[BuffDef]:
	var picked: Array[BuffDef] = []
	var eligible: Array[BuffDef] = []
	for def in BuffPool.all():
		if buff_stacks(def.id) < def.max_stacks:
			eligible.append(def)
	if eligible.is_empty():
		return picked
	# First pass: one per category, so the three cards always read as a choice.
	var by_tag := {}
	for def in eligible:
		if not by_tag.has(def.tag):
			by_tag[def.tag] = []
		(by_tag[def.tag] as Array).append(def)
	var tags := by_tag.keys()
	tags.shuffle()
	for t in tags:
		if picked.size() >= count:
			break
		var group: Array = by_tag[t]
		group.shuffle()
		if not group.is_empty():
			picked.append(group.pop_back())
	# Second pass: fill leftovers randomly.
	var rest: Array[BuffDef] = []
	for def in eligible:
		if not picked.has(def):
			rest.append(def)
	rest.shuffle()
	while picked.size() < count and not rest.is_empty():
		picked.append(rest.pop_back())
	picked.sort_custom(func(a: BuffDef, b: BuffDef) -> bool: return a.tag < b.tag)
	return picked


func buff_stacks(buff_id: String) -> int:
	return int(buffs.get(buff_id, 0))


func add_buff(def: BuffDef) -> bool:
	if def == null:
		return false
	var stacks := buff_stacks(def.id)
	if stacks >= def.max_stacks:
		return false
	buffs[def.id] = stacks + 1
	if not buff_order.has(def.id):
		buff_order.append(def.id)
	buff_damage_mult += def.damage_pct
	buff_fire_rate_mult += def.fire_rate_pct
	buff_extra_shots += def.extra_shots
	buff_pierce += def.pierce
	buff_heal_on_kill += def.heal_on_kill
	buff_dash_cd_mult = maxf(0.35, buff_dash_cd_mult - def.dash_cd_pct)
	buff_move_mult += def.move_pct
	buff_magnet += def.magnet
	buff_drop_mult += def.drop_pct
	buff_bounty_mult += def.bounty_pct
	buff_lifesteal += def.lifesteal_pct
	buff_auto_attack += def.auto_attack
	buff_special_damage_mult += def.special_damage_pct
	buff_special_cd_mult = maxf(0.4, buff_special_cd_mult - def.special_cd_pct)
	buff_special_radius_mult += def.special_radius_pct
	if def.health_add > 0 and player is PlayerUnit:
		(player as PlayerUnit).add_max_health(def.health_add)
	buff_changed.emit(def, stacks + 1)
	return true


func _reset_buffs() -> void:
	buffs.clear()
	buff_order.clear()
	buff_damage_mult = 1.0
	buff_fire_rate_mult = 1.0
	buff_extra_shots = 0
	buff_pierce = 0
	buff_heal_on_kill = 0.0
	buff_dash_cd_mult = 1.0
	buff_move_mult = 1.0
	buff_magnet = 0.0
	buff_drop_mult = 1.0
	buff_bounty_mult = 1.0
	buff_lifesteal = 0.0
	buff_auto_attack = 0
	buff_special_damage_mult = 1.0
	buff_special_cd_mult = 1.0
	buff_special_radius_mult = 1.0


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
	# Load first: the same file carries the language setting, and a fresh
	# ConfigFile would wipe it every time a run ends with a new record.
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)
	cfg.set_value("scores", "best", best_score)
	cfg.save(SAVE_PATH)
