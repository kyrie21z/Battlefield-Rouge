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
		# The opening gift is one realm's three core cards, not three cards from
		# three realms. That way the mechanic card explains a single noun and the
		# player starts the run understanding one system instead of half of four.
		var realms: Array[int] = []
		for card in candidates:
			if card.core and not realms.has(card.sin):
				realms.append(card.sin)
		if realms.is_empty():
			return result
		var opening_sin: int = realms[rng.randi_range(0, realms.size() - 1)]
		for slot in [BoonData.Slot.GUN, BoonData.Slot.BLADE, BoonData.Slot.DASH]:
			var matching: Array[BoonData] = []
			for card in candidates:
				if card.core and card.slot == slot and card.sin == opening_sin:
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
	# 分层：一轮最多给一张"会替换现有构筑"的核心卡，其余名额留给特性。
	# 这样既不会三张全替换，又保证玩家每轮都能看到一次换系的机会。
	var swaps: Array[BoonData] = []
	var frees: Array[BoonData] = []
	for card in candidates:
		if _would_replace(card, manager):
			swaps.append(card)
		else:
			frees.append(card)
	if not swaps.is_empty() and not frees.is_empty():
		var first := _draw(swaps, rng, 1, manager)
		result.append_array(first)
		# 已经给出过的替换卡要从池里拿掉，否则特性不够时补位会把它再抽一次。
		for card in first:
			swaps.erase(card)
		if result.size() < count:
			result.append_array(_draw(frees, rng, count - result.size(), manager))
		if result.size() < count:
			result.append_array(_draw(swaps, rng, count - result.size(), manager))
	else:
		result.append_array(_draw(candidates, rng, count, manager))
	return result


## 加权不放回抽样。每张卡的权重由 _weight 决定，绝不给零权重卡机会。
static func _draw(pool: Array[BoonData], rng: RandomNumberGenerator, count: int,
		manager: BoonManager) -> Array[BoonData]:
	var picked: Array[BoonData] = []
	if count <= 0:
		return picked
	var remaining := pool.duplicate()
	while picked.size() < count and not remaining.is_empty():
		var total := 0
		for card in remaining:
			total += _weight(card, manager)
		if total <= 0:
			break
		var roll := rng.randi_range(1, total)
		var chosen := 0
		for i in remaining.size():
			roll -= _weight(remaining[i], manager)
			if roll <= 0:
				chosen = i
				break
		picked.append(remaining[chosen])
		remaining.remove_at(chosen)
	return picked


## 这张卡装上会顶掉现有核心吗？是的话它属于"替换卡"那一档。
static func _would_replace(card: BoonData, manager: BoonManager) -> bool:
	return manager != null and card.core and card.rarity != BoonData.Rarity.DUAL \
		and manager.slots[card.slot].data != null


## 替换卡内部再分轻重：没投资过的领域优先出现，玩家才看得到转系入口；
## 已经投资过的系只是补位，避免每轮都劝人拆掉自己刚建的构筑。
static func _weight(card: BoonData, manager: BoonManager = null) -> int:
	var base: int = [6, 4, 2, 1, 1][card.rarity]
	if manager == null or not card.core or card.rarity == BoonData.Rarity.DUAL:
		return base
	if manager.slots[card.slot].data != null:
		return base * 2 if not manager.has_sin_core(card.sin) else base
	return base
