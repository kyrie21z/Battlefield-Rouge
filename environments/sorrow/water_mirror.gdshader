shader_type spatial;
// Stay in the opaque pass: Godot Forward+ SSR reflects into this surface.
// ALPHA/screen-texture refraction would remove it from that pass.
render_mode cull_disabled;
#include "res://environments/sorrow/rain_layout.gdshaderinc"
uniform vec4 water_color : source_color = vec4(0.014, 0.045, 0.075, 1.0);
uniform float clock = 0.0;
uniform vec4 ripples[32]; // x/z position, birth time, strength
uniform bool rain_enabled = true;
uniform float rain_strength : hint_range(0.0, 1.0) = 0.22;
uniform vec3 whirlpool = vec3(0.0); // local x/z and radius
varying vec3 water_pos;

// Derivative of a damped concentric wave packet; normals bend the actual
// reflected image, rather than painting a bright decal on a flat mirror.
vec3 ring(vec2 offset, float age, float strength, float speed, float life) {
	if (age < 0.0 || age >= life) { return vec3(0.0); }
	float d = length(offset);
	float front = d - age * speed;
	float envelope = exp(-front * front * 9.0) * pow(1.0 - age / life, 2.0);
	float wave = sin(front * 24.0);
	float slope = (24.0 * cos(front * 24.0) - 18.0 * front * wave) * envelope;
	vec2 normal = offset / max(d, 0.025) * slope * strength * 0.009;
	return vec3(normal, envelope * abs(wave) * strength);
}
void vertex() { water_pos = VERTEX; }
void fragment() {
	vec3 waves = vec3(0.0);
	for (int i = 0; i < 32; i++) {
		waves += ring(water_pos.xz - ripples[i].xy, clock - ripples[i].z, ripples[i].w, 2.1, 2.4);
	}
	if (rain_enabled) {
		vec2 cell = floor((water_pos.xz - RAIN_MIN) / RAIN_CELL);
		// Neighbouring packets cross cell boundaries without seams.
		for (int x = -1; x <= 1; x++) {
			for (int z = -1; z <= 1; z++) {
				vec2 near_cell = cell + vec2(float(x), float(z));
				if (all(greaterThanEqual(near_cell, vec2(0.0))) && all(lessThan(near_cell, RAIN_GRID))) {
					waves += ring(water_pos.xz - rain_point(near_cell), rain_phase(near_cell, clock) - RAIN_FALL, rain_strength, 0.65, RAIN_RING);
				}
			}
		}
	}
	vec2 breath = vec2(sin(water_pos.y + water_pos.x * 0.43 + clock * 0.23), cos(water_pos.z * 0.51 - clock * 0.19)) * 0.0015;
	vec2 current = water_pos.xz - whirlpool.xy;
	float foam = 0.0;
	float eddy = 0.0;
	if (dot(current, current) < whirlpool.z * whirlpool.z) {
		float distance = length(current);
		float t = distance / whirlpool.z;
		float rim = 1.0 - smoothstep(0.52, 1.0, t);
		vec2 outward = current / max(distance, 0.045);
		float angle = atan(current.y, current.x + 0.00001);
		float phase = 3.0 * angle + t * 15.0 - clock * 3.3;
		float arm = cos(phase + 0.25 * sin(angle * 7.0 + t * 23.0 - clock * 1.7));
		float threads = 0.76 + 0.24 * cos(t * 48.0 - angle * 5.0 + clock * 0.9);
		foam = smoothstep(0.41, 0.98, arm) * smoothstep(0.06, 0.18, t) * rim * threads;
		eddy = (1.0 - smoothstep(0.06, 0.66, t)) * 0.82;
		waves.xy += (outward * (0.065 * rim) + vec2(-outward.y, outward.x) * foam * 0.054)
			* smoothstep(0.03, 0.18, t);
	}
	vec2 slope = clamp(waves.xy + breath, vec2(-0.16), vec2(0.16));
	NORMAL = normalize((VIEW_MATRIX * MODEL_MATRIX * vec4(normalize(vec3(-slope.x, 1.0, -slope.y)), 0.0)).xyz);
	ALBEDO = mix(water_color.rgb * (1.0 - eddy), vec3(0.044, 0.136, 0.164), foam * 0.75);
	METALLIC = 0.32;
	ROUGHNESS = 0.055;
	SPECULAR = 0.95;
	RIM = 0.1;
	RIM_TINT = 0.3;
	BACKLIGHT = vec3(0.0, 0.008, 0.015);
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
	EMISSION = vec3(0.02, 0.10, 0.16) * (fresnel * 0.08 + min(waves.z, 2.0) * 0.05)
		+ vec3(0.035, 0.065, 0.076) * foam;
}
