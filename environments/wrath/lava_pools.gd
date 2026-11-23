extends Node3D
## The glowing ellipses are the damage footprint. Their dark lips are safe.

const MELT := preload("res://assets/materials/wrath_kiln_melt.gdshader")
const DAMAGE := 12.0
const TICK_INTERVAL := 0.65
const BEDS := [
	Vector4(-6.5, 9.7, 2.55, 1.55),
	Vector4(5.0, -3.5, 1.85, 2.03),
	Vector4(-7.0, -13.2, 2.40, 1.70),
]

var player: Player
var _molten := ShaderMaterial.new()
var _lights: Array[OmniLight3D] = []
var _clock := 0.0
var _until_tick := 0.0


func _ready() -> void:
	_molten.shader = MELT
	var basalt := StandardMaterial3D.new()
	basalt.albedo_color = Color("382a2d")
	basalt.roughness = 0.92
	basalt.vertex_color_use_as_albedo = true
	for bed: Vector4 in BEDS:
		var basin := Node3D.new()
		basin.position = Vector3(bed.x, 0.0, bed.y)
		add_child(basin)
		var radii := Vector2(bed.z, bed.w)
		_add_mesh(basin, _surface(radii), _molten)
		_add_mesh(basin, _lip(radii), basalt)
		var glow := OmniLight3D.new()
		glow.position.y = 0.66
		glow.light_color = Color("ff6940")
		glow.light_energy = 0.72
		glow.light_specular = 0.24
		glow.omni_range = 5.0
		basin.add_child(glow)
		_lights.append(glow)


func set_deprivation(active: bool) -> void:
	_molten.set_shader_parameter("heat", 0.0 if active else 1.0)
	for glow in _lights:
		glow.visible = not active
	_until_tick = 0.0
	set_physics_process(not active)


func _physics_process(delta: float) -> void:
	_clock += delta
	_molten.set_shader_parameter("flow_time", _clock)
	_until_tick = maxf(0.0, _until_tick - delta)
	if _until_tick > 0.0 or not is_instance_valid(player) or player.health.is_dead() or not player.is_on_floor():
		return
	var feet := to_local(player.global_position)
	if feet.y > 0.18:
		return
	for bed: Vector4 in BEDS:
		var offset := (Vector2(feet.x, feet.z) - Vector2(bed.x, bed.y)) / Vector2(bed.z, bed.w)
		if offset.length_squared() <= 1.0:
			_until_tick = TICK_INTERVAL
			player.health.apply_damage(DAMAGE, Hitbox.BodyPart.BODY, null, {"tag": &"lava"})
			return


func _surface(radii: Vector2) -> ArrayMesh:
	const SIDES := 40
	const BANDS := 5
	var steps := SurfaceTool.new()
	steps.begin(Mesh.PRIMITIVE_TRIANGLES)
	for band in BANDS + 1:
		var fraction := float(band) / BANDS
		for side in SIDES:
			var angle := TAU * side / SIDES
			var uv := Vector2(cos(angle), sin(angle)) * fraction
			steps.set_normal(Vector3.UP)
			steps.set_uv(Vector2(0.5 + uv.x * 0.5, uv.y * radii.y))
			steps.set_uv2(Vector2(radii.x * 2.0, 1.0))
			steps.add_vertex(Vector3(uv.x * radii.x, 0.070 - fraction * fraction * 0.010, uv.y * radii.y))
			if band > 0:
				var inner := (band - 1) * SIDES + side
				var inner_next := (band - 1) * SIDES + (side + 1) % SIDES
				for index in [inner, inner + SIDES, inner_next + SIDES]:
					steps.add_index(index)
				if band > 1:
					for index in [inner, inner_next + SIDES, inner_next]:
						steps.add_index(index)
	return steps.commit()


func _lip(radii: Vector2) -> ArrayMesh:
	const SIDES := 40
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	for side in SIDES:
		var a := TAU * side / SIDES
		var b := TAU * (side + 1) / SIDES
		var inner_a := _rim_point(radii, a, 0.995, 0.055)
		var inner_b := _rim_point(radii, b, 0.995, 0.055)
		var ridge_a := _rim_point(radii, a, 1.07, 0.135 + sin(a * 17.0) * 0.047)
		var ridge_b := _rim_point(radii, b, 1.07, 0.135 + sin(b * 17.0) * 0.047)
		var outer_a := _rim_point(radii, a, 1.16 + 0.031 * sin(a * 9.0), 0.008)
		var outer_b := _rim_point(radii, b, 1.16 + 0.031 * sin(b * 9.0), 0.008)
		st.set_color(Color.WHITE.darkened(0.20 + 0.24 * absf(sin(side * 3.7))))
		for point in [inner_a, ridge_b, inner_b, inner_a, ridge_a, ridge_b,
				ridge_a, outer_b, ridge_b, ridge_a, outer_a, outer_b]:
			st.add_vertex(point)
	st.generate_normals()
	return st.commit()


func _rim_point(radii: Vector2, angle: float, scale_value: float, height: float) -> Vector3:
	return Vector3(cos(angle) * radii.x * scale_value, height, sin(angle) * radii.y * scale_value)


func _add_mesh(parent: Node3D, mesh: ArrayMesh, material: Material) -> void:
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.material_override = material
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(visual)
