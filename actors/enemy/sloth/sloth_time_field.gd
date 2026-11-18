class_name SlothTimeField
extends MeshInstance3D
## Sample the terrain once. The shader animates the dial or wave on that surface.

const MATERIAL := preload("res://assets/materials/sloth_time_field.gdshader")
const SPOKES := 40
const BANDS := 8
const MAX_STEP := 0.38
const FLOOR_MARGIN := 0.045

var recluse_wave := false
var reach := 3.2
var safe_half_angle := 0.0
var _effect: ShaderMaterial


func _ready() -> void:
	name = "TimeWave" if recluse_wave else "StasisDial"
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_effect = ShaderMaterial.new()
	_effect.shader = MATERIAL
	_effect.set_shader_parameter("wave", recluse_wave)
	_effect.set_shader_parameter("reach", reach)
	_effect.set_shader_parameter("safe_half_angle", safe_half_angle)
	material_override = _effect
	_build_ground_mesh()


func show_charge(progress: float) -> void:
	_effect.set_shader_parameter("progress", progress)


func show_active(age: float, front: float, duration: float) -> void:
	_effect.set_shader_parameter("active", true)
	_effect.set_shader_parameter("age", age)
	_effect.set_shader_parameter("front", front)
	_effect.set_shader_parameter("remaining", duration - age)


static func floor_below(space: PhysicsDirectSpaceState3D, feet: Vector3) -> Vector3:
	var query := PhysicsRayQueryParameters3D.create(feet + Vector3.UP * 0.25,
		feet - Vector3.UP * 3.0, CollisionLayers.WORLD)
	var hit := space.intersect_ray(query)
	return hit.position if not hit.is_empty() and hit.normal.y >= 0.65 else feet


func _build_ground_mesh() -> void:
	var space := get_world_3d().direct_space_state
	var floor_ray := PhysicsRayQueryParameters3D.create(Vector3.ZERO, Vector3.ZERO, CollisionLayers.WORLD)
	var blocker := PhysicsRayQueryParameters3D.create(Vector3.ZERO, Vector3.ZERO, CollisionLayers.WORLD)
	var spokes: Array[PackedVector3Array] = []
	for spoke in SPOKES:
		var angle := float(spoke) * TAU / SPOKES
		var direction := Vector3(sin(angle), 0.0, cos(angle))
		var points := PackedVector3Array([Vector3.ZERO])
		for band in range(1, BANDS + 1):
			var previous := to_global(points[-1])
			var sample := to_global(direction * reach * float(band) / BANDS)
			sample.y = previous.y
			floor_ray.from = sample + Vector3.UP * MAX_STEP
			floor_ray.to = sample - Vector3.UP * (MAX_STEP + FLOOR_MARGIN)
			var hit := space.intersect_ray(floor_ray)
			if hit.is_empty() or hit.normal.y < 0.65:
				break
			var next: Vector3 = hit.position + Vector3.UP * FLOOR_MARGIN
			blocker.from = previous + Vector3.UP * 0.16
			blocker.to = next + Vector3.UP * 0.16
			if not space.intersect_ray(blocker).is_empty():
				break
			points.append(to_local(next))
		spokes.append(points)

	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var vertex_count := 0
	for spoke in SPOKES:
		var a := spokes[spoke]
		var b := spokes[(spoke + 1) % SPOKES]
		for band in range(1, mini(a.size(), b.size())):
			if absf(a[band].y - b[band].y) > MAX_STEP:
				break
			for point in [a[band - 1], b[band], a[band]]:
				_ground_vertex(surface, point)
			vertex_count += 3
			if band > 1:
				for point in [a[band - 1], b[band - 1], b[band]]:
					_ground_vertex(surface, point)
				vertex_count += 3
	if vertex_count > 0:
		mesh = surface.commit()


func _ground_vertex(surface: SurfaceTool, point: Vector3) -> void:
	surface.set_normal(Vector3.UP)
	surface.set_uv(Vector2(point.x, point.z))
	surface.add_vertex(point)
