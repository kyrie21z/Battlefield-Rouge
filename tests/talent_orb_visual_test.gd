extends Node3D
## Behaviour + optics test for the faceted-obsidian TalentOrb. Runs headless:
##   godot --headless --path . res://tests/talent_orb_visual_test.tscn
## Verifies the generated GLB contract, the shader wiring, four-realm accents,
## the deterministic scatter / assemble schedule (AC-07), the floor-relative
## ground halo, the claim-time teardown and pause behaviour.

var checks := 0
var failures := 0
var _shell_targets: Array[Transform3D] = []


func check(label: String, ok: bool) -> void:
	checks += 1
	print("%s %s" % ["PASS" if ok else "FAIL", label])
	if not ok:
		failures += 1


func frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func physics_frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _ready() -> void:
	await run()
	for child in get_children():
		child.queue_free()
	await get_tree().process_frame
	OS.delay_msec(250)
	await get_tree().process_frame
	print("TALENT ORB VISUAL: %s (%d checks, %d failures)" % ["ALL PASSED" if failures == 0 else "FAIL", checks, failures])
	get_tree().quit(0 if failures == 0 else 1)


func run() -> void:
	await test_models()
	await test_wiring()
	await test_accents()
	await test_scatter_schedule()
	await test_rng_isolation()
	await test_ground_halo()
	await test_collision_teardown()
	await test_pause()


func _spawn() -> TalentOrb:
	var orb := TalentOrb.new()
	add_child(orb)
	return orb


func _bounds(nodes: Array[MeshInstance3D]) -> AABB:
	var box := AABB()
	for index in nodes.size():
		var piece: AABB = nodes[index].transform * nodes[index].get_aabb()
		box = piece if index == 0 else box.merge(piece)
	return box


func _reach(box: AABB) -> float:
	return maxf(maxf(absf(box.position.x), absf(box.position.y)), maxf(absf(box.position.z),
		maxf(maxf(absf(box.end.x), absf(box.end.y)), absf(box.end.z))))


func test_models() -> void:
	var orb := _spawn()
	await frames(2)
	check("shell GLB carries 56-76 independent obsidian pieces", orb._shell_meshes.size() >= 56 and orb._shell_meshes.size() <= 76)
	check("core GLB carries the gem, the heart and six bladelets", orb._core_meshes.size() == 8)
	var names: Array[String] = []
	for mi in orb._shell_meshes:
		names.append(mi.name)
	var required: Array[String] = ["SHELL_backcap"]
	for index in 4:
		required.append("SHELL_under_%d" % index)
	for index in 8:
		required.append("SHELL_band_%d" % index)
		required.append("SHELL_lip_%d" % index)
		required.append("SHROUD_%d" % index)
		required.append("INSET_%02d" % index)
		required.append("SHROUD_lamp_%d" % index)
	for column in 8:
		for layer in 3:
			required.append("PLATE_%d_%d" % [column, layer])
	var missing: Array[String] = []
	for piece_name in required:
		if not names.has(piece_name):
			missing.append(piece_name)
	check("every contracted geode piece is present (%d named)" % required.size(), missing.is_empty())
	if not missing.is_empty():
		print("     missing: ", missing)

	var shell := _bounds(orb._shell_meshes)
	check("shell silhouette is a faceted ball of radius 0.50-0.56",
		_reach(shell) >= 0.50 and _reach(shell) <= 0.56)
	check("shell closes behind the core (rear reach >= 0.50 m)", shell.end.z >= 0.50)
	check("shell opens at the mouth instead of wrapping it (front z <= -0.15)", shell.position.z <= -0.15)
	check("shell is wider than it is deep, so the aperture reads from the front",
		shell.size.x > shell.size.z and shell.size.y > shell.size.z)

	var core := _bounds(orb._core_meshes)
	var core_names: Array[String] = []
	for mi in orb._core_meshes:
		core_names.append(mi.name)
	check("core is the contracted cut-crystal gem + heart + six shards",
		core_names.has("CORE_crystal") and core_names.has("CORE_heart")
		and core_names.has("CORE_shard_0") and core_names.has("CORE_shard_5"))
	check("core stays inside a 0.23-0.28 m radius", _reach(core) >= 0.23 and _reach(core) <= 0.28)
	check("core sits on the mouth axis", orb._core.position.is_equal_approx(Vector3(0.0, 0.0, TalentOrb.CORE_FORWARD)))
	orb.queue_free()
	await frames(1)


func test_wiring() -> void:
	var orb := _spawn()
	await frames(2)
	var shell_mat: ShaderMaterial = orb._shell_materials[0]
	check("shell pieces use the talent_orb_shell shader", shell_mat != null
		and shell_mat.shader.resource_path.ends_with("talent_orb_shell.gdshader"))
	check("shell shader is backed by crystal_optics.gdshaderinc",
		shell_mat != null and shell_mat.shader.code.contains("crystal_optics.gdshaderinc"))
	var plate_mat: ShaderMaterial = null
	var inlay_mat: ShaderMaterial = null
	var lamp_mat: ShaderMaterial = null
	for index in orb._shell_meshes.size():
		var piece_name := orb._shell_meshes[index].name
		if piece_name == "PLATE_0_0":
			plate_mat = orb._shell_materials[index]
		elif piece_name == "INSET_00":
			inlay_mat = orb._shell_materials[index]
		elif piece_name.begins_with("SHROUD_lamp_"):
			lamp_mat = orb._shell_materials[index]
	check("shell armour plates keep seam_glow at 0", plate_mat != null
		and is_zero_approx(float(plate_mat.get_shader_parameter("seam_glow"))))
	check("INSET_ inlays carry a realm seam glow", inlay_mat != null
		and is_equal_approx(float(inlay_mat.get_shader_parameter("seam_glow")), TalentOrb.SEAM_GLOW))
	check("SHROUD_lamp_ rods share the inlay seam glow", lamp_mat != null
		and is_equal_approx(float(lamp_mat.get_shader_parameter("seam_glow")), TalentOrb.SEAM_GLOW))
	check("core gem and heart use the psyche cut-crystal shader",
		orb._core_material.shader.resource_path.ends_with("psyche_shard_crystal.gdshader"))
	check("detached bladelets get their own deeper crystal material",
		orb._core_shard_material != null and orb._core_shard_material != orb._core_material
		and orb._core_shard_material.shader == orb._core_material.shader)

	var halo := orb.get_node_or_null("GroundHalo") as MeshInstance3D
	check("GroundHalo is a 2.35 m quad lying flat on the floor", halo != null
		and halo.mesh is QuadMesh and is_equal_approx((halo.mesh as QuadMesh).size.x, TalentOrb.HALO_SIZE)
		and is_equal_approx(halo.rotation.x, -PI * 0.5))
	check("GroundHalo uses the psyche ground sigil shader and casts no shadow", halo != null
		and (halo.material_override as ShaderMaterial).shader.resource_path.ends_with("psyche_shard_halo.gdshader")
		and halo.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)

	var motes := orb.get_node_or_null("Motes") as Node3D
	check("Motes holds eight shadowless splinters on the core material",
		motes != null and motes.get_child_count() == TalentOrb.MOTE_COUNT)
	if motes != null:
		var all_ok := true
		for child in motes.get_children():
			var mote := child as MeshInstance3D
			all_ok = all_ok and mote != null and mote.mesh != null \
				and mote.material_override == orb._core_material \
				and mote.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		check("every mote reuses PsycheShardMesh.splinter_mesh() and the core material", all_ok)
		check("motes orbit around the core", motes.position.is_equal_approx(Vector3(0.0, 0.0, TalentOrb.CORE_FORWARD)))

	var aura := orb.get_node_or_null("AuraLight") as OmniLight3D
	check("AuraLight sits on the mouth axis with a 4 m reach and no shadow",
		aura != null and aura.position.is_equal_approx(Vector3(0.0, 0.0, TalentOrb.CORE_FORWARD))
		and is_equal_approx(aura.omni_range, 4.0) and is_equal_approx(aura.light_energy, 1.05)
		and not aura.shadow_enabled)
	orb.queue_free()
	await frames(1)


func test_accents() -> void:
	var orb := _spawn()
	await frames(2)
	var halo := orb.get_node("GroundHalo") as MeshInstance3D
	var halo_mat := halo.material_override as ShaderMaterial
	var aura := orb.get_node("AuraLight") as OmniLight3D
	var seen: Array[Color] = []
	var profile_match := true
	var not_white := true
	for realm in 4:
		var accent: Color = BoonIdentity.COLORS[realm]
		orb.set_accent(accent)
		var profile := TalentOrb._profile_for_accent(accent)
		var expected: Dictionary = PsycheShardPickup.REALM_PROFILES[realm]
		var base: Color = orb._core_material.get_shader_parameter("base_color")
		seen.append(base)
		if not base.is_equal_approx(profile["core_color"]) \
				or not (profile["core_color"] as Color).is_equal_approx(expected["core_color"]) \
				or not (profile["rim_color"] as Color).is_equal_approx(expected["rim_color"]) \
				or not is_equal_approx(float(profile["emission_strength"]), float(expected["emission_strength"])):
			profile_match = false
		if base.v > 0.95:
			not_white = false
		check("realm %d halo and aura take the boon accent" % realm,
			(halo_mat.get_shader_parameter("halo_color") as Color).is_equal_approx(accent)
			and aura.light_color.is_equal_approx(accent))
	check("accent profile follows the shared psyche shard HSV curve", profile_match)
	check("cut-crystal core never clips to flat white", not_white)
	var distinct := true
	for left in seen.size():
		for right in range(left + 1, seen.size()):
			if seen[left].is_equal_approx(seen[right]):
				distinct = false
	check("all four realms render distinct core crystals", distinct)

	var custom := Color(0.42, 0.86, 0.35)
	orb.set_accent(custom)
	var custom_profile := TalentOrb._profile_for_accent(custom)
	check("a custom accent still gets a saturated custom crystal",
		(orb._core_material.get_shader_parameter("base_color") as Color).is_equal_approx(custom_profile["core_color"])
		and (custom_profile["core_color"] as Color).s > 0.8)
	orb.queue_free()
	await frames(1)


func test_scatter_schedule() -> void:
	var orb := _spawn()
	await frames(2)
	_shell_targets.clear()
	for mi in orb._shell_meshes:
		_shell_targets.append(mi.transform)

	orb.scatter(1.5)
	check("assembly_seconds matches the piece schedule",
		is_equal_approx(orb.assembly_seconds(),
			float(orb._shell_meshes.size()) * TalentOrb.PIECE_STEP + TalentOrb.ASSEMBLE_START + TalentOrb.ASSEMBLE_TIME))
	check("scatter takes every piece and reports the real total",
		orb._pieces.size() == orb._shell_meshes.size() and orb._piece_count == orb._shell_meshes.size())
	var hidden := true
	var hot := true
	for index in orb._shell_meshes.size():
		hidden = hidden and is_equal_approx(orb._shell_meshes[index].transparency, 1.0)
		hot = hot and is_equal_approx(float(orb._shell_materials[index].get_shader_parameter("scatter_glow")), TalentOrb.SCATTER_HEAT)
	check("every shard starts invisible and realm-hot", hidden and hot)
	var reveal := orb.reveal_pieces(0.5)
	check("reveal_pieces reports its own staggered duration",
		is_equal_approx(reveal, float(orb._shell_meshes.size() - 1) * TalentOrb.PIECE_STEP + 0.5))

	orb.assemble(0.12, 0.0)
	# the last piece only starts 1.36 s in (one PIECE_STEP slot each), so the
	# whole formation needs the full staggered window before it is whole again
	await physics_frames(110)
	var home := true
	var cooled := true
	for index in orb._shell_meshes.size():
		var target := _shell_targets[index]
		var live := orb._shell_meshes[index].transform
		home = home and live.origin.is_equal_approx(target.origin) and live.basis.is_equal_approx(target.basis)
		cooled = cooled and is_zero_approx(float(orb._shell_materials[index].get_shader_parameter("scatter_glow")))
	check("assembly flies every shard back to its authored pose", home)
	check("assembly drains the scatter heat to zero", cooled)
	check("assembly stops stepping pieces once it lands", orb._pieces.is_empty())
	orb.queue_free()
	await frames(1)


func test_rng_isolation() -> void:
	seed(246813579)
	var expected: Array[float] = []
	for i in 96:
		expected.append(randf())
	seed(246813579)
	var orb := _spawn()
	await frames(2)
	orb.scatter(1.2)
	orb.reveal_pieces()
	orb.assemble(0.4, 0.0)
	await frames(6)
	var actual: Array[float] = []
	for i in 96:
		actual.append(randf())
	var identical := true
	for i in expected.size():
		if not is_equal_approx(expected[i], actual[i]):
			identical = false
			break
	check("scatter, reveal and assemble consume zero gameplay RNG (AC-07)", identical)
	orb.queue_free()
	await frames(1)


func test_ground_halo() -> void:
	var orb := _spawn()
	await frames(2)
	var halo := orb.get_node("GroundHalo") as MeshInstance3D
	orb.set_idle_enabled(false)
	orb.set_ground_height(0.35)
	orb.position = Vector3(0.0, 2.4, 0.0)
	await frames(2)
	check("GroundHalo is re-pinned 3 cm over the real floor, not the rig",
		is_equal_approx(halo.position.y, 0.35 - 2.4 + 0.03))
	check("hover_height still stacks base_height on the floor", is_equal_approx(orb.hover_height(), 0.35 + orb.base_height))

	orb.set_idle_enabled(true)
	await physics_frames(8)
	check("bobbing never lifts the ground ring off the floor",
		is_equal_approx(orb.position.y + halo.position.y, 0.35 + 0.03))
	orb.queue_free()
	await frames(1)


func test_collision_teardown() -> void:
	var orb := _spawn()
	await frames(2)
	var halo := orb.get_node("GroundHalo") as MeshInstance3D
	var aura := orb.get_node("AuraLight") as OmniLight3D
	var body := orb.get_node_or_null("Body") as StaticBody3D
	check("orb has a solid WORLD body sized under the interact range", body != null
		and body.collision_layer == CollisionLayers.WORLD
		and ((body.get_child(0) as CollisionShape3D).shape as SphereShape3D).radius < TalentOrb.INTERACT_RANGE)
	orb.set_collision_enabled(false)
	check("claiming turns the body off and takes the floor ring with it",
		body.collision_layer == CollisionLayers.NONE and not halo.visible and not aura.visible)
	orb.set_collision_enabled(true)
	check("re-enabling collision restores the body and the floor ring",
		body.collision_layer == CollisionLayers.WORLD and halo.visible and aura.visible)

	orb.set_core_visible(false)
	check("hiding the core hides the motes and the aura",
		not orb._core.visible and not orb._mote_pivot.visible and not aura.visible)
	orb.set_core_visible(true)
	check("showing the core brings the motes and the aura back",
		orb._core.visible and orb._mote_pivot.visible and aura.visible)

	orb.set_energy(0.4)
	var dimmed := true
	for mi in orb._shell_meshes:
		dimmed = dimmed and is_equal_approx(mi.transparency, 0.6)
	check("set_energy dims shell, core, motes and the energy_scale uniform", dimmed
		and is_equal_approx(orb._core_meshes[0].transparency, 0.6)
		and is_equal_approx(orb._motes[0].transparency, 0.6)
		and is_equal_approx(float(orb._shell_materials[0].get_shader_parameter("energy_scale")), 0.4)
		and is_equal_approx(aura.light_energy, 1.05 * 0.4))
	orb.queue_free()
	await frames(1)


func test_pause() -> void:
	var always_parent := Node3D.new()
	always_parent.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(always_parent)
	var orb := TalentOrb.new()
	always_parent.add_child(orb)
	await frames(2)
	check("orb stays pausable so the tree freezes it", orb.process_mode == Node.PROCESS_MODE_PAUSABLE)
	var material: ShaderMaterial = orb._shell_materials[0]
	var mote := orb._motes[0]
	var before: float = material.get_shader_parameter("pulse_time")
	var before_mote := mote.position
	await frames(5)
	check("sim-clock pulse and mote orbit advance through _process",
		float(material.get_shader_parameter("pulse_time")) > before
		and not mote.position.is_equal_approx(before_mote))

	get_tree().paused = true
	await frames(2)
	var frozen: float = material.get_shader_parameter("pulse_time")
	var frozen_mote := mote.position
	await frames(5)
	check("pausing freezes the orb even under an ALWAYS parent",
		is_equal_approx(float(material.get_shader_parameter("pulse_time")), frozen)
		and mote.position.is_equal_approx(frozen_mote))
	get_tree().paused = false
	await frames(3)
	check("unpausing resumes the orb", float(material.get_shader_parameter("pulse_time")) > frozen)
	always_parent.queue_free()
	await frames(1)
