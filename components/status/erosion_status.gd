class_name ErosionStatus
extends Node3D
## Refreshing five-layer water erosion. Explicit fixed-interval accumulator
## keeps damage identical under different render frame partitions.
signal pulse(status: ErosionStatus, layers: int)
signal saturated(status: ErosionStatus)
signal expired(status: ErosionStatus)
const CYAN := Color(0.12, 0.65, 0.95)
var target: Node3D
var layers := 0
var remaining := 5.0
var duration := 5.0
var interval := 0.5
var _until_tick := 0.5
var active := true
var _crystals: Array[MeshInstance3D] = []


func setup(victim: Node3D, seconds: float, cadence: float) -> void:
	target = victim
	duration = seconds
	remaining = seconds
	interval = cadence
	_until_tick = cadence
	position = Vector3(0, 1.15, 0)


func add_layers(amount: int) -> void:
	var previous := layers
	layers = clampi(layers + amount, 0, 5)
	remaining = duration
	_update_visual()
	if previous < 5 and layers == 5:
		saturated.emit(self)


func advance(delta: float) -> void:
	if not active or not is_inside_tree() or get_tree().paused:
		return
	var step := minf(maxf(delta, 0.0), remaining)
	remaining -= step
	_until_tick -= step
	while _until_tick <= 0.000001 and active:
		_until_tick += interval
		pulse.emit(self, layers)
	if remaining <= 0.000001 and active:
		active = false
		expired.emit(self)
		queue_free()


func cancel() -> void:
	active = false
	visible = false
	queue_free()


func _ready() -> void:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = CYAN
	material.emission_enabled = true
	material.emission = CYAN
	material.emission_energy_multiplier = 0.8
	for index in 5:
		var crystal := MeshInstance3D.new()
		var prism := PrismMesh.new()
		prism.size = Vector3(0.10, 0.22, 0.07)
		crystal.mesh = prism
		crystal.material_override = material
		var angle := float(index) * TAU / 5.0
		crystal.position = Vector3(cos(angle) * 0.38, sin(angle * 2.0) * 0.15, sin(angle) * 0.38)
		add_child(crystal)
		_crystals.append(crystal)
	_update_visual()


func _update_visual() -> void:
	for index in _crystals.size():
		_crystals[index].visible = index < layers
