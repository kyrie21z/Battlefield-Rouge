shader_type canvas_item;
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float openness : hint_range(0.0, 1.0) = 0.0;
uniform float defocus : hint_range(0.0, 6.0) = 0.0;
uniform float whiteout : hint_range(0.0, 1.0) = 0.0;
uniform float crown_flash : hint_range(0.0, 1.0) = 0.0;
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float aperture = openness * 1.7 - 0.05 - abs(p.y) - p.x * p.x * 0.19;
	float lid = smoothstep(-0.025, 0.035, aperture);
	vec3 world = textureLod(screen_texture, SCREEN_UV, defocus).rgb;
	world = mix(world, vec3(1.0), whiteout);
	float corner = pow(abs(p.x * p.y), 3.0);
	world += vec3(1.0, 0.72, 0.23) * corner * crown_flash;
	COLOR = vec4(world * lid, 1.0);
}
