extends Node
var checks := 0
var failures := 0
func check(label: String,passed: bool) -> void:
	checks += 1
	if not passed: failures += 1
	print(("PASS " if passed else "FAIL ")+label)
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()
func _run() -> void:
	check("failure audit is isolated from the real profile",MetaProgression.isolated_profile)
	if not MetaProgression.isolated_profile: get_tree().quit(1);return
	var profile: String = MetaProgression.save_path()
	var barrier := profile+".blocked-parent"
	var file := FileAccess.open(barrier,FileAccess.WRITE)
	file.store_string("test-owned blocker")
	file.close()
	RunDirector.begin_run(152901)
	RunDirector.earned_will=40
	RunDirector.earned_anchors=2
	var id: String=RunDirector.run_id
	var count: int=RunDirector.run_count
	var scene_id:=get_tree().current_scene.get_instance_id()
	var wallet: int=MetaProgression.will_shards
	var anchors: int=MetaProgression.reality_anchors
	MetaProgression.override_path=barrier+"/cannot-save.json"
	RunDirector.record_death(&"abyss")
	check("failed death save keeps the original run ID and every pending reward",RunDirector._dead and not RunDirector._settled and RunDirector.run_id==id and RunDirector.earned_will==40 and RunDirector.earned_anchors==2)
	check("failed save leaves verified wallet unchanged",MetaProgression.will_shards==wallet and MetaProgression.reality_anchors==anchors and not MetaProgression.settled_runs.has(id))
	check("failure exposes a live retry button and clear pending-save message",is_instance_valid(RunDirector._save_notice) and is_instance_valid(RunDirector._save_retry) and not RunDirector.settlement_error.is_empty())
	RunDirector.restart()
	check("death restart cannot discard rewards or change scene while disk is blocked",RunDirector.run_id==id and RunDirector.run_count==count and get_tree().current_scene.get_instance_id()==scene_id and RunDirector._dead)
	check("direct new challenge also refuses to erase pending income",not RunDirector.begin_run(152902) and RunDirector.run_id==id and RunDirector.earned_will==40)
	MetaProgression.override_path=profile
	RunDirector._save_retry.pressed.emit()
	await get_tree().process_frame
	check("actual retry button banks the original run once after disk recovers",RunDirector._settled and MetaProgression.settled_runs.has(id) and MetaProgression.will_shards==wallet+40 and MetaProgression.reality_anchors==anchors+2 and MetaProgression.history.death_cause=="abyss")
	check("successful retry removes the failure notice without restarting gameplay",not is_instance_valid(RunDirector._save_notice) and RunDirector._dead and RunDirector.run_id==id)
	RunDirector.settle_rewards()
	check("repeated retry does not duplicate the saved transaction",MetaProgression.will_shards==wallet+40 and MetaProgression.reality_anchors==anchors+2)
	check("a successful settlement permits exactly one fresh challenge",RunDirector.begin_run(152903) and RunDirector.run_id!=id and RunDirector.earned_will==0 and not RunDirector._dead)
	id=RunDirector.run_id
	RunDirector.earned_will=9
	MetaProgression.override_path=barrier+"/cannot-save.json"
	RunDirector.finish_campaign()
	check("save failure cannot re-enable the completed death loop",RunDirector.completed and not RunDirector.active and not RunDirector._settled and RunDirector.earned_will==9)
	var menu:=preload("res://ui/ending_menu.tscn").instantiate()
	add_child(menu)
	menu._start_new_challenge()
	check("ending menu preserves the failed completed run instead of loading a new scene",RunDirector.completed and RunDirector.run_id==id and get_tree().current_scene.get_instance_id()==scene_id)
	RunDirector.restart()
	check("R restart remains blocked after terminal completion",RunDirector.completed and RunDirector.run_id==id and not RunDirector.active)
	MetaProgression.override_path=profile
	RunDirector._save_retry.pressed.emit()
	await get_tree().process_frame
	check("completed-run retry preserves the terminal state and pays its original ID",RunDirector.completed and not RunDirector.active and MetaProgression.settled_runs.has(id) and MetaProgression.will_shards==wallet+49)
	RunDirector.finish_campaign()
	check("duplicate ending cannot replay a recovered settlement",MetaProgression.will_shards==wallet+49)
	check("explicit new challenge is available after successful terminal save",RunDirector.begin_run(152904) and not RunDirector.completed and RunDirector.run_id!=id and MetaProgression.will_shards==wallet+49)
	menu.queue_free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(barrier))
	for frame in 4: await get_tree().process_frame
	print("META SETTLEMENT GUARD: %d checks, %d failures" % [checks,failures])
	get_tree().quit(1 if failures else 0)
