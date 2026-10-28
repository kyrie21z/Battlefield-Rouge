class_name HudStyle
## Shared look for the graphical HUD: translucent dark panels, clipped corners
## and the cyan-white / warning palette. Drawing only; no state lives here.

const ACCENT := Color("73f1ff")
const WARNING := Color("ff4d4d")
const TEXT := Color("e8fbff")
const MUTED := Color(0.62, 0.78, 0.82, 0.9)
const PANEL_FILL := Color(0.015, 0.045, 0.06, 0.74)
const PANEL_LINE := Color(0.45, 0.95, 1.0, 0.5)
const DARK := Color(0.01, 0.03, 0.04, 0.92)


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


static func draw_panel(ci: CanvasItem, rect: Rect2, border: Color, cut := 12.0,
		fill := PANEL_FILL) -> void:
	var points := bevel_points(rect, cut)
	ci.draw_colored_polygon(points, fill)
	var closed := points.duplicate()
	closed.append(points[0])
	ci.draw_polyline(closed, border, 2.0, true)


static func draw_glow(ci: CanvasItem, rect: Rect2, color: Color, cut := 12.0) -> void:
	var points := bevel_points(rect, cut)
	var closed := points.duplicate()
	closed.append(points[0])
	ci.draw_polyline(closed, Color(color, 0.22), 7.0, true)


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
