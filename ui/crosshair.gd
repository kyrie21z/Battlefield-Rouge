class_name Crosshair
extends Control
## Crosshair with four selectable styles. The dot is what you headshot with;
## the lines can be turned off, which is what aiming down iron sights does.
## The game defaults to CROSS_DOT, which is the look before the settings menu.

enum Style { CROSS, CROSS_DOT, DOT, RING }

@export var style := Style.CROSS_DOT
@export var line_length := 5.0
@export var thickness := 1.5
@export var color := Color(1, 1, 1, 0.9)
## Side of the centre dot, and the width of the dark outline around it (pixels).
@export var dot_size := 3.0
@export var outline := 1.0
## Smallest and largest gap that is ever drawn. The real spread can bloom far past
## the maximum while moving or in the air; the lines stop at the maximum.
@export var min_gap := 2.0
@export var max_gap := 24.0

## The spread projected onto the screen in pixels, set by the HUD every frame.
var gap := 2.0
var show_lines := true
var focused := false
## How many times each part has been drawn (tests read these).
var dot_draws := 0
var line_draws := 0
var ring_draws := 0

const OUTLINE_COLOR := Color(0, 0, 0, 0.85)
const RING_RADIUS := 9.0
## The line length the ring radius is sized against (the default).
const RING_BASE_LENGTH := 5.0


## The gap that is actually drawn.
func drawn_gap() -> float:
	return clampf(gap, min_gap, max_gap)


func _draw() -> void:
	var c := size * 0.5
	if focused:
		var diamond := PackedVector2Array([c + Vector2(0, -4), c + Vector2(4, 0),
			c + Vector2(0, 4), c + Vector2(-4, 0), c + Vector2(0, -4)])
		draw_polyline(diamond, OUTLINE_COLOR, thickness + 2.0, true)
		draw_polyline(diamond, color, thickness, true)
		return
	match style:
		Style.CROSS:
			# Iron sights hide the lines; keep the dot so the aim point never vanishes.
			if show_lines:
				_draw_lines(c)
			else:
				_draw_dot(c)
		Style.CROSS_DOT:
			if show_lines:
				_draw_lines(c)
			_draw_dot(c)
		Style.DOT:
			_draw_dot(c)
		Style.RING:
			_draw_ring(c)


func _draw_lines(c: Vector2) -> void:
	line_draws += 1
	var g := drawn_gap()
	for dir: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		var near := c + dir * g
		var far := c + dir * (g + line_length)
		var line := Rect2(near, Vector2.ZERO).expand(far).grow_individual(
			thickness * 0.5 * absf(dir.y), thickness * 0.5 * absf(dir.x),
			thickness * 0.5 * absf(dir.y), thickness * 0.5 * absf(dir.x))
		draw_rect(line.grow(outline), OUTLINE_COLOR)
		draw_rect(line, color)


func _draw_dot(c: Vector2) -> void:
	dot_draws += 1
	# Square dot on whole pixels, so it stays crisp and sits on the true aim point.
	var dot := Rect2((c - Vector2.ONE * dot_size * 0.5).round(), Vector2.ONE * dot_size)
	draw_rect(dot.grow(outline), OUTLINE_COLOR)
	draw_rect(dot, color)


func _draw_ring(c: Vector2) -> void:
	ring_draws += 1
	# Scales with the size setting (line_length) and opens with the spread gap.
	var radius := maxf(RING_RADIUS * line_length / RING_BASE_LENGTH, drawn_gap() + thickness)
	draw_arc(c, radius, 0.0, TAU, 48, OUTLINE_COLOR, thickness + outline * 2.0, true)
	draw_arc(c, radius, 0.0, TAU, 48, color, thickness, true)
