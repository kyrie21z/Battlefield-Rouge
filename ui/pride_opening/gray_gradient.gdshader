shader_type spatial;
render_mode diffuse_burley, specular_disabled;
uniform vec4 base_color : source_color = vec4(0.7, 0.73, 0.75, 1.0);
varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// Large, quiet tonal changes instead of detailed surface textures.
	float height_mix = smoothstep(-1.0, 20.0, world_pos.y);
	float depth_mix = 1.0 - smoothstep(-80.0, 8.0, world_pos.z);
	vec3 low = base_color.rgb * 0.72;
	vec3 high = mix(base_color.rgb, vec3(0.92, 0.94, 0.94), 0.28);
	ALBEDO = mix(low, high, height_mix);
	ALBEDO = mix(ALBEDO, vec3(0.68, 0.73, 0.76), depth_mix * 0.22);
	ROUGHNESS = 1.0;
}
