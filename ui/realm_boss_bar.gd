class_name RealmBossBar
extends Control
## Architectural ruler boss health bar (Scheme B):
## Ivory paper track framed in sharp carbon ink, realm accent fill, and dark cut trail.

const SHAKE_TIME := 0.12
const SHAKE_PIXELS := 4.0
const TRACK_COLOR := Color("f6f4eef2")

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
	var origin := Vector2(shake_offset, 0.0)
	var max_health := maxf(max_value, 1.0)
	var inner_origin := origin + Vector2(2.0, 2.0)
	var inner_size := Vector2(maxf(size.x - 4.0, 1.0), maxf(size.y - 4.0, 1.0))
	var current_width := inner_size.x * clampf(trail.current / max_health, 0.0, 1.0)
	var delayed_width := inner_size.x * clampf(trail.delayed / max_health, 0.0, 1.0)

	# Hard offset shadow + ivory ruler track
	draw_rect(Rect2(origin + Vector2(3.0, 3.0), size), Color(EditorialStyle.INK, 0.72))
	draw_rect(Rect2(origin, size), TRACK_COLOR)
	# Realm accent fill
	if current_width > 0.0:
		draw_rect(Rect2(inner_origin, Vector2(current_width, inner_size.y)), _fill_color)
	# Delayed damage cut in translucent carbon ink for high contrast on paper
	if delayed_width > current_width:
		draw_rect(Rect2(inner_origin + Vector2(current_width, 0.0),
			Vector2(delayed_width - current_width, inner_size.y)),
			Color(EditorialStyle.INK, 0.35))
	# Crisp quarter divisions
	for q in range(1, 4):
		var tx := inner_origin.x + inner_size.x * (float(q) * 0.25)
		draw_line(Vector2(tx, inner_origin.y), Vector2(tx, inner_origin.y + inner_size.y),
			Color(EditorialStyle.INK, 0.22), 1.0)
	# Sharp outer ink border
	draw_rect(Rect2(origin, size), EditorialStyle.INK, false, 2.0)
