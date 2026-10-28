class_name HealthTrail
extends RefCounted

const HOLD := 0.4
const DRAIN := 120.0

var current := 0.0
var delayed := 0.0
var _hold_remaining := 0.0


func reset(value: float) -> void:
	current = value
	delayed = value
	_hold_remaining = 0.0


func advance(value: float, delta: float) -> void:
	if value < current:
		delayed = maxf(delayed, current)
		_hold_remaining = HOLD
	elif value > current:
		delayed = value
		_hold_remaining = 0.0
	current = value
	var drain_time := maxf(0.0, delta - _hold_remaining)
	_hold_remaining = maxf(0.0, _hold_remaining - delta)
	delayed = maxf(current, move_toward(delayed, current, DRAIN * drain_time))
