class_name PsycheFragments
extends Node
## Inventory handoff contract only. Fragment abilities and pickup arrive in #139.
signal changed
var player: Player
var shards: Array[int] = []
var deprivations: Array[int] = []

func bind(value: Player) -> void:
	player = value

func configure_deprivation(values: Array[int]) -> void:
	deprivations.assign(values)
	changed.emit()

func has_shard(realm: int) -> bool:
	return shards.has(realm)

func restore(values: Array[int]) -> void:
	shards.assign(values)
	changed.emit()
