class_name PlayerShield
extends Node
## Any skill-school buff unlocks the shield action (G). Stats own every upgradeable number.

signal activated
signal expired

const ACCENT := Color("B36CFF")

@export var stats: Stats
@export var health: Health

var cooldown_remaining := 0.0
var active_remaining := 0.0
var _overlay := ColorRect.new()


func _ready() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 2
	add_child(layer)
	layer.add_child(_overlay)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.color = Color(ACCENT, 0.15)
	_overlay.visible = false


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
	_overlay.visible = false


func try_activate() -> bool:
	if not is_unlocked() or cooldown_remaining > 0.0 or health.is_dead():
		return false
	active_remaining = maxf(0.1, stats.get_value(Stats.SHIELD_DURATION))
	cooldown_remaining = active_remaining + cooldown_duration()
	health.invulnerable = true
	_overlay.visible = true
	activated.emit()
	return true


func _process(delta: float) -> void:
	var was_active := is_active()
	cooldown_remaining = maxf(0.0, cooldown_remaining - delta)
	active_remaining = maxf(0.0, active_remaining - delta)
	health.invulnerable = is_active()
	_overlay.visible = is_active()
	if was_active and not is_active():
		expired.emit()
	if Input.is_action_just_pressed("shield") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		try_activate()
