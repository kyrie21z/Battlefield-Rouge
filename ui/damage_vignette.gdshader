shader_type canvas_item;
// Red edge vignette for taking damage. The centre stays clear so the player
// keeps aiming through it; the ColorRect's colour alpha is the intensity.

uniform vec3 tint : source_color = vec3(0.72, 0.03, 0.02);
// 0 = screen centre, 1 = edge midpoints (corners reach ~1.41).
uniform float clear_radius : hint_range(0.0, 1.2) = 0.35;
uniform float edge_radius : hint_range(0.0, 1.6) = 0.95;
// Leaves a little of the scene visible even at the strongest hit.
uniform float max_strength : hint_range(0.0, 1.0) = 0.9;

void fragment() {
	vec2 from_centre = UV - vec2(0.5);
	float distance = length(from_centre) * 2.0;
	float mask = smoothstep(clear_radius, edge_radius, distance) * max_strength;
	COLOR = vec4(tint, COLOR.a * mask);
}
