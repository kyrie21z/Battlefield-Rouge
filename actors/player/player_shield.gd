class_name PlayerShield
extends Node
## Any skill-school buff unlocks the shield action (G). Stats own every upgradeable number.

signal activated
signal expired

const ACCENT := Color("B36CFF")


## A near-field energy rim gives the shield depth without covering the aim.
## Its clock is driven by PlayerShield, so pause and cancellation stay in sync.
class ShieldFeedback extends Control:
	const COUNTER_DURATION := 0.72
	const IMPACT_DURATION := 0.24
	var active := false
	var charged := false
	var impact_remaining := 0.0
	var counter_remaining := 0.0
	var activation_remaining := 0.0
	var _age := 0.0


	func activate() -> void:
		active = true
		charged = false
		activation_remaining = 0.2
		visible = true
		queue_redraw()


	func absorb(can_counter: bool) -> void:
		impact_remaining = IMPACT_DURATION
		charged = charged or can_counter
		queue_redraw()


	func counter() -> void:
		counter_remaining = COUNTER_DURATION
		charged = false
		visible = true
		queue_redraw()


	func clear() -> void:
		active = false
		charged = false
		impact_remaining = 0.0
		counter_remaining = 0.0
		activation_remaining = 0.0
		visible = false
		queue_redraw()


	func advance(delta: float, shield_active: bool) -> void:
		_age += delta
		active = shield_active
		impact_remaining = maxf(0.0, impact_remaining - delta)
		counter_remaining = maxf(0.0, counter_remaining - delta)
		activation_remaining = maxf(0.0, activation_remaining - delta)
		if not active:
			charged = false
		visible = active or counter_remaining > 0.0
		queue_redraw()


	func _draw() -> void:
		if size.x <= 0.0 or size.y <= 0.0:
			return
		if active:
			_draw_shield()
		if counter_remaining > 0.0:
			_draw_counter()


	func _draw_shield() -> void:
		var center := size * 0.5
		var extent := size * 0.48
		var outline := PackedVector2Array()
		for point in [Vector2(-0.44, -0.94), Vector2(0.44, -0.94),
				Vector2(0.92, -0.56), Vector2(0.92, 0.48), Vector2(0.45, 0.94),
				Vector2(-0.45, 0.94), Vector2(-0.92, 0.48), Vector2(-0.92, -0.56)]:
			outline.append(center + point * extent)
		outline.append(outline[0])
		var impact := impact_remaining / IMPACT_DURATION
		var raised := activation_remaining / 0.2
		var energy := 0.72 + (0.12 * sin(_age * 8.0) if charged else 0.0)
		var light := Color("F0DFFF")
		# Faceted glass between the two rims, rather than a full-screen wash.
		for index in outline.size() - 1:
			var inner_a := center + (outline[index] - center) * 0.94
			var inner_b := center + (outline[index + 1] - center) * 0.94
			draw_colored_polygon(PackedVector2Array([
				outline[index], outline[index + 1], inner_b, inner_a]),
				Color(PlayerShield.ACCENT, 0.15 + impact * 0.14))
		draw_polyline(outline, Color(PlayerShield.ACCENT, 0.10 + impact * 0.12), 42.0, true)
		draw_polyline(outline, Color("5D2A8C"), 16.0, true)
		draw_polyline(outline, Color(PlayerShield.ACCENT, energy), 10.0 + raised * 5.0, true)
		draw_polyline(outline, Color(light, 0.78 + impact * 0.22), 3.0 + impact * 3.0, true)
		var inner := PackedVector2Array()
		for point in outline:
			inner.append(center + (point - center) * 0.94)
		draw_polyline(inner, Color(PlayerShield.ACCENT, 0.35 + impact * 0.4), 3.0, true)


	func _draw_counter() -> void:
		var progress := 1.0 - counter_remaining / COUNTER_DURATION
		_draw_wave(progress, 1.0)
		if progress > 0.14:
			_draw_wave(progress - 0.14, 0.45)


	func _draw_wave(progress: float, strength: float) -> void:
		var center := size * Vector2(0.5, 0.58)
		var extent := size * Vector2(0.6, 0.65) * (0.1 + progress * 1.8)
		var points := PackedVector2Array()
		for index in 97:
			var angle := TAU * float(index) / 96.0
			points.append(center + Vector2(cos(angle), sin(angle)) * extent)
		var alpha := strength * (1.0 - progress)
		draw_polyline(points, Color(PlayerShield.ACCENT, alpha * 0.18), 38.0, true)
		draw_polyline(points, Color(PlayerShield.ACCENT, alpha * 0.85), 12.0, true)
		draw_polyline(points, Color("F0DFFF", alpha), 3.0, true)


@export var stats: Stats
@export var health: Health

var cooldown_remaining := 0.0
var active_remaining := 0.0
var _overlay := ShieldFeedback.new()


func _ready() -> void:
	var layer := CanvasLayer.new()
	layer.name = "ShieldFeedback"
	# Keep the rim behind the HUD's readable labels, above the world.
	layer.layer = 0
	add_child(layer)
	layer.add_child(_overlay)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.name = "ShieldRim"
	_overlay.visible = false
	health.blocked.connect(_on_blocked)


func is_unlocked() -> bool:
	return stats.get_value(Stats.SKILL_UNLOCKED) > 0.0


func is_active() -> bool:
	return active_remaining > 0.0


func cooldown_duration() -> float:
	return maxf(0.5, stats.get_value(Stats.SHIELD_COOLDOWN))


## Death clears the shield without expiring it into a counterattack.
func cancel() -> void:
	active_remaining = 0.0
	cooldown_remaining = 0.0
	health.invulnerable = false
	_overlay.clear()


func try_activate() -> bool:
	if not is_unlocked() or cooldown_remaining > 0.0 or health.is_dead():
		return false
	active_remaining = maxf(0.1, stats.get_value(Stats.SHIELD_DURATION))
	cooldown_remaining = active_remaining + cooldown_duration()
	health.invulnerable = true
	_overlay.activate()
	activated.emit()
	return true


## Only the successful damaging counter calls this; an unused shield fades out.
func show_counter_pulse() -> void:
	if not health.is_dead():
		_overlay.counter()


func _on_blocked(amount: float, _source: Node) -> void:
	if is_active() and amount > 0.0:
		_overlay.absorb(stats.get_value(Stats.SHIELD_PULSE_DAMAGE) > 0.0)


func _process(delta: float) -> void:
	var was_active := is_active()
	cooldown_remaining = maxf(0.0, cooldown_remaining - delta)
	active_remaining = maxf(0.0, active_remaining - delta)
	health.invulnerable = is_active()
	_overlay.advance(delta, is_active())
	if was_active and not is_active():
		expired.emit()
	if Input.is_action_just_pressed("shield") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		try_activate()
