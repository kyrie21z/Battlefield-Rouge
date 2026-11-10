shader_type canvas_item;
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
void fragment() {
	vec3 background = textureLod(screen_texture, SCREEN_UV, 2.0).rgb;
	COLOR = vec4(background * 0.38, COLOR.a);
}
