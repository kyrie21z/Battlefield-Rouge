class_name SorrowCry
extends Node3D
var source: Enemy
var target: Player
var effect_key: StringName
var radius := 0.0
var hit_player := false
var ring: MeshInstance3D
var audio: AudioStreamPlayer3D
const WAVE_BLUE := Color(0.06,0.42,0.95)
static var _ring_mesh: TorusMesh
static var _voice_stream: AudioStreamWAV

static func prepare() -> void:
	if _ring_mesh == null:
		_ring_mesh = TorusMesh.new()
		_ring_mesh.inner_radius = 0.94
		_ring_mesh.outer_radius = 1.0
		_ring_mesh.rings = 48
		_ring_mesh.ring_segments = 4
	if _voice_stream == null:
		_voice_stream = _build_voice()

func _ready() -> void:
	prepare()
	ring = MeshInstance3D.new()
	ring.mesh = _ring_mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = WAVE_BLUE
	mat.emission_enabled = true
	mat.emission = WAVE_BLUE
	mat.emission_energy_multiplier = 0.7
	ring.material_override = mat
	ring.position.y = 0.5
	add_child(ring)
	audio = AudioStreamPlayer3D.new()
	audio.stream = _voice()
	audio.volume_db = -19
	audio.max_distance = 24
	add_child(audio)
	audio.play()

func _physics_process(delta: float) -> void:
	if not is_instance_valid(source) or source.health.is_dead():
		queue_free()
		return
	if source.boon_stunned:
		return
	delta *= source.boon_time_scale
	radius += delta*12
	ring.scale = Vector3(maxf(radius,0.05),1,maxf(radius,0.05))
	if is_instance_valid(target) and not hit_player:
		var distance := global_position.distance_to(target.global_position)
		if distance <= radius+0.6 and distance >= radius-delta*12-1:
			var ray := PhysicsRayQueryParameters3D.create(global_position+Vector3.UP,target.global_position+Vector3.UP,CollisionLayers.WORLD)
			if get_world_3d().direct_space_state.intersect_ray(ray).is_empty():
				hit_player = true
				target.set_realm_effect(effect_key,{"owner":source,"duration":3.0,"reload_multiplier":0.4,"cooldown_multiplier":2.0,"monochrome":1.0})
	if radius > 18:
		queue_free()

func _voice() -> AudioStreamWAV:
	if _voice_stream == null:
		_voice_stream = _build_voice()
	return _voice_stream

static func _build_voice() -> AudioStreamWAV:
	var data := PackedByteArray()
	var rate := 22050
	data.resize(rate*2)
	for i in rate:
		var t := float(i)/rate
		var value := (sin(TAU*(280*t-40*t*t))+sin(TAU*423*t)*0.35)*sin(PI*t)*0.15
		data.encode_s16(i*2,int(value*32767))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.data = data
	return wav

func _exit_tree() -> void:
	if is_instance_valid(audio):
		audio.stop()
		audio.stream = null
