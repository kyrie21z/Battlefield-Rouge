class_name BoonHitstop
extends Node
## Presentation only: semantic boon impacts share the HUD's fixture-safe hitstop.
const IMPACTS: Array[StringName] = [&"sloth_burst", &"fear_flaw_broken", &"wall_slam"]
var _player: Player

static func attach(hud: Node, player: Player) -> BoonHitstop:
	var feedback := BoonHitstop.new()
	feedback._player = player
	hud.add_child(feedback)
	return feedback

func _ready() -> void:
	_player.boons.event_dispatched.connect(_on_impact)

func _on_impact(event: StringName, _context: Dictionary) -> void:
	if not IMPACTS.has(event) or RunState.fixture != null:
		return
	if get_tree().paused or not is_instance_valid(_player) or _player.health.is_dead():
		return
	HitStop.request(get_tree(), 0.04)
