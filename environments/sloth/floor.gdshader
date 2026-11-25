shader_type spatial;
render_mode diffuse_burley, specular_disabled;
uniform vec4 stone_color : source_color = vec4(0.51,0.56,0.58,1.0);
uniform bool radial_mode = true;
uniform bool carved_court = false;
varying vec3 world_pos;
varying vec3 world_normal;

// Lines are filtered by their pixel footprint and fade before becoming subpixel.
float filtered_line(float distance_to_line, float half_width) {
    float footprint=max(fwidth(distance_to_line),0.001);
    return (1.0-smoothstep(half_width,half_width+footprint,abs(distance_to_line)))
        *min(1.0,half_width/footprint);
}
void vertex(){
    world_pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
    world_normal=MODEL_NORMAL_MATRIX*NORMAL;
}
void fragment(){
    float seam=0.0;
    float inlay=0.0;
    if(radial_mode){
        float r=length(world_pos.xz);
        float theta=atan(world_pos.x,world_pos.z);
        float angular_distance=abs(fract(theta*48.0/6.2831853+0.5)-0.5)*r*6.2831853/48.0;
        seam=filtered_line(angular_distance,0.045)*smoothstep(14.4,15.8,r);
        float ring_distance=min(min(abs(r-14.5),abs(r-24.0)),min(abs(r-39.8),abs(r-44.5)));
        inlay=filtered_line(ring_distance,0.07);
    }else{
        float joint_distance=abs(mod(world_pos.z,4.0)-2.0);
        seam=filtered_line(joint_distance,0.045);
        inlay=filtered_line(abs(world_pos.x)-6.2,0.065);
    }
    float top=smoothstep(0.8,0.98,world_normal.y);
    float fade=1.0-smoothstep(50.0,135.0,distance(CAMERA_POSITION_WORLD,world_pos));
    vec3 base=stone_color.rgb*vec3(0.91,0.94,0.96);
    base=mix(base,vec3(0.19,0.25,0.29),seam*top*fade*0.6);
    base=mix(base,vec3(0.34,0.27,0.17),inlay*top*fade*0.7);
    if (carved_court) {
        vec2 p = world_pos.xz;
        float path = 1.0 - smoothstep(3.0, 3.12, abs(p.x));
        vec2 tile = p / vec2(2.42, 3.12);
        tile.x += floor(tile.y) * 0.5;
        vec2 joints = min(fract(tile), 1.0 - fract(tile)) * vec2(2.42, 3.12);
        float course = filtered_line(min(joints.x, joints.y), 0.034) * fade;
        float grain = sin(p.x * 6.15 + p.y * 9.79 + sin(p.y * 2.0)) * 0.012;
        float warm_thread = filtered_line(abs(p.x) - 3.45, 0.043);
        warm_thread += filtered_line(abs(p.x) - 3.59, 0.022);
        vec2 local = vec2(p.x, mod(p.y + 5.7, 10.4) - 5.2);
        float r = length(local);
        float plate = filtered_line(r - 1.24, 0.040);
        float ticks = filtered_line(r - 1.53, 0.064)
            * step(0.82, cos(atan(local.x, local.y + 0.00001) * 24.0));
        base *= 1.0 + top * (grain - course * 0.23 + path * 0.064);
        base = mix(base, vec3(0.36, 0.28, 0.17), clamp(warm_thread + plate + ticks, 0.0, 1.0) * top * fade * 0.39);
    }
    ALBEDO=base;
    ROUGHNESS=0.92;
}
