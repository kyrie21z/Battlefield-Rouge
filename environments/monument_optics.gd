class_name MonumentOptics
extends RefCounted
## Shared Ultra-1 monumental PBR optics, sky IBL, and atmospheric baseline.
## Uses deterministic fixed seeds (AC-07 safe) and WeakRef texture caching so
## all scenes reuse baked 512px mineral maps without leaking resources at exit.

const STONE_SHADER := preload("res://assets/materials/mind_monument_stone.gdshader")
const SKY_SHADER := preload("res://assets/materials/mind_realm_sky.gdshader")

const PRESERVE_SHADERS := [
	"castle_glass.gdshader",
	"wrath_kiln_melt.gdshader",
	"wrath_kiln_fur.gdshader",
	"water_mirror.gdshader",
	"water.gdshader",
	"flooded_fall.gdshader",
	"rain_motion.gdshader",
	"cloud_sea.gdshader",
	"sloth_time_field.gdshader",
	"sloth_resin_pool.gdshader",
	"sloth_cloth.gdshader",
]

static var _normal_ref: WeakRef
static var _height_ref: WeakRef
static var _vein_ref: WeakRef

static func _shared_textures() -> Dictionary:
	if DisplayServer.get_name() == "headless":
		var stub: Texture2D = _normal_ref.get_ref() if _normal_ref != null else null
		if stub == null:
			stub = ImageTexture.create_from_image(Image.create(2, 2, false, Image.FORMAT_RGBA8))
			_normal_ref = weakref(stub)
		return {"normal": stub, "height": stub, "vein": stub}

	var tex_normal: NoiseTexture2D = _normal_ref.get_ref() if _normal_ref != null else null
	if tex_normal == null:
		var n_stone := FastNoiseLite.new()
		n_stone.seed = 20261127
		n_stone.noise_type = FastNoiseLite.TYPE_PERLIN
		n_stone.frequency = 0.032
		n_stone.fractal_type = FastNoiseLite.FRACTAL_FBM
		n_stone.fractal_octaves = 6
		n_stone.fractal_lacunarity = 2.15
		n_stone.fractal_gain = 0.56
		n_stone.domain_warp_enabled = true
		n_stone.domain_warp_amplitude = 6.0
		n_stone.domain_warp_frequency = 0.025
		tex_normal = NoiseTexture2D.new()
		tex_normal.width = 512
		tex_normal.height = 512
		tex_normal.seamless = true
		tex_normal.seamless_blend_skirt = 0.18
		tex_normal.as_normal_map = true
		tex_normal.bump_strength = 9.5
		tex_normal.noise = n_stone
		_normal_ref = weakref(tex_normal)

	var tex_height: NoiseTexture2D = _height_ref.get_ref() if _height_ref != null else null
	if tex_height == null:
		var n_height := FastNoiseLite.new()
		n_height.seed = 90421
		n_height.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		n_height.frequency = 0.022
		n_height.fractal_type = FastNoiseLite.FRACTAL_FBM
		n_height.fractal_octaves = 4
		n_height.fractal_gain = 0.50
		tex_height = NoiseTexture2D.new()
		tex_height.width = 512
		tex_height.height = 512
		tex_height.seamless = true
		tex_height.seamless_blend_skirt = 0.20
		tex_height.noise = n_height
		_height_ref = weakref(tex_height)

	var tex_vein: NoiseTexture2D = _vein_ref.get_ref() if _vein_ref != null else null
	if tex_vein == null:
		var n_vein := FastNoiseLite.new()
		n_vein.seed = 44109
		n_vein.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		n_vein.frequency = 0.014
		n_vein.fractal_type = FastNoiseLite.FRACTAL_RIDGED
		n_vein.fractal_octaves = 5
		n_vein.fractal_lacunarity = 2.05
		n_vein.fractal_gain = 0.55
		n_vein.domain_warp_enabled = true
		n_vein.domain_warp_amplitude = 18.0
		n_vein.domain_warp_frequency = 0.012
		tex_vein = NoiseTexture2D.new()
		tex_vein.width = 512
		tex_vein.height = 512
		tex_vein.seamless = true
		tex_vein.seamless_blend_skirt = 0.22
		tex_vein.noise = n_vein
		_vein_ref = weakref(tex_vein)

	return {"normal": tex_normal, "height": tex_height, "vein": tex_vein}

static func make_stone_material(cfg: Dictionary, is_floor := false) -> ShaderMaterial:
	var tex := _shared_textures()
	var mat := ShaderMaterial.new()
	mat.shader = STONE_SHADER
	mat.set_shader_parameter("is_floor", is_floor)
	mat.set_shader_parameter("carved_frame_enabled", cfg.get("carved_frame_enabled", true))
	mat.set_shader_parameter("court_inlay_enabled", cfg.get("court_inlay_enabled", is_floor))
	var default_crack := 0.46 if is_floor else 0.28
	mat.set_shader_parameter("crack_density", cfg.get("crack_density", default_crack))
	mat.set_shader_parameter("micro_normal_tex", tex["normal"])
	mat.set_shader_parameter("micro_height_tex", tex["height"])
	mat.set_shader_parameter("mineral_vein_tex", tex["vein"])
	mat.set_shader_parameter("stone_albedo", cfg.get("stone_albedo", Color("c9c3b8")))
	mat.set_shader_parameter("dark_albedo", cfg.get("dark_albedo", Color("151922")))
	mat.set_shader_parameter("inlay_metal", cfg.get("inlay_metal", Color("b89252")))
	mat.set_shader_parameter("crystal_glint_color", cfg.get("crystal_glint_color", Color("ffe7c2")))
	mat.set_shader_parameter("sun_direction", cfg.get("sun_direction", Vector3(-0.62, 0.27, -0.74)))
	return mat

static func make_trim_material(albedo: Color, roughness := 0.42, metallic := 0.84) -> StandardMaterial3D:
	var tex := _shared_textures()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = albedo
	mat.normal_enabled = true
	mat.normal_texture = tex["normal"]
	mat.normal_scale = 0.22
	mat.metallic = metallic
	mat.roughness = roughness
	mat.clearcoat = 0.14
	return mat

static func make_obsidian_material(albedo: Color) -> StandardMaterial3D:
	var tex := _shared_textures()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = albedo
	mat.normal_enabled = true
	mat.normal_texture = tex["normal"]
	mat.normal_scale = 0.25
	mat.metallic = 0.28
	mat.roughness = 0.15
	mat.clearcoat = 0.82
	mat.clearcoat_roughness = 0.08
	return mat

static func make_sky(cfg: Dictionary) -> Sky:
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = SKY_SHADER
	sky_mat.set_shader_parameter("zenith_color", cfg.get("zenith_color", Color("112338")))
	sky_mat.set_shader_parameter("horizon_color", cfg.get("horizon_color", Color("9eaab8")))
	sky_mat.set_shader_parameter("ground_color", cfg.get("ground_color", Color("2c3645")))
	sky_mat.set_shader_parameter("sun_color", cfg.get("sun_color", Color("ffd091")))
	sky_mat.set_shader_parameter("sun_dir", cfg.get("sun_dir", Vector3(-0.62, 0.27, -0.74)))
	sky_mat.set_shader_parameter("sky_energy", cfg.get("sky_energy", 0.94))
	sky_mat.set_shader_parameter("sun_halo_strength", cfg.get("sun_halo_strength", 0.54))
	sky_mat.set_shader_parameter("sun_disk_strength", cfg.get("sun_disk_strength", 3.0))
	var sky := Sky.new()
	sky.radiance_size = Sky.RADIANCE_SIZE_128
	sky.sky_material = sky_mat
	return sky

static func configure_environment(env: Environment, cfg: Dictionary) -> void:
	env.background_mode = Environment.BG_SKY
	env.sky = make_sky(cfg)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 1.0
	env.ambient_light_energy = cfg.get("ambient_light_energy", 0.70)
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = cfg.get("tonemap_exposure", 0.96)
	env.ssao_enabled = true
	env.ssao_radius = 1.50
	env.ssao_intensity = 1.48
	env.ssao_power = 1.32
	env.ssao_detail = 0.85
	env.ssao_light_affect = 0.20
	env.ssil_enabled = true
	env.ssil_radius = 4.6
	env.ssil_intensity = 0.90
	env.ssr_enabled = cfg.get("ssr_enabled", true)
	env.ssr_max_steps = cfg.get("ssr_max_steps", 48)
	env.ssr_fade_in = cfg.get("ssr_fade_in", 0.15)
	env.ssr_fade_out = cfg.get("ssr_fade_out", 2.0)
	env.ssr_depth_tolerance = 0.25
	env.glow_enabled = true
	env.glow_normalized = true
	env.glow_intensity = cfg.get("glow_intensity", 0.24)
	env.glow_bloom = cfg.get("glow_bloom", 0.08)
	env.glow_hdr_threshold = cfg.get("glow_hdr_threshold", 1.12)
	env.fog_enabled = true
	env.fog_light_color = cfg.get("fog_light_color", Color("99a8b8"))
	env.fog_density = cfg.get("fog_density", 0.0050)
	env.fog_aerial_perspective = cfg.get("fog_aerial_perspective", 0.56)
	env.fog_sky_affect = cfg.get("fog_sky_affect", 0.24)
	if cfg.has("fog_height"):
		env.fog_height = cfg["fog_height"]
		env.fog_height_density = cfg.get("fog_height_density", 0.0)
	env.volumetric_fog_enabled = cfg.get("volumetric_fog_enabled", true)
	env.volumetric_fog_density = cfg.get("volumetric_fog_density", 0.0080)
	env.volumetric_fog_albedo = cfg.get("volumetric_fog_albedo", Color("d9c9b6"))
	if cfg.has("volumetric_fog_emission"):
		env.volumetric_fog_emission = cfg["volumetric_fog_emission"]
		env.volumetric_fog_emission_energy = cfg.get("volumetric_fog_emission_energy", 0.14)
	env.volumetric_fog_anisotropy = cfg.get("volumetric_fog_anisotropy", 0.70)
	env.volumetric_fog_length = cfg.get("volumetric_fog_length", 105.0)
	env.adjustment_enabled = true
	env.adjustment_contrast = cfg.get("adjustment_contrast", 1.10)
	env.adjustment_saturation = cfg.get("adjustment_saturation", 1.04)

static func configure_sun(sun: DirectionalLight3D, rot_deg: Vector3, color: Color, energy: float, max_dist := 120.0) -> void:
	sun.rotation_degrees = rot_deg
	sun.light_color = color
	sun.light_energy = energy
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = max_dist
	sun.shadow_bias = 0.055
	sun.shadow_normal_bias = 0.58
	sun.light_angular_distance = 1.4

static func add_reflection_probe(parent: Node3D, probe_size := Vector3(54.0, 26.0, 64.0), pos := Vector3(0.0, 7.5, 0.0), intensity := 1.0) -> ReflectionProbe:
	var probe := ReflectionProbe.new()
	probe.name = "MonumentReflectionProbe"
	probe.position = pos
	probe.size = probe_size
	probe.box_projection = true
	probe.interior = false
	probe.intensity = intensity
	probe.update_mode = ReflectionProbe.UPDATE_ONCE
	parent.add_child(probe)
	return probe

static func add_volumetric_shaft(parent: Node3D, from_pos: Vector3, target: Vector3, color: Color, energy: float, fog_energy: float, spot_range := 52.0, angle := 32.0, shadows := true) -> SpotLight3D:
	var shaft := SpotLight3D.new()
	shaft.name = "VolumetricShaft"
	shaft.light_color = color
	shaft.light_energy = energy
	shaft.light_volumetric_fog_energy = fog_energy
	shaft.spot_range = spot_range
	shaft.spot_angle = angle
	shaft.shadow_enabled = shadows
	parent.add_child(shaft)
	shaft.look_at_from_position(from_pos, target, Vector3.UP)
	return shaft

static func apply_monument_override(node: Node, wall_mat: Material, floor_mat: Material, trim_mat: Material, dark_mat: Material) -> void:
	if node is MeshInstance3D or node is MultiMeshInstance3D:
		var gi := node as GeometryInstance3D
		var orig := _current_material(gi)
		if not _should_preserve(orig):
			if _is_floor_node(gi, orig):
				gi.material_override = floor_mat
			elif orig is StandardMaterial3D:
				var std := orig as StandardMaterial3D
				if std.metallic >= 0.30:
					gi.material_override = trim_mat
				elif std.albedo_color.get_luminance() < 0.22:
					gi.material_override = dark_mat
				else:
					gi.material_override = wall_mat
			elif orig is ShaderMaterial:
				gi.material_override = wall_mat
	for child in node.get_children():
		apply_monument_override(child, wall_mat, floor_mat, trim_mat, dark_mat)

static func _current_material(gi: GeometryInstance3D) -> Material:
	if gi.material_override != null:
		return gi.material_override
	if gi is MeshInstance3D:
		var mi := gi as MeshInstance3D
		if mi.mesh is PrimitiveMesh:
			return (mi.mesh as PrimitiveMesh).material
		if mi.mesh != null and mi.mesh.get_surface_count() > 0:
			return mi.mesh.surface_get_material(0)
	elif gi is MultiMeshInstance3D:
		var mmi := gi as MultiMeshInstance3D
		if mmi.multimesh != null and mmi.multimesh.mesh != null:
			var m := mmi.multimesh.mesh
			if m is PrimitiveMesh:
				return (m as PrimitiveMesh).material
			if m.get_surface_count() > 0:
				return m.surface_get_material(0)
	return null

static func _is_floor_node(gi: GeometryInstance3D, orig: Material) -> bool:
	if orig is ShaderMaterial and (orig as ShaderMaterial).shader != null:
		var spath: String = (orig as ShaderMaterial).shader.resource_path
		if spath.ends_with("floor.gdshader") or spath.ends_with("wrath_kiln_floor.gdshader"):
			return true
	var nlow := gi.name.to_lower()
	if "floor" in nlow or "court" in nlow or "paving" in nlow or "deck" in nlow:
		return true
	if gi is MeshInstance3D and (gi as MeshInstance3D).mesh is BoxMesh:
		var sz: Vector3 = ((gi as MeshInstance3D).mesh as BoxMesh).size
		if sz.x >= 8.0 and sz.z >= 8.0 and sz.y <= 2.5:
			return true
	return false

static func _should_preserve(orig: Material) -> bool:
	if orig == null:
		return true
	if orig is ShaderMaterial and (orig as ShaderMaterial).shader != null:
		var spath: String = (orig as ShaderMaterial).shader.resource_path
		if spath.ends_with("mind_monument_stone.gdshader"):
			return true
		for fn in PRESERVE_SHADERS:
			if spath.ends_with(fn):
				return true
	if orig is StandardMaterial3D:
		var std := orig as StandardMaterial3D
		if std.emission_enabled or std.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
			return true
	return false

static func realm_preset(realm_id: String) -> Dictionary:
	match realm_id:
		"sloth":
			return {
				"wall": {
					"stone_albedo": Color("c9c3b8"), "dark_albedo": Color("151922"),
					"inlay_metal": Color("b89252"), "crystal_glint_color": Color("ffe7c2"),
					"sun_direction": Vector3(-0.62, 0.27, -0.74), "crack_density": 0.28,
				},
				"floor": {
					"stone_albedo": Color("9ca4ad"), "dark_albedo": Color("131720"),
					"inlay_metal": Color("be9652"), "crystal_glint_color": Color("ffe4ba"),
					"sun_direction": Vector3(-0.62, 0.27, -0.74), "crack_density": 0.46,
					"court_inlay_enabled": true,
				},
				"trim_color": Color("a6834c"),
				"obsidian_color": Color("141923"),
				"env": {
					"zenith_color": Color("112338"), "horizon_color": Color("9eaab8"),
					"ground_color": Color("2c3645"), "sun_color": Color("ffd091"),
					"sun_dir": Vector3(-0.62, 0.27, -0.74), "sky_energy": 0.94,
					"sun_halo_strength": 0.54, "sun_disk_strength": 3.0,
					"ambient_light_energy": 0.70, "tonemap_exposure": 0.96, "glow_intensity": 0.24,
					"fog_light_color": Color("99a8b8"), "fog_density": 0.0050,
					"fog_aerial_perspective": 0.56, "fog_sky_affect": 0.24,
					"volumetric_fog_density": 0.0082, "volumetric_fog_albedo": Color("d9c9b6"),
					"volumetric_fog_anisotropy": 0.72,
				},
				"sun_rot": Vector3(-18.0, -40.0, 0.0), "sun_color": Color("ffd9a6"), "sun_energy": 1.90,
			}
		"fear":
			return {
				"wall": {
					"stone_albedo": Color("7d7591"), "dark_albedo": Color("120d1f"),
					"inlay_metal": Color("a89bc9"), "crystal_glint_color": Color("d2c7ff"),
					"sun_direction": Vector3(0.42, 0.48, -0.76), "crack_density": 0.28,
				},
				"floor": {
					"stone_albedo": Color("5f5973"), "dark_albedo": Color("0e0a1a"),
					"inlay_metal": Color("9c8fc4"), "crystal_glint_color": Color("cabfff"),
					"sun_direction": Vector3(0.42, 0.48, -0.76), "crack_density": 0.46,
					"court_inlay_enabled": false,
				},
				"trim_color": Color("8c82ad"),
				"obsidian_color": Color("161024"),
				"env": {
					"zenith_color": Color("2d244a"), "horizon_color": Color("72659c"),
					"ground_color": Color("231c38"), "sun_color": Color("d8d0ff"),
					"sun_dir": Vector3(0.42, 0.48, -0.76), "sky_energy": 1.15,
					"sun_halo_strength": 0.36, "sun_disk_strength": 2.0,
					"ambient_light_energy": 0.98, "tonemap_exposure": 1.06, "glow_intensity": 0.30,
					"fog_light_color": Color("3a3057"), "fog_density": 0.0055,
					"fog_aerial_perspective": 0.30, "fog_sky_affect": 0.20,
					"fog_height": -6.0, "fog_height_density": 0.12,
					"volumetric_fog_density": 0.0095, "volumetric_fog_albedo": Color("998ac4"),
					"volumetric_fog_emission": Color("201738"), "volumetric_fog_emission_energy": 0.14,
					"volumetric_fog_anisotropy": 0.65,
				},
				"sun_rot": Vector3(-34.0, 28.0, 0.0), "sun_color": Color("d8d0ff"), "sun_energy": 0.85,
			}
		"wrath":
			return {
				"wall": {
					"stone_albedo": Color("a8938a"), "dark_albedo": Color("1c1210"),
					"inlay_metal": Color("c47d4b"), "crystal_glint_color": Color("ffbe85"),
					"sun_direction": Vector3(-0.46, 0.42, -0.78), "crack_density": 0.30,
				},
				"floor": {
					"stone_albedo": Color("8a766e"), "dark_albedo": Color("180f0e"),
					"inlay_metal": Color("cc7c47"), "crystal_glint_color": Color("ffb87a"),
					"sun_direction": Vector3(-0.46, 0.42, -0.78), "crack_density": 0.48,
					"court_inlay_enabled": true,
				},
				"trim_color": Color("997052"),
				"obsidian_color": Color("221816"),
				"env": {
					"zenith_color": Color("3a2429"), "horizon_color": Color("b57a62"),
					"ground_color": Color("4a2d25"), "sun_color": Color("ffc48c"),
					"sun_dir": Vector3(-0.46, 0.42, -0.78), "sky_energy": 1.08,
					"sun_halo_strength": 0.52, "sun_disk_strength": 2.8,
					"ambient_light_energy": 1.05, "tonemap_exposure": 1.02, "glow_intensity": 0.28,
					"fog_light_color": Color("8a5c4f"), "fog_density": 0.0048,
					"fog_aerial_perspective": 0.44, "fog_sky_affect": 0.24,
					"volumetric_fog_density": 0.0078, "volumetric_fog_albedo": Color("cf987e"),
					"volumetric_fog_emission": Color("381c14"), "volumetric_fog_emission_energy": 0.14,
					"volumetric_fog_anisotropy": 0.68,
				},
				"sun_rot": Vector3(-42.0, -32.0, 0.0), "sun_color": Color("ffd5ab"), "sun_energy": 1.65,
			}
		"sorrow":
			return {
				"wall": {
					"stone_albedo": Color("8c9ba6"), "dark_albedo": Color("131b24"),
					"inlay_metal": Color("7ea0b3"), "crystal_glint_color": Color("c9ecff"),
					"sun_direction": Vector3(-0.48, 0.44, -0.76), "crack_density": 0.28,
				},
				"floor": {
					"stone_albedo": Color("6b7c87"), "dark_albedo": Color("101821"),
					"inlay_metal": Color("789aad"), "crystal_glint_color": Color("bde4fa"),
					"sun_direction": Vector3(-0.48, 0.44, -0.76), "crack_density": 0.42,
					"court_inlay_enabled": false,
				},
				"trim_color": Color("738d9c"),
				"obsidian_color": Color("16202b"),
				"env": {
					"zenith_color": Color("1b3242"), "horizon_color": Color("7c95a3"),
					"ground_color": Color("2b3e4a"), "sun_color": Color("d4eef7"),
					"sun_dir": Vector3(-0.48, 0.44, -0.76), "sky_energy": 1.05,
					"sun_halo_strength": 0.36, "sun_disk_strength": 2.0,
					"ambient_light_energy": 0.88, "tonemap_exposure": 0.98, "glow_intensity": 0.24,
					"ssr_enabled": true, "ssr_max_steps": 128, "ssr_fade_in": 0.1, "ssr_fade_out": 4.0,
					"fog_light_color": Color("6b8391"), "fog_density": 0.0060,
					"fog_aerial_perspective": 0.52, "fog_sky_affect": 0.26,
					"volumetric_fog_density": 0.0072, "volumetric_fog_albedo": Color("9bb6c4"),
					"volumetric_fog_anisotropy": 0.62,
				},
				"sun_rot": Vector3(-34.0, -34.0, 0.0), "sun_color": Color("d8eef7"), "sun_energy": 1.45,
			}
		_:
			# StasisHub / serene sanctuary
			return {
				"wall": {
					"stone_albedo": Color("cfc9be"), "dark_albedo": Color("171c26"),
					"inlay_metal": Color("c29c57"), "crystal_glint_color": Color("ffebd0"),
					"sun_direction": Vector3(-0.56, 0.34, -0.75), "crack_density": 0.14,
				},
				"floor": {
					"stone_albedo": Color("a4adb6"), "dark_albedo": Color("141922"),
					"inlay_metal": Color("c49d58"), "crystal_glint_color": Color("ffe7c4"),
					"sun_direction": Vector3(-0.56, 0.34, -0.75), "crack_density": 0.20,
					"court_inlay_enabled": true,
				},
				"trim_color": Color("b38e52"),
				"obsidian_color": Color("161b24"),
				"env": {
					"zenith_color": Color("162b42"), "horizon_color": Color("b0bcc7"),
					"ground_color": Color("364250"), "sun_color": Color("ffdba6"),
					"sun_dir": Vector3(-0.56, 0.34, -0.75), "sky_energy": 0.98,
					"sun_halo_strength": 0.44, "sun_disk_strength": 2.4,
					"ambient_light_energy": 0.76, "tonemap_exposure": 0.96, "glow_intensity": 0.22,
					"fog_light_color": Color("a9b7c4"), "fog_density": 0.0038,
					"fog_aerial_perspective": 0.46, "fog_sky_affect": 0.20,
					"volumetric_fog_density": 0.0052, "volumetric_fog_albedo": Color("d8d3c9"),
					"volumetric_fog_anisotropy": 0.65,
				},
				"sun_rot": Vector3(-24.0, -36.0, 0.0), "sun_color": Color("ffe0b5"), "sun_energy": 1.72,
			}
