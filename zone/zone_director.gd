class_name ZoneDirector
extends Node
## Runs one zone: bakes navigation, applies the run's buffs to the player and
## hands enemies their target and cover points. Step 4 adds enemy counting,
## opening the capture point and moving to the next zone.

@export var navigation_region: NavigationRegion3D


func _ready() -> void:
	if navigation_region != null:
		navigation_region.bake_navigation_mesh(false)

	var player := get_tree().get_first_node_in_group("player") as Player
	for buff: Buff in RunState.buffs:
		player.stats.apply_buff(buff)

	var cover_points: Array[CoverPoint] = []
	for node in get_tree().get_nodes_in_group("cover_point"):
		cover_points.append(node as CoverPoint)
	for enemy: Enemy in get_tree().get_nodes_in_group("enemy"):
		enemy.setup(player, cover_points)
