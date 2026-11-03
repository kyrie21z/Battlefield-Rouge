class_name Tracer
extends MeshInstance3D
## A short bright streak that flies from the muzzle to where the shot ended, then
## frees itself. One thin stretched box with an unshaded additive material; no
## physics, no particles, no random numbers.

const SPEED := 320.0
const LENGTH := 5.0
const THICKNESS := 0.014
## Longest path drawn, so a shot into the sky does not chase the horizon.
const MAX_PATH := 120.0

static var _mesh: BoxMesh
static var _material: StandardMaterial3D

var _from := Vector3.ZERO
var _direction := Vector3.FORWARD
var _distance := 0.0
var _travelled := 0.0


static func spawn(parent: Node, from: Vector3, to: Vector3) -> Tracer:
	var path := to - from
	if path.length() < 0.5:
		return null
	var tracer := Tracer.new()
	tracer._from = from
	tracer._direction = path.normalized()
	tracer._distance = minf(path.length(), MAX_PATH)
	tracer.mesh = _shared_mesh()
	tracer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(tracer)
	tracer._place()
	return tracer


func _process(delta: float) -> void:
	_travelled += SPEED * delta
	if _travelled - LENGTH >= _distance:
		queue_free()
		return
	_place()


## Streak between the tail and the head of the flight, along the shot line.
func _place() -> void:
	var head := minf(_travelled, _distance)
	var tail := maxf(_travelled - LENGTH, 0.0)
	var length := maxf(head - tail, 0.01)
	var up := Vector3.UP if absf(_direction.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
	var basis := Basis.looking_at(_direction, up).scaled(Vector3(1.0, 1.0, length))
	global_transform = Transform3D(basis, _from + _direction * (head + tail) * 0.5)


static func _shared_mesh() -> BoxMesh:
	if _mesh == null:
		_material = StandardMaterial3D.new()
		_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_material.albedo_color = Color(1.0, 0.86, 0.55, 0.75)
		_mesh = BoxMesh.new()
		_mesh.size = Vector3(THICKNESS, THICKNESS, 1.0)
		_mesh.material = _material
	return _mesh
