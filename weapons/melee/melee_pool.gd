class_name MeleePool
## The melee loadout, in the order Q cycles through it. Cut-001b AC-05 needs all
## three usable and readable: 匕首 快 / 近 / 低, 斧 慢 / 中 / 高, 太刀 中 / 远 / 中.
## The numbers live in the .tres files, so tuning never touches this list.

const ALL: Array[MeleeData] = [
	preload("res://weapons/melee/knife.tres"),
	preload("res://weapons/melee/axe.tres"),
	preload("res://weapons/melee/tachi.tres"),
]
