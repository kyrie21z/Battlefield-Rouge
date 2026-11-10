class_name WrathVisual
extends SlothVisual
## Authored faceted additions follow the existing 24-bone crystal body.
var pressure := 0.0
var telegraph := 0.0

func _build() -> void:
	if _built:
		return
	_built = true
	_crystal = CRYSTAL.duplicate() as ShaderMaterial
	_crystal.set_shader_parameter("base_color", Color(0.36, 0.025, 0.035))
	_crystal.set_shader_parameter("emission_color", Color(1.0, 0.055, 0.015))
	_crystal.set_shader_parameter("rim_color", Color(0.92, 0.18, 0.08))
	_crystal.set_shader_parameter("roughness_value", 0.26)
	_crystal.set_shader_parameter("inner_glow", 0.06)
	model = BODY.instantiate() as Node3D
	add_child(model)
	for child in model.find_children("*", "MeshInstance3D", true, false):
		(child as MeshInstance3D).material_override = _crystal
	for child in model.find_children("*", "Skeleton3D", true, false):
		skeleton = child as Skeleton3D
		break
	for child in model.find_children("*", "AnimationPlayer", true, false):
		animation = child as AnimationPlayer
		break
	if animation != null:
		var library := animation.get_animation_library("").duplicate(true) as AnimationLibrary
		animation.remove_animation_library("")
		animation.add_animation_library("", library)
		for clip in ["idle", "walk"]:
			if animation.has_animation(clip):
				animation.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	_outfit = Node3D.new()
	_outfit.name = "FracturedSilhouette"
	add_child(_outfit)
	_metal = _material(Color(0.86, 0.82, 0.78), 0.35, 0.26)
	_dark = _material(Color(0.10, 0.015, 0.025), 0.4, 0.26)
	_light = _material(Color(1.0, 0.075, 0.015), 0.25, 0.25)
	_light.emission_enabled = true
	_light.emission = Color(1.0, 0.035, 0.008)
	_light.emission_energy_multiplier = 1.2
	if kind == 0:
		var shoulder := _follow("Spine", "HeadArmLance")
		_spike(shoulder, Vector3(-0.35, 1.7, 0), Vector3(-0.18, 1.72, -2.3), 0.27)
		for side in [-1.0, 1.0]:
			for i in 3:
				_spike(_outfit, Vector3(side * 0.31, 1.6, 0.04), Vector3(side * (0.7 + i * 0.17), 1.8 + i * 0.17, 0.1), 0.12)
		model.rotation.x = -0.16
	elif kind == 1:
		var shield := _follow("Spine", "PressureShield")
		_plate(shield, Vector3(0, 1.05, -0.30), Vector3(1.35, 1.5, 0.4), _metal)
		for side in [-1.0, 1.0]:
			_plate(shield, Vector3(side * 0.7, 1.15, -0.12), Vector3(0.3, 1.55, 0.4), _dark)
		for i in 5:
			_line(shield, Vector3(-0.55, 0.55 + i * 0.24, -0.48), Vector3(0.55, 0.68 + i * 0.24, -0.48), 0.018, _light)
		model.scale = Vector3(1.25, 0.88, 1.15)
	else:
		for bone_prefix in ["Left", "Right"]:
			var saw := _follow(bone_prefix + "ForeArm", "SerratedArm")
			var forearm := skeleton.get_bone_global_rest(skeleton.find_bone(bone_prefix + "ForeArm")).origin
			var hand := skeleton.get_bone_global_rest(skeleton.find_bone(bone_prefix + "Hand")).origin
			var blade := Node3D.new()
			saw.add_child(blade)
			blade.position = forearm.lerp(hand, 0.6)
			blade.quaternion = Quaternion(Vector3.RIGHT, (hand - forearm).normalized())
			_plate(blade, Vector3.ZERO, Vector3(0.70, 0.19, 0.24), _dark)
			for i in 6:
				_spike(blade, Vector3(-0.3 + i * 0.12, 0, -0.08), Vector3(-0.27 + i * 0.12, 0, -0.42), 0.10)
		model.rotation.x = -0.18
		model.scale = Vector3(1.05, 1.12, 1.0)
	_outfit.transform = model.transform
	play_motion("idle")
	if animation != null:
		animation.advance(0)
	_update_bones()

func _spike(parent: Node3D, start: Vector3, end: Vector3, radius: float) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.0
	mesh.bottom_radius = radius
	mesh.height = start.distance_to(end)
	mesh.radial_segments = 4
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = _light
	parent.add_child(node)
	node.position = (start + end) * 0.5
	node.quaternion = Quaternion(Vector3.UP, (end - start).normalized())

func play_motion(motion: String) -> void:
	if animation == null or _dead:
		return
	var clip := "walk" if motion in ["walk", "run"] else "idle"
	if animation.has_animation(clip) and animation.current_animation != clip:
		animation.play(clip)

func _process(delta: float) -> void:
	if _dead:
		return
	var actor := get_parent() as Enemy
	if actor != null:
		delta *= actor.boon_time_scale
		if actor.boon_stunned:
			delta = 0.0
	_time += delta
	_update_bones()
	_light.emission_energy_multiplier = 0.8 + pressure * 3.0 + telegraph * (1.0 + sin(_time * 16.0))
	_crystal.set_shader_parameter("emission_strength", 0.10 + pressure * 0.6)

func set_cast(amount: float) -> void:
	telegraph = amount

func die(point := Vector3.INF, direction := Vector3.FORWARD) -> void:
	if _dead:
		return
	_dead = true
	if animation != null:
		animation.stop()
	shatter = WrathShatter.new()
	get_parent().get_parent().add_child(shatter)
	shatter.build(self, global_position + Vector3.UP if point == Vector3.INF else point, direction)
	model.hide()
	_outfit.hide()
