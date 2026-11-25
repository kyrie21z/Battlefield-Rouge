shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform vec4 stone_color : source_color = vec4(0.8,0.8,0.75,1.0);
uniform bool weathered = false;
varying vec3 world_pos;
varying vec3 world_normal;

float block_tone(vec2 cell) {
    return fract(sin(dot(cell, vec2(27.17, 64.31))) * 43758.5453);
}

void vertex() {
    world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
    float h = smoothstep(-14.0, 40.0, world_pos.y);
    vec3 base = stone_color.rgb * mix(vec3(0.76,0.84,0.91), vec3(1.0,0.98,0.93), h);
    if (weathered) {
        vec3 axis = abs(world_normal);
        vec2 point = axis.y > 0.66 ? world_pos.xz : (axis.x > axis.z ? world_pos.zy : world_pos.xy);
        vec2 course = point / vec2(2.16, 1.19);
        course.x += floor(course.y) * 0.5;
        vec2 local = min(fract(course), 1.0 - fract(course));
        float joint = min(local.x * 2.16, local.y * 1.19);
        float width = max(fwidth(joint), 0.008);
        float weight = 1.0 - smoothstep(42.0, 108.0, distance(CAMERA_POSITION_WORLD, world_pos));
        float grout = (1.0 - smoothstep(0.015, 0.030 + width, joint)) * min(1.0, 0.028 / width);
        float layers = sin(point.x * 2.21 - point.y * 4.82 + sin(point.x * 1.04) * 1.3);
        float veins = 0.036 * (layers * 0.75 + sin(point.y * 2.5 + point.x * 6.0) * 0.25);
        float block = mix(0.91, 1.025, block_tone(floor(course)));
        base *= mix(1.0, block + veins - grout * 0.30, weight);
    }
    ALBEDO = base;
    ROUGHNESS = 0.84;
}
