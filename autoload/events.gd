extends Node
## Global signal bus. Actors and components only emit here; they never read
## or write run state. See ARCHITECTURE.md.

signal enemy_killed(enemy: Node)
## Any gun fired, so enemies can hear it.
signal gunshot(position: Vector3)
## A blade landed on a capture point. Enemies hear it like a gunshot.
signal clock_struck(position: Vector3)
signal player_died
## The zone has no enemies left; its capture point opens.
signal zone_cleared(zone_index: int)
signal point_captured(zone_index: int)
signal buff_chosen(buff: Resource)
signal run_won

## Successful blade reflection; UI owns the optional hitstop.
signal blade_parried(position: Vector3)
