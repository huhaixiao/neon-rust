class_name BuffPool
## Every module the player can be offered, and the only place balance lives.
## Values are per stack: picking the same buff again adds the delta again, up
## to `max_stacks`, so a run cannot loop one card forever.

static func all() -> Array[BuffDef]:
	var defs: Array[BuffDef] = []

	# --- OFFENSE ---------------------------------------------------------
	var overclock := BuffDef.make(
		"overclock", "OVERCLOCK", "PULSE DAMAGE +25%", BuffDef.Tag.OFFENSE, 3)
	overclock.damage_pct = 0.25
	defs.append(overclock)

	var rapid := BuffDef.make(
		"rapid", "RAPID CYCLE", "FIRE RATE +18%", BuffDef.Tag.OFFENSE, 3)
	rapid.fire_rate_pct = 0.18
	defs.append(rapid)

	var split := BuffDef.make(
		"split", "SPLIT SHOT", "ONE EXTRA ROUND AT 72% DAMAGE", BuffDef.Tag.OFFENSE, 2)
	split.extra_shots = 1
	defs.append(split)

	var pierce := BuffDef.make(
		"pierce", "PIERCING ROUNDS", "PULSE PUNCHES THROUGH +1 TARGET", BuffDef.Tag.OFFENSE, 2)
	pierce.pierce = 1
	defs.append(pierce)

	# --- DEFENSE ---------------------------------------------------------
	var hull := BuffDef.make(
		"hull", "HULL PLATING", "MAX HULL +25, HEALS 25", BuffDef.Tag.DEFENSE, 3)
	hull.health_add = 25
	defs.append(hull)

	var repair := BuffDef.make(
		"repair", "REPAIR DRONE", "HEAL 3 HULL ON EVERY KILL", BuffDef.Tag.DEFENSE, 3)
	repair.heal_on_kill = 3.0
	defs.append(repair)

	var phase := BuffDef.make(
		"phase", "PHASE CAPACITOR", "DASH COOLDOWN -25%", BuffDef.Tag.DEFENSE, 2)
	phase.dash_cd_pct = 0.25
	defs.append(phase)

	# --- MOBILITY --------------------------------------------------------
	var thrust := BuffDef.make(
		"thrust", "THRUSTER TUNE", "MOVE SPEED +12%", BuffDef.Tag.MOBILITY, 3)
	thrust.move_pct = 0.12
	defs.append(thrust)

	# --- UTILITY ---------------------------------------------------------
	var magnet := BuffDef.make(
		"magnet", "MAGNET COIL", "PICKUPS SEEK YOU FROM 430 PX", BuffDef.Tag.UTILITY, 2)
	magnet.magnet = 1.0
	defs.append(magnet)

	var salvage := BuffDef.make(
		"salvage", "SALVAGE RIG", "ENEMY DROP CHANCE +70%", BuffDef.Tag.UTILITY, 2)
	salvage.drop_pct = 0.7
	defs.append(salvage)

	var bounty := BuffDef.make(
		"bounty", "BOUNTY CHIP", "WAVE CLEAR BONUS +50%", BuffDef.Tag.UTILITY, 2)
	bounty.bounty_pct = 0.5
	defs.append(bounty)

	return defs


static func find(buff_id: String) -> BuffDef:
	for def in all():
		if def.id == buff_id:
			return def
	return null
