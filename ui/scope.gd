class_name ScopeReticle
extends Control
## The reticle of the sniper scope: a full-screen crosshair with mil ticks and the
## magnification readout. There is deliberately **no mask**: an early version drew a
## black surround with a round window, then an ellipse filling the frame, and both
## ate screen the player was trying to aim with. Now the glass is the whole viewport
## — the zoom and the reticle are what tell the player the scope is up, plus the HUD
## hiding its normal crosshair.

const RETICLE_COLOR := Color(0.05, 0.05, 0.06, 0.92)
const TICK_COLOR := Color(0.05, 0.05, 0.06, 0.7)

## Magnification of the scope in hand. Drives the readout and the tick spacing.
var zoom := 2.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var centre := size * 0.5
	var gap := minf(size.x, size.y) * 0.022

	# Crosshair arms run off the screen: nothing frames the view.
	draw_line(Vector2(0.0, centre.y), Vector2(centre.x - gap, centre.y), RETICLE_COLOR, 2.0)
	draw_line(Vector2(centre.x + gap, centre.y), Vector2(size.x, centre.y), RETICLE_COLOR, 2.0)
	draw_line(Vector2(centre.x, 0.0), Vector2(centre.x, centre.y - gap), RETICLE_COLOR, 2.0)
	draw_line(Vector2(centre.x, centre.y + gap), Vector2(centre.x, size.y), RETICLE_COLOR, 2.0)
	draw_circle(centre, 2.2, RETICLE_COLOR)

	# Mil ticks: closer together as the magnification goes up, the way a zoomed
	# reticle looks smaller against the world.
	var spacing := size.y * 0.055 * (2.0 / maxf(zoom, 1.0)) + size.y * 0.02
	var index := 1
	var offset := spacing
	while offset < size.y * 0.48:
		var length := size.y * (0.008 if index % 2 == 0 else 0.014)
		for sign_y in [-1.0, 1.0]:
			var y: float = centre.y + offset * sign_y
			draw_line(Vector2(centre.x - length, y), Vector2(centre.x + length, y), TICK_COLOR, 2.0)
		# Matching marks on the horizontal arms, so the reticle is symmetric.
		var side := size.y * (0.006 if index % 2 == 0 else 0.01)
		for sign_x in [-1.0, 1.0]:
			var x: float = centre.x + offset * sign_x
			if x > 0.0 and x < size.x:
				draw_line(Vector2(x, centre.y - side), Vector2(x, centre.y + side), TICK_COLOR, 2.0)
		offset += spacing
		index += 1

	# Readout under the middle of the view: magnification and how to change it, on
	# a dark pill so it stays legible against snow and sky alike.
	var font := ThemeDB.fallback_font
	if font == null:
		return
	var label := "%.0f×  ·  滚轮换倍率" % zoom
	var text_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 18)
	var origin := centre + Vector2(-text_size.x * 0.5, size.y * 0.22)
	draw_rect(Rect2(origin - Vector2(10.0, text_size.y * 0.85),
		text_size + Vector2(20.0, text_size.y * 1.1)), Color(0.0, 0.0, 0.0, 0.55))
	draw_string(font, origin + Vector2(0.0, text_size.y * 0.2), label,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.92, 0.96, 1.0, 0.95))
