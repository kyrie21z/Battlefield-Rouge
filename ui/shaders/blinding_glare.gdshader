shader_type canvas_item;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float intensity : hint_range(0.0, 1.0) = 0.03;
uniform float fracture_level : hint_range(0.0, 4.0) = 0.0;
uniform float visual_time = 0.0;
uniform bool reduced_motion = false;
uniform vec2 source_uv = vec2(0.5, -0.08);
void fragment() {
	vec2 aspect = vec2(SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x, 1.0);
	vec2 ray = (SCREEN_UV - source_uv) * aspect;
	float radius = max(length(ray), 0.008);
	float angle = atan(ray.y, ray.x);
	vec2 border_uv = abs(SCREEN_UV * 2.0 - 1.0);
	float edge = pow(max(border_uv.x, border_uv.y), 5.0);
	float high = smoothstep(2.8, 4.0, fracture_level);
	float pulse = reduced_motion ? 1.0 : 0.985 + 0.015 * sin(visual_time * 0.75);
	float star = pow(abs(cos(angle * 6.0)), 44.0) / (1.0 + radius * 4.0);
	float streak = exp(-abs(ray.y) * 75.0) / (1.0 + abs(ray.x) * 1.5);
	float halo = exp(-abs(radius - 0.48) * 16.0) * 0.045;
	// Keep the reticle readable while the edges remain pressurised by the crown.
	float center = smoothstep(0.06, 0.34, length((SCREEN_UV - 0.5) * aspect));
	float energy = (edge * 0.25 + high * (star * 0.42 + streak * 0.35 + halo)) * intensity * pulse * center;
	vec2 dispersion = (ray / radius) / aspect * SCREEN_PIXEL_SIZE.y * 1.6 * high * intensity * edge;
	vec3 scene = texture(screen_texture, SCREEN_UV).rgb;
	vec3 split = vec3(texture(screen_texture, SCREEN_UV + dispersion).r, scene.g,
		texture(screen_texture, SCREEN_UV - dispersion).b);
	vec3 gold = vec3(1.0, 0.85, 0.51);
	vec3 result = mix(scene, split, high * edge * 0.38) + gold * energy;
	COLOR = vec4(result, 1.0);
}
