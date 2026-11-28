shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;

uniform float age = 0.0;
uniform float heat : hint_range(0.0, 1.0) = 0.0;
uniform float curl : hint_range(0.0, 1.0) = 0.0;

void vertex() {
	float height = UV.y;
	float pulse = 0.86 + 0.14 * sin(age * 21.0 + height * 9.0 + MODEL_MATRIX[3].x * 5.0);
	VERTEX.y *= pulse * mix(0.74, 1.42, heat);
	VERTEX.x += height * height * (0.11 * sin(age * 14.0 + height * 4.0) + 0.58 * curl);
}

void fragment() {
	vec3 amber = mix(vec3(1.0, 0.28, 0.028), vec3(0.82, 0.056, 0.005), smoothstep(0.0, 0.90, UV.y));
	float center = (1.0 - smoothstep(0.06, 0.20, abs(UV.x - 0.48))) * (1.0 - UV.y);
	ALBEDO = amber + vec3(0.42, 0.21, 0.04) * center;
	EMISSION = amber * mix(0.22, 0.78, heat);
}
