class_name Impact
extends GPUParticles3D
## One-shot burst where a bullet lands, facing along the surface normal. Frees itself.
##  - flesh: a dark red puff plus a few droplets,
##  - world: sparks plus debris chips and a small dust puff.
## The sparks / puff are this node; the droplets, chips and dust are a
## DebrisBurst, added only when `detail` is true (a shotgun asks for them on the
## first few pellets only). Not more particle nodes: each one would draw a
## number from the global random sequence when constructed.

const SPARK := preload("res://assets/vfx/spark.png")
const PUFF := preload("res://assets/vfx/puff.png")


static func spawn(parent: Node, point: Vector3, normal: Vector3, flesh: bool, detail := true) -> void:
	var impact := Impact.new()
	impact._setup(flesh)
	parent.add_child(impact)
	impact.global_position = point + normal * 0.02
	if absf(normal.dot(Vector3.UP)) < 0.99:
		impact.look_at(point + normal, Vector3.UP)
	else:
		impact.look_at(point + normal, Vector3.FORWARD)
	impact.emitting = true
	if detail:
		DebrisBurst.spawn(parent, impact.global_position, normal, flesh)
	impact.finished.connect(impact.queue_free)
	# `finished` never comes without a renderer; the timer keeps headless runs clean.
	impact.get_tree().create_timer(1.0).timeout.connect(impact.queue_free)


func _setup(flesh: bool) -> void:
	one_shot = true
	explosiveness = 1.0
	amount = 8 if flesh else 14
	lifetime = 0.4 if flesh else 0.28

	var process := ParticleProcessMaterial.new()
	# Particles fly out along -Z, which look_at() pointed along the normal.
	process.direction = Vector3(0, 0, -1)
	process.spread = 40.0 if flesh else 60.0
	process.initial_velocity_min = 0.7 if flesh else 2.2
	process.initial_velocity_max = 1.8 if flesh else 6.0
	process.gravity = Vector3(0, -6.0, 0)
	process.scale_min = 0.7
	process.scale_max = 1.5 if flesh else 1.3
	process.color_ramp = _fade_ramp(1.0)
	process_material = process

	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * (0.2 if flesh else 0.1)
	quad.material = _material(PUFF if flesh else SPARK,
		Color(0.55, 0.08, 0.06) if flesh else Color(1.0, 0.8, 0.45), not flesh)
	draw_pass_1 = quad


static func _fade_ramp(start_alpha: float) -> GradientTexture1D:
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, start_alpha))
	fade.set_color(1, Color(1, 1, 1, 0))
	var ramp := GradientTexture1D.new()
	ramp.gradient = fade
	return ramp


static func _material(texture: Texture2D, color: Color, additive: bool) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if additive else BaseMaterial3D.BLEND_MODE_MIX
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = texture
	mat.albedo_color = color
	return mat
