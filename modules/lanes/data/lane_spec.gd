class_name LaneSpec
extends RefCounted
## The one middle lane, as a line from the Dire entry in the top-right corner
## down to the World Tree in the bottom-left. Everything that needs a lane
## coordinate (spawner, terrain art, tests) reads it from here, so re-aiming the
## lane is two constants and no scattered magic numbers.

## Creeps walk in from here: top-right corner of the 1600x1000 arena.
const START := Vector2(1460.0, 150.0)
## The World Tree sits here: bottom-left corner.
const TREE := Vector2(190.0, 800.0)
## Dirt width, and how far off the centre line the lane art may wobble.
const WIDTH := 220.0
const HALF_WIDTH := WIDTH * 0.5
## Where the hero stands: in front of the tree, facing up the lane.
const HERO_SPAWN := Vector2(392.0, 706.0)
## The one tower, behind the hero and in front of the tree. Until it falls the
## lane creeps cannot reach the tree at all.
const TOWER_T := 0.92
## Radiant (our) creeps step onto the lane just behind that tower.
const RADIANT_SPAWN_T := 0.97


static func direction() -> Vector2:
	return (TREE - START).normalized()


## Perpendicular to the lane, pointing "left" of the walk direction.
static func normal() -> Vector2:
	return direction().orthogonal()


static func length() -> float:
	return START.distance_to(TREE)


## A point along the lane, 0.0 at the Dire entry, 1.0 at the tree.
static func point(t: float) -> Vector2:
	return START.lerp(TREE, clampf(t, 0.0, 1.0))


## How far off the centre line a world point sits (signed, in pixels).
static func lateral(at: Vector2) -> float:
	return (at - START).dot(normal())


## How far along the lane a world point sits (0..1, unclamped).
static func progress_of(at: Vector2) -> float:
	return (at - START).dot(direction()) / length()


## Where the hero spawns: front of the tree, slightly up-lane.
static func hero_spawn() -> Vector2:
	return HERO_SPAWN


static func tower_pos() -> Vector2:
	return point(TOWER_T)


## Radiant creeps start behind the tower and push up the lane.
static func radiant_spawn() -> Vector2:
	return point(RADIANT_SPAWN_T)
