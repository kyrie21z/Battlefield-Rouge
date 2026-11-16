extends Node
## Native wall-frame benchmark. No screenshot/readback during sampled windows.
var samples: Array[float] = []
var last := 0
var output := "res://.runtime/fear-hitches.json"
var entry := false
var rows: Array[Dictionary] = []
func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	if last > 0: samples.append((now-last)/1000.0)
	last = now
func frames(count: int) -> void:
	for index in count: await get_tree().process_frame
func window(label: String, cost: float, count := 24, seconds := 0.0) -> void:
	if seconds > 0.0: await get_tree().create_timer(seconds).timeout
	else: await frames(count)
	var sorted := samples.duplicate()
	sorted.sort()
	var row := {"event":label,"cpu_ms":cost,"frame_max_ms":sorted[-1] if not sorted.is_empty() else 0.0,"frame_p95_ms":sorted[int((sorted.size()-1)*0.95)] if not sorted.is_empty() else 0.0,"time_scale":Engine.time_scale}
	rows.append(row)
	print(JSON.stringify(row))
	samples.clear()
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): output = arg.trim_prefix("--out=")
		if arg == "--entry": entry = true
	var stage := load("res://maps/realms/fear_1.tscn").instantiate() as RealmStage
	add_child(stage)
	var master: FearReaper
	for actor in stage.enemies:
		actor.set_physics_process(false)
		if actor is FearReaper: master = actor
	stage.player.set_physics_process(false)
	stage.player.set_process_unhandled_input(false)
	stage.player.health.invulnerable = true
	master.position = Vector3(0,0.05,10)
	stage.player.aim_at(Vector3(0,1.5,10))
	if entry:
		stage.offer_entry_reward()
		await frames(60)
		stage.selection._choose(stage._reward_offer[0])
	await frames(90)
	samples.clear()
	await window("idle",0.0,60)
	for trial in 3:
		samples.clear()
		var started := Time.get_ticks_usec()
		master._summon()
		var cost := (Time.get_ticks_usec()-started)/1000.0
		for wisp in master.living_wisps():
			wisp.set_physics_process(false)
			wisp.visual.advance(0,1,true)
		await window("summon-%d" % trial,cost)
		started = Time.get_ticks_usec()
		master._dismiss_wisps()
		await window("dismiss-%d" % trial,(Time.get_ticks_usec()-started)/1000.0)
	for actor in stage.enemies:
		samples.clear()
		stage.player.aim_at(actor.position+Vector3.UP)
		await frames(20)
		samples.clear()
		var started := Time.get_ticks_usec()
		actor.health.apply_damage(100000,Hitbox.BodyPart.BODY,stage.player,{"true_damage":true})
		var cost := (Time.get_ticks_usec()-started)/1000.0
		await window("death-%d" % stage.enemies.find(actor),cost,40)
		get_tree().paused = false
	# Clear now creates a world pickup. Sample its full animation and claim apart
	# from the killing frame, rather than calling all three events a reward popup.
	if stage.orb_pending():
		stage.player.aim_at(stage.talent_orb.global_position)
		samples.clear()
		await window("orb-assembly",0.0,0,stage.talent_orb.assembly_seconds()+1.3)
		samples.clear()
		var claim_start := Time.get_ticks_usec()
		stage.claim_talent()
		await window("orb-claim-picker",(Time.get_ticks_usec()-claim_start)/1000.0,40)
		stage.selection._choose(stage._reward_offer[0])
		await frames(3)
	await frames(180)
	stage.queue_free()
	await frames(5)
	var boss_stage := load("res://maps/realms/fear_boss.tscn").instantiate() as RealmStage
	add_child(boss_stage)
	boss_stage.boss.set_physics_process(false)
	boss_stage.player.set_physics_process(false)
	boss_stage.player.set_process_unhandled_input(false)
	boss_stage.player.aim_at(boss_stage.boss.position+Vector3.UP*4)
	await frames(60)
	samples.clear()
	var started := Time.get_ticks_usec()
	boss_stage.boss.health.apply_damage(100000,Hitbox.BodyPart.BODY,boss_stage.player,{"true_damage":true})
	await window("death-boss",(Time.get_ticks_usec()-started)/1000.0,60)
	get_tree().paused = false
	boss_stage.queue_free()
	await frames(5)
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	var file := FileAccess.open(output,FileAccess.WRITE)
	file.store_string(JSON.stringify(rows,"  "))
	OS.delay_msec(250)
	get_tree().quit()
