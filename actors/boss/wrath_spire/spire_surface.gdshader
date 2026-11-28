shader_type spatial;

uniform vec4 surface_color : source_color = vec4(0.53, 0.11, 0.07, 1.0);
uniform bool fire_livery = false;
uniform float heat : hint_range(0.0, 1.0) = 0.0;
varying vec3 local_vertex;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float fracture(vec2 p) {
	vec2 cell = floor(p);
	vec2 offset = fract(p);
	float nearest = 8.0;
	float next = 8.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 tile = vec2(float(x), float(y));
			vec2 sample_point = tile + vec2(hash(cell + tile), hash(cell + tile + 17.0));
			vec2 diff = sample_point - offset;
			float depth = dot(diff, diff);
			next = min(next, max(nearest, depth));
			nearest = min(nearest, depth);
		}
	}
	return next - nearest;
}

void vertex() {
	local_vertex = VERTEX;
}

void fragment() {
	vec3 p = local_vertex;
	float soot = hash(floor(p.xy * 14.0 + vec2(p.z * 17.0, p.z * 9.0)));
	vec3 base = surface_color.rgb * mix(0.67, 1.08, soot);
	if (fire_livery) {
		float rise = clamp((p.y - 0.51) / 1.06, 0.0, 1.0);
		float around = atan(p.x, -p.z) / TAU;
		float curl = 0.30 * sin(4.3 * rise) - 0.18 * rise;
		float tongue = abs(fract(around * 7.0 - curl) - 0.5);
		float width = mix(0.48, 0.016, pow(rise, 0.68));
		float paint = (1.0 - smoothstep(width - 0.025, width, tongue));
		paint *= smoothstep(0.51, 0.55, p.y) * (1.0 - smoothstep(1.48, 1.59, p.y));
		paint *= smoothstep(0.07, 0.18, soot);
		vec3 pigment = mix(vec3(0.16, 0.021, 0.009), vec3(0.70, 0.16, 0.018), rise);
		ALBEDO = mix(base, pigment, paint * 0.87);
		METALLIC = mix(0.66, 0.16, paint);
		ROUGHNESS = mix(0.56, 0.82, paint);
	} else {
		vec2 pattern = vec2(p.x + 0.63 * p.z, p.y + 0.31 * p.z) * 3.25;
		float seam = fracture(pattern);
		float crack = 1.0 - smoothstep(0.009, 0.052, seam);
		float bevel = smoothstep(0.024, 0.045, seam) * (1.0 - smoothstep(0.051, 0.094, seam));
		float hot = crack * smoothstep(0.03, 0.72, heat);
		ALBEDO = mix(base, base * 0.25, crack * 0.75) + vec3(0.095, 0.041, 0.017) * bevel;
		EMISSION = vec3(1.0, 0.15, 0.019) * hot * 0.82;
		ROUGHNESS = 0.68;
	}
}
