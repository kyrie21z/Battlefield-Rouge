class_name BoonPalette
extends RefCounted
## Theme 0 preserves the unmodified clock; themes 1..4 match Sin + 1.
const COLORS: Array[Color] = [Color("efb853"), Color("b79aff"), Color("f26464"), Color("69bfff")]

static func clock_color(theme: int, fallback: Color) -> Color:
	return COLORS[theme - 1] if theme >= 1 and theme <= COLORS.size() else fallback
