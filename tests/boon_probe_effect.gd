extends BoonEffect
var counts: Dictionary = {}
var prevent_damage := false

func on_event(event: StringName, context: Dictionary) -> void:
	counts[event] = int(counts.get(event, 0)) + 1
	if event == &"hit_before" and context.kind == &"gun":
		context.damage += 7.0
	if event == &"damage_before" and prevent_damage:
		context.cancelled = true
