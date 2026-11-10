extends Node3D
## Deterministic behavioral coverage of Epic 1.1/1.2 with a real physics Hitbox.

class Source extends CharacterBody3D:
	var team := 0

const CRYSTAL_IMPACT := preload("res://weapons/effects/crystal_impact.gd")

var _failed := 0
var _finished := false
var _refills := 0
var _refill_snapshot := {}


func _ready() -> void:
	await _run()
	var ok := _failed == 0 and _finished
	print("%s (%d failed%s)" % ["ALL PASSED" if ok else "FAIL", _failed,
		"" if _finished else ", run did not finish"])
	for child in get_children():
		child.queue_free()
	await get_tree().process_frame
	# AudioServer drains real-time playback on its own thread even under fixed-fps.
	OS.delay_msec(100)
	await get_tree().process_frame
	get_tree().quit(0 if ok else 1)


func _run() -> void:
	var camera := Camera3D.new()
	add_child(camera)
	var source := Source.new()
	add_child(source)
	var target := Node3D.new()
	target.position = Vector3(0, 0, -10)
	var health := Health.new()
	health.max_health = 1000.0
	target.add_child(health)
	var hitbox := Hitbox.new()
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(3, 3, 1)
	collision.shape = box
	hitbox.add_child(collision)
	target.add_child(hitbox)
	add_child(target)
	var weapon := Weapon.new()
	weapon.data = weapon.data.duplicate() as WeaponData
	weapon.camera = camera
	weapon.shooter = source
	add_child(weapon)
	weapon.set_process(false)
	for i in 3:
		await get_tree().physics_frame
	var view := weapon._view as ObsidianPistolView
	_check("single eight-round semi-auto pistol", weapon.ammo == 8 and weapon.data.fire_mode == WeaponData.FireMode.SEMI)
	_check("no loadout switching API", not weapon.has_method("select") and not weapon.has_method("cycle_zoom"))
	_check("unlimited crystal regeneration", weapon.reserve == -1)
	_check("view uses imported Blender model without CSG", view.get_node("Model").scene_file_path == "res://assets/models/weapons/obsidian_pistol.glb" and view.find_children("*", "CSGShape3D", true, false).is_empty())
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tools/epic1_models/manifest.json"))
	var model: Dictionary = manifest.models[0]
	_check("Blender source count records flat triangle/quad polygons", model.source_polygons == ObsidianPistolView.SOURCE_POLYGONS and model.objects.values().all(
		func(part: Dictionary) -> bool: return part.flat_faces and part.triangles_authored + part.quads_authored == part.polygons))
	_check("model hash matches Blender export receipt", FileAccess.get_sha256("res://assets/models/weapons/obsidian_pistol.glb") == model.sha256)
	var triangles := _body_triangles(view)
	_check("actual imported GLB triangle count matches Blender receipt (%d)" % triangles, triangles == int(model.glb_triangles) and triangles == ObsidianPistolView.BODY_TRIANGLES)
	var bounds := _model_bounds(view)
	_check("pistol measures 220 x 135 x 32mm", bounds.size.is_equal_approx(Vector3(.032, .135, .220)))
	var grip := view.get_node("Model").find_child("grip_block", true, false) as MeshInstance3D
	_check("32mm slanted grip is centred on root origin", absf(grip.mesh.get_aabb().size.x - .032) < .0001 and view.to_local(grip.global_position).length() < 0.001)
	_check("GLB preserves flat face normals", _flat_normals(view.get_node("Model")))
	var muzzle := view.get_node("Muzzle") as Node3D
	_check("muzzle marker matches barrel opening", muzzle.position.is_equal_approx(Vector3(model.muzzle_game[0], model.muzzle_game[1], model.muzzle_game[2])) and is_equal_approx(model.muzzle_recess_depth_m, .01))
	_check("all four pieces pivot around their own geometry centres", view._pieces.all(
		func(part: Node3D) -> bool: return (part as MeshInstance3D).mesh.get_aabb().get_center().length() < 0.001))
	_check("gun stays right of centre in hip and ADS", weapon.data.hip_position.x >= 0.2 and weapon.data.ads_position.x > 0.04)
	_check("hip field of view is 75 degrees", is_equal_approx(weapon.fov_for(75), 75))
	var hip_spread := weapon.spread_degrees()
	weapon.aiming = true
	_check("ADS uses 58 degrees and tightens spread", is_equal_approx(weapon.fov_for(75), 58) and weapon.spread_degrees() < hip_spread * 0.25)
	weapon.aiming = false
	_check("damage remains full through thirty metres", is_equal_approx(weapon._falloff(30), 1.0))
	_check("damage falls smoothly after thirty metres", weapon._falloff(31) < 1.0 and weapon._falloff(31) > weapon._falloff(60))
	weapon.ammo_refilled.connect(func():
		_refills += 1
		_refill_snapshot = {"ammo": weapon.ammo, "progress": view.reassembly_progress, "flash": weapon._flash.visible}
	)
	weapon.try_reload()
	_check("R on full magazine is a no-op", not weapon.is_reloading() and _refills == 0)
	weapon.ammo = 7
	get_tree().paused = true
	weapon.try_reload()
	_check("pause rejects public fire/reload without spending ammo", not weapon.try_fire() and weapon.ammo == 7 and not weapon.is_reloading())
	get_tree().paused = false
	weapon.ammo = 8
	var recoil_values := []
	weapon.recoil.connect(func(pitch: float, yaw: float, manual: float): recoil_values.append([pitch, yaw, manual]))
	var previous := health.health
	_check("click fires immediately", weapon.try_fire())
	_check("first click damages real Hitbox by 35", is_equal_approx(previous - health.health, 35.0))
	var impacts: Array[Node] = get_children().filter(func(n: Node) -> bool: return n.get_script() == CRYSTAL_IMPACT)
	_check("a pistol hit spawns solid polyhedral shards instead of flesh particles", impacts.size() == 1 and impacts[0].get_child_count() == 8 and impacts[0].get_children().all(
		func(n: Node) -> bool: return n is MeshInstance3D and (n as MeshInstance3D).mesh is PrismMesh))
	_check("pistol body hit has no red particle puff", get_children().all(func(n: Node) -> bool: return not n is Impact))
	var shard := impacts[0].get_child(0) as MeshInstance3D
	var shard_start := shard.position
	impacts[0].set_process(false)
	impacts[0]._process(0.1)
	_check("crystal fragments travel and shrink in three dimensions", shard.position.distance_to(shard_start) > 0.05 and shard.scale.x < 1.0)
	impacts[0]._process(0.4)
	_check("crystal impact queues cleanup at the .45 second lifetime", impacts[0].is_queued_for_deletion())
	seed(8765)
	var expected_rng := randi()
	seed(8765)
	var extra := CRYSTAL_IMPACT.spawn(self, Vector3.ZERO, Vector3.UP)
	_check("crystal presentation does not consume simulation randomness", randi() == expected_rng)
	extra.queue_free()
	_check("recoil signal has 1.2 pitch and bounded random yaw", recoil_values.size() == 1 and is_equal_approx(recoil_values[0][0], 1.2) and absf(recoil_values[0][1]) <= 0.3)
	_check("cannot fire twice inside 0.18 seconds", not weapon.try_fire())
	weapon._process(0.179)
	_check("cooldown still holds at 0.179 seconds", not weapon.try_fire())
	weapon._process(0.0011)
	_check("next click at 0.18 seconds fires", weapon.try_fire())
	for i in 6:
		weapon._process(0.181)
		_check("round %d fires" % (i + 3), weapon.try_fire())
	_check("eighth round immediately begins bloom", weapon.ammo == 0 and weapon.is_reloading() and is_equal_approx(view.reassembly_progress, 0.0))
	_check("exact base reassembly duration is .85 seconds", is_equal_approx(weapon._reload_left, 0.85))
	_check("reassembly blocks shots", not weapon.try_fire())
	get_tree().paused = true
	weapon._process(1.0)
	weapon.try_reload()
	_check("pause freezes reassembly and refuses shots", is_equal_approx(weapon._reload_left, 0.85) and not weapon.try_fire())
	get_tree().paused = false
	weapon._process(0.35)
	_check("bloom opens each block by 5 to 15 cm", _pieces_open(view))
	weapon.try_reload()
	_check("R during bloom cannot restart it", is_equal_approx(weapon._reload_left, 0.5))
	weapon._process(0.30)
	_check("floating stage leaves magazine empty", weapon.ammo == 0 and _refills == 0)
	weapon._process(0.199)
	_check("no early ammo before the snap", weapon.ammo == 0 and _refills == 0)
	weapon._process(0.001)
	_check("snap and ammo_refilled agree on the exact completion frame", _refills == 1 and _refill_snapshot.get("ammo") == 8 and is_equal_approx(_refill_snapshot.get("progress", 0.0), 1.0))
	_check("all pieces return exactly to rest", _pieces_closed(view))
	_check("reassembly snap lights the muzzle on the ammo_refilled frame", _refill_snapshot.get("flash", false) and is_equal_approx(weapon._flash_left, 0.06))
	weapon._process(0.061)
	_check("the snap flash ends without firing or spending a round", not weapon._flash.visible and weapon.ammo == 8)
	weapon._process(0.85)
	_check("completion emits once", _refills == 1)
	weapon.ammo = 3
	weapon.try_reload()
	weapon.set_melee_active(true)
	weapon._process(0.1)
	_check("blade makes room without hiding pistol or cancelling recharge", view.visible and weapon.trigger_enabled and weapon.is_reloading() and view.position.x > weapon.data.hip_position.x)
	weapon.set_melee_active(false)
	weapon._process(0.75)
	_check("manual recharge restores 8/8", weapon.ammo == 8 and _refills == 2)
	weapon.ammo = 2
	weapon.try_reload()
	weapon._process(0.35)
	weapon.deactivate()
	weapon._process(1.0)
	_check("death cancels recharge without granting ammo", weapon.ammo == 2 and _refills == 2 and not weapon.is_reloading())
	_check("dead weapon rejects firing and recharge", not weapon.try_fire())
	weapon.try_reload()
	_check("dead weapon cannot restart recharge", not weapon.is_reloading())
	await _test_input_hold(camera, source)
	await _test_scaled_reload(camera, source)
	_finished = true


func _body_triangles(view: Node3D) -> int:
	var triangles := 0
	for part in view.get_node("Model").find_children("*", "MeshInstance3D", true, false):
		triangles += (part as MeshInstance3D).mesh.get_faces().size() / 3
	return triangles


func _model_bounds(view: Node3D) -> AABB:
	var bounds := AABB()
	var first := true
	for found in view.get_node("Model").find_children("*", "MeshInstance3D", true, false):
		var part := found as MeshInstance3D
		var box := view.global_transform.affine_inverse() * part.global_transform * part.mesh.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	return bounds


func _pieces_open(view: ObsidianPistolView) -> bool:
	for i in view._pieces.size():
		var distance := view._pieces[i].position.distance_to(view._rest[i].origin)
		if distance < 0.05 or distance > 0.15:
			return false
	return true


func _pieces_closed(view: ObsidianPistolView) -> bool:
	for i in view._pieces.size():
		if not view._pieces[i].transform.is_equal_approx(view._rest[i]):
			return false
	return true


func _check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["ok" if ok else "FAIL", label])
	if not ok:
		_failed += 1


func _flat_normals(model: Node3D) -> bool:
	for found in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := (found as MeshInstance3D).mesh
		for surface in mesh.get_surface_count():
			var arrays := mesh.surface_get_arrays(surface)
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			for i in range(0, indices.size(), 3):
				if normals[indices[i]].distance_to(normals[indices[i + 1]]) > .002 or normals[indices[i]].distance_to(normals[indices[i + 2]]) > .002:
					return false
	return true


func _test_input_hold(camera: Camera3D, source: Source) -> void:
	if DisplayServer.get_name() == "headless":
		print("[skip] fire press/hold/release requires native mouse capture; run this scene natively")
		return
	var probe := Weapon.new()
	probe.data = preload("res://weapons/obsidian_pistol/obsidian_pistol.tres")
	probe.camera = camera
	probe.shooter = source
	add_child(probe)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	Input.action_press("fire")
	for i in 24:
		await get_tree().process_frame
	_check("holding the real fire action across two cooldowns fires once", probe.ammo == 7)
	Input.action_release("fire")
	await get_tree().process_frame
	Input.action_press("fire")
	await get_tree().process_frame
	await get_tree().process_frame
	_check("releasing and pressing the fire action shoots a second round", probe.ammo == 6)
	Input.action_release("fire")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	probe.queue_free()
	await get_tree().process_frame


func _test_scaled_reload(camera: Camera3D, source: Source) -> void:
	var stats := Stats.new()
	stats.base[Stats.RELOAD_SPEED] = 2.0
	stats.base[Stats.MAGAZINE_SIZE] = 1.5
	add_child(stats)
	var probe := Weapon.new()
	probe.data = preload("res://weapons/obsidian_pistol/obsidian_pistol.tres")
	probe.stats = stats
	probe.camera = camera
	probe.shooter = source
	add_child(probe)
	probe.set_process(false)
	probe.ammo = 3
	probe.try_reload()
	_check("reload-speed Stats scales the whole cycle to 0.425 seconds", is_equal_approx(probe._reload_total, .425))
	probe._process(.175)
	_check("speed-scaled bloom still opens all four blocks", _pieces_open(probe._view as ObsidianPistolView))
	probe._process(.15)
	_check("speed-scaled suspension keeps the partial magazine", probe.ammo == 3 and probe.is_reloading())
	probe._process(.10)
	_check("speed-scaled snap restores buffed 12-round capacity", probe.ammo == 12 and probe.reserve == -1 and not probe.is_reloading())
	probe.queue_free()
	stats.queue_free()
	await get_tree().process_frame
