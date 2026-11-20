shader_type spatial;
render_mode cull_disabled, diffuse_burley;

// The mesh supplies individual torn locks. Small tapered clumps follow the
// same downward nap, with distance filtering so they settle into a solid pelt.
void fragment() {
	vec2 p = UV;
	float comb = p.x * 49.0 + 1.48 * sin(p.y * 3.9 + p.x * 11.0) + 0.53 * sin(p.y * 8.3 - p.x * 17.0);
	float lane = floor(comb);
	float seed = fract(sin(lane * 17.35) * 7115.13);
	float end = fract(p.y * 2.5 + seed);
	float hair = abs(fract(comb) - 0.5);
	float aa = max(fwidth(comb), 0.035);
	float strand = (1.0 - smoothstep(0.04, 0.16 + aa, hair)) * sin(end * 3.14159)
		* (1.0 - smoothstep(0.18, 0.94, aa));
	float undercoat = 0.5 + 0.5 * sin(p.x * 56.0 + 1.1 * sin(p.y * 4.7));
	ALBEDO = COLOR.rgb * (0.85 + 0.17 * undercoat + 0.32 * strand);
	ROUGHNESS = 0.94;
	SPECULAR = 0.19;
}
