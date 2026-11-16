class_name BuffPedestal
extends Node3D
## The clear-reward pickup beside the planted flag. The zone director opens the
## clear-buff offer when the player presses interact inside INTERACT_RANGE.
##
## The grey box that used to live here is replaced by the reclaimed-talent orb:
## a plated sphere that keeps its mouth turned toward the player, with a framed
## cube spinning inside. Position, interaction range and the reward-theme API are
## unchanged, so zone_director, world_marker, minimap and the HUD tests keep
## working as-is.

const INTERACT_RANGE := 2.4

var _label: Label3D
var _orb: TalentOrb
var _player_ref: WeakRef


func _ready() -> void:
	add_to_group("buff_pedestal")

	_orb = TalentOrb.new()
	_orb.name = "TalentOrb"
	add_child(_orb)

	var player := _player_ref.get_ref() as Node3D if _player_ref != null else null
	if player != null and is_instance_valid(player):
		_orb.set_player(player)

	_label = Label3D.new()
	_label.text = "按 %s 取回天赋" % KeyHint.of("interact")
	_label.font_size = 48
	_label.pixel_size = 0.0045
	_label.position = Vector3(0.0, 2.05, 0.0)
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.modulate = Color(0.92, 1.0, 0.88)
	_label.outline_size = 8
	add_child(_label)


## Injected by the zone director so the orb can face the player without
## searching the tree or reading RunState.
func set_player(player: Node3D) -> void:
	_player_ref = weakref(player)
	if _orb != null:
		_orb.set_player(player)


func in_range(body: Node3D) -> bool:
	return global_position.distance_to(body.global_position) <= INTERACT_RANGE


func show_reward_theme(accent: Color) -> void:
	_label.hide()
	if _orb != null:
		_orb.set_accent(accent)
