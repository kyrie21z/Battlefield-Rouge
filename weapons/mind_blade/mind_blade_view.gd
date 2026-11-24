class_name MindBladeView
extends Node3D

const OBSIDIAN_MATERIAL := preload("res://assets/materials/obsidian_weapon_material.tres")


func _ready() -> void:
	for piece_name in ["blade", "grip"]:
		var piece := $Model.find_child(piece_name, true, false) as MeshInstance3D
		if piece != null:
			piece.material_override = OBSIDIAN_MATERIAL
