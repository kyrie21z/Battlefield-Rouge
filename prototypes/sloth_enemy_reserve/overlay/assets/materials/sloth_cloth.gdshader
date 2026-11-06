shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform vec4 cloth_color : source_color = vec4(0.105, 0.12, 0.145, 1.0);
uniform float visual_time = 0.0;
uniform float sway = 0.018;
uniform float mantle_open = 0.0;
uniform float cast_amount = 0.0;

void vertex() {
	// UV.y is distance down the mantle. The shoulders and hood stay attached.
	float weight = smoothstep(0.08, 1.0, UV.y);
	VERTEX.x += sign(VERTEX.x) * mantle_open * weight * 0.12;
	VERTEX.z += mantle_open * weight * 0.055;
	VERTEX.x += sin(visual_time * 1.45 + VERTEX.y * 4.0 + VERTEX.z * 3.5) * sway * weight;
	VERTEX.z += cos(visual_time * 1.2 + VERTEX.x * 5.5) * sway * weight;
}

void fragment() {
	float warp = sin(UV.x * 1100.0) * sin(UV.y * 870.0);
	float crease = 0.94 + 0.06 * sin(UV.x * 113.0 + UV.y * 15.0);
	ALBEDO = cloth_color.rgb * crease * (1.0 + warp * 0.026);
	ROUGHNESS = 0.94;
	SPECULAR = 0.18;
	RIM = 0.16;
	RIM_TINT = 0.35;
	EMISSION = vec3(0.11, 0.18, 0.22) * cast_amount * 0.13;
}
