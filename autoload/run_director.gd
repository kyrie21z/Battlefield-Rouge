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
var run_id := ""
var earned_will := 0
var earned_anchors := 0
var forge_visited := false
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

func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func begin_run(value_seed: int = -1) -> bool:
	# Never discard a failed settlement when the player asks for another run.
	if not run_id.is_empty() and not _settled and (_dead or completed or earned_will>0 or earned_anchors>0):
		if not settle_rewards():
			return false
	active = true
	completed = false
	current_stage = null
	run_id = "%d-%d-%d" % [int(Time.get_unix_time_from_system()*1000000),OS.get_process_id(),randi()]
	earned_will = 0
	earned_anchors = 0
	_rewarded_kills.clear()
	_rewarded_rooms.clear()
	_settled = false
	forge_visited = false
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
	_epoch += 1
	MetaProgression.record_history(run_count,last_death_depth,str(last_death_cause))
	changed.emit()
	return true

func prepare_departure() -> void:
	# Called after the starting Forge closes, before the first Player is spawned.
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

func difficulty(depth: int = -1) -> float:
	return 1.0 + 0.18 * clampi(floor_index if depth < 0 else depth,0,3)

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
	var body := player.get_node_or_null("ShadowBody")
	if body != null and body.has_method("set_fracture_level"):
		body.set_fracture_level(defeated.size())
	var crown := player.get_node_or_null("CrownVoiceSystem")
	if crown != null:
		crown.configure_history(run_count,last_death_depth,str(last_death_cause),room_index == 0)
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
		next.set("difficulty_multiplier",difficulty())
		next.set("run_seed",run_seed)
		next.set("rerolls_remaining",rerolls)
		next.configure_run(floor_index,deprivations,shards,hp,boons)
		next.realm_defeated.connect(_realm_defeated)
		next.enemy_defeated.connect(_enemy_defeated)
		next.stage_cleared.connect(_stage_cleared)
		next.exit_requested.connect(_stage_exit)
		next.player_fallen.connect(_stage_fallen)
		next.retry_requested.connect(_stage_retry)
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
	changed.emit()
	return true

func _load_current(epoch: int) -> void:
	if epoch != _epoch or _dead or not active:
		return
	get_tree().paused = true
	var fade := SceneFade.new()
	get_tree().root.add_child(fade)
	await fade.fade_to_black(0.22)
	if epoch != _epoch or _dead or not active:
		fade.discard()
		get_tree().paused = false
		return
	fade.show_loading()
	await get_tree().process_frame
	var packed := load(scene_path()) as PackedScene
	if install_stage(packed) != OK:
		_transitioning = false
		get_tree().paused = false
		fade.show_error("门扉未能展开，请重试。",func():_load_current(_epoch))
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

func record_death(cause: StringName) -> void:
	if not active or _dead or completed:
		return
	_dead = true
	_transitioning = false
	last_death_depth = mini(floor_index+1,4)
	last_death_cause = cause
	if current_realm() >= 0:
		MetaProgression.record_archive(current_realm())
	settle_rewards()
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
	get_tree().paused = false
	get_tree().change_scene_to_file("res://ui/game_start.tscn")

func finish_campaign() -> void:
	if active and not run_id.is_empty():
		MetaProgression.record_archive(-1,false,true)
	settle_rewards()
	completed = true
	active = false
	_dead = false
	_epoch += 1
	changed.emit()
