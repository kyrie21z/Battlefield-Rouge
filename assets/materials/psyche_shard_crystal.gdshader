shader_type spatial;
render_mode depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

#include "res://assets/materials/crystal_optics.gdshaderinc"

// Cut-crystal pickup optics: the shared SUPERHOT facet model plus a slow
// resonance pulse and player-proximity lift. Only emission and rim breathe;
// the dark/bright planar contrast stays intact.
uniform vec4 base_color : source_color = vec4(0.85, 0.66, 0.30, 1.0);
uniform vec4 emission_color : source_color = vec4(0.95, 0.78, 0.45, 1.0);
uniform float emission_strength : hint_range(0.0, 8.0) = 1.05;
uniform vec4 rim_color : source_color = vec4(1.0, 0.92, 0.70, 1.0);
uniform float rim_strength : hint_range(0.0, 4.0) = 0.75;
uniform float rim_power : hint_range(0.5, 12.0) = 2.4;
uniform vec4 spec_color : source_color = vec4(1.0, 0.97, 0.90, 1.0);
uniform float specular_amount : hint_range(0.0, 2.0) = 0.9;
uniform float roughness_value : hint_range(0.0, 1.0) = 0.14;
uniform float inner_glow : hint_range(0.0, 4.0) = 0.55;
uniform float pulse_time = 0.0;
uniform float pulse_strength : hint_range(0.0, 2.0) = 0.18;
uniform float proximity_boost : hint_range(0.0, 1.0) = 0.0;
// Scales the shared mirror-glint term so large planar facets stay readable
// instead of clipping to white under bright realm lighting.
uniform float facet_glint : hint_range(0.0, 1.5) = 0.6;
// Scales the glassy clearcoat; the dark base bezel keeps only a whisper of it.
uniform float coat_strength : hint_range(0.0, 1.0) = 1.0;
// Scales the internal gem-body glow; the base bezel stays stone-dark.
uniform float body_emission : hint_range(0.0, 2.0) = 1.0;

varying vec3 local_pos;

void vertex() {
	local_pos = VERTEX;
}

void fragment() {
	float breath = 0.5 + 0.5 * sin(pulse_time * 2.1);
	float facet_beat = 0.5 + 0.5 * sin(pulse_time * 3.6 + local_pos.y * 11.0 + local_pos.x * 5.0);
	float pulse = pulse_strength * (breath * 0.7 + facet_beat * 0.3);
	float lift = 1.0 + pulse + proximity_boost * 0.55;

	CrystalSurface crystal = evaluate_crystal(
		VERTEX, NORMAL, VIEW, INV_VIEW_MATRIX, local_pos,
		base_color.rgb,
		emission_color.rgb,
		emission_strength * lift,
		rim_color.rgb,
		rim_strength * (1.0 + (pulse + proximity_boost) * 0.65),
		rim_power,
		spec_color.rgb,
		specular_amount,
		roughness_value,
		inner_glow * (1.0 + proximity_boost * 0.35),
		facet_glint
	);

	NORMAL = crystal.normal;
	ALBEDO = crystal.albedo;
	ROUGHNESS = clamp(max(crystal.roughness, roughness_value), 0.16, 0.45);
	METALLIC = crystal.metallic;
	SPECULAR = crystal.specular;
	CLEARCOAT = crystal.clearcoat * coat_strength;
	CLEARCOAT_ROUGHNESS = max(crystal.clearcoat_roughness, 0.14);
	EMISSION = crystal.emission * body_emission;
}
