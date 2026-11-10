shader_type particles;
render_mode disable_force, disable_velocity;
#include "res://environments/sorrow/rain_layout.gdshaderinc"
uniform float clock = 0.0;
uniform float water_level = 0.14;
mat4 drop_transform(uint index) {
	vec2 cell = vec2(float(index % 25u), float(index / 25u));
	vec2 point = rain_point(cell);
	float phase = rain_phase(cell, clock);
	float height = mix(13.0, water_level, phase / RAIN_FALL);
	// Once a drop reaches water, only its corresponding shader ring remains.
	if (phase >= RAIN_FALL) { height = -1000.0; }
	mat4 result = mat4(1.0);
	result[3] = vec4(point.x, height, point.y, 1.0);
	return result;
}
void start() { TRANSFORM = drop_transform(INDEX); COLOR = vec4(1.0); }
void process() { TRANSFORM = drop_transform(INDEX); }
