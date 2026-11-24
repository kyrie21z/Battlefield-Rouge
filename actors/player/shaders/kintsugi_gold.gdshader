shader_type spatial;
render_mode depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

#include "res://assets/materials/crystal_optics.gdshaderinc"

uniform vec4 accent : source_color = vec4(1.0, 0.62, 0.12, 1.0);
uniform float seam_width = 0.0016;
uniform float restored : hint_range(0.0, 1.0) = 1.0;
uniform float visual_time = 0.0;
uniform bool reduced_motion = false;
varying vec3 distances;
varying flat int edges;
varying vec3 rest_position;
void vertex() {
	distances = CUSTOM0.xyz;
	edges = int(CUSTOM0.w + 0.5);
	rest_position = VERTEX;
}
void fragment() {
	// Match the protagonist material's source colors in linear space.
	CrystalSurface crystal = evaluate_crystal(
		VERTEX, NORMAL, VIEW, INV_VIEW_MATRIX, rest_position,
		vec3(0.603827, 0.620916, 0.655931), vec3(0.073239, 0.078288, 0.088982), 0.16,
		vec3(0.827571, 0.890005, 1.000000), 0.45, 2.6, vec3(1.0), 0.95, 0.06, 0.12, 1.0
	);
	float d = 100.0;
	if ((edges & 1) != 0) { d = min(d, distances.x); }
	if ((edges & 2) != 0) { d = min(d, distances.y); }
	if ((edges & 4) != 0) { d = min(d, distances.z); }
	float seam = (1.0 - smoothstep(seam_width, seam_width + max(fwidth(d), 0.00006), d)) * restored;
	float clock = reduced_motion ? 0.0 : visual_time;
	float flow = 0.5 + 0.5 * sin(dot(rest_position, vec3(9.0, 14.0, 7.0)) - clock * 0.65);
	float breath = 0.96 + 0.04 * sin(clock * 0.55);
	float node = pow(max(sin(dot(rest_position, vec3(37.0, 51.0, 29.0))), 0.0), 24.0);
	vec3 gold = mix(vec3(0.18, 0.095, 0.024), vec3(0.42, 0.25, 0.067), flow * 0.55);
	vec3 gold_emission = vec3(0.018)
		+ vec3(0.25, 0.13, 0.025) * (0.65 + flow * 0.35) * breath
		+ accent.rgb * node * 0.42;
	NORMAL = crystal.normal;
	ALBEDO = mix(crystal.albedo, gold, seam);
	METALLIC = mix(crystal.metallic, 0.92, seam);
	ROUGHNESS = mix(crystal.roughness, 0.15, seam);
	SPECULAR = mix(crystal.specular, 0.65, seam);
	CLEARCOAT = mix(crystal.clearcoat, 0.2, seam);
	CLEARCOAT_ROUGHNESS = crystal.clearcoat_roughness;
	EMISSION = mix(crystal.emission, gold_emission, seam);
}
