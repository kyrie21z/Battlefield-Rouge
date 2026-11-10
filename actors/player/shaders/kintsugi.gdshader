shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform vec4 accent : source_color = vec4(1.0,0.62,0.12,1.0);
uniform float seam_width=0.0010;
uniform float restored=1.0;
varying vec3 distances;
varying flat int edges;
void vertex(){distances=CUSTOM0.xyz;edges=int(CUSTOM0.w+0.5);}
void fragment(){
	float d=100.0;
	if((edges&1)!=0){d=min(d,distances.x);}
	if((edges&2)!=0){d=min(d,distances.y);}
	if((edges&4)!=0){d=min(d,distances.z);}
	float seam=(1.0-smoothstep(seam_width,seam_width+max(fwidth(d),0.00006),d))*restored;
	ALBEDO=mix(vec3(0.8,0.81,0.83),vec3(0.24,0.13,0.035),seam);
	METALLIC=seam*0.85;
	ROUGHNESS=mix(0.26,0.2,seam);
	SPECULAR=0.55;
	EMISSION=vec3(0.025)+seam*(vec3(0.2,0.1,0.02)+accent.rgb*0.16);
}
