class_name Projectile
extends Node3D
## Glowing tracer for enemy fire. Moves in a straight line and sweeps a ray each
## physics frame from its last position, so it cannot tunnel through thin
## geometry even at 30 m/s.

const MASK := CollisionLayers.WORLD | CollisionLayers.HITBOXES | CollisionLayers.PARRY
## The tracer is this many seconds of travel long, so it reads at any speed.
const TRACER_SECONDS := 0.035
const TRACER_MIN_LENGTH := 0.7

var speed := 30.0
var damage := 10.0
var max_distance := 45.0
## The shooter, passed to Health as the damage source (for the team check).
var source: Node
var exclude: Array[RID] = []
var tint := Color(1.0, 0.55, 0.2)

var reflected := false

var _travelled := 0.0
var _tracer_length := TRACER_MIN_LENGTH


static func spawn(parent: Node, from: Vector3, direction: Vector3, p_source: Node, p_damage: float,
		p_speed: float, p_exclude: Array[RID], p_tint: Color = Color(1.0, 0.55, 0.2)) -> Projectile:
	var projectile := Projectile.new()
	projectile.source = p_source
	projectile.damage = p_damage
	projectile.speed = p_speed
	projectile.exclude = p_exclude
	projectile.tint = p_tint
	parent.add_child(projectile)
	projectile.global_position = from
	projectile.look_at(from + direction, Vector3.UP if absf(direction.y) < 0.99 else Vector3.FORWARD)
	return projectile


func _ready() -> void:
	_tracer_length = maxf(TRACER_MIN_LENGTH, speed * TRACER_SECONDS)
	var mesh := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.045
	capsule.height = _tracer_length
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = tint
	mat.emission_enabled = true
	mat.emission = tint
	mat.emission_energy_multiplier = 4.0
	capsule.material = mat
	mesh.mesh = capsule
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Capsules stand along Y; lay it along -Z, the flight direction.
	mesh.rotation.x = PI * 0.5
	add_child(mesh)

	# A camera-facing glow, so the bullet reads clearly even when it flies
	# straight at the player and the tracer is seen end-on.
	var glow := Sprite3D.new()
	var gradient := Gradient.new()
	gradient.set_color(0, tint.lightened(0.5))
	gradient.set_color(1, Color(tint.r, tint.g, tint.b, 0.0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(0.5, 0.0)
	texture.width = 64
	texture.height = 64
	glow.texture = texture
	glow.pixel_size = 0.8 / 64.0
	glow.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	glow.shaded = false
	glow.transparent = true
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(glow)

	var light := OmniLight3D.new()
	light.light_color = tint
	light.light_energy = 1.0
	light.omni_range = 2.0
	add_child(light)


## Length of the visible tracer in metres. For tests.
func tracer_length() -> float:
	return _tracer_length


func _physics_process(delta: float) -> void:
	var from := global_position
	var to := from - global_basis.z * speed * delta
	var query := PhysicsRayQueryParameters3D.create(from, to, MASK, exclude)
	query.collide_with_areas = true
	query.hit_from_inside = true
	var space := get_world_3d().direct_space_state
	var hit := space.intersect_ray(query)
	# An inactive/rear-facing blade is transparent to the projectile. Exclude
	# only that area for this sweep, then continue to the actual world/body hit.
	while not hit.is_empty() and hit.collider is Area3D:
		var area := hit.collider as Area3D
		if area.has_method("try_parry") and area.try_parry(self, hit.position):
			return
		var skipped := query.exclude
		skipped.append(area.get_rid())
		query.exclude = skipped
		hit = space.intersect_ray(query)
	if not hit.is_empty():
		# Sparks on walls only: a puff on the player's own hitbox would sit
		# right in front of the camera. The HUD damage flash covers that case.
		if not hit.collider is Hitbox:
			Impact.spawn(get_parent(), hit.position, hit.normal, false)
		else:
			(hit.collider as Hitbox).apply_hit_at(damage, source, hit.position, -global_basis.z, true)
		queue_free()
		return
	global_position = to
	_travelled += speed * delta
	if _travelled >= max_distance:
		queue_free()


## Transfer ownership atomically: the old shooter's exclusions must disappear,
## and the player's bodies must be excluded before the next swept step.
func reflect(new_source: CollisionObject3D, point: Vector3) -> void:
	var direction := global_basis.z.normalized()
	source = new_source
	reflected = true
	exclude = []
	_collect_exclusions(new_source)
	speed = maxf(60.0, speed * 1.8)
	damage = maxf(damage * 2.0, 55.0)
	_travelled = 0.0
	global_position = point
	look_at(point + direction, Vector3.UP if absf(direction.y) < 0.99 else Vector3.FORWARD)
	for child in get_children():
		if child is OmniLight3D:
			child.light_color = Color(1.0, 0.85, 0.4)


func _collect_exclusions(node: Node) -> void:
	if node is CollisionObject3D:
		exclude.append((node as CollisionObject3D).get_rid())
	for child in node.get_children():
		_collect_exclusions(child)
