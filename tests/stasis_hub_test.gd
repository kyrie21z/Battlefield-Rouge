extends Node

const ENDING := "res://ui/ending_menu.tscn"
const TITLE := "res://ui/game_start.tscn"

var _checks := 0
var _failures := 0
var _proof_dir := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--stasis-hub-proof-dir="):
			_proof_dir = argument.get_slice("=", 1)
	_run.call_deferred()


func _run() -> void:
	var tree := get_tree()
	tree.create_timer(120).timeout.connect(func(): tree.quit(2))
	# Keep the test driver at the root while the production route swaps scenes.
	tree.current_scene = null
	PauseMenu.allow_headless = true
	var settings_path := GameSettings.settings_path
	GameSettings.settings_path = "user://stasis_hub_%d.cfg" % OS.get_process_id()
	RunState.clear_fixture()
	RunDirector.randomize_realm_order = false
	_check("campaign uses an isolated profile", MetaProgression.isolated_profile)
	# Fund two prior Reflex levels plus exactly the three purchases performed in the Hub.
	MetaProgression.settle_run("hub-test-fund", 225, 0)
	MetaProgression.purchase("reflex")
	MetaProgression.purchase("reflex")
	RunDirector.begin_run(274)
	RunDirector.install_stage(load(RunDirector.scene_path()) as PackedScene)
	var stage := RunDirector.current_stage as RealmStage
	_fall_into_abyss(stage)
	await _frames()
	_check("death displays Hub exit and clears old checkpoint",
		stage.hud._hub_button.is_visible_in_tree() and not MetaProgression.has_active_run())
	var spawn_points: Array[Vector3] = []
	var record_spawn := func(node: Node) -> void:
		if node is Player and node.get_parent() is StasisHub:
			spawn_points.append(node.position)
	tree.node_added.connect(record_spawn)
	stage.hud._hub_button.pressed.emit()
	await tree.process_frame
	tree.node_added.disconnect(record_spawn)
	var hub := tree.current_scene as StasisHub
	if not _check("death button routes to real post-death Hub", hub != null and hub.hub_reason == "post_death"):
		tree.quit(1)
		return

	var player := hub.player
	_check("spawn and camera face -Z at the prescribed point",
		spawn_points == [Vector3(0, 0.02, 2.0)]
		and player.view_forward().dot(Vector3.FORWARD) > 0.99
		and tree.root.get_camera_3d() == player.view_camera)
	_check("Hub is idle with worn Crown and inherited progression",
		not tree.paused and not RunDirector.active and RunDirector.current_stage == null
		and hub.crown.model.worn and player.dash_max_charges() == 2
		and is_equal_approx(player.stats.get_value(Stats.DASH_RECHARGE), 1.2)
		and hub.find_children("*", "RealmHUD", true, false).is_empty())
	_check("Hub disables pistol, reload and blade with arms and body retained",
		not player.weapon.visible and not player.melee.visible and not player.weapon.try_fire()
		and not player.melee.swing_now() and player.get_node("ShadowBody").is_visible_in_tree())
	var ammo := player.weapon.ammo
	_send_action(&"fire")
	player.weapon.try_reload()
	_send_action(&"reload")
	_send_action(&"melee")
	await _physics_frames()
	_check("combat inputs leave the weapon idle and ammo untouched",
		not player.weapon.is_reloading() and not player.melee.is_swinging() and player.weapon.ammo == ammo)
	_check("historical response waits before speaking", hub.crown.played_keys.is_empty())
	await tree.create_timer(0.45).timeout
	_check("Hub plays one matching historical debrief without creating a run",
		hub.run_count == 1 and hub.last_death_depth == 1 and hub.last_death_cause == &"abyss"
		and hub.crown.played_keys == ["early_abyss"] and MetaProgression.history.run_count == 1)
	await _capture("hub-spawn")

	await _test_forge(hub)
	await _test_archive(hub)
	var menu := hub.get_node("HubInterface/PauseMenu") as PauseMenu
	_send_key(KEY_ESCAPE)
	_check("ESC opens settings in the Hub", tree.paused and menu.is_open() and menu._title_exit.visible)
	var sensitivity := player.mouse_sensitivity
	menu._sliders["mouse"].value = 1.5
	_check("Hub applies mouse sensitivity immediately", is_equal_approx(player.mouse_sensitivity, sensitivity * 1.5))
	_send_key(KEY_ESCAPE)
	_check("closing settings resumes Hub", not tree.paused and not menu.is_open())

	player.recover_from_fall(Vector3(0, 0.02, 2.0))
	player.aim_at(player.eye_position() + Vector3.FORWARD)
	await _physics_frames()
	var departures: Array[bool] = []
	var dashes: Array[bool] = []
	hub.departure_requested.connect(func(): departures.append(true))
	player.dash.dashing.connect(func(_direction, _speed, _duration): dashes.append(true))
	Input.action_press(&"move_forward")
	Input.action_press(&"dash")
	var steps := 0
	while steps < 180 and departures.is_empty():
		await tree.physics_frame
		if steps == 2:
			Input.action_release(&"dash")
		steps += 1
	Input.action_release(&"move_forward")
	Input.action_release(&"dash")
	_check("normal movement crosses the gate in %d physics frames with one dash" % steps,
		departures.size() == 1 and dashes == [true] and steps < 180 and player.position.z < -11.2)
	_send_action(&"interact")
	await _wait_for_room()
	stage = RunDirector.current_stage as RealmStage
	if not _check("crossing starts exactly one real Floor 1 Room 1",
		stage != null and stage == tree.current_scene and stage.realm == 1
		and RunDirector.floor_index == 0 and RunDirector.room_index == 0
		and RunDirector.active and RunDirector.run_count == 2 and departures.size() == 1):
		tree.quit(1)
		return
	var cold := MetaProgressionStore.new()
	cold.override_path = MetaProgression.save_path()
	add_child(cold)
	_check("a cold store reads the initial checkpoint and upgraded start HP",
		cold.has_active_run() and cold.active_run.run_id == RunDirector.run_id
		and cold.active_run.floor_index == 0 and cold.active_run.room_index == 0
		and not cold.active_run.entry_reward_claimed and cold.active_run.hp == 110.0
		and cold.active_run.earned_will == 0 and cold.active_run.earned_anchors == 0)
	cold.queue_free()
	_check("post-death Hub departure suppresses exactly the first room history",
		(stage.player.get_node("CrownVoiceSystem") as CrownVoiceSystem).played_keys.is_empty()
		and not RunDirector.suppress_entry_history_voice)

	var stage_id := stage.get_instance_id()
	_fall_into_abyss(stage)
	await _frames()
	_send_key(KEY_R)
	await _frames()
	await _wait_for_room()
	stage = RunDirector.current_stage as RealmStage
	if not _check("R directly retries Floor 1 Room 1 with normal history playback",
		stage != null and stage.get_instance_id() != stage_id and RunDirector.run_count == 3
		and (stage.player.get_node("CrownVoiceSystem") as CrownVoiceSystem).played_keys == ["early_abyss"]):
		tree.quit(1)
		return

	var saved_id := RunDirector.run_id
	if is_instance_valid(stage.selection):
		stage.selection._buttons[0].pressed.emit()
	await _frames()
	_send_key(KEY_ESCAPE)
	stage.hud.pause_menu._title_exit.pressed.emit()
	await _frames()
	_check("RealmStage title exit leaves the current checkpoint and count intact",
		tree.current_scene.scene_file_path == TITLE and not RunDirector.active
		and tree.current_scene.get("title_screen") is TitleScreen
		and MetaProgression.active_run.get("run_id") == saved_id and RunDirector.run_count == 3)
	_find_button(tree.current_scene, "继续当前挑战").pressed.emit()
	await _wait_for_room()
	_check("title continues the same room without starting another run",
		tree.current_scene is RealmStage and RunDirector.run_id == saved_id
		and RunDirector.run_count == 3 and RunDirector.room_index == 0)
	await _test_title_and_ending()

	tree.paused = false
	tree.current_scene.queue_free()
	tree.current_scene = null
	await tree.create_timer(0.5).timeout
	DirAccess.remove_absolute(GameSettings.settings_path)
	GameSettings.settings_path = settings_path
	PauseMenu.allow_headless = false
	print("STASIS HUB: %d checks, %d failures" % [_checks, _failures])
	tree.quit(1 if _failures else 0)


func _test_forge(hub: StasisHub) -> void:
	var light := hub.get_node("ForgeAltar/ForgeLight") as OmniLight3D
	var miniature := hub.get_node("ForgeAltar/ForgeCrown") as CrownModel
	var intensity := light.light_energy
	await _physics_frames()
	_check("affordable altar pulses with a floating unworn Crown",
		hub.affordable_upgrade and not is_equal_approx(intensity, light.light_energy) and not miniature.worn)
	_place_player(hub.player, Vector3(-4.2, 0.02, 0.65), Vector3(-4.2, 1.35, 2))
	await _physics_frames()
	_send_action(&"interact")
	_check("looking away from the altar prevents its prompt and interaction",
		not hub._prompt.visible and not get_tree().paused)
	_place_player(hub.player, Vector3(-4.2, 0.02, 0.65), Vector3(-4.2, 1.35, -1.5))
	await _physics_frames()
	_check("Forge prompt appears when close and facing the altar",
		hub._prompt.visible and hub._prompt_label.text == "[ F ] 皇冠锻造台")
	await _capture("hub-forge")
	_send_action(&"interact")
	var forge := hub.get_node_or_null("CrownForge") as CrownForge
	if not _check("interact opens and pauses the real Forge", forge != null and get_tree().paused):
		return
	(forge._cards["resolve"].button as Button).pressed.emit()
	(forge._cards["reflex"].button as Button).pressed.emit()
	(forge._cards["focus"].button as Button).pressed.emit()
	_check("real purchases deduct the wallet and update health, dash and magazine while open",
		MetaProgression.will_shards == 0 and hub.player.health.max_health == 110.0
		and hub.player.dash_max_charges() == 3 and hub.player.weapon.magazine_capacity() == 9)
	_check("last purchase immediately clears the gold pulse",
		not hub.affordable_upgrade and is_equal_approx(light.light_energy, 0.18))
	_send_key(KEY_ESCAPE)
	await _frames()
	_check("Forge ESC unpauses and resumes the same Hub without departing",
		not is_instance_valid(forge) and get_tree().current_scene == hub and not get_tree().paused
		and (DisplayServer.get_name() == "headless" or Input.mouse_mode == Input.MOUSE_MODE_CAPTURED)
		and not MetaProgression.has_active_run())


func _test_archive(hub: StasisHub) -> void:
	var stele := hub.get_node("ArchiveStele")
	for realm in 4:
		var pillar := stele.get_node("Pillar%d" % realm)
		var core := pillar.get_node("Crystal") as MeshInstance3D
		var trim := pillar.get_node("Trim") as MeshInstance3D
		var inlay := pillar.get_node("Kintsugi") as Node3D
		var white := _mesh_color(core)
		var unvisited := not MetaProgression.visited_realms.has(realm)
		var white_initial := not unvisited or _mesh_color(trim) == white
		MetaProgression.record_archive(realm)
		var accent := EditorialStyle.realm_accent(realm)
		var visited_only := _mesh_color(core) == white and _mesh_color(trim) == accent and not inlay.visible
		MetaProgression.record_archive(realm, true)
		_check("realm %d maps white, visited trim and defeated tint" % realm,
			white_initial and visited_only and _mesh_color(core).is_equal_approx(white.lerp(accent, 0.66)))
	MetaProgression.record_archive(-1, false, true)
	var inlays := stele.find_children("Kintsugi", "Node3D", true, false)
	_check("reconciliation reveals gold inlays on all four pillars",
		inlays.size() == 4 and inlays.all(func(inlay: Node3D):
			return inlay.visible and _mesh_color(inlay.get_child(0)) == StasisHub.GOLD))

	_place_player(hub.player, Vector3(4.2, 0.02, 0.65), Vector3(4.2, 1.35, -1.8))
	await _physics_frames()
	_check("right-side prompt names both archive pages",
		hub._prompt.visible and hub._prompt_label.text == "[ F ] 心象档案与赐福图鉴")
	await _capture("hub-archive")
	var hash_before := FileAccess.get_sha256(MetaProgression.save_path())
	var archive_before := MetaProgression.archive_snapshot()
	var discovered_before := MetaProgression.discovered_boons.duplicate()
	_send_action(&"interact")
	var archive := hub.get_node("HubInterface/StasisArchiveModal") as StasisArchiveModal
	_check("archive opens the read-only diary and codex", get_tree().paused and archive.visible
		and archive._diary.visible and archive._tabs.size() == 2)
	archive._tabs[1].pressed.emit()
	_check("codex tab is browsable without a combat build", archive._codex.visible and not archive._diary.visible)
	_send_key(KEY_ESCAPE)
	_check("archive ESC resumes Hub and leaves profile byte-for-byte intact",
		not get_tree().paused and not archive.visible and get_tree().current_scene == hub
		and (DisplayServer.get_name() == "headless" or Input.mouse_mode == Input.MOUSE_MODE_CAPTURED)
		and archive_before == MetaProgression.archive_snapshot()
		and discovered_before == MetaProgression.discovered_boons
		and hash_before == FileAccess.get_sha256(MetaProgression.save_path()))


func _test_title_and_ending() -> void:
	var tree := get_tree()
	RunDirector.abandon_active_run()
	await _show_ending()
	var ending := tree.current_scene
	_find_button(ending, "心象日记").pressed.emit()
	_check("EndingMenu archive still opens and Quit remains available", is_instance_valid(ending._archive_reader)
		and _find_button(ending, "退出") != null)
	ending._archive_reader.closed.emit()
	_find_button(ending, "返回标题画面").pressed.emit()
	await _frames()
	_check("EndingMenu returns to TitleScreen without starting a run",
		tree.current_scene.scene_file_path == TITLE and RunDirector.run_count == 3
		and tree.current_scene.get("title_screen") is TitleScreen)
	await _show_ending()
	_find_button(tree.current_scene, "返回静滞之门").pressed.emit()
	await _frames()
	var hub := tree.current_scene as StasisHub
	_check("EndingMenu Hub exit opens a quiet epilogue Hub",
		hub != null and hub.hub_reason == "epilogue" and hub.crown.played_keys.is_empty()
		and RunDirector.run_count == 3)
	var requests: Array[bool] = []
	if hub == null:
		return
	hub.title_requested.connect(func(): requests.append(true))
	_send_key(KEY_ESCAPE)
	(hub.get_node("HubInterface/PauseMenu") as PauseMenu)._title_exit.pressed.emit()
	await _frames()
	_check("Hub PauseMenu requests the TitleScreen once",
		requests == [true] and tree.current_scene.scene_file_path == TITLE
		and tree.current_scene.get("title_screen") is TitleScreen
		and not tree.paused and RunDirector.run_count == 3 and not MetaProgression.has_active_run())

	await _show_ending()
	_find_button(tree.current_scene, "返回静滞之门").pressed.emit()
	await _frames()
	hub = tree.current_scene as StasisHub
	if hub == null:
		_check("EndingMenu Hub exit reopens StasisHub", false)
		return
	_place_player(hub.player, Vector3(0, 0.02, -8.5), Vector3(0, 1.5, -10.5))
	await _physics_frames()
	await _capture("hub-gate")
	_send_action(&"interact")
	await _wait_for_room()
	_check("EndingMenu Hub exit supports interact departure",
		tree.current_scene is RealmStage and RunDirector.run_count == 4)


func _show_ending() -> void:
	get_tree().change_scene_to_file(ENDING)
	await get_tree().scene_changed


func _find_button(scene: Node, caption: String) -> Button:
	for button: Button in scene.find_children("*", "Button", true, false):
		if button.text.begins_with(caption):
			return button
	return null


func _capture(name: String) -> void:
	if _proof_dir.is_empty() or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var path := _proof_dir.path_join(name + ".png")
	_check("native capture " + path, get_viewport().get_texture().get_image().save_png(path) == OK)


func _mesh_color(mesh: MeshInstance3D) -> Color:
	return (mesh.material_override as StandardMaterial3D).albedo_color


func _fall_into_abyss(stage: RealmStage) -> void:
	stage.player.health.apply_damage(1, Hitbox.BodyPart.BODY, null,
		{"environmental_fatal": true, "tag": &"abyss"})


func _place_player(player: Player, point: Vector3, target: Vector3) -> void:
	player.recover_from_fall(point)
	player.aim_at(target)


func _wait_for_room() -> void:
	for frame in 600:
		if RunDirector.current_stage is RealmStage:
			break
		await get_tree().process_frame
	await _frames()


func _physics_frames() -> void:
	for frame in 3:
		await get_tree().physics_frame


func _frames() -> void:
	for frame in 4:
		await get_tree().process_frame


func _send_action(action: StringName) -> void:
	for pressed in [true, false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = pressed
		get_viewport().push_input(event)


func _send_key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = code
		event.pressed = pressed
		get_viewport().push_input(event)


func _check(label: String, ok: bool) -> bool:
	_checks += 1
	if not ok:
		_failures += 1
	print(("PASS " if ok else "FAIL ") + label)
	return ok
