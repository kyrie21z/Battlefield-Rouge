shader_type spatial;
render_mode depth_prepass_alpha, cull_back;
uniform float print_progress : hint_range(0.0, 1.0) = 0.0;
uniform float origin_y = 0.0;
uniform float visual_time = 0.0;
uniform bool reduced_motion = false;
varying vec3 world_position;
void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	float cutoff = origin_y + mix(2.5, -0.2, print_progress);
	float printed = step(cutoff, world_position.y);
	float band = 1.0 - smoothstep(0.012, 0.045, abs(world_position.y - cutoff));
	vec3 cell = abs(fract(world_position * 16.0 - 0.5) - 0.5);
	vec3 aa = max(fwidth(world_position * 16.0), vec3(0.008));
	vec3 grid = 1.0 - smoothstep(vec3(0.015), vec3(0.015) + aa, cell);
	float wire = max(grid.y, max(grid.x, grid.z));
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	float pulse = reduced_motion ? 1.0 : 0.94 + 0.06 * sin(visual_time * 5.0);
	ALBEDO = mix(vec3(0.12, 0.4, 0.58), vec3(0.94, 0.96, 0.99), printed);
	METALLIC = mix(0.15, 0.74, printed);
	ROUGHNESS = mix(0.55, 0.055, printed);
	SPECULAR = 0.85;
	EMISSION = mix(vec3(0.1, 0.6, 1.0) * (wire * 0.9 + fresnel * 0.4) * pulse,
		vec3(0.1), printed) + band * vec3(3.5, 5.5, 7.0);
	ALPHA = mix(0.045 + wire * 0.36 + fresnel * 0.12, 1.0, printed);
	ALPHA = max(ALPHA, band);
}
