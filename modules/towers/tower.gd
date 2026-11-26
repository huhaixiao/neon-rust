class_name LaneTower
extends Node2D
## DotA1 一塔, sitting between the hero and the World Tree.
##
##   1300 HP / 18 armour / 100-120 damage / 700 range / 1.0s
##
## While it stands no Dire creep can reach the tree: every creep stops here and
## chews on the tower instead, and leaks cost the tower its health rather than
## the ancient's. That is the buffer between a sloppy wave and a lost run.
##
## Drawn in code like the tree, so the defence layer needs no art pipeline.

const HEALTH := 1300.0
const ARMOR := 18.0
const DAMAGE_MIN := 100.0
const DAMAGE_MAX := 120.0
const RANGE := 700.0
const INTERVAL := 1.0
## Physical footprint: lane creeps stop this far out from the centre.
const RADIUS := 26.0

var health := HEALTH
var health_max := HEALTH
var dead := false

var _cd := 0.0
var _hit := 0.0
var _shot := 0.0
var _rubble := 0.0

@onready var sfx: AudioStreamPlayer = $SfxShoot


func _ready() -> void:
	Game.tower = self
	add_to_group("tower")
	_modulate_by_state()


func _process(delta: float) -> void:
	_hit = maxf(0.0, _hit - delta * 4.0)
	_shot = maxf(0.0, _shot - delta * 7.0)
	if dead:
		_rubble += delta
	queue_redraw()


func _physics_process(delta: float) -> void:
	if dead or not Game.running:
		return
	_cd = maxf(0.0, _cd - delta)
	if _cd > 0.0:
		return
	var target := _nearest_dire()
	if target == null:
		return
	_cd = INTERVAL
	# Damage is flat 100-120; the creep's own armour is applied inside
	# `take_damage`, so a 2-armour melee creep takes ~98 per bolt.
	target.take_damage(randf_range(DAMAGE_MIN, DAMAGE_MAX), global_position)
	_bolt(target.global_position)
	_shot = 1.0
	Game.add_shake(0.06)
	sfx.pitch_scale = randf_range(0.9, 1.05)
	sfx.play()


func _nearest_dire() -> Enemy:
	var best: Enemy = null
	var best_gap := RANGE
	if not is_instance_valid(Game.enemies_root):
		return null
	for node in Game.enemies_root.get_children():
		var creep := node as Enemy
		if creep == null or creep.dead:
			continue
		if creep.team != Enemy.Team.DIRE:
			continue
		var gap := creep.global_position.distance_to(global_position)
		if gap <= best_gap:
			best_gap = gap
			best = creep
	return best


## Fading line from the tower head to the target, so a 700-range shot reads.
func _bolt(to: Vector2) -> void:
	var root := Game.fx_root
	if root == null:
		return
	var line := Line2D.new()
	line.width = 3.6
	line.default_color = Color(1.0, 0.86, 0.5, 0.95)
	line.points = PackedVector2Array([Vector2(0.0, -74.0), to - global_position])
	line.position = global_position
	line.z_index = 5
	root.add_child(line)
	var tween := line.create_tween()
	tween.tween_property(line, "modulate:a", 0.0, 0.14)
	tween.finished.connect(line.queue_free)
	Fx.burst(to, Color(1.0, 0.8, 0.4), 6, 130.0, 0.6)


func take_damage(amount: float, hit_at: Vector2) -> void:
	if dead:
		return
	health -= Armor.apply(amount, ARMOR)
	_hit = 1.0
	_apply_hp_bar()
	Fx.burst(hit_at, Color(0.9, 0.7, 0.4), 5, 140.0, 0.6)
	Game.add_shake(0.2)
	if health <= 0.0:
		_destroy()


func health_ratio() -> float:
	return clampf(health / health_max, 0.0, 1.0)


func _apply_hp_bar() -> void:
	queue_redraw()


func _destroy() -> void:
	dead = true
	health = 0.0
	Fx.burst(global_position + Vector2(0.0, -40.0), Color(0.85, 0.6, 0.35), 34, 420.0, 1.3)
	Fx.flash(global_position, Color(1.0, 0.72, 0.35), 2.0)
	Fx.sfx(Fx.SFX_DIE, 0.0, 0.6)
	Game.add_shake(1.4)
	Game.announce(L10n.t("hud.tower_down"), L10n.t("hud.tower_down_sub"))
	queue_redraw()


func _modulate_by_state() -> void:
	queue_redraw()


func _draw() -> void:
	var ratio := health_ratio() if not dead else 0.0
	var stone := Color(0.46, 0.46, 0.42)
	var stone_dark := Color(0.26, 0.26, 0.24)
	var trim := Color(0.62, 0.58, 0.44)
	if dead:
		# Rubble: a broken stump and a couple of fallen blocks.
		draw_circle(Vector2(0.0, 16.0), 30.0, Color(0.0, 0.0, 0.0, 0.35))
		draw_rect(Rect2(-28.0, 0.0, 56.0, 22.0), stone_dark)
		draw_rect(Rect2(-20.0, -12.0, 40.0, 16.0), stone)
		for i in 3:
			var offset := Vector2(-34.0 + float(i) * 26.0, 30.0 + float(i % 2) * 6.0)
			draw_rect(Rect2(offset.x, offset.y, 16.0, 12.0), stone.lightened(0.1))
		draw_line(Vector2(-30.0, 10.0), Vector2(30.0, 18.0), Color(0.35, 0.3, 0.25), 4.0)
		return

	# Shadow + stone plinth.
	draw_circle(Vector2(0.0, 18.0), 40.0, Color(0.0, 0.0, 0.0, 0.32))
	draw_rect(Rect2(-32.0, 6.0, 64.0, 20.0), stone_dark)
	draw_rect(Rect2(-28.0, 2.0, 56.0, 8.0), stone)
	# Shaft: three stacked blocks so it reads as masonry at a glance.
	var body_top := -56.0
	draw_rect(Rect2(-22.0, body_top, 44.0, 60.0), stone)
	for i in 3:
		draw_rect(Rect2(-22.0, body_top + float(i) * 20.0, 44.0, 2.0), stone_dark)
		draw_rect(Rect2(-22.0 + float(i % 2) * 22.0, body_top + float(i) * 20.0, 2.0, 20.0), stone_dark)
	# Battlement + beacon head.
	draw_rect(Rect2(-28.0, -66.0, 56.0, 12.0), stone.lightened(0.06))
	for x in [-26.0, -12.0, 2.0, 16.0]:
		draw_rect(Rect2(x, -76.0, 9.0, 11.0), stone)
	draw_circle(Vector2(0.0, -40.0), 9.0, stone_dark)
	var glow := 0.55 + 0.45 * sin(Time.get_ticks_msec() / 320.0)
	draw_circle(Vector2(0.0, -40.0), 6.5, Color(1.0, 0.78, 0.35, 0.45 + 0.35 * glow))
	# Shield plate with the team trim.
	draw_rect(Rect2(-10.0, -30.0, 20.0, 26.0), stone_dark)
	draw_line(Vector2(-10.0, -30.0), Vector2(10.0, -30.0), trim, 2.0)
	if _shot > 0.0:
		draw_circle(Vector2(0.0, -66.0), 10.0 + 12.0 * _shot, Color(1.0, 0.85, 0.5, 0.5 * _shot))

	# Bar above: the tower's own health, so a leak is visible on the map.
	var bar_width := 78.0
	var bar := Rect2(-bar_width * 0.5, -104.0, bar_width, 8.0)
	draw_rect(bar, Color(0.06, 0.06, 0.06, 0.85))
	var fill := Color(0.92, 0.78, 0.30).lerp(Color(0.85, 0.25, 0.22), 1.0 - ratio)
	draw_rect(Rect2(bar.position.x + 1.0, bar.position.y + 1.0, (bar_width - 2.0) * ratio, 6.0), fill)
	draw_rect(bar, Color(0.55, 0.5, 0.4, 0.8), false, 1.0)
	if _hit > 0.0:
		draw_circle(Vector2(0.0, -30.0), 60.0, Color(1.0, 0.55, 0.3, 0.18 * _hit))
