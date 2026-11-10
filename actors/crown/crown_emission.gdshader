shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform vec4 ivory_gold : source_color = vec4(0.90, 0.72, 0.34, 1.0);
uniform float emission_strength : hint_range(0.0, 32.0) = 0.5;
void fragment() {
	ALBEDO = ivory_gold.rgb;
	METALLIC = 0.65;
	ROUGHNESS = 0.23;
	float rim = pow(1.0 - clamp(dot(normalize(NORMAL), VIEW), 0.0, 1.0), 2.5);
	EMISSION = vec3(1.0, 0.88, 0.58) * emission_strength * (0.45 + 0.55 * rim);
}
