class_name WaveDirector
extends Node2D
## DotA1 兵线节奏:
##
##   - 每波: 3 个近战兵 + 1 个远程兵；每第 7 波多一辆投石车
##   - 没有间隔: 一波清空, 下一波立刻从上方走进中路
##   - 小兵按 DotA1 的 7:30 周期升级（每 15 波一次, 见 CreepCatalog）
##
## One middle lane for now: creeps enter at the top of the map and walk down
## to the World Tree. Side lanes stay as data for later (see `docs/`).

const ENEMY_SCENE := preload("res://modules/enemies/enemy.tscn")
const PICKUP_SCENE := preload("res://modules/pickups/pickup.tscn")

const LANE_X := 800.0
const LANE_START_Y := 110.0
const LANE_END := Vector2(800.0, 858.0)
## How close the hero has to get before a lane creep stops marching and fights.
const ENGAGE_RANGE := 250.0

## DotA1 wave layout (6.83d).
const MELEE_PER_WAVE := 3
const RANGED_PER_WAVE := 1
const SIEGE_EVERY_N_WAVES := 7
## Creeps of one wave walk in together rather than one by one.
const SPAWN_INTERVAL := 0.35
## Only the very first wave gets a beat of quiet so the player can read the lane.
const FIRST_START_DELAY := 1.2

var wave := 0
var lane_end := LANE_END

var _alive: Array[Enemy] = []
var _queue: Array[int] = []
var _spawn_cd := 0.0
var _spawn_interval := SPAWN_INTERVAL
var _start_delay := 0.0
var _active := false


func start() -> void:
	_active = true
	wave = 0
	_alive.clear()
	_queue.clear()
	_start_delay = FIRST_START_DELAY


func _process(delta: float) -> void:
	if not _active or not Game.running:
		return
	_prune()
	if _start_delay > 0.0:
		_start_delay -= delta
		if _start_delay <= 0.0:
			_begin_wave(wave + 1)
		return
	if not _queue.is_empty():
		_spawn_cd -= delta
		if _spawn_cd <= 0.0:
			_spawn_one()
		return
	# No intermission: the moment the lane is empty the next wave steps in.
	if _alive.is_empty() and wave > 0:
		_finish_wave()


## One DotA1 wave, as a list of creep kinds in walking order.
func composition(index: int) -> Array[int]:
	var out: Array[int] = []
	for i in MELEE_PER_WAVE:
		out.append(Enemy.Kind.CHASER)
	for i in RANGED_PER_WAVE:
		out.append(Enemy.Kind.SPITTER)
	if index % SIEGE_EVERY_N_WAVES == 0:
		out.append(Enemy.Kind.BRUTE)
	return out


func _begin_wave(index: int) -> void:
	wave = index
	Game.set_wave(index)
	_queue = composition(index)
	_spawn_cd = 0.0
	Fx.sfx(Fx.SFX_WAVE, -2.0, 1.0)


func _spawn_one() -> void:
	if Game.enemies_root == null or _queue.is_empty():
		return
	var kind: int = _queue.pop_front()
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
	# The draft that follows pauses the tree; the queue is already loaded so
	# the next wave walks in as soon as play resumes.
	_begin_wave(wave + 1)


func _on_enemy_died(kind: int, at: Vector2) -> void:
	# Deaths arrive from inside a physics callback (bullet hits), so anything
	# that adds colliders has to wait for the physics step to finish.
	# Bounty and XP come from the same DotA1 sheet the creep's stats did.
	var creep_id := CreepCatalog.MELEE
	match kind:
		Enemy.Kind.BRUTE:
			creep_id = CreepCatalog.SIEGE
		Enemy.Kind.SPITTER:
			creep_id = CreepCatalog.RANGED
	var def := CreepCatalog.get_def(creep_id)
	Game.register_kill(def.bounty_gold, def.bounty_xp)
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
