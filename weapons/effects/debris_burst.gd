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

static var alive := 0
static var _rng := RandomNumberGenerator.new()
static var _seeded := false
static var _quad: QuadMesh
static var _materials := {}

var _bits: Array[Dictionary] = []
var _age := 0.0
var _life := 0.0


## A cone of droplets (`flesh`) or chips and dust (world) around `normal`.
static func spawn(parent: Node, point: Vector3, normal: Vector3, flesh: bool) -> DebrisBurst:
	if alive >= MAX_ALIVE:
		return null
	if not _seeded:
		_rng.seed = SEED
		_seeded = true
	var burst := DebrisBurst.new()
	alive += 1
	parent.add_child(burst)
	burst.global_position = point
	if flesh:
		for i in 6:
			burst._add_bit(normal, 55.0, 1.6, 4.8, 0.035, 9.0, 0.45, Color(0.7, 0.05, 0.04), false)
	else:
		for i in 5:
			burst._add_bit(normal, 70.0, 1.5, 4.2, 0.04, 12.0, 0.5, Color(0.24, 0.21, 0.18), false)
		for i in 3:
			burst._add_bit(normal, 80.0, 0.2, 0.8, 0.2, -0.4, 0.6, Color(0.62, 0.57, 0.48, 0.5), true)
	return burst


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
	var direction := normal.rotated(side, _rng.randf() * cone).rotated(normal, _rng.randf() * TAU)
	_bits.append({
		"node": node, "velocity": direction * _rng.randf_range(speed_min, speed_max),
		"gravity": gravity, "life": life, "dust": dust, "base": size / 0.1})
	_life = maxf(_life, life)


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
