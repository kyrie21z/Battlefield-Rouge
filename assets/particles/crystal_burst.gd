class_name CrystalBurst
extends Node3D
## Cosmetic GPU debris: bounded emitters, cached flat triangles, no gameplay RNG.
const COLORS := [Color("e6a23a"), Color("a777ed"), Color("f14237"), Color("48bddd")]
const MAX_ACTIVE := 48
static var active := 0
static var meshes: Dictionary = {}
static var ring_mesh: TorusMesh

class EmitterPool extends Node3D:
	var ready_for_use := false
	var warm_frames := 0
	func _process(_delta: float) -> void:
		warm_frames += 1
		if warm_frames < 4:
			return
		for child in get_children():
			if child is GPUParticles3D:
				child.emitting = false
				child.hide()
			else:
				child.queue_free()
		ready_for_use = true
		set_process(false)
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
	var pool := EmitterPool.new()
	pool.process_mode = Node.PROCESS_MODE_ALWAYS
	pool.name = "CrystalEmitterPool"
	parent.add_child(pool)
	parent.set_meta("crystal_emitter_pool",pool)
	if ring_mesh == null:
		ring_mesh = TorusMesh.new()
		ring_mesh.inner_radius = 0.94
		ring_mesh.outer_radius = 1.0
		ring_mesh.rings = 48
		ring_mesh.ring_segments = 4
	# Four transparent warm draws compile the same render pipeline as real rings.
	for sin in 4:
		var warm_ring := MeshInstance3D.new()
		warm_ring.mesh = ring_mesh
		var warm_material := ring_material(sin)
		warm_material.albedo_color.a = 0.0
		warm_ring.material_override = warm_material
		pool.add_child(warm_ring)
	for index in MAX_ACTIVE:
		var emitter := GPUParticles3D.new()
		emitter.emitting = false
		emitter.use_fixed_seed = true
		emitter.seed = 0xC1757A1+index
		emitter.amount = 44
		emitter.one_shot = true
		emitter.explosiveness = 1.0
		emitter.lifetime = 2.2
		emitter.visibility_aabb = AABB(Vector3(-7,-5,-7),Vector3(14,12,14))
		emitter.draw_pass_1 = shard_mesh(index%4)
		var process := process_material(index%4)
		process.color = Color(1,1,1,0)
		emitter.process_material = process
		emitter.set_meta("sin_type",index%4)
		pool.add_child(emitter)
		emitter.emitting = true
		emitter.restart()


static func spawn(parent: Node, point: Vector3, sin: int, event: StringName = &"hit", direction := Vector3.UP) -> CrystalBurst:
	if not is_instance_valid(parent) or sin < 0 or sin >= COLORS.size() or active >= MAX_ACTIVE:
		return null
	var pool := parent.get_meta("crystal_emitter_pool",null) as EmitterPool
	if not is_instance_valid(pool) or not pool.ready_for_use:
		return null
	var available: GPUParticles3D
	for child in pool.get_children():
		if child is GPUParticles3D and int(child.get_meta("sin_type",-1))==sin:
			available = child
			break
	if available == null:
		return null
	var burst := CrystalBurst.new()
	burst._pool = pool
	burst.particles = available
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
	particles.amount_ratio = 12.0/44.0 if kind == &"hit" else 1.0
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.lifetime = duration
	particles.randomness = 0.35
	particles.visibility_aabb = AABB(Vector3(-7,-5,-7),Vector3(14,12,14))
	particles.draw_pass_1 = shard_mesh(sin_type)
	var process := particles.process_material as ParticleProcessMaterial
	process.color = Color.WHITE
	process.scale_min = 0.035 if kind == &"hit" else 0.06
	process.scale_max = 0.085 if kind == &"hit" else 0.16
	particles.show()
	add_child(particles)
	if kind != &"hit":
		ring = MeshInstance3D.new()
		ring.mesh = ring_mesh
		ring.material_override = ring_material(sin_type)
		add_child(ring)

static func ring_material(sin: int) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = COLORS[sin]
	material.emission_enabled = true
	material.emission = COLORS[sin]
	material.emission_energy_multiplier = 2.0
	return material

static func process_material(sin: int) -> ParticleProcessMaterial:
	var process := ParticleProcessMaterial.new()
	process.spread = 28.0 if sin == 1 else 100.0
	process.initial_velocity_min = 0.8 if sin == 0 else 2.5
	process.initial_velocity_max = [2.1,8.0,5.0,3.5][sin]
	process.gravity = Vector3(0,-0.35 if sin == 0 else -6.0,0)
	process.damping_min = 0.3
	process.damping_max = 1.0
	process.scale_min = 0.06
	process.scale_max = 0.16
	process.angular_velocity_min = -160.0
	process.angular_velocity_max = 160.0
	var fade := Gradient.new()
	fade.set_color(0,Color.WHITE)
	fade.set_color(1,Color(1,1,1,0))
	var ramp := GradientTexture1D.new()
	ramp.gradient = fade
	process.color_ramp = ramp
	return process


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
		particles.hide()
		remove_child(particles)
		_pool.add_child(particles)
		particles = null
		set_process(false)
		queue_free()

func _exit_tree() -> void:
	if _counted:
		active -= 1
