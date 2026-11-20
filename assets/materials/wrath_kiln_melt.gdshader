shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

// UV.y measures metres downstream. UV2.y goes from underside (-1) to crown (+1).
uniform float flow_time = 0.0;
uniform float heat : hint_range(0.0, 1.0) = 1.0;

float hash(vec2 cell) {
	vec3 p = fract(vec3(cell.xyx) * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}

float lava_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + 1.0), f.x), f.y);
}

void vertex() {
	float along = UV.y * 3.0 - flow_time * 1.74;
	float fold = sin(along + 2.1 * sin(UV.x * 9.0 + along * 0.43));
	VERTEX += NORMAL * fold * min(0.047, UV2.x * 0.035) * heat;
}

void fragment() {
	float bank = abs(2.0 * UV.x - 1.0);
	vec2 p = vec2((UV.x - 0.5) * UV2.x, UV.y);
	p.y -= flow_time * 0.58;
	float bend = lava_noise(vec2(p.x * 0.8, p.y * 0.38));
	vec2 grain = p * vec2(2.9, 1.20) + vec2(1.27 * bend, bend);
	float rind = lava_noise(grain * 4.3 + bend);
	float fold = lava_noise(grain) + 0.22 * lava_noise(grain * 2.8);
	float edge = abs(fold - 0.57);
	float fissure = 1.0 - smoothstep(0.004, 0.084 + fwidth(fold), edge);
	float top = smoothstep(-0.55, 0.78, UV2.y);
	float crust = smoothstep(0.036, 0.32, edge + 0.20 * pow(bank, 4.0) + 0.15 * (1.0 - top));
	float opening = (1.0 - crust) * heat;
	vec3 basalt = mix(vec3(0.024, 0.015, 0.019), vec3(0.133, 0.046, 0.028), rind);
	vec3 hot = mix(vec3(0.56, 0.045, 0.010), vec3(1.61, 0.40, 0.065), fissure);
	ALBEDO = mix(basalt, vec3(0.33, 0.074, 0.019), opening);
	EMISSION = hot * opening * (0.23 + 0.77 * top);
	ROUGHNESS = mix(0.83 - rind * 0.23, 0.38, opening);
	SPECULAR = 0.36;
}
