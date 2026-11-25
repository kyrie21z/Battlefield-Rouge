class_name Tracer
extends MeshInstance3D
## A short bright streak that flies from the muzzle to where the shot ended, then
## frees itself. One thin stretched box with an unshaded additive material; no
## physics, no particles, no random numbers.

const SPEED := 190.0
const LENGTH := 5.0
const THICKNESS := 0.020
## Longest path drawn, so a shot into the sky does not chase the horizon.
const MAX_PATH := 120.0
## The player's default tracer colour; realm tints come from Projectile.REALM_TINTS.
const DEFAULT_TINT := Color(1.0, 0.86, 0.55, 0.75)

static var _meshes := {}

var _from := Vector3.ZERO
var _direction := Vector3.FORWARD
var _distance := 0.0
var _travelled := 0.0


static func spawn(parent: Node, from: Vector3, to: Vector3,
		tint: Color = DEFAULT_TINT) -> Tracer:
	var path := to - from
	if path.length() < 0.5:
		return null
	var tracer := Tracer.new()
	tracer._from = from
	tracer._direction = path.normalized()
	tracer._distance = minf(path.length(), MAX_PATH)
	tracer.mesh = _shared_mesh(tint)
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
	var basis := Basis.looking_at(_direction, up)
	# Stretch the local flight axis. World-axis scaling after rotation skews
	# the streak away from its path when the player turns or pitches the gun.
	basis.z *= length
	global_transform = Transform3D(basis, _from + _direction * (head + tail) * 0.5)


## One mesh/material per tint, cached so a new colour costs a single allocation.
static func _shared_mesh(tint: Color) -> BoxMesh:
	var key := tint.to_html()
	if not _meshes.has(key):
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		material.albedo_color = tint
		var mesh := BoxMesh.new()
		mesh.size = Vector3(THICKNESS, THICKNESS, 1.0)
		mesh.material = material
		_meshes[key] = mesh
	return _meshes[key]
