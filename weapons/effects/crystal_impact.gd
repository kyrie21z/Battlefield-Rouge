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
static var alive := 0
## Private sequence, so consecutive hits get their own shard pattern without
## touching the simulation's global random stream (ADR 0005).
static var _spawn_seq := 0
static var _mesh: PrismMesh
static var _dark: StandardMaterial3D
static var _glint: StandardMaterial3D

var _age := 0.0
var _pieces: Array[MeshInstance3D] = []
var _velocities: Array[Vector3] = []
var _spin: Array[Vector3] = []
## For tests: the private seed this burst used and the size multiplier it got.
var seed_used := 0
var scale_used := 1.0


static func spawn(parent: Node, point: Vector3, normal: Vector3, headshot := false) -> Node3D:
	if parent == null or alive >= MAX_ALIVE:
		return null
	var burst := load("res://weapons/effects/crystal_impact.gd").new() as CrystalImpact
	parent.add_child(burst)
	burst.global_position = point + normal * 0.02
	burst.scale_used = HEADSHOT_SCALE if headshot else 1.0
	alive += 1
	burst._build(normal)
	_spawn_glint(parent, point)
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


## The light lives beside the burst instead of inside it, and frees itself, so
## the shard node stays exactly the authored polyhedra.
static func _spawn_glint(parent: Node, point: Vector3) -> void:
	if not parent.is_inside_tree():
		return
	var light := OmniLight3D.new()
	light.light_color = GLINT_COLOR
	light.light_energy = GLINT_ENERGY
	light.omni_range = GLINT_RANGE
	light.shadow_enabled = false
	parent.add_child(light)
	light.global_position = point
	var weak: WeakRef = weakref(light)
	parent.get_tree().create_timer(GLINT_TIME).timeout.connect(
		func() -> void:
			var node: Object = weak.get_ref()
			if node != null:
				node.queue_free())


func _process(delta: float) -> void:
	_age += delta
	if _age >= LIFETIME:
		queue_free()
		return
	var shrink := (1.0 - pow(_age / LIFETIME, 2.0)) * scale_used
	for i in _pieces.size():
		_velocities[i].y -= 6.0 * delta
		_pieces[i].position += _velocities[i] * delta
		_pieces[i].rotation += _spin[i] * delta
		_pieces[i].scale = Vector3.ONE * shrink


func _exit_tree() -> void:
	alive = maxi(alive - 1, 0)
