shader_type spatial;

varying vec3 kiln_point;

vec2 cell_offset(vec2 cell) {
	vec2 seed = vec2(dot(cell, vec2(35.1, 79.7)), dot(cell, vec2(81.9, 29.3)));
	return 0.24 + 0.52 * fract(sin(seed) * 43758.5453);
}

void vertex() {
	kiln_point = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 grid = kiln_point.xz * 0.31 + vec2(0.37, 0.81);
	vec2 cell = floor(grid);
	vec2 local = fract(grid);
	float closest = 8.0;
	float next_closest = 8.0;
	float glaze = 0.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 offset = vec2(float(x), float(y));
			vec2 delta = offset + cell_offset(cell + offset) - local;
			float distance_squared = dot(delta, delta);
			if (distance_squared < closest) {
				next_closest = closest;
				closest = distance_squared;
				glaze = cell_offset(cell + offset).x;
			} else {
				next_closest = min(next_closest, distance_squared);
			}
		}
	}
	float boundary = next_closest - closest;
	float aa = min(fwidth(boundary), 0.08);
	float seam = 1.0 - smoothstep(0.009 - aa, 0.025 + aa, boundary);
	float baked_edge = 1.0 - smoothstep(0.035, 0.095, boundary);
	float vestibule = smoothstep(8.0, 17.0, kiln_point.z);
	float side_lane = smoothstep(10.2, 15.2, kiln_point.x);
	vec3 porcelain = mix(vec3(0.26, 0.207, 0.177), vec3(0.48, 0.385, 0.309), glaze);
	// Released kiln dust settles along the banks and bakes into the tile joins.
	float dust = smoothstep(11.0, 19.0, abs(kiln_point.x) + 1.4 * sin(kiln_point.z * 0.55));
	porcelain *= 1.0 - dust * (0.19 + 0.21 * baked_edge);
	porcelain = mix(porcelain, vec3(0.31, 0.255, 0.24), side_lane * 0.30);
	porcelain = mix(porcelain, vec3(0.14, 0.10, 0.095), vestibule * 0.84);
	porcelain *= 1.0 - 0.15 * baked_edge;
	ALBEDO = mix(porcelain, vec3(0.145, 0.074, 0.055), seam * 0.48);
	ROUGHNESS = 0.72 + 0.20 * seam;
	SPECULAR = 0.24;
}
