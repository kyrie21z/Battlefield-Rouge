class_name CrystalCombatFeedback
extends Node
## Bound by the player. Reads real resolved action events, never runs damage.
var player: Player
var bursts := 0
func bind(value: Player) -> void:
	player = value
	player.boons.event_dispatched.connect(_event)
func _event(event: StringName, context: Dictionary) -> void:
	var sin := -1
	match event:
		&"sloth_burst": sin = 0
		&"fear_flaw_broken": sin = 1
		&"wall_slam": sin = 2
		&"sorrow_tear_broken", &"sorrow_tear_collected": sin = 3
	if sin < 0 or not context.has("position") or not is_instance_valid(player):
		return
	if CrystalBurst.spawn(player.get_parent(),context.position,sin,event,context.get("normal",Vector3.UP) if event == &"wall_slam" else context.get("direction",Vector3.UP)) != null:
		bursts += 1
