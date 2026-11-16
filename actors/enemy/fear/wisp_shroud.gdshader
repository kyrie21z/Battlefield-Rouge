shader_type spatial;
render_mode cull_disabled;
uniform float visual_time = 0.0;
uniform float threat = 0.0;
void vertex() {
	float hem = clamp(-VERTEX.y + 0.1, 0.0, 0.7);
	VERTEX.x *= 1.0 + threat * 0.16;
	VERTEX.y *= 1.0 + threat * 0.30;
	VERTEX.z += sin(visual_time * 4.0 + VERTEX.x * 8.0) * hem * 0.065;
}
void fragment() {
	ALBEDO = vec3(0.57, 0.34, 0.86);
	ROUGHNESS = 0.65;
	EMISSION = vec3(0.14, 0.025, 0.30) * (0.18 + threat * 0.18);
}
