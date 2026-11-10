shader_type canvas_item;
uniform float intensity : hint_range(0.0, 1.0) = 0.03;
uniform float fracture_level : hint_range(0.0, 4.0) = 0.0;
uniform float visual_time = 0.0;
uniform bool reduced_motion = false;
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float border = max(abs(p.x), abs(p.y));
	float corners = pow(abs(p.x * p.y), 2.0);
	float rays = pow(max(sin(atan(p.y, p.x) * 14.0), 0.0), 14.0) * corners;
	float pulse = reduced_motion ? 1.0 : 0.97 + sin(visual_time * 0.75) * 0.03;
	float haze = fracture_level > 3.5 ? 0.022 : 0.0;
	float alpha = clamp((pow(border, 7.0) * 0.36 + rays * 0.12) * intensity * pulse + haze, 0.0, 0.54);
	COLOR = vec4(mix(vec3(1.0, 0.84, 0.47), vec3(1.0), intensity), alpha);
}
