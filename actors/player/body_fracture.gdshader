shader_type spatial;
render_mode world_vertex_coords, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

#include "res://assets/materials/crystal_optics.gdshaderinc"

uniform vec4 base_color : source_color = vec4(0.8, 0.81, 0.83, 1.0);
uniform vec4 emission_color : source_color = vec4(0.3, 0.31, 0.33, 1.0);
uniform float emission_strength = 0.16;
uniform vec4 rim_color : source_color = vec4(0.92, 0.95, 1.0, 1.0);
uniform float rim_strength = 0.45;
uniform float rim_power = 2.6;
uniform vec4 spec_color : source_color = vec4(1.0);
uniform float specular_amount = 0.95;
uniform float roughness_value = 0.06;
uniform float inner_glow = 0.12;
uniform int fracture_level : hint_range(0, 4) = 0;
uniform int body_part = 0; // 1 left forearm, 2 torso, 3 other arm, 0 remaining body.
uniform mat4 rest_from_world;
uniform vec3 wrist_position = vec3(-0.680741, 1.5629, 0.051034);
varying vec3 rest_position;

vec3 hash33(vec3 p) {
	p = fract(p * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yxz + 33.33);
	return fract((p.xxy + p.yxx) * p.zyx);
}

vec2 voronoi_plane_crack(vec3 p) {
	vec3 ip = floor(p);
	vec3 fp = fract(p);
	vec3 mr = vec3(0.0);
	vec3 mg = vec3(0.0);
	float md = 8.0;
	vec3 best_h = vec3(0.0);
	for (int z = -1; z <= 1; z++) {
		for (int y = -1; y <= 1; y++) {
			for (int x = -1; x <= 1; x++) {
				vec3 g = vec3(float(x), float(y), float(z));
				vec3 h = hash33(ip + g);
				vec3 r = g + (0.14 + 0.72 * h) - fp;
				float d = dot(r, r);
				if (d < md) {
					md = d;
					mr = r;
					mg = g;
					best_h = h;
				}
			}
		}
	}
	float edge_d = 8.0;
	for (int z = -1; z <= 1; z++) {
		for (int y = -1; y <= 1; y++) {
			for (int x = -1; x <= 1; x++) {
				vec3 g = mg + vec3(float(x), float(y), float(z));
				vec3 h = hash33(ip + g);
				vec3 r = g + (0.14 + 0.72 * h) - fp;
				vec3 diff = r - mr;
				if (dot(diff, diff) > 0.0001) {
					edge_d = min(edge_d, dot(0.5 * (mr + r), normalize(diff)));
				}
			}
		}
	}
	return vec2(edge_d, fract(best_h.x * 17.3 + best_h.y * 31.7 + best_h.z * 11.1));
}

vec2 eval_crystal_fissure(vec3 rp, float level_f, float region) {
	if (level_f < 0.5 || region <= 0.001) {
		return vec2(0.0);
	}
	float t = clamp((level_f - 1.0) / 3.0, 0.0, 1.0);

	vec3 p_macro = rp * vec3(10.5, 8.0, 10.5);
	vec3 p_micro = rp * vec3(24.0, 19.0, 24.0) + vec3(4.2, -2.7, 1.9);

	vec2 v1 = voronoi_plane_crack(p_macro);
	vec2 v2 = voronoi_plane_crack(p_micro);

	float macro_gate = smoothstep(mix(0.62, 0.25, t), mix(0.85, 0.55, t), v1.y);
	float near_macro = 1.0 - smoothstep(0.02, mix(0.12, 0.28, t), v1.x);
	float micro_gate = near_macro * smoothstep(mix(0.55, 0.18, t), 0.78, v2.y);

	float w1 = mix(0.006, 0.015, t) * (0.35 + 0.65 * macro_gate);
	float w2 = mix(0.004, 0.010, t) * micro_gate;
	float aa1 = max(fwidth(v1.x) * 0.75, 0.0015);
	float aa2 = max(fwidth(v2.x) * 0.75, 0.0015);

	float c1 = (1.0 - smoothstep(w1 * 0.35, w1 + aa1, v1.x)) * step(0.05, macro_gate);
	float c2 = (1.0 - smoothstep(w2 * 0.35, w2 + aa2, v2.x)) * step(0.05, micro_gate) * 0.78;
	float crack = clamp(max(c1, c2), 0.0, 1.0) * region;

	float g1 = smoothstep(w1 * 0.5, w1 + aa1 * 1.2, v1.x)
		* (1.0 - smoothstep(w1 + aa1 * 1.2, w1 * 3.8 + aa1 * 2.5, v1.x)) * macro_gate;
	float g2 = smoothstep(w2 * 0.5, w2 + aa2 * 1.2, v2.x)
		* (1.0 - smoothstep(w2 + aa2 * 1.2, w2 * 3.5 + aa2 * 2.0, v2.x)) * micro_gate * 0.65;
	float glint = clamp(g1 + g2, 0.0, 1.0) * region;

	return vec2(crack, glint);
}

void vertex() {
	// Forward+ skins before vertex(). Pose inverse maps world coordinates back to anatomy.
	rest_position = (rest_from_world * vec4(VERTEX, 1.0)).xyz;
	if (fracture_level >= 3 && body_part == 2) {
		// The asset has ONE torso shard. Offset selected original flat facets,
		// without fabricating chest pieces or changing the source triangulation.
		vec3 n = normalize(mat3(rest_from_world) * NORMAL);
		float chosen = step(0.48, n.x);
		VERTEX += NORMAL * chosen * (fracture_level == 3 ? 0.0017 : 0.0030);
	}
}

void fragment() {
	CrystalSurface crystal = evaluate_crystal(
		VERTEX, NORMAL, VIEW, INV_VIEW_MATRIX, rest_position, base_color.rgb,
		emission_color.rgb, emission_strength, rim_color.rgb, rim_strength,
		rim_power, spec_color.rgb, specular_amount, roughness_value, inner_glow, 1.0
	);
	float region = 0.0;
	if (fracture_level == 1 && body_part == 1) {
		region = 1.0 - smoothstep(0.065, 0.095, distance(rest_position, wrist_position));
	}
	if (fracture_level == 2) {
		if (body_part == 1) {
			region = 1.0 - smoothstep(wrist_position.x + 0.05, wrist_position.x + 0.13, rest_position.x);
		}
		if (body_part == 2) { region = smoothstep(1.32, 1.43, rest_position.y); }
	}
	if (fracture_level == 3 && body_part > 0) { region = 1.0; }
	if (fracture_level >= 4) { region = 1.0; }

	float level_f = float(fracture_level);
	vec3 r_in_rest = normalize(mat3(rest_from_world) * crystal.refract_world);
	vec2 f0 = eval_crystal_fissure(rest_position, level_f, region);
	vec2 f1 = eval_crystal_fissure(rest_position + r_in_rest * 0.0028, level_f, region);
	vec2 f2 = eval_crystal_fissure(rest_position + r_in_rest * 0.0062, level_f, region);

	float surface_cut = f0.x;
	float internal_sheet = clamp(f1.x * 0.62 + f2.x * 0.34, 0.0, 1.0) * (1.0 - surface_cut);
	float internal_tir = clamp(f0.y * 0.80 + f1.y * 0.70 + f2.y * 0.45, 0.0, 1.0) * (1.0 - surface_cut);

	vec3 sheet_shadow = mix(crystal.emission, crystal.emission * vec3(0.22, 0.28, 0.38), internal_sheet * 0.85);
	vec3 cracked_emission = sheet_shadow
		+ vec3(0.92, 0.97, 1.0) * internal_tir * (0.38 + 0.90 * crystal.surf_spec + 0.45 * crystal.fresnel);

	NORMAL = crystal.normal;
	ALBEDO = mix(crystal.albedo, vec3(0.004, 0.006, 0.010), surface_cut);
	ROUGHNESS = mix(crystal.roughness, 0.72, surface_cut);
	SPECULAR = mix(crystal.specular, 0.12, surface_cut);
	METALLIC = mix(crystal.metallic, 0.0, surface_cut);
	CLEARCOAT = mix(crystal.clearcoat, 0.0, surface_cut);
	CLEARCOAT_ROUGHNESS = mix(crystal.clearcoat_roughness, 0.80, surface_cut);
	EMISSION = cracked_emission * (1.0 - surface_cut * 0.94);
}
