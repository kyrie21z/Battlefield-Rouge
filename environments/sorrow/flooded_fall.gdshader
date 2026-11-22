shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform float water_clock = 0.0;

float stream_hash(vec2 p) {
	vec3 h = fract(p.xyx * 0.1031);
	h += dot(h, h.yzx + 33.33);
	return fract((h.x + h.y) * h.z);
}

float stream_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(stream_hash(i), stream_hash(i + vec2(1.0, 0.0)), f.x),
		mix(stream_hash(i + vec2(0.0, 1.0)), stream_hash(i + 1.0), f.x), f.y);
}

void vertex() {
	float phase = UV.y * 24.0 - water_clock * 3.0;
	float folds = sin(UV.x * 31.0 + phase * 0.61) + 0.38 * sin(UV.x * 55.0 - phase);
	VERTEX.z += folds * 0.068 * sin(UV.y * 2.6);
}

void fragment() {
	float time = water_clock;
	float run = UV.y * 16.5 - time * 3.3;
	float meander = stream_noise(vec2(UV.x * 11.0, run * 0.29)) * 0.87;
	float threads = stream_noise(vec2(UV.x * 87.0 + meander, run));
	float broad = stream_noise(vec2(UV.x * 22.0 + meander * 0.51, run * 0.47));
	float crest = smoothstep(0.41, 0.84, threads * 0.41 + broad * 0.59);
	float aeration = smoothstep(0.65, 1.0, UV.y + threads * 0.18);
	float lip = (1.0 - smoothstep(0.0, 0.16, UV.y)) * smoothstep(0.25, 0.80, threads);
	float foam = clamp(crest * 0.66 + aeration * 0.34 + lip * 0.62, 0.0, 1.0);
	vec3 deep = vec3(0.058, 0.135, 0.19);
	vec3 spray = vec3(0.61, 0.72, 0.76);
	ALBEDO = mix(deep, spray, 0.16 + foam * 0.79);
	EMISSION = vec3(0.10, 0.145, 0.162) * (0.20 + foam * 0.68);
	ROUGHNESS = 0.18 + foam * 0.46;
	SPECULAR = 0.61;
}
