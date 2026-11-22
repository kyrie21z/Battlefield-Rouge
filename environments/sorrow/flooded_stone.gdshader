shader_type spatial;
render_mode cull_disabled, diffuse_burley;

uniform vec4 base_tint : source_color = vec4(1.0);
uniform float wetness : hint_range(0.0, 1.0) = 1.0;
varying vec3 stone_pos;
varying vec3 stone_normal;

float stone_hash(vec2 p) {
	vec3 h = fract(p.xyx * 0.1031);
	h += dot(h, h.yzx + 33.33);
	return fract((h.x + h.y) * h.z);
}

float stone_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(stone_hash(i), stone_hash(i + vec2(1.0, 0.0)), f.x),
		mix(stone_hash(i + vec2(0.0, 1.0)), stone_hash(i + 1.0), f.x), f.y);
}

void vertex() {
	stone_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	stone_normal = abs(normalize(MODEL_NORMAL_MATRIX * NORMAL));
}

void fragment() {
	bool floor_face = stone_normal.y > 0.70;
	vec2 slab = stone_normal.x > stone_normal.z ? stone_pos.zy : stone_pos.xy;
	slab = floor_face ? stone_pos.xz : slab;
	vec2 course = floor_face ? vec2(3.35, 2.85) : vec2(2.42, 0.89);
	vec2 cell = slab / course;
	cell.x += 0.50 * mod(floor(cell.y), 2.0);
	vec2 within = min(fract(cell), 1.0 - fract(cell)) * course;
	float edge = min(within.x, within.y);
	float aa = min(fwidth(edge), 0.06);
	float joint = 1.0 - smoothstep(0.013 - aa, 0.035 + aa, edge);
	float key = stone_hash(floor(cell));
	float mottling = stone_noise(slab * 1.36);
	float streak = stone_noise(slab * vec2(8.5, 0.24));
	float waterline = 1.0 - smoothstep(0.13, 1.32, stone_pos.y + 0.41 * mottling);
	float runoff = smoothstep(0.39, 0.91, streak) * 0.24;
	float soaked = wetness * max(waterline * 0.34, runoff);
	vec3 surface = (COLOR.rgb * base_tint.rgb) * (0.84 + 0.17 * key + 0.14 * mottling);
	vec3 patina = surface * vec3(0.54, 0.72, 0.74);
	ALBEDO = mix(surface, patina, soaked) * (1.0 - joint * 0.39);
	ROUGHNESS = clamp(0.76 + joint * 0.1 - soaked * 0.49, 0.42, 0.92);
	SPECULAR = 0.3;
}
