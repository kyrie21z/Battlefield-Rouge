shader_type sky;

float ash_noise(vec3 p) {
	vec3 cell = floor(p);
	vec3 f = fract(p);
	f = f*f*(3.0-2.0*f);
	float seed = dot(cell, vec3(1.0, 37.0, 113.0));
	vec4 corners = seed + vec4(0.0, 37.0, 113.0, 150.0);
	vec4 along_x = mix(fract(sin(corners) * 4375.51), fract(sin(corners + 1.0) * 4375.51), f.x);
	return mix(mix(along_x.x, along_x.y, f.y), mix(along_x.z, along_x.w, f.y), f.z);
}

void sky() {
	float elevation = clamp(EYEDIR.y, 0.0, 1.0);
	vec3 soot = vec3(0.050, 0.040, 0.058);
	vec3 dust = vec3(0.16, 0.089, 0.091);
	float horizon = exp(-max(EYEDIR.y, 0.0) * 4.3);
	vec3 view = normalize(vec3(-0.38, 0.22, -0.94));
	float glow = pow(max(dot(EYEDIR, view), 0.0), 7.0) * exp(-elevation * 2.6);
	float angle = atan(EYEDIR.x, EYEDIR.z);
	float ribbons = sin(elevation * 38.0 + sin(angle * 7.0) * 0.72 + cos(angle * 13.0) * 0.21);
	ribbons = smoothstep(0.37, 1.0, ribbons) * smoothstep(0.0, 0.22, elevation) * (1.0 - elevation);
	vec3 air = EYEDIR * vec3(4.6, 11.0, 4.6);
	float smoke = 0.65 * ash_noise(air) + 0.35 * ash_noise(air * 2.72);
	float banks = smoothstep(0.28, 0.78, smoke);
	COLOR = mix(soot, dust, horizon) * (0.7 + 0.5 * banks)
		+ vec3(0.34, 0.088, 0.036) * glow * (1.29 - banks)
		+ ribbons * vec3(0.010, 0.007, 0.008);
}
