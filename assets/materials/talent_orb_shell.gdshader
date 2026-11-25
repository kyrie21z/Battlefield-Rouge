shader_type spatial;
render_mode depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

#include "res://assets/materials/crystal_optics.gdshaderinc"

// Faceted obsidian geode armour for the talent orb. Same studio-reflection
// model as obsidian_crystal.gdshader, plus a realm-tinted rim, seam inlays and
// a scatter heat that cools to zero while the shell flies back together.
// pulse_time comes from SimClock, never wall-clock TIME, so a replay matches.
uniform vec4 obsidian_tint : source_color = vec4(0.008, 0.010, 0.016, 1.0);
uniform vec4 glint_color : source_color = vec4(0.84, 0.92, 1.0, 1.0);
uniform vec4 accent_color : source_color = vec4(1.0, 0.62, 0.18, 1.0);
uniform float accent_rim : hint_range(0.0, 2.0) = 0.28;
uniform float seam_glow : hint_range(0.0, 4.0) = 0.0;
uniform float scatter_glow : hint_range(0.0, 4.0) = 0.0;
uniform float energy_scale : hint_range(0.0, 2.0) = 1.0;
uniform float pulse_time = 0.0;
// 1.0 on the interior bowl steps: they must stay a pitch-black void behind the
// core instead of mirroring the studio panels the way the outer plates do.
uniform float cavity : hint_range(0.0, 1.0) = 0.0;

float obsidian_studio(vec3 d) {
	float top = smoothstep(0.64, 0.72, d.y) * 1.25;
	float key = pow(max(dot(d, normalize(vec3(0.50, 0.64, 0.58))), 0.0), 36.0) * 3.0;
	float side_l = pow(max(dot(d, normalize(vec3(-0.82, 0.16, 0.54))), 0.0), 26.0) * 1.85;
	float side_r = pow(max(dot(d, normalize(vec3(0.78, -0.18, -0.59))), 0.0), 24.0) * 1.45;
	float horizon_blade = smoothstep(0.02, 0.06, d.y) * (1.0 - smoothstep(0.08, 0.14, d.y)) * 1.10;
	float low_blade = smoothstep(-0.34, -0.28, d.y) * (1.0 - smoothstep(-0.24, -0.18, d.y)) * 0.72;
	return top + key + side_l + side_r + horizon_blade + low_blade;
}

void fragment() {
	vec3 n = flat_facet_normal(VERTEX, NORMAL);
	NORMAL = n;

	float ndv = clamp(dot(n, VIEW), 0.0, 1.0);
	vec3 n_world = normalize((INV_VIEW_MATRIX * vec4(n, 0.0)).xyz);
	vec3 v_world = normalize((INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz);
	vec3 r_out = reflect(-v_world, n_world);
	vec3 r_in = refract(-v_world, n_world, 1.0 / 1.54);
	vec3 back_n = quantize_crystal_plane(-r_in - n_world * 0.30);
	vec3 r_tir = reflect(r_in, back_n);

	float fresnel = 0.06 + 0.94 * pow(1.0 - ndv, 4.2);
	float surf_spec = obsidian_studio(r_out);
	float inner_spec = obsidian_studio(r_tir);

	ALBEDO = mix(obsidian_tint.rgb, vec3(0.002, 0.003, 0.005), cavity);
	METALLIC = mix(0.34, 0.08, cavity);
	ROUGHNESS = mix(0.032, 0.10, cavity);
	SPECULAR = mix(1.0, 0.10, cavity);
	CLEARCOAT = mix(1.0, 0.12, cavity);
	CLEARCOAT_ROUGHNESS = 0.015;

	vec3 inner_depth = vec3(0.014, 0.024, 0.044) * (0.20 + inner_spec * 1.45) * (1.0 - 0.45 * cavity);
	vec3 glass_flash = glint_color.rgb * surf_spec * (0.09 + fresnel * 1.15) * (1.0 - 0.88 * cavity);
	vec3 edge_sheen = mix(glint_color.rgb, accent_color.rgb, 0.42)
		* pow(1.0 - ndv, 4.5) * accent_rim;

	// Seam inlays breathe slowly; armour plates keep seam_glow at zero.
	float breath = 0.5 + 0.5 * sin(pulse_time * 1.7);
	float seam = seam_glow * (0.62 + 0.38 * breath);
	vec3 seam_light = accent_color.rgb * seam * (0.30 + 0.70 * pow(1.0 - ndv, 1.6));

	// Scatter heat is a wide planar glow, not an edge term, so a shard reads as
	// hot glass even face-on before it cools back to obsidian.
	vec3 heat = mix(accent_color.rgb, vec3(1.0, 0.86, 0.66), 0.34) * scatter_glow;

	EMISSION = (inner_depth + glass_flash + edge_sheen + seam_light + heat) * energy_scale;
}
