shader_type spatial;
uniform vec4 stone_color : source_color = vec4(0.29, 0.22, 0.37, 1.0);
uniform vec2 block_size = vec2(1.45, 0.62);
uniform float mortar = 0.024;
varying vec3 castle_position;
varying vec3 castle_normal;

float hash(vec2 key) {
	return fract(sin(dot(key, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	castle_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	castle_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
	vec3 axis = abs(castle_normal);
	vec2 p = axis.y > 0.7 ? castle_position.xz
		: (axis.x > axis.z ? castle_position.zy : castle_position.xy);
	vec2 grid = p / block_size;
	grid.x += mod(floor(grid.y), 2.0) * 0.5;
	vec2 cell = floor(grid);
	vec2 local = fract(grid);
	vec2 edge = min(local, 1.0 - local) * block_size;
	float chip = 0.004 * sin(p.x * 49.0 + p.y * 15.0) + 0.006 * sin(p.y * 33.0 - p.x * 9.0);
	float face = smoothstep(mortar - 0.010, mortar + 0.020, min(edge.x, edge.y) + chip);
	float tone = mix(0.73, 1.19, hash(cell));
	float grain = 0.035 * sin(p.x * 88.0 + sin(p.y * 26.0)) + 0.018 * sin(p.y * 63.0);
	float veins = 0.038 * sin(p.y * 9.0 + p.x * 2.0 + 2.3 * sin(p.x * 3.7 + p.y * 1.7));
	ALBEDO = stone_color.rgb * (mix(0.37, tone, face) + grain + veins);
	ROUGHNESS = mix(0.92, 0.55, face);
}
