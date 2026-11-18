class_name SlothRealmShatter
extends Node3D
## 56 authored crystal pieces become WORLD-colliding rigid bodies at the current pose.
const RESERVE_KEY := &"sloth_realm_prepared_shatter"
static var _shapes: Dictionary = {}
var pieces: Array[RigidBody3D] = []
var elapsed := 0.0
var started := false
var _material: ShaderMaterial
var _retiring := false
var _retire_queue: Array[RigidBody3D] = []

func _init() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE

static func prepare_shapes() -> void:
	SlothShatter.prepare_templates()
	if _shapes.size() == SlothShatter._templates.size():
		return
	for i in SlothShatter._templates.size():
		if not _shapes.has(i):
			_shapes[i] = (SlothShatter._templates[i].mesh as Mesh).create_convex_shape(false, false)

static func prepare_for(visual: Node3D, source: ShaderMaterial) -> SlothRealmShatter:
	var existing := visual.get_meta(RESERVE_KEY) as SlothRealmShatter if visual.has_meta(RESERVE_KEY) else null
	if is_instance_valid(existing):
		return existing
	var burst := SlothRealmShatter.new()
	burst.prepare(source)
	visual.set_meta(RESERVE_KEY, burst)
	visual.tree_exiting.connect(burst._discard_unused, CONNECT_ONE_SHOT)
	return burst

static func take(visual: Node3D, source: ShaderMaterial) -> SlothRealmShatter:
	var burst := prepare_for(visual, source)
	visual.remove_meta(RESERVE_KEY)
	return burst

func _discard_unused() -> void:
	if not started:
		queue_free()

func prepare(source: ShaderMaterial) -> void:
	if not pieces.is_empty():
		return
	prepare_shapes()
	_material = source.duplicate() as ShaderMaterial
	for i in SlothShatter._templates.size():
		var template: Dictionary = SlothShatter._templates[i]
		var body := RigidBody3D.new()
		body.mass = 0.06
		body.collision_layer = CollisionLayers.NONE
		body.collision_mask = CollisionLayers.NONE
		body.freeze = true
		body.gravity_scale = 0.7
		body.linear_damp = 0.7
		body.angular_damp = 1.0
		var mesh := MeshInstance3D.new()
		mesh.mesh = template.mesh
		mesh.material_override = _material
		body.add_child(mesh)
		var shape := CollisionShape3D.new()
		shape.shape = _shapes[i]
		body.add_child(shape)
		add_child(body)
		pieces.append(body)
	hide()
	set_physics_process(false)

func build(visual: SlothVisual, point: Vector3, direction: Vector3) -> void:
	prepare(visual.crystal_material())
	var source := visual.crystal_material()
	for parameter in ["base_color", "rim_color", "emission_color", "emission_strength", "rim_strength", "inner_glow", "spec_color", "roughness_value"]:
		var val: Variant = source.get_shader_parameter(parameter)
		if val != null:
			_material.set_shader_parameter(parameter, val)
	var poses := {}
	var dir := direction.normalized() if direction.length_squared() > 0.001 else Vector3.FORWARD
	for i in SlothShatter._templates.size():
		var template: Dictionary = SlothShatter._templates[i]
		var bone := visual.skeleton.find_bone(SlothShatter.PART_BONE.get(template.part,"Spine"))
		if not poses.has(bone):
			poses[bone] = visual.skeleton.get_bone_global_pose(bone) * visual.skeleton.get_bone_global_rest(bone).affine_inverse() if bone >= 0 else Transform3D.IDENTITY
		var xf: Transform3D = visual.model.global_transform * poses[bone] * (template.transform as Transform3D)
		var body := pieces[i]
		var mesh := body.get_child(0) as MeshInstance3D
		var shape := body.get_child(1) as CollisionShape3D
		var sc := xf.basis.get_scale()
		mesh.scale = sc
		shape.scale = sc
		body.global_transform = Transform3D(xf.basis.orthonormalized(), xf.origin)
		var scatter := Vector3(sin(i*2.4),0.7,cos(i*2.4))
		body.linear_velocity = (xf.origin-point).normalized()*1.5 + dir*1.5 + scatter
		body.angular_velocity = Vector3(cos(i),sin(i*2.2),0.7)*2.0
		body.collision_mask = CollisionLayers.WORLD
		body.freeze = false
		body.sleeping = false
	started = true
	show()
	set_physics_process(true)

func _physics_process(delta: float) -> void:
	elapsed += delta
	if elapsed < 2.4:
		return
	if not _retiring:
		_retiring = true
		hide()
		for piece in pieces:
			if is_instance_valid(piece):
				piece.freeze = true
				piece.collision_mask = CollisionLayers.NONE
				_retire_queue.append(piece)
	for _i in mini(8, _retire_queue.size()):
		var piece := _retire_queue.pop_back() as RigidBody3D
		if is_instance_valid(piece):
			piece.queue_free()
	if _retire_queue.is_empty():
		queue_free()
