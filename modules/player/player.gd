class_name PlayerUnit
extends ShipBody
## Twin-stick player: eight-way move, free aim (mouse or right stick),
## hold-to-fire, and a dash with invulnerability frames.

const BULLET_SCENE := preload("res://modules/projectiles/bullet.tscn")

@export var move_speed := 430.0
@export var dash_speed := 1500.0
@export var dash_duration := 0.13
@export var dash_cooldown := 1.5
@export var fire_interval := 0.085
@export var bullet_damage := 18.0
@export var bullet_speed := 1050.0
@export var max_health := 100

var health := 100
var aim := Vector2.RIGHT
var overdrive_left := 0.0

var _dashing := false
var _dash_left := 0.0
var _dash_cd := 0.0
var _dash_dir := Vector2.RIGHT
var _fire_cd := 0.0
var _invuln := 0.0
var _ghost_cd := 0.0
var _flash_tween: Tween = null

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
	health = max_health
	Game.set_health(health, max_health)
	muzzle_flash.visible = false


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
	_try_fire()
	_update_visuals()


func _tick(delta: float) -> void:
	_fire_cd = maxf(0.0, _fire_cd - delta)
	_dash_cd = maxf(0.0, _dash_cd - delta)
	_invuln = maxf(0.0, _invuln - delta)
	tick_hit_flash(delta)
	_ghost_cd = maxf(0.0, _ghost_cd - delta)
	if overdrive_left > 0.0:
		overdrive_left = maxf(0.0, overdrive_left - delta)
		if overdrive_left <= 0.0:
			Game.overdrive_changed.emit(false, 0.0)
	if _dashing:
		_dash_left -= delta
		if _dash_left <= 0.0:
			_dashing = false


func _update_aim() -> void:
	var stick := Vector2(
		Input.get_joy_axis(0, JOY_AXIS_RIGHT_X),
		Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)
	)
	if stick.length() > 0.3:
		aim = stick.normalized()
		return
	var to_mouse := get_global_mouse_position() - global_position
	if to_mouse.length() > 4.0:
		aim = to_mouse.normalized()


func _move(delta: float) -> void:
	var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
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
	if Game.bullets_root == null or _fire_cd > 0.0:
		return
	if not Input.is_action_pressed("fire"):
		return
	_shoot()
	var rate := fire_interval / Game.buff_fire_rate_mult
	_fire_cd = rate * (0.62 if overdrive_left > 0.0 else 1.0)


func _shoot() -> void:
	# One fan for every source of extra rounds, so overdrive and SPLIT SHOT
	# compose instead of fighting over who writes the bullet loop.
	var count := mini(1 + Game.buff_extra_shots + (2 if overdrive_left > 0.0 else 0), 6)
	var damage := bullet_damage * Game.buff_damage_mult
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


func _spawn_bullet(direction: Vector2, damage: float) -> void:
	var bullet := BULLET_SCENE.instantiate()
	bullet.setup(direction, damage, bullet_speed, true, Color(0.45, 1.0, 1.0), Game.buff_pierce)
	bullet.position = muzzle.global_position
	Game.bullets_root.add_child(bullet)


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
	if flash_left > 0.0:
		body.modulate = Color(2.0, 1.1, 1.1, 1.0)
	elif overdrive_left > 0.0:
		body.modulate = Color(1.3, 1.05, 0.55, 1.0)
	else:
		body.modulate = Color.WHITE
	if _invuln > 0.0 and not _dashing:
		body.modulate.a = 0.55 + 0.45 * absf(sin(Time.get_ticks_msec() / 90.0))
	else:
		body.modulate.a = 1.0


func take_damage(amount: float, from: Vector2 = Vector2.ZERO) -> void:
	if dead or _invuln > 0.0 or not Game.running:
		return
	health = maxi(0, health - int(round(amount)))
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


func grant_overdrive(seconds: float) -> void:
	if dead:
		return
	overdrive_left = maxf(overdrive_left, seconds)
	Game.overdrive_changed.emit(true, overdrive_left)
	Fx.burst(global_position, Color(1.0, 0.8, 0.3), 12, 200.0, 0.8)


func is_dash_ready() -> bool:
	return _dash_cd <= 0.0


func _dash_cooldown() -> float:
	return dash_cooldown * Game.buff_dash_cd_mult


func dash_ratio() -> float:
	var total := _dash_cooldown()
	if total <= 0.0:
		return 1.0
	return clampf(1.0 - _dash_cd / total, 0.0, 1.0)


func _die() -> void:
	dead = true
	velocity = Vector2.ZERO
	body.visible = false
	muzzle_flash.visible = false
	Fx.burst(global_position, Color(0.45, 0.9, 1.0), 30, 480.0, 1.2)
	Fx.burst(global_position, Color(1.0, 0.4, 0.5), 16, 300.0, 0.9)
	Fx.flash(global_position, Color(0.7, 0.95, 1.0), 1.4)
	Fx.sfx(Fx.SFX_DIE, 0.0, 0.7)
	Game.add_shake(1.3)
	Game.end_run()
