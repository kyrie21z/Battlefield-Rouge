struct CrystalSurface {
	vec3 normal;
	vec3 albedo;
	float roughness;
	float metallic;
	float specular;
	float clearcoat;
	float clearcoat_roughness;
	vec3 emission;
	vec3 refract_world;
	float surf_spec;
	float fresnel;
};

vec3 flat_facet_normal(vec3 frag_vertex, vec3 frag_normal) {
	vec3 dpdx = dFdx(frag_vertex);
	vec3 dpdy = dFdy(frag_vertex);
	vec3 geo_cross = cross(dpdy, dpdx);
	float area = length(geo_cross);
	vec3 n = area > length(dpdx) * length(dpdy) * 0.00001
		? geo_cross / area : normalize(frag_normal);
	if (dot(n, frag_normal) < 0.0) {
		n = -n;
	}
	return n;
}

vec3 quantize_crystal_plane(vec3 d) {
	vec3 a = abs(d);
	vec3 oct = sign(d) * normalize(pow(a + vec3(0.001), vec3(2.4)));
	return normalize(mix(d, oct, 0.65));
}

float studio_env(vec3 d) {
	float top_panel = smoothstep(0.62, 0.72, d.y) * 1.15;
	float key_panel = pow(max(dot(d, normalize(vec3(0.52, 0.66, 0.54))), 0.0), 34.0) * 2.5;
	float side_strip = pow(max(dot(d, normalize(vec3(-0.76, 0.30, -0.58))), 0.0), 22.0) * 1.30;
	float horizon = smoothstep(0.04, 0.09, d.y) * (1.0 - smoothstep(0.12, 0.19, d.y)) * 0.80;
	float floor_dark = smoothstep(-0.22, 0.04, d.y);
	return (top_panel + key_panel + side_strip + horizon) * (0.14 + 0.86 * floor_dark);
}

vec2 internal_refraction(vec3 pos, vec3 r_in, vec3 n_world) {
	vec3 p = pos * 2.1 + r_in * 0.65;
	float w1 = sin(dot(p, vec3(1.73, 2.41, -1.97)));
	float w2 = cos(dot(p, vec3(-2.63, 1.37, 2.19)) + w1 * 0.55);
	float depth_band = 0.5 + 0.5 * sin((w1 + w2) * 1.15);
	float caustic = pow(max(0.0, 0.5 + 0.5 * (w1 * w2)), 6.0);
	float angle_mod = 0.60 + 0.40 * abs(dot(n_world, vec3(0.42, 0.81, -0.40)));
	return vec2(depth_band * angle_mod, caustic);
}

CrystalSurface evaluate_crystal(
	vec3 frag_vertex, vec3 frag_normal, vec3 frag_view, mat4 inv_view_matrix,
	vec3 crystal_pos, vec3 base_color, vec3 emission_color, float emission_strength,
	vec3 rim_color, float rim_strength, float rim_power, vec3 spec_color,
	float specular_amount, float roughness_value, float inner_glow, float shard_damp
) {
	vec3 n = flat_facet_normal(frag_vertex, frag_normal);

	float ndv = clamp(dot(n, frag_view), 0.0, 1.0);
	vec3 n_world = normalize((inv_view_matrix * vec4(n, 0.0)).xyz);
	vec3 v_world = normalize((inv_view_matrix * vec4(frag_view, 0.0)).xyz);

	float cmax = max(base_color.r, max(base_color.g, base_color.b));
	float cmin = min(base_color.r, min(base_color.g, base_color.b));
	float sat = (cmax - cmin) / max(cmax, 0.001);
	float is_quartz = (1.0 - smoothstep(0.08, 0.26, sat)) * smoothstep(0.45, 0.72, cmax);

	float f0 = mix(0.11, 0.08, is_quartz);
	float fresnel = f0 + (1.0 - f0) * pow(1.0 - ndv, 4.2);

	float ior = mix(1.77, 1.55, is_quartz);
	vec3 r_out = reflect(-v_world, n_world);
	vec3 r_in = refract(-v_world, n_world, 1.0 / ior);
	vec3 back_n = quantize_crystal_plane(-r_in - n_world * 0.35);
	vec3 r_tir = reflect(r_in, back_n);

	float surf_spec = studio_env(r_out);
	float inner_spec = studio_env(r_tir);
	vec2 inner = internal_refraction(crystal_pos, r_in, n_world);

	vec3 gem_hue = base_color / max(cmax, 0.001);
	vec3 deep_core = mix(
		base_color * 0.24 + gem_hue * 0.035,
		vec3(0.08, 0.13, 0.21),
		is_quartz
	);
	vec3 mid_crystal = mix(
		mix(base_color * 1.15, gem_hue * 0.58, 0.48),
		vec3(0.36, 0.44, 0.55),
		is_quartz
	);
	vec3 bright_refract = mix(
		mix(gem_hue * 1.08, rim_color, 0.48),
		vec3(0.92, 0.97, 1.0),
		is_quartz
	);

	float inner_light = clamp(
		inner_spec * mix(0.66, 0.72, is_quartz)
		+ inner.x * mix(0.22, 0.16, is_quartz)
		+ pow(1.0 - ndv, mix(1.9, 2.2, is_quartz)) * mix(0.36, 0.26, is_quartz),
		0.0, 1.0
	);
	vec3 crystal_body = mix(
		deep_core, mid_crystal,
		smoothstep(mix(0.08, 0.06, is_quartz), mix(0.50, 0.48, is_quartz), inner_light)
	);
	crystal_body = mix(
		crystal_body, bright_refract,
		smoothstep(mix(0.54, 0.52, is_quartz), mix(0.94, 0.90, is_quartz), inner_light)
	);
	crystal_body += bright_refract * inner.y * (0.14 + 0.30 * inner_spec) * mix(0.85, 0.45, is_quartz);

	vec3 dispersion = vec3(
		pow(1.0 - ndv, 3.0) * 0.95,
		pow(1.0 - ndv, 3.8) * 0.85,
		pow(1.0 - ndv, 2.2) * 1.15
	) * mix(0.06, 0.20, is_quartz);

	CrystalSurface surface;
	surface.normal = n;
	surface.albedo = mix(deep_core * 0.82, vec3(0.06, 0.08, 0.11), is_quartz);
	surface.roughness = clamp(roughness_value * 0.25, 0.025, 0.085);
	surface.metallic = mix(0.12, 0.08, is_quartz);
	surface.specular = clamp(specular_amount, 0.0, 1.0);
	surface.clearcoat = 1.0;
	surface.clearcoat_roughness = 0.02;
	surface.refract_world = r_in;
	surface.surf_spec = surf_spec;
	surface.fresnel = fresnel;

	vec3 mirror_glint = mix(spec_color, vec3(0.97, 0.99, 1.0), 0.72)
		* surf_spec * (0.15 + fresnel * mix(0.95, 1.10, is_quartz) * shard_damp);
	float rim = f0 + (1.0 - f0) * pow(1.0 - ndv, rim_power);
	vec3 rim_accent = rim_color * rim * rim_strength * mix(0.45, 0.22, is_quartz) * shard_damp;
	vec3 cast_glow = emission_color * emission_strength * mix(0.32, 0.10, is_quartz);

	surface.emission = crystal_body * (mix(0.44, 0.56, is_quartz) + inner_glow * 0.32)
		+ mirror_glint
		+ rim_accent
		+ dispersion * mix(0.30, 0.85, is_quartz)
		+ cast_glow;
	return surface;
}
