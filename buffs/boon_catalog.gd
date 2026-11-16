class_name BoonCatalog
extends RefCounted
const FAMILIES := ["sloth", "fear", "wrath", "sorrow", "dual"]
static var _cards: Array[BoonData] = []

static func all() -> Array[BoonData]:
	if not _cards.is_empty(): return _cards.duplicate()
	var result: Array[BoonData] = []
	for family in FAMILIES:
		var path := "res://buffs/resources/%s/pool.tres" % family
		if ResourceLoader.exists(path):
			var pool := load(path) as BoonPool
			if pool != null:
				result.append_array(pool.cards)
	_cards.assign(result)
	return result

static func eligible(manager: BoonManager, sin: int = -1) -> Array[BoonData]:
	var result: Array[BoonData] = []
	for card in all():
		if (sin < 0 or card.sin == sin) and manager.can_equip(card):
			result.append(card)
	return result
