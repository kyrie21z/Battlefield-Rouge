shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform float visual_time = 0.0;
uniform bool reduced_motion = false;
void fragment() {
	float rim = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 2.0);
	float stripes = reduced_motion ? 0.0 : pow(max(sin(UV.x * 100.53 + visual_time * 0.4), 0.0), 16.0);
	float fade = sin(UV.y * 3.14159);
	ALBEDO = vec3(0.38, 0.72, 1.0);
	ALPHA = (0.018 + rim * 0.12 + stripes * 0.035) * fade;
}
