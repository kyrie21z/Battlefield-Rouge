shader_type spatial;
render_mode world_vertex_coords, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// Original white-crystal lighting. Fractures follow authored facet joints and
// are black at every level; the body is never tinted by narrative progression.
uniform vec4 base_color : source_color = vec4(0.8, 0.81, 0.83, 1.0);
uniform vec4 emission_color : source_color = vec4(0.3, 0.31, 0.33, 1.0);
uniform float emission_strength = 0.2;
uniform vec4 rim_color : source_color = vec4(0.92, 0.95, 1.0, 1.0);
uniform float rim_strength = 0.45;
uniform float rim_power = 2.6;
uniform vec4 spec_color : source_color = vec4(1.0);
uniform float specular_amount = 0.5;
uniform float roughness_value = 0.22;
uniform float inner_glow = 0.1;
uniform int fracture_level : hint_range(0, 4) = 0;
uniform int body_part = 0; // 1 left forearm, 2 torso, 3 other arm, 0 remaining body.
uniform mat4 rest_from_world;
uniform vec3 wrist_position = vec3(-0.680741, 1.5629, 0.051034);
varying vec3 rest_position;
varying vec3 facet_distances;
varying flat int facet_mask;

void vertex() {
	// Forward+ skins before vertex(). Pose inverse maps world coordinates back
	// to anatomy; CUSTOM0 remains attached to the original triangle vertices.
	rest_position = (rest_from_world * vec4(VERTEX, 1.0)).xyz;
	facet_distances = CUSTOM0.xyz;
	facet_mask = int(CUSTOM0.w + 0.5);
	if (fracture_level >= 3 && body_part == 2) {
		// The asset has ONE torso shard. Offset selected original flat facets,
		// without fabricating chest pieces or changing the source triangulation.
		vec3 n = normalize(mat3(rest_from_world) * NORMAL);
		float chosen = step(0.48, n.x);
		VERTEX += NORMAL * chosen * (fracture_level == 3 ? 0.0017 : 0.0030);
	}
}

void fragment() {
	float ndv = clamp(dot(normalize(NORMAL), VIEW), 0.0, 1.0);
	float fresnel = pow(1.0 - ndv, rim_power);
	vec3 original_emission = emission_color.rgb * emission_strength
		+ rim_color.rgb * fresnel * rim_strength
		+ base_color.rgb * pow(ndv, 1.5) * inner_glow
		+ spec_color.rgb * fresnel * 0.2;
	float region = 0.0;
	if (fracture_level == 1 && body_part == 1) {
		region = 1.0 - smoothstep(0.065, 0.095, distance(rest_position, wrist_position));
	}
	if (fracture_level == 2) {
		if (body_part == 1) {
			region = 1.0 - smoothstep(wrist_position.x + 0.05, wrist_position.x + 0.13, rest_position.x);
		}
		if (body_part == 2) { region = smoothstep(1.32, 1.43, rest_position.y); }
	}
	if (fracture_level == 3 && body_part > 0) { region = 1.0; }
	if (fracture_level >= 4) { region = 1.0; }
	float d = 100.0;
	if ((facet_mask & 1) != 0) { d = min(d, facet_distances.x); }
	if ((facet_mask & 2) != 0) { d = min(d, facet_distances.y); }
	if ((facet_mask & 4) != 0) { d = min(d, facet_distances.z); }
	float width = fracture_level == 1 ? 0.00025 : (fracture_level == 2 ? 0.00040 : (fracture_level == 3 ? 0.00065 : 0.00090));
	float aa = max(fwidth(d) * 0.5, 0.00005);
	float seam = (1.0 - smoothstep(width, width + aa, d)) * region;
	ALBEDO = mix(base_color.rgb, vec3(0.006), seam);
	ROUGHNESS = mix(roughness_value, 0.82, seam);
	SPECULAR = mix(specular_amount, 0.08, seam);
	METALLIC = 0.0;
	EMISSION = original_emission * (1.0 - seam);
}
