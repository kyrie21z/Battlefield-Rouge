class_name SlothRealmVisual
extends SlothVisual
## Uses the original skinned body; only this instance's material and bone scales change.
var realm_shatter: SlothRealmShatter
var pulse: MeshInstance3D
var armor: Array[MeshInstance3D] = []
var boss_form := false

func _build() -> void:
	if _built:
		return
	super._build()
	_bones.clear()
	_shell.clear()
	_outfit.free()
	_outfit = Node3D.new()
	_outfit.name = "AmberDeformation"
	add_child(_outfit)
	_crystal.set_shader_parameter("base_color", Color(0.34, 0.18, 0.045))
	_crystal.set_shader_parameter("emission_color", Color(0.55, 0.24, 0.025))
	_crystal.set_shader_parameter("rim_color", Color(1.0, 0.65, 0.20))
	_crystal.set_shader_parameter("spec_color", Color(1.0, 0.84, 0.48))
	_crystal.set_shader_parameter("inner_glow", 0.12)
	_crystal.set_shader_parameter("roughness_value", 0.30)
	var amber := _material(Color(0.48,0.25,0.055),0.38,0.32)
	var glow := _material(Color(0.9,0.50,0.12),0.15,0.35)
	glow.emission_enabled = true
	glow.emission = Color(1.0,0.5,0.08)
	glow.emission_energy_multiplier = 0.6
	if kind == 0:
		for side in [-1.0,1.0]:
			var wrist := _follow("LeftHand" if side < 0 else "RightHand", "ResinDrip")
			_plate(wrist, Vector3(side*0.56,0.78,-0.01),Vector3(0.16,0.56,0.16),amber)
		pulse = _torus(_outfit,Vector3(0,0.9,0),0.82,0.018,glow)
	elif kind == 1:
		_plate(_outfit, Vector3(0,0.24,0),Vector3(1.32,0.76,1.06),amber)
		for side in [-1.0,1.0]:
			_plate(_outfit,Vector3(side*0.55,0.12,0),Vector3(0.45,0.38,0.8),amber)
		pulse = _torus(_outfit,Vector3(0,0.04,0),0.94,0.03,glow)
	else:
		# CowerIdle folds the authored arms and knees inward rather than hiding the body.
		play_motion("CowerIdle")
		_plate(_outfit,Vector3(0,1.25,0.31),Vector3(0.60,0.58,0.22),amber)
	if boss_form:
		var spine := _follow("Spine", "TitanDorsalArmor")
		for i in 5:
			var plate := _plate(spine,Vector3(0,1.0+i*0.13,0.22+i*0.012),
				Vector3(0.68-i*0.035,0.19,0.18),amber)
			plate.rotation.x = -0.24
			armor.append(plate)
		play_motion("CowerIdle")
	_apply_pose()

func _prepare_shatter() -> void:
	SlothRealmShatter.prepare_for(self, _crystal)

func _apply_pose() -> void:
	if skeleton == null:
		return
	for bone_name in ["LeftForeArm","RightForeArm"]:
		var id := skeleton.find_bone(bone_name)
		if id >= 0:
			skeleton.set_bone_pose_scale(id, Vector3(0.85,1.22,0.85) if kind == 0 else Vector3(0.80,1.35,0.80) if kind == 2 else Vector3.ONE)
	if kind == 1:
		for bone_name in ["LeftLeg","RightLeg"]:
			var id := skeleton.find_bone(bone_name)
			if id >= 0:
				skeleton.set_bone_pose_scale(id, Vector3(1.35,0.75,1.35))

func _process(delta: float) -> void:
	super._process(delta)
	if _dead:
		return
	_apply_pose()
	if is_instance_valid(pulse):
		pulse.scale = Vector3.ONE * (1.0 + sin(_time * 0.65) * 0.07)

func set_cast(amount: float) -> void:
	super.set_cast(amount)
	if is_instance_valid(pulse):
		pulse.visible = amount >= 0.0

func die(point := Vector3.INF, direction := Vector3.FORWARD) -> void:
	if _dead:
		return
	_dead = true
	if animation != null:
		animation.pause()
	realm_shatter = SlothRealmShatter.take(self, _crystal)
	get_parent().get_parent().add_child(realm_shatter)
	realm_shatter.build(self, global_position + Vector3.UP if point == Vector3.INF else point, direction)
	model.hide()
	_outfit.hide()
