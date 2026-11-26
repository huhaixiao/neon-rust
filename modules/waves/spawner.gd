class_name WaveDirector
extends Node2D
## 两边兵线，一波一波往上加压强:
##
##   - 天灾（敌方）: 3 近战 + 1 远程, 从第 4 波起每 6 波多补 1 个兵（近战/远程
##     交替）, 每第 7 波多一辆投石车; 每 7 波升一档 (DotA1 的 7:30 升级周期)
##   - 天辉（我方）: 恒定 3 近战 + 1 远程, 不升级, 不吃 buff
##
## 没有间隔: 敌方本波全灭, 下一波立刻从右上角进场; 我方同时从树侧出兵, 双方
## 在中路对撞, 英雄站在己方兵后面补刀。压力全在敌方那侧增长, 所以局面一定是
## 越来越难守, 不会因为"两边一样强"卡成僵局。
##
## The whole line lives in `LaneSpec`.

const ENEMY_SCENE := preload("res://modules/enemies/enemy.tscn")
const PICKUP_SCENE := preload("res://modules/pickups/pickup.tscn")

## How close the hero has to get before a lane creep stops marching and fights.
const ENGAGE_RANGE := 250.0

## DotA1 wave layout (6.83d).
const MELEE_PER_WAVE := 3
const RANGED_PER_WAVE := 1
const SIEGE_EVERY_N_WAVES := 7
## Dire reinforcement ladder: one extra unit every REINFORCE_EVERY waves starting
## at REINFORCE_FROM_WAVE, alternating melee / ranged. Capped so a long run does
## not turn into a single file of 20 creeps.
const REINFORCE_FROM_WAVE := 4
const REINFORCE_EVERY := 6
const REINFORCE_MAX_STEPS := 6
## Creeps of one wave walk in together rather than one by one.
const SPAWN_INTERVAL := 0.35
## Only the very first wave gets a beat of quiet so the player can read the lane.
const FIRST_START_DELAY := 1.2
## Our wave dies faster than the Dire one (the Dire side is the bigger fleet),
## so the barracks keeps feeding it: 15 s after the Radiant line is wiped a new
## one steps on. Without this the hero ends up alone in front of the tower with
## every Dire creep alive, which is a different game.
const RADIANT_REINFORCE_DELAY := 15.0

var wave := 0
var lane_end := LaneSpec.TREE

var _dire: Array[Enemy] = []
var _friendly: Array[Enemy] = []
var _dire_queue: Array[int] = []
var _friendly_queue: Array[int] = []
var _spawn_cd := 0.0
var _spawn_interval := SPAWN_INTERVAL
var _start_delay := 0.0
var _friendly_timer := 0.0
var _active := false


func start() -> void:
	_active = true
	wave = 0
	_dire.clear()
	_friendly.clear()
	_dire_queue.clear()
	_friendly_queue.clear()
	_start_delay = FIRST_START_DELAY
	_friendly_timer = RADIANT_REINFORCE_DELAY


func _process(delta: float) -> void:
	if not _active or not Game.running:
		return
	_prune()
	if _start_delay > 0.0:
		_start_delay -= delta
		if _start_delay <= 0.0:
			_begin_wave(wave + 1)
		return
	_tick_radiant(delta)
	if not _dire_queue.is_empty() or not _friendly_queue.is_empty():
		_spawn_cd -= delta
		if _spawn_cd <= 0.0:
			_spawn_next()
		return
	# No intermission: the moment the Dire wave is wiped the next one steps in.
	if _dire.is_empty() and wave > 0:
		_finish_wave()


## Radiant barracks: refill the wall 15 s after the last of our creeps died.
func _tick_radiant(delta: float) -> void:
	if wave <= 0:
		return
	if not _friendly.is_empty() or not _friendly_queue.is_empty():
		_friendly_timer = RADIANT_REINFORCE_DELAY
		return
	_friendly_timer -= delta
	if _friendly_timer <= 0.0:
		_friendly_queue = friendly_composition()


## The Dire wave, as a list of creep kinds in walking order.
func composition(index: int) -> Array[int]:
	var out: Array[int] = []
	var steps := _reinforce_steps(index)
	for i in MELEE_PER_WAVE + int(ceil(float(steps) * 0.5)):
		out.append(Enemy.Kind.CHASER)
	for i in RANGED_PER_WAVE + int(floor(float(steps) * 0.5)):
		out.append(Enemy.Kind.SPITTER)
	if index % SIEGE_EVERY_N_WAVES == 0:
		out.append(Enemy.Kind.BRUTE)
	return out


## The Radiant wave never changes: it is the wall the player pushes behind, not
## a second win condition.
func friendly_composition() -> Array[int]:
	var out: Array[int] = []
	for i in MELEE_PER_WAVE:
		out.append(Enemy.Kind.CHASER)
	for i in RANGED_PER_WAVE:
		out.append(Enemy.Kind.SPITTER)
	return out


## 0 at wave 1-3, then 1 step per REINFORCE_EVERY waves (wave 4 = 1, wave 10 = 2).
func _reinforce_steps(index: int) -> int:
	if index < REINFORCE_FROM_WAVE:
		return 0
	var steps := 1 + int(float(index - REINFORCE_FROM_WAVE) / float(REINFORCE_EVERY))
	return mini(steps, REINFORCE_MAX_STEPS)


func _begin_wave(index: int) -> void:
	wave = index
	Game.set_wave(index)
	_dire_queue = composition(index)
	# Do not stack two Radiant waves when the last one is still walking up.
	_friendly_queue.clear()
	if _friendly.is_empty():
		_friendly_queue = friendly_composition()
	_spawn_cd = 0.0
	Fx.sfx(Fx.SFX_WAVE, -2.0, 1.0)


func _spawn_next() -> void:
	if Game.enemies_root == null:
		return
	if not _dire_queue.is_empty():
		_spawn_one(_dire_queue.pop_front(), Enemy.Team.DIRE)
	if not _friendly_queue.is_empty():
		_spawn_one(_friendly_queue.pop_front(), Enemy.Team.RADIANT)
	_spawn_cd = _spawn_interval


func _spawn_one(kind: int, team: int) -> void:
	var enemy := ENEMY_SCENE.instantiate() as Enemy
	enemy.configure(kind, wave, team)
	enemy.lane_active = true
	enemy.lane_end = LaneSpec.START if team == Enemy.Team.RADIANT else lane_end
	enemy.despawn_at_end = team == Enemy.Team.RADIANT
	enemy.engage_range = ENGAGE_RANGE
	enemy.position = _spawn_point(team)
	enemy.died.connect(_on_enemy_died)
	Game.enemies_root.add_child(enemy)
	if team == Enemy.Team.DIRE:
		_dire.append(enemy)
	else:
		_friendly.append(enemy)


func _spawn_point(team := Enemy.Team.DIRE) -> Vector2:
	# One middle lane. Dire creeps enter just inside the top-right corner and walk
	# down-left; Radiant creeps step on behind the tower and walk up. Jitter goes
	# along the lane's normal and a little way back, so a wave arrives as a loose
	# cluster instead of one stacked point.
	var dir := LaneSpec.direction()
	var side := LaneSpec.normal()
	var origin := LaneSpec.START if team == Enemy.Team.DIRE else LaneSpec.radiant_spawn()
	var along := randf_range(-10.0, 40.0) if team == Enemy.Team.DIRE else randf_range(-34.0, 6.0)
	return origin + side * randf_range(-62.0, 62.0) + dir * along


func _prune() -> void:
	var kept_dire: Array[Enemy] = []
	for enemy in _dire:
		if is_instance_valid(enemy) and not enemy.is_queued_for_deletion():
			kept_dire.append(enemy)
	_dire = kept_dire
	var kept_friendly: Array[Enemy] = []
	for enemy in _friendly:
		if is_instance_valid(enemy) and not enemy.is_queued_for_deletion():
			kept_friendly.append(enemy)
	_friendly = kept_friendly


func _finish_wave() -> void:
	var bonus := int(round(float(25 + wave * 20) * Game.buff_bounty_mult))
	Game.add_score(bonus)
	Game.wave_cleared.emit(wave, bonus)
	# The draft that follows pauses the tree; the queue is already loaded so
	# the next wave walks in as soon as play resumes.
	_begin_wave(wave + 1)


func _on_enemy_died(kind: int, at: Vector2, team: int) -> void:
	# Deaths arrive from inside a physics callback (bullet hits), so anything
	# that adds colliders has to wait for the physics step to finish.
	# Bounty and XP come from the same DotA1 sheet the creep's stats did, and
	# every Dire death pays the hero in full whether he landed the last hit or
	# his own creeps did - last-hitting with a pad is misery.
	if team != Enemy.Team.DIRE:
		return
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
