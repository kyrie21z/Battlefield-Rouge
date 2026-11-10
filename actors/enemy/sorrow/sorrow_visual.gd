class_name SorrowVisual
extends SlothVisual
var submerged := false
var immersion := 0.0
var drops: CPUParticles3D

func _build() -> void:
	if _built:
		return
	_built = true
	_crystal = CRYSTAL.duplicate() as ShaderMaterial
	_crystal.set_shader_parameter("base_color",Color(0.015,0.14,0.22))
	_crystal.set_shader_parameter("emission_color",Color(0.04,0.48,0.72))
	_crystal.set_shader_parameter("rim_color",Color(0.2,0.7,0.95))
	_crystal.set_shader_parameter("roughness_value",0.15)
	_crystal.set_shader_parameter("inner_glow",0.07)
	model = BODY.instantiate() as Node3D
	add_child(model)
	for child in model.find_children("*","MeshInstance3D",true,false):
		(child as MeshInstance3D).material_override = _crystal
	for child in model.find_children("*","Skeleton3D",true,false):
		skeleton = child as Skeleton3D
		break
	for child in model.find_children("*","AnimationPlayer",true,false):
		animation = child as AnimationPlayer
		animation.stop()
		animation.process_mode = Node.PROCESS_MODE_DISABLED
		break
	_outfit = Node3D.new()
	add_child(_outfit)
	_metal = _material(Color(0.12,0.28,0.34),0.6,0.22)
	_dark = _material(Color(0.015,0.05,0.07),0.4,0.18)
	_light = _material(Color(0.16,0.65,0.83),0.3,0.16)
	_light.emission_enabled = true
	_light.emission = Color(0.08,0.45,0.65)
	_light.emission_energy_multiplier = 0.5
	if kind == 0:
		for child in model.find_children("*","MeshInstance3D",true,false):
			var label := String(child.name).to_lower()
			if "thigh" in label or "shin" in label or "hips" in label:
				child.hide()
		model.position.y = -0.35
		var pool := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.55
		mesh.bottom_radius = 0.9
		mesh.height = 0.12
		mesh.radial_segments = 9
		pool.mesh = mesh
		pool.material_override = _crystal
		pool.position.y = 0.18
		_outfit.add_child(pool)
		var melt := MeshInstance3D.new()
		var taper := CylinderMesh.new()
		taper.top_radius = 0.23
		taper.bottom_radius = 0.64
		taper.height = 0.68
		taper.radial_segments = 7
		melt.mesh = taper
		melt.material_override = _crystal
		melt.position.y = 0.45
		_outfit.add_child(melt)
		_pose_arms(false)
	elif kind == 1:
		_pose_arms(false)
		_place_bone("Head",Vector3(0,1.21,-0.35))
		_place_bone("Neck",Vector3(0,1.25,-0.05))
		for side in [-1.0,1.0]:
			_plate(_outfit,Vector3(side*0.38,0.24,0.0),Vector3(0.38,0.52,0.48),_dark)
			_line(_outfit,Vector3(side*0.38,0.4,0),Vector3(side*0.38,1.3,0),0.035,_metal)
	else:
		_pose_kneeling()
		model.position.y = 0.45
		_drops()
	_update_bones()

func _place_bone(label: String, point: Vector3) -> void:
	var index := skeleton.find_bone(label)
	var xf := skeleton.get_bone_global_rest(index)
	xf.origin = point
	skeleton.set_bone_global_pose_override(index,xf,1.0,true)

func _segment(label: String, next: String, start: Vector3, end: Vector3) -> void:
	var index := skeleton.find_bone(label)
	var rest := skeleton.get_bone_global_rest(index)
	var old := skeleton.get_bone_global_rest(skeleton.find_bone(next)).origin-rest.origin
	var turn := Quaternion(old.normalized(),(end-start).normalized())
	skeleton.set_bone_global_pose_override(index,Transform3D(Basis(turn)*rest.basis,start),1.0,true)

func _pose_arms(covered: bool) -> void:
	for prefix in ["Left","Right"]:
		var side := -1.0 if prefix == "Left" else 1.0
		var shoulder := Vector3(side*0.2,1.22 if covered else 1.56,0.04)
		var elbow := Vector3(side*0.36,1.10 if covered else 0.99,-0.29 if covered else 0.0)
		var hand := Vector3(side*0.075,1.42,-0.22) if covered else Vector3(side*0.39,0.36,0)
		_segment(prefix+"Arm",prefix+"ForeArm",shoulder,elbow)
		_segment(prefix+"ForeArm",prefix+"Hand",elbow,hand)
		_place_bone(prefix+"Hand",hand)

func _pose_kneeling() -> void:
	animation.stop()
	skeleton.reset_bone_poses()
	skeleton.clear_bones_global_pose_override()
	for label in ["Hips","Spine","Chest","LeftShoulder","RightShoulder"]:
		var rest := skeleton.get_bone_global_rest(skeleton.find_bone(label))
		_place_bone(label,rest.origin-Vector3.UP*0.25)
	_place_bone("Neck",Vector3(0,1.35,0.03))
	_place_bone("Head",Vector3(0,1.42,-0.08))
	for prefix in ["Left","Right"]:
		var side := -1.0 if prefix == "Left" else 1.0
		var shoulder := Vector3(side*0.19,1.315,0.04)
		var elbow := Vector3(side*0.35,1.15,-0.12)
		var hand := Vector3(side*0.10,1.39,-0.27)
		_segment(prefix+"Arm",prefix+"ForeArm",shoulder,elbow)
		_segment(prefix+"ForeArm",prefix+"Hand",elbow,hand)
		_place_bone(prefix+"Hand",hand)
		var hip := Vector3(side*0.1,0.82,0)
		var knee := Vector3(side*0.18,0.3,-0.38)
		var foot := Vector3(side*0.18,0.1,0.05)
		_segment(prefix+"UpLeg",prefix+"Leg",hip,knee)
		_segment(prefix+"Leg",prefix+"Foot",knee,foot)
		_place_bone(prefix+"Foot",foot)
	var hands := _follow("Head","CoveringHands")
	var head := skeleton.get_bone_global_rest(skeleton.find_bone("Head")).origin
	for side in [-1.0,1.0]:
		_plate(hands,head+Vector3(side*0.065,-0.035,-0.17),Vector3(0.14,0.23,0.12),_metal)

func _drops() -> void:
	drops = CPUParticles3D.new()
	drops.amount = 20
	drops.lifetime = 1.5
	drops.position = Vector3(0,1.86,-0.22)
	drops.direction = Vector3.DOWN
	drops.spread = 6
	drops.initial_velocity_min = 0.2
	drops.initial_velocity_max = 0.4
	drops.gravity = Vector3(0,-1.4,0)
	var mesh := SphereMesh.new()
	mesh.radius = 0.025
	mesh.height = 0.07
	mesh.radial_segments = 5
	mesh.rings = 3
	drops.mesh = mesh
	drops.material_override = _light
	add_child(drops)

func _process(delta: float) -> void:
	if _dead:
		return
	var actor := get_parent() as Enemy
	if actor != null:
		delta *= actor.boon_time_scale
		if actor.boon_stunned:
			delta = 0
	_time += delta
	if kind == 0:
		immersion = move_toward(immersion,1.0 if submerged else 0.0,delta*4.0)
		model.position.y = -0.35-immersion*1.6
		model.visible = immersion < 0.85
		_outfit.scale.y = 1.0-immersion*0.7
	if kind == 2:
		model.position.y = 0.45+sin(_time*1.4)*0.06
		_outfit.transform = model.transform
		if drops != null:
			drops.position = model.transform*skeleton.get_bone_global_pose(skeleton.find_bone("Head")).origin+Vector3(0,-0.05,-0.08)
	_light.emission_energy_multiplier = 0.5+_cast*2.0
	_crystal.set_shader_parameter("emission_strength",0.10+_cast*0.4)
	_update_bones()

func set_submerged(value: bool) -> void:
	submerged = value

func set_cast(value: float) -> void:
	_cast = value

func play_motion(_motion: String) -> void:
	pass # Authored alien poses remain; locomotion is a deliberate water glide.

func die(point := Vector3.INF, direction := Vector3.FORWARD) -> void:
	if _dead:
		return
	_dead = true
	shatter = WrathShatter.new()
	get_parent().get_parent().add_child(shatter)
	shatter.build(self,global_position+Vector3.UP if point == Vector3.INF else point,direction)
	model.hide()
	_outfit.hide()
	if drops != null:
		drops.emitting = false
