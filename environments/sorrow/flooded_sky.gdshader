shader_type sky;

float cloud(vec3 p) {
	vec3 cell = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float seed = dot(cell, vec3(1.0, 37.0, 113.0));
	vec4 samples = seed + vec4(0.0, 37.0, 113.0, 150.0);
	vec4 x = mix(fract(sin(samples) * 4375.51), fract(sin(samples + 1.0) * 4375.51), f.x);
	return mix(mix(x.x, x.y, f.y), mix(x.z, x.w, f.y), f.z);
}

void sky() {
	float elevation = max(EYEDIR.y, 0.0);
	vec3 p = EYEDIR * vec3(4.10, 14.0, 4.10);
	float rolling = cloud(p) * 0.7 + cloud(p * 2.7) * 0.3;
	vec3 dusk = vec3(0.036, 0.056, 0.088);
	vec3 horizon = vec3(0.14, 0.191, 0.234);
	float break_in_cloud = pow(max(dot(EYEDIR, normalize(vec3(0.33, 0.17, -1.0))), 0.0), 9.0);
	COLOR = mix(dusk, horizon, exp(-4.5 * elevation)) * (0.57 + 0.69 * rolling)
		+ vec3(0.16, 0.184, 0.18) * break_in_cloud * (1.0 - 0.42 * rolling);
}
