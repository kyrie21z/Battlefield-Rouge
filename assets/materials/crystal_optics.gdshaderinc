struct CrystalSurface {
	vec3 normal;
	vec3 albedo;
	float roughness;
	float metallic;
	float specular;
	float clearcoat;
	float clearcoat_roughness;
	vec3 emission;
};

vec3 quantize_crystal_plane(vec3 d) {
	vec3 a = abs(d);
	vec3 oct = sign(d) * normalize(pow(a + vec3(0.001), vec3(2.4)));
	return normalize(mix(d, oct, 0.65));
}

float studio_env(vec3 d) {
	// Bright studio panels with negative fill below the horizon.
	float top_panel = smoothstep(0.58, 0.72, d.y) * 0.95;
	float key_panel = pow(max(dot(d, normalize(vec3(0.54, 0.64, 0.55))), 0.0), 30.0) * 2.0;
	float side_strip = pow(max(dot(d, normalize(vec3(-0.76, 0.28, -0.58))), 0.0), 18.0) * 1.05;
	float horizon = smoothstep(-0.02, 0.10, d.y) * (1.0 - smoothstep(0.15, 0.30, d.y)) * 0.48;
	float floor_dark = smoothstep(-0.35, -0.02, d.y);
	return (top_panel + key_panel + side_strip + horizon) * (0.22 + 0.78 * floor_dark);
}

// Planar bands and thin cleavage flashes inside the crystal.
vec2 internal_cleavage(vec3 pos, vec3 r_in, vec3 n_world) {
	vec3 p1 = pos * 5.2 + r_in * 0.38;
	vec3 p2 = pos * 8.4 + r_in * 0.72;
	float s1 = abs(fract(dot(p1, vec3(0.577, 0.577, 0.577))) - 0.5);
	float s2 = abs(fract(dot(p1, vec3(-0.707, 0.500, 0.500))) - 0.5);
	float s3 = abs(fract(dot(p2, vec3(0.354, -0.707, 0.612))) - 0.5);
	float band_a = step(0.24, s1) * 0.55 + step(0.30, s2) * 0.45;
	float gleam = (1.0 - smoothstep(0.0, 0.032, s1)) * 0.45
		+ (1.0 - smoothstep(0.0, 0.028, s2)) * 0.35
		+ (1.0 - smoothstep(0.0, 0.024, s3)) * 0.25;
	float angle_mod = 0.55 + 0.45 * abs(dot(n_world, vec3(0.42, 0.81, -0.40)));
	return vec2(band_a * angle_mod, gleam);
}

CrystalSurface evaluate_crystal(
	vec3 frag_vertex, vec3 frag_normal, vec3 frag_view, mat4 inv_view_matrix,
	vec3 crystal_pos, vec3 base_color, vec3 emission_color, float emission_strength,
	vec3 rim_color, float rim_strength, float rim_power, vec3 spec_color,
	float specular_amount, float roughness_value, float inner_glow, float shard_damp
) {
	vec3 dpdx = dFdx(frag_vertex);
	vec3 dpdy = dFdy(frag_vertex);
	vec3 geo_cross = cross(dpdy, dpdx);
	float area = length(geo_cross);
	vec3 n = area > length(dpdx) * length(dpdy) * 0.00001
		? geo_cross / area : normalize(frag_normal);
	if (dot(n, frag_normal) < 0.0) {
		n = -n;
	}

	float ndv = clamp(dot(n, frag_view), 0.0, 1.0);
	vec3 n_world = normalize((inv_view_matrix * vec4(n, 0.0)).xyz);
	vec3 v_world = normalize((inv_view_matrix * vec4(frag_view, 0.0)).xyz);

	// Quartz requires low HSV saturation and a bright base color.
	float cmax = max(base_color.r, max(base_color.g, base_color.b));
	float cmin = min(base_color.r, min(base_color.g, base_color.b));
	float sat = (cmax - cmin) / max(cmax, 0.001);
	float is_quartz = (1.0 - smoothstep(0.08, 0.26, sat)) * smoothstep(0.45, 0.72, cmax);

	// High-IOR Schlick Fresnel (quartz ~1.55, colored gem ~1.77)
	float f0 = mix(0.11, 0.08, is_quartz);
	float fresnel = f0 + (1.0 - f0) * pow(1.0 - ndv, 4.2);

	// Coplanar facets contribute no normal change.
	float edge_delta = length(dFdx(n)) + length(dFdy(n));
	float ridge = smoothstep(0.13, 0.64, edge_delta);

	// Reflect the refracted ray off a quantized back facet to approximate TIR.
	float ior = mix(1.77, 1.55, is_quartz);
	vec3 r_out = reflect(-v_world, n_world);
	vec3 r_in = refract(-v_world, n_world, 1.0 / ior);
	vec3 back_n = quantize_crystal_plane(-r_in - n_world * 0.35);
	vec3 r_tir = reflect(r_in, back_n);

	float surf_spec = studio_env(r_out);
	float inner_spec = studio_env(r_tir);
	vec2 cleavage = internal_cleavage(crystal_pos, r_in, n_world);

	// Normalize the hue so dark gems keep colored refracted highlights.
	vec3 gem_hue = base_color / max(cmax, 0.001);
	vec3 deep_core = mix(
		base_color * 0.24 + gem_hue * 0.035,
		vec3(0.15, 0.22, 0.32),
		is_quartz
	);
	vec3 mid_crystal = mix(
		mix(base_color * 1.15, gem_hue * 0.58, 0.48),
		vec3(0.46, 0.54, 0.64),
		is_quartz
	);
	vec3 bright_refract = mix(
		mix(gem_hue * 1.08, rim_color, 0.48),
		vec3(0.90, 0.96, 1.0),
		is_quartz
	);

	// Strong dark-core to bright-facet internal refraction step
	float inner_light = clamp(inner_spec * 0.62 + cleavage.x * 0.26 + pow(1.0 - ndv, 1.9) * 0.36, 0.0, 1.0);
	vec3 crystal_body = mix(deep_core, mid_crystal, smoothstep(0.08, 0.50, inner_light));
	crystal_body = mix(crystal_body, bright_refract, smoothstep(0.54, 0.94, inner_light));
	// Crisp subtle internal cleavage flash
	crystal_body += bright_refract * cleavage.y * (0.14 + 0.32 * inner_spec) * mix(0.85, 0.65, is_quartz);

	// Subtle prismatic dispersion at grazing angles & crystal ridges
	vec3 dispersion = vec3(
		pow(1.0 - ndv, 3.0) * 0.95,
		pow(1.0 - ndv, 3.8) * 0.85,
		pow(1.0 - ndv, 2.2) * 1.15
	) * mix(0.06, 0.20, is_quartz);

	CrystalSurface surface;
	surface.normal = n;
	surface.albedo = mix(deep_core * 0.82, vec3(0.24, 0.30, 0.38), is_quartz);
	surface.roughness = clamp(roughness_value * 0.5, 0.025, 0.16);
	surface.metallic = mix(0.12, 0.05, is_quartz);
	surface.specular = clamp(specular_amount, 0.0, 1.0);
	surface.clearcoat = 1.0;
	surface.clearcoat_roughness = 0.02;

	float rim_scale = clamp(rim_strength / 0.45, 0.35, 2.6);
	vec3 mirror_glint = mix(spec_color, vec3(0.97, 0.99, 1.0), 0.72)
		* surf_spec * (0.15 + fresnel * 0.95 * shard_damp);
	vec3 ridge_line = mix(rim_color, vec3(0.95, 0.99, 1.0), mix(0.42, 0.88, is_quartz))
		* ridge * (0.20 + 0.55 * fresnel + 0.28 * surf_spec) * min(rim_scale, 1.6) * shard_damp;
	float rim = f0 + (1.0 - f0) * pow(1.0 - ndv, rim_power);
	vec3 rim_accent = rim_color * rim * rim_strength * mix(0.45, 0.22, is_quartz) * shard_damp;
	vec3 cast_glow = emission_color * emission_strength * mix(0.32, 0.10, is_quartz);

	surface.emission = crystal_body * (0.44 + inner_glow * 0.32)
		+ mirror_glint
		+ ridge_line
		+ rim_accent
		+ dispersion * (0.28 + ridge * 0.75)
		+ cast_glow;
	return surface;
}
