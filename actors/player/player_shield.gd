class_name PlayerShield
extends Node
## Any skill-school buff unlocks the shield action (G). Stats own every upgradeable number.

signal activated
signal expired
signal counter_released(absorbed: float)
signal absorbed_hit(amount: float)

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
var last_released_damage := 0.0
var last_release_automatic := false
var _counter_active := false
var _absorbed := 0.0
var _pending_auto_release := 0.0
var _owns_invulnerability := false
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
	health.damage_absorber = _absorb_damage
	health.damage_resolved.connect(_on_damage_resolved)
	stats.changed.connect(_on_stats_changed)


func is_unlocked() -> bool:
	return stats.get_value(Stats.SKILL_UNLOCKED) > 0.0


func is_active() -> bool:
	return _counter_active or active_remaining > 0.0


func is_counter_mode() -> bool:
	return stats.get_value(Stats.SHIELD_REFLECT_MULTIPLIER) > 0.0


func capacity() -> float:
	return maxf(1.0, stats.get_value(Stats.SHIELD_CAPACITY))


func absorbed_damage() -> float:
	return _absorbed


func charge_fraction() -> float:
	return clampf(_absorbed / capacity(), 0.0, 1.0)


func cooldown_duration() -> float:
	return maxf(0.5, stats.get_value(Stats.SHIELD_COOLDOWN))


## Death clears the shield without expiring it into a counterattack.
func cancel() -> void:
	active_remaining = 0.0
	_counter_active = false
	_absorbed = 0.0
	_pending_auto_release = 0.0
	last_released_damage = 0.0
	cooldown_remaining = 0.0
	_set_timed_protection(false)
	_overlay.clear()


func try_activate() -> bool:
	if get_tree().paused or health.is_dead() or health.unbuffered:
		return false
	if _counter_active:
		return try_release()
	if not is_unlocked() or is_active() or cooldown_remaining > 0.0:
		return false
	_absorbed = 0.0
	_pending_auto_release = 0.0
	last_released_damage = 0.0
	_counter_active = is_counter_mode()
	if _counter_active:
		active_remaining = 0.0
		cooldown_remaining = 0.0
	else:
		active_remaining = maxf(0.1, stats.get_value(Stats.SHIELD_DURATION))
		cooldown_remaining = active_remaining + cooldown_duration()
		_set_timed_protection(true)
	_overlay.activate()
	activated.emit()
	return true


## The same action raises the shield and releases an already raised counter.
func try_release() -> bool:
	if get_tree().paused or not _counter_active or health.is_dead():
		return false
	_end_counter(false)
	_emit_counter(last_released_damage)
	return true


## Health calls this only after team/parry/independent immunity filtering and
## body multipliers. It resolves HP overflow before allowing the auto pulse.
func _absorb_damage(amount: float) -> float:
	if not _counter_active or health.is_dead() or amount <= 0.0:
		return amount
	var accepted := minf(amount, maxf(0.0, capacity() - _absorbed))
	_absorbed += accepted
	if _absorbed >= capacity():
		_end_counter(true)
		_pending_auto_release = last_released_damage
	if accepted > 0.0:
		if _counter_active:
			_overlay.absorb(true)
		absorbed_hit.emit(accepted)
	return amount - accepted


func _end_counter(automatic: bool) -> void:
	last_released_damage = _absorbed
	last_release_automatic = automatic
	_counter_active = false
	_absorbed = 0.0
	cooldown_remaining = cooldown_duration()
	_overlay.advance(0.0, false)


func _on_damage_resolved() -> void:
	if _pending_auto_release <= 0.0:
		return
	var absorbed := _pending_auto_release
	_pending_auto_release = 0.0
	if not health.is_dead():
		_emit_counter(absorbed)


func _emit_counter(absorbed: float) -> void:
	# State is already consumed before callbacks can try to release it again.
	if absorbed > 0.0:
		counter_released.emit(absorbed)
	expired.emit()


func _set_timed_protection(active: bool) -> void:
	if active:
		health.invulnerable = true
		_owns_invulnerability = true
	elif _owns_invulnerability:
		health.invulnerable = false
		_owns_invulnerability = false


func _on_stats_changed() -> void:
	if not is_unlocked() or (_counter_active and not is_counter_mode()):
		cancel()


func _exit_tree() -> void:
	if is_instance_valid(health) and health.damage_absorber == Callable(self, "_absorb_damage"):
		health.damage_absorber = Callable()


## Only the successful damaging counter calls this; an unused shield fades out.
func show_counter_pulse() -> void:
	if not health.is_dead():
		_overlay.counter()


func _on_blocked(amount: float, _source: Node) -> void:
	if active_remaining > 0.0 and amount > 0.0 and not health.dash_invulnerable:
		_overlay.absorb(false)


func _process(delta: float) -> void:
	var was_timed := active_remaining > 0.0
	cooldown_remaining = maxf(0.0, cooldown_remaining - delta)
	active_remaining = maxf(0.0, active_remaining - delta)
	_set_timed_protection(active_remaining > 0.0)
	_overlay.advance(delta, is_active())
	if was_timed and not is_active():
		expired.emit()
	if Input.is_action_just_pressed("shield") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		try_activate()
