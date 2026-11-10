class_name SlothWave
extends Node3D
## Segmented mineral ring: no gameplay randomness, lighting or imported assets.
var radius := 3.0
var lifetime := 0.45
var remaining := 0.45
var expanding := true
var _segments: Array[MeshInstance3D] = []
var _mat: StandardMaterial3D


static func spawn(parent: Node, origin: Vector3, size: float, seconds := 0.45, grow := true) -> SlothWave:
	var wave := SlothWave.new()
	wave.radius = size
	wave.lifetime = seconds
	wave.remaining = seconds
	wave.expanding = grow
	parent.add_child(wave)
	wave.global_position = origin
	return wave


func _ready() -> void:
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.albedo_color = Color(1.0, 0.55, 0.10, 0.8)
	_mat.emission_enabled = true
	_mat.emission = Color(1.0, 0.42, 0.05)
	_mat.emission_energy_multiplier = 1.6
	for index in 24:
		var angle := TAU * float(index) / 24.0
		var shard := LatencyStatus._bar(Vector3(radius * 0.19, 0.045, 0.075), _mat)
		shard.rotation.y = -angle
		add_child(shard)
		_segments.append(shard)
	_update_ring()


func _process(delta: float) -> void:
	remaining = maxf(0.0, remaining - delta)
	_update_ring()
	if remaining <= 0.0:
		queue_free()


func _update_ring() -> void:
	var progress := 1.0 - remaining / maxf(lifetime, 0.01)
	var distance := radius * lerpf(0.12, 1.0, progress) if expanding else radius
	_mat.albedo_color.a = 0.75 * (1.0 - progress)
	for index in _segments.size():
		var angle := TAU * float(index) / float(_segments.size())
		_segments[index].position = Vector3(sin(angle) * distance, 0.035 + sin(progress * PI) * 0.2, cos(angle) * distance)
		if expanding:
			_segments[index].rotation.z = progress * (0.6 if index % 2 == 0 else -0.6)
