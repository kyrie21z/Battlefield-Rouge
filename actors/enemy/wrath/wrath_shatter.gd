class_name WrathShatter
extends SlothShatter
## Real rigid bodies reuse the 56 source shards; meshes/hulls are cached.
static var _hulls: Dictionary = {}

func build(visual: SlothVisual, point: Vector3, direction: Vector3) -> void:
	prepare_templates()
	impact_point = point
	impact_direction = direction.normalized()
	var mat := visual.crystal_material().duplicate() as ShaderMaterial
	mat.set_shader_parameter("emission_strength", 0.7)
	for i in _templates.size():
		var template: Dictionary = _templates[i]
		var bone := visual.skeleton.find_bone(PART_BONE.get(template.part, "Spine"))
		var delta := visual.skeleton.get_bone_global_pose(bone) * visual.skeleton.get_bone_global_rest(bone).affine_inverse()
		var xf: Transform3D = visual.model.global_transform * delta * (template.transform as Transform3D)
		var piece := RigidBody3D.new()
		piece.collision_layer = 0
		piece.collision_mask = CollisionLayers.WORLD
		piece.mass = 0.06
		piece.linear_damp = 0.6
		piece.angular_damp = 1.2
		var mesh := MeshInstance3D.new()
		mesh.mesh = template.mesh
		mesh.material_override = mat
		mesh.scale = xf.basis.get_scale()
		piece.add_child(mesh)
		var shape := CollisionShape3D.new()
		if not _hulls.has(i):
			_hulls[i] = (template.mesh as Mesh).create_convex_shape()
		shape.shape = _hulls[i]
		shape.scale = xf.basis.get_scale()
		piece.add_child(shape)
		add_child(piece)
		piece.global_transform = Transform3D(xf.basis.orthonormalized(), xf.origin)
		piece.linear_velocity = (xf.origin - point).normalized() * 2.0 + impact_direction * 2.0 + Vector3(sin(i * 2.4), 2.4, cos(i * 2.4))
		piece.angular_velocity = Vector3(sin(i), cos(i * 1.7), 0.7) * 4.0
		fragments.append({"node": piece, "part": template.part, "released": true})

func _physics_process(delta: float) -> void:
	elapsed += delta
	if elapsed > 1.6:
		for fragment in fragments:
			var piece := fragment.node as RigidBody3D
			(piece.get_child(0) as MeshInstance3D).scale = Vector3.ONE * maxf(0.01, 1.0 - (elapsed - 1.6) / 0.4)
	if elapsed >= 2.0:
		queue_free()
