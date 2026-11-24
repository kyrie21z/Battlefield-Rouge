shader_type spatial;
render_mode depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

#include "res://assets/materials/crystal_optics.gdshaderinc"

uniform vec4 obsidian_tint : source_color = vec4(0.007, 0.009, 0.014, 1.0);
uniform vec4 glint_color : source_color = vec4(0.84, 0.92, 1.0, 1.0);
uniform vec4 ember_tint : source_color = vec4(1.0, 0.64, 0.20, 1.0);

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

	ALBEDO = obsidian_tint.rgb;
	METALLIC = 0.34;
	ROUGHNESS = 0.028;
	SPECULAR = 1.0;
	CLEARCOAT = 1.0;
	CLEARCOAT_ROUGHNESS = 0.012;

	vec3 inner_depth = vec3(0.014, 0.024, 0.044) * (0.20 + inner_spec * 1.45);
	vec3 glass_flash = glint_color.rgb * surf_spec * (0.09 + fresnel * 1.15);
	vec3 edge_sheen = mix(glint_color.rgb, ember_tint.rgb, 0.16) * pow(1.0 - ndv, 4.5) * 0.38;

	EMISSION = inner_depth + glass_flash + edge_sheen;
}
