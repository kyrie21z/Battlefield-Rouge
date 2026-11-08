shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform vec4 stone_color : source_color = vec4(0.8,0.8,0.75,1.0);
varying vec3 world_pos;
void vertex(){ world_pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment(){
    float height_tint=smoothstep(-14.0,40.0,world_pos.y);
    ALBEDO=stone_color.rgb*mix(vec3(0.76,0.84,0.91),vec3(1.0,0.98,0.93),height_tint);
    ROUGHNESS=0.84;
}
