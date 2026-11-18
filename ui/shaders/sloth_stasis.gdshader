shader_type canvas_item;

uniform float amount = 0.0;

void fragment() {
	vec2 from_center = UV * 2.0 - 1.0;
	float radius = length(from_center);
	float rim = smoothstep(0.62, 1.30, radius);
	float angle = atan(from_center.y, from_center.x + 0.00001);
	float marks = smoothstep(0.85, 0.99, cos(angle * 24.0));
	marks *= smoothstep(0.91, 0.98, radius) * (1.0 - smoothstep(1.06, 1.12, radius));
	float edge_line = (1.0 - smoothstep(0.0, 0.024, abs(radius - 1.07))) * 0.15;
	vec3 amber = mix(vec3(0.34, 0.16, 0.035), vec3(0.92, 0.57, 0.16), marks);
	COLOR = vec4(amber, (0.43 * rim + 0.21 * marks + edge_line) * amount);
}
