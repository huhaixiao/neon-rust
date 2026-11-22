class_name WaveDirector
extends Node2D
## Wave director: builds a budget per wave, trickles enemies in from the arena
## edges, waits for a full clear, then hands out a bonus and the next wave.

const ENEMY_SCENE := preload("res://modules/enemies/enemy.tscn")
const PICKUP_SCENE := preload("res://modules/pickups/pickup.tscn")

var wave := 0

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
	var total := mini(6 + index * 2, 44)
	var spitters := 0
	var brutes := 0
	if index >= 2:
		spitters = maxi(1, int(index * 0.7))
	if index >= 3:
		brutes = maxi(1, int(index * 0.25))
	var chasers := maxi(1, total - spitters - brutes)
	_queue.clear()
	for i in chasers:
		_queue.append(Enemy.Kind.CHASER)
	for i in spitters:
		_queue.append(Enemy.Kind.SPITTER)
	for i in brutes:
		_queue.append(Enemy.Kind.BRUTE)
	_queue.shuffle()
	_spawn_interval = clampf(0.95 - 0.04 * index, 0.2, 0.95)
	_spawn_cd = 0.3
	Fx.sfx(Fx.SFX_WAVE, -2.0, 1.0)


func _spawn_one() -> void:
	if Game.enemies_root == null or _queue.is_empty():
		return
	var kind: int = _queue.pop_back()
	var enemy := ENEMY_SCENE.instantiate() as Enemy
	enemy.configure(kind, wave)
	enemy.position = _spawn_point()
	enemy.died.connect(_on_enemy_died)
	Game.enemies_root.add_child(enemy)
	_alive.append(enemy)
	_spawn_cd = _spawn_interval


func _spawn_point() -> Vector2:
	var bounds := Game.arena.grow(-40.0)
	var player := Game.player as PlayerUnit
	var point := bounds.get_center()
	for attempt in 8:
		var side := randi_range(0, 3)
		match side:
			0:
				point = Vector2(randf_range(bounds.position.x, bounds.end.x), bounds.position.y)
			1:
				point = Vector2(randf_range(bounds.position.x, bounds.end.x), bounds.end.y)
			2:
				point = Vector2(bounds.position.x, randf_range(bounds.position.y, bounds.end.y))
			_:
				point = Vector2(bounds.end.x, randf_range(bounds.position.y, bounds.end.y))
		if player == null or point.distance_to(player.global_position) > 300.0:
			break
	return point


func _prune() -> void:
	var kept: Array[Enemy] = []
	for enemy in _alive:
		if is_instance_valid(enemy) and not enemy.is_queued_for_deletion():
			kept.append(enemy)
	_alive = kept


func _finish_wave() -> void:
	var bonus := 25 + wave * 20
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
	if not is_inside_tree():
		return
	_maybe_drop.call_deferred(at)


func _maybe_drop(at: Vector2) -> void:
	var roll := randf()
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
