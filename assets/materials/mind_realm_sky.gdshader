shader_type sky;
render_mode use_debanding;

uniform vec3 zenith_color : source_color = vec3(0.07, 0.14, 0.22);
uniform vec3 horizon_color : source_color = vec3(0.62, 0.67, 0.72);
uniform vec3 ground_color : source_color = vec3(0.17, 0.21, 0.27);
uniform vec3 sun_color : source_color = vec3(1.0, 0.82, 0.57);
uniform vec3 sun_dir = vec3(-0.62, 0.27, -0.74);
uniform float sky_energy = 0.96;
uniform float sun_halo_strength = 0.52;
uniform float sun_disk_strength = 2.8;

void sky() {
	vec3 d = normalize(EYEDIR);
	vec3 sdir = normalize(sun_dir);
	float h = max(d.y, 0.0);

	vec3 upper = mix(horizon_color, zenith_color, pow(h, 0.48));
	float band = exp(-abs(d.y) * 9.5);
	upper += horizon_color * band * 0.16;

	float sun_dot = max(dot(d, sdir), 0.0);
	upper += sun_color * pow(sun_dot, 8.0) * sun_halo_strength;
	upper += sun_color * pow(sun_dot, 96.0) * (sun_halo_strength * 1.4);
	upper += sun_color * smoothstep(0.9992, 0.99975, sun_dot) * sun_disk_strength;

	vec3 col = upper;
	if (d.y < 0.0) {
		col = mix(horizon_color * 0.82, ground_color, smoothstep(0.0, 0.45, -d.y));
	}
	COLOR = col * sky_energy;
}
