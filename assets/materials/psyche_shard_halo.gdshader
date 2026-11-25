shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, shadows_disabled;

// Ground sigil under a psyche shard. Everything is drawn from UV space and
// pulse_time, so it freezes with _process instead of following wall-clock TIME.
// Uses alpha blending so the sigil remains readable on both dark arenas and
// bright white-stone floors. Alpha reaches zero well before the quad border.
uniform vec4 halo_color : source_color = vec4(0.94, 0.72, 0.33, 1.0);
uniform vec4 accent_color : source_color = vec4(1.0, 0.90, 0.66, 1.0);
uniform float pulse_time = 0.0;
uniform float proximity_boost : hint_range(0.0, 1.0) = 0.0;
uniform float opacity : hint_range(0.0, 2.0) = 0.78;

const float TAU_ = 6.28318530718;

float band(float distance_value, float width) {
	float feather = fwidth(distance_value) * 1.35 + 0.0015;
	return 1.0 - smoothstep(width - feather, width + feather, abs(distance_value));
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float radius = length(p);
	float angle = atan(p.y, p.x);
	float spin = pulse_time * (0.22 + 0.34 * proximity_boost);
	float rotation = angle + spin;

	float wedge = TAU_ / 8.0;
	float local_angle = mod(rotation, wedge) - wedge * 0.5;
	float polygon_radius = 0.560 * cos(wedge * 0.5) / max(cos(local_angle), 0.35);
	vec2 folded = vec2(cos(local_angle), sin(local_angle)) * radius;

	float outer_band = band(radius - polygon_radius, 0.016);
	float arc = abs(local_angle) * polygon_radius;
	float segment = 1.0 - smoothstep(0.180, 0.212, arc);
	float diamond = abs(folded.x - polygon_radius) + abs(folded.y) * 1.55;
	float diamond_tick = 1.0 - smoothstep(0.022, 0.040, diamond);
	float outer = outer_band * (segment + 0.85 * diamond_tick);

	float phase = fract(pulse_time * 0.34);
	float inner_radius = mix(0.16, 0.48, phase);
	float inner_ring = band(radius - inner_radius, 0.007 + 0.011 * (1.0 - phase));
	float inner_fade = pow(1.0 - phase, 1.6);

	float cross_ticks = (band(p.x - p.y, 0.0055) + band(p.x + p.y, 0.0055))
		* smoothstep(0.20, 0.28, radius)
		* (1.0 - smoothstep(0.42, 0.52, radius));

	float core_glow = pow(max(0.0, 1.0 - radius / 0.42), 2.4);
	float haze = pow(max(0.0, 1.0 - radius / 0.78), 3.0) * 0.12;
	float edge_fade = 1.0 - smoothstep(0.72, 0.94, radius);

	float detail = clamp(outer + cross_ticks + inner_ring * inner_fade, 0.0, 1.0);
	vec3 rich_color = mix(halo_color.rgb * 0.85, accent_color.rgb, detail * 0.55);
	vec3 color = rich_color * (1.05 + proximity_boost * 0.30);
	color += accent_color.rgb * core_glow * 0.25;

	float alpha = (outer * 0.92 + inner_ring * inner_fade * 0.78
		+ core_glow * 0.40 + cross_ticks * 0.72 + haze)
		* opacity * (1.0 + proximity_boost * 0.35) * edge_fade;

	ALBEDO = color;
	ALPHA = clamp(alpha, 0.0, 0.92);
}
