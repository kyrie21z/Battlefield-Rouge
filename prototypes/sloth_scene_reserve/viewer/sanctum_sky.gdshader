shader_type sky;
render_mode use_debanding;

void sky(){
    float h=max(EYEDIR.y,0.0);
    vec3 horizon=vec3(0.48,0.62,0.72);
    vec3 zenith=vec3(0.065,0.18,0.32);
    vec3 c=mix(horizon,zenith,pow(h,0.52));
    vec3 sun_dir=normalize(vec3(-0.6,0.42,-0.55));
    float sun=max(dot(EYEDIR,sun_dir),0.0);
    c+=vec3(1.0,0.80,0.52)*pow(sun,12.0)*0.12;
    c=mix(c,vec3(1.5,1.25,0.85),smoothstep(0.9996,0.99985,sun));
    if(EYEDIR.y<0.0){c=mix(horizon,vec3(0.32,0.43,0.54),min(-EYEDIR.y,1.0));}
    COLOR=c;
}
