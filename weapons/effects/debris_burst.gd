class_name DebrisBurst
extends Node3D
## The extra bits of a bullet impact: blood droplets on a body, chips and a dust
## puff on the world. Hand-integrated little billboards, not particle nodes: a
## Godot particle node draws one number from the *global* random sequence when
## it is constructed, which would shift the simulation's randomness (ADR 0005).
## These use a private seeded generator and nothing else random.

const PUFF := preload("res://assets/vfx/puff.png")
const SEED := 90210
const MAX_ALIVE := 12
## Fixed seeds for the two bursts that must replay identically (ADR 0005).
const DEATH_SEED := 0xD3A7
const SPARK_SEED := 0x5A42

static var alive := 0
static var _rng := RandomNumberGenerator.new()
static var _seeded := false
static var _quad: QuadMesh
static var _materials := {}

var _bits: Array[Dictionary] = []
var _age := 0.0
var _life := 0.0
## Size multiplier this burst was spawned with, for tests.
var scale_used := 1.0
## Seed of the private generator this burst used, for tests.
var seed_used := 0
## Set only by spawn_death() / spawn_sparks(): their private generator, so they
## never move the shared burst sequence.
var _local_rng: RandomNumberGenerator


## A cone of droplets (`flesh`) or chips and dust (world) around `normal`.
static func spawn(parent: Node, point: Vector3, normal: Vector3, flesh: bool) -> DebrisBurst:
	if alive >= MAX_ALIVE:
		return null
	if not _seeded:
		_rng.seed = SEED
		_seeded = true
	var burst := _begin(parent, point, 1.0, 0)
	if flesh:
		for i in 6:
			burst._add_bit(normal, 55.0, 1.6, 4.8, 0.035, 9.0, 0.45, Color(0.7, 0.05, 0.04), false)
	else:
		for i in 5:
			burst._add_bit(normal, 70.0, 1.5, 4.2, 0.04, 12.0, 0.5, Color(0.24, 0.21, 0.18), false)
		for i in 3:
			burst._add_bit(normal, 80.0, 0.2, 0.8, 0.2, -0.4, 0.6, Color(0.62, 0.57, 0.48, 0.5), true)
	return burst


## The bigger spray of a death: body-coloured chunks, a little darker blood and
## a dust puff. `direction` is the way the body was pushed. Uses its own seeded
## generator, so every death replays the same and the global sequence is untouched.
static func spawn_death(parent: Node, point: Vector3, direction: Vector3,
		p_scale := 1.0, p_seed := DEATH_SEED) -> DebrisBurst:
	var burst := _begin(parent, point, p_scale, p_seed)
	if burst == null:
		return null
	# Mostly a fountain around the body: chunks fly up and out, so the burst
	# reads from the front instead of disappearing behind the corpse.
	var spray := (Vector3.UP * 2.0 + direction).normalized()
	for i in 22:
		burst._add_scaled_bit(spray, 100.0, 2.0, 4.8, 0.14, 11.0, 0.6, Color(0.55, 0.06, 0.05), false)
	for i in 6:
		burst._add_scaled_bit(spray, 120.0, 0.8, 2.6, 0.15, 9.0, 0.65, Color(0.3, 0.04, 0.04), false)
	# A few pale cloth / skin bits, so the spray reads against a red hoodie.
	for i in 4:
		burst._add_scaled_bit(spray, 110.0, 1.0, 2.8, 0.1, 10.0, 0.55, Color(0.55, 0.55, 0.58), false)
	for i in 4:
		burst._add_scaled_bit(spray, 110.0, 0.9, 2.6, 0.1, 10.0, 0.55, Color(0.85, 0.68, 0.52), false)
	for i in 6:
		burst._add_scaled_bit(spray, 80.0, 0.4, 1.3, 0.4, -0.3, 0.7, Color(0.5, 0.1, 0.08, 0.5), true)
	return burst


## A headshot's bright spark spray, with a few body bits. Private seeded
## generator, like spawn_death().
static func spawn_sparks(parent: Node, point: Vector3, direction: Vector3,
		p_scale := 1.0, p_seed := SPARK_SEED) -> DebrisBurst:
	var burst := _begin(parent, point, p_scale, p_seed)
	if burst == null:
		return null
	for i in 8:
		burst._add_scaled_bit(direction, 65.0, 2.0, 4.0, 0.02, 12.0, 0.28, Color(1.0, 0.82, 0.35), false)
	for i in 5:
		burst._add_scaled_bit(direction, 55.0, 1.0, 2.5, 0.035, 10.0, 0.4, Color(0.6, 0.07, 0.05), false)
	return burst


## How long this burst lives in seconds. For tests.
func lifetime() -> float:
	return _life


## The velocities this burst was given, for the determinism test.
func bit_velocities() -> PackedVector3Array:
	var out := PackedVector3Array()
	for bit in _bits:
		out.append(bit["velocity"])
	return out


func _process(delta: float) -> void:
	_age += delta
	if _age >= _life:
		queue_free()
		return
	for bit in _bits:
		var node: MeshInstance3D = bit.node
		bit.velocity.y -= bit.gravity * delta
		node.position += bit.velocity * delta
		var t := clampf(_age / bit.life, 0.0, 1.0)
		if bit.dust:
			node.scale = Vector3.ONE * bit.base * lerpf(1.0, 2.2, t)
			node.transparency = t
		else:
			node.scale = Vector3.ONE * bit.base * (1.0 - t * t)


func _exit_tree() -> void:
	alive = maxi(alive - 1, 0)


func _add_bit(normal: Vector3, cone_degrees: float, speed_min: float, speed_max: float, size: float,
		gravity: float, life: float, color: Color, dust: bool) -> void:
	if normal.length_squared() < 0.0001:
		normal = Vector3.UP
	var rng := _local_rng if _local_rng != null else _rng
	var node := MeshInstance3D.new()
	node.mesh = _shared_quad()
	node.material_override = _material(color, dust)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# The quad is 0.1 m; `size` goes in through the scale, which _process then
	# animates relative to this base.
	node.scale = Vector3.ONE * size / 0.1
	add_child(node)
	var cone := deg_to_rad(cone_degrees)
	var side := normal.cross(Vector3.UP if absf(normal.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT).normalized()
	var direction := normal.rotated(side, rng.randf() * cone).rotated(normal, rng.randf() * TAU)
	_bits.append({
		"node": node, "velocity": direction * rng.randf_range(speed_min, speed_max),
		"gravity": gravity, "life": life, "dust": dust, "base": size / 0.1})
	_life = maxf(_life, life)


## Same as _add_bit(), with the burst's size multiplier applied to the chunk
## size and speed. The directions stay identical for a given seed.
func _add_scaled_bit(normal: Vector3, cone_degrees: float, speed_min: float, speed_max: float,
		size: float, gravity: float, life: float, color: Color, dust: bool) -> void:
	_add_bit(normal, cone_degrees, speed_min * scale_used, speed_max * scale_used,
		size * scale_used, gravity, life, color, dust)


## Creates a burst and, when `p_seed` is non-zero, gives it its own generator so
## it replays identically and never draws from the shared sequence.
static func _begin(parent: Node, point: Vector3, p_scale: float, p_seed: int) -> DebrisBurst:
	if parent == null or alive >= MAX_ALIVE:
		return null
	var burst := DebrisBurst.new()
	alive += 1
	parent.add_child(burst)
	burst.global_position = point
	burst.scale_used = p_scale
	burst.seed_used = p_seed
	if p_seed != 0:
		burst._local_rng = RandomNumberGenerator.new()
		burst._local_rng.seed = p_seed
	return burst


static func _shared_quad() -> QuadMesh:
	if _quad == null:
		_quad = QuadMesh.new()
		_quad.size = Vector2.ONE * 0.1
	return _quad


static func _material(color: Color, dust: bool) -> StandardMaterial3D:
	var key := "%s%s" % [color, dust]
	if not _materials.has(key):
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		mat.albedo_texture = PUFF
		mat.albedo_color = color
		_materials[key] = mat
	return _materials[key]
