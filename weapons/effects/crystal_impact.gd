class_name CrystalImpact
extends Node3D
## Pistol-only impact: solid faceted shards, no flesh billboards or textures.
## The bounded, short-lived effect uses its own random stream, never simulation RNG.

const MAX_ALIVE := 24
const SHARDS := 8
const LIFETIME := 0.45
const SEED := 0x0B51D
## A headshot spray is bigger and starts faster.
const HEADSHOT_SCALE := 1.45
## Short unshadowed point light so the hit reads at range.
const GLINT_TIME := 0.06
const GLINT_ENERGY := 3.5
const GLINT_RANGE := 1.8
const GLINT_COLOR := Color(0.72, 0.90, 1.0)
const DEFLECT_COLOR := Color(1.0, 0.86, 0.56)
static var alive := 0
static var deflect_alive := 0
static var _spawn_seq := 0
static var _mesh: PrismMesh
static var _dark: StandardMaterial3D
static var _glint: StandardMaterial3D
static var _spark_mesh: BoxMesh
static var _spark_material: StandardMaterial3D


class GlintLight extends OmniLight3D:
	var _left := GLINT_TIME
	var _total := GLINT_TIME
	var _peak := GLINT_ENERGY

	func _init(color: Color, energy: float, range_m: float, duration: float) -> void:
		process_mode = Node.PROCESS_MODE_PAUSABLE
		light_color = color
		light_energy = energy
		omni_range = range_m
		shadow_enabled = false
		_left = duration
		_total = maxf(duration, 0.001)
		_peak = energy

	func _process(delta: float) -> void:
		if get_tree().paused:
			return
		_left = maxf(_left - delta, 0.0)
		if _left <= 0.0:
			queue_free()
			return
		light_energy = _peak * (_left / _total)


var _age := 0.0
var _pieces: Array[MeshInstance3D] = []
var _velocities: Array[Vector3] = []
var _spin: Array[Vector3] = []
## For tests: the private seed this burst used and the size multiplier it got.
var seed_used := 0
var scale_used := 1.0
var is_deflect := false
var _lifetime := LIFETIME


static func spawn(parent: Node, point: Vector3, normal: Vector3, headshot := false) -> Node3D:
	if parent == null or alive >= MAX_ALIVE:
		return null
	var burst := load("res://weapons/effects/crystal_impact.gd").new() as CrystalImpact
	parent.add_child(burst)
	burst.global_position = point + normal * 0.02
	burst.scale_used = HEADSHOT_SCALE if headshot else 1.0
	alive += 1
	burst._build(normal)
	_spawn_glint(parent, point, GLINT_COLOR, GLINT_ENERGY)
	return burst


static func spawn_deflect(parent: Node, point: Vector3, normal: Vector3) -> Node3D:
	if parent == null or deflect_alive >= MAX_ALIVE:
		return null
	var burst := load("res://weapons/effects/crystal_impact.gd").new() as CrystalImpact
	parent.add_child(burst)
	burst.global_position = point + normal * 0.02
	burst.is_deflect = true
	burst._lifetime = 0.24
	deflect_alive += 1
	burst._build_deflect(normal)
	_spawn_glint(parent, point, DEFLECT_COLOR, 2.8)
	return burst


## The velocities of every shard, for the determinism/randomisation test.
func shard_velocities() -> PackedVector3Array:
	var out := PackedVector3Array()
	for velocity in _velocities:
		out.append(velocity)
	return out


func _build(normal: Vector3) -> void:
	if _mesh == null:
		_mesh = PrismMesh.new()
		_mesh.size = Vector3(0.065, 0.10, 0.04)
		_dark = StandardMaterial3D.new()
		_dark.albedo_color = Color(0.025, 0.035, 0.06)
		_dark.roughness = 0.25
		_glint = StandardMaterial3D.new()
		_glint.albedo_color = Color(0.65, 0.84, 0.95)
		_glint.emission_enabled = true
		_glint.emission = Color(0.12, 0.27, 0.4)
		_glint.roughness = 0.25
	var rng := RandomNumberGenerator.new()
	_spawn_seq += 1
	seed_used = SEED + _spawn_seq
	rng.seed = seed_used
	var outward := normal.normalized() if normal.length_squared() > 0.001 else Vector3.UP
	for i in SHARDS:
		var piece := MeshInstance3D.new()
		piece.mesh = _mesh
		piece.material_override = _dark if i % 2 == 0 else _glint
		piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		piece.rotation = Vector3(rng.randf(), rng.randf(), rng.randf()) * TAU
		add_child(piece)
		_pieces.append(piece)
		var scatter := Vector3(rng.randf_range(-1, 1), rng.randf_range(0.2, 1.2), rng.randf_range(-1, 1))
		_velocities.append((outward * 1.5 + scatter).normalized() * rng.randf_range(1.5, 4.0) * scale_used)
		_spin.append(Vector3(rng.randf_range(-9, 9), rng.randf_range(-9, 9), rng.randf_range(-9, 9)))


func _build_deflect(normal: Vector3) -> void:
	if _spark_mesh == null:
		_spark_mesh = BoxMesh.new()
		_spark_mesh.size = Vector3(0.018, 0.018, 0.11)
		_spark_material = StandardMaterial3D.new()
		_spark_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_spark_material.albedo_color = DEFLECT_COLOR
		_spark_material.emission_enabled = true
		_spark_material.emission = DEFLECT_COLOR
		_spark_material.emission_energy_multiplier = 2.4
	var rng := RandomNumberGenerator.new()
	_spawn_seq += 1
	seed_used = SEED + _spawn_seq
	rng.seed = seed_used
	var outward := normal.normalized() if normal.length_squared() > 0.001 else Vector3.UP
	for i in 10:
		var piece := MeshInstance3D.new()
		piece.mesh = _spark_mesh
		piece.material_override = _spark_material
		piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var scatter := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.4, 1.0), rng.randf_range(-1, 1))
		var direction := (outward * 1.8 + scatter).normalized()
		var up := Vector3.UP if absf(direction.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
		piece.basis = Basis.looking_at(direction, up)
		add_child(piece)
		_pieces.append(piece)
		_velocities.append(direction * rng.randf_range(3.2, 6.8))
		_spin.append(Vector3.ZERO)


static func _spawn_glint(parent: Node, point: Vector3, color: Color, energy: float) -> void:
	if not parent.is_inside_tree():
		return
	var light := GlintLight.new(color, energy, GLINT_RANGE, GLINT_TIME)
	parent.add_child(light)
	light.global_position = point


func _process(delta: float) -> void:
	if get_tree().paused:
		return
	_age += delta
	if _age >= _lifetime:
		queue_free()
		return
	var shrink := (1.0 - pow(_age / _lifetime, 2.0)) * scale_used
	for i in _pieces.size():
		_velocities[i].y -= 6.0 * delta
		_pieces[i].position += _velocities[i] * delta
		_pieces[i].rotation += _spin[i] * delta
		_pieces[i].scale = Vector3.ONE * shrink


func _exit_tree() -> void:
	if is_deflect:
		deflect_alive = maxi(deflect_alive - 1, 0)
	else:
		alive = maxi(alive - 1, 0)
