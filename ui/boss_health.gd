class_name BossHealth
extends Control
## Legacy zone boss health bar upgraded to Scheme B (Architectural Editorial).
## Preserves all fields & layout contracts tested by hud_test.gd and boss_test.gd.

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
	var rect := Rect2(Vector2.ZERO, size)
	var header_h := minf(34.0, size.y * 0.52)

	# Hard architectural shadow + ivory body + carbon top header
	draw_rect(Rect2(Vector2(4.0, 4.0), size), Color(EditorialStyle.INK, 0.80))
	draw_rect(rect, EditorialStyle.PAPER)
	draw_rect(Rect2(Vector2.ZERO, Vector2(size.x, header_h)), EditorialStyle.INK)

	# Left accent strip inside carbon header
	draw_rect(Rect2(12.0, 8.0, 4.0, header_h - 16.0), fill_color)

	var title_font := EditorialStyle.font_sans(800, 2)
	var mono_font := EditorialStyle.font_mono(700, 1)
	draw_string(title_font, Vector2(24.0, header_h - 10.0), "BOSS",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 18, EditorialStyle.PAPER)
	draw_string(mono_font, Vector2(size.x - 216.0, header_h - 10.0), health_text,
		HORIZONTAL_ALIGNMENT_RIGHT, 200.0, 17, EditorialStyle.PAPER if not fallen else EditorialStyle.ASH)

	# Crisp ruler track on ivory lower half
	var bar := Rect2(12.0, header_h + 7.0, size.x - 24.0, maxf(size.y - header_h - 14.0, 10.0))
	draw_rect(bar, EditorialStyle.PAPER_TRACK)
	var current_width := bar.size.x * clampf(displayed_health / max_health, 0.0, 1.0)
	var delayed_width := bar.size.x * clampf(delayed_health / max_health, 0.0, 1.0)
	if current_width > 0.0:
		draw_rect(Rect2(bar.position, Vector2(current_width, bar.size.y)), fill_color)
	if delayed_width > current_width:
		draw_rect(Rect2(bar.position + Vector2(current_width, 0.0),
			Vector2(delayed_width - current_width, bar.size.y)),
			CapturePoint.COLOR_LOCKED if fallen else Color(EditorialStyle.INK, 0.40))
	for q in range(1, 4):
		var tx := bar.position.x + bar.size.x * (float(q) * 0.25)
		draw_line(Vector2(tx, bar.position.y), Vector2(tx, bar.position.y + bar.size.y),
			Color(EditorialStyle.INK, 0.25), 1.0)
	draw_rect(bar, EditorialStyle.INK, false, 1.5)
	draw_rect(rect, EditorialStyle.INK, false, 2.0)
