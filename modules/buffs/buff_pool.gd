class_name BuffPool
## Every module the player can be offered, and the only place balance lives.
## Values are per stack: picking the same buff again adds the delta again, up
## to `max_stacks`, so a run cannot loop one card forever.
## Names/descriptions live in `modules/l10n/data/strings_*.gd`, keyed by id.

static func all() -> Array[BuffDef]:
	var defs: Array[BuffDef] = []

	# --- OFFENSE ---------------------------------------------------------
	var overclock := BuffDef.make("overclock", BuffDef.Tag.OFFENSE, 3)
	overclock.damage_pct = 0.25
	defs.append(overclock)

	var rapid := BuffDef.make("rapid", BuffDef.Tag.OFFENSE, 3)
	rapid.fire_rate_pct = 0.18
	defs.append(rapid)

	var split := BuffDef.make("split", BuffDef.Tag.OFFENSE, 2)
	split.extra_shots = 1
	defs.append(split)

	var pierce := BuffDef.make("pierce", BuffDef.Tag.OFFENSE, 2)
	pierce.pierce = 1
	defs.append(pierce)

	# --- DEFENSE ---------------------------------------------------------
	var hull := BuffDef.make("hull", BuffDef.Tag.DEFENSE, 3)
	hull.health_add = 25
	defs.append(hull)

	var repair := BuffDef.make("repair", BuffDef.Tag.DEFENSE, 3)
	repair.heal_on_kill = 3.0
	defs.append(repair)

	var phase := BuffDef.make("phase", BuffDef.Tag.DEFENSE, 2)
	phase.dash_cd_pct = 0.25
	defs.append(phase)

	# --- MOBILITY --------------------------------------------------------
	var thrust := BuffDef.make("thrust", BuffDef.Tag.MOBILITY, 3)
	thrust.move_pct = 0.12
	defs.append(thrust)

	# --- UTILITY ---------------------------------------------------------
	var magnet := BuffDef.make("magnet", BuffDef.Tag.UTILITY, 2)
	magnet.magnet = 1.0
	defs.append(magnet)

	var salvage := BuffDef.make("salvage", BuffDef.Tag.UTILITY, 2)
	salvage.drop_pct = 0.7
	defs.append(salvage)

	var bounty := BuffDef.make("bounty", BuffDef.Tag.UTILITY, 2)
	bounty.bounty_pct = 0.5
	defs.append(bounty)

	return defs


static func find(buff_id: String) -> BuffDef:
	for def in all():
		if def.id == buff_id:
			return def
	return null
