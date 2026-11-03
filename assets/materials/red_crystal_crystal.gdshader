// SUPERHOT red crystal enemy - Godot 4 crystal shader
// Reverse engineered from Unity material "MAIN RedCrystalNuEnemyMaterial":
//   _Color         = (0.7206, 0, 0)      -> base_color
//   _EmissionColor = (0.5221, 0, 0)      -> emission_color
//   _SpecColor     = (1.0, 0.186, 0)     -> spec_color
//   _RampColor     = (1.0, 0.145, 0)     -> rim_color
// The original is a custom "MAIN" forward shader (translucent crystal + fresnel
// rim + phase flicker). This reproduces the look with a Godot spatial shader:
// solid red body + fresnel rim light + slight emission.
// Mesh normals are flat (as authored in Unity), so the low-poly facets survive.

shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

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
		+ spec_color.rgb * fresnel * 0.2;
}
