class_name CodexRequirements
extends RefCounted
## Explanatory text only. BoonManager.can_equip remains the eligibility authority.

static func describe(card: BoonData, manager: BoonManager, catalog: Array[BoonData]) -> Array[String]:
	var lines: Array[String] = []
	if not is_instance_valid(manager):
		lines.append("尚未接入当前构筑；以下为合成路线。")
	for id in card.prerequisites:
		lines.append(_mark(manager, id) + _card_name(id, catalog))
	if not card.prerequisite_any.is_empty():
		var alternatives: Array[String] = []
		var held := false
		for id in card.prerequisite_any:
			alternatives.append(_card_name(id, catalog))
			held = held or (is_instance_valid(manager) and manager.has(id))
		lines.append(("✓ 已满足任选一项：" if held else "还缺少以下任一：") + " 或 ".join(alternatives))
	for sin_type in card.required_sins:
		var cores: Array[String] = []
		var held_cores: Array[String] = []
		for candidate in catalog:
			if candidate.core and candidate.sin == sin_type:
				cores.append(candidate.name)
				if is_instance_valid(manager) and manager.has(candidate.id):
					held_cores.append(candidate.name)
		var family := BoonIdentity.SIN_NAMES[sin_type]
		if not held_cores.is_empty():
			lines.append("✓ %s核心：%s" % [family, "、".join(held_cores)])
		else:
			lines.append("还缺少：%s核心任一（%s）" % [family, " 或 ".join(cores)])
	if card.required_trait_count > 0:
		var count := 0
		if is_instance_valid(manager):
			for trait_card in manager.traits:
				if trait_card.rarity != BoonData.Rarity.DUAL and (card.required_trait_sin < 0 or trait_card.sin == card.required_trait_sin):
					count += 1
		var family := "任意心魔" if card.required_trait_sin < 0 else BoonIdentity.SIN_NAMES[card.required_trait_sin]
		lines.append("%s%s特质 %d / %d%s" % ["✓ " if count >= card.required_trait_count else "还缺少：", family, count, card.required_trait_count, "（还需 %d 张）" % (card.required_trait_count - count) if count < card.required_trait_count else ""])
	if lines.is_empty():
		lines.append("无额外前置；核心替换仍需在选卡时确认。" if card.core else "无额外前置。")
	return lines

static func _mark(manager: BoonManager, id: String) -> String:
	return "✓ 已持有：" if is_instance_valid(manager) and manager.has(id) else "还缺少："

static func _card_name(id: String, catalog: Array[BoonData]) -> String:
	for card in catalog:
		if card.id == id:
			return "%s·%s" % [BoonIdentity.SIN_NAMES[card.sin], card.name]
	return id
