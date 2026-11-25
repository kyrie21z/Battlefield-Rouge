extends Node
var checks := 0
var failures := 0
func check(title: String,value: bool) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("FAIL: "+title)
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().create_timer(120,true).timeout.connect(func():get_tree().quit(2))
	check("autoload profile is isolated",MetaProgression.isolated_profile)
	check("new archive is locked",MetaProgression.visited_realms.is_empty() and MetaProgression.defeated_realms.is_empty() and not MetaProgression.reconciled)
	RunDirector.begin_run(175)
	RunDirector.order.assign([0,1,2,3])
	RunDirector.install_stage(load(RunDirector.scene_path()))
	await get_tree().process_frame
	check("production room entry records its realm",MetaProgression.visited_realms==[0])
	check("entry does not unlock protective dossier",MetaProgression.defeated_realms.is_empty())
	RunDirector.floor_index = 1
	RunDirector.install_stage(load(RunDirector.scene_path()))
	var death_stage := RunDirector.current_stage as RealmStage
	death_stage.player.health.apply_damage(99999,Hitbox.BodyPart.BODY,death_stage)
	check("actual player death passes through campaign archive hook",RunDirector._dead and death_stage.fallen and MetaProgression.visited_realms.has(1) and MetaProgression.defeated_realms.is_empty())
	RunDirector.begin_run(175)
	RunDirector.order.assign([0,1,2,3])
	RunDirector.floor_index = 2
	RunDirector.room_index = RunDirector.ROOM_BOSS
	RunDirector.install_stage(load(RunDirector.scene_path()))
	var stage := RunDirector.current_stage as RealmStage
	stage.boss.health.apply_damage(99999,Hitbox.BodyPart.BODY,stage.player)
	await get_tree().process_frame
	check("real realm Boss death unlocks protective dossier",MetaProgression.defeated_realms==[2] and MetaProgression.visited_realms.has(2))
	check("undiscovered sorrow remains locked",not MetaProgression.visited_realms.has(3))
	RunDirector.finish_campaign()
	check("campaign reconciliation unlocks final diary",MetaProgression.reconciled)
	var reader := MetaProgressionStore.new()
	reader.override_path = MetaProgression.save_path()
	add_child(reader)
	check("archive survives fresh load",reader.archive_snapshot()==MetaProgression.archive_snapshot())
	var copy := reader.archive_snapshot()
	copy.visited_realms.clear()
	check("UI snapshot cannot mutate progress",not reader.visited_realms.is_empty())
	check("invalid realm is rejected",not reader.record_archive(4))
	var old_path := reader.override_path
	var blocker := old_path+".blocker"
	var file := FileAccess.open(blocker,FileAccess.WRITE)
	file.store_string("not a directory")
	file.close()
	reader.override_path = blocker+"/save.json"
	check("failed diary write keeps progress pending",not reader.record_archive(3) and reader.codex_save_pending and reader.visited_realms.has(3))
	reader.override_path = old_path
	check("retry persists diary without modifying rewards",reader.save() and not reader.codex_save_pending and reader.will_shards==MetaProgression.will_shards)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(blocker))
	var legacy := reader._payload()
	legacy.erase("archive")
	reader._restore(legacy)
	check("pre-archive payload defaults safely locked",reader.visited_realms.is_empty() and not reader.reconciled)
	reader.queue_free()
	RunDirector.current_stage.queue_free()
	RunDirector.current_stage = null
	get_tree().paused = false
	await get_tree().process_frame
	print("LORE PROGRESS: %d checks, %d failed" % [checks,failures])
	get_tree().quit(0 if failures==0 else 1)
