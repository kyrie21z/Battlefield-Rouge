extends Node
## Native evidence for persistent capacity shielding on a real playable map.
## A legacy fixture grants the old shield perk; current entry uses boon cards.
## Physical G input and hostile Projectile hits exercise the real shield.
## Other AI is frozen to isolate shielding; no shield clock/state is assigned.

var _out := "res://artifacts/counter-pressure-native"
var _checks := 0
var _failures := 0
var _finished := false
var _seconds := 0.0
var _scene: Node3D
var _player: Player
var _source: SlothEnemy
var _pulses := 0
var _shots: Array[String] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):_out=arg.trim_prefix("--out=")
	if DisplayServer.get_name()=="headless":
		push_error("Counter pressure visual proof requires native Forward+")
		get_tree().quit(1)
		return
	_out=ProjectSettings.globalize_path(_out)
	_check(DirAccess.make_dir_recursive_absolute(_out)==OK,"proof directory is writable")
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
	DisplayServer.window_set_title("持续反击盾验证（自动结束）")
	_run.call_deferred()

func _process(delta: float) -> void:
	_seconds+=delta
	if _seconds>45.0 and not _finished:
		push_error("Counter pressure proof timed out")
		get_tree().quit(1)

func _run() -> void:
	_check(RenderingServer.get_current_rendering_method()=="forward_plus","native Forward+ renderer")
	var fixture := RunFixture.new()
	fixture.id = "LEGACY-COUNTER-PROOF"
	fixture.description = "Legacy shield-only visual fixture; not a new boon reward"
	fixture.run_seed = 20261108
	fixture.buffs.assign([BuffPool.ALL[6]])
	RunState.start_fixture(fixture)
	_scene=load("res://maps/zone_1.tscn").instantiate() as Node3D
	add_child(_scene)
	var director := _scene.get_node("ZoneDirector") as ZoneDirector
	_player=_scene.get_node("Player") as Player
	var minions := get_tree().get_nodes_in_group("enemy")
	for enemy in minions:
		enemy.set_physics_process(false)
		if enemy is SlothEnemy:enemy._cancel_attack()
	_check(minions.size()==7,"proof uses the authored increased first wave")
	_check(director.selection!=null,"real opening card UI is present")
	(director.selection.get_node("Center/Box/Choices").get_child(0) as Button).pressed.emit()
	await get_tree().process_frame
	_player.boons.clear() # Isolate the historical shield from new family effects.
	_check(_player.shield.is_unlocked() and _player.shield.is_counter_mode(),"explicit legacy fixture unlocks persistent shielding")
	_check(is_equal_approx(_player.shield.capacity(),100.0),"default capacity is 100 absorbed damage")
	_player.set_physics_process(false)
	_player.set_process_unhandled_input(false)
	_player.weapon.set_process(false)
	_player.global_position=Vector3(0,0.05,14)
	_player.velocity=Vector3.ZERO
	_source=_scene.get_node("Enemy1") as SlothEnemy
	_source.global_position=Vector3(0,0,10)
	_source.velocity=Vector3.ZERO
	_player.aim_at(_source.global_position+Vector3.UP*1.2)
	_player.combat_traits.shield_pulsed.connect(func():_pulses+=1)
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	for frame in 4:await get_tree().physics_frame
	await RenderingServer.frame_post_draw
	var baseline := get_viewport().get_texture().get_image()
	var initial_hp := _player.health.health
	var target_hp := _source.health.health
	print("SHIELD_PROOF_READY | paused=",get_tree().paused," | process=",_player.shield.is_processing()," | mouse=",Input.mouse_mode," | HP=",initial_hp," | immunity=",_player.health.invulnerable,"/",_player.health.dash_invulnerable)
	await _key(KEY_G)
	_check(_player.shield.is_active() and _player.shield._overlay.visible,"physical G raises the actual visible shield")
	await get_tree().create_timer(3.2).timeout
	_check(_player.shield.is_active() and _player.shield._overlay.visible and _pulses==0,
		"uncharged shield remains visible past the old two-second expiry")
	var persistent_frame := await _shot("01-persistent-idle")
	var rim := Rect2i(int(baseline.get_width()*0.025),int(baseline.get_height()*0.28),
		int(baseline.get_width()*0.10),int(baseline.get_height()*0.35))
	_check(_pixel_change(baseline,persistent_frame,rim)>0.008,"native pixels retain a visible shield rim past the old lifetime")
	await _projectile_hit(35.0,35.0)
	_check(_player.health.health==initial_hp and is_equal_approx(_player.shield.absorbed_damage(),35.0),
		"actual hostile projectile stores 35 damage without HP loss")
	await get_tree().create_timer(2.2).timeout
	_check(_player.shield.is_active() and _player.shield._overlay.visible and _player.shield._overlay.charged,
		"partial charge keeps the shield and its sustained visual until release")
	_check(_pulses==0 and is_equal_approx(_source.health.health,target_hp),"partial absorption never auto-releases on a timer")
	await _shot("02-persistent-charged")
	await _key(KEY_G)
	_check(not _player.shield.is_active() and _pulses==1,"physical G manually releases the partially charged shield once")
	_check(is_equal_approx(_source.health.health,target_hp-35.0),"manual pulse deals exactly the absorbed 35 damage to a real nearby Sloth enemy")
	_check(_player.shield.cooldown_remaining>7.0 and _player.shield._overlay.counter_remaining>0.0,
		"manual release starts cooldown and the outgoing visual wave")
	await get_tree().create_timer(0.16).timeout
	await _shot("03-manual-reflect")
	await _key(KEY_G)
	_check(not _player.shield.is_active() and _pulses==1,"repeated G during cooldown cannot duplicate the pulse")
	await get_tree().create_timer(8.1).timeout
	await _key(KEY_G)
	_check(_player.shield.is_active() and is_zero_approx(_player.shield.absorbed_damage()),"after normal cooldown G raises a fresh empty shield")
	await _projectile_hit(40.0,40.0)
	_check(_player.shield.is_active() and _pulses==1,"40 damage stays held below capacity")
	await _projectile_hit(60.0,100.0)
	_check(not _player.shield.is_active() and _pulses==2 and _player.shield.last_release_automatic,
		"the hit reaching 100 capacity automatically releases exactly one counter")
	_check(_player.health.health==initial_hp and _source.health.is_dead(),
		"full shield blocks exactly 100 and its actual pulse defeats the nearby remaining target")
	_check(is_equal_approx(_player.shield.last_released_damage,100.0) and _player.shield._overlay.counter_remaining>0.0,
		"automatic release records 100 and keeps its native outgoing wave visible")
	await get_tree().create_timer(0.16).timeout
	await _shot("04-auto-reflect")
	var report := {"checks":_checks,"failures":_failures,"renderer":RenderingServer.get_current_rendering_method(),
		"adapter":RenderingServer.get_video_adapter_name(),"capacity":_player.shield.capacity(),"manual_absorbed":35.0,
		"automatic_absorbed":100.0,"pulse_count":_pulses,"screenshots":_shots,
		"staging":"Real zone_1 with explicit legacy skill_unlock fixture, current boon entry accepted then removed for isolation, physical G, actual hostile Projectiles. Other AI frozen and one authored Sloth target placed four metres ahead; normal shield clocks and damage remain unchanged. This does not demonstrate a current boon award."}
	var file := FileAccess.open(_out.path_join("counter-report.json"),FileAccess.WRITE)
	if file!=null:file.store_string(JSON.stringify(report,"\t")+"\n")
	Input.action_release("shield")
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	_scene.free()
	await get_tree().process_frame
	OS.delay_msec(100)
	_finished=true
	print("COUNTER_PRESSURE_NATIVE | ",_checks," checks | ",_failures," failures")
	get_tree().quit(0 if _failures==0 else 1)

func _projectile_hit(amount: float, accumulated: float) -> void:
	var projectile := Projectile.spawn(_scene,_player.global_position+Vector3(0,1.0,-0.85),Vector3.BACK,
		_source,amount,12.0,_source._hitbox_rids)
	for frame in 30:
		await get_tree().physics_frame
		if accumulated>=100.0 and not _player.shield.is_active():return
		if is_equal_approx(_player.shield.absorbed_damage(),accumulated):return
	print("SHIELD_PROJECTILE_TIMEOUT | valid=",is_instance_valid(projectile)," | position=",projectile.global_position if is_instance_valid(projectile) else Vector3.INF," | shield=",_player.shield.is_active()," | HP=",_player.health.health," | immunity=",_player.health.invulnerable,"/",_player.health.dash_invulnerable)
	_check(false,"hostile projectile failed to reach expected absorption")

func _key(code: int) -> void:
	await get_tree().process_frame
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	var event := InputEventKey.new()
	event.physical_keycode=code
	event.keycode=code
	event.pressed=true
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	print("SHIELD_PROOF_KEY | mouse=",Input.mouse_mode," | just_pressed=",Input.is_action_just_pressed("shield")," | bindings=",InputMap.action_get_events("shield"))
	for frame in 2:await get_tree().process_frame
	event=event.duplicate()
	event.pressed=false
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	for frame in 2:await get_tree().process_frame

func _shot(title: String) -> Image:
	await RenderingServer.frame_post_draw
	var path := _out.path_join(title+".png")
	var frame := get_viewport().get_texture().get_image()
	_check(frame.save_png(path)==OK,"native screenshot saved: "+title)
	_shots.append(path)
	return frame

func _pixel_change(before: Image,after: Image,area: Rect2i) -> float:
	var total := 0.0
	var count := 0
	for y in range(area.position.y,area.end.y,3):
		for x in range(area.position.x,area.end.x,3):
			var a := before.get_pixel(x,y)
			var b := after.get_pixel(x,y)
			total+=(absf(a.r-b.r)+absf(a.g-b.g)+absf(a.b-b.b))/3.0
			count+=1
	return total/maxf(float(count),1.0)

func _check(ok: bool,message: String) -> void:
	_checks+=1
	if not ok:_failures+=1
	print("PASS | " if ok else "FAIL | ",message)
