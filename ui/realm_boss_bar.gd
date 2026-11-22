class_name RealmBossBar
extends Control

const SHAKE_TIME := 0.12
const SHAKE_PIXELS := 4.0
const TRACK_COLOR := Color(0.06, 0.06, 0.07, 0.85)

var trail := HealthTrail.new()
var shake_offset := 0.0
var value: float:
	get: return trail.current
var max_value: float:
	get: return _health.max_health if is_instance_valid(_health) else 1.0

var _health: Health
var _fill_color: Color
var _shake_left := 0.0


func setup(health: Health, accent: Color) -> void:
	_health = health
	_fill_color = accent
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = is_instance_valid(_health) and not _health.is_dead()
	set_process(visible)
	if visible:
		trail.reset(_health.health)
		_health.damaged.connect(_on_damaged)
		_health.died.connect(_on_died)


func _on_damaged(_amount: float, _part: Hitbox.BodyPart, _source: Node) -> void:
	if not get_tree().paused and not _health.is_dead():
		_advance(0.0)


func _on_died(_source: Node) -> void:
	hide()
	set_process(false)
	_shake_left = 0.0
	shake_offset = 0.0


func _process(delta: float) -> void:
	if not is_instance_valid(_health) or _health.is_dead():
		_on_died(null)
		return
	_advance(delta)


func _advance(delta: float) -> void:
	_shake_left = maxf(_shake_left - delta, 0.0)
	if _health.health < trail.current:
		_shake_left = SHAKE_TIME
	trail.advance(_health.health, delta)
	var fraction := _shake_left / SHAKE_TIME
	shake_offset = SHAKE_PIXELS * fraction * cos(TAU * 2.0 * (1.0 - fraction))
	queue_redraw()


func _draw() -> void:
	if not is_instance_valid(_health):
		return
	var origin := Vector2(shake_offset, 0)
	var max_health := maxf(max_value, 1.0)
	var current_width := size.x * clampf(trail.current / max_health, 0.0, 1.0)
	var delayed_width := size.x * clampf(trail.delayed / max_health, 0.0, 1.0)
	draw_rect(Rect2(origin, size), TRACK_COLOR)
	draw_rect(Rect2(origin, Vector2(current_width, size.y)), _fill_color)
	if delayed_width > current_width:
		draw_rect(Rect2(origin + Vector2(current_width, 0), Vector2(delayed_width - current_width, size.y)), Color.WHITE)
