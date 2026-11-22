class_name BoonPresentation
extends BoonIdentity
## Shared authored identity for cards and their corresponding world reward (Scheme B).

static func label(text: String, size: int, color: Color, weight := 500, mono := false, spacing := 0) -> Label:
	return EditorialStyle.make_label(text, size, color, weight, mono, spacing)


static func panel(background: Color, border: Color, width: int = 2) -> StyleBoxFlat:
	return EditorialStyle.plaque(background, border, width, Vector2.ZERO, Color.TRANSPARENT, 20, 18)


## High-contrast accent tailored for ivory paper cards.
static func paper_accent(data: BoonData) -> Color:
	if data.rarity == BoonData.Rarity.DUAL:
		return Color("b07a18")
	return EditorialStyle.realm_accent(data.sin)


## 单行版机制说明，给选卡界面底部那一栏用。
## max_lines 控制列几条要点：普通卡三条，双重卡要放两系，所以各取两条以免撑破底栏。
static func realm_help_inline(sin: int, max_lines: int = 3) -> String:
	var data: Dictionary = RealmIntro.INTRO[clampi(sin, 0, RealmIntro.INTRO.size() - 1)]
	var source: Array = data["lines"]
	var parts: PackedStringArray = []
	for i in mini(max_lines, source.size()):
		parts.append(String(source[i]))
	return String(data["title"]) + "   " + " · ".join(parts)
