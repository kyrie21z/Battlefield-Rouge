class_name FearOculusVisual
extends Node3D
## Concentric folded limbs are baked from the existing crystalline human body.
var rings: Array[Node3D] = []
var iris: MeshInstance3D
var pieces: Array[MeshInstance3D] = []
var material: ShaderMaterial
var elapsed := 0.0
var charge := 0.0
var dead := false

func _ready() -> void:
	material = preload("res://assets/materials/red_crystal_material_shader.tres").duplicate() as ShaderMaterial
	material.set_shader_parameter("base_color", Color(0.16, 0.07, 0.3))
	material.set_shader_parameter("rim_color", Color(0.65, 0.38, 0.95))
	material.set_shader_parameter("emission_color", Color(0.4, 0.12, 0.8))
	material.set_shader_parameter("inner_glow", 0.06)
	material.set_shader_parameter("emission_strength", 0.12)
	material.set_shader_parameter("rim_strength", 0.3)
	material.set_shader_parameter("spec_color", Color(0.49, 0.38, 0.71))
	var body := preload("res://assets/models/characters/red_crystal_enemy_animated.glb").instantiate()
	add_child(body)
	var parts: Array[Mesh] = []
	for child in body.find_children("*", "MeshInstance3D", true, false):
		var mesh := child as MeshInstance3D
		if "arm" in String(mesh.name).to_lower() or "shin" in String(mesh.name).to_lower() or "torso" in String(mesh.name).to_lower():
			parts.append(static_part(mesh.mesh))
	if parts.is_empty():
		for child in body.find_children("*", "MeshInstance3D", true, false):
			parts.append(static_part((child as MeshInstance3D).mesh))
	body.free()
	for ring_index in 3:
		var ring := Node3D.new()
		ring.position.y = 5.3
		ring.rotation.y = (ring_index - 1) * 0.18
		add_child(ring)
		rings.append(ring)
		var count := 8 + ring_index * 4
		var radius := 1.7 + ring_index * 1.3
		for index in count:
			var angle := TAU * index / count
			var fold := Node3D.new()
			fold.position = Vector3(cos(angle), sin(angle), 0) * radius
			fold.rotation.z = angle
			fold.rotation.x = 0.3 * (1 if index % 2 else -1)

			ring.add_child(fold)
			var part := MeshInstance3D.new()
			part.mesh = parts[(index + ring_index) % parts.size()]
			part.material_override = material
			var bounds := part.mesh.get_aabb()
			var axis := bounds.size.max_axis_index()
			var direction := Vector3.ZERO
			direction[axis] = 1.0
			part.quaternion = Quaternion(direction, Vector3.UP)
			var size := (TAU * radius / count) * 1.12 / bounds.size[axis]
			part.scale = Vector3.ONE * size
			part.position = -(part.basis * bounds.get_center())
			fold.add_child(part)
			pieces.append(part)
	iris = MeshInstance3D.new()
	var pupil := SphereMesh.new()
	pupil.radius = 1.05
	pupil.height = 2.1
	pupil.radial_segments = 8
	pupil.rings = 4
	iris.mesh = pupil
	iris.scale = Vector3(1, 1, 0.55)
	iris.position = Vector3(0, 5.3, -0.2)
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(0.55, 0.24, 0.95)
	glow.emission_enabled = true
	glow.emission = Color(0.55, 0.2, 0.95)
	glow.emission_energy_multiplier = 0.55
	glow.roughness = 0.15
	iris.material_override = glow
	add_child(iris)
	# The slit is actual opaque geometry, readable against a faceted iris.
	var pupil_slit := MeshInstance3D.new()
	var slit := SphereMesh.new()
	slit.radius = 0.32
	slit.height = 1.6
	slit.radial_segments = 6
	slit.rings = 3
	pupil_slit.mesh = slit
	pupil_slit.position = Vector3(0, 0, 1.08)
	pupil_slit.scale.z = 0.12
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.006, 0.002, 0.012)
	dark.roughness = 0.3
	pupil_slit.material_override = dark
	iris.add_child(pupil_slit)

func static_part(source: Mesh) -> ArrayMesh:
	# Imported bind-pose vertices already describe each body part. Removing only
	# skin indices/weights makes a reusable rigid fold without a GPU readback.
	var result := ArrayMesh.new()
	for surface in source.get_surface_count():
		var arrays := source.surface_get_arrays(surface).duplicate(true)
		arrays[Mesh.ARRAY_BONES] = null
		arrays[Mesh.ARRAY_WEIGHTS] = null
		result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return result

func _process(delta: float) -> void:
	if dead:
		return
	if get_parent() is Enemy:
		var actor := get_parent() as Enemy
		if actor.boon_stunned:
			return
		delta *= actor.boon_time_scale
	elapsed += delta
	for index in rings.size():
		rings[index].rotation.z = elapsed * [0.18, -0.12, 0.075][index]
		rings[index].rotation.y = sin(elapsed * 0.27 + index) * 0.24
	iris.scale = Vector3(1, 1, 0.55) * (0.75 + charge * 0.4)

func shatter() -> void:
	if dead:
		return
	dead = true
	SlothShatter.prepare_templates()
	var burst := FearShatter.new()
	get_parent().get_parent().add_child(burst)
	for index in SlothShatter._templates.size():
		var entry: Dictionary = SlothShatter._templates[index]
		var piece := RigidBody3D.new()
		piece.collision_layer = 0
		piece.collision_mask = CollisionLayers.WORLD
		piece.mass = 0.15
		piece.continuous_cd = true
		var mesh := MeshInstance3D.new()
		mesh.mesh = entry.mesh
		mesh.material_override = material
		piece.add_child(mesh)
		var shape := CollisionShape3D.new()
		shape.shape = (entry.mesh as Mesh).create_convex_shape(true, true)
		piece.add_child(shape)
		burst.add_child(piece)
		var ring := index % 3
		var angle := index * 2.4 + rings[ring].rotation.z
		piece.global_position = global_position + Vector3(cos(angle), sin(angle), 0) * (1.7 + ring * 1.3) + Vector3.UP * 5.3
		piece.linear_velocity = Vector3(cos(angle) * 4, sin(angle) * 3 + 2, cos(index * 1.5) * 3)
		piece.angular_velocity = Vector3(1, cos(angle), sin(angle)) * 4
		burst.pieces.append(piece)
	hide()
