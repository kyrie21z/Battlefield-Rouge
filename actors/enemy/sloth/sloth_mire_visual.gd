class_name SlothMireVisual
extends SlothRealmVisual
## Uneven shoulders and long resin-encrusted arms separate this silhouette
## from the cloaks, anchors and folded shells.
var _windup := 0.0
var _abdomen: MeshInstance3D

func _build() -> void:
	if _built:
		return
	super._build()
	if is_instance_valid(pulse):
		pulse.free()
		pulse = null
	_crystal.set_shader_parameter("base_color",Color("5e3a1d"))
	_crystal.set_shader_parameter("rim_color",Color("eab154"))
	_crystal.set_shader_parameter("emission_color",Color("a3561b"))
	_crystal.set_shader_parameter("spec_color",Color("ffd289"))
	var resin := _material(Color("d48b29"),0.30,0.32)
	resin.emission_enabled = true
	resin.emission = Color("eba335")
	resin.emission_energy_multiplier = 0.7
	var right := _follow("RightForeArm","ResinClaws")
	var left := _follow("LeftShoulder","CrookedShoulder")
	for i in 4:
		var barb := _plate(right,Vector3(0.65 + i * 0.052,0.97 - i * 0.19,-0.12),Vector3(0.16,0.32,0.15),resin)
		barb.rotation.z = -0.36 - i * 0.14
	for i in 3:
		var rib := _plate(left,Vector3(-0.38 - i * 0.08,1.47 - i * 0.19,0.15),Vector3(0.21,0.39,0.20),_edge)
		rib.rotation.z = 0.69 + i * 0.20
	_abdomen = _sphere(_outfit,Vector3(0.11,1.15,-0.26),0.24,resin)
	_abdomen.scale = Vector3(0.8,1.3,0.7)
	_apply_pose()

func set_windup(progress: float) -> void:
	_windup = progress
	set_cast(progress)

func _apply_pose() -> void:
	if skeleton == null:
		return
	_pose_bone("Spine",Vector3(0.72,1.10,1.20),Vector3(0.27,0.22,-0.28))
	_pose_bone("Head",Vector3(0.72,0.84,0.78),Vector3(-0.26,-0.33,0.36))
	_pose_bone("RightForeArm",Vector3(1.18,1.55,0.91),Vector3(0.48 + _windup,0.0,0.31))
	_pose_bone("LeftForeArm",Vector3(0.83,1.22,0.82),Vector3(-0.45,0.12,-0.38))
	if is_instance_valid(_abdomen):
		_abdomen.scale = Vector3(0.8,1.3,0.7) * (1.0 + _windup * 0.25)

func _pose_bone(bone: String, stretch: Vector3, twist: Vector3) -> void:
	var index := skeleton.find_bone(bone)
	if index >= 0:
		skeleton.set_bone_pose_scale(index,stretch)
		skeleton.set_bone_pose_rotation(index,skeleton.get_bone_rest(index).basis.get_rotation_quaternion() * Quaternion.from_euler(twist))
