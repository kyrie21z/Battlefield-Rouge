class_name SlothResinPool
extends MeshInstance3D
## The warning and the active gel share a floor-projected footprint.

const RADIUS := 3.2
const LIFETIME := 3.5
const MIN_FLOOR_NORMAL := 0.64
const TICK_SECONDS := 0.25
const TICK_DAMAGE := 2.5
const SLOW_MULTIPLIER := 0.65
const SECTORS := 24
const RINGS := 4
const MAX_STEP := 0.34
const SURFACE_OFFSET := 0.035
const SLOW_EFFECT := &"sloth_resin"
const GEL := preload("res://assets/materials/sloth_resin_pool.gdshader")


class ShaderWarmup extends Node3D:
	var _frames := 0

	func _process(_delta: float) -> void:
		_frames += 1
		if _frames >= 4:
			queue_free()


static func prepare_shader(parent: Node) -> void:
	if not is_instance_valid(parent) or parent.has_meta("sloth_resin_warmed"):
		return
	parent.set_meta("sloth_resin_warmed", true)
	var warmup := ShaderWarmup.new()
	warmup.name = "SlothResinWarmup"
	var quad := QuadMesh.new()
	quad.size = Vector2(0.005, 0.005)
	for is_landed in [false, true]:
		var mat := ShaderMaterial.new()
		mat.shader = GEL
		mat.set_shader_parameter("landed", is_landed)
		var mi := MeshInstance3D.new()
		mi.mesh = quad
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.extra_cull_margin = 16384.0
		warmup.add_child(mi)
	parent.add_child(warmup)

var victim: Player
var attacker: Enemy
var damage_scale := 1.0
var landed := false
var age := 0.0
var _affecting := false
var _until_tick := TICK_SECONDS
var _gel: ShaderMaterial
var _triangles: Array[PackedVector3Array] = []


func _ready() -> void:
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_gel = ShaderMaterial.new()
	_gel.shader = GEL
	material_override = _gel
	_build_surface()
	set_physics_process(false)


func land() -> void:
	landed = true
	_gel.set_shader_parameter("landed", true)
	show()
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	delta = minf(delta, LIFETIME - age)
	age += delta
	_gel.set_shader_parameter("gel_age", age)
	var spread := lerpf(0.40, 1.0, smoothstep(0.0, 0.18, age))
	_gel.set_shader_parameter("spread", spread)
	if is_instance_valid(victim) and not victim.health.is_dead() and _touches(victim.global_position, spread):
		_damage_while_inside(delta)
	else:
		_clear_slow()
	if age >= LIFETIME:
		queue_free()


func _damage_while_inside(delta: float) -> void:
	if not _affecting:
		# One player-wide source avoids stacking damage in overlapping pools.
		if victim.realm_effects.effects.has(SLOW_EFFECT):
			return
		_affecting = true
		_until_tick = TICK_SECONDS
		victim.set_realm_effect(SLOW_EFFECT, {"move_multiplier": SLOW_MULTIPLIER, "owner": self})
	_until_tick -= delta
	while _until_tick <= 0.00001 and not victim.health.is_dead():
		_until_tick += TICK_SECONDS
		var source := attacker if is_instance_valid(attacker) else null
		victim.health.apply_damage(TICK_DAMAGE * damage_scale, Hitbox.BodyPart.BODY, source,
			{"tag": &"sloth_resin", "kind": &"proc", "proc_depth": 1})


func _clear_slow() -> void:
	if _affecting:
		_affecting = false
		if is_instance_valid(victim) and is_instance_valid(victim.realm_effects):
			victim.clear_realm_effect(SLOW_EFFECT)


func _exit_tree() -> void:
	_clear_slow()


func _touches(feet: Vector3, spread: float) -> bool:
	var local_feet := to_local(feet)
	var flat := Vector2(local_feet.x, local_feet.z)
	if flat.length_squared() > (RADIUS * spread) ** 2 or absf(local_feet.y) > 1.8:
		return false
	var angle := fposmod(flat.angle(), TAU)
	var sector := mini(int(angle / TAU * SECTORS), SECTORS - 1)
	var triangles := _triangles[sector]
	# Sample the same triangles we draw, so a jump or a lower storey is safe.
	for vertex in range(0, triangles.size(), 3):
		if Geometry3D.segment_intersects_triangle(local_feet + Vector3.UP * 0.07,
				local_feet - Vector3.UP * 0.23, triangles[vertex], triangles[vertex + 1],
				triangles[vertex + 2]) != null:
			return true
	return false


func _build_surface() -> void:
	var space := get_world_3d().direct_space_state
	var floor_ray := PhysicsRayQueryParameters3D.create(Vector3.ZERO, Vector3.ZERO, CollisionLayers.WORLD)
	var wall_ray := PhysicsRayQueryParameters3D.create(Vector3.ZERO, Vector3.ZERO, CollisionLayers.WORLD)
	var spokes: Array[PackedVector3Array] = []
	var center := Vector3.UP * SURFACE_OFFSET
	# The ray fan is built just once, at lock. Stop a spoke at walls and at
	# drops so both the gel and its damage stay on the accessible surface.
	for sector in SECTORS:
		var angle := float(sector) * TAU / SECTORS
		var edge := RADIUS * (0.94 + 0.037 * cos(angle * 5.0) + 0.023 * sin(angle * 9.0 + 0.8))
		var spoke := PackedVector3Array([center])
		for ring in range(1, RINGS + 1):
			var previous := to_global(spoke[-1])
			var sample := to_global(Vector3(cos(angle), 0.0, sin(angle)) * edge * float(ring) / RINGS)
			sample.y = previous.y
			floor_ray.from = sample + Vector3.UP * MAX_STEP
			floor_ray.to = sample - Vector3.UP * (MAX_STEP + SURFACE_OFFSET)
			var hit := space.intersect_ray(floor_ray)
			if hit.is_empty() or hit.normal.y < MIN_FLOOR_NORMAL:
				break
			var next: Vector3 = hit.position + Vector3.UP * SURFACE_OFFSET
			wall_ray.from = previous + Vector3.UP * 0.09
			wall_ray.to = next + Vector3.UP * 0.09
			if not space.intersect_ray(wall_ray).is_empty():
				break
			spoke.append(to_local(next))
		spokes.append(spoke)

	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var has_surface := false
	for sector in SECTORS:
		var left := spokes[sector]
		var right := spokes[(sector + 1) % SECTORS]
		var triangles := PackedVector3Array()
		for ring in range(1, mini(left.size(), right.size())):
			var t := float(ring) / RINGS
			var inner := float(ring - 1) / RINGS
			if absf(left[ring].y - right[ring].y) > MAX_STEP:
				break
			_emit_triangle(surface, triangles, left[ring - 1], left[ring], right[ring], Vector3(inner, t, t))
			if ring > 1:
				_emit_triangle(surface, triangles, left[ring - 1], right[ring], right[ring - 1], Vector3(inner, t, inner))
		has_surface = has_surface or not triangles.is_empty()
		_triangles.append(triangles)
	if has_surface:
		mesh = surface.commit()


func _emit_triangle(surface: SurfaceTool, triangles: PackedVector3Array,
		a: Vector3, b: Vector3, c: Vector3, radial: Vector3) -> void:
	var points := [a, b, c]
	for index in 3:
		var point: Vector3 = points[index]
		triangles.append(point)
		surface.set_normal(Vector3.UP)
		surface.set_uv(Vector2(point.x, point.z) / RADIUS)
		surface.set_color(Color(radial[index], 0.0, 0.0))
		surface.add_vertex(point)
