class_name WaveDirector
extends Node2D
## Wave director: builds a budget per wave, trickles enemies in from the arena
## edges, waits for a full clear, then hands out a bonus and the next wave.

const ENEMY_SCENE := preload("res://modules/enemies/enemy.tscn")
const PICKUP_SCENE := preload("res://modules/pickups/pickup.tscn")

## One middle lane for now: creeps enter at the top of the map and walk down
## to the World Tree. Side lanes stay as data for later (see `docs/`).
const LANE_X := 800.0
const LANE_START_Y := 110.0
const LANE_END := Vector2(800.0, 858.0)
## How close the hero has to get before a lane creep stops marching and fights.
const ENGAGE_RANGE := 250.0

var wave := 0
var lane_end := LANE_END

var _alive: Array[Enemy] = []
var _queue: Array[int] = []
var _spawn_cd := 0.0
var _spawn_interval := 0.9
var _intermission := 0.0
var _active := false


func start() -> void:
	_active = true
	wave = 0
	_alive.clear()
	_queue.clear()
	_intermission = 2.6


func _process(delta: float) -> void:
	if not _active or not Game.running:
		return
	_prune()
	if _intermission > 0.0:
		_intermission -= delta
		if _intermission <= 0.0:
			_begin_wave(wave + 1)
		return
	if not _queue.is_empty():
		_spawn_cd -= delta
		if _spawn_cd <= 0.0:
			_spawn_one()
		return
	if _alive.is_empty():
		_finish_wave()


func _begin_wave(index: int) -> void:
	wave = index
	Game.set_wave(index)
	# One lane means one wave budget, not four edges' worth. Count keeps the
	# ramp readable instead of drowning a single lane in creeps.
	var total := mini(5 + index * 2, 32)
	var spitters := 0
	var brutes := 0
	if index >= 3:
		spitters = maxi(1, int(index * 0.5))
	if index >= 4:
		brutes = maxi(1, int(index * 0.25))
	var melee := maxi(1, total - spitters - brutes)
	_queue.clear()
	for i in melee:
		_queue.append(Enemy.Kind.CHASER)
	for i in spitters:
		_queue.append(Enemy.Kind.SPITTER)
	for i in brutes:
		_queue.append(Enemy.Kind.BRUTE)
	_queue.shuffle()
	_spawn_interval = clampf(0.95 - 0.04 * index, 0.25, 0.95)
	_spawn_cd = 0.3
	Fx.sfx(Fx.SFX_WAVE, -2.0, 1.0)


func _spawn_one() -> void:
	if Game.enemies_root == null or _queue.is_empty():
		return
	var kind: int = _queue.pop_back()
	var enemy := ENEMY_SCENE.instantiate() as Enemy
	enemy.configure(kind, wave)
	enemy.lane_active = true
	enemy.lane_end = lane_end
	enemy.engage_range = ENGAGE_RANGE
	enemy.position = _spawn_point()
	enemy.died.connect(_on_enemy_died)
	Game.enemies_root.add_child(enemy)
	_alive.append(enemy)
	_spawn_cd = _spawn_interval


func _spawn_point() -> Vector2:
	# Single middle lane: creeps enter at the top and walk down to the tree.
	# Lateral jitter keeps them from stacking into one line the separation
	# pass has to untangle.
	return Vector2(LANE_X + randf_range(-30.0, 30.0), LANE_START_Y + randf_range(-12.0, 12.0))


func _prune() -> void:
	var kept: Array[Enemy] = []
	for enemy in _alive:
		if is_instance_valid(enemy) and not enemy.is_queued_for_deletion():
			kept.append(enemy)
	_alive = kept


func _finish_wave() -> void:
	var bonus := int(round(float(25 + wave * 20) * Game.buff_bounty_mult))
	Game.add_score(bonus)
	Game.wave_cleared.emit(wave, bonus)
	_intermission = 2.8


func _on_enemy_died(kind: int, at: Vector2) -> void:
	# Deaths arrive from inside a physics callback (bullet hits), so anything
	# that adds colliders has to wait for the physics step to finish.
	var values := {
		Enemy.Kind.CHASER: 10,
		Enemy.Kind.BRUTE: 45,
		Enemy.Kind.SPITTER: 30,
	}
	Game.add_score(int(values.get(kind, 10)))
	Game.enemy_killed.emit(kind, at)
	if not is_inside_tree():
		return
	_maybe_drop.call_deferred(at)


func _maybe_drop(at: Vector2) -> void:
	var roll := randf() / Game.buff_drop_mult
	if roll < 0.06:
		_spawn_pickup(Pickup.Kind.HEALTH, at)
	elif roll < 0.15:
		_spawn_pickup(Pickup.Kind.OVERDRIVE, at)


func _spawn_pickup(kind: Pickup.Kind, at: Vector2) -> void:
	if Game.pickups_root == null:
		return
	var pickup := PICKUP_SCENE.instantiate() as Pickup
	pickup.setup(kind)
	pickup.position = at
	Game.pickups_root.add_child(pickup)
