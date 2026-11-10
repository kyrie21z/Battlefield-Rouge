shader_type spatial;
render_mode cull_disabled;
uniform vec4 water_color : source_color = vec4(0.015, 0.10, 0.15, 1.0);
uniform float clock = 0.0;
uniform vec3 ripples[8];
varying vec3 world_pos;
void vertex() { world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
 float wave = sin(world_pos.x * 2.3 + clock * 0.9) * cos(world_pos.z * 1.7 - clock * 0.7);
 float rings = 0.0;
 for (int i=0;i<8;i++) {
  float age = clock - ripples[i].z;
  float d = distance(world_pos.xz, ripples[i].xy);
  if (age >= 0.0 && age < 2.0) rings += exp(-pow((d - age * 2.3) * 7.0, 2.0)) * (1.0-age/2.0);
 }
 ALBEDO = water_color.rgb + vec3(0.05,0.16,0.20) * rings + wave * 0.007;
 METALLIC = 0.7; ROUGHNESS = 0.10; SPECULAR = 0.85;
 NORMAL_MAP = vec3(0.5 + wave * 0.05, 0.5 + sin(world_pos.z * 1.4+clock) * 0.05, 1.0);
 EMISSION = vec3(0.08,0.27,0.33) * rings * 0.25;
}
