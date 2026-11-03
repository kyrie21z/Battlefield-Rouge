class_name BuffPedestal
extends Node3D
## Grey box beside the planted flag. The zone director opens the clear-buff
## offer when the player presses interact inside INTERACT_RANGE.

const INTERACT_RANGE := 2.4

var _label: Label3D


func _ready() -> void:
	add_to_group("buff_pedestal")
	var body := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.9, 1.15, 0.9)
	body.mesh = box
	body.position.y = 0.575
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.32, 0.72, 0.48)
	body.material_override = material
	add_child(body)
	_label = Label3D.new()
	_label.text = "按 %s 领取增益" % KeyHint.of("interact")
	_label.font_size = 48
	_label.pixel_size = 0.0045
	_label.position = Vector3(0.0, 1.85, 0.0)
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.modulate = Color(0.92, 1.0, 0.88)
	_label.outline_size = 8
	add_child(_label)


func in_range(body: Node3D) -> bool:
	return global_position.distance_to(body.global_position) <= INTERACT_RANGE
