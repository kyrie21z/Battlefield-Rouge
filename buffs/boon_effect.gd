class_name BoonEffect
extends RefCounted
## One instance per script, even when several cards share the same effect.
var manager: BoonManager

func setup(value: BoonManager) -> void:
	manager = value

func on_event(_event: StringName, _context: Dictionary) -> void:
	pass

func tick(_delta: float) -> void:
	pass

func cleanup() -> void:
	pass
