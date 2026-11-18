shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;

uniform bool wave = false;
uniform bool active = false;
uniform float reach = 3.2;
uniform float safe_half_angle = 0.384;
uniform float progress = 0.0;
uniform float age = 0.0;
uniform float front = 0.0;
uniform float remaining = 1.0;

float ink(float distance_to_line, float width) {
	return 1.0 - smoothstep(width, width + max(fwidth(distance_to_line), 0.009), abs(distance_to_line));
}

void fragment() {
	float r = length(UV);
	float theta = atan(UV.x, UV.y + 0.00001);
	float angle = abs(theta);
	float in_gap = 1.0 - smoothstep(safe_half_angle - 0.004, safe_half_angle + 0.004, angle);
	float strength = 0.0;
	float glow = 0.0;
	float falloff = 1.0 - smoothstep(reach - 0.03, reach, r);
	if (!wave) {
		float outer = ink(r - (reach - 0.105), 0.024);
		float ticks = ink(sin(theta * 18.0) * r, 0.22)
			* smoothstep(2.46, 2.60, r) * (1.0 - smoothstep(2.94, 3.01, r));
		float dial = ink(r - 2.43, 0.018) + ink(r - 1.43, 0.024);
		float clock_angle = theta - (age * 1.65 + progress * 1.9);
		float pointer = ink(sin(clock_angle) * r, 0.038) * step(0.0, cos(clock_angle))
			* (1.0 - smoothstep(2.02, 2.35, r));
		float hub = ink(r - 0.24, 0.028);
		float ripple = exp(-14.0 * abs(r - fract(age * 0.35) * reach));
		strength = 0.13 + 0.45 * outer + 0.44 * ticks + 0.30 * dial + 0.54 * pointer + 0.40 * hub;
		strength *= active ? 1.0 : mix(0.38, 0.85, progress);
		glow = ripple * (active ? 0.73 : 0.12) + 0.30 * pointer;
	} else if (!active) {
		float warning_ring = ink(r - (reach - 0.12), 0.055);
		float converging = ink(r - mix(reach - 0.28, 0.28, progress), 0.046);
		float ticks = ink(sin(theta * 16.0) * r, 0.24) * smoothstep(reach - 0.68, reach - 0.26, r);
		float rails = ink((angle - safe_half_angle) * r, 0.036) * smoothstep(0.18, 0.65, r);
		strength = (0.075 + 0.54 * warning_ring + 0.23 * ticks + 0.34 * converging) * (1.0 - in_gap)
			+ 0.40 * rails;
		glow = 0.22 * rails + 0.40 * converging * (1.0 - in_gap);
	} else {
		float travel = front - r;
		float crest = ink(travel - 0.08, 0.063);
		float echo = ink(travel - 0.44, 0.040) * 0.40;
		float wake = smoothstep(-0.25, 0.07, travel) * (1.0 - smoothstep(0.25, 0.94, travel));
		strength = (0.32 * wake + 0.88 * crest + echo) * (1.0 - in_gap);
		glow = (0.62 * crest + 0.21 * wake + 0.52 * echo) * (1.0 - in_gap);
	}
	vec3 amber_ink = vec3(0.39, 0.13, 0.013);
	vec3 amber_light = vec3(1.0, 0.63, 0.16);
	ALBEDO = mix(amber_ink, amber_light, clamp(glow, 0.0, 1.0));
	ALPHA = clamp(strength, 0.0, 0.86) * falloff * (active ? smoothstep(0.0, 0.18, remaining) : 1.0);
}
