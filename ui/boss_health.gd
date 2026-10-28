class_name BossHealth
extends Control

var boss: Enemy
var displayed_health := 0.0
var delayed_health := 0.0
var max_health := 1.0
var health_text := ""
var fallen := false
var fill_color := HudStyle.WARNING
var _trail := HealthTrail.new()


func setup(target: Enemy) -> void:
	boss = target
	visible = is_instance_valid(boss)
	if not visible:
		return
	_trail.reset(boss.health.health)
	boss.health.damaged.connect(_on_damaged)
	advance(0.0)


func _on_damaged(_amount: float, _part: Hitbox.BodyPart, _source: Node) -> void:
	advance(0.0)


func _process(delta: float) -> void:
	advance(delta)


func advance(delta: float) -> void:
	if not is_instance_valid(boss):
		return
	var health := boss.health
	_trail.advance(health.health, delta)
	displayed_health = _trail.current
	delayed_health = _trail.delayed
	max_health = maxf(health.max_health, 1.0)
	fallen = health.is_dead()
	fill_color = CapturePoint.COLOR_LOCKED if fallen else HudStyle.WARNING
	health_text = "已倒下" if fallen else "%d / %d" % [ceili(displayed_health), ceili(max_health)]
	queue_redraw()


func _draw() -> void:
	HudStyle.draw_panel(self, Rect2(Vector2.ZERO, size), fill_color)
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(18.0, 30.0), "Boss", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, fill_color)
	draw_string(font, Vector2(size.x - 218.0, 30.0), health_text,
		HORIZONTAL_ALIGNMENT_RIGHT, 200.0, 22, HudStyle.TEXT if not fallen else fill_color)
	var bar := Rect2(18.0, 42.0, size.x - 36.0, 20.0)
	draw_rect(bar, Color(0.0, 0.0, 0.0, 0.65))
	var current_width := bar.size.x * clampf(displayed_health / max_health, 0.0, 1.0)
	var delayed_width := bar.size.x * clampf(delayed_health / max_health, 0.0, 1.0)
	draw_rect(Rect2(bar.position, Vector2(current_width, bar.size.y)), fill_color)
	if delayed_width > current_width:
		draw_rect(Rect2(bar.position + Vector2(current_width, 0.0),
			Vector2(delayed_width - current_width, bar.size.y)),
			CapturePoint.COLOR_LOCKED if fallen else Color.WHITE)
