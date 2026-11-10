class_name CrystalImpact
extends Node3D
## Pistol-only impact: solid faceted shards, no flesh billboards or textures.
## The bounded, short-lived effect uses its own random stream, never simulation RNG.

const MAX_ALIVE := 24
const SHARDS := 8
const LIFETIME := 0.45
const SEED := 0x0B51D
static var alive := 0
static var _mesh: PrismMesh
static var _dark: StandardMaterial3D
static var _glint: StandardMaterial3D

var _age := 0.0
var _pieces: Array[MeshInstance3D] = []
var _velocities: Array[Vector3] = []
var _spin: Array[Vector3] = []


static func spawn(parent: Node, point: Vector3, normal: Vector3) -> Node3D:
	if parent == null or alive >= MAX_ALIVE:
		return null
	var burst: Node3D = load("res://weapons/effects/crystal_impact.gd").new()
	parent.add_child(burst)
	burst.global_position = point + normal * 0.02
	alive += 1
	burst._build(normal)
	return burst


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
	rng.seed = SEED
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
		_velocities.append((outward * 1.5 + scatter).normalized() * rng.randf_range(1.5, 4.0))
		_spin.append(Vector3(rng.randf_range(-9, 9), rng.randf_range(-9, 9), rng.randf_range(-9, 9)))


func _process(delta: float) -> void:
	_age += delta
	if _age >= LIFETIME:
		queue_free()
		return
	var shrink := 1.0 - pow(_age / LIFETIME, 2.0)
	for i in _pieces.size():
		_velocities[i].y -= 6.0 * delta
		_pieces[i].position += _velocities[i] * delta
		_pieces[i].rotation += _spin[i] * delta
		_pieces[i].scale = Vector3.ONE * shrink


func _exit_tree() -> void:
	alive = maxi(alive - 1, 0)
