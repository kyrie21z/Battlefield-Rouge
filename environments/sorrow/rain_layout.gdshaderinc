// Shared by GPU drops and water normals: a drop and its ring have the same
// basin-space cell, phase and impact time. No TIME or gameplay RNG is consumed.
const float RAIN_CELL = 1.58;
const vec2 RAIN_MIN = vec2(-19.75, -23.7);
const vec2 RAIN_GRID = vec2(25.0, 30.0);
const float RAIN_FALL = 1.45;
const float RAIN_RING = 0.85;
const float RAIN_PERIOD = RAIN_FALL + RAIN_RING;
float rain_hash(vec2 cell) {
	return fract(sin(dot(cell, vec2(127.1, 311.7))) * 43758.5453);
}
vec2 rain_point(vec2 cell) {
	return RAIN_MIN + (cell + vec2(0.18) + vec2(rain_hash(cell), rain_hash(cell + 19.7)) * 0.64) * RAIN_CELL;
}
float rain_phase(vec2 cell, float clock) {
	return mod(clock + rain_hash(cell + 7.3) * RAIN_PERIOD, RAIN_PERIOD);
}
