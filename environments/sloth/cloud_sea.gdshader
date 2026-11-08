shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque, fog_disabled;
uniform sampler2D cloud_noise : filter_linear_mipmap, repeat_enable;
uniform vec3 shadow_color : source_color = vec3(0.22, 0.33, 0.43);
uniform vec3 light_color : source_color = vec3(0.75, 0.78, 0.78);
varying vec3 world_pos;
void vertex(){world_pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
    // A shallow ray-marched cloud band avoids hard polygon silhouettes.
    // Seeded engine noise is shared by every pixel and remains completely still.
    vec3 ray=normalize(world_pos-CAMERA_POSITION_WORLD);
    float down=max(-ray.y,0.008);
    float start=max((CAMERA_POSITION_WORLD.y+21.0)/down,0.0);
    float stride=40.0/down/24.0;
    float jitter=texture(cloud_noise,world_pos.xz*0.0467).r;
    vec3 accumulated=vec3(0.0);
    float transmittance=1.0;
    for(int i=0;i<24;i++){
        vec3 p=CAMERA_POSITION_WORLD+ray*(start+(float(i)+jitter)*stride);
        vec2 uv=p.xz*0.0014+vec2(p.y*0.0015,p.y*0.001);
        float n=texture(cloud_noise,uv).r*0.76+texture(cloud_noise,uv*2.34).r*0.24;
        float height=-65.0+n*64.0;
        float density=smoothstep(0.0,9.0,height-p.y)*0.17;
        float alpha=1.0-exp(-density*min(stride,28.0));
        float shade=clamp((p.y+54.0)/30.0,0.0,1.0);
        vec3 lit=mix(shadow_color,light_color,shade);
        accumulated+=transmittance*alpha*lit;
        transmittance*=1.0-alpha;
        if(transmittance<0.015){break;}
    }
    vec3 c=accumulated+transmittance*shadow_color;
    float distance_fade=smoothstep(350.0,1600.0,start);
    ALBEDO=mix(c,vec3(0.48,0.62,0.72),distance_fade);
}
