class_name Vitals
extends Control
## Bottom-left health panel: segmented bar, the white chip-damage trail, the
## shield duration strip and the low-health warning border. Reads the player only.

const SEGMENTS := 12
const DELAY_HOLD := 0.4
const DELAY_DRAIN := 120.0
const LOW_FRACTION := 0.3
const BAR_RECT := Rect2(92.0, 26.0, 232.0, 44.0)

var player: Player
var displayed_health := 0.0
var delayed_health := 0.0
var max_health := 100.0
var health_number := 0
var warning := false
var shield_visible := false
var shield_fraction := 0.0

var _last_health := 0.0
var _delay_timer := 0.0
var _pulse := 0.0


func setup(owner: Player) -> void:
	player = owner
	var health := player.health
	_last_health = health.health
	displayed_health = health.health
	delayed_health = health.health
	max_health = maxf(health.max_health, 1.0)
	advance(0.0)


func _process(delta: float) -> void:
	advance(delta)


func advance(delta: float) -> void:
	_pulse += delta
	if player == null:
		return
	var health := player.health
	var current := health.health
	max_health = maxf(health.max_health, 1.0)
	if current < _last_health:
		delayed_health = maxf(delayed_health, _last_health)
		_delay_timer = DELAY_HOLD
	elif current > _last_health:
		delayed_health = current
		_delay_timer = 0.0
	_last_health = current
	displayed_health = current
	health_number = ceili(current)
	var drain_time := delta
	if _delay_timer > 0.0:
		drain_time = maxf(0.0, delta - _delay_timer)
		_delay_timer = maxf(0.0, _delay_timer - delta)
	if drain_time > 0.0:
		delayed_health = move_toward(delayed_health, current, DELAY_DRAIN * drain_time)
	delayed_health = maxf(delayed_health, current)
	warning = current > 0.0 and current / max_health < LOW_FRACTION

	var shield := player.shield
	shield_visible = shield != null and shield.is_active()
	shield_fraction = 0.0
	if shield_visible:
		var duration := maxf(player.stats.get_value(Stats.SHIELD_DURATION), 0.01)
		shield_fraction = clampf(shield.active_remaining / duration, 0.0, 1.0)
	queue_redraw()


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	var border := HudStyle.PANEL_LINE
	if warning:
		var blink := 0.55 + 0.45 * sin(_pulse * 11.0)
		border = Color(HudStyle.WARNING, blink)
	HudStyle.draw_panel(self, rect, border)

	var font := ThemeDB.fallback_font
	var number_color := HudStyle.WARNING if warning else HudStyle.TEXT
	draw_string(font, Vector2(16.0, BAR_RECT.position.y + BAR_RECT.size.y * 0.5 + 11.0),
		str(health_number), HORIZONTAL_ALIGNMENT_LEFT, -1, 32, number_color)

	if shield_visible:
		var strip := Rect2(BAR_RECT.position.x, BAR_RECT.position.y - 16.0, BAR_RECT.size.x, 6.0)
		draw_rect(strip, Color(0.0, 0.0, 0.0, 0.55))
		draw_rect(Rect2(strip.position, Vector2(strip.size.x * shield_fraction, strip.size.y)),
			HudStyle.ACCENT)
		draw_line(strip.position, Vector2(strip.end.x, strip.position.y),
			Color(HudStyle.ACCENT, 0.45), 2.0, true)

	draw_rect(BAR_RECT, Color(0.0, 0.0, 0.0, 0.55))
	var gap := 3.0
	var segment_width := (BAR_RECT.size.x - gap * float(SEGMENTS - 1)) / float(SEGMENTS)
	var health_x := BAR_RECT.position.x + BAR_RECT.size.x * clampf(displayed_health / max_health, 0.0, 1.0)
	var delayed_x := BAR_RECT.position.x + BAR_RECT.size.x * clampf(delayed_health / max_health, 0.0, 1.0)
	var fill_color := HudStyle.WARNING if warning else HudStyle.ACCENT
	for i in SEGMENTS:
		var cell := Rect2(BAR_RECT.position.x + float(i) * (segment_width + gap),
			BAR_RECT.position.y, segment_width, BAR_RECT.size.y)
		draw_rect(cell, Color(0.04, 0.10, 0.12, 0.9))
		var filled_end := clampf(health_x, cell.position.x, cell.end.x)
		if filled_end > cell.position.x:
			draw_rect(Rect2(cell.position, Vector2(filled_end - cell.position.x, cell.size.y)),
				fill_color)
		var trail_start := maxf(cell.position.x, health_x)
		var trail_end := clampf(delayed_x, cell.position.x, cell.end.x)
		if trail_end > trail_start:
			draw_rect(Rect2(Vector2(trail_start, cell.position.y),
				Vector2(trail_end - trail_start, cell.size.y)), Color(0.95, 0.98, 1.0, 0.9))
