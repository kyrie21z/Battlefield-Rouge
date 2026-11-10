class_name BoonOffers
extends RefCounted
## Uses a zone-owned independent stream; inspecting UI never consumes combat RNG.


static func pick(manager: BoonManager, rng: RandomNumberGenerator, count: int = 3, sin_filter: int = -1, previous: Array[BoonData] = [], starter: bool = false) -> Array[BoonData]:
	var candidates: Array[BoonData] = []
	for card in BoonCatalog.eligible(manager):
		if sin_filter < 0 or card.sin == sin_filter or (card.rarity == BoonData.Rarity.DUAL and card.required_sins.has(sin_filter)):
			candidates.append(card)
	var result: Array[BoonData] = []
	if count <= 0:
		return result
	if starter:
		for slot in [BoonData.Slot.GUN, BoonData.Slot.BLADE, BoonData.Slot.DASH]:
			var matching: Array[BoonData] = []
			for card in candidates:
				if card.core and card.slot == slot:
					matching.append(card)
			var fresh: Array[BoonData] = []
			for card in matching:
				if not previous.has(card):
					fresh.append(card)
			if not fresh.is_empty():
				matching = fresh
			if not matching.is_empty():
				result.append(matching[rng.randi_range(0, matching.size() - 1)])
			if result.size() >= count:
				break
		return result
	var fresh: Array[BoonData] = []
	for card in candidates:
		if not previous.has(card):
			fresh.append(card)
	# Avoid an identical re-offer when the eligible pool has enough alternatives.
	if fresh.size() >= count:
		candidates = fresh
	while result.size() < count and not candidates.is_empty():
		var total := 0
		for card in candidates:
			total += _weight(card)
		var roll := rng.randi_range(1, total)
		for i in candidates.size():
			roll -= _weight(candidates[i])
			if roll <= 0:
				result.append(candidates[i])
				candidates.remove_at(i)
				break
	return result


static func _weight(card: BoonData) -> int:
	return [6, 4, 2, 1, 1][card.rarity]
