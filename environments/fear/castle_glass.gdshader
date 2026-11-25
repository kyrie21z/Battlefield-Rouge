shader_type spatial;
render_mode unshaded, cull_disabled;
uniform float medallion = 0.0;
uniform float tint_shift = 0.0;

float hash(vec2 key) {
	return fract(sin(dot(key, vec2(87.7, 271.9))) * 43758.5453);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float angle = atan(p.y, p.x + 0.00001);
	vec2 diamonds = vec2(UV.x * 4.0 + UV.y * 9.0, UV.x * 4.0 - UV.y * 9.0);
	float lead = min(abs(fract(diamonds.x) - 0.5), abs(fract(diamonds.y) - 0.5));
	float rose_lead = min(abs(fract(r * 4.25) - 0.5), abs(fract(angle * 2.5465) - 0.5));
	float pane = hash(floor(diamonds) + vec2(tint_shift, 0.0));
	float petal = hash(floor(vec2(r * 5.0, angle * 2.5465)) + tint_shift);
	float pattern = mix(lead, rose_lead, medallion);
	float tint = mix(pane, petal, medallion);
	vec3 glass = mix(vec3(0.095, 0.025, 0.24), vec3(0.64, 0.30, 0.93), tint * tint);
	float shine = (1.12 - 0.32 * r) * (0.94 + 0.06 * sin(UV.x * 90.0 + UV.y * 60.0));
	vec3 seam = vec3(0.018, 0.009, 0.031);
	ALBEDO = mix(seam, glass * shine, smoothstep(0.045, 0.085, pattern));
	EMISSION = ALBEDO * (0.45 + 0.45 * tint);
}
