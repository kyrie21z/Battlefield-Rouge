extends Node
## Regression coverage for the pre-boss rest sanctuary: room contents, guards,
## the post-Sloth collapse, checkpoint/resume and the untouched Sloth contracts.

const REST_SCENES := [
	"res://maps/realms/sloth_rest.tscn",
	"res://maps/realms/fear_rest.tscn",
	"res://maps/realms/wrath_rest.tscn",
	"res://maps/realms/sorrow_rest.tscn",
]
const PLAYER_SCENE := preload("res://actors/player/player.tscn")
const TITLE_SCENE := preload("res://ui/title_screen/title_screen.tscn")

var checks := 0
var failures := 0
var _proof_dir := ""


func check(label: String, ok: bool) -> void:
	checks += 1
	print("%s %s" % ["PASS" if ok else "FAIL", label])
	if not ok:
		failures += 1


func frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func process_frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func _ready() -> void:
	MetaProgression.introduced_realms.assign([0, 1, 2, 3])
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--proof-dir="):
			_proof_dir = arg.trim_prefix("--proof-dir=")
	await get_tree().process_frame
	get_tree().current_scene = null
	MetaProgression.reset_profile()

	await _check_sanctuaries()
	await _check_rest_guards()
	await _check_pre_sloth_route()
	await _check_resume_and_schema()
	await _check_sloth_contract()

	OS.delay_msec(250)
	print("REST ROOM: %s (%d checks, %d failures)" % ["ALL PASSED" if failures == 0 else "FAIL", checks, failures])
	get_tree().quit(0 if failures == 0 else 1)


func _capture(stage: RealmStage, file_name: String) -> void:
	if _proof_dir.is_empty() or DisplayServer.get_name() == "headless":
		return
	await frames(4)
	await process_frames(4)
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(_proof_dir)
	var path := _proof_dir.path_join(file_name)
	var err := get_viewport().get_texture().get_image().save_png(path)
	check("native proof screenshot " + file_name, err == OK and is_instance_valid(stage))


func _check_sanctuaries() -> void:
	for realm in REST_SCENES.size():
		var stage := (load(REST_SCENES[realm]) as PackedScene).instantiate() as RealmStage
		stage.campaign = false
		add_child(stage)
		await frames(4)
		stage.player.set_physics_process(false)
		check("realm %d sanctuary loads with no enemies" % realm,
			stage.rest_room and stage.enemies.is_empty() and not is_instance_valid(stage.boss))
		check("realm %d sanctuary bakes traversable geometry" % realm,
			stage._region != null and stage._region.navigation_mesh.get_polygon_count() > 0)
		check("realm %d sanctuary arrives cleared with an open boss gate" % realm,
			stage.cleared and stage.exit_ready and stage._gate_label.text.contains("首领门扉"))
		check("realm %d sanctuary altar waits for the player" % realm, stage.rest_altar_pending())
		check("realm %d sanctuary spawns at the entrance" % realm,
			stage.player.position.distance_to(Vector3(0, 0.1, 11)) < 0.2)
		check("realm %d badge reads the fourth slot" % realm, stage.room_badge_text() == "休息室 3/4")
		await process_frames(2)
		check("realm %d HUD plaque announces the sanctuary" % realm,
			stage.hud._realm_caption.text.contains("休息室 3/4"))
		if realm == PsycheFragments.SLOTH:
			stage.player.health.health = 45.0
			stage.player.aim_at(stage.geometry.to_global(stage.geometry.call("rest_position")) + Vector3.UP * 1.4)
			await _capture(stage, "sloth-rest-entry.png")
		elif realm == PsycheFragments.FEAR:
			stage.player.aim_at(stage.geometry.to_global(stage.geometry.call("rest_position")) + Vector3.UP * 1.4)
			await _capture(stage, "fear-rest-entry.png")
		stage.queue_free()
		await frames(2)


func _check_rest_guards() -> void:
	var stage := (load(REST_SCENES[PsycheFragments.SLOTH]) as PackedScene).instantiate() as RealmStage
	stage.campaign = false
	add_child(stage)
	await frames(4)
	stage.player.set_physics_process(false)
	var altar: Vector3 = stage.geometry.to_global(stage.geometry.call("rest_position"))
	check("a distant player cannot rest", not stage.request_rest())

	stage.player.position = altar + Vector3(0, 0.1, 1.4)
	var blocker := StaticBody3D.new()
	blocker.name = "RestSightBlocker"
	blocker.collision_layer = CollisionLayers.WORLD
	blocker.collision_mask = 0
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(3.0, 3.0, 0.4)
	collision.shape = shape
	blocker.add_child(collision)
	blocker.position = altar + Vector3(0, 1.5, 0.7)
	add_child(blocker)
	await frames(2)
	await process_frames(2)
	check("a wall between the player and the altar blocks the rest and hides the prompt",
		not stage.can_interact_rest() and not stage.request_rest() and not stage.rest_used and not stage.hud._exit_hint.visible)
	blocker.queue_free()
	await frames(2)

	stage.player.health.health = stage.player.health.max_health * 0.4
	var before := stage.player.health.health
	stage.player.position = altar + Vector3(0, 0.1, 2.3)
	stage.player.aim_at(altar + Vector3.UP * 1.35)
	await _capture(stage, "sloth-rest-prompt.png")
	check("the first nearby interaction rests", stage.request_rest() and stage.rest_used)
	check("the rest heals exactly to full", is_equal_approx(stage.player.health.health, stage.player.health.max_health)
		and stage.player.health.health > before)
	check("a second interaction cannot heal again", not stage.request_rest())
	check("the altar dims and its label changes after resting",
		(stage.geometry.get("altar_label") as Label3D).text.contains("心绪已平复")
		and (stage.geometry.get("altar_light") as OmniLight3D).light_energy < 1.0)
	check("resting keeps the boss gate open", stage.exit_ready)
	await _capture(stage, "sloth-rest-healed.png")
	stage.queue_free()
	await frames(2)


func _check_pre_sloth_route() -> void:
	RunDirector.randomize_realm_order = false
	RunDirector.begin_run(60606)
	RunDirector.order.assign([1, 2, 0, 3])
	RunDirector.prepare_departure()
	var sanctuaries_ok := true
	for floor in 3:
		RunDirector.floor_index = floor
		RunDirector.room_index = RunDirector.ROOM_REST
		sanctuaries_ok = sanctuaries_ok and RunDirector.has_rest_room() \
			and RunDirector.rooms_in_floor() == 4 \
			and RunDirector.scene_path().ends_with("_rest.tscn")
	check("Fear, Wrath and Sloth each keep a sanctuary while Sloth lives", sanctuaries_ok)

	RunDirector.floor_index = 2
	RunDirector.room_index = RunDirector.ROOM_BOSS
	check("the Sloth boss slot is the only place its deprivation can be taken", RunDirector.defeat_realm(PsycheFragments.SLOTH)
		and RunDirector.deprivations.has(PsycheFragments.SLOTH))
	RunDirector.shards.append(PsycheFragments.SLOTH)
	check("the Sloth floor closes into Sorrow's first room",
		RunDirector.advance_room() and RunDirector.floor_index == 3 and RunDirector.room_index == RunDirector.ROOM_COMBAT_1)
	check("Sorrow's floor collapses to three rooms", not RunDirector.has_rest_room() and RunDirector.rooms_in_floor() == 3)
	RunDirector.room_index = RunDirector.ROOM_COMBAT_2
	check("Sorrow's second room skips the lost sanctuary", RunDirector.advance_room()
		and RunDirector.room_index == RunDirector.ROOM_BOSS and RunDirector.scene_path().ends_with("sorrow_boss.tscn"))

	check("Sorrow's first room reads 房间 1/3",
		await _badge_for("res://maps/realms/sorrow_1.tscn", 0) == "房间 1/3")
	check("Sorrow's second room reads 房间 2/3",
		await _badge_for("res://maps/realms/sorrow_2.tscn", 1) == "房间 2/3")
	check("Sorrow's boss reads 首领 3/3",
		await _badge_for("res://maps/realms/sorrow_boss.tscn", 3) == "首领 3/3")


func _badge_for(scene_path: String, room: int) -> String:
	var stage := (load(scene_path) as PackedScene).instantiate() as RealmStage
	stage.campaign = false
	stage.configure_run(3, [PsycheFragments.SLOTH], [PsycheFragments.SLOTH], 60.0, [])
	add_child(stage)
	await frames(3)
	var text := stage.room_badge_text()
	stage.queue_free()
	await frames(2)
	return text


func _check_resume_and_schema() -> void:
	MetaProgression.reset_profile()
	RunDirector.randomize_realm_order = false
	RunDirector.begin_run(70707)
	RunDirector.order.assign([1, 2, 0, 3])
	RunDirector.prepare_departure()
	RunDirector.advance_room()
	RunDirector.advance_room()
	check("the Fear floor stops inside its sanctuary",
		RunDirector.floor_index == 0 and RunDirector.is_rest_room() and RunDirector.scene_path().ends_with("fear_rest.tscn"))

	var player := PLAYER_SCENE.instantiate() as Player
	add_child(player)
	player.set_physics_process(false)
	var card: BoonData = null
	for candidate in BoonCatalog.all():
		if candidate.core:
			card = candidate
			break
	player.boons.restore([card])
	player.health.health = 55.0
	player.fragments.restore([PsycheFragments.FEAR])
	RunDirector.capture_player(player)
	check("the sanctuary checkpoint records health, boons and cores", RunDirector._checkpoint_active_run()
		and is_equal_approx(RunDirector.hp, 55.0) and RunDirector.boons.size() == 1
		and RunDirector.shards.size() == 1 and RunDirector.shards.has(PsycheFragments.FEAR))
	player.free()

	var cold := MetaProgressionStore.new()
	cold.override_path = MetaProgression.save_path()
	add_child(cold)
	check("a cold restart reloads the sanctuary room",
		cold.has_active_run()
		and int(cold.active_run.get("floor_index", -1)) == 0
		and int(cold.active_run.get("room_index", -1)) == RunDirector.ROOM_REST
		and is_equal_approx(float(cold.active_run.get("hp", 0.0)), 55.0))
	MetaProgression.active_run = cold.active_run.duplicate(true)
	MetaProgression.active_run_id = str(MetaProgression.active_run.get("run_id", ""))

	var title := TITLE_SCENE.instantiate() as TitleScreen
	add_child(title)
	await process_frames(3)
	check("the title summary names the sanctuary", title._summary.text == "第 1 层 · 恐惧 休息室 3/4")
	title.queue_free()
	cold.queue_free()
	await frames(2)

	var dummy := Node.new()
	dummy.name = "RestResumeDummy"
	get_tree().root.add_child(dummy)
	get_tree().current_scene = dummy
	var fake_packed := PackedScene.new()
	var fake_root := Node.new()
	fake_root.name = "RestResumeFake"
	fake_packed.pack(fake_root)
	fake_root.free()
	var resumed = load("res://autoload/run_director.gd").new()
	add_child(resumed)
	check("resume_run lands back inside the sanctuary",
		resumed.resume_run(fake_packed) and resumed.room_index == RunDirector.ROOM_REST
		and resumed.scene_path().ends_with("fear_rest.tscn"))
	check("resume keeps health, boons, cores and the seed",
		is_equal_approx(resumed.hp, 55.0) and resumed.boons.size() == 1
		and resumed.shards.size() == 1 and resumed.shards.has(PsycheFragments.FEAR)
		and resumed.run_seed == RunDirector.run_seed)
	resumed.defeated.append(PsycheFragments.SLOTH)
	resumed.deprivations.append(PsycheFragments.SLOTH)
	check("the schema refuses a sanctuary checkpoint once Sloth is lost",
		not MetaProgression.save_active_run(resumed._active_run_snapshot()))
	resumed.deprivations.clear()
	check("the schema refuses contradictory defeated and deprivations sets",
		not MetaProgression.save_active_run(resumed._active_run_snapshot()))
	resumed.queue_free()
	get_tree().current_scene = null
	dummy.queue_free()
	await frames(2)


func _check_sloth_contract() -> void:
	var stage := (load("res://maps/realms/sloth_1.tscn") as PackedScene).instantiate() as RealmStage
	stage.campaign = false
	add_child(stage)
	await frames(4)
	stage.player.set_physics_process(false)
	var zones: Array = stage.geometry.get("rest_zones")
	var lights: Array = stage.geometry.get("rest_lights")
	check("Sloth's own two Rest Zones stay intact", zones.size() == 2 and bool(stage.geometry.get("rest_enabled")))
	stage.geometry.call("set_deprivation", true)
	var dark := lights.all(func(light: OmniLight3D) -> bool: return is_zero_approx(light.light_energy))
	check("depriving Sloth still extinguishes its Rest Zones", not bool(stage.geometry.get("rest_enabled")) and dark)
	stage.geometry.call("set_deprivation", false)
	check("restoring Sloth relights its Rest Zones", bool(stage.geometry.get("rest_enabled")))
	check("the Slumber Shard room heal cap is unchanged",
		is_equal_approx(PsycheFragments.SLUMBER_ROOM_HEAL_CAP, 30.0))
	stage.queue_free()
	await frames(2)
	var sloth_boss := (load("res://maps/realms/sloth_boss.tscn") as PackedScene).instantiate() as RealmStage
	sloth_boss.campaign = false
	sloth_boss.configure_run(0, [], [], 100.0, [])
	add_child(sloth_boss)
	await frames(4)
	sloth_boss.player.set_physics_process(false)
	check("Sloth boss enters on a four-room floor badge", sloth_boss.room_badge_text() == "首领 4/4")
	sloth_boss.boss.health.apply_damage(100000, Hitbox.BodyPart.BODY, sloth_boss.player, {"true_damage": true})
	await frames(4)
	await process_frames(2)
	check("killing Sloth keeps the current floor badge at 4/4 instead of jumping to 3/3",
		sloth_boss.boss_defeated and sloth_boss.deprivations.has(PsycheFragments.SLOTH)
		and sloth_boss.room_badge_text() == "首领 4/4"
		and sloth_boss.hud._realm_caption.text.contains("首领 4/4"))
	sloth_boss.queue_free()
	await frames(2)
