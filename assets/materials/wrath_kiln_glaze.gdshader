shader_type spatial;

uniform vec4 glaze : source_color = vec4(0.78, 0.72, 0.65, 1.0);
uniform float firing = 0.5;
varying vec3 kiln_world;

float grain(vec2 point) {
	return fract(sin(dot(point, vec2(65.7, 113.1))) * 17531.743);
}

float noise(vec2 point) {
	vec2 cell = floor(point);
	vec2 fraction = fract(point);
	vec2 weight = fraction * fraction * (3.0 - 2.0 * fraction);
	return mix(mix(grain(cell), grain(cell + vec2(1.0, 0.0)), weight.x),
		mix(grain(cell + vec2(0.0, 1.0)), grain(cell + 1.0), weight.x), weight.y);
}

void vertex() {
	kiln_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 surface_point = vec2(kiln_world.x + kiln_world.z * 0.68, kiln_world.y + kiln_world.z * 0.25);
	float mottling = noise(surface_point * 1.86) * 0.7 + noise(surface_point * 8.2) * 0.3;
	float striae = noise(surface_point * vec2(12.2, 0.71));
	float edge = min(min(UV.x, UV.y), min(1.0 - UV.x, 1.0 - UV.y));
	float baking = (1.0 - smoothstep(0.05, 0.30, edge + mottling * 0.12)) * firing;
	float streak = smoothstep(0.52, 0.89, striae) * (1.0 - smoothstep(0.1, 0.76, UV.y));
	float hairline = abs(noise(surface_point * 11.0 + mottling * 2.9) - 0.44);
	float fine_craze = (1.0 - smoothstep(0.012, 0.054, hairline)) * smoothstep(0.40, 0.82, mottling);
	vec3 fired_clay = glaze.rgb * vec3(0.68, 0.46, 0.37);
	vec3 fired_glaze = mix(glaze.rgb * (0.89 + mottling * 0.17), fired_clay, baking + streak * 0.18);
	ALBEDO = fired_glaze * (1.0 - fine_craze * 0.12);
	ROUGHNESS = mix(0.45 + mottling * 0.19, 0.8, baking);
}
