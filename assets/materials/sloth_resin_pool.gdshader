shader_type spatial;
render_mode cull_disabled, depth_prepass_alpha;

uniform bool landed = false;
uniform float gel_age = 0.0;
uniform float spread = 0.4;

void fragment() {
	float r = length(UV);
	float edge = COLOR.r;
	if (!landed) {
		float lead = smoothstep(0.85, 0.97, edge);
		float bars = smoothstep(0.0, 0.16, sin(atan(UV.y, UV.x) * 14.0));
		ALBEDO = vec3(1.0, 0.56, 0.08);
		EMISSION = vec3(0.8, 0.24, 0.015) * lead;
		ROUGHNESS = 0.6;
		ALPHA = 0.06 + lead * (0.21 + 0.49 * bars);
	} else {
		if (r > spread) {
			discard;
		}
		float full_edge = max(edge, r / spread);
		float twist = sin(UV.x * 18.0 + sin(UV.y * 12.0)) * cos(UV.y * 16.0 - gel_age * 0.9);
		float coils = sin(r * 33.0 - gel_age * 3.2 + twist * 1.4);
		float ridges = smoothstep(0.42, 0.92, coils) * smoothstep(0.22, 0.81, twist);
		float honey = clamp(0.45 + 0.28 * twist + 0.18 * coils, 0.0, 1.0);
		vec3 amber = mix(vec3(0.48, 0.18, 0.008), vec3(1.0, 0.68, 0.053), honey);
		float lip = smoothstep(0.80, 0.92, full_edge);
		float shine = ridges * 0.65 + lip * 0.31;
		ALBEDO = mix(amber, vec3(1.0, 0.84, 0.25), shine);
		EMISSION = vec3(0.24, 0.10, 0.008) * (0.35 + shine);
		ROUGHNESS = mix(0.31, 0.17, shine);
		SPECULAR = 0.57;
		ALPHA = 1.0 - 0.28 * lip;
	}
}
