class_name PlayerUnit
extends ShipBody
## Twin-stick player: eight-way move, free aim (mouse or right stick),
## hold-to-fire, and a dash with invulnerability frames.

const BULLET_SCENE := preload("res://modules/projectiles/bullet.tscn")
const ARROW_SCENE := preload("res://modules/projectiles/arrow.tscn")
## How long the bow wind-up pins the hero in place after a manual shot. This is
## the DotA1 attack animation: you root yourself for the shot, you do not kite
## mid-draw.
const ROOT_TIME := 0.42

@export var move_speed := 430.0
@export var dash_speed := 1500.0
@export var dash_duration := 0.13
@export var dash_cooldown := 1.5
@export var fire_interval := 0.085
@export var bullet_damage := 18.0
@export var bullet_speed := 1050.0
@export var max_health := 100
@export var special_cooldown := 8.0
@export var special_damage := 55.0
@export var special_radius := 240.0
## Which hero this unit is playing. Stats come from `HeroCatalog`, not from
## the exports above, so a hero swap is one string.
@export var hero_id := HeroCatalog.DROW
@export var auto_aim := true

var attack_range := 470.0
## Gold/XP/items/passives. Kills feed it, it feeds `refresh_stats()`.
var progress: HeroProgress = null
## Force staff: an instant shove along the aim, on its own cooldown.
var force_push := 300.0
var force_cooldown := 20.0
var armor := 0.0
var health := 100
## HP per second: the DotA1 base regen plus anything the auto-bought items add.
var hp_regen := 0.0
var _regen_acc := 0.0
var aim := Vector2.RIGHT
var overdrive_left := 0.0
## Closest enemy inside `attack_range`, refreshed every frame in auto mode.
var target: Enemy = null
var bullet_color := Color(0.45, 1.0, 1.0)
var _slow_factor := 0.0
var _slow_time := 0.0
var _damage_min := 0.0
var _damage_max := 0.0
## The hero sheet before items and passives, so a recompute never compounds.
var _base := {}
var _root_left := 0.0
var _force_cd := 0.0
var _art: HeroArt = null

var _dashing := false
var _dash_left := 0.0
var _dash_cd := 0.0
var _dash_dir := Vector2.RIGHT
var _fire_cd := 0.0
var _special_cd := 0.0
var _invuln := 0.0
var _ghost_cd := 0.0
var _flash_tween: Tween = null
var _aim_from_stick := false
var _steal_acc := 0.0
## Debug counter: how many volleys the hero actually let go this run.
var shots_fired := 0
var _sentry: Node2D = null
var _sentry_cd := 0.0
var _sentry_angle := 0.0

@onready var body: Sprite2D = $Body
@onready var muzzle: Marker2D = $Muzzle
@onready var muzzle_flash: Sprite2D = $MuzzleFlash
@onready var sfx_shoot: AudioStreamPlayer = $SfxShoot
@onready var sfx_dash: AudioStreamPlayer = $SfxDash
@onready var sfx_hurt: AudioStreamPlayer = $SfxHurt


func _ready() -> void:
	add_to_group("player")
	Game.player = self
	if not Game.enemy_killed.is_connected(_on_enemy_killed):
		Game.enemy_killed.connect(_on_enemy_killed)
	apply_hero(HeroCatalog.get_def(hero_id))
	progress = HeroProgress.new()
	progress.changed.connect(refresh_stats)
	progress.item_purchased.connect(_on_item_purchased)
	progress.leveled_up.connect(_on_leveled_up)
	_art = HeroArt.new()
	# Drawn art is authored around a ~30px figure; the sheet silhouette should
	# sit above the creeps at the 0.85 camera zoom.
	_art.scale = Vector2(1.35, 1.35)
	add_child(_art)
	body.visible = false
	refresh_stats()
	health = max_health
	Game.set_health(health, max_health)
	muzzle_flash.visible = false


## Copies the hero sheet onto the player unit. Everything that makes 小黑 feel
## different from the next hero goes through here.
func apply_hero(def: HeroDef) -> void:
	hero_id = def.id
	attack_range = def.attack_range
	bullet_damage = def.damage
	_damage_min = def.damage_min
	_damage_max = def.damage_max
	armor = def.armor
	hp_regen = def.hp_regen
	fire_interval = def.attack_interval
	bullet_speed = def.bullet_speed
	move_speed = def.move_speed
	max_health = def.health
	bullet_color = def.bullet_color
	_slow_factor = def.slow_factor
	_slow_time = def.slow_time
	auto_aim = def.auto_attack
	_base = {
		"damage_min": def.damage_min,
		"damage_max": def.damage_max,
		"damage": def.damage,
		"fire_interval": def.attack_interval,
		"armor": def.armor,
		"regen": def.hp_regen,
		"max_health": def.health,
		"move_speed": def.move_speed,
		"slow": def.slow_factor,
	}
	health = max_health


## Folds items and passive levels onto the base hero sheet. Called on every
## purchase and every level, so there is one place that owns the numbers.
func refresh_stats() -> void:
	if progress == null or _base.is_empty():
		return
	var bonus := progress.bonus()
	var dmg_min: float = float(_base.damage_min) * (1.0 + float(bonus.damage_pct)) + float(bonus.damage)
	var dmg_max: float = float(_base.damage_max) * (1.0 + float(bonus.damage_pct)) + float(bonus.damage)
	_damage_min = dmg_min
	_damage_max = dmg_max
	bullet_damage = (dmg_min + dmg_max) * 0.5
	# DotA1 attack speed is interval x (1 - IAS); clamp it so a full item build
	# cannot turn the bow into a machine gun.
	fire_interval = maxf(0.30, float(_base.fire_interval) * (1.0 - float(bonus.attack_speed)))
	armor = float(_base.armor) + float(bonus.armor)
	hp_regen = float(_base.regen) + float(bonus.regen)
	move_speed = float(_base.move_speed) + float(bonus.move)
	_slow_factor = maxf(float(_base.slow), float(bonus.slow))
	var new_max := int(round(float(_base.max_health) + float(bonus.health)))
	if new_max != max_health:
		var gain := new_max - max_health
		max_health = new_max
		health = mini(max_health, health + maxi(0, gain))
	Game.set_health(health, max_health)


func _on_item_purchased(item_id: String) -> void:
	var def := HeroProgress.item_by_id(item_id)
	Fx.burst(global_position, Color(1.0, 0.85, 0.35), 10, 150.0, 0.7)
	if def.has("name_zh"):
		Game.announce(L10n.t("hud.bought") % HeroProgress.label(def), HeroProgress.label(def))


func _on_leveled_up(level: int) -> void:
	Fx.flash(global_position, Color(0.6, 0.9, 1.0), 1.6)
	Game.announce(L10n.t("hud.level_up") % level, L10n.t("hud.level_up_sub"))


## Called by the wave director when a creep dies.
func register_kill(bounty_gold: int, bounty_xp: int) -> void:
	if progress == null or dead:
		return
	progress.add_kill(bounty_gold, bounty_xp)


func _process(delta: float) -> void:
	if dead:
		return
	_tick(delta)
	if not Game.running:
		return
	_update_aim()
	rotation = aim.angle()
	_move(delta)
	_try_dash()
	_try_force_staff()
	_try_fire()
	_try_special()
	_update_sentry(delta)
	_update_visuals()


func _input(event: InputEvent) -> void:
	# Mouse takes over aim only when the player actually moves it; otherwise a
	# released right stick would snap back to wherever the cursor happens to sit.
	if event is InputEventMouseMotion:
		_aim_from_stick = false
	elif event is InputEventJoypadMotion:
		var motion := event as InputEventJoypadMotion
		if motion.axis == JOY_AXIS_RIGHT_X or motion.axis == JOY_AXIS_RIGHT_Y:
			if absf(motion.axis_value) > 0.3:
				_aim_from_stick = true


func _tick(delta: float) -> void:
	_fire_cd = maxf(0.0, _fire_cd - delta)
	_dash_cd = maxf(0.0, _dash_cd - delta)
	_special_cd = maxf(0.0, _special_cd - delta)
	_invuln = maxf(0.0, _invuln - delta)
	_force_cd = maxf(0.0, _force_cd - delta)
	_root_left = maxf(0.0, _root_left - delta)
	if _art != null:
		_art.pose = lerpf(_art.pose, clampf(_root_left / ROOT_TIME, 0.0, 1.0), minf(1.0, delta * 12.0))
		_art.bob = 1.0 if velocity.length() > 30.0 else 0.0
	tick_hit_flash(delta)
	_ghost_cd = maxf(0.0, _ghost_cd - delta)
	_tick_regen(delta)
	if overdrive_left > 0.0:
		overdrive_left = maxf(0.0, overdrive_left - delta)
		if overdrive_left <= 0.0:
			Game.overdrive_changed.emit(false, 0.0)
	if _dashing:
		_dash_left -= delta
		if _dash_left <= 0.0:
			_dashing = false


## Sips health back at the sheet's rate. Fractions are carried, so 0.76 HP/s
## reads as a steady trickle instead of a stutter of ones.
func _tick_regen(delta: float) -> void:
	if dead or not Game.running or hp_regen <= 0.0 or health >= max_health:
		return
	_regen_acc += hp_regen * delta
	var whole := int(_regen_acc)
	if whole <= 0:
		return
	_regen_acc -= float(whole)
	health = mini(max_health, health + whole)
	Game.set_health(health, max_health)


func _update_aim() -> void:
	# Lane mode: no mouse, no stick. The hero swings toward the closest creep
	# in range and keeps the last heading when the lane is empty, so the
	# sprite never snaps back to a stale direction.
	if auto_aim:
		target = _nearest_enemy(attack_range)
		if target == null:
			return
		var to_target: Vector2 = target.global_position - global_position
		if to_target.length() > 1.0:
			aim = to_target.normalized()
		return
	var stick := Vector2(
		Input.get_joy_axis(0, JOY_AXIS_RIGHT_X),
		Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)
	)
	aim = resolve_aim(stick, get_global_mouse_position() - global_position)


## Split out so the stick-release rule is testable without a physical pad.
func resolve_aim(stick: Vector2, to_mouse: Vector2) -> Vector2:
	if stick.length() > 0.3:
		_aim_from_stick = true
		return stick.normalized()
	# Stick released: hold the last stick heading instead of falling back to a
	# stale mouse position. A real mouse move clears this flag above.
	if _aim_from_stick:
		return aim
	if to_mouse.length() > 4.0:
		return to_mouse.normalized()
	return aim


func _move(delta: float) -> void:
	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	# Mid-draw the archer is pinned: that is the whole point of the wind-up.
	if _root_left > 0.0 and not _dashing:
		velocity = Vector2.ZERO
		return
	if _dashing:
		velocity = _dash_dir * dash_speed
		if _ghost_cd <= 0.0:
			_ghost_cd = 0.045
			Fx.ghost(self)
	else:
		velocity = input_dir * move_speed * Game.buff_move_mult
	position += velocity * delta
	clamp_to_arena(24.0)


func _try_dash() -> void:
	if _dashing or _dash_cd > 0.0:
		return
	if not Input.is_action_just_pressed("dash"):
		return
	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	_dash_dir = input_dir.normalized() if input_dir.length() > 0.1 else aim
	_dashing = true
	_dash_left = dash_duration
	_dash_cd = _dash_cooldown()
	_invuln = maxf(_invuln, dash_duration + 0.08)
	sfx_dash.play()
	Game.add_shake(0.18)
	Fx.ghost(self)


func _try_fire() -> void:
	if Game.bullets_root == null or _fire_cd > 0.0 or _root_left > 0.0:
		return
	# Auto mode fires by itself as long as something is inside the hero's
	# range - no trigger to hold, and no wasted shots into empty lane.
	if auto_aim:
		if target == null or not is_instance_valid(target) or target.dead:
			return
		if global_position.distance_to(target.global_position) > attack_range + 12.0:
			return
		_shoot()
		var auto_rate := fire_interval / Game.buff_fire_rate_mult
		_fire_cd = auto_rate * (0.62 if overdrive_left > 0.0 else 1.0)
		return
	# Manual shot: one press, one arrow, then the draw pins the hero for
	# ROOT_TIME. Held fire is not a thing any more.
	if not Input.is_action_just_pressed("fire"):
		return
	_shoot(true)
	var rate := fire_interval / Game.buff_fire_rate_mult
	_fire_cd = rate * (0.62 if overdrive_left > 0.0 else 1.0)


func _try_special() -> void:
	if _special_cd > 0.0:
		return
	if not Input.is_action_just_pressed("special"):
		return
	fire_special()


func fire_special() -> void:
	if dead or Game.enemies_root == null or Game.bullets_root == null:
		return
	var radius := special_radius * Game.buff_special_radius_mult
	var damage := special_damage * Game.buff_special_damage_mult
	_special_cd = _special_total()
	_spawn_nova_ring(radius)
	for node in Game.enemies_root.get_children():
		var enemy := node as Enemy
		if enemy == null or enemy.dead:
			continue
		# Only the Dire fleet is a target: the Radiant wave is the hero's own
		# lane partner, so aiming at it would eat the hero's whole output.
		if enemy.team != Enemy.Team.DIRE:
			continue
		if enemy.global_position.distance_to(global_position) <= radius:
			enemy.take_damage(damage, global_position)
	# The pulse doubles as a panic button: hostile rounds inside the ring go too.
	for node in Game.bullets_root.get_children():
		var shot := node as Projectile
		if shot == null or shot.friendly:
			continue
		if shot.global_position.distance_to(global_position) <= radius:
			Fx.burst(shot.global_position, Color(0.6, 1.0, 1.0), 3, 100.0, 0.5)
			shot.queue_free()
	Game.add_shake(0.9)
	Fx.flash(global_position, Color(0.6, 1.0, 1.0), 2.2)
	Fx.burst(global_position, Color(0.5, 1.0, 1.0), 26, 520.0, 1.2)
	Fx.sfx(Fx.SFX_WAVE, -2.0, 0.85)


func _spawn_nova_ring(radius: float) -> void:
	if Game.fx_root == null:
		return
	var ring := Line2D.new()
	ring.width = 4.0
	ring.default_color = Color(0.55, 1.0, 1.0, 0.9)
	var points := PackedVector2Array()
	var segments := 64
	for i in segments + 1:
		var angle := TAU * float(i) / float(segments)
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	ring.points = points
	ring.position = global_position
	ring.scale = Vector2(0.2, 0.2)
	Game.fx_root.add_child(ring)
	var tween := ring.create_tween()
	tween.set_parallel(true)
	tween.tween_property(ring, "scale", Vector2.ONE, 0.38).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(ring, "modulate:a", 0.0, 0.38)
	tween.finished.connect(ring.queue_free)


func _update_sentry(delta: float) -> void:
	if Game.buff_auto_attack <= 0:
		if is_instance_valid(_sentry):
			_sentry.visible = false
		return
	if not is_instance_valid(_sentry):
		_build_sentry()
	_sentry.visible = true
	_sentry_angle += delta * 2.2
	_sentry.global_position = global_position + Vector2(cos(_sentry_angle), sin(_sentry_angle)) * 52.0
	_sentry.rotation = aim.angle()
	_sentry_cd = maxf(0.0, _sentry_cd - delta)
	if _sentry_cd > 0.0:
		return
	var target := _nearest_enemy(700.0)
	if target == null:
		return
	_shoot_sentry(target)
	_sentry_cd = _sentry_interval()


func _build_sentry() -> void:
	_sentry = Node2D.new()
	_sentry.top_level = true
	var gem := Polygon2D.new()
	gem.polygon = PackedVector2Array([
		Vector2(0.0, -8.0), Vector2(7.0, 0.0), Vector2(0.0, 8.0), Vector2(-7.0, 0.0)
	])
	gem.color = Color(0.5, 1.0, 0.95, 1.0)
	_sentry.add_child(gem)
	var core := Polygon2D.new()
	core.polygon = PackedVector2Array([
		Vector2(0.0, -3.0), Vector2(3.0, 0.0), Vector2(0.0, 3.0), Vector2(-3.0, 0.0)
	])
	core.color = Color(1.0, 0.95, 0.7, 1.0)
	_sentry.add_child(core)
	add_child(_sentry)


func _nearest_enemy(max_distance: float) -> Enemy:
	var best: Enemy = null
	var best_gap := max_distance
	for node in Game.enemies_root.get_children():
		var enemy := node as Enemy
		if enemy == null or enemy.dead:
			continue
		if enemy.team != Enemy.Team.DIRE:
			continue
		var gap := enemy.global_position.distance_to(global_position)
		if gap <= best_gap:
			best_gap = gap
			best = enemy
	return best


func _shoot_sentry(target: Enemy) -> void:
	var dir := (target.global_position - _sentry.global_position).normalized()
	var bullet := BULLET_SCENE.instantiate()
	bullet.setup(dir, bullet_damage * 0.5 * Game.buff_damage_mult, 900.0, true, Color(1.0, 0.85, 0.45), Game.buff_pierce)
	bullet.position = _sentry.global_position
	Game.bullets_root.add_child(bullet)
	Fx.burst(_sentry.global_position, Color(1.0, 0.9, 0.5), 3, 90.0, 0.4)


func _sentry_interval() -> float:
	return 1.1 * pow(0.72, maxf(0.0, float(Game.buff_auto_attack - 1)))


func _shoot(manual := false) -> void:
	shots_fired += 1
	if manual:
		_root_left = ROOT_TIME
	# One fan for every source of extra rounds, so overdrive and SPLIT SHOT
	# compose instead of fighting over who writes the bullet loop.
	var count := mini(1 + Game.buff_extra_shots + (2 if overdrive_left > 0.0 else 0), 6)
	var damage := _roll_damage() * Game.buff_damage_mult
	var per := damage if count == 1 else damage * 0.72
	if count == 1:
		_spawn_bullet(aim, per)
	else:
		var step := 0.13
		var half := step * float(count - 1) * 0.5
		for i in count:
			_spawn_bullet(aim.rotated(-half + step * float(i)), per)
	Game.add_shake(0.05)
	sfx_shoot.pitch_scale = randf_range(0.94, 1.10)
	sfx_shoot.play()
	_pop_muzzle()


## DotA1 damage is a window, not a fixed number: 44-55 for 小黑.
func _roll_damage() -> float:
	if _damage_max > _damage_min:
		return randf_range(_damage_min, _damage_max)
	return bullet_damage


func _spawn_bullet(direction: Vector2, damage: float) -> void:
	var arrow := ARROW_SCENE.instantiate() as Arrow
	# Frost Arrows read pale blue, a plain shot reads bone white - the payload
	# of the passives is visible on the projectile itself.
	var tint := Color(0.72, 0.92, 1.0) if _slow_factor > 0.0 else Color(0.94, 0.90, 0.72)
	arrow.setup(direction, damage, bullet_speed, true, tint, Game.buff_pierce, _slow_factor, _slow_time)
	# Fire from the hull, not from the muzzle tip: a creep standing on top of the
	# hero would otherwise be spawned past, and a point-blank shot would miss.
	arrow.position = global_position + direction * 14.0
	Game.bullets_root.add_child(arrow)


func _pop_muzzle() -> void:
	muzzle_flash.visible = true
	muzzle_flash.modulate = Color(0.7, 1.0, 1.0, 1.0)
	muzzle_flash.scale = Vector2(0.35, 0.35)
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	_flash_tween = create_tween()
	_flash_tween.set_parallel(true)
	_flash_tween.tween_property(muzzle_flash, "scale", Vector2(0.62, 0.62), 0.06)
	_flash_tween.tween_property(muzzle_flash, "modulate:a", 0.0, 0.09)
	_flash_tween.finished.connect(_hide_muzzle)


func _hide_muzzle() -> void:
	muzzle_flash.visible = false
	muzzle_flash.modulate.a = 1.0


func _update_visuals() -> void:
	var visual: CanvasItem = _art if _art != null else body
	if flash_left > 0.0:
		visual.modulate = Color(2.0, 1.1, 1.1, 1.0)
	elif overdrive_left > 0.0:
		visual.modulate = Color(1.3, 1.05, 0.55, 1.0)
	else:
		visual.modulate = Color.WHITE
	if _invuln > 0.0 and not _dashing:
		visual.modulate.a = 0.55 + 0.45 * absf(sin(Time.get_ticks_msec() / 90.0))
	else:
		visual.modulate.a = 1.0


func take_damage(amount: float, from: Vector2 = Vector2.ZERO) -> void:
	if dead or _invuln > 0.0 or not Game.running:
		return
	health = maxi(0, health - int(round(Armor.apply(amount, armor))))
	_invuln = 0.42
	start_hit_flash(0.14)
	Game.set_health(health, max_health)
	Game.add_shake(0.6)
	Fx.burst(global_position, Color(1.0, 0.35, 0.45), 10, 220.0, 0.7)
	Fx.flash(global_position, Color(1.0, 0.4, 0.5))
	sfx_hurt.play()
	knock_back(from, 10.0)
	if health <= 0:
		_die()


func add_max_health(amount: int) -> void:
	# HULL PLATING: raising the cap and filling the new space in one move keeps
	# the HUD bar honest.
	max_health += amount
	health = mini(max_health, health + amount)
	Game.set_health(health, max_health)
	Fx.burst(global_position, Color(0.35, 1.0, 0.65), 14, 200.0, 0.8)


func _on_enemy_killed(_kind: int, _at: Vector2) -> void:
	if dead or Game.buff_heal_on_kill <= 0.0:
		return
	heal(int(round(Game.buff_heal_on_kill)))


func heal(amount: int) -> void:
	if dead:
		return
	health = mini(max_health, health + amount)
	Game.set_health(health, max_health)
	Fx.burst(global_position, Color(0.3, 1.0, 0.5), 10, 170.0, 0.7)


## Called by friendly bullets. Fractions are carried between hits so a 4%
## siphon on an 18-damage pulse still heals at a readable whole-number rate.
func on_damage_dealt(amount: float) -> void:
	if dead or Game.buff_lifesteal <= 0.0:
		return
	_steal_acc += amount * Game.buff_lifesteal
	var whole := int(_steal_acc)
	if whole <= 0:
		return
	_steal_acc -= float(whole)
	heal(whole)


func grant_overdrive(seconds: float) -> void:
	if dead:
		return
	overdrive_left = maxf(overdrive_left, seconds)
	Game.overdrive_changed.emit(true, overdrive_left)
	Fx.burst(global_position, Color(1.0, 0.8, 0.3), 12, 200.0, 0.8)


func is_dash_ready() -> bool:
	return _dash_cd <= 0.0


func dash_ratio() -> float:
	var total := _dash_cooldown()
	if total <= 0.0:
		return 1.0
	return clampf(1.0 - _dash_cd / total, 0.0, 1.0)


func is_special_ready() -> bool:
	return _special_cd <= 0.0


func special_ratio() -> float:
	var total := _special_total()
	if total <= 0.0:
		return 1.0
	return clampf(1.0 - _special_cd / total, 0.0, 1.0)


func _special_total() -> float:
	return special_cooldown * Game.buff_special_cd_mult


func _dash_cooldown() -> float:
	return dash_cooldown * Game.buff_dash_cd_mult


## --- force staff (推推棒) ------------------------------------------------

func _try_force_staff() -> void:
	if _force_cd > 0.0:
		return
	if not Input.is_action_just_pressed("force_staff"):
		return
	push_self(aim)


## Shoves the hero `force_push` pixels along `dir` in one frame, with a visible
## streak so a teleport-like hop still reads as movement.
func push_self(dir: Vector2) -> void:
	if dead or not Game.running:
		return
	var heading := dir.normalized() if dir.length() > 0.01 else aim
	var from := global_position
	var to := clamp_to_arena_at(from + heading * force_push)
	_force_cd = force_cooldown * Game.buff_dash_cd_mult
	_invuln = maxf(_invuln, 0.25)
	global_position = to
	_streak(from, to)
	Fx.burst(from, Color(0.6, 0.9, 1.0), 10, 180.0, 0.6)
	Fx.burst(to, Color(0.75, 0.95, 1.0), 14, 220.0, 0.7)
	Fx.flash(to, Color(0.7, 0.9, 1.0), 1.3)
	Fx.sfx(Fx.SFX_WAVE, -4.0, 1.2)
	Game.add_shake(0.25)


func clamp_to_arena_at(point: Vector2) -> Vector2:
	var margin := 28.0
	return Vector2(
		clampf(point.x, Game.arena.position.x + margin, Game.arena.end.x - margin),
		clampf(point.y, Game.arena.position.y + margin, Game.arena.end.y - margin)
	)


func _streak(from: Vector2, to: Vector2) -> void:
	if Game.fx_root == null:
		return
	var line := Line2D.new()
	line.width = 10.0
	line.default_color = Color(0.55, 0.9, 1.0, 0.35)
	line.points = PackedVector2Array([from, to])
	Game.fx_root.add_child(line)
	var tween := line.create_tween()
	tween.tween_property(line, "modulate:a", 0.0, 0.28)
	tween.finished.connect(line.queue_free)


func is_force_ready() -> bool:
	return _force_cd <= 0.0


func force_ratio() -> float:
	var total := force_cooldown * Game.buff_dash_cd_mult
	if total <= 0.0:
		return 1.0
	return clampf(1.0 - _force_cd / total, 0.0, 1.0)


func _die() -> void:
	dead = true
	velocity = Vector2.ZERO
	body.visible = false
	if _art != null:
		_art.visible = false
	muzzle_flash.visible = false
	Fx.burst(global_position, Color(0.45, 0.9, 1.0), 30, 480.0, 1.2)
	Fx.burst(global_position, Color(1.0, 0.4, 0.5), 16, 300.0, 0.9)
	Fx.flash(global_position, Color(0.7, 0.95, 1.0), 1.4)
	Fx.sfx(Fx.SFX_DIE, 0.0, 0.7)
	Game.add_shake(1.3)
	Game.end_run()
