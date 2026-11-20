class_name WrathVisual
extends SlothVisual
## Authored faceted additions follow the existing 24-bone crystal body.
const GUARD_GEAR := preload("res://actors/enemy/wrath/wrath_guard_gear.gd")
const GRIP := preload("res://actors/enemy/wrath/wrath_guard_grip.gd")
var pressure := 0.0
var telegraph := 0.0
var _shield_seams: Array[StandardMaterial3D] = []
var _last_shield_pressure := -1.0
var _pages: Array[Node3D] = []
var _tear_age := -1.0
var _grip: GRIP

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
	var actor := get_parent() as WrathRealmEnemy
	var guard := actor != null and not actor.is_boss
	if guard and kind != WrathRealmEnemy.Variant.READER:
		_build_guard_clothes()
	if kind == 0:
		var shoulder := _follow("Spine", "HeadArmLance")
		_build_lance(shoulder)
		model.rotation.x = -0.16
	elif kind == 1:
		_build_pressure_shield()
		model.scale = Vector3(1.25, 0.88, 1.15)
	elif kind == WrathRealmEnemy.Variant.READER:
		_build_reader()
	else:
		for bone_prefix in ["Left", "Right"]:
			var saw := _follow(bone_prefix + "ForeArm", "SerratedArm")
			var forearm := skeleton.get_bone_global_rest(skeleton.find_bone(bone_prefix + "ForeArm")).origin
			var hand := skeleton.get_bone_global_rest(skeleton.find_bone(bone_prefix + "Hand")).origin
			var blade := Node3D.new()
			saw.add_child(blade)
			blade.position = forearm.lerp(hand, 0.6)
			if guard:
				_build_rip_saw(blade, (hand - forearm).normalized())
				continue
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
	WrathShatter.prepare_for(self, _crystal)

func _equip(parent: Node3D, mesh: Mesh, label: String) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.name = label
	part.mesh = mesh
	parent.add_child(part)
	return part

func _build_guard_clothes() -> void:
	var shoulders := _follow("Chest", "KilnMantle")
	var belt := _follow("Hips", "SplitApron")
	_equip(shoulders, GUARD_GEAR.garment(kind, true), "LayeredHide")
	_equip(belt, GUARD_GEAR.garment(kind, false), "LeatherPanels")
	var hide := _material(Color("563831"), 0.03, 0.83)
	var copper := _material(Color("b5835a"), 0.48, 0.54)
	var band := _torus(belt, Vector3(0, 1.06, 0.0), 0.23, 0.033, hide)
	band.scale.z = 0.76
	_plate(belt, Vector3(0.03, 1.065, -0.196), Vector3(0.105, 0.087, 0.042), copper)
	var sash := _plate(shoulders, Vector3(0.025, 1.37, -0.161), Vector3(0.088, 0.49, 0.049), hide)
	sash.rotation.z = -0.65
	if kind == 2:
		var cross_strap := _plate(shoulders, Vector3(-0.02, 1.37, -0.183), Vector3(0.084, 0.48, 0.046), hide)
		cross_strap.rotation.z = 0.65
	elif kind == 1:
		var collar := _torus(shoulders, Vector3(0, 1.61, 0.015), 0.196, 0.043, copper)
		collar.scale.z = 0.78
	# One shoulder carries the lance yoke. The shield bearer wears two shorter caps.
	if kind != 2:
		for prefix in (["Left"] if kind == 0 else ["Left", "Right"]):
			var pivot := _follow(prefix + "Arm", "CeramicPauldron" + prefix)
			var joint := skeleton.get_bone_global_rest(skeleton.find_bone(prefix + "Arm")).origin
			var rim := _plate(pivot, joint, Vector3(0.35, 0.25, 0.34), hide)
			rim.rotation.z = -0.19 if prefix == "Left" else 0.19
			_plate(pivot, joint + Vector3.UP * 0.041, Vector3(0.33, 0.21, 0.35), _metal)

func _build_lance(shoulder: Node3D) -> void:
	var stock := _material(Color("665045"), 0.29, 0.66)
	var shaft := Node3D.new()
	shaft.name = "BarbedKilnLance"
	shaft.rotation.y = PI * 0.5
	shaft.position = Vector3(-0.34, 1.65, -1.07)
	shoulder.add_child(shaft)
	_line(shaft, Vector3(-1.32, 0, 0), Vector3(0.10, 0, 0), 0.065, stock)
	for offset: float in [-1.13, -0.86, -0.31, -0.15]:
		_line(shaft, Vector3(offset - 0.045, 0, 0), Vector3(offset + 0.045, 0, 0), 0.083, _metal)
	_equip(shaft, GUARD_GEAR.blade(false), "BarbedSteel")
	_line(shaft, Vector3(-0.14, 0.027, 0.072), Vector3(0.63, 0.027, 0.072), 0.017, _light)
	_line(shaft, Vector3(-0.14, 0.027, -0.072), Vector3(0.63, 0.027, -0.072), 0.017, _light)
	_plate(shoulder, Vector3(-0.30, 1.62, -0.01), Vector3(0.38, 0.22, 0.37), stock)
	for side: float in [-1.0, 1.0]:
		_spike(shoulder, Vector3(side * 0.24, 1.60, 0.13), Vector3(side * 0.46, 1.81, 0.36), 0.083)

func _build_rip_saw(mount: Node3D, axis: Vector3) -> void:
	var edge := Vector3.FORWARD.slide(axis).normalized()
	mount.basis = Basis(axis, edge, axis.cross(edge))
	_equip(mount, GUARD_GEAR.blade(true), "ForgedSaw")
	_plate(mount, Vector3(-0.08, -0.01, 0), Vector3(0.40, 0.22, 0.24), _dark)
	for x: float in [-0.19, 0.04]:
		var cuff := _torus(mount, Vector3(x, -0.03, 0), 0.106, 0.021, _metal)
		cuff.rotation.z = PI * 0.5
	for sign_z: float in [-1.0, 1.0]:
		_line(mount, Vector3(0.02, 0.025, sign_z * 0.062),
			Vector3(0.32, 0.025, sign_z * 0.062), 0.012, _light)

func _build_pressure_shield() -> void:
	var shield := _follow("Spine", "PressureShield")
	_grip = GRIP.new()
	_grip.anchor = "Spine"
	_grip.left = Vector3(-0.27, 1.14, -0.05)
	_grip.right = Vector3(0.27, 1.14, -0.05)
	skeleton.add_child(_grip)
	var glaze := _material(Color("e9d8c8"), 0.08, 0.48)
	var fired := _material(Color("b0998c"), 0.10, 0.67)
	var binding := _material(Color("584041"), 0.52, 0.57)
	_plate(shield, Vector3(0, 0.99, -0.33), Vector3(1.22, 1.02, 0.29), _dark)
	# A raised regulator and vented spine connect the six plates. The charge
	# seams remain visible on each side, and the grips sit behind the shield.
	_plate(shield, Vector3(0, 0.99, -0.52), Vector3(0.18, 0.94, 0.13), binding)
	_torus(shield, Vector3(0, 1.025, -0.61), 0.126, 0.022, fired, Vector3(PI * 0.5, 0, 0))
	_plate(shield, Vector3(0, 1.025, -0.61), Vector3(0.17, 0.17, 0.067), binding)
	for y: float in [0.72, 0.80, 1.25, 1.33]:
		_plate(shield, Vector3(0, y, -0.591), Vector3(0.117, 0.026, 0.02), fired)
	for side in [-1.0, 1.0]:
		var foot := Vector3(side * 0.27, 0.94, -0.19)
		_polyline(shield, PackedVector3Array([foot, foot + Vector3(0, 0.03, 0.14),
			foot + Vector3(0, 0.30, 0.14), foot + Vector3(0, 0.34, 0)]), 0.031, binding)
		var strut := _plate(shield, Vector3(side * 0.27, 1.02, -0.16), Vector3(0.14, 0.78, 0.20), binding)
		strut.rotation.z = side * 0.18
		var collar := _plate(shield, Vector3(side * 0.5, 1.39, -0.29), Vector3(0.29, 0.39, 0.24), fired)
		collar.rotation.z = side * -0.29

	for row in 3:
		var seam := _material(Color("432628"), 0.02, 0.49)
		seam.emission_enabled = true
		seam.emission = Color("ff6b25")
		seam.emission_energy_multiplier = 0.0
		_shield_seams.append(seam)
		for side in [-1.0, 1.0]:
			var tile := Node3D.new()
			tile.position = Vector3(side * (0.28 + 0.035 * (row % 2)), 0.63 + row * 0.31 + side * 0.028, -0.46 + 0.016 * row)
			tile.rotation = Vector3(-0.06 + 0.065 * row, side * 0.24, -side * (0.08 + row * 0.018))
			shield.add_child(tile)
			var width: float = [0.49, 0.57, 0.51][row]
			_plate(tile, Vector3(0, 0, 0.050), Vector3(width + 0.035, 0.35, 0.23), fired)
			_plate(tile, Vector3.ZERO, Vector3(width, 0.315, 0.19), glaze)
			var split := Vector3(side * 0.024, 0.011, -0.124)
			var shoulder := Vector3(side * -0.12, 0.034, -0.093)
			_line(tile, Vector3(side * -0.18, 0.112, -0.064), shoulder, 0.009, seam)
			_line(tile, shoulder, split, 0.009, seam)
			_line(tile, split, Vector3(side * 0.118, -0.118, -0.078), 0.009, seam)
			_line(tile, split, Vector3(side * 0.139, 0.105, -0.070), 0.006, seam)

func _build_reader() -> void:
	var chest := _follow("Chest", "FoldedGazette")
	for side: float in [-1.0, 1.0]:
		var lapel := _plate(chest, Vector3(side * 0.11, 1.47, -0.126), Vector3(0.093, 0.29, 0.045), _dark)
		lapel.rotation.z = -side * 0.42
	var tie := _plate(chest, Vector3(0, 1.45, -0.16), Vector3(0.082, 0.32, 0.038), _dark)
	tie.rotation.z = 0.13
	for side: int in [-1, 1]:
		var page := _equip(chest, GUARD_GEAR.newspaper(side), "GazetteLeft" if side < 0 else "GazetteRight")
		page.position = Vector3(0, 1.40, -0.30)
		_pages.append(page)
		if side == -1:
			var title := Label3D.new()
			title.text = "熔城晚报"
			title.font_size = 42
			title.pixel_size = 0.00145
			title.outline_size = 0
			title.modulate = Color("403231")
			title.rotation.y = PI
			title.position = Vector3(-0.177, 0.155, -0.007)
			page.add_child(title)
	_grip = GRIP.new()
	skeleton.add_child(_grip)

func tear_paper() -> void:
	if _tear_age < 0.0:
		_tear_age = 0.0

func _update_reader(delta: float, actor: WrathRealmEnemy) -> void:
	if _tear_age < 0.0:
		return
	if _tear_age < 0.60:
		_tear_age = minf(0.60, _tear_age + delta)
		for i in _pages.size():
			var side := -1.0 if i == 0 else 1.0
			var t := _tear_age
			_pages[i].position = Vector3(side * 0.87 * t, 1.40 + 0.48*t - 2.9*t*t, -0.30 - 0.42*t)
			_pages[i].rotation = Vector3(t * 2.5, side * t * 2.9, side * t * 1.7)
			_pages[i].visible = t < 0.60
	_grip.left = Vector3(-0.22, 1.44, -0.28)
	_grip.right = Vector3(0.27, 1.43, -0.22)
	if actor.attack_phase == WrathRealmEnemy.Attack.RUSH:
		_grip.right = Vector3(0.12, 1.43, -0.53)
	elif _tear_age < 0.48:
		var fling := sin(PI * _tear_age / 0.48)
		_grip.left.x -= 0.21 * fling
		_grip.right.x += 0.21 * fling

func _update_shield_pressure() -> void:
	if _shield_seams.is_empty() or is_equal_approx(_last_shield_pressure, pressure):
		return
	_last_shield_pressure = pressure
	for row in _shield_seams.size():
		var level := smoothstep(0.04, 0.90, pressure * _shield_seams.size() - row)
		_shield_seams[row].albedo_color = Color("432628").lerp(Color("ff922f"), level)
		_shield_seams[row].emission_energy_multiplier = level * 2.35

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
	_crystal.set_shader_parameter("emission_strength", 0.10 + pressure * 0.6 + (0.25 if _tear_age >= 0.0 else 0.0))
	if not _pages.is_empty():
		_update_reader(delta, actor as WrathRealmEnemy)
	_update_shield_pressure()

func set_cast(amount: float) -> void:
	telegraph = amount

func die(point := Vector3.INF, direction := Vector3.FORWARD) -> void:
	if _dead:
		return
	_dead = true
	if animation != null:
		animation.stop()
	shatter = WrathShatter.take(self, _crystal)
	get_parent().get_parent().add_child(shatter)
	shatter.build(self, global_position + Vector3.UP if point == Vector3.INF else point, direction)
	model.hide()
	_outfit.hide()
