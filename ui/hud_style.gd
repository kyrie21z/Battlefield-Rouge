class_name HudStyle
## Shared architectural HUD drawing helpers and palette (Scheme B: Architectural Editorial).
## Preserves legacy constant names for backward compatibility with older HUD components & tests.

const ACCENT := Color("d49b35")
const WARNING := Color("d94141")
const TEXT := Color("f6f4ee")
const MUTED := Color("9ea3ad")
const PANEL_FILL := Color("111317f0")
const PANEL_LINE := Color("111317")
const DARK := Color("111317")


static func bevel_points(rect: Rect2, cut: float) -> PackedVector2Array:
	var c := minf(cut, minf(rect.size.x, rect.size.y) * 0.5)
	var x0 := rect.position.x
	var y0 := rect.position.y
	var x1 := rect.end.x
	var y1 := rect.end.y
	return PackedVector2Array([
		Vector2(x0 + c, y0), Vector2(x1 - c, y0), Vector2(x1, y0 + c),
		Vector2(x1, y1 - c), Vector2(x1 - c, y1), Vector2(x0 + c, y1),
		Vector2(x0, y1 - c), Vector2(x0, y0 + c),
	])


static func draw_panel(ci: CanvasItem, rect: Rect2, border: Color, _cut := 0.0,
		fill := PANEL_FILL) -> void:
	# Hard offset architectural shadow + sharp solid plaque
	ci.draw_rect(Rect2(rect.position + Vector2(4.0, 4.0), rect.size), Color(EditorialStyle.INK, 0.82))
	ci.draw_rect(rect, fill)
	ci.draw_rect(rect, border, false, 2.0)


static func draw_glow(ci: CanvasItem, rect: Rect2, color: Color, _cut := 0.0) -> void:
	ci.draw_rect(rect.grow(1.5), Color(color, 0.45), false, 2.0)


## Largest rect with `texture`'s aspect ratio that fits inside `rect`.
static func fit_texture(texture: Texture2D, rect: Rect2) -> Rect2:
	if texture == null:
		return Rect2(rect.position, Vector2.ZERO)
	var tex_size := texture.get_size()
	if tex_size.x <= 0.0 or tex_size.y <= 0.0:
		return Rect2(rect.position, Vector2.ZERO)
	var scale := minf(rect.size.x / tex_size.x, rect.size.y / tex_size.y)
	var draw_size := tex_size * scale
	return Rect2(rect.position + (rect.size - draw_size) * 0.5, draw_size)


static func draw_icon(ci: CanvasItem, texture: Texture2D, rect: Rect2, color: Color) -> void:
	if texture == null:
		return
	ci.draw_texture_rect(texture, fit_texture(texture, rect), false, color)


static func draw_text_centered(ci: CanvasItem, font: Font, center_x: float, baseline_y: float,
		text: String, font_size: int, color: Color) -> void:
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	ci.draw_string(font, Vector2(center_x - width * 0.5, baseline_y), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
