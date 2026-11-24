extends Node
## Campaign state and composition root. Actors receive values, never this object.
signal changed
signal realm_completed(realm: int, count: int)
signal run_failed(depth: int, cause: StringName)
signal threshold_reached
const REALMS := ["sloth","fear","wrath","sorrow"]
## Optional fixed route for focused Fear diagnostics; ordinary runs use shuffle.
const PLAYTEST_ORDER := [1,0,2,3]
var randomize_realm_order := true
const THRESHOLD := "res://levels/climax/threshold_corridor.tscn"
const STASIS_HUB := "res://levels/stasis_hub/stasis_hub.tscn"
const TITLE_ENTRY := "res://ui/game_start.tscn"
var active := false
var completed := false
var run_count := 0
var last_death_depth := 0
var last_death_cause: StringName = &""
var run_seed := 0
var order: Array[int] = []
var floor_index := 0
var room_index := 0
var defeated: Array[int] = []
var deprivations: Array[int] = []
var shards: Array[int] = []
var hp := -1.0
var boons: Array = []
var fragment_state: Dictionary = {}
var rerolls := 2
var selections: Array[Dictionary] = []
var crown_strength := 0.5
var current_stage: Node
var _transitioning := false
var _dead := false
var _starter_given := false
var _epoch := 0
const KILL_WILL := 5
const ROOM_WILL := 20
## Depth scaling is a three-axis vector and never depends on realm identity:
## health climbs fastest, damage stays fair, and tempo tightens the enemy
## attack cadence. Only the depth and the lost realms may change it.
const HP_SCALES := [1.0, 1.35, 1.85, 2.45]
const DAMAGE_SCALES := [1.0, 1.15, 1.32, 1.50]
const TEMPO_SCALES := [1.0, 1.08, 1.18, 1.28]
## Losing Sloth deprives the run of rest: every later room runs faster.
const SLOTH_HASTE := 0.12
var run_id := ""
var earned_will := 0
var earned_anchors := 0
## True once the first room's opening three-card choice has been taken. A
## resumed 0:0 run must never offer that choice again.
var entry_reward_claimed := false
## Set for a resumed room or a fresh departure after the hub debrief.
var suppress_entry_history_voice := false
var _departure_prepared := false
var _settled := false
var _rewarded_kills := {}
var _rewarded_rooms := {}
var settlement_error := ""
var _save_notice: CanvasLayer
var _save_retry: Button

func _ready() -> void:
	run_count = int(MetaProgression.history.run_count)
	last_death_depth = int(MetaProgression.history.last_depth)
	last_death_cause = StringName(MetaProgression.history.death_cause)
	if not MetaProgression.revived.is_connected(_revived_for_checkpoint):
		MetaProgression.revived.connect(_revived_for_checkpoint)

func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func begin_run(value_seed: int = -1, persist_history := true) -> bool:
	# Never discard a failed settlement when the player asks for another run.
	if not run_id.is_empty() and not _settled and (_dead or completed or earned_will>0 or earned_anchors>0):
		if not settle_rewards():
			return false
	# A new campaign must not inherit a stale resumable room from an older one.
	if MetaProgression.has_active_run():
		MetaProgression.clear_active_run()
	active = true
	completed = false
	current_stage = null
	run_id = "%d-%d-%d" % [int(Time.get_unix_time_from_system()*1000000),OS.get_process_id(),randi()]
	earned_will = 0
	earned_anchors = 0
	_rewarded_kills.clear()
	_rewarded_rooms.clear()
	_settled = false
	_departure_prepared = false
	MetaProgression.begin_run(run_id)
	run_count += 1
	run_seed = randi() if value_seed < 0 else value_seed
	var rng := RandomNumberGenerator.new()
	rng.seed = run_seed
	order.assign(PLAYTEST_ORDER)
	if randomize_realm_order:
		order.assign([0,1,2,3])
		for index in range(3,0,-1):
			var other := rng.randi_range(0,index)
			var saved := order[index]
			order[index] = order[other]
			order[other] = saved
	floor_index = 0
	room_index = 0
	defeated.clear()
	deprivations.clear()
	shards.clear()
	boons.clear()
	fragment_state.clear()
	selections.clear()
	hp = MetaProgression.maximum_health()
	rerolls = MetaProgression.starting_rerolls()
	crown_strength = 0.5
	_transitioning = false
	_dead = false
	_starter_given = false
	entry_reward_claimed = false
	suppress_entry_history_voice = false
	_epoch += 1
	if persist_history:
		MetaProgression.record_history(run_count,last_death_depth,str(last_death_cause))
	changed.emit()
	return true

func start_opening_run(audio: AudioStreamPlayer) -> bool:
	# Publish the opening flag, history and first room in the same store write.
	if _transitioning or not begin_run(-1, false):
		return false
	prepare_departure(true)
	_transitioning = true
	_load_current(_epoch, true, true, audio)
	return true

func prepare_departure(completes_opening := false) -> void:
	# Apply permanent talents and checkpoint the run before the first combat Player.
	if _departure_prepared or floor_index != 0 or room_index != 0:
		return
	_departure_prepared = true
	hp = MetaProgression.maximum_health()
	rerolls = MetaProgression.starting_rerolls()
	var rng := RandomNumberGenerator.new()
	rng.seed = run_seed ^ 152013
	var starting := MetaProgression.starting_boon(rng)
	if starting != null:
		boons.append(starting)
	entry_reward_claimed = false
	# Boundary 1: the run stands at the first room's doorstep. Nothing earned,
	# nothing claimed, no mid-room state can leak into the checkpoint.
	_checkpoint_active_run(completes_opening)

## Boundary 2/3 shared writer. Only room-start state is ever captured: a resume
## restarts the room, so unfinished kills must stay in memory, not on disk.
func _checkpoint_active_run(completes_opening := false) -> bool:
	if not active or completed or _dead or run_id.is_empty():
		return false
	var snapshot := _active_run_snapshot()
	if completes_opening:
		return MetaProgression.mark_opening_completed(snapshot, _history())
	return MetaProgression.save_active_run(snapshot)

func _active_run_snapshot() -> Dictionary:
	var boon_ids: Array[String] = []
	for card in boons:
		if card is BoonData:
			boon_ids.append(card.id)
	return {
		"run_id":run_id,
		"run_seed":run_seed,
		"order":order.duplicate(),
		"floor_index":floor_index,
		"room_index":room_index,
		"defeated":defeated.duplicate(),
		"deprivations":deprivations.duplicate(),
		"shards":shards.duplicate(),
		"hp":float(hp if hp > 0.0 else MetaProgression.maximum_health()),
		"boon_ids":boon_ids,
		"fragment_state":fragment_state.duplicate(true),
		"rerolls":rerolls,
		"selections":selections.duplicate(true),
		"entry_reward_claimed":entry_reward_claimed,
		"earned_will":earned_will,
		"earned_anchors":earned_anchors,
		"defiance_consumed":MetaProgression.defiance_consumed,
	}

## A spent revival is a monotonic safety latch: leaving mid-room must not hand
## the player a fresh defiance, but the same room's unfinished kills stay
## excluded. Only the boolean is rewritten.
func _revived_for_checkpoint(_player: Player) -> void:
	if run_id.is_empty() or MetaProgression.active_run.is_empty():
		return
	if str(MetaProgression.active_run.get("run_id","")) != run_id:
		return
	if bool(MetaProgression.active_run.get("defiance_consumed",false)):
		return
	var updated: Dictionary = MetaProgression.active_run.duplicate(true)
	updated["defiance_consumed"] = true
	MetaProgression.save_active_run(updated)

## Rebuilds the whole campaign from the stored room-start snapshot and installs
## that room. Callers route here instead of begin_run when a checkpoint exists.
func resume_run(stage_scene: PackedScene = null) -> bool:
	var snapshot: Dictionary = MetaProgression.active_run
	if snapshot.is_empty():
		return false
	var restored_boons: Array = []
	for boon_id in snapshot.get("boon_ids",[]):
		var card := _boon_by_id(str(boon_id))
		if card == null:
			return false
		restored_boons.append(card)
	active = true
	completed = false
	_dead = false
	_settled = false
	_transitioning = false
	run_id = str(snapshot.get("run_id",""))
	run_seed = int(snapshot.get("run_seed",0))
	order.assign(snapshot.get("order",[]))
	floor_index = int(snapshot.get("floor_index",0))
	room_index = int(snapshot.get("room_index",0))
	defeated.assign(snapshot.get("defeated",[]))
	deprivations.assign(snapshot.get("deprivations",[]))
	shards.assign(snapshot.get("shards",[]))
	hp = float(snapshot.get("hp",MetaProgression.maximum_health()))
	boons = restored_boons
	fragment_state = snapshot.get("fragment_state",{}).duplicate(true)
	rerolls = int(snapshot.get("rerolls",0))
	selections.clear()
	for entry in snapshot.get("selections",[]):
		if entry is Dictionary:
			selections.append(entry.duplicate(true))
	entry_reward_claimed = bool(snapshot.get("entry_reward_claimed",false))
	earned_will = int(snapshot.get("earned_will",0))
	earned_anchors = int(snapshot.get("earned_anchors",0))
	crown_strength = 0.5 * pow(2.4,defeated.size())
	_rewarded_kills.clear()
	_rewarded_rooms.clear()
	_starter_given = false
	# The saved run already passed its departure; re-running the starter gift
	# here would duplicate an "初见锋芒" boon.
	_departure_prepared = true
	suppress_entry_history_voice = true
	MetaProgression.active_run_id = run_id
	MetaProgression.defiance_consumed = bool(snapshot.get("defiance_consumed",false))
	_epoch += 1
	changed.emit()
	var packed := stage_scene if stage_scene != null else load(scene_path()) as PackedScene
	if packed == null:
		return false
	return install_stage(packed) == OK

## Title-screen "return to the stasis hub": lock in the currency the player had
## already earned up to the last room boundary and drop the checkpoint.
func abandon_active_run() -> bool:
	var snapshot: Dictionary = MetaProgression.active_run.duplicate(true)
	if snapshot.is_empty():
		return false
	var id := str(snapshot.get("run_id",""))
	if not id.is_empty() and not MetaProgression.settled_runs.has(id):
		if not MetaProgression.settle_run(id,int(snapshot.get("earned_will",0)),int(snapshot.get("earned_anchors",0))):
			settlement_error = MetaProgression.last_error if not MetaProgression.last_error.is_empty() else "无法保存本局结果"
			return false
	MetaProgression.clear_active_run()
	_settled = true
	_finish_abandoned_run()
	return true

func _finish_abandoned_run() -> void:
	active = false
	completed = false
	_dead = false
	_transitioning = false
	run_id = ""
	earned_will = 0
	earned_anchors = 0
	boons.clear()
	fragment_state.clear()
	defeated.clear()
	deprivations.clear()
	shards.clear()
	selections.clear()
	floor_index = 0
	room_index = 0
	hp = -1.0
	run_seed = 0
	order.clear()
	rerolls = RunState.STARTING_REROLLS
	crown_strength = 0.5
	_rewarded_kills.clear()
	_rewarded_rooms.clear()
	entry_reward_claimed = false
	suppress_entry_history_voice = false
	_departure_prepared = false
	_starter_given = false
	current_stage = null
	_epoch += 1
	changed.emit()

func reset_campaign() -> bool:
	if not MetaProgression.reset_profile():
		return false
	run_count = 0
	last_death_depth = 0
	last_death_cause = &""
	_settled = false
	settlement_error = ""
	if is_instance_valid(_save_notice):
		_save_notice.queue_free()
	_save_notice = null
	_save_retry = null
	_finish_abandoned_run()
	return true

func _boon_by_id(id: String) -> BoonData:
	for card in BoonCatalog.all():
		if card.id == id:
			return card
	return null

func _history() -> Dictionary:
	return {"run_count":run_count,"last_depth":last_death_depth,"death_cause":str(last_death_cause)}

func settle_rewards() -> bool:
	# Standalone cinematic fixtures do not own a campaign economy.
	if run_id.is_empty():
		return true
	if _settled or MetaProgression.settled_runs.has(run_id):
		_settled = true
	else:
		_settled = MetaProgression.settle_run(run_id,earned_will,earned_anchors,_history())
	if _settled:
		settlement_error = ""
		if is_instance_valid(_save_notice):
			_save_notice.queue_free()
		_save_notice = null
		_save_retry = null
	else:
		settlement_error = MetaProgression.last_error if not MetaProgression.last_error.is_empty() else "无法保存本局结果"
		_show_save_failure()
	return _settled

func _show_save_failure() -> void:
	if is_instance_valid(_save_notice):
		return
	_save_notice = CanvasLayer.new()
	_save_notice.layer = 90
	_save_notice.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_save_notice)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -360
	panel.offset_right = 360
	panel.offset_top = -100
	panel.offset_bottom = 100
	_save_notice.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",18)
	panel.add_child(column)
	var label := Label.new()
	label.text = "本局收益尚未保存\n%s\n收益仍保留，请重试保存后再开始新挑战。请勿退出游戏。" % settlement_error
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size",24)
	column.add_child(label)
	_save_retry = Button.new()
	_save_retry.text = "重试保存"
	_save_retry.pressed.connect(settle_rewards)
	column.add_child(_save_retry)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func final_duel_defeated(stage: Node, actor: Enemy) -> void:
	if stage != current_stage or floor_index != 4 or not active or _dead or _settled:
		return
	if not is_instance_valid(actor) or not actor.health.is_dead() or stage.encounter.boss != actor:
		return
	var id := actor.get_instance_id()
	if not _rewarded_kills.has(id):
		_rewarded_kills[id] = true
		earned_will += KILL_WILL
	var room_key := "4:0"
	if not _rewarded_rooms.has(room_key):
		_rewarded_rooms[room_key] = true
		earned_will += ROOM_WILL
	changed.emit()

func _enemy_defeated(stage: Node, actor: Enemy) -> void:
	if stage != current_stage or not active or _dead or _settled or not is_instance_valid(actor) or not actor.health.is_dead() or not stage.enemies.has(actor):
		return
	var id := actor.get_instance_id()
	if _rewarded_kills.has(id):
		return
	_rewarded_kills[id] = true
	earned_will += KILL_WILL
	changed.emit()

func _stage_cleared(stage: Node) -> void:
	if stage != current_stage or not active or _dead or _settled or not bool(stage.get("cleared")):
		return
	var key := "%d:%d" % [floor_index,room_index]
	if _rewarded_rooms.has(key):
		return
	_rewarded_rooms[key] = true
	earned_will += ROOM_WILL
	changed.emit()

func _depth_index(depth: int) -> int:
	return clampi(floor_index if depth < 0 else depth,0,3)

func hp_scale(depth: int = -1) -> float:
	return float(HP_SCALES[_depth_index(depth)])

func damage_scale(depth: int = -1) -> float:
	return float(DAMAGE_SCALES[_depth_index(depth)])

func tempo_scale(depth: int = -1, active_deprivations = null) -> float:
	var values: Array = deprivations if active_deprivations == null else active_deprivations
	var value := float(TEMPO_SCALES[_depth_index(depth)])
	if values.has(0):
		value += SLOTH_HASTE
	return value

func difficulty_profile(depth: int = -1) -> Dictionary:
	return {
		"hp_scale":hp_scale(depth),
		"damage_scale":damage_scale(depth),
		"tempo_scale":tempo_scale(depth),
	}

## Backward-compatible scalar entry: it keeps meaning the damage multiplier.
func difficulty(depth: int = -1) -> float:
	return damage_scale(depth)

func current_realm() -> int:
	return order[floor_index] if floor_index < order.size() else -1

func scene_path() -> String:
	if floor_index >= 4:
		return THRESHOLD
	if order.size() != 4:
		return ""
	var suffix := str(room_index+1) if room_index < 2 else "boss"
	return "res://maps/realms/%s_%s.tscn" % [REALMS[current_realm()],suffix]

func defeat_realm(realm: int) -> bool:
	if not active or _dead or room_index != 2 or realm != current_realm() or defeated.has(realm):
		return false
	defeated.append(realm)
	MetaProgression.record_archive(realm,true)
	deprivations.append(realm)
	crown_strength = 0.5 * pow(2.4,defeated.size())
	Events.sin_defeated.emit(defeated.size())
	realm_completed.emit(realm,defeated.size())
	changed.emit()
	return true

func capture_player(player: Player) -> void:
	hp = player.health.health
	boons = player.boons.all_equipped().duplicate()
	shards.assign(player.fragments.shards)
	fragment_state = {
		"barrier":player.fragments.barrier,"recovery":player.fragments._barrier_recovery,
		"counter":player.fragments._counter_left,"charge":player.fragments.spite_charge,
		"since_combat":player.fragments.since_combat,
		"resonance":player.fragments.resonance_cooldown,
		"room_healed":player.fragments.room_healed,
	}

func restore_player(player: Player) -> void:
	MetaProgression.apply_to_player(player)
	if player.boons.all_equipped() != boons:
		player.boons.restore(boons)
	MetaProgression.record_discoveries(player.boons.all_equipped())
	player.fragments.configure_deprivation(deprivations)
	player.fragments.restore(shards)
	if hp >= 0.0:
		player.health.health = clampf(hp,1.0,player.health.max_health)
	if not fragment_state.is_empty():
		player.fragments.barrier = float(fragment_state.get("barrier",0.0))
		player.fragments._barrier_recovery = float(fragment_state.get("recovery",0.0))
		player.fragments._counter_left = float(fragment_state.get("counter",0.0))
		player.fragments.spite_charge = int(fragment_state.get("charge",0))
		player.fragments.since_combat = float(fragment_state.get("since_combat",0.0))
		player.fragments.resonance_cooldown = float(fragment_state.get("resonance",0.0))
		player.fragments.room_healed = float(fragment_state.get("room_healed",0.0))
	var body := player.get_node_or_null("ShadowBody")
	if body != null and body.has_method("set_fracture_level"):
		body.set_fracture_level(defeated.size())
	var crown := player.get_node_or_null("CrownVoiceSystem")
	if crown != null:
		crown.configure_history(run_count,last_death_depth,str(last_death_cause),room_index == 0 and not suppress_entry_history_voice)
		crown.set_fracture_level(defeated.size())
		crown.enter_floor(mini(floor_index+1,5))
	else:
		var radiance := player.get_node_or_null("CrownRadiance") as CrownRadiance
		if radiance == null:
			radiance = CrownRadiance.new()
			radiance.name = "CrownRadiance"
			radiance.position = Vector3(0,1.83,0)
			player.add_child(radiance)
		radiance.set_fracture_level(defeated.size())

func install_stage(packed: PackedScene) -> Error:
	if packed == null or not packed.can_instantiate():
		return ERR_CANT_CREATE
	prepare_departure()
	var next := packed.instantiate()
	if next.has_method("configure_run"):
		next.set("campaign",true)
		next.set("hp_multiplier",hp_scale())
		next.set("difficulty_multiplier",damage_scale())
		next.set("tempo_multiplier",tempo_scale())
		# The room must not add the Sloth haste a second time when the run
		# director already folded it into tempo_multiplier.
		next.set("tempo_includes_sloth_haste",deprivations.has(0))
		next.set("run_seed",run_seed)
		next.set("rerolls_remaining",rerolls)
		if "skip_entry_reward" in next:
			# The opening gift belongs to a fresh 0:0 entry only. A resumed run
			# that already claimed it must not be offered the same card twice.
			next.set("skip_entry_reward",floor_index == 0 and room_index == 0 and entry_reward_claimed)
		next.configure_run(floor_index,deprivations,shards,hp,boons)
		next.realm_defeated.connect(_realm_defeated)
		next.enemy_defeated.connect(_enemy_defeated)
		next.stage_cleared.connect(_stage_cleared)
		next.exit_requested.connect(_stage_exit)
		next.player_fallen.connect(_stage_fallen)
		next.retry_requested.connect(_stage_retry)
		next.hub_requested.connect(_stage_hub, CONNECT_DEFERRED)
		next.title_requested.connect(_stage_title, CONNECT_DEFERRED)
		next.reward_selected.connect(_reward_selected)
		next.reroll_spent.connect(_reroll_spent)
	var previous := get_tree().current_scene
	get_tree().paused = false
	get_tree().root.add_child(next)
	get_tree().current_scene = next
	current_stage = next
	if is_instance_valid(previous):
		previous.queue_free()
	if "player" in next and next.get("player") is Player:
		restore_player(next.get("player"))
	# The suppression belongs to the first restored room only; later floors in
	# the same session must keep their normal entry lines.
	suppress_entry_history_voice = false
	if active and next is RealmStage and current_realm() >= 0:
		MetaProgression.record_archive(current_realm())
	if floor_index >= 4:
		threshold_reached.emit()
	# The opening three-card gift is gone: a fresh run starts with the base
	# loadout and meets its first realm card when the first room is cleared,
	# which is also where the realm's mechanic card gets explained.
	_transitioning = false
	changed.emit()
	return OK

func _realm_defeated(stage: Node) -> void:
	if stage != current_stage or not defeat_realm(int(stage.get("realm"))):
		return
	earned_anchors += 1
	stage.player.fragments.configure_deprivation(deprivations)
	stage.deprivations.assign(deprivations)
	capture_player(stage.player)

func _reward_selected(stage: Node, card: BoonData) -> void:
	if stage != current_stage or _dead:
		return
	selections.append({"floor":floor_index+1,"room":room_index,"realm":current_realm(),"boon_id":card.id})
	capture_player(stage.player)
	if floor_index == 0 and room_index == 0:
		# Boundary 2: the opening choice is spent. It happens before the room is
		# cleared, so no mid-room reward can ride along with this write.
		entry_reward_claimed = true
		_checkpoint_active_run()
	changed.emit()

func _reroll_spent(stage: Node) -> void:
	if stage == current_stage:
		rerolls = maxi(0,int(stage.rerolls_remaining))
		changed.emit()

func _stage_exit(stage: Node) -> void:
	if stage != current_stage or _transitioning or _dead or not active:
		return
	if bool(stage.boss_room) and (not defeated.has(current_realm()) or not stage.player.fragments.has_shard(current_realm())):
		stage.transitioning = false
		return
	capture_player(stage.player)
	rerolls = int(stage.rerolls_remaining)
	if not advance_room():
		stage.transitioning = false
		return
	_transitioning = true
	_load_current.call_deferred(_epoch)

func advance_room() -> bool:
	if not active or _dead or floor_index >= 4:
		return false
	if room_index == 2:
		if not defeated.has(current_realm()) or not shards.has(current_realm()):
			return false
		floor_index += 1
		room_index = 0
	else:
		room_index += 1
	# A new room restores the rest budget only; fragment cooldowns carry over.
	if not fragment_state.is_empty():
		fragment_state["room_healed"] = 0.0
	# Boundary 3: the next room's doorstep, including the floor-5 return corridor.
	_checkpoint_active_run()
	changed.emit()
	return true

func _load_current(epoch: int, require_initial_checkpoint := false, completes_opening := false,
		opening_audio: AudioStreamPlayer = null) -> void:
	if epoch != _epoch or _dead or not active:
		return
	get_tree().paused = true
	var fade := SceneFade.new()
	get_tree().root.add_child(fade)
	if is_instance_valid(opening_audio):
		var start_db := opening_audio.volume_db
		await fade.fade_to_black(0.45, func(progress: float):
			if is_instance_valid(opening_audio):
				opening_audio.volume_db = lerpf(start_db, -60.0, progress))
		if is_instance_valid(opening_audio):
			opening_audio.stop()
	else:
		await fade.fade_to_black(0.22)
	if epoch != _epoch or _dead or not active:
		fade.discard()
		return
	if require_initial_checkpoint and MetaProgression.active_run.get("run_id", "") != run_id:
		if not _checkpoint_active_run(completes_opening):
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			fade.show_error("挑战起点尚未保存，请重试。", func():
				fade.discard()
				_load_current(epoch, true, completes_opening))
			return
	fade.show_loading()
	# Present the overlay before a synchronous load can stall rendering.
	await get_tree().process_frame
	await get_tree().process_frame
	if epoch != _epoch or _dead or not active:
		fade.discard()
		return
	var packed := load(scene_path()) as PackedScene
	if install_stage(packed) != OK:
		_transitioning = false
		get_tree().paused = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		fade.show_error("门扉未能展开，请重试。", func():
			fade.discard()
			_load_current(epoch, require_initial_checkpoint, completes_opening))
		push_error("Cannot load campaign stage: " + scene_path())
		return
	fade.reveal(3,0.35)

func _stage_fallen(stage: Node, cause: StringName) -> void:
	if stage != current_stage:
		return
	record_death(cause)

func _stage_retry(stage: Node) -> void:
	if stage == current_stage:
		restart.call_deferred()

func _stage_hub(stage: Node) -> void:
	if stage == current_stage and _dead:
		enter_hub("post_death")

func _stage_title(stage: Node) -> void:
	if stage == current_stage:
		return_to_title()

func enter_hub(reason := "") -> void:
	if (_dead or completed) and not settle_rewards():
		return
	if MetaProgression.has_active_run() or get_tree().current_scene is StasisHub:
		return
	var hub := (load(STASIS_HUB) as PackedScene).instantiate() as StasisHub
	hub.hub_reason = reason
	hub.run_count = run_count
	hub.last_death_depth = last_death_depth
	hub.last_death_cause = last_death_cause
	hub.departure_requested.connect(_depart_from_hub.bind(hub), CONNECT_DEFERRED)
	hub.title_requested.connect(return_to_title, CONNECT_DEFERRED)
	_install_noncombat_scene(hub)

func _depart_from_hub(hub: StasisHub) -> void:
	if hub != get_tree().current_scene:
		return
	if not begin_run():
		hub.allow_departure_retry()
		return
	suppress_entry_history_voice = hub.hub_reason == "post_death"
	prepare_departure()
	_transitioning = true
	_load_current(_epoch, true)

func return_to_title() -> void:
	if (_dead or completed) and not settle_rewards():
		return
	# This route must leave the latest room checkpoint intact.
	var title := (load(TITLE_ENTRY) as PackedScene).instantiate()
	title.set("allow_cli_bypass", false)
	_install_noncombat_scene(title)

func _install_noncombat_scene(next: Node) -> void:
	var tree := get_tree()
	var previous := tree.current_scene
	active = false
	_dead = false
	_transitioning = false
	current_stage = null
	_epoch += 1
	tree.paused = false
	tree.root.add_child(next)
	tree.current_scene = next
	if is_instance_valid(previous):
		previous.queue_free()
	changed.emit()

func record_death(cause: StringName) -> void:
	if not active or _dead or completed:
		return
	_dead = true
	_transitioning = false
	last_death_depth = mini(floor_index+1,4)
	last_death_cause = cause
	if current_realm() >= 0:
		MetaProgression.record_archive(current_realm())
	if settle_rewards() and not run_id.is_empty():
		# The run is banked, so its checkpoint must not survive as a second life.
		MetaProgression.clear_active_run()
	run_failed.emit(last_death_depth,cause)
	changed.emit()

func _unhandled_input(event: InputEvent) -> void:
	if active and _dead and event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_R:
		get_viewport().set_input_as_handled()
		restart.call_deferred()

func restart() -> void:
	if not _dead or completed:
		return
	if not begin_run():
		return
	prepare_departure()
	_transitioning = true
	_load_current.call_deferred(_epoch)

func finish_campaign() -> void:
	if active and not run_id.is_empty():
		MetaProgression.record_archive(-1,false,true)
	if settle_rewards() and not run_id.is_empty():
		MetaProgression.clear_active_run()
	completed = true
	active = false
	_dead = false
	_epoch += 1
	changed.emit()
