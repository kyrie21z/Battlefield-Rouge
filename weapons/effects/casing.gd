class_name Casing
extends MeshInstance3D
## A spent shell thrown out of the gun. Not a rigid body: a hand-integrated
## ballistic arc with a spin, a short life and a global cap, so a full-auto
## burst costs a handful of tiny meshes and nothing else.

enum Kind { RIFLE, SHOTGUN, SNIPER }

const LIFE := 0.7
const GRAVITY := 9.8
## Never more than this many alive at once; extra casings are simply not drawn.
const MAX_ALIVE := 24

static var alive := 0
static var _meshes := {}

var _velocity := Vector3.ZERO
var _spin := Vector3.ZERO
var _age := 0.0


static func spawn(parent: Node, at: Vector3, velocity: Vector3, spin: Vector3, kind: Kind) -> Casing:
	if alive >= MAX_ALIVE:
		return null
	var casing := Casing.new()
	casing.mesh = _mesh_for(kind)
	casing.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	casing._velocity = velocity
	casing._spin = spin
	alive += 1
	parent.add_child(casing)
	casing.global_position = at
	return casing


func _process(delta: float) -> void:
	_age += delta
	if _age >= LIFE:
		queue_free()
		return
	_velocity.y -= GRAVITY * delta
	global_position += _velocity * delta
	rotation += _spin * delta
	# Shrink away over the last tenth so it does not pop out of existence.
	var fade := clampf((LIFE - _age) / (LIFE * 0.15), 0.0, 1.0)
	scale = Vector3.ONE * fade


func _exit_tree() -> void:
	alive = maxi(alive - 1, 0)


static func _mesh_for(kind: Kind) -> Mesh:
	if not _meshes.has(kind):
		var mesh := CylinderMesh.new()
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		match kind:
			Kind.SHOTGUN:
				mesh.top_radius = 0.011
				mesh.bottom_radius = 0.011
				mesh.height = 0.06
				material.albedo_color = Color(0.75, 0.12, 0.1)
			Kind.SNIPER:
				mesh.top_radius = 0.008
				mesh.bottom_radius = 0.01
				mesh.height = 0.07
				material.albedo_color = Color(0.9, 0.7, 0.28)
			_:
				mesh.top_radius = 0.0045
				mesh.bottom_radius = 0.006
				mesh.height = 0.045
				material.albedo_color = Color(0.9, 0.7, 0.28)
		mesh.radial_segments = 6
		mesh.rings = 1
		mesh.material = material
		_meshes[kind] = mesh
	return _meshes[kind]
