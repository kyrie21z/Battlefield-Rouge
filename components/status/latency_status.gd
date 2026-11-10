class_name LatencyStatus
extends Node3D
## One non-refreshing clock per victim. The owning effect advances this clock
## with simulation delta and observes resolved damage; visuals share that clock.
signal detonated(status: LatencyStatus, origin: Vector3, damage: float)

const AMBER := Color(1.0, 0.56, 0.12)
var target: Node3D
var duration := 1.5
var remaining := 1.5
var base_damage := 60.0
var shot_pressure := 0.0
var damage_pressure := 0.0
var pressure_multiplier := 1.0
## Raw base/shot pressure receives current offense once; recorded HP loss has
## already resolved offense and must never receive it a second time.
var offense_scale: Callable
var slow_factor := 0.6
var active := true
var _ticks: Array[MeshInstance3D] = []
var _hand: MeshInstance3D
var _counter: Label3D


func setup(victim: Node3D, seconds: float, base: float, deep := false) -> void:
	target = victim
	duration = maxf(seconds, 0.01)
	remaining = duration
	base_damage = maxf(base, 0.0)
	slow_factor = 0.3 if deep else 0.6
	position = Vector3(0, 2.35, 0)


func _ready() -> void:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = AMBER
	mat.emission_enabled = true
	mat.emission = AMBER
	mat.emission_energy_multiplier = 1.4
	for index in 12:
		var angle := TAU * float(index) / 12.0
		var tick := _bar(Vector3(0.045, 0.105, 0.025), mat)
		tick.position = Vector3(sin(angle), cos(angle), 0) * 0.28
		tick.rotation.z = -angle
		add_child(tick)
		_ticks.append(tick)
	_hand = _bar(Vector3(0.022, 0.24, 0.03), mat)
	add_child(_hand)
	_counter = Label3D.new()
	_counter.font_size = 40
	_counter.pixel_size = 0.003
	_counter.position = Vector3(0, -0.43, 0)
	_counter.modulate = AMBER
	_counter.outline_modulate = Color(0.08, 0.035, 0.005)
	_counter.no_depth_test = false
	add_child(_counter)
	_update_clock()


func add_shot_pressure(amount: float) -> void:
	if active:
		shot_pressure += maxf(amount, 0.0)


func record_damage(actual: float) -> void:
	if active:
		damage_pressure += maxf(actual, 0.0)


func deepen() -> void:
	slow_factor = minf(slow_factor, 0.3)


func burst_damage(multiplier := 1.0) -> float:
	var scale := float(offense_scale.call()) if offense_scale.is_valid() else 1.0
	return ((base_damage + shot_pressure) * scale + damage_pressure * pressure_multiplier) * multiplier


func advance(delta: float) -> void:
	if not active or not is_inside_tree() or get_tree().paused:
		return
	remaining = maxf(0.0, remaining - maxf(delta, 0.0))
	_update_clock()
	if remaining <= 0.000001:
		detonate()


func detonate(multiplier := 1.0) -> void:
	if not active:
		return
	active = false
	var origin := target.global_position + Vector3.UP
	visible = false
	detonated.emit(self, origin, burst_damage(multiplier))
	queue_free()


func cancel() -> void:
	active = false
	visible = false
	queue_free()


func _update_clock() -> void:
	if not is_instance_valid(_hand):
		return
	var fraction := clampf(remaining / duration, 0.0, 1.0)
	var angle := TAU * (1.0 - fraction)
	_hand.rotation.z = -angle
	_hand.position = Vector3(sin(angle), cos(angle), 0) * 0.10
	_counter.text = "%.1f" % remaining
	for index in _ticks.size():
		_ticks[index].visible = float(index) < ceilf(fraction * 12.0)
	var camera := get_viewport().get_camera_3d()
	if is_instance_valid(camera) and global_position.distance_squared_to(camera.global_position) > 0.01:
		look_at(camera.global_position, Vector3.UP, true)


static func _bar(size: Vector3, mat: Material) -> MeshInstance3D:
	var item := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	item.mesh = box
	item.material_override = mat
	item.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return item
