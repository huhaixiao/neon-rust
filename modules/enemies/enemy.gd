class_name Enemy
extends ShipBody
## DotA1 兵线小兵. The whole stat sheet comes from `CreepCatalog`, so the three
## kinds here are only "which lane role", not a hand-tuned enemy design:
##
##   CHASER  = 近战兵   BRUTE = 投石车   SPITTER = 远程兵

signal died(kind: int, at: Vector2)

enum Kind { CHASER, BRUTE, SPITTER }

const TEX_CHASER := preload("res://modules/enemies/assets/sprites/enemy_chaser.png")
const TEX_BRUTE := preload("res://modules/enemies/assets/sprites/enemy_brute.png")
const TEX_SPITTER := preload("res://modules/enemies/assets/sprites/enemy_spitter.png")
const BULLET_SCENE := preload("res://modules/projectiles/bullet.tscn")

@export var kind: Kind = Kind.CHASER

var def: CreepDef
var health := 550.0
var health_max := 550.0
var speed := 325.0
var contact_damage := 21.0
var armor := 2.0
var attack_range := 100.0
var attack_interval := 1.0
var projectile_speed := 0.0
var projectile_color := Color(0.55, 1.0, 0.35)
var vs_hero_pct := 0.75
var bounty := 43
var score_value := 43
var radius := 17.0
var body_scale := 0.82
var base_color := Color(1.0, 0.25, 0.5)

## Lane duty. A creep with `lane_active` walks toward `lane_end` (the World
## Tree) and only breaks off to fight when the hero comes within `engage_range`.
## Reaching the tree does not delete the creep any more: it stands there and
## hits the tree until something kills it, exactly like a DotA1 creep pushing
## a building.
var lane_active := false
var lane_end := Vector2.ZERO
var engage_range := 250.0

var slow_mult := 1.0
var slow_left := 0.0

var art: CreepArt = null
var hp_bar: CreepHealthBar = null
var art_kind := 0

var _attack_cd := 0.0
var _at_tree := false
var _orbit := 1.0

@onready var sprite: Sprite2D = $Sprite
@onready var hitbox: CollisionShape2D = $Hitbox
@onready var sfx_die: AudioStreamPlayer = $SfxDie
@onready var sfx_shoot: AudioStreamPlayer = $SfxShoot


func configure(kind_value, wave_index: int) -> void:
	kind = kind_value
	var creep_id := CreepCatalog.MELEE
	match kind:
		Kind.BRUTE:
			creep_id = CreepCatalog.SIEGE
		Kind.SPITTER:
			creep_id = CreepCatalog.RANGED
	def = CreepCatalog.get_def(creep_id)
	var cycles := CreepCatalog.cycles_for_wave(wave_index)
	health_max = def.health_at(cycles)
	health = health_max
	armor = def.armor
	contact_damage = def.damage_at(cycles)
	attack_range = def.attack_range
	attack_interval = def.attack_interval
	projectile_speed = def.projectile_speed
	projectile_color = def.projectile_color
	vs_hero_pct = def.vs_hero_pct
	speed = def.move_speed
	bounty = def.bounty_gold
	score_value = def.bounty_gold
	radius = def.radius
	body_scale = def.body_scale
	base_color = def.color
	_orbit = 1.0 if randf() < 0.5 else -1.0


## Dire-side palette: the creeps are the enemy lane, so they all read red even
## though the hit sparks keep each role's colour.
const DIRE_MELEE := Color(0.66, 0.20, 0.20)
const DIRE_RANGED := Color(0.52, 0.20, 0.40)
const DIRE_SIEGE := Color(0.46, 0.26, 0.18)


func _ready() -> void:
	add_to_group("enemies")
	_apply_look()
	sprite.visible = false
	art = CreepArt.new()
	add_child(art)
	art.build(art_kind, _team_color())
	hp_bar = CreepHealthBar.new()
	hp_bar.top_level = true
	add_child(hp_bar)
	art.scale = Vector2.ONE * 0.15
	var pop := create_tween()
	# Drawn art is authored around a ~30px figure; scale it up so a lane creep
	# reads as a body at the 0.85 camera zoom instead of a speck.
	pop.tween_property(art, "scale", Vector2.ONE * (body_scale * 1.7), 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _team_color() -> Color:
	match art_kind:
		2:
			return DIRE_SIEGE
		1:
			return DIRE_RANGED
		_:
			return DIRE_MELEE


func _apply_look() -> void:
	var texture: Texture2D = TEX_CHASER
	var look := def.look if def != null else 0
	if look == 2:
		texture = TEX_BRUTE
	elif look == 1:
		texture = TEX_SPITTER
	sprite.texture = texture
	sprite.scale = Vector2(body_scale, body_scale)
	art_kind = 1 if look == 2 else (2 if look == 1 else 0)
	var shape := hitbox.shape.duplicate() as CircleShape2D
	if shape != null:
		shape.radius = radius
		hitbox.shape = shape


func _process(delta: float) -> void:
	tick_hit_flash(delta)
	if art != null:
		art.modulate = Color(2.0, 2.0, 2.0, 1.0) if flash_left > 0.0 else Color.WHITE
	if hp_bar != null:
		# Top-level, so it has to be parked over the body every frame.
		hp_bar.global_position = global_position + Vector2(0.0, -radius - 22.0)
		hp_bar.set_ratio(health / maxf(1.0, health_max))


func _physics_process(delta: float) -> void:
	if dead:
		return
	_attack_cd = maxf(0.0, _attack_cd - delta)
	_tick_slow(delta)
	if not Game.running:
		return
	var player := Game.player as PlayerUnit
	if player != null and not player.dead:
		var distance: float = player.global_position.distance_to(global_position)
		# On lane duty the hero has to come to the creep; otherwise the whole
		# wave would peel off and chase one target around the map.
		if not lane_active or distance <= engage_range:
			_fight(player, distance, delta)
			return
	if lane_active:
		_march_lane(delta)


## Chases, stops at its own attack range, and hits on its own interval.
func _fight(player: PlayerUnit, distance: float, delta: float) -> void:
	var to_player: Vector2 = player.global_position - global_position
	var direction := to_player.normalized() if distance > 0.001 else Vector2.RIGHT
	var standoff := attack_range if attack_range > 150.0 else radius + 20.0
	if distance > standoff:
		velocity = velocity.lerp(direction * speed * slow_mult, minf(1.0, delta * 4.0))
	elif distance < standoff - 8.0:
		# Back off instead of standing inside the hero: melee creeps that pile
		# onto the hull end up spawned past by point-blank shots.
		velocity = velocity.lerp(-direction * speed * 0.6 * slow_mult, minf(1.0, delta * 4.0))
	else:
		velocity = velocity.lerp(Vector2.ZERO, minf(1.0, delta * 6.0))
	velocity += _separation()
	position += velocity * delta
	clamp_to_arena(radius + 4.0)
	if projectile_speed <= 0.0 and velocity.length() > 4.0:
		rotation = lerp_angle(rotation, velocity.angle(), minf(1.0, delta * 9.0))
	else:
		_face(direction, delta)
	if distance <= standoff + 8.0:
		_strike(player)


func _face(direction: Vector2, delta: float) -> void:
	rotation = lerp_angle(rotation, direction.angle(), minf(1.0, delta * 7.0))


## Walks the middle lane toward the tree, then sieges it.
func _march_lane(delta: float) -> void:
	if _at_tree:
		_siege_tree(delta)
		return
	var to_end: Vector2 = lane_end - global_position
	var distance := to_end.length()
	if distance <= radius + 26.0:
		_at_tree = true
		velocity = Vector2.ZERO
		_siege_tree(delta)
		return
	var direction := to_end.normalized() if distance > 0.001 else Vector2.DOWN
	velocity = velocity.lerp(direction * speed * slow_mult, minf(1.0, delta * 4.0))
	velocity += _separation()
	position += velocity * delta
	clamp_to_arena(radius + 4.0)
	_face(direction, delta)


## Creeps that get past the hero keep chewing on the tree. DotA1 numbers:
## a melee creep pays 21 damage per hit into a 4250 HP ancient.
func _siege_tree(_delta: float) -> void:
	if _attack_cd > 0.0:
		return
	_attack_cd = attack_interval
	Game.damage_tree(int(round(contact_damage)))
	Fx.burst(global_position + Vector2(0.0, 12.0), Color(1.0, 0.6, 0.3), 10, 170.0, 0.6)
	Fx.flash(global_position, Color(1.0, 0.55, 0.35))
	Fx.sfx(Fx.SFX_HIT, -6.0, 0.8)


func _strike(player: PlayerUnit) -> void:
	if _attack_cd > 0.0:
		return
	_attack_cd = attack_interval
	var amount := contact_damage * vs_hero_pct
	if projectile_speed > 0.0:
		if Game.bullets_root == null:
			return
		var aim: Vector2 = (player.global_position - global_position).normalized()
		if aim == Vector2.ZERO:
			aim = Vector2.DOWN
		var bullet := BULLET_SCENE.instantiate()
		bullet.setup(aim, amount, projectile_speed, false, projectile_color)
		bullet.position = global_position + aim * (radius + 6.0)
		Game.bullets_root.add_child(bullet)
		sfx_shoot.pitch_scale = randf_range(0.82, 0.98)
		sfx_shoot.play()
		return
	player.take_damage(int(round(amount)), global_position)
	Fx.burst(global_position, base_color, 6, 150.0, 0.6)


func apply_slow(factor: float, duration: float) -> void:
	# Strongest slow wins and the timer refreshes on every frost arrow; a
	# creep never stacks itself down to a standstill.
	slow_mult = minf(slow_mult, clampf(1.0 - factor, 0.15, 1.0))
	slow_left = maxf(slow_left, duration)


func _tick_slow(delta: float) -> void:
	if slow_left <= 0.0:
		return
	slow_left = maxf(0.0, slow_left - delta)
	if slow_left <= 0.0:
		slow_mult = 1.0


func _separation() -> Vector2:
	var push := Vector2.ZERO
	for other in get_tree().get_nodes_in_group("enemies"):
		var neighbour := other as Enemy
		if neighbour == null or neighbour == self:
			continue
		var offset: Vector2 = global_position - neighbour.global_position
		var gap := offset.length()
		var limit: float = radius + neighbour.radius
		if gap > 0.01 and gap < limit:
			push += offset / gap * (limit - gap) * 5.0
	return push


func take_damage(amount: float, hit_at: Vector2) -> void:
	if dead:
		return
	health -= Armor.apply(amount, armor)
	start_hit_flash(0.1)
	knock_back(hit_at, 3.0)
	Fx.burst(hit_at, base_color, 4, 130.0, 0.5)
	if health <= 0.0:
		_die()


func _die() -> void:
	dead = true
	died.emit(kind, global_position)
	Fx.burst(global_position, base_color, 22, 360.0, 1.0)
	Fx.flash(global_position, base_color)
	Fx.sfx(Fx.SFX_DIE, -4.0, randf_range(0.9, 1.2))
	Game.add_shake(0.3 if kind == Kind.CHASER else 0.6)
	queue_free()
