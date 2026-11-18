class_name BoonPresentation
extends BoonIdentity
## Shared authored identity for cards and their corresponding world reward.

static func label(text: String, size: int, color: Color) -> Label:
	var result := Label.new()
	result.text = text
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result.add_theme_font_size_override("font_size", size)
	result.add_theme_color_override("font_color", color)
	return result


static func panel(background: Color, border: Color, width: int = 1) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(3)
	style.set_content_margin_all(20)
	return style


## 单行版机制说明，给选卡界面底部那一栏用。
## max_lines 控制列几条要点：普通卡三条，双重卡要放两系，所以各取两条以免撑破底栏。
static func realm_help_inline(sin: int, max_lines: int = 3) -> String:
	var data: Dictionary = RealmIntro.INTRO[clampi(sin, 0, RealmIntro.INTRO.size() - 1)]
	var source: Array = data["lines"]
	var parts: PackedStringArray = []
	for i in mini(max_lines, source.size()):
		parts.append(String(source[i]))
	return String(data["title"]) + "   " + " · ".join(parts)
