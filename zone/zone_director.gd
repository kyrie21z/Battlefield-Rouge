class_name ZoneDirector
extends Node
## Runs one zone. For now it only applies the run's buffs to the player when
## the zone loads; step 4 adds enemy counting, opening the capture point and
## moving to the next zone.

func _ready() -> void:
	var player := get_tree().get_first_node_in_group("player") as Player
	for buff: Buff in RunState.buffs:
		player.stats.apply_buff(buff)
