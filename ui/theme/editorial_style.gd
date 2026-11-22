class_name EditorialStyle
## Architectural Editorial (Scheme B) design tokens, typography and StyleBox builders.
## High-contrast ivory paper & carbon ink plaques, 0-2px sharp corners, solid offset
## architectural shadows and zero muddy glows. Pure presentation; no gameplay state.

const PAPER := Color("f6f4ee")
const PAPER_SOFT := Color("ebe8e0")
const PAPER_TRACK := Color("dedbd2")
const PAPER_DIM := Color("d2cec3")

const INK := Color("111317")
const INK_SOFT := Color("1d2027")
const INK_TRACK := Color("2b2f38")
const INK_MUTED := Color("3b3f4a")

const SLATE := Color("5f646e")
const ASH := Color("9ea3ad")
const GOLD := Color("d49b35")
const GOLD_BRIGHT := Color("e5b756")
const WARNING := Color("d94141")
const SHIELD := Color("3b82c4")

## Saturated-for-paper realm accent tones (readable on both PAPER and INK).
const REALM_ACCENTS: Array[Color] = [
	Color("d49b35"), # Sloth - warm architectural gold
	Color("825ad4"), # Fear  - royal violet
	Color("d94141"), # Wrath - crisp vermilion
	Color("2e7ac4"), # Sorrow - cobalt blue
]

const REALM_EN: Array[String] = [
	"SLOTH REALM",
	"FEAR REALM",
	"WRATH REALM",
	"SORROW REALM",
]

const BOSS_NAMES: Array[String] = [
	"沉眠巨像",
	"审判之瞳",
	"狂暴尖塔",
	"哀泣巨碑",
]

const SANS_FAMILIES: PackedStringArray = [
	"Noto Sans CJK SC",
	"Source Han Sans SC",
	"Microsoft YaHei UI",
	"PingFang SC",
	"Hiragino Sans GB",
	"DejaVu Sans",
]

const MONO_FAMILIES: PackedStringArray = [
	"JetBrains Mono",
	"Cascadia Mono",
	"Consolas",
	"DejaVu Sans Mono",
	"Noto Sans Mono",
]

const SERIF_FAMILIES: PackedStringArray = [
	"Noto Serif CJK SC",
	"Source Han Serif SC",
	"Songti SC",
	"SimSun",
	"DejaVu Serif",
]

static var _fonts: Dictionary = {}
static var _theme_cache: Theme


static func realm_accent(realm: int) -> Color:
	return REALM_ACCENTS[clampi(realm, 0, REALM_ACCENTS.size() - 1)]


static func realm_en(realm: int) -> String:
	return REALM_EN[clampi(realm, 0, REALM_EN.size() - 1)]


static func font_sans(weight := 500, spacing := 0) -> Font:
	var key := "sans_%d_%d" % [weight, spacing]
	if _fonts.has(key):
		return _fonts[key]
	var base := SystemFont.new()
	base.font_names = SANS_FAMILIES
	base.font_weight = weight
	base.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_AUTO
	var result: Font = base
	if spacing != 0:
		var variation := FontVariation.new()
		variation.base_font = base
		variation.spacing_glyph = spacing
		result = variation
	_fonts[key] = result
	return result


static func font_mono(weight := 700, spacing := 0) -> Font:
	var key := "mono_%d_%d" % [weight, spacing]
	if _fonts.has(key):
		return _fonts[key]
	var base := SystemFont.new()
	base.font_names = MONO_FAMILIES
	base.font_weight = weight
	base.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_AUTO
	var variation := FontVariation.new()
	variation.base_font = base
	variation.spacing_glyph = spacing
	variation.opentype_features = {"tnum": 1}
	_fonts[key] = variation
	return variation


static func font_serif(weight := 500, spacing := 0) -> Font:
	var key := "serif_%d_%d" % [weight, spacing]
	if _fonts.has(key):
		return _fonts[key]
	var base := SystemFont.new()
	base.font_names = SERIF_FAMILIES
	base.font_weight = weight
	base.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_AUTO
	var result: Font = base
	if spacing != 0:
		var variation := FontVariation.new()
		variation.base_font = base
		variation.spacing_glyph = spacing
		result = variation
	_fonts[key] = result
	return result


static func plaque(
		bg: Color,
		border := INK,
		border_width := 2,
		shadow_offset := Vector2(4, 4),
		shadow_color := Color(INK, 0.85),
		pad_h := 16,
		pad_v := 12,
		top_accent_width := 0,
		top_accent_color := Color.TRANSPARENT) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(border_width)
	if top_accent_width > 0:
		style.border_width_top = top_accent_width
		if top_accent_color.a > 0.0:
			style.border_color = top_accent_color
	style.set_corner_radius_all(0)
	style.content_margin_left = pad_h
	style.content_margin_right = pad_h
	style.content_margin_top = pad_v
	style.content_margin_bottom = pad_v
	if shadow_offset != Vector2.ZERO and shadow_color.a > 0.0:
		style.shadow_color = shadow_color
		style.shadow_size = 1
		style.shadow_offset = shadow_offset
	return style


static func button_box(
		bg: Color,
		border: Color,
		border_width := 2,
		shadow_offset := Vector2.ZERO,
		shadow_color := Color(INK, 0.85),
		pad_h := 16,
		pad_v := 10) -> StyleBoxFlat:
	return plaque(bg, border, border_width, shadow_offset, shadow_color, pad_h, pad_v)


static func style_button(
		button: Button,
		primary := false,
		on_paper := false,
		font_size := 18) -> void:
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_override("font", font_sans(700, 1))
	button.add_theme_font_size_override("font_size", font_size)
	if primary:
		button.add_theme_stylebox_override("normal",
			button_box(INK, INK, 2, Vector2(4, 4), Color(GOLD, 0.9) if not on_paper else Color(INK, 0.35)))
		button.add_theme_stylebox_override("hover",
			button_box(GOLD, INK, 2, Vector2(4, 4), Color(INK, 0.85)))
		button.add_theme_stylebox_override("pressed",
			button_box(INK_SOFT, GOLD, 2, Vector2(2, 2), Color(INK, 0.85)))
		button.add_theme_stylebox_override("focus",
			button_box(INK_SOFT, GOLD, 2, Vector2(4, 4), Color(GOLD, 0.85)))
		button.add_theme_stylebox_override("disabled",
			button_box(INK_TRACK, INK_MUTED, 1))
		button.add_theme_color_override("font_color", PAPER)
		button.add_theme_color_override("font_hover_color", INK)
		button.add_theme_color_override("font_pressed_color", PAPER)
		button.add_theme_color_override("font_focus_color", PAPER)
		button.add_theme_color_override("font_disabled_color", SLATE)
	elif on_paper:
		button.add_theme_stylebox_override("normal",
			button_box(PAPER, INK, 2, Vector2(3, 3), Color(INK, 0.25)))
		button.add_theme_stylebox_override("hover",
			button_box(INK, INK, 2, Vector2(3, 3), Color(GOLD, 0.85)))
		button.add_theme_stylebox_override("pressed",
			button_box(INK_SOFT, GOLD, 2, Vector2(1, 1), Color(INK, 0.4)))
		button.add_theme_stylebox_override("focus",
			button_box(PAPER_SOFT, GOLD, 2, Vector2(3, 3), Color(INK, 0.25)))
		button.add_theme_stylebox_override("disabled",
			button_box(PAPER_TRACK, PAPER_DIM, 1))
		button.add_theme_color_override("font_color", INK)
		button.add_theme_color_override("font_hover_color", PAPER)
		button.add_theme_color_override("font_pressed_color", GOLD_BRIGHT)
		button.add_theme_color_override("font_focus_color", INK)
		button.add_theme_color_override("font_disabled_color", SLATE)
	else:
		button.add_theme_stylebox_override("normal",
			button_box(INK, Color(PAPER, 0.35), 1, Vector2(3, 3), Color(INK, 0.7)))
		button.add_theme_stylebox_override("hover",
			button_box(PAPER, PAPER, 2, Vector2(3, 3), Color(GOLD, 0.85)))
		button.add_theme_stylebox_override("pressed",
			button_box(PAPER_SOFT, GOLD, 2, Vector2(1, 1), Color(INK, 0.7)))
		button.add_theme_stylebox_override("focus",
			button_box(INK_SOFT, GOLD, 2, Vector2(3, 3), Color(INK, 0.7)))
		button.add_theme_stylebox_override("disabled",
			button_box(Color(INK, 0.65), INK_TRACK, 1))
		button.add_theme_color_override("font_color", PAPER)
		button.add_theme_color_override("font_hover_color", INK)
		button.add_theme_color_override("font_pressed_color", INK)
		button.add_theme_color_override("font_focus_color", PAPER)
		button.add_theme_color_override("font_disabled_color", SLATE)


static func style_tab(button: Button, on_paper := false, font_size := 18) -> void:
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_override("font", font_sans(700, 1))
	button.add_theme_font_size_override("font_size", font_size)
	if on_paper:
		button.add_theme_stylebox_override("normal", button_box(PAPER_SOFT, PAPER_DIM, 1, Vector2.ZERO, Color.TRANSPARENT, 16, 8))
		button.add_theme_stylebox_override("hover", button_box(PAPER, INK, 2, Vector2.ZERO, Color.TRANSPARENT, 16, 8))
		button.add_theme_stylebox_override("pressed", button_box(INK, INK, 2, Vector2(3, 3), Color(GOLD, 0.9), 16, 8))
		button.add_theme_stylebox_override("hover_pressed", button_box(INK, GOLD, 2, Vector2(3, 3), Color(GOLD, 0.9), 16, 8))
		button.add_theme_stylebox_override("focus", button_box(PAPER, GOLD, 2, Vector2.ZERO, Color.TRANSPARENT, 16, 8))
		button.add_theme_color_override("font_color", SLATE)
		button.add_theme_color_override("font_hover_color", INK)
		button.add_theme_color_override("font_pressed_color", PAPER)
		button.add_theme_color_override("font_hover_pressed_color", GOLD_BRIGHT)
		button.add_theme_color_override("font_focus_color", INK)
	else:
		button.add_theme_stylebox_override("normal", button_box(INK_SOFT, INK_TRACK, 1, Vector2.ZERO, Color.TRANSPARENT, 16, 8))
		button.add_theme_stylebox_override("hover", button_box(INK_TRACK, PAPER, 1, Vector2.ZERO, Color.TRANSPARENT, 16, 8))
		button.add_theme_stylebox_override("pressed", button_box(PAPER, PAPER, 2, Vector2(3, 3), Color(GOLD, 0.85), 16, 8))
		button.add_theme_stylebox_override("hover_pressed", button_box(PAPER, GOLD, 2, Vector2(3, 3), Color(GOLD, 0.85), 16, 8))
		button.add_theme_stylebox_override("focus", button_box(INK_SOFT, GOLD, 2, Vector2.ZERO, Color.TRANSPARENT, 16, 8))
		button.add_theme_color_override("font_color", ASH)
		button.add_theme_color_override("font_hover_color", PAPER)
		button.add_theme_color_override("font_pressed_color", INK)
		button.add_theme_color_override("font_hover_pressed_color", INK)
		button.add_theme_color_override("font_focus_color", PAPER)


static func style_label(
		label: Label,
		font_size: int,
		color := INK,
		weight := 500,
		mono := false,
		spacing := 0) -> Label:
	label.add_theme_font_override("font", font_mono(weight, spacing) if mono else font_sans(weight, spacing))
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


static func make_label(
		text: String,
		font_size: int,
		color := INK,
		weight := 500,
		mono := false,
		spacing := 0) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return style_label(label, font_size, color, weight, mono, spacing)


static func make_eyebrow(text: String, font_size := 13) -> Label:
	var label := make_label(text, font_size, PAPER, 700, true, 2)
	var box := plaque(INK, INK, 0, Vector2.ZERO, Color.TRANSPARENT, 12, 5)
	label.add_theme_stylebox_override("normal", box)
	return label


static func make_rule(color := PAPER_DIM, thickness := 1) -> ColorRect:
	var rule := ColorRect.new()
	rule.color = color
	rule.custom_minimum_size.y = thickness
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rule


static func build_theme() -> Theme:
	if _theme_cache != null:
		return _theme_cache
	var theme := Theme.new()
	theme.default_font = font_sans(500)
	theme.default_font_size = 18

	# PanelContainer default: crisp ivory architectural plaque
	theme.set_stylebox("panel", "PanelContainer", plaque(PAPER, INK, 2, Vector2(5, 5), Color(INK, 0.85), 20, 18))

	# Button default: sharp carbon ink button (eliminates Godot grey)
	theme.set_font("font", "Button", font_sans(700, 1))
	theme.set_stylebox("normal", "Button", button_box(INK, INK, 2, Vector2(3, 3), Color(GOLD, 0.85)))
	theme.set_stylebox("hover", "Button", button_box(GOLD, INK, 2, Vector2(3, 3), Color(INK, 0.85)))
	theme.set_stylebox("pressed", "Button", button_box(INK_SOFT, GOLD, 2, Vector2(1, 1), Color(INK, 0.85)))
	theme.set_stylebox("focus", "Button", button_box(INK_SOFT, GOLD, 2, Vector2(3, 3), Color(GOLD, 0.85)))
	theme.set_stylebox("disabled", "Button", button_box(INK_TRACK, INK_MUTED, 1))
	theme.set_color("font_color", "Button", PAPER)
	theme.set_color("font_hover_color", "Button", INK)
	theme.set_color("font_pressed_color", "Button", PAPER)
	theme.set_color("font_focus_color", "Button", PAPER)
	theme.set_color("font_disabled_color", "Button", SLATE)

	# OptionButton & PopupMenu
	theme.set_font("font", "OptionButton", font_sans(600))
	theme.set_stylebox("normal", "OptionButton", button_box(PAPER, INK, 2, Vector2.ZERO, Color.TRANSPARENT, 12, 6))
	theme.set_stylebox("hover", "OptionButton", button_box(PAPER_SOFT, INK, 2, Vector2.ZERO, Color.TRANSPARENT, 12, 6))
	theme.set_stylebox("pressed", "OptionButton", button_box(INK, INK, 2, Vector2.ZERO, Color.TRANSPARENT, 12, 6))
	theme.set_stylebox("focus", "OptionButton", button_box(PAPER, GOLD, 2, Vector2.ZERO, Color.TRANSPARENT, 12, 6))
	theme.set_color("font_color", "OptionButton", INK)
	theme.set_color("font_hover_color", "OptionButton", INK)
	theme.set_color("font_pressed_color", "OptionButton", PAPER)
	theme.set_color("font_focus_color", "OptionButton", INK)

	theme.set_stylebox("panel", "PopupMenu", plaque(PAPER, INK, 2, Vector2(4, 4), Color(INK, 0.75), 6, 6))
	theme.set_stylebox("hover", "PopupMenu", plaque(INK, INK, 0, Vector2.ZERO, Color.TRANSPARENT, 8, 6))
	theme.set_color("font_color", "PopupMenu", INK)
	theme.set_color("font_hover_color", "PopupMenu", PAPER)

	# CheckButton
	theme.set_font("font", "CheckButton", font_sans(600))
	theme.set_stylebox("normal", "CheckButton", button_box(Color.TRANSPARENT, Color.TRANSPARENT, 0, Vector2.ZERO, Color.TRANSPARENT, 6, 4))
	theme.set_stylebox("hover", "CheckButton", button_box(Color(INK, 0.06), Color.TRANSPARENT, 0, Vector2.ZERO, Color.TRANSPARENT, 6, 4))
	theme.set_stylebox("pressed", "CheckButton", button_box(Color.TRANSPARENT, Color.TRANSPARENT, 0, Vector2.ZERO, Color.TRANSPARENT, 6, 4))
	theme.set_stylebox("focus", "CheckButton", button_box(Color.TRANSPARENT, GOLD, 2, Vector2.ZERO, Color.TRANSPARENT, 6, 4))
	theme.set_color("font_color", "CheckButton", INK)
	theme.set_color("font_hover_color", "CheckButton", INK)
	theme.set_color("font_pressed_color", "CheckButton", INK)

	# HSlider: architectural hairline track + solid carbon fill
	var slider_bg := StyleBoxFlat.new()
	slider_bg.bg_color = PAPER_TRACK
	slider_bg.border_color = INK
	slider_bg.set_border_width_all(1)
	slider_bg.content_margin_top = 4
	slider_bg.content_margin_bottom = 4
	var slider_fill := StyleBoxFlat.new()
	slider_fill.bg_color = INK
	slider_fill.content_margin_top = 4
	slider_fill.content_margin_bottom = 4
	var slider_fill_hl := StyleBoxFlat.new()
	slider_fill_hl.bg_color = GOLD
	slider_fill_hl.content_margin_top = 4
	slider_fill_hl.content_margin_bottom = 4
	theme.set_stylebox("slider", "HSlider", slider_bg)
	theme.set_stylebox("grabber_area", "HSlider", slider_fill)
	theme.set_stylebox("grabber_area_highlight", "HSlider", slider_fill_hl)

	# ScrollBar: clean razor track
	var scroll_bg := StyleBoxFlat.new()
	scroll_bg.bg_color = Color(INK, 0.08)
	scroll_bg.content_margin_left = 4
	scroll_bg.content_margin_right = 4
	var scroll_grab := StyleBoxFlat.new()
	scroll_grab.bg_color = SLATE
	var scroll_grab_hl := StyleBoxFlat.new()
	scroll_grab_hl.bg_color = INK
	theme.set_stylebox("scroll", "VScrollBar", scroll_bg)
	theme.set_stylebox("grabber", "VScrollBar", scroll_grab)
	theme.set_stylebox("grabber_highlight", "VScrollBar", scroll_grab_hl)
	theme.set_stylebox("grabber_pressed", "VScrollBar", scroll_grab_hl)

	# ProgressBar default
	theme.set_stylebox("background", "ProgressBar", plaque(PAPER, INK, 2, Vector2.ZERO, Color.TRANSPARENT, 0, 0))
	theme.set_stylebox("fill", "ProgressBar", plaque(INK, INK, 0, Vector2.ZERO, Color.TRANSPARENT, 0, 0))

	_theme_cache = theme
	return theme


static func apply_theme(control: Control) -> void:
	if control != null:
		control.theme = build_theme()
