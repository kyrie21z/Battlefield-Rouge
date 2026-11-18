extends RefCounted
## The Blender shapes use the existing hand bones and preserve the shared body rig.

const GRIPS := preload("res://assets/models/characters/protagonist_hands.glb")
const FOREARMS := ["GEO_m_forearm_R", "GEO_m_forearm_L"]
static var _arms: Dictionary = {}
static var _hands: Dictionary = {}


static func install_forearms(model: Node3D) -> void:
	if _arms.is_empty():
		var geometry := GRIPS.instantiate()
		for name: String in FOREARMS:
			var arm := geometry.find_child(name, true, false) as MeshInstance3D
			var original := model.find_child(name, true, false) as MeshInstance3D
			var bind_poses: Dictionary = {}
			for bind in original.skin.get_bind_count():
				bind_poses[original.skin.get_bind_name(bind)] = original.skin.get_bind_pose(bind)
			# Use the exported vertex indices with the gameplay rig's authored
			# inverse binds. Blender often reorients the glTF joint axes on export.
			var skin := Skin.new()
			for bind in arm.skin.get_bind_count():
				var bone := arm.skin.get_bind_name(bind)
				skin.add_named_bind(bone, bind_poses[bone])
			_arms[name] = {"mesh": arm.mesh, "skin": skin}
		for side in ["Right", "Left"]:
			var hand := geometry.find_child(side + "Grip", true, false) as MeshInstance3D
			_hands[side] = hand.mesh
		geometry.free()
	for name: String in FOREARMS:
		var arm := model.find_child(name, true, false) as MeshInstance3D
		arm.mesh = _arms[name].mesh
		arm.skin = _arms[name].skin


static func hand_mesh(side: String) -> ArrayMesh:
	return _hands[side]


static func set_blade_weight(mesh: MeshInstance3D, weight: float) -> void:
	var shape := mesh.find_blend_shape_by_name(&"BladeGrip")
	if shape >= 0:
		mesh.set_blend_shape_value(shape, weight)
