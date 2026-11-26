class_name Armor
extends RefCounted
## DotA1 6.x armour maths: damage reduction = 0.06*armour / (1 + 0.06*armour).
## Kept in one place so creep armour and hero armour can never drift apart.

const K := 0.06


static func reduction(armor: float) -> float:
	if armor <= 0.0:
		return 0.0
	return K * armor / (1.0 + K * armor)


## Positive armour soaks damage; negative armour amplifies it (DotA1 does the
## same sum with a negative value, which is why this is not clamped).
static func apply(damage: float, armor: float) -> float:
	if armor == 0.0:
		return damage
	return damage * (1.0 - reduction(armor))
