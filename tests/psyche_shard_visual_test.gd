extends Node3D
## Behaviour + optics test for PsycheShardPickup. Runs headless:
##   godot --headless --path . res://tests/psyche_shard_visual_test.tscn
## Verifies the public API, the crystal/halo shader wiring, pause freezing,
## deterministic RNG (AC-07) and the physical pickup contract.

var checks := 0
var failures := 0
var player: Player


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
	print("PSYCHE SHARD VISUAL: %s (%d checks, %d failures)" % ["ALL PASSED" if failures == 0 else "FAIL", checks, failures])
	get_tree().quit(0 if failures == 0 else 1)


func run() -> void:
	check("four titles and four realm profiles are shared data", PsycheShardPickup.TITLES.size() == 4 and PsycheShardPickup.REALM_PROFILES.size() == 4)
	test_mesh_winding()
	await test_instantiation()
	await test_rng_isolation()
	await test_animation_and_pause()
	await test_pickup_behaviour()


func test_mesh_winding() -> void:
	var meshes: Dictionary = {
		"core": PsycheShardMesh.core_mesh(),
		"blade0": PsycheShardMesh.mantle_blade_mesh(0),
		"blade1": PsycheShardMesh.mantle_blade_mesh(1),
		"blade2": PsycheShardMesh.mantle_blade_mesh(2),
		"splinter": PsycheShardMesh.splinter_mesh(),
		"bezel": PsycheShardMesh.base_ring_mesh(),
	}
	var total_tris := 0
	var all_front := true
	for label: String in meshes:
		var mesh := meshes[label] as ArrayMesh
		var arrays := mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		for i in range(0, vertices.size(), 3):
			total_tris += 1
			var cw_front := (vertices[i + 2] - vertices[i]).cross(vertices[i + 1] - vertices[i]).normalized()
			if cw_front.dot(normals[i]) < 0.99 or cw_front.dot(normals[i + 1]) < 0.99 or cw_front.dot(normals[i + 2]) < 0.99:
				all_front = false
	check("all six crystal meshes use front-facing clockwise winding aligned with outward normals", total_tris > 0 and all_front)


func _nodes_of(shard: PsycheShardPickup) -> Dictionary:
	return {
		"visual": shard.get_node_or_null("VisualRoot") as Node3D,
		"core": shard.get_node_or_null("VisualRoot/CoreMesh") as MeshInstance3D,
		"mantle": shard.get_node_or_null("VisualRoot/MantlePivot") as Node3D,
		"splinters": shard.get_node_or_null("VisualRoot/SplinterPivot") as Node3D,
		"halo": shard.get_node_or_null("GroundHalo") as MeshInstance3D,
		"ring": shard.get_node_or_null("BaseRing") as MeshInstance3D,
		"light": shard.get_node_or_null("AuraLight") as OmniLight3D,
		"label": shard.get_node_or_null("Label3D") as Label3D,
	}


func _assert_optics(shard: PsycheShardPickup, realm: int, source: String) -> void:
	var nodes := _nodes_of(shard)
	var built := nodes["visual"] != null and nodes["core"] != null and nodes["mantle"] != null \
		and nodes["splinters"] != null and nodes["halo"] != null and nodes["ring"] != null \
		and nodes["light"] != null and nodes["label"] != null
	check("realm %d %s builds the full crystal hierarchy" % [realm, source], built)
	if not built:
		return
	check("realm %d %s carries four mantle blades and six splinters" % [realm, source],
		nodes["mantle"].get_child_count() == 4 and nodes["splinters"].get_child_count() == 6)
	check("realm %d %s has physical meshes for core, halo and base ring" % [realm, source],
		nodes["core"].mesh is ArrayMesh and nodes["halo"].mesh is QuadMesh and nodes["ring"].mesh is ArrayMesh)

	var core_material := nodes["core"].material_override as ShaderMaterial
	var halo_material := nodes["halo"].material_override as ShaderMaterial
	var mantle_material := (nodes["mantle"].get_child(0) as MeshInstance3D).material_override as ShaderMaterial
	check("realm %d %s core and mantle use the psyche cut-crystal shader" % [realm, source],
		core_material != null and mantle_material != null \
		and core_material.shader.resource_path.ends_with("psyche_shard_crystal.gdshader") \
		and mantle_material.shader.resource_path.ends_with("psyche_shard_crystal.gdshader"))
	check("realm %d %s crystal shader is backed by crystal_optics.gdshaderinc" % [realm, source],
		core_material != null and core_material.shader.code.contains("crystal_optics.gdshaderinc"))
	check("realm %d %s halo uses the procedural ground sigil shader" % [realm, source],
		halo_material != null and halo_material.shader.resource_path.ends_with("psyche_shard_halo.gdshader"))

	var profile: Dictionary = PsycheShardPickup.REALM_PROFILES[realm]
	var tint: Color = BoonIdentity.COLORS[realm]
	var halo_color: Color = halo_material.get_shader_parameter("halo_color")
	var core_color: Color = core_material.get_shader_parameter("base_color")
	var aura_color: Color = nodes["light"].light_color
	check("realm %d %s halo matches the boon palette" % [realm, source], halo_color.is_equal_approx(tint))
	check("realm %d %s core uses the bright realm profile" % [realm, source],
		core_color.is_equal_approx(profile["core_color"]))
	check("realm %d %s aura light is realm tinted" % [realm, source], aura_color.is_equal_approx(tint))
	check("realm %d %s label reads its title and prompt" % [realm, source],
		nodes["label"].text.begins_with(PsycheShardPickup.TITLES[realm]) and nodes["label"].text.contains("走近拾取"))
	check("realm %d %s aura range and label pixel size stay readable" % [realm, source],
		nodes["light"].omni_range >= 4.0 and nodes["label"].pixel_size > 0.0)


func test_instantiation() -> void:
	var scene := load("res://zone/psyche_shard_pickup.tscn") as PackedScene
	check("pickup scene and script both load", scene != null)
	var seen: Array[Color] = []
	for realm in 4:
		var from_scene := scene.instantiate() as PsycheShardPickup
		from_scene.realm = realm
		from_scene.position = Vector3(float(realm) * 3.0, 0.0, 0.0)
		add_child(from_scene)
		await get_tree().process_frame
		_assert_optics(from_scene, realm, "scene")
		var scene_halo := from_scene.get_node("GroundHalo") as MeshInstance3D
		var halo_material := scene_halo.material_override as ShaderMaterial
		seen.append(halo_material.get_shader_parameter("halo_color"))

		var from_script := PsycheShardPickup.new()
		from_script.realm = realm
		from_script.position = Vector3(float(realm) * 3.0, 0.0, 6.0)
		add_child(from_script)
		await get_tree().process_frame
		_assert_optics(from_script, realm, "new()")
		from_script.queue_free()
		from_scene.queue_free()
	await get_tree().process_frame

	var distinct := true
	for left in seen.size():
		for right in range(left + 1, seen.size()):
			if seen[left].is_equal_approx(seen[right]):
				distinct = false
	check("all four realms render distinct palette colors", distinct)

	var live := PsycheShardPickup.new()
	add_child(live)
	await get_tree().process_frame
	check("default pickup radius and realm stay compatible", live.realm == 0 and is_equal_approx(live.pickup_radius, 1.3) and not live.consumed)
	check("collected signal keeps its realm argument", live.has_signal("collected"))
	live.realm = 2
	var live_core := live.get_node("VisualRoot/CoreMesh") as MeshInstance3D
	var core_material := live_core.material_override as ShaderMaterial
	var label := live.get_node("Label3D") as Label3D
	var light := live.get_node("AuraLight") as OmniLight3D
	var core_base: Color = core_material.get_shader_parameter("base_color")
	check("runtime realm change rewrites the label", label.text.begins_with(PsycheShardPickup.TITLES[2]))
	check("runtime realm change rewrites core optics",
		core_base.is_equal_approx(PsycheShardPickup.REALM_PROFILES[2]["core_color"]))
	check("runtime realm change retints the aura", light.light_color.is_equal_approx(BoonIdentity.COLORS[2]))
	var halo := live.get_node("GroundHalo") as MeshInstance3D
	live.pickup_radius = 2.6
	check("runtime pickup_radius update resizes ground halo", is_equal_approx((halo.mesh as QuadMesh).size.x, 2.6 * 2.15))
	live._proximity = 0.75
	live._push_motion_uniforms()
	live.pickup_radius = 0.0
	check("non-positive pickup_radius hides ground halo and clears proximity boost",
		not halo.visible and is_zero_approx(float(core_material.get_shader_parameter("proximity_boost"))))
	live.queue_free()
	await get_tree().process_frame


func test_rng_isolation() -> void:
	seed(987654321)
	var expected: Array[float] = []
	for i in 96:
		expected.append(randf())
	seed(987654321)
	var shards: Array[PsycheShardPickup] = []
	for realm in 4:
		var shard := PsycheShardPickup.new()
		shard.realm = realm
		shard.position = Vector3(float(realm) * 2.5, 0.0, 0.0)
		add_child(shard)
		shards.append(shard)
	await frames(3)
	var actual: Array[float] = []
	for i in 96:
		actual.append(randf())
	var identical := true
	for i in expected.size():
		if not is_equal_approx(expected[i], actual[i]):
			identical = false
			break
	check("instantiating and stepping four shards consumes zero gameplay RNG", identical)
	for shard in shards:
		shard.queue_free()
	await get_tree().process_frame


func test_animation_and_pause() -> void:
	var always_parent := Node3D.new()
	always_parent.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(always_parent)
	var shard := PsycheShardPickup.new()
	always_parent.add_child(shard)
	await get_tree().process_frame
	var shard_core := shard.get_node("VisualRoot/CoreMesh") as MeshInstance3D
	var material := shard_core.material_override as ShaderMaterial
	var visual := shard.get_node("VisualRoot") as Node3D
	var before_pulse: float = material.get_shader_parameter("pulse_time")
	var before_turn := visual.rotation.y
	await frames(4)
	var after_pulse: float = material.get_shader_parameter("pulse_time")
	var after_turn := visual.rotation.y
	check("visual animation advances through _process", after_pulse > before_pulse and not is_equal_approx(after_turn, before_turn))

	get_tree().paused = true
	await frames(2)
	var frozen_pulse: float = material.get_shader_parameter("pulse_time")
	var frozen_turn := visual.rotation.y
	await frames(4)
	check("paused tree freezes the crystal pulse and motion even under an ALWAYS parent",
		is_equal_approx(material.get_shader_parameter("pulse_time"), frozen_pulse)
		and is_equal_approx(visual.rotation.y, frozen_turn))
	get_tree().paused = false
	await frames(2)
	check("unpausing resumes the shard animation",
		float(material.get_shader_parameter("pulse_time")) > frozen_pulse)
	always_parent.queue_free()
	await get_tree().process_frame


func test_pickup_behaviour() -> void:
	var ground := StaticBody3D.new()
	ground.position = Vector3(0.0, -0.5, 0.0)
	ground.collision_layer = CollisionLayers.WORLD
	var ground_shape := CollisionShape3D.new()
	var ground_box := BoxShape3D.new()
	ground_box.size = Vector3(50.0, 1.0, 50.0)
	ground_shape.shape = ground_box
	ground.add_child(ground_shape)
	add_child(ground)

	player = preload("res://actors/player/player.tscn").instantiate() as Player
	add_child(player)
	await physics_frames(6)

	CrystalBurst.prepare(self)
	await frames(6)

	var scene := load("res://zone/psyche_shard_pickup.tscn") as PackedScene

	var distant := scene.instantiate() as PsycheShardPickup
	distant.realm = 1
	distant.position = Vector3(4.0, 0.0, 0.0)
	distant.setup(player)
	distant.set_physics_process(false)
	add_child(distant)
	await physics_frames(1)
	check("a distant shard refuses collection", not distant.try_collect() and not distant.consumed)
	distant.queue_free()
	await physics_frames(1)

	var blocked := scene.instantiate() as PsycheShardPickup
	blocked.realm = 1
	blocked.position = Vector3(1.0, 0.0, 0.0)
	blocked.setup(player)
	add_child(blocked)
	blocked.set_physics_process(false)
	check("manual collection control holds the physics step", not blocked.is_physics_processing())
	var wall := StaticBody3D.new()
	wall.position = Vector3(0.5, 1.0, 0.0)
	wall.collision_layer = CollisionLayers.WORLD
	var wall_shape := CollisionShape3D.new()
	var wall_box := BoxShape3D.new()
	wall_box.size = Vector3(0.1, 2.0, 2.0)
	wall_shape.shape = wall_box
	wall.add_child(wall_shape)
	add_child(wall)
	await physics_frames(3)
	check("a WORLD wall blocks the pickup line of sight", not blocked.consumed and not blocked.try_collect())
	wall.queue_free()
	await physics_frames(3)

	var blocked_signal := [-1]
	blocked.collected.connect(func(value: int) -> void: blocked_signal[0] = value)
	var collected := blocked.try_collect()
	check("clear line of sight collects the same shard once",
		collected and blocked.consumed and blocked_signal[0] == 1 and player.fragments.has_shard(1))
	check("pickup queues its own deletion immediately", blocked.is_queued_for_deletion())
	check("a second collection attempt is a no-op", not blocked.try_collect())
	await get_tree().process_frame
	check("the collected pickup leaves the tree at once", not is_instance_valid(blocked))

	var pulse := get_node_or_null("PsycheShardPulse")
	var burst: CrystalBurst = null
	for child in get_children():
		if child is CrystalBurst:
			burst = child
	check("collection spawns a self-contained parented pulse", pulse != null)
	check("collection borrows the pooled crystal burst on the parent", burst != null)
	check("parented feedback never holds the freed pickup alive", not is_instance_valid(blocked) and is_instance_valid(burst))
	if pulse != null:
		var pulse_parent := Node3D.new()
		pulse_parent.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(pulse_parent)
		remove_child(pulse)
		pulse_parent.add_child(pulse)
		get_tree().paused = true
		await frames(2)
		var frozen_elapsed: float = pulse.elapsed
		await frames(4)
		check("pickup pulse freezes while paused even under an ALWAYS parent",
			is_equal_approx(pulse.elapsed, frozen_elapsed))
		get_tree().paused = false
		await frames(2)
		check("pickup pulse resumes after unpause", pulse.elapsed > frozen_elapsed)
		pulse_parent.remove_child(pulse)
		add_child(pulse)
		pulse_parent.queue_free()

	var automatic := scene.instantiate() as PsycheShardPickup
	automatic.realm = 2
	automatic.position = player.global_position
	automatic.setup(player)
	var automatic_signal := [-1]
	automatic.collected.connect(func(value: int) -> void: automatic_signal[0] = value)
	add_child(automatic)
	await physics_frames(2)
	check("walking range auto-collects through _physics_process",
		player.fragments.has_shard(2) and automatic_signal[0] == 2 and not is_instance_valid(automatic))

	await get_tree().create_timer(0.6).timeout
	check("the pickup pulse self-frees within its short lifetime", not is_instance_valid(pulse))
	await get_tree().create_timer(2.4).timeout
	var lingering := false
	for child in get_children():
		if child is CrystalBurst:
			lingering = true
	var pool := get_meta("crystal_emitter_pool") as Node
	check("the pooled burst returns its emitter and frees itself",
		not lingering and pool.get_child_count() == 48)
