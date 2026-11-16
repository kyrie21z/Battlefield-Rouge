class_name FearShatter
extends Node3D
## All 56 authored shard meshes, frozen to the live 24-bone pose, then rigid physics.
var pieces: Array[RigidBody3D] = []
var elapsed := 0.0
static var _collision_shapes: Array[Shape3D] = []
var started := false
var _material: ShaderMaterial
var _retiring := false
const RESERVE_KEY := &"fear_prepared_shatter"

static func prepare_for(visual: Node3D, source: ShaderMaterial) -> FearShatter:
	var existing := visual.get_meta(RESERVE_KEY) as FearShatter if visual.has_meta(RESERVE_KEY) else null
	if is_instance_valid(existing): return existing
	var burst := FearShatter.new()
	burst.prepare(source)
	visual.set_meta(RESERVE_KEY,burst)
	visual.tree_exiting.connect(burst._discard_unused,CONNECT_ONE_SHOT)
	return burst

static func take(visual: Node3D, source: ShaderMaterial) -> FearShatter:
	var burst := prepare_for(visual,source)
	visual.remove_meta(RESERVE_KEY)
	return burst

func _discard_unused() -> void:
	if not started: queue_free()

static func prepare_templates() -> void:
	if not _collision_shapes.is_empty():
		return
	SlothShatter.prepare_templates()
	for entry in SlothShatter._templates:
		_collision_shapes.append((entry.mesh as Mesh).create_convex_shape(true, true))

func prepare(source: ShaderMaterial) -> void:
	if not pieces.is_empty(): return
	prepare_templates()
	_material = source.duplicate() as ShaderMaterial
	var physics := PhysicsMaterial.new()
	physics.bounce = 0.25
	for entry in SlothShatter._templates:
		var piece := RigidBody3D.new()
		piece.collision_layer = 0
		piece.collision_mask = 0
		piece.freeze = true
		piece.mass = 0.07
		piece.continuous_cd = true
		piece.physics_material_override = physics
		var mesh := MeshInstance3D.new()
		mesh.mesh = entry.mesh
		mesh.material_override = _material
		piece.add_child(mesh)
		var collision := CollisionShape3D.new()
		collision.shape = _collision_shapes[pieces.size()]
		piece.add_child(collision)
		add_child(piece)
		pieces.append(piece)
	hide()
	set_physics_process(false)

func release(source: ShaderMaterial, flash := true) -> void:
	for parameter in ["base_color","rim_color","emission_color","emission_strength","rim_strength","inner_glow","spec_color"]:
		_material.set_shader_parameter(parameter,source.get_shader_parameter(parameter))
	if flash: _material.set_shader_parameter("rim_strength",0.7)
	started = true
	show()
	set_physics_process(true)
	for piece in pieces:
		piece.collision_mask = CollisionLayers.WORLD
		piece.freeze = false
		piece.sleeping = false

func build(visual: SlothVisual, point: Vector3, direction: Vector3) -> void:
	prepare(visual.crystal_material())
	var poses := {}
	for index in SlothShatter._templates.size():
		var entry: Dictionary = SlothShatter._templates[index]
		var bone := visual.skeleton.find_bone(SlothShatter.PART_BONE.get(entry.part,"Spine"))
		if not poses.has(bone):
			poses[bone] = visual.skeleton.get_bone_global_pose(bone)*visual.skeleton.get_bone_global_rest(bone).affine_inverse() if bone >= 0 else Transform3D.IDENTITY
		var xf: Transform3D = visual.model.global_transform*poses[bone]*(entry.transform as Transform3D)
		var piece := pieces[index]
		piece.global_transform = xf
		var scatter := Vector3(sin(index * 2.4), 0.8 + cos(index) * 0.3, cos(index * 2.4))
		piece.linear_velocity = (xf.origin - point).normalized() * 2 + direction.normalized() * 1.5 + scatter
		piece.angular_velocity = Vector3(cos(index), sin(index * 2.2), 0.7) * 3
	release(visual.crystal_material())

func _physics_process(delta: float) -> void:
	elapsed += delta
	if elapsed < 2.4: return
	if not _retiring:
		_retiring = true
		hide()
		for piece in pieces:
			piece.freeze = true
			piece.collision_mask = 0
	# Spread destruction too: several simultaneous kills must not free 280
	# rigid bodies in a single combat frame.
	for index in mini(8,pieces.size()):
		var piece := pieces.pop_back() as RigidBody3D
		piece.queue_free()
	if pieces.is_empty(): queue_free()
