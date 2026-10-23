class_name CollisionLayers
## Physics layer bits, in one place. Bullets test WORLD | HITBOXES only, so
## an actor's movement capsule never stops a bullet before its hitboxes.

## Level geometry and props. Layer 1.
const WORLD := 1 << 0
## Movement capsules of the player and enemies. Layer 2.
const ACTORS := 1 << 1
## Hitbox bodies that take damage. Layer 4.
const HITBOXES := 1 << 3
