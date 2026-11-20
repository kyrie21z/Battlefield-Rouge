shader_type spatial;

varying vec3 wall_point;
varying vec3 wall_normal;

void vertex() {
	wall_point = VERTEX;
	wall_normal = NORMAL;
}

void fragment() {
	// Courses follow the wall's local tilt, including around its exposed ends.
	vec2 face = abs(wall_normal.x) > 0.5 ? wall_point.zy : wall_point.xy;
	if (abs(wall_normal.y) > 0.5) {
		face = wall_point.xz;
	}
	vec2 grid = face / vec2(1.55, 0.64);
	grid.x += 0.5 * mod(floor(grid.y), 2.0);
	vec2 brick = floor(grid);
	float firing = fract(sin(dot(brick, vec2(37.1, 17.3))) * 1535.76);
	vec2 border = min(fract(grid), 1.0 - fract(grid)) * vec2(1.55, 0.64);
	float edge = min(border.x, border.y);
	float aa = max(fwidth(edge), 0.005);
	float clay = smoothstep(0.012 - aa, 0.032 + aa, edge);
	float bevel = (1.0 - smoothstep(0.04, 0.085 + aa, edge)) * clay;
	vec3 biscuit = mix(vec3(0.21, 0.132, 0.110), vec3(0.345, 0.224, 0.163), firing);
	float soot = 1.0 - smoothstep(-2.8, 0.8, wall_point.y + 0.23 * sin(face.x * 1.3));
	ALBEDO = mix(vec3(0.083, 0.054, 0.051), biscuit * (1.0 - soot * 0.43), clay) + bevel * 0.035;
	ROUGHNESS = 0.87;
}
