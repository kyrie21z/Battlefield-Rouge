class_name Crosshair
extends Control
## Centre dot plus four short lines whose gap follows the weapon's current spread.
## The dot is always drawn (it is what you headshot with); the lines can be turned
## off, which is what aiming down iron sights does.

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
## How many times the centre dot has been drawn (tests read this).
var dot_draws := 0

const OUTLINE_COLOR := Color(0, 0, 0, 0.85)


## The gap that is actually drawn.
func drawn_gap() -> float:
	return clampf(gap, min_gap, max_gap)


func _draw() -> void:
	var c := size * 0.5
	if show_lines:
		var g := drawn_gap()
		for dir: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
			var near := c + dir * g
			var far := c + dir * (g + line_length)
			var line := Rect2(near, Vector2.ZERO).expand(far).grow_individual(
				thickness * 0.5 * absf(dir.y), thickness * 0.5 * absf(dir.x),
				thickness * 0.5 * absf(dir.y), thickness * 0.5 * absf(dir.x))
			draw_rect(line.grow(outline), OUTLINE_COLOR)
			draw_rect(line, color)
	# Square dot on whole pixels, so it stays crisp and sits on the true aim point.
	dot_draws += 1
	var dot := Rect2((c - Vector2.ONE * dot_size * 0.5).round(), Vector2.ONE * dot_size)
	draw_rect(dot.grow(outline), OUTLINE_COLOR)
	draw_rect(dot, color)
