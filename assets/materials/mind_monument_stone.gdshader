shader_type spatial;
render_mode depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

// Production Ultra-1 Monument Stone Shader (Control x Elden Ring)
// High-frequency mineral PBR maps + 5-step POM masonry depth + UV-Jacobian carved
// architectural border relief + clean per-slab brittle fractures + obsidian/metal contrast.
uniform bool is_floor = false;
uniform bool carved_frame_enabled = true;
uniform bool court_inlay_enabled = false;
uniform float crack_density : hint_range(0.0, 1.0) = 0.46;

uniform sampler2D micro_normal_tex : hint_normal, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D micro_height_tex : repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D mineral_vein_tex : repeat_enable, filter_linear_mipmap_anisotropic;

uniform vec4 stone_albedo : source_color = vec4(0.79, 0.76, 0.72, 1.0);
uniform vec4 dark_albedo : source_color = vec4(0.08, 0.10, 0.13, 1.0);
uniform vec4 inlay_metal : source_color = vec4(0.72, 0.57, 0.32, 1.0);
uniform vec4 crystal_glint_color : source_color = vec4(1.0, 0.91, 0.76, 1.0);
uniform vec3 sun_direction = vec3(-0.62, 0.27, -0.74);

varying vec3 v_world_pos;
varying vec3 v_world_normal;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

// Sharp piecewise-linear brittle kink (zero smooth sine/wave curves)
float brittle_zigzag(float t, float seed) {
	float i = floor(t);
	float f = fract(t);
	return mix(hash21(vec2(i, seed)) - 0.5, hash21(vec2(i + 1.0, seed)) - 0.5, f);
}

vec2 brittle_crack_seg(vec2 p, vec2 a, vec2 b, float seed, float jaggedness) {
	vec2 ba = b - a;
	float len_ab = max(length(ba), 0.001);
	vec2 dir = ba / len_ab;
	vec2 perp = vec2(-dir.y, dir.x);
	float t = clamp(dot(p - a, dir) / len_ab, 0.0, 1.0);
	float env = clamp(min(t * 4.0, (1.0 - t) * 4.0), 0.0, 1.0);
	float kink = brittle_zigzag(t * 5.0 + seed * 3.1, seed) * 0.65
		+ brittle_zigzag(t * 13.0 - seed * 7.3, seed + 19.7) * 0.27
		+ brittle_zigzag(t * 27.0 + seed * 11.9, seed + 41.3) * 0.08;
	vec2 closest = a + dir * (t * len_ab) + perp * (kink * jaggedness * env);
	return vec2(length(p - closest), t);
}

float eval_relief_height(vec2 p2, vec2 tile_size, bool floor_mode) {
	vec2 tc = p2 / tile_size;
	if (!floor_mode) {
		tc.x += floor(tc.y) * 0.5;
	}
	vec2 f = fract(tc);
	vec2 de = min(f, 1.0 - f) * tile_size;
	float seam_d = min(de.x, de.y);
	float joint_h = smoothstep(0.010, 0.055, seam_d);
	float micro_h = texture(micro_height_tex, p2 * 0.28).r;
	return joint_h * (0.78 + 0.22 * micro_h);
}

void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
	vec3 nw = normalize(v_world_normal);
	vec3 abs_n = abs(nw);

	vec2 p2;
	vec3 t_axis;
	vec3 b_axis;
	if (abs_n.y >= abs_n.x && abs_n.y >= abs_n.z) {
		p2 = v_world_pos.xz;
		t_axis = vec3(1.0, 0.0, 0.0);
		b_axis = vec3(0.0, 0.0, 1.0);
	} else if (abs_n.x >= abs_n.z) {
		p2 = v_world_pos.zy;
		t_axis = vec3(0.0, 0.0, 1.0);
		b_axis = vec3(0.0, 1.0, 0.0);
	} else {
		p2 = v_world_pos.xy;
		t_axis = vec3(1.0, 0.0, 0.0);
		b_axis = vec3(0.0, 1.0, 0.0);
	}

	vec3 v_world = normalize(CAMERA_POSITION_WORLD - v_world_pos);
	float cam_dist = distance(CAMERA_POSITION_WORLD, v_world_pos);
	float detail_fade = 1.0 - smoothstep(28.0, 78.0, cam_dist);

	// Analytic world-space box-face bevels & carved architectural reveal frames
	vec3 dpdx = dFdx(v_world_pos);
	vec3 dpdy = dFdy(v_world_pos);
	vec2 duvdx = dFdx(UV);
	vec2 duvdy = dFdy(UV);
	float det = duvdx.x * duvdy.y - duvdx.y * duvdy.x;

	vec3 bevel_tilt = vec3(0.0);
	float edge_mask = 0.0;
	float panel_recess = 0.0;
	float panel_frame_groove = 0.0;
	float panel_fillet = 0.0;
	vec3 frame_tilt = vec3(0.0);

	if (abs(det) > 1e-6) {
		vec3 dpdU = (dpdx * duvdy.y - dpdy * duvdx.y) / det;
		vec3 dpdV = (dpdy * duvdx.x - dpdx * duvdy.x) / det;
		float lenU = clamp(length(dpdU), 0.05, 80.0);
		float lenV = clamp(length(dpdV), 0.05, 80.0);
		float du_m = min(UV.x, 1.0 - UV.x) * lenU;
		float dv_m = min(UV.y, 1.0 - UV.y) * lenV;
		float edge_m = min(du_m, dv_m);
		float min_face = min(lenU, lenV);

		float bw = min(0.048, min_face * 0.20);
		float wu = 1.0 - smoothstep(0.0, bw, du_m);
		float wv = 1.0 - smoothstep(0.0, bw, dv_m);
		float su = UV.x < 0.5 ? -1.0 : 1.0;
		float sv = UV.y < 0.5 ? -1.0 : 1.0;
		vec3 dirU = normalize(dpdU);
		vec3 dirV = normalize(dpdV);
		bevel_tilt = (dirU * (su * wu) + dirV * (sv * wv)) * 0.58;
		edge_mask = clamp(max(wu, wv), 0.0, 1.0);

		if (carved_frame_enabled && !is_floor && min_face > 0.85) {
			float inset_d = 0.14;
			float groove_d = abs(edge_m - inset_d);
			float aa_g = max(fwidth(edge_m), 0.004);
			panel_frame_groove = 1.0 - smoothstep(0.008, 0.024 + aa_g, groove_d);
			panel_fillet = 1.0 - smoothstep(0.003, 0.011 + aa_g, abs(edge_m - (inset_d + 0.028)));
			panel_recess = smoothstep(inset_d - 0.01, inset_d + 0.03, edge_m);
			float f_slope = (1.0 - smoothstep(0.006, 0.036 + aa_g, groove_d)) * sign(edge_m - inset_d);
			vec3 f_dir = du_m < dv_m ? (dirU * (-su)) : (dirV * (-sv));
			frame_tilt = f_dir * (f_slope * 0.45);
		}
	}

	// 5-step Parallax Occlusion Mapping for masonry seams & micro-relief depth
	vec2 tile_size = is_floor ? vec2(2.8, 2.8) : vec2(2.35, 1.18);
	vec2 v_tan = vec2(dot(v_world, t_axis), dot(v_world, b_axis));
	float v_dot_n = max(abs(dot(v_world, nw)), 0.25);
	vec2 pom_dir = (v_tan / v_dot_n) * (is_floor ? 0.048 : 0.038) * detail_fade;

	vec2 p_pom = p2;
	if (detail_fade > 0.05) {
		float layer_step = 0.20;
		float cur_depth = 0.0;
		vec2 d_uv = pom_dir * layer_step;
		vec2 cur_p = p2;
		float cur_h = eval_relief_height(cur_p, tile_size, is_floor);
		for (int i = 0; i < 5; i++) {
			if (cur_depth >= (1.0 - cur_h)) {
				break;
			}
			cur_p -= d_uv;
			cur_h = eval_relief_height(cur_p, tile_size, is_floor);
			cur_depth += layer_step;
		}
		p_pom = cur_p;
	}

	// Sample 512px seamless multi-frequency PBR mineral maps
	vec2 uv_fine = p_pom * 0.32;
	vec2 uv_micro = p_pom * 1.15;
	vec3 n_map1 = texture(micro_normal_tex, uv_fine).rgb * 2.0 - 1.0;
	vec3 n_map2 = texture(micro_normal_tex, uv_micro).rgb * 2.0 - 1.0;
	vec2 micro_n_xy = (n_map1.xy * 0.65 + n_map2.xy * 0.45) * (is_floor ? 0.42 : 0.56);

	float h_fine = texture(micro_height_tex, uv_fine).r;
	float h_micro = texture(micro_height_tex, uv_micro).r;
	float vein_val = texture(mineral_vein_tex, p_pom * 0.14).r;
	float micro_grain = (h_micro - 0.5) * 0.06;

	// Architectural slabs & recessed mortar joints
	vec2 tc = p_pom / tile_size;
	if (!is_floor) {
		tc.x += floor(tc.y) * 0.5;
	}
	vec2 cell = floor(tc);
	vec2 f = fract(tc);
	vec2 de = min(f, 1.0 - f) * tile_size;
	float seam_d = min(de.x, de.y);
	float aa = max(fwidth(seam_d), 0.0035);
	float groove = 1.0 - smoothstep(0.007, 0.020 + aa, seam_d);
	vec2 seam_dir = de.x < de.y
		? vec2(f.x < 0.5 ? -1.0 : 1.0, 0.0)
		: vec2(0.0, f.y < 0.5 ? -1.0 : 1.0);
	float seam_slope = (1.0 - smoothstep(0.010, 0.052 + aa, seam_d)) * (1.0 - groove);
	float block_var = mix(0.92, 1.06, hash21(cell));
	float chipped_edge = edge_mask * smoothstep(0.62, 0.88, h_fine) * 0.45;

	// Clean, sparse, joint-anchored brittle hairline fractures (zero fuzzy halo / moss)
	float crack_core = 0.0;
	float branch_crack = 0.0;
	float fissure = 0.0;
	float crack_hf = 1.0;

	if (crack_density > 0.01) {
		vec2 local_m = f * tile_size;
		float r0 = hash21(cell + vec2(11.3, 4.7));
		float r1 = hash21(cell + vec2(27.9, 13.1));
		float r2 = hash21(cell + vec2(5.1, 31.7));
		float r3 = hash21(cell + vec2(43.2, 9.4));

		float threshold = 1.0 - clamp(crack_density, 0.0, 0.85);
		float min_d = 9.0;
		float tip_taper = 1.0;
		if (r0 > threshold) {
			vec2 pA;
			vec2 pB;
			if (r1 < 0.28) {
				pA = vec2(0.0, mix(0.24, 0.80, r2) * tile_size.y);
				pB = vec2(mix(0.32, 0.90, r3) * tile_size.x, r2 > 0.5 ? tile_size.y : 0.0);
			} else if (r1 < 0.56) {
				pA = vec2(mix(0.20, 0.80, r2) * tile_size.x, 0.0);
				pB = vec2(tile_size.x, mix(0.25, 0.82, r3) * tile_size.y);
			} else if (r1 < 0.78) {
				float cx = r2 > 0.5 ? 0.0 : tile_size.x;
				float cy = r3 > 0.5 ? 0.0 : tile_size.y;
				pA = vec2(cx, abs(cy - mix(0.28, 0.62, r2) * tile_size.y));
				pB = vec2(abs(cx - mix(0.28, 0.62, r3) * tile_size.x), cy);
			} else {
				pA = vec2(mix(0.22, 0.78, r2) * tile_size.x, r3 > 0.5 ? 0.0 : tile_size.y);
				pB = vec2(mix(0.28, 0.72, r3) * tile_size.x, mix(0.38, 0.68, r2) * tile_size.y);
			}
			float jag = is_floor ? 0.19 : 0.14;
			vec2 seg1 = brittle_crack_seg(local_m, pA, pB, r0 * 53.0 + r1 * 17.0, jag);
			tip_taper = (r1 >= 0.78) ? (1.0 - smoothstep(0.50, 1.0, seg1.y)) : (0.72 + 0.28 * abs(seg1.y * 2.0 - 1.0));
			min_d = seg1.x;

			float fork_gate = mix(threshold, 1.0, 0.62);
			if (r0 > fork_gate) {
				vec2 fork_start = mix(pA, pB, mix(0.35, 0.62, r2));
				vec2 main_dir = normalize(pB - pA);
				float sgn = r3 > 0.5 ? 1.0 : -1.0;
				vec2 fork_dir = normalize(main_dir * 0.68 + vec2(-main_dir.y, main_dir.x) * (0.73 * sgn));
				vec2 fork_end = clamp(fork_start + fork_dir * mix(0.42, 0.95, r1), vec2(0.0), tile_size);
				vec2 seg2 = brittle_crack_seg(local_m, fork_start, fork_end, r2 * 71.0 + 3.7, 0.11);
				float aa_b = max(fwidth(seg2.x), 0.002);
				float b_w = mix(0.0065, 0.0018, seg2.y);
				branch_crack = 1.0 - smoothstep(b_w * 0.35, b_w + aa_b, seg2.x);
				min_d = min(min_d, seg2.x * 1.15);
			}
		}
		float aa_c = max(fwidth(min_d), 0.002);
		float w_core = mix(0.0022, 0.0085, tip_taper);
		crack_core = 1.0 - smoothstep(w_core * 0.35, w_core + aa_c, min_d);
		fissure = clamp(max(crack_core, branch_crack * 0.82), 0.0, 1.0);
		crack_hf = smoothstep(0.0, 0.022, min_d);
	}

	// View-dependent micro-crystal mineral flecks
	vec2 fleck_cell = floor(p_pom * 36.0);
	float fleck_seed = hash21(fleck_cell);
	vec3 fleck_n = normalize(nw + (vec3(hash21(fleck_cell + 1.7), hash21(fleck_cell + 9.3), hash21(fleck_cell + 5.1)) - 0.5) * 0.9);
	float sparkle_spec = pow(max(dot(reflect(-v_world, fleck_n), normalize(sun_direction)), 0.0), 42.0);
	float sparkle = step(0.86, fleck_seed) * sparkle_spec * detail_fade;

	// Architectural floor obsidian runners & geometric arena brass inlays
	float court_obsidian = 0.0;
	float court_brass = 0.0;
	if (is_floor && court_inlay_enabled) {
		court_obsidian = max(
			1.0 - smoothstep(0.08, 0.14, abs(abs(v_world_pos.x) - 5.2)),
			(1.0 - smoothstep(0.05, 0.09, abs(v_world_pos.x))) * 0.95
		);
		float r_center = length(v_world_pos.xz - vec2(0.0, -4.0));
		float court_ring = clamp(
			(1.0 - smoothstep(0.022, 0.048, abs(r_center - 7.5)))
			+ (1.0 - smoothstep(0.018, 0.040, abs(r_center - 11.2))) * 0.8,
			0.0, 1.0
		);
		court_brass = clamp(
			(1.0 - smoothstep(0.014, 0.030, abs(abs(v_world_pos.x) - 5.42)))
			+ (1.0 - smoothstep(0.012, 0.026, abs(abs(v_world_pos.x) - 4.98))) * 0.7
			+ court_ring,
			0.0, 1.0
		);
	}

	float height_grad_y = smoothstep(-2.0, 15.0, v_world_pos.y);
	float vein_band = smoothstep(0.28, 0.78, vein_val);
	vec3 stone_body = stone_albedo.rgb * block_var * mix(0.93, 1.05, vein_band) * (1.0 + micro_grain);

	vec3 albedo;
	float roughness;
	float metallic;
	float specular;
	float clearcoat;
	float clearcoat_rough = 0.08;
	float ao;
	vec3 emission;

	if (is_floor) {
		float worn_polish = smoothstep(0.28, 0.72, vein_val * 0.6 + h_fine * 0.4);
		albedo = stone_body;
		albedo = mix(albedo, dark_albedo.rgb, court_obsidian);
		albedo = mix(albedo, inlay_metal.rgb, court_brass);
		albedo *= (1.0 - groove * 0.46);
		albedo = mix(albedo, dark_albedo.rgb * 0.50, fissure * 0.90);

		roughness = mix(0.70, 0.32, worn_polish);
		roughness = mix(roughness, 0.14, court_obsidian);
		roughness = mix(roughness, 0.24, court_brass);
		roughness = mix(roughness, 0.90, clamp(groove + fissure, 0.0, 1.0));
		metallic = clamp(court_brass * 0.90 + court_obsidian * 0.12, 0.0, 1.0);
		specular = mix(0.54, 0.88, court_obsidian);
		clearcoat = court_obsidian * 0.68 * (1.0 - groove);
		ao = 1.0 - clamp(groove * 0.48 + fissure * 0.55, 0.0, 0.80);
		emission = crystal_glint_color.rgb * sparkle * (0.28 + court_obsidian * 0.6);
	} else {
		vec3 alt_grad = mix(vec3(0.87, 0.90, 0.94), vec3(1.04, 1.02, 0.98), height_grad_y);
		albedo = stone_body * alt_grad;
		albedo *= mix(1.0, 0.95, panel_recess * 0.5);
		albedo = mix(albedo, dark_albedo.rgb * 1.15, panel_frame_groove * 0.65);
		albedo = mix(albedo, inlay_metal.rgb * 0.98, panel_fillet * 0.85);
		albedo = mix(albedo, dark_albedo.rgb * 1.10, groove * 0.54);
		albedo = mix(albedo, albedo * 1.10, edge_mask * (1.0 - chipped_edge) * 0.36);
		albedo = mix(albedo, dark_albedo.rgb * 0.48, fissure * 0.90);

		roughness = mix(0.44, 0.76, 1.0 - vein_band * 0.6 - h_fine * 0.4);
		roughness = mix(roughness, 0.26, panel_fillet * 0.85);
		roughness = mix(roughness, 0.32, edge_mask * (1.0 - chipped_edge) * 0.5);
		roughness = mix(roughness, 0.90, clamp(groove + panel_frame_groove + fissure, 0.0, 1.0));
		metallic = panel_fillet * 0.88;
		specular = 0.52;
		clearcoat = 0.0;
		ao = 1.0 - clamp(groove * 0.48 + panel_frame_groove * 0.48 + fissure * 0.55, 0.0, 0.80);
		emission = crystal_glint_color.rgb * sparkle * 0.22;
	}

	vec3 crack_grad_w = dFdx(crack_hf) * dpdx + dFdy(crack_hf) * dpdy;
	vec3 crack_tilt = clamp(crack_grad_w * 36.0, vec3(-0.32), vec3(0.32));
	bevel_tilt *= mix(1.0, 0.55 + h_fine * 0.75, chipped_edge);

	vec3 surf_tilt = (t_axis * (micro_n_xy.x + seam_dir.x * seam_slope * 0.45)
		+ b_axis * (micro_n_xy.y + seam_dir.y * seam_slope * 0.45)
		+ frame_tilt - crack_tilt) * detail_fade;

	vec3 final_nw = normalize(nw + bevel_tilt + surf_tilt);
	if (dot(final_nw, nw) < 0.22) {
		final_nw = normalize(mix(nw, final_nw, 0.5));
	}
	vec3 view_n = normalize((VIEW_MATRIX * vec4(final_nw, 0.0)).xyz);
	NORMAL = view_n;

	float ndv = clamp(dot(view_n, VIEW), 0.0, 1.0);
	float graz = pow(1.0 - ndv, 3.8);
	emission += crystal_glint_color.rgb * graz * edge_mask * 0.04;

	ALBEDO = albedo;
	ROUGHNESS = clamp(roughness, 0.05, 0.96);
	METALLIC = clamp(metallic, 0.0, 1.0);
	SPECULAR = specular;
	CLEARCOAT = clamp(clearcoat, 0.0, 1.0);
	CLEARCOAT_ROUGHNESS = clearcoat_rough;
	AO = clamp(ao, 0.18, 1.0);
	AO_LIGHT_AFFECT = 0.62;
	EMISSION = emission;
}
