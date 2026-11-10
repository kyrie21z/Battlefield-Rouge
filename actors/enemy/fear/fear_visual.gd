class_name FearRealmVisual
extends SlothVisual
## The same authored body becomes a hovering needle, trembling figure or crawler.
var face_crystal: MeshInstance3D
var ghost_count := 0
var claws: Array[Node3D] = []

func _build() -> void:
	if _built:
		return
	_built = true
	_crystal = CRYSTAL.duplicate() as ShaderMaterial
	_crystal.set_shader_parameter("base_color", Color(0.115, 0.045, 0.23))
	_crystal.set_shader_parameter("rim_color", Color(0.63, 0.38, 0.95))
	_crystal.set_shader_parameter("emission_color", Color(0.35, 0.12, 0.66))
	_crystal.set_shader_parameter("inner_glow", 0.06)
	_crystal.set_shader_parameter("spec_color", Color(0.43, 0.37, 0.62))
	_crystal.set_shader_parameter("emission_strength", 0.16)
	_crystal.set_shader_parameter("rim_strength", 0.28)
	_crystal.set_shader_parameter("roughness_value", 0.32)
	model = BODY.instantiate() as Node3D
	model.name = "FearCrystalBody"
	add_child(model)
	for node in model.find_children("*", "MeshInstance3D", true, false):
		(node as MeshInstance3D).material_override = _crystal
	for node in model.find_children("*", "Skeleton3D", true, false):
		skeleton = node as Skeleton3D
		break
	for node in model.find_children("*", "AnimationPlayer", true, false):
		animation = node as AnimationPlayer
		break
	if animation != null and animation.has_animation("idle"):
		animation.play("idle")
		animation.advance(0.0)
		animation.pause()
	_outfit = Node3D.new()
	add_child(_outfit)
	var light := _material(Color(0.56, 0.26, 0.9), 0.3, 0.2)
	light.emission_enabled = true
	light.emission = Color(0.55, 0.2, 0.95)
	light.emission_energy_multiplier = 0.45
	match kind:
		0:
			model.position.y = 0.45
			_pose_scale("Head", Vector3(0.3, 0.3, 0.3))
			for limb in ["LeftArm", "RightArm", "LeftForeArm", "RightForeArm", "LeftUpLeg", "RightUpLeg", "LeftLeg", "RightLeg"]:
				_pose_scale(limb, Vector3(0.52, 1.2, 0.52))
			face_crystal = _plate(_outfit, Vector3(0, 2.18, -0.05), Vector3(0.26, 0.38, 0.26), light)
		1:
			_pose_scale("Spine", Vector3(0.75, 1.05, 0.75))
			_pose_rotation("LeftArm", Vector3(0, 0, 0.2))
			_pose_rotation("RightArm", Vector3(0, 0, -0.2))
		2:
			_pose_crawler(0.0)
			for side in ["LeftHand", "RightHand"]:
				var hand := Node3D.new()
				_outfit.add_child(hand)
				hand.set_meta("bone", skeleton.find_bone(side))
				claws.append(hand)
				for finger in 3:
					var claw := _plate(hand, Vector3((finger - 1) * 0.065, -0.03, -0.15), Vector3(0.045, 0.08, 0.38), _crystal)
					claw.rotation.x = -0.4
					var hook := _plate(hand, Vector3((finger - 1) * 0.065, -0.07, -0.29), Vector3(0.035, 0.15, 0.10), light)
					hook.rotation.x = -0.55
	skeleton.force_update_all_bone_transforms()

func _pose_crawler(stride: float) -> void:
	# Four real contact limbs: solve in skeleton space, keeping each authored
	# rest basis. Replacing local quaternions loses the imported joint frames.
	var points := {
		"Hips": Vector3(0, 0.72, 0.40), "Spine": Vector3(0, 0.67, 0.23),
		"Chest": Vector3(0, 0.64, 0.0), "Neck": Vector3(0, 0.62, -0.215),
		"Head": Vector3(0, 0.65, -0.37)}
	var next := {"Hips":"Spine", "Spine":"Chest", "Chest":"Neck", "Neck":"Head"}
	for side in ["Left", "Right"]:
		var sign_x := -1.0 if side == "Left" else 1.0
		var step := stride * sign_x
		points[side + "Shoulder"] = Vector3(sign_x * 0.03, 0.635, -0.01)
		points[side + "Arm"] = Vector3(sign_x * 0.19, 0.57, -0.02)
		points[side + "ForeArm"] = Vector3(sign_x * 0.28, 0.37, -0.06 + step * 0.3)
		points[side + "Hand"] = Vector3(sign_x * 0.35, 0.13 + maxf(step, 0) * 0.3, -0.11 + step)
		points[side + "UpLeg"] = Vector3(sign_x * 0.10, 0.72, 0.42)
		points[side + "Leg"] = Vector3(sign_x * 0.30, 0.30, 0.70)
		points[side + "Foot"] = Vector3(sign_x * 0.32, 0.08 + maxf(-step, 0) * 0.3, 0.30 - step)
		points[side + "Toe"] = Vector3(sign_x * 0.32, 0.02, 0.19 - step)
		for chain in [["Shoulder","Arm"],["Arm","ForeArm"],["ForeArm","Hand"],["UpLeg","Leg"],["Leg","Foot"],["Foot","Toe"]]:
			next[side + chain[0]] = side + chain[1]
	for index in skeleton.get_bone_count():
		var bone_name := skeleton.get_bone_name(index)
		if not points.has(bone_name):
			continue
		var rest := skeleton.get_bone_global_rest(index)
		var target_basis := rest.basis
		if next.has(bone_name):
			var child_index := skeleton.find_bone(next[bone_name])
			var original := skeleton.get_bone_global_rest(child_index).origin - rest.origin
			var desired: Vector3 = points[next[bone_name]] - points[bone_name]
			target_basis = Basis(Quaternion(original.normalized(), desired.normalized())) * rest.basis
		var desired_pose := Transform3D(target_basis, points[bone_name])
		var parent_pose := skeleton.get_bone_global_pose(skeleton.get_bone_parent(index))
		var local := parent_pose.affine_inverse() * desired_pose
		skeleton.set_bone_pose_position(index, local.origin)
		skeleton.set_bone_pose_rotation(index, local.basis.get_rotation_quaternion())
		skeleton.force_update_all_bone_transforms()

func _pose_scale(bone_name: String, value: Vector3) -> void:
	var bone := skeleton.find_bone(bone_name)
	if bone >= 0:
		skeleton.set_bone_pose_scale(bone, value)

func _pose_rotation(bone_name: String, value: Vector3) -> void:
	var bone := skeleton.find_bone(bone_name)
	if bone >= 0:
		skeleton.set_bone_pose_rotation(bone, skeleton.get_bone_pose_rotation(bone) * Quaternion.from_euler(value))

func set_cast(amount: float) -> void:
	_cast = amount
	if _crystal != null:
		_crystal.set_shader_parameter("rim_strength", 0.25 + amount * 0.6)

func _process(delta: float) -> void:
	if _dead:
		return
	if get_parent() is Enemy:
		var actor := get_parent() as Enemy
		if actor.boon_stunned:
			return
		delta *= actor.boon_time_scale
	_time += delta
	if kind == 2:
		var moving := get_parent() is CharacterBody3D and (get_parent() as CharacterBody3D).velocity.length() > 0.2
		_pose_crawler(sin(_time * 8.0) * 0.04 if moving else 0.0)
	for hand in claws:
		hand.global_position = (skeleton.global_transform * skeleton.get_bone_global_pose(int(hand.get_meta("bone")))).origin
	if kind == 0:
		model.position.y = 0.45 + sin(_time * 1.2) * 0.07
	elif kind == 1:
		model.position.x = sin(_time * 53.0) * 0.026
		model.rotation.z = sin(_time * 47.0) * 0.023

func spawn_ghost() -> void:
	if _dead:
		return
	ghost_count += 1
	var ghost := BODY.instantiate() as Node3D
	get_parent().get_parent().add_child(ghost)
	ghost.global_transform = model.global_transform
	for node in ghost.find_children("*", "AnimationPlayer", true, false):
		(node as AnimationPlayer).pause()
		(node as AnimationPlayer).active = false
	var copy := ghost.find_child("Skeleton3D", true, false) as Skeleton3D
	for bone in skeleton.get_bone_count():
		copy.set_bone_pose_position(bone, skeleton.get_bone_pose_position(bone))
		copy.set_bone_pose_rotation(bone, skeleton.get_bone_pose_rotation(bone))
		copy.set_bone_pose_scale(bone, skeleton.get_bone_pose_scale(bone))
	copy.force_update_all_bone_transforms()
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.57, 0.25, 0.95, 0.28)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for child in ghost.find_children("*", "MeshInstance3D", true, false):
		(child as MeshInstance3D).material_override = material
	var tween := ghost.create_tween()
	tween.tween_property(material, "albedo_color:a", 0.0, 0.5)
	tween.tween_callback(ghost.queue_free)

func die(point := Vector3.INF, direction := Vector3.FORWARD) -> void:
	if _dead:
		return
	_dead = true
	var burst := FearShatter.new()
	get_parent().get_parent().add_child(burst)
	burst.build(self, global_position + Vector3.UP if point == Vector3.INF else point, direction)
	model.hide()
	_outfit.hide()
