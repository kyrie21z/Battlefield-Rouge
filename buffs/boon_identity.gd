class_name BoonIdentity
extends RefCounted
## Shared data identity; world markers do not depend on UI controls.
const COLORS: Array[Color] = BoonPalette.COLORS
const SIN_NAMES: Array[String] = ["怠惰", "恐惧", "暴怒", "悲伤"]
const SLOT_NAMES: Array[String] = ["枪械", "战刃", "冲刺", "被动"]
const RARITIES: Array[String] = ["普通", "稀有", "史诗", "传奇", "双重共鸣"]
const ICONS: Array[Texture2D] = [
	preload("res://assets/ui/boons/sloth.svg"), preload("res://assets/ui/boons/fear.svg"),
	preload("res://assets/ui/boons/wrath.svg"), preload("res://assets/ui/boons/sorrow.svg"),
]
const DUAL_ICON := preload("res://assets/ui/boons/dual.svg")

static func accent(data: BoonData) -> Color:
	return Color("f4d989") if data.rarity == BoonData.Rarity.DUAL else COLORS[data.sin]

static func icon(data: BoonData) -> Texture2D:
	if data.icon != null:
		return data.icon
	return DUAL_ICON if data.rarity == BoonData.Rarity.DUAL else ICONS[data.sin]

static func identity(data: BoonData) -> String:
	return "双重共鸣" if data.rarity == BoonData.Rarity.DUAL else SIN_NAMES[data.sin]
