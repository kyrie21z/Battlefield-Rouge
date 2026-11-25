shader_type canvas_item;
// 沉睡共鸣的"子弹时间"观感：去饱和 + 冷色偏移 + 暗角。
// 只做屏幕调色，不改变任何玩法时钟；intensity 由 SlumberTimeWarp 驱动。

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float intensity = 0.0;
// 怠惰的金色，和沉睡共鸣释放时那圈 #e3a23a 的反馈同一个色系。
uniform vec3 tint : source_color = vec3(0.89, 0.64, 0.23);
uniform float desaturation = 0.35;
uniform float vignette = 0.55;

void fragment() {
	vec4 screen = texture(screen_tex, SCREEN_UV);
	float luma = dot(screen.rgb, vec3(0.2126, 0.7152, 0.0722));
	// 只轻轻压掉一点饱和度，保住怠惰的金色，不要洗成土黄。
	vec3 graded = mix(vec3(luma), screen.rgb, 1.0 - desaturation * intensity);
	// 整体往金色推，暗部更明显，亮部保留。
	graded = mix(graded, graded * tint * 1.25, 0.55 * intensity);
	// 暗角：把注意力压回准星。
	vec2 centered = SCREEN_UV - vec2(0.5);
	float dist = length(centered) * 1.42;
	float edge = smoothstep(0.32, 1.0, dist);
	graded *= 1.0 - edge * vignette * intensity;
	COLOR = vec4(graded, screen.a);
}
