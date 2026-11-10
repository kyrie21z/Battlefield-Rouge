class_name ObsidianPistolView
extends Node3D
## Static flat-shaded pistol; crystal reassembly is introduced in issue #102.
const SOURCE_POLYGONS := 120
const BODY_TRIANGLES := 180
var _pieces: Array[Node3D] = []
var _rest: Array[Transform3D] = []

func _ready() -> void:
	for piece_name in ["barrel_block", "slide_block", "grip_block", "core_crystal"]:
		var piece := $Model.find_child(piece_name, true, false) as MeshInstance3D
		piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_pieces.append(piece)
		_rest.append(piece.transform)
