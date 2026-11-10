class_name CrystalBurst
extends Node3D
## Cosmetic GPU debris: bounded emitters, cached flat triangles, no gameplay RNG.
const COLORS := [Color("e6a23a"), Color("a777ed"), Color("f14237"), Color("48bddd")]
const MAX_ACTIVE := 48
static var active := 0
static var meshes: Dictionary = {}
var sin_type := 0
var kind: StringName = &"hit"
var particles: GPUParticles3D
var ring: MeshInstance3D
var elapsed := 0.0
var duration := 1.6
var _counted := false
var _pool: Node3D

## Godot GPU node constructors draw a global random seed even in fixed-seed mode.
## Allocate BEFORE the room seeds gameplay; all combat spawns only borrow.
static func prepare(parent: Node) -> void:
	if parent.has_meta("crystal_emitter_pool"):
		return
	var pool := Node3D.new()
	pool.name = "CrystalEmitterPool"
	parent.add_child(pool)
	parent.set_meta("crystal_emitter_pool",pool)
	for index in MAX_ACTIVE:
		var emitter := GPUParticles3D.new()
		emitter.emitting = false
		emitter.use_fixed_seed = true
		emitter.seed = 0xC1757A1+index
		pool.add_child(emitter)


static func spawn(parent: Node, point: Vector3, sin: int, event: StringName = &"hit", direction := Vector3.UP) -> CrystalBurst:
	if not is_instance_valid(parent) or sin < 0 or sin >= COLORS.size() or active >= MAX_ACTIVE:
		return null
	var pool := parent.get_meta("crystal_emitter_pool",null) as Node3D
	if not is_instance_valid(pool) or pool.get_child_count()==0:
		return null
	var burst := CrystalBurst.new()
	burst._pool = pool
	burst.particles = pool.get_child(0) as GPUParticles3D
	pool.remove_child(burst.particles)
	burst.sin_type = sin
	burst.kind = event
	parent.add_child(burst)
	burst.global_position = point
	var material := burst.particles.process_material as ParticleProcessMaterial
	material.direction = -direction.normalized() if direction.length_squared() > 0.001 else Vector3.UP
	if event == &"wall_slam" and is_instance_valid(burst.ring):
		var normal := direction.normalized() if direction.length_squared() > 0.001 else Vector3.UP
		burst.ring.basis = Basis(Quaternion(Vector3.UP,normal))
		burst.ring.position = normal*0.025
	burst.particles.emitting = true
	burst.particles.restart()
	return burst

func _ready() -> void:
	active += 1
	_counted = true
	duration = 2.0 if kind == &"wall_slam" else (2.2 if sin_type == 0 else 1.5)
	particles.use_fixed_seed = true
	particles.seed = 0xC1757A1 + sin_type
	particles.name = "CrystalDebris"
	particles.amount = 12 if kind == &"hit" else 44
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.lifetime = duration
	particles.randomness = 0.35
	particles.visibility_aabb = AABB(Vector3(-7,-5,-7),Vector3(14,12,14))
	particles.draw_pass_1 = shard_mesh(sin_type)
	var process := ParticleProcessMaterial.new()
	process.spread = 28.0 if sin_type == 1 else 100.0
	process.initial_velocity_min = 0.8 if sin_type == 0 else 2.5
	process.initial_velocity_max = [2.1,8.0,5.0,3.5][sin_type]
	process.gravity = Vector3(0,-0.35 if sin_type == 0 else -6.0,0)
	process.damping_min = 0.3
	process.damping_max = 1.0
	process.scale_min = 0.035 if kind == &"hit" else 0.06
	process.scale_max = 0.085 if kind == &"hit" else 0.16
	process.angular_velocity_min = -160.0
	process.angular_velocity_max = 160.0
	var fade := Gradient.new()
	fade.set_color(0,Color.WHITE)
	fade.set_color(1,Color(1,1,1,0))
	var ramp := GradientTexture1D.new()
	ramp.gradient = fade
	process.color_ramp = ramp
	particles.process_material = process
	add_child(particles)
	if kind != &"hit":
		ring = MeshInstance3D.new()
		var shape := TorusMesh.new()
		shape.inner_radius = 0.94
		shape.outer_radius = 1.0
		shape.rings = 48
		shape.ring_segments = 4
		ring.mesh = shape
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.albedo_color = COLORS[sin_type]
		material.emission_enabled = true
		material.emission = COLORS[sin_type]
		material.emission_energy_multiplier = 2.0
		ring.material_override = material
		add_child(ring)

static func shard_mesh(sin: int) -> ArrayMesh:
	if meshes.has(sin):
		return meshes[sin]
	var width := 0.38 if sin == 1 else 0.65
	var height := 1.8 if sin == 1 else 1.0
	var vertices := [Vector3(0,height,0),Vector3(width,0,0),Vector3(0,0,width),Vector3(-width,0,0),Vector3(0,0,-width),Vector3(0,-height*0.55,0)]
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for face in [[0,2,1],[0,3,2],[0,4,3],[0,1,4],[5,1,2],[5,2,3],[5,3,4],[5,4,1]]:
		var normal: Vector3 = (vertices[face[1]]-vertices[face[0]]).cross(vertices[face[2]]-vertices[face[0]]).normalized()
		for index in face:
			surface.set_normal(normal)
			surface.add_vertex(vertices[index])
	var mesh := surface.commit()
	var material := StandardMaterial3D.new()
	material.albedo_color = COLORS[sin]
	material.metallic = 0.45
	material.roughness = 0.22
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.emission_enabled = true
	material.emission = COLORS[sin]
	material.emission_energy_multiplier = 0.65
	mesh.surface_set_material(0,material)
	meshes[sin] = mesh
	return mesh

func _process(delta: float) -> void:
	if particles == null:
		return
	elapsed += delta
	if is_instance_valid(ring):
		var size_value := 0.65 if kind == &"wall_slam" else 0.2 + elapsed * (2.4 if sin_type == 3 else 3.5)
		ring.scale = Vector3.ONE * size_value
		(ring.material_override as StandardMaterial3D).albedo_color.a = maxf(0.0,1.0-elapsed/duration)
	if elapsed >= duration + 0.1:
		particles.emitting = false
		remove_child(particles)
		_pool.add_child(particles)
		particles = null
		set_process(false)
		queue_free()

func _exit_tree() -> void:
	if _counted:
		active -= 1
