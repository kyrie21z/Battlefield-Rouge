extends Node
## Global signal bus. Actors and components only emit here; they never read
## or write run state. See ARCHITECTURE.md.

signal enemy_killed(enemy: Node)
signal player_died
## The zone has no enemies left; its capture point opens.
signal zone_cleared(zone_index: int)
signal point_captured(zone_index: int)
signal buff_chosen(buff: Resource)
signal run_won
