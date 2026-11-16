shader_type spatial;
render_mode cull_disabled;
uniform float visual_time = 0.0;
void vertex() {
	VERTEX.x += sin(visual_time * 6.0 - VERTEX.z * 3.0) * clamp(-VERTEX.z, 0.0, 1.4) * 0.025;
}
void fragment() {
	ALBEDO = vec3(0.48, 0.16, 0.72);
	ROUGHNESS = 0.55;
}
