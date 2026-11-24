extends Node
## The single top-level E2E seam for #271 / Ticket 05.
## One real SceneTree session covers: title states and reset, mid-run resume
## across a simulated cold restart with all four anti-S/L invariants, the 3D
## StasisHub interaction loop from the death panel, and the standalone settings
## menu on the title screen. Every route uses production nodes; only the save
## file, settings file and process-global RunDirector memory are isolated.

const BOOT := "res://ui/game_start.tscn"
const REALM_CHECKPOINT := {
	"run_id": "e2e-three-realm-checkpoint", "run_seed": 275, "order": [0, 1, 2, 3],
	"floor_index": 3, "room_index": 1, "defeated": [0, 1, 2],
	"deprivations": [0, 1, 2], "shards": [0, 1, 2], "hp": 95.0, "boon_ids": [],
	"fragment_state": {}, "rerolls": 2, "selections": [],
	"entry_reward_claimed": true, "earned_will": 45, "earned_anchors": 2,
	"defiance_consumed": false,
}

var checks := 0
var failures := 0
var elapsed := 0.0
var _original_settings := ""
var _test_settings := ""
var _boot: Node
var _title: TitleScreen


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	PauseMenu.allow_headless = true
	_run.call_deferred()


func _process(delta: float) -> void:
	elapsed += delta
	if elapsed > 240.0:
		push_error("Title/Hub/Resume E2E timed out")
		get_tree().quit(2)


func _run() -> void:
	var tree := get_tree()
	tree.current_scene = null
	_original_settings = GameSettings.settings_path
	_test_settings = "user://title_hub_settings_%d.cfg" % OS.get_process_id()
	GameSettings.settings_path = _test_settings
	if FileAccess.file_exists(_test_settings):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_test_settings))
	RunState.clear_fixture()
	RunDirector.randomize_realm_order = false
	_check("autoload boots on an isolated test profile", MetaProgression.isolated_profile
		and MetaProgression.save_path() != MetaProgression.SAVE_PATH
		and GameSettings.settings_path != GameSettings.DEFAULT_PATH)

	# ------------------------------------------------------------------ A
	# Title screen three states, opening handoff, checkpoint injection and reset.
	await _mount_boot()
	_check("ordinary boot mounts only the title screen", _title != null
		and not RunDirector.active and RunDirector.run_count == 0
		and not MetaProgression.has_profile() and tree.get_nodes_in_group("player").is_empty())
	_check("fresh menu offers a new game only", _button("Primary").text == "开始游戏"
		and not _button("Abandon").visible and not _button("Reset").visible)
	var fresh := _title.bust_state()
	_check("fresh bust floats an unworn crown above an unbroken body",
		fresh.crown_hovering and not fresh.kintsugi and fresh.fracture_level == 0
		and is_equal_approx(fresh.crown_emission, 0.5) and fresh.lit_realms == 0)
	_check("fresh tagline stays unspoiled", fresh.tagline == TitleScreen.TAGLINE)
	await _capture("e2e-fresh.png")

	_button("Primary").pressed.emit()
	if not await _wait_until(func(): return _boot.opening != null, 600):
		_check("the opening mounts after 开始游戏", false)
		_finish()
		return
	var opening := _boot.opening as OpeningSequence
	opening.set_process(false)
	_check("a first run starts the one-shot opening at the fall", opening.phase == OpeningSequence.Phase.FALL)
	opening.skip_button.pressed.emit()
	_check("skipping releases first-person control at the gate",
		opening.control_released and opening.entry_count == 0)
	opening.player.position.z = -13.2
	opening.advance(0.1)
	_check("walking through the opening gate requests combat exactly once", opening.entry_count == 1)
	if not await _wait_until(func(): return RunDirector.current_stage is RealmStage, 1200):
		_check("the opened gate installs the first room", false)
		_finish()
		return
	await _frames(4)
	var payload := _saved_payload()
	_check("the gate atomically saves opening, history and the first checkpoint",
		MetaProgression.opening_completed and RunDirector.run_count == 1
		and not RunDirector.run_id.is_empty()
		and payload.get("opening_completed") == true
		and int(payload.get("history", {}).get("run_count", -1)) == 1
		and str(payload.get("active_run", {}).get("run_id", "")) == RunDirector.run_id
		and int(payload.get("active_run", {}).get("floor_index", -1)) == 0
		and int(payload.get("active_run", {}).get("room_index", -1)) == 0)

	RunDirector.return_to_title()
	if not await _wait_until(func(): return _current_title() != null, 300):
		_check("the title remounts after the opening room", false)
		_finish()
		return
	await _frames(2)
	_boot = tree.current_scene
	_title = _current_title()
	for realm in 3:
		MetaProgression.record_archive(realm, true)
	_check("a three-realm checkpoint is accepted", MetaProgression.save_active_run(REALM_CHECKPOINT))
	await _frames(2)
	var crowned := _title.bust_state()
	_check("exploring bust seats the crown with three fracture levels and bright gold",
		not crowned.crown_hovering and not crowned.kintsugi and crowned.fracture_level == 3
		and is_equal_approx(crowned.crown_emission, 0.5 * pow(2.4, 3))
		and crowned.lit_realms == 3)
	_check("checkpoint menu offers continue and the stasis gate",
		_button("Primary").text == "继续当前挑战" and _button("Abandon").visible
		and _title._summary.text == "第 4 层 · 悲伤 房 2/3")
	await _capture("e2e-mid.png")

	MetaProgression.record_archive(-1, false, true)
	await _frames(2)
	var healed := _title.bust_state()
	_check("reconciled bust switches to kintsugi, a calm crown and the epilogue line",
		healed.kintsugi and not healed.crown_hovering
		and is_equal_approx(healed.crown_emission, 0.55) and healed.lit_realms == 4
		and healed.tagline == TitleScreen.RECONCILED_TAGLINE)
	await _capture("e2e-reconciled.png")

	var old_bytes := FileAccess.get_file_as_bytes(MetaProgression.save_path())
	_button("Reset").pressed.emit()
	var dialog := _title.get_node("Confirmation") as ConfirmationDialog
	_check("new game asks for confirmation and explains the .bak backup",
		dialog.visible and dialog.dialog_text.contains(".bak"))
	dialog.get_ok_button().pressed.emit()
	if not await _wait_until(func(): return is_instance_valid(_boot) and _boot.opening != null, 600):
		_check("confirmed reset enters the opening with a clean profile", false)
		_finish()
		return
	_check("confirmed reset clears the profile but preserves the old .bak copy",
		not MetaProgression.has_profile() and not MetaProgression.opening_completed
		and MetaProgression.active_run.is_empty() and not old_bytes.is_empty()
		and FileAccess.get_file_as_bytes(MetaProgression.save_path() + ".bak") == old_bytes
		and RunDirector.run_count == 0 and not RunDirector.active)
	await _free_scene()

	# ------------------------------------------------------------------ B
	# Mid-run resume and all four anti-S/L invariants across a cold restart.
	_check("budget unlocks keepsake slots and one defiance",
		MetaProgression.settle_run("e2e-budget", 600, 40)
		and MetaProgression.purchase("keepsake_slots")
		and MetaProgression.purchase("defiance")
		and MetaProgression.level("defiance") == 1 and MetaProgression.slots_capacity() == 1)
	_check("a fresh campaign starts", RunDirector.begin_run(275))
	RunDirector.install_stage(load(RunDirector.scene_path()) as PackedScene)
	if not await _wait_until(func(): return RunDirector.current_stage is RealmStage, 900):
		_check("the fresh 0:0 room installs", false)
		_finish()
		return
	await _frames(4)
	var stage := RunDirector.current_stage as RealmStage
	var checkpoint := MetaProgression.active_run
	_check("departure checkpoints 0:0 before any reward",
		int(checkpoint.get("floor_index", -1)) == 0 and int(checkpoint.get("room_index", -1)) == 0
		and not bool(checkpoint.get("entry_reward_claimed", true))
		and int(checkpoint.get("earned_will", -1)) == 0)
	if not await _wait_until(func(): return is_instance_valid(stage.selection), 180):
		_check("the first room offers the opening card", false)
		_finish()
		return
	_check("the opening card is the 0:0 entry offer", stage._reward_context == "enter")
	var entry_card := stage.selection._offered[0]
	_check("the initial offer can be taken", _take_reward(stage.selection) and RunDirector.boons.size() == 1
		and (RunDirector.boons[0] as BoonData).id == entry_card.id)
	await _frames(3)
	checkpoint = MetaProgression.active_run
	_check("claiming the opening card is persisted once",
		RunDirector.entry_reward_claimed and bool(checkpoint.get("entry_reward_claimed", false)))

	var roster: Array[Enemy] = stage.enemies.duplicate()
	for enemy in roster:
		if is_instance_valid(enemy) and not enemy.health.is_dead():
			enemy.health.apply_damage(99999, Hitbox.BodyPart.BODY, stage.player)
	await _frames(5)
	var cleared_will: int = roster.size() * RunDirector.KILL_WILL + RunDirector.ROOM_WILL
	_check("clearing 0:0 pays every kill and the room once",
		stage.cleared and RunDirector.earned_will == cleared_will)
	_check("clear leaves the talent orb waiting by the gate", stage.orb_pending())
	_place_player(stage.player, stage.talent_orb.global_position + Vector3(0, 0.2, 1.0),
		stage.talent_orb.global_position)
	await _physics_frames()
	_send_action(&"interact")
	if not await _wait_until(func(): return is_instance_valid(stage.selection), 180):
		_check("the clear orb opens its reward", false)
		_finish()
		return
	_check("the orb reward is the clear offer", stage._reward_context == "clear")
	_check("the clear offer can be taken", _take_reward(stage.selection))
	await _frames(3)
	_check("the clear reward opens the next-room gate", stage.exit_ready)

	var earned_before_exit := RunDirector.earned_will
	var previous_stage_id := stage.get_instance_id()
	_place_player(stage.player, stage.gate.global_position + Vector3(0, 0.15, 1.4),
		stage.gate.global_position + Vector3.UP)
	await _physics_frames()
	_send_action(&"interact")
	if not await _wait_until(func():
			if not RunDirector.current_stage is RealmStage:
				return false
			return RunDirector.current_stage.get_instance_id() != previous_stage_id, 900):
		_check("the gate advances the campaign", false)
		_finish()
		return
	await _frames(4)
	var next_stage := RunDirector.current_stage as RealmStage
	checkpoint = MetaProgression.active_run
	_check("the gate lands on 0:1 with the cleared room income on disk",
		RunDirector.floor_index == 0 and RunDirector.room_index == 1
		and next_stage.room_index == 1
		and int(checkpoint.get("floor_index", -1)) == 0
		and int(checkpoint.get("room_index", -1)) == 1
		and int(checkpoint.get("earned_will", -1)) == earned_before_exit
		and bool(checkpoint.get("entry_reward_claimed", false)))
	var saved_run := RunDirector.run_id
	var saved_seed := RunDirector.run_seed
	stage = next_stage
	stage.player.set_physics_process(false)

	stage.player.health.health = stage.player.health.max_health
	stage.player.health.apply_damage(99999, Hitbox.BodyPart.BODY)
	await _frames(4)
	_check("lethal damage consumes the single defiance revival",
		MetaProgression.defiance_consumed and not stage.fallen
		and is_equal_approx(stage.player.health.health, stage.player.health.max_health * 0.4))
	_check("the spent revival is latched into the checkpoint",
		bool(MetaProgression.active_run.get("defiance_consumed", false)))
	var safe_will := RunDirector.earned_will
	var safe_anchors := RunDirector.earned_anchors
	var victim: Enemy = null
	for enemy in stage.enemies:
		if is_instance_valid(enemy) and not enemy.health.is_dead():
			victim = enemy
			break
	if victim == null:
		_check("a live enemy remains in 0:1", false)
		_finish()
		return
	victim.health.apply_damage(99999, Hitbox.BodyPart.BODY, stage.player)
	await _frames(2)
	_check("an unfinished-room kill only raises in-memory income",
		RunDirector.earned_will == safe_will + RunDirector.KILL_WILL
		and int(MetaProgression.active_run.get("earned_will", -1)) == safe_will)

	_send_key(KEY_ESCAPE)
	await _frames(2)
	_check("the pause menu opens mid-run", stage.hud.pause_menu.is_open() and tree.paused)
	stage.hud.pause_menu._title_exit.pressed.emit()
	if not await _wait_until(func(): return _current_title() != null, 300):
		_check("返回标题画面 leaves combat", false)
		_finish()
		return
	await _frames(3)
	_boot = tree.current_scene
	_title = _current_title()
	_check("returning to the title keeps the room checkpoint and the saved run",
		not RunDirector.active and _button("Primary").text == "继续当前挑战"
		and str(MetaProgression.active_run.get("run_id", "")) == saved_run
		and int(MetaProgression.active_run.get("room_index", -1)) == 1)

	await _free_scene()
	_check("a cold profile reload reads the same checkpoint", MetaProgression.load_save())
	_reset_director_memory()
	await _mount_boot()
	_check("the cold title offers only the saved challenge",
		_button("Primary").text == "继续当前挑战" and _button("Abandon").visible)
	_check("the cold summary names the saved room",
		_title._summary.text == "第 1 层 · 恐惧 房 2/3")
	_button("Primary").pressed.emit()
	if not await _wait_until(func(): return RunDirector.current_stage is RealmStage and RunDirector.active, 900):
		_check("继续当前挑战 installs the saved room", false)
		_finish()
		return
	await _frames(6)
	stage = RunDirector.current_stage as RealmStage
	_check("resume lands exactly on 0:1 with the original seed",
		RunDirector.run_id == saved_run and RunDirector.run_seed == saved_seed
		and RunDirector.floor_index == 0 and RunDirector.room_index == 1
		and stage.room_index == 1)
	_check("resume never re-offers the 0:0 entry card",
		stage.selection == null and stage._reward_context == "")
	_check("resume keeps safe income and the already-spent revival",
		RunDirector.earned_will == safe_will and MetaProgression.defiance_consumed
		and bool(MetaProgression.active_run.get("defiance_consumed", false))
		and stage.player.health.is_dead() == false)

	var wallet := MetaProgression.will_shards
	var anchor_wallet := MetaProgression.reality_anchors
	stage.player.health.health = 1.0
	stage.player.health.apply_damage(99999, Hitbox.BodyPart.BODY)
	await _frames(4)
	_check("final death settles once, clears the checkpoint and banks safe income only",
		RunDirector._dead and MetaProgression.active_run.is_empty()
		and MetaProgression.settled_runs.has(saved_run)
		and MetaProgression.will_shards == wallet + safe_will
		and MetaProgression.reality_anchors == anchor_wallet + safe_anchors)
	var banked := MetaProgression.will_shards
	_check("a settled run can never be paid a second time",
		not MetaProgression.settle_run(saved_run, 500, 5)
		and MetaProgression.will_shards == banked)
	RunDirector.settle_rewards()
	_check("repeated death settlement leaves the wallet untouched",
		MetaProgression.will_shards == banked)

	# ------------------------------------------------------------------ C
	# StasisHub interaction loop from the death panel.
	await _frames(3)
	_check("the death panel exposes the stasis gate exit",
		stage.hud._hub_button.is_visible_in_tree()
		and stage.hud._hub_button.text.begins_with("返回静滞之门"))
	stage.hud._hub_button.pressed.emit()
	if not await _wait_until(func(): return tree.current_scene is StasisHub, 300):
		_check("返回静滞之门 opens the real hub", false)
		_finish()
		return
	await _frames(2)
	var hub := tree.current_scene as StasisHub
	_check("the hub is the post-death hall with the death context",
		hub.hub_reason == "post_death" and hub.run_count == RunDirector.run_count
		and hub.last_death_depth == 1 and hub.last_death_cause == &"combat"
		and not tree.paused)
	_check("the crown waits before its debrief", hub.crown.played_keys.is_empty())
	await tree.create_timer(0.5).timeout
	_check("the hub speaks exactly one historical debrief", hub.crown.played_keys == ["early"])
	await _capture("e2e-hub-spawn.png")

	_check("the funded altar advertises an upgrade", hub.affordable_upgrade)
	_place_player(hub.player, Vector3(-4.2, 0.02, 0.65), Vector3(-4.2, 1.35, -1.5))
	await _physics_frames()
	_check("the left forge shows its interaction prompt",
		hub._prompt.visible and hub._prompt_label.text == "[ F ] 皇冠锻造台")
	_send_action(&"interact")
	await _frames(2)
	var forge := hub.get_node_or_null("CrownForge") as CrownForge
	if not _check("interact opens and pauses the real CrownForge", forge != null and tree.paused):
		_finish()
		return
	var will_before := MetaProgression.will_shards
	var max_before := hub.player.health.max_health
	(forge._cards["resolve"].button as Button).pressed.emit()
	_check("the forge charges once and refreshes the hub player immediately",
		MetaProgression.will_shards < will_before and MetaProgression.level("resolve") == 1
		and hub.player.health.max_health == max_before + 10.0)
	_send_key(KEY_ESCAPE)
	await _frames(3)
	_check("closing the forge resumes the same hub without departing",
		not is_instance_valid(forge) and not tree.paused
		and tree.current_scene == hub and not RunDirector.active)

	_place_player(hub.player, Vector3(4.2, 0.02, 0.65), Vector3(4.2, 1.35, -1.8))
	await _physics_frames()
	_check("the right archive shows its interaction prompt",
		hub._prompt.visible and hub._prompt_label.text == "[ F ] 心象档案与赐福图鉴")
	var hash_before := FileAccess.get_sha256(MetaProgression.save_path())
	var archive_before := MetaProgression.archive_snapshot()
	var discovered_before: Array[String] = MetaProgression.discovered_boons.duplicate()
	_send_action(&"interact")
	await _frames(2)
	var archive := hub.get_node("HubInterface/StasisArchiveModal") as StasisArchiveModal
	_check("the archive opens read-only on the lore diary",
		tree.paused and archive.visible and archive._diary.visible
		and archive._tabs.size() == 2)
	archive._tabs[1].pressed.emit()
	_check("the codex tab browses without a combat build",
		archive._codex.visible and not archive._diary.visible)
	archive._tabs[0].pressed.emit()
	_check("the diary tab returns without changing state",
		archive._diary.visible and not archive._codex.visible)
	_send_key(KEY_ESCAPE)
	await _frames(2)
	_check("ESC closes the archive and leaves the profile byte-for-byte intact",
		not tree.paused and not archive.visible and tree.current_scene == hub
		and archive_before == MetaProgression.archive_snapshot()
		and discovered_before == MetaProgression.discovered_boons
		and hash_before == FileAccess.get_sha256(MetaProgression.save_path()))

	hub.player.recover_from_fall(Vector3(0, 0.02, 2.0))
	hub.player.aim_at(hub.player.eye_position() + Vector3.FORWARD)
	await _physics_frames()
	var departures: Array[bool] = []
	hub.departure_requested.connect(func(): departures.append(true))
	Input.action_press(&"move_forward")
	Input.action_press(&"dash")
	var steps := 0
	while steps < 240 and departures.is_empty():
		await tree.physics_frame
		if steps == 2:
			Input.action_release(&"dash")
		steps += 1
	Input.action_release(&"move_forward")
	Input.action_release(&"dash")
	_check("normal movement crosses the mind gate once",
		departures.size() == 1 and hub.player.position.z < -11.2)
	if not await _wait_until(func(): return RunDirector.current_stage is RealmStage, 900):
		_check("the hub gate starts a real floor", false)
		_finish()
		return
	await _frames(6)
	stage = RunDirector.current_stage as RealmStage
	var fresh_checkpoint := MetaProgression.active_run
	_check("the gate installs a genuine Floor 1 Room 1",
		RunDirector.active and RunDirector.floor_index == 0 and RunDirector.room_index == 0
		and stage.realm == RunDirector.order[0] and stage.scene_file_path.ends_with("_1.tscn"))
	_check("hub departure persists an empty 0:0 checkpoint",
		str(fresh_checkpoint.get("run_id", "")) == RunDirector.run_id
		and int(fresh_checkpoint.get("floor_index", -1)) == 0
		and int(fresh_checkpoint.get("room_index", -1)) == 0
		and int(fresh_checkpoint.get("earned_will", -1)) == 0
		and int(fresh_checkpoint.get("earned_anchors", -1)) == 0
		and not bool(fresh_checkpoint.get("entry_reward_claimed", true)))
	_check("the first room does not replay the hub debrief",
		(stage.player.get_node("CrownVoiceSystem") as CrownVoiceSystem).played_keys.is_empty())

	# ------------------------------------------------------------------ D
	# Standalone PauseMenu on the title, with an isolated settings file.
	if is_instance_valid(stage.selection):
		_take_reward(stage.selection)
	await _frames(3)
	stage.request_title()
	if not await _wait_until(func(): return _current_title() != null, 300):
		_check("the title remounts for standalone settings", false)
		_finish()
		return
	await _frames(3)
	_boot = tree.current_scene
	_title = _current_title()
	_check("the title still offers the fresh checkpoint", _button("Primary").text == "继续当前挑战"
		and not _title._error.visible)
	_button("Settings").pressed.emit()
	await _frames(2)
	var menu := _title.get_node("PauseMenu") as PauseMenu
	_check("设置与按键 opens without a Player",
		menu.is_open() and tree.paused and menu._player == null
		and not menu._title_exit.visible)
	menu._sliders.mouse.value = 1.35
	_send_key(KEY_ESCAPE)
	await _frames(3)
	_check("the standalone menu closes cleanly back to the title",
		not menu.is_open() and not tree.paused and _title.is_visible_in_tree()
		and not _title._error.visible)
	var reloaded := GameSettings.new()
	_check("the isolated settings file keeps the new sensitivity",
		reloaded.load_from(GameSettings.settings_path)
		and is_equal_approx(reloaded.mouse_sensitivity, 1.35)
		and not _title._error.visible)
	await _free_scene()

	_restore_settings()
	for suffix in ["", ".bak", ".tmp"]:
		var path: String = MetaProgression.save_path() + str(suffix)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	_check("the unique test profile was cleaned up",
		not FileAccess.file_exists(MetaProgression.save_path()))
	_finish()


# ---------------------------------------------------------------- helpers

func _mount_boot() -> void:
	var tree := get_tree()
	tree.current_scene = null
	_boot = (load(BOOT) as PackedScene).instantiate()
	tree.root.add_child(_boot)
	tree.current_scene = _boot
	await _frames(2)
	_title = _boot.title_screen as TitleScreen


func _free_scene() -> void:
	var tree := get_tree()
	var scene := tree.current_scene
	tree.current_scene = null
	if is_instance_valid(scene):
		scene.queue_free()
	_boot = null
	_title = null
	await _frames(4)


func _current_title() -> TitleScreen:
	var scene := get_tree().current_scene
	if scene == null:
		return null
	var value: Variant = scene.get("title_screen")
	return value as TitleScreen if value is TitleScreen else null


func _reset_director_memory() -> void:
	# A fresh process would only have the persisted store. Reproduce that here
	# without touching MetaProgression.active_run.
	RunDirector._finish_abandoned_run()
	RunDirector._settled = false
	RunDirector.settlement_error = ""
	RunDirector.run_count = int(MetaProgression.history.run_count)
	RunDirector.last_death_depth = int(MetaProgression.history.last_depth)
	RunDirector.last_death_cause = StringName(MetaProgression.history.death_cause)


func _restore_settings() -> void:
	if FileAccess.file_exists(_test_settings):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_test_settings))
	GameSettings.settings_path = _original_settings
	PauseMenu.allow_headless = false


func _take_reward(picker: BoonPicker) -> bool:
	if not is_instance_valid(picker):
		return false
	for card: BoonData in picker._offered:
		picker._choose(card)
		if picker._pending != null:
			picker.confirm_replacement(true)
		if picker._selected:
			return true
	return false


func _place_player(player: Player, point: Vector3, target: Vector3) -> void:
	player.recover_from_fall(point)
	player.aim_at(target)


func _saved_payload() -> Dictionary:
	return MetaProgression._read_payload(MetaProgression.save_path())


func _finish() -> void:
	print("TITLE HUB RESUME: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)


func _wait_until(predicate: Callable, limit: int) -> bool:
	for frame in limit:
		if predicate.call():
			return true
		await get_tree().process_frame
	return bool(predicate.call())


func _frames(count := 2) -> void:
	for frame in count:
		await get_tree().process_frame


func _physics_frames() -> void:
	for frame in 3:
		await get_tree().physics_frame


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


func _button(id: String) -> Button:
	return _title.find_child(id, true, false) as Button


func _check(label: String, passed: bool) -> bool:
	checks += 1
	if not passed:
		failures += 1
	print(("PASS " if passed else "FAIL ") + label)
	return passed


func _capture(filename: String) -> void:
	var output := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--title-hub-proof-dir="):
			output = argument.trim_prefix("--title-hub-proof-dir=")
	if output.is_empty() or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(output)
	var path := output.path_join(filename)
	_check("native screenshot " + path,
		get_viewport().get_texture().get_image().save_png(path) == OK)
