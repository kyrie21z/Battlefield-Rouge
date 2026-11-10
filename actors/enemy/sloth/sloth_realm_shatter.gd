class_name SlothRealmShatter
extends Node3D
## 56 authored crystal pieces become WORLD-colliding rigid bodies at the current pose.
static var _shapes: Dictionary = {}
var pieces: Array[RigidBody3D] = []
var elapsed := 0.0

func _init() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE

func build(visual: SlothVisual, point: Vector3, direction: Vector3) -> void:
	SlothShatter.prepare_templates()
	var material := visual.crystal_material().duplicate() as ShaderMaterial
	for i in SlothShatter._templates.size():
		var template: Dictionary = SlothShatter._templates[i]
		var delta := Transform3D.IDENTITY
		var bone := visual.skeleton.find_bone(SlothShatter.PART_BONE.get(template.part,"Spine"))
		if bone >= 0:
			delta = visual.skeleton.get_bone_global_pose(bone) * visual.skeleton.get_bone_global_rest(bone).affine_inverse()
		var xf: Transform3D = visual.model.global_transform * delta * (template.transform as Transform3D)
		var body := RigidBody3D.new()
		body.mass = 0.06
		body.collision_layer = 0
		body.collision_mask = CollisionLayers.WORLD
		body.gravity_scale = 0.7
		body.linear_damp = 0.7
		body.angular_damp = 1.0
		var mesh := MeshInstance3D.new()
		mesh.mesh = template.mesh
		mesh.material_override = material
		body.add_child(mesh)
		var shape := CollisionShape3D.new()
		if not _shapes.has(i):
			_shapes[i] = (template.mesh as Mesh).create_convex_shape(false, false)
		shape.shape = _shapes[i]
		body.add_child(shape)
		add_child(body)
		body.global_transform = Transform3D(xf.basis.orthonormalized(),xf.origin)
		mesh.scale = xf.basis.get_scale()
		shape.scale = xf.basis.get_scale()
		var scatter := Vector3(sin(i*2.4),0.7,cos(i*2.4))
		body.linear_velocity = (xf.origin-point).normalized()*1.5 + direction.normalized()*1.5 + scatter
		body.angular_velocity = Vector3(cos(i),sin(i*2.2),0.7)*2.0
		pieces.append(body)

func _physics_process(delta: float) -> void:
	elapsed += delta
	if elapsed >= 2.4:
		queue_free()
