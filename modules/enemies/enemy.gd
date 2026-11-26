class_name Enemy
extends ShipBody
## One lane creep. Two of these fleets exist at once: the Dire wave that walks
## down the lane at the tree, and the Radiant wave that walks up it at the Dire
## entry. Both sides read the same DotA1 sheet (`CreepCatalog`), so a creep's
## strength never depends on which side it fights for — only the Dire fleet
## scales over the run.
##
##   CHASER = 近战兵   BRUTE = 投石车   SPITTER = 远程兵
##
## Combat is lane-vs-lane: a creep picks the closest *opposing creep* first and
## only goes for the hero when no enemy creep is around. That is what lets the
## hero stand behind its own wave and last-hit instead of tanking four bodies.

signal died(kind: int, at: Vector2, team: int)

enum Kind { CHASER, BRUTE, SPITTER }
enum Team { DIRE, RADIANT }

const TEX_CHASER := preload("res://modules/enemies/assets/sprites/enemy_chaser.png")
const TEX_BRUTE := preload("res://modules/enemies/assets/sprites/enemy_brute.png")
const TEX_SPITTER := preload("res://modules/enemies/assets/sprites/enemy_spitter.png")
const BULLET_SCENE := preload("res://modules/projectiles/bullet.tscn")

@export var kind: Kind = Kind.CHASER

var team := Team.DIRE
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

## Lane duty. A creep with `lane_active` walks toward `lane_end` and only breaks
## off to fight. Reaching the far end does not delete a Dire creep: it stands at
## the tower (or the tree) and hits it until something kills it, exactly like a
## DotA1 creep pushing a building. Radiant creeps that reach the Dire entry walk
## off the map instead - they are the ones doing the pushing.
var lane_active := false
var lane_end := Vector2.ZERO
var engage_range := 250.0
var despawn_at_end := false

var slow_mult := 1.0
var slow_left := 0.0

var art: CreepArt = null
var hp_bar: CreepHealthBar = null
var art_kind := 0

var _attack_cd := 0.0
var _at_end := false
var _being_despawned := false
var _orbit := 1.0

@onready var sprite: Sprite2D = $Sprite
@onready var hitbox: CollisionShape2D = $Hitbox
@onready var sfx_die: AudioStreamPlayer = $SfxDie
@onready var sfx_shoot: AudioStreamPlayer = $SfxShoot


func configure(kind_value, wave_index: int, side := Team.DIRE) -> void:
	kind = kind_value
	team = side
	var creep_id := CreepCatalog.MELEE
	match kind:
		Kind.BRUTE:
			creep_id = CreepCatalog.SIEGE
		Kind.SPITTER:
			creep_id = CreepCatalog.RANGED
	def = CreepCatalog.get_def(creep_id)
	# Only the Dire fleet gets the DotA1 upgrade cycles; the Radiant wave is the
	# constant "wall" the player pushes behind.
	var cycles := 0 if team == Team.RADIANT else CreepCatalog.cycles_for_wave(wave_index)
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


## Dire-side palette: the creeps that walk at the tree all read red.
const DIRE_MELEE := Color(0.66, 0.20, 0.20)
const DIRE_RANGED := Color(0.52, 0.20, 0.40)
const DIRE_SIEGE := Color(0.46, 0.26, 0.18)
## Radiant-side palette: the wave the player fights behind reads green/teal.
const RADIANT_MELEE := Color(0.24, 0.52, 0.28)
const RADIANT_RANGED := Color(0.22, 0.44, 0.52)
const RADIANT_SIEGE := Color(0.30, 0.44, 0.26)


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
	if team == Team.RADIANT:
		match art_kind:
			2:
				return RADIANT_SIEGE
			1:
				return RADIANT_RANGED
			_:
				return RADIANT_MELEE
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
	if dead or _being_despawned:
		return
	_attack_cd = maxf(0.0, _attack_cd - delta)
	_tick_slow(delta)
	if not Game.running:
		return
	# Lane-vs-lane first: a creep that has an opposing creep nearby never peels
	# off to chase the hero.
	var foe := _nearest_foe()
	if foe != null:
		_fight_foe(foe, delta)
		return
	var player := Game.player as PlayerUnit
	if player != null and not player.dead and team == Team.DIRE:
		var distance: float = player.global_position.distance_to(global_position)
		# On lane duty the hero has to come to the creep; otherwise the whole
		# wave would peel off and chase one target around the map.
		if not lane_active or distance <= engage_range:
			_fight_hero(player, distance, delta)
			return
	if lane_active:
		_march_lane(delta)


## The closest creep of the other fleet inside engage distance.
func _nearest_foe() -> Enemy:
	var best: Enemy = null
	var best_gap := maxf(attack_range, 300.0)
	for node in get_tree().get_nodes_in_group("enemies"):
		var other := node as Enemy
		if other == null or other == self or other.dead or other.team == team:
			continue
		var gap := other.global_position.distance_to(global_position)
		if gap <= best_gap:
			best_gap = gap
			best = other
	return best


## Creep vs creep: walk into range, then trade blows on the DotA1 attack
## interval. Damage is full (no hero-style reduction) and armour still applies
## inside `take_damage`.
func _fight_foe(foe: Enemy, delta: float) -> void:
	var offset: Vector2 = foe.global_position - global_position
	var distance := offset.length()
	var direction := offset.normalized() if distance > 0.001 else Vector2.RIGHT
	var standoff := attack_range if attack_range > 150.0 else radius + foe.radius + 6.0
	if distance > standoff:
		velocity = velocity.lerp(direction * speed * slow_mult, minf(1.0, delta * 4.0))
	elif distance < standoff - 10.0:
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
	if distance <= standoff + 10.0 and not foe.dead:
		_strike_foe(foe)


func _strike_foe(foe: Enemy) -> void:
	if _attack_cd > 0.0:
		return
	_attack_cd = attack_interval
	if projectile_speed > 0.0:
		_tracer(foe.global_position, projectile_color)
		sfx_shoot.pitch_scale = randf_range(0.82, 0.98)
		sfx_shoot.play()
	foe.take_damage(contact_damage, global_position)


## Chases the hero, stops at its own attack range, and hits on its own interval.
func _fight_hero(player: PlayerUnit, distance: float, delta: float) -> void:
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
		_strike_hero(player)


func _face(direction: Vector2, delta: float) -> void:
	rotation = lerp_angle(rotation, direction.angle(), minf(1.0, delta * 7.0))


## Walks the middle lane, then sieges whatever is at the end of it: the tower
## while it stands, the tree once it is rubble.
func _march_lane(delta: float) -> void:
	if _at_end:
		_siege_structure()
		return
	var stop_pos := lane_end
	var stop_gap := radius + 26.0
	var tower := Game.tower as LaneTower
	if team == Team.DIRE and is_instance_valid(tower) and not tower.dead:
		stop_pos = tower.global_position
		stop_gap = radius + LaneTower.RADIUS + 26.0
	var to_end: Vector2 = stop_pos - global_position
	var distance := to_end.length()
	if distance <= stop_gap:
		_at_end = true
		velocity = Vector2.ZERO
		_siege_structure()
		return
	var direction := to_end.normalized() if distance > 0.001 else Vector2.DOWN
	velocity = velocity.lerp(direction * speed * slow_mult, minf(1.0, delta * 4.0))
	velocity += _separation()
	position += velocity * delta
	clamp_to_arena(radius + 4.0)
	_face(direction, delta)
	if despawn_at_end and distance <= stop_gap * 2.0:
		_pass_through()


## Radiant creeps that finish the push walk off the map instead of standing in
## the entry corner for the rest of the run.
func _pass_through() -> void:
	if _being_despawned:
		return
	_being_despawned = true
	if hp_bar != null:
		hp_bar.queue_free()
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(art, "modulate:a", 0.0, 0.25)
	tween.tween_property(art, "scale", art.scale * 0.6, 0.25)
	tween.finished.connect(queue_free)


## Creeps that get past the hero chew on the tower first, then the tree.
## DotA1 numbers: a melee creep pays 21 per hit, a siege unit 150% of that into
## buildings; the tower's own 18 armour is applied by `take_damage`.
func _siege_structure() -> void:
	if _attack_cd > 0.0:
		return
	var tower := Game.tower as LaneTower
	if is_instance_valid(tower) and not tower.dead:
		_attack_cd = attack_interval
		var siege := 1.5 if kind == Kind.BRUTE else 1.0
		tower.take_damage(contact_damage * siege, global_position)
		Fx.burst(tower.global_position, Color(1.0, 0.7, 0.35), 8, 160.0, 0.7)
		Fx.sfx(Fx.SFX_HIT, -6.0, 0.8)
		return
	# Tower is down (or there never was one): if the creep is still standing at
	# its rubble, get back on the lane and go for the tree.
	if global_position.distance_to(lane_end) > radius + 34.0:
		_at_end = false
		return
	_attack_cd = attack_interval
	Game.damage_tree(int(round(contact_damage)))
	Fx.burst(global_position + Vector2(0.0, 12.0), Color(1.0, 0.6, 0.3), 10, 170.0, 0.6)
	Fx.flash(global_position, Color(1.0, 0.55, 0.35))
	Fx.sfx(Fx.SFX_HIT, -6.0, 0.8)


func _strike_hero(player: PlayerUnit) -> void:
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


## Thin fading line for ranged creeps: they trade blows from 500 px, so the
## shot has to be readable without spawning a real projectile per exchange.
func _tracer(to: Vector2, color: Color) -> void:
	var root := Game.fx_root
	if root == null:
		return
	var line := Line2D.new()
	line.width = 2.4
	line.default_color = color
	line.points = PackedVector2Array([Vector2.ZERO, to - global_position])
	line.position = global_position
	line.z_index = 5
	root.add_child(line)
	var tween := line.create_tween()
	tween.tween_property(line, "modulate:a", 0.0, 0.16)
	tween.finished.connect(line.queue_free)


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
	if dead or _being_despawned:
		return
	health -= Armor.apply(amount, armor)
	start_hit_flash(0.1)
	knock_back(hit_at, 3.0)
	Fx.burst(hit_at, base_color, 4, 130.0, 0.5)
	if health <= 0.0:
		_die()


func _die() -> void:
	dead = true
	died.emit(kind, global_position, team)
	Fx.burst(global_position, base_color, 22, 360.0, 1.0)
	Fx.flash(global_position, base_color)
	Fx.sfx(Fx.SFX_DIE, -4.0, randf_range(0.9, 1.2))
	Game.add_shake(0.3 if kind == Kind.CHASER else 0.6)
	queue_free()
