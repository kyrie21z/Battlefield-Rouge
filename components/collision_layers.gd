class_name CollisionLayers
## Physics layer bits, in one place. Bullets test WORLD | HITBOXES only, so
## an actor's movement capsule never stops a bullet before its hitboxes.

## Level geometry and props. Layer 1.
const WORLD := 1 << 0
## The player's movement capsule. Layer 2.
const ACTORS := 1 << 1
## Enemy movement capsules. Layer 3. Not in an enemy's own mask, so soldiers
## pass through each other instead of squeezing a body into a map corner.
const ENEMIES := 1 << 2
## Hitbox bodies that take damage. Layer 4.
const HITBOXES := 1 << 3
## Invisible walls above the map rim, which only the player moves into: a
## pitched dash can lift it over the 4 m boundary. They are not WORLD, so
## bullets pass through instead of stopping short of the map edge. Layer 5.
const BOUNDARY := 1 << 4
