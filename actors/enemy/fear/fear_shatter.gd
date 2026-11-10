class_name FearShatter
extends Node3D
## All 56 authored shard meshes, frozen to the live 24-bone pose, then rigid physics.
var pieces: Array[RigidBody3D] = []
var elapsed := 0.0

func build(visual: SlothVisual, point: Vector3, direction: Vector3) -> void:
	SlothShatter.prepare_templates()
	var material := visual.crystal_material().duplicate() as ShaderMaterial
	material.set_shader_parameter("rim_strength", 0.7)
	for entry in SlothShatter._templates:
		var delta := Transform3D.IDENTITY
		var bone := visual.skeleton.find_bone(SlothShatter.PART_BONE.get(entry.part, "Spine"))
		if bone >= 0:
			delta = visual.skeleton.get_bone_global_pose(bone) * visual.skeleton.get_bone_global_rest(bone).affine_inverse()
		var xf := visual.model.global_transform * delta * (entry.transform as Transform3D)
		var piece := RigidBody3D.new()
		piece.collision_layer = 0
		piece.collision_mask = CollisionLayers.WORLD
		piece.mass = 0.07
		piece.continuous_cd = true
		piece.physics_material_override = PhysicsMaterial.new()
		piece.physics_material_override.bounce = 0.25
		var mesh := MeshInstance3D.new()
		mesh.mesh = entry.mesh
		mesh.material_override = material
		piece.add_child(mesh)
		var collision := CollisionShape3D.new()
		collision.shape = (entry.mesh as Mesh).create_convex_shape(true, true)
		piece.add_child(collision)
		add_child(piece)
		piece.global_transform = xf
		var index := float(pieces.size())
		var scatter := Vector3(sin(index * 2.4), 0.8 + cos(index) * 0.3, cos(index * 2.4))
		piece.linear_velocity = (xf.origin - point).normalized() * 2 + direction.normalized() * 1.5 + scatter
		piece.angular_velocity = Vector3(cos(index), sin(index * 2.2), 0.7) * 3
		pieces.append(piece)

func _physics_process(delta: float) -> void:
	elapsed += delta
	if elapsed >= 2.4:
		queue_free()
