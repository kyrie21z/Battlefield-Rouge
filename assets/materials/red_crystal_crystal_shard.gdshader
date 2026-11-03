// Red crystal enemy - shard variant of red_crystal_crystal.gdshader
// Same look as the body shader, but the fresnel rim and the specular rim are
// pulled down (rim_strength 0.55 -> 0.16, rim_power 2.6 -> 3.2, spec_rim 0.06).
// Shards are small and mostly seen at grazing angles, so the body settings blow
// the highlights out and a shatter reads as a colour pop instead of the same
// crystal. Only shards use this file; the body keeps the original shader.

shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 base_color : source_color = vec4(0.720588, 0.0, 0.0, 1.0);
uniform vec4 emission_color : source_color = vec4(0.522059, 0.0, 0.0, 1.0);
uniform float emission_strength : hint_range(0.0, 8.0) = 0.35;

uniform vec4 rim_color : source_color = vec4(1.0, 0.145, 0.0, 1.0);
uniform float rim_strength : hint_range(0.0, 4.0) = 0.16;
uniform float rim_power : hint_range(0.5, 12.0) = 3.2;

uniform vec4 spec_color : source_color = vec4(1.0, 0.186, 0.0, 1.0);
uniform float specular_amount : hint_range(0.0, 2.0) = 0.5;
uniform float roughness_value : hint_range(0.0, 1.0) = 0.22;

uniform float inner_glow : hint_range(0.0, 4.0) = 0.15;
uniform float spec_rim : hint_range(0.0, 1.0) = 0.06;
uniform float alpha : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec3 n = normalize(NORMAL);
	float ndv = clamp(dot(n, VIEW), 0.0, 1.0);
	float fresnel = pow(1.0 - ndv, rim_power);
	float inner = pow(ndv, 1.5);

	ALBEDO = base_color.rgb;
	ROUGHNESS = roughness_value;
	SPECULAR = specular_amount;
	METALLIC = 0.0;
	ALPHA = alpha;

	EMISSION = emission_color.rgb * emission_strength
		+ rim_color.rgb * fresnel * rim_strength
		+ base_color.rgb * inner * inner_glow
		+ spec_color.rgb * fresnel * spec_rim;
}
