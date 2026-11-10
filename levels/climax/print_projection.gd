class_name PrintProjection
extends Node3D
## Original geometry and deterministic PCM; clocks come from the controller.
var beam: MeshInstance3D
var sparks: GPUParticles3D
var laser: AudioStreamPlayer3D
var material: ShaderMaterial
var elapsed := 0.0
var reduced_motion := false
func _ready() -> void:
	beam = MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.15
	cylinder.bottom_radius = 1.05
	cylinder.height = 3.1
	cylinder.radial_segments = 48
	beam.mesh = cylinder
	beam.position.y = 1.55
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	material = ShaderMaterial.new()
	material.shader = preload("res://levels/climax/shaders/print_projection.gdshader")
	beam.material_override = material
	add_child(beam)
	# Godot consumes a global RNG value in this constructor even with a fixed
	# seed. Allocate exactly once during cinematic setup, never during combat.
	sparks = GPUParticles3D.new()
	sparks.amount = 48
	sparks.lifetime = 0.38
	sparks.use_fixed_seed = true
	sparks.seed = 170
	sparks.visibility_aabb = AABB(Vector3(-2,-1,-2),Vector3(4,5,4))
	var particles := ParticleProcessMaterial.new()
	particles.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	particles.emission_ring_radius = 1.0
	particles.emission_ring_inner_radius = 0.4
	particles.emission_ring_height = 0.015
	particles.emission_ring_axis = Vector3.UP
	particles.direction = Vector3(0,0.3,0)
	particles.spread = 85
	particles.initial_velocity_min = 0.25
	particles.initial_velocity_max = 0.8
	particles.gravity = Vector3(0,-1.8,0)
	sparks.process_material = particles
	var shard := PrismMesh.new()
	shard.size = Vector3(0.013,0.038,0.013)
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = Color(0.65,0.85,1)
	glow.emission_enabled = true
	glow.emission = Color(0.5,0.8,1)
	glow.emission_energy_multiplier = 3
	shard.material = glow
	sparks.draw_pass_1 = shard
	add_child(sparks)
	sparks.emitting = false
	laser = AudioStreamPlayer3D.new()
	laser.stream = make_laser_audio()
	laser.volume_db = -13
	laser.unit_size = 9
	add_child(laser)
	hide()
func begin(reduce := false) -> void:
	reduced_motion = reduce
	elapsed = 0
	show()
	sparks.emitting = not reduced_motion
	laser.play()
func advance(delta: float, cutoff: float, reduce: bool) -> void:
	elapsed += delta
	reduced_motion = reduce
	material.set_shader_parameter("visual_time",elapsed)
	material.set_shader_parameter("reduced_motion",reduce)
	sparks.position.y = cutoff
	sparks.emitting = visible and not reduce
	laser.position.y = cutoff
func finish() -> void:
	hide()
	sparks.emitting = false
	laser.stop()
static func make_laser_audio() -> AudioStreamWAV:
	var samples := PackedFloat32Array()
	samples.resize(int(2.5 * ProceduralAudio.SAMPLE_RATE))
	for index in samples.size():
		var t := float(index) / ProceduralAudio.SAMPLE_RATE
		var envelope := minf(t / 0.035,1) * minf((2.5-t) / 0.08,1)
		# Cold laser partials, stepper chatter, and a final mechanical latch.
		var hum := sin(TAU*780*t+sin(TAU*33*t)*0.4)*0.22 + sin(TAU*1561*t)*0.07
		var stepper := sin(TAU*118*t)*pow(maxf(sin(TAU*18*t),0),8)*0.17
		var latch := sin(TAU*210*t)*exp(-maxf(t-2.3,0)*24)*0.18 if t>2.3 else 0.0
		samples[index] = (hum+stepper+latch)*envelope
	return ProceduralAudio._make_normalised_wav(samples,-6.0)
