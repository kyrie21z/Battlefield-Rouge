class_name WrathShatter
extends SlothShatter
## Real rigid bodies reuse the 56 source shards; meshes/hulls are cached.
const WRATH_RESERVE_KEY := &"wrath_prepared_shatter"
static var _hulls: Dictionary = {}
var _base_scales: Array[Vector3] = []
var _frozen_for_fade := false
var _retiring := false
var _retire_queue: Array[RigidBody3D] = []

static func prepare_shapes() -> void:
	SlothShatter.prepare_templates()
	if _hulls.size() == SlothShatter._templates.size():
		return
	for i in SlothShatter._templates.size():
		if not _hulls.has(i):
			_hulls[i] = (SlothShatter._templates[i].mesh as Mesh).create_convex_shape()

static func prepare_for(visual: Node3D, source: ShaderMaterial) -> WrathShatter:
	var existing := visual.get_meta(WRATH_RESERVE_KEY) as WrathShatter if visual.has_meta(WRATH_RESERVE_KEY) else null
	if is_instance_valid(existing):
		return existing
	var burst := WrathShatter.new()
	burst.prepare(source)
	visual.set_meta(WRATH_RESERVE_KEY, burst)
	visual.tree_exiting.connect(burst._discard_unused, CONNECT_ONE_SHOT)
	return burst

static func take(visual: Node3D, source: ShaderMaterial) -> WrathShatter:
	var burst := prepare_for(visual, source)
	visual.remove_meta(WRATH_RESERVE_KEY)
	return burst

func prepare(source: ShaderMaterial) -> void:
	if not fragments.is_empty():
		return
	prepare_shapes()
	_material = source.duplicate() as ShaderMaterial
	for i in _templates.size():
		var template: Dictionary = _templates[i]
		var piece := RigidBody3D.new()
		piece.collision_layer = CollisionLayers.NONE
		piece.collision_mask = CollisionLayers.NONE
		piece.freeze = true
		piece.mass = 0.06
		piece.linear_damp = 0.6
		piece.angular_damp = 1.2
		var mesh := MeshInstance3D.new()
		mesh.mesh = template.mesh
		mesh.material_override = _material
		piece.add_child(mesh)
		var shape := CollisionShape3D.new()
		shape.shape = _hulls[i]
		piece.add_child(shape)
		add_child(piece)
		fragments.append({"node": piece, "part": template.part, "released": true})
		_base_scales.append(Vector3.ONE)
	hide()
	set_physics_process(false)

func build(visual: SlothVisual, point: Vector3, direction: Vector3) -> void:
	prepare(visual.crystal_material())
	var source := visual.crystal_material()
	for parameter in ["base_color", "rim_color", "emission_color", "emission_strength", "rim_strength", "inner_glow", "spec_color", "roughness_value", "guard", "print_cutoff"]:
		var val: Variant = source.get_shader_parameter(parameter)
		if val != null:
			_material.set_shader_parameter(parameter, val)
	_material.set_shader_parameter("emission_strength", 0.7)
	impact_point = point
	impact_direction = direction.normalized() if direction.length_squared() > 0.001 else Vector3.FORWARD
	var poses := {}
	for i in _templates.size():
		var template: Dictionary = _templates[i]
		var bone := visual.skeleton.find_bone(PART_BONE.get(template.part, "Spine"))
		if not poses.has(bone):
			poses[bone] = visual.skeleton.get_bone_global_pose(bone) * visual.skeleton.get_bone_global_rest(bone).affine_inverse() if bone >= 0 else Transform3D.IDENTITY
		var xf: Transform3D = visual.model.global_transform * poses[bone] * (template.transform as Transform3D)
		var piece := fragments[i].node as RigidBody3D
		var mesh := piece.get_child(0) as MeshInstance3D
		var shape := piece.get_child(1) as CollisionShape3D
		var sc := xf.basis.get_scale()
		_base_scales[i] = sc
		mesh.scale = sc
		shape.scale = sc
		piece.global_transform = Transform3D(xf.basis.orthonormalized(), xf.origin)
		piece.linear_velocity = (xf.origin - point).normalized() * 2.0 + impact_direction * 2.0 + Vector3(sin(i * 2.4), 2.4, cos(i * 2.4))
		piece.angular_velocity = Vector3(sin(i), cos(i * 1.7), 0.7) * 4.0
		piece.collision_mask = CollisionLayers.WORLD
		piece.freeze = false
		piece.sleeping = false
	started = true
	show()
	set_physics_process(true)

func _physics_process(delta: float) -> void:
	elapsed += delta
	if elapsed > 1.6 and elapsed < 1.88:
		if not _frozen_for_fade:
			_frozen_for_fade = true
			for fragment in fragments:
				var piece := fragment.node as RigidBody3D
				piece.freeze = true
				piece.collision_mask = CollisionLayers.NONE
		var shrink := maxf(0.01, 1.0 - (elapsed - 1.6) / 0.28)
		for i in fragments.size():
			var piece := fragments[i].node as RigidBody3D
			(piece.get_child(0) as MeshInstance3D).scale = _base_scales[i] * shrink
	if elapsed >= 1.88:
		if not _retiring:
			_retiring = true
			hide()
			for fragment in fragments:
				var piece := fragment.node as RigidBody3D
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
