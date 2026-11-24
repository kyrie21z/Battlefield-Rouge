shader_type spatial;
render_mode depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

#include "res://assets/materials/crystal_optics.gdshaderinc"

uniform vec4 base_color : source_color = vec4(0.720588, 0.0, 0.0, 1.0);
uniform vec4 emission_color : source_color = vec4(0.522059, 0.0, 0.0, 1.0);
uniform float emission_strength : hint_range(0.0, 8.0) = 0.35;

uniform vec4 rim_color : source_color = vec4(1.0, 0.145, 0.0, 1.0);
uniform float rim_strength : hint_range(0.0, 4.0) = 0.55;
uniform float rim_power : hint_range(0.5, 12.0) = 2.6;

uniform vec4 spec_color : source_color = vec4(1.0, 0.186, 0.0, 1.0);
uniform float specular_amount : hint_range(0.0, 2.0) = 0.5;
uniform float roughness_value : hint_range(0.0, 1.0) = 0.18;

uniform float inner_glow : hint_range(0.0, 4.0) = 0.15;
// Kept for material compatibility. Writing ALPHA would select the transparent pass.
uniform float alpha : hint_range(0.0, 1.0) = 1.0;

varying vec3 local_pos;

void vertex() {
	local_pos = VERTEX;
}

void fragment() {
	CrystalSurface crystal = evaluate_crystal(
		VERTEX, NORMAL, VIEW, INV_VIEW_MATRIX, local_pos, base_color.rgb,
		emission_color.rgb, emission_strength, rim_color.rgb, rim_strength,
		rim_power, spec_color.rgb, specular_amount, roughness_value, inner_glow, 1.0
	);
	NORMAL = crystal.normal;
	ALBEDO = crystal.albedo;
	ROUGHNESS = crystal.roughness;
	METALLIC = crystal.metallic;
	SPECULAR = crystal.specular;
	CLEARCOAT = crystal.clearcoat;
	CLEARCOAT_ROUGHNESS = crystal.clearcoat_roughness;
	EMISSION = crystal.emission;
}
