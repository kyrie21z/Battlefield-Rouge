shader_type spatial;
uniform vec4 base_color : source_color = vec4(0.91,0.94,0.97,1.0);
uniform float print_cutoff = -100.0;
uniform float emission_strength = 0.12;
uniform float guard = 0.0;
varying float world_y;
void vertex() { world_y = (MODEL_MATRIX * vec4(VERTEX,1.0)).y; }
void fragment() {
 if (world_y < print_cutoff) discard;
 float band = 1.0-smoothstep(0.0,0.08,abs(world_y-print_cutoff));
 float fresnel = pow(1.0-clamp(dot(NORMAL,VIEW),0.0,1.0),4.0);
 ALBEDO = base_color.rgb; METALLIC = 0.74; ROUGHNESS = 0.055; SPECULAR = 0.85;
 EMISSION = vec3(0.88,0.95,1.0)*(emission_strength+band*4.0+fresnel*(0.12+guard));
}
