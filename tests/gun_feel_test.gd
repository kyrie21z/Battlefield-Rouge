extends Node
## Headless check of the gun-feel layer (batch 1: firing weight):
##   godot --headless --path . res://tests/gun_feel_test.tscn
## Everything here is presentation. The rays are checked to be unmoved by the
## camera shake, the springs to come back to rest, and the audio voices to keep
## a shot's tail alive when the next one is fired.

var _failures := 0
var _finished := false
var _player: Player
var _weapon: Weapon


func _ready() -> void:
	await _run()
	var ok := _failures == 0 and _finished
	print("%s (%d failed%s)" % ["ALL PASSED" if ok else "FAIL", _failures,
		"" if _finished else ", run did not finish"])
	get_tree().quit(0 if ok else 1)


func _run() -> void:
	_test_spring()
	_test_wav_layers()

	var scene: Node = load("res://maps/zone_1.tscn").instantiate()
	add_child(scene)
	await get_tree().process_frame
	get_tree().paused = false
	_player = scene.get_node("Player") as Player
	_weapon = _player.weapon
	for node in get_tree().get_nodes_in_group("enemy"):
		(node as Enemy).set_physics_process(false)
	_player.global_rotation = Vector3.ZERO
	await _frames(3)

	await _test_viewmodel_spring()
	await _test_camera_shake()
	await _test_scoped_shake()
	await _test_audio_voices()
	await _test_crosshair(scene)
	await _test_hitmarker(scene)
	await _test_enemy_reaction(scene)
	await _test_impacts(scene)
	await _test_tracers()
	await _test_hitstop(scene)
	_finished = true


func _test_spring() -> void:
	print("== the viewmodel spring")
	var spring := ViewSpring.new()
	spring.stiffness = 170.0
	spring.damping = 13.0
	spring.kick(Vector3(0, 0, 0.1), Vector3(5, 1, -2))
	_check("a kick displaces it at once", spring.position.z > 0.099 and spring.rotation.x > 4.99)
	var overshoot := 0.0
	var min_z := 0.0
	for i in 60:
		spring.step(1.0 / 60.0)
		min_z = minf(min_z, spring.position.z)
		overshoot = maxf(overshoot, spring.position.z)
	_check("an underdamped heavy gun swings through rest (z min %.4f < 0)" % min_z, min_z < -0.001)
	for i in 180:
		spring.step(1.0 / 60.0)
	_check("and settles back to rest", spring.is_at_rest())
	_check("exactly where it started (|p|=%.5f |r|=%.4f)" % [spring.position.length(), spring.rotation.length()],
		spring.position.length() < 0.001 and spring.rotation.length() < 0.05)
	# A long frame must not blow the integrator up.
	var wild := ViewSpring.new()
	wild.stiffness = 420.0
	wild.damping = 26.0
	wild.kick(Vector3(0, 0, 0.05), Vector3(2, 0, 0))
	wild.step(0.5)
	_check("a 0.5 s frame stays finite and bounded", wild.position.length() < 0.2 and wild.rotation.length() < 10.0)
	var stack := ViewSpring.new()
	for i in 20:
		stack.kick(Vector3(0, 0, 0.02), Vector3(1, 0, 0))
	_check("a burst of kicks is capped (z %.3f <= %.3f)" % [stack.position.z, 0.02 * ViewSpring.MAX_STACK],
		stack.position.z <= 0.02 * ViewSpring.MAX_STACK + 0.0001)


func _test_wav_layers() -> void:
	print("== procedural sounds")
	for kind in ["gun_rifle", "gun_shotgun", "gun_sniper", "hit_kill", "hit_tink"]:
		var wav := ProceduralAudio.generate(kind)
		var peak := 0
		for i in range(0, wav.data.size(), 2):
			var v := wav.data[i] | (wav.data[i + 1] << 8)
			if v >= 32768:
				v -= 65536
			peak = maxi(peak, absi(v))
		_check("%s has samples (%.2f s) and is not silent or clipped flat" % [kind, wav.get_length()],
			wav.data.size() > 1000 and peak > 4000)
	_check("heavier guns ring longer (rifle < shotgun < sniper)",
		ProceduralAudio.generate("gun_rifle").get_length() < ProceduralAudio.generate("gun_shotgun").get_length()
		and ProceduralAudio.generate("gun_shotgun").get_length() < ProceduralAudio.generate("gun_sniper").get_length())
	_check("generation is deterministic", ProceduralAudio.generate("gun_rifle").data == ProceduralAudio.generate("gun_rifle").data)


func _test_viewmodel_spring() -> void:
	print("== the gun in hand kicks and comes back")
	for slot in 3:
		_weapon.select(slot)
		await _frames(30)
		var view := _weapon._view
		var rest := _weapon.data.hip_position
		_check("%s rests at its hip position" % _weapon.data.display_name,
			view.position.distance_to(rest) < 0.001 and view.rotation.length() < 0.001)
		_weapon._cooldown = 0.0
		_weapon.try_fire()
		_weapon._process(0.0)
		_check("%s: a shot pushes the model back (+z) and the muzzle up" % _weapon.data.display_name,
			view.position.z > rest.z + _weapon.data.view_kick_back * 0.5 and view.rotation.x > 0.0)
		await _frames(150)
		_check("%s: and 2.5 s later it is back (d=%.4f)" % [_weapon.data.display_name, view.position.distance_to(rest)],
			view.position.distance_to(rest) < 0.001 and view.rotation.length() < 0.002)
		_check("kick scales with weight: back %.3f m, rise %.1f deg" % [_weapon.data.view_kick_back,
			_weapon.data.view_kick_pitch], true)
		_weapon.ammo = _weapon.magazine_capacity()
	_check("rifle < shotgun < sniper in kickback", _weapon.data_set[0].view_kick_back < _weapon.data_set[1].view_kick_back
		and _weapon.data_set[1].view_kick_back < _weapon.data_set[2].view_kick_back)
	# Aiming: the spring rides on top of the ADS position instead of fighting it.
	_weapon.select(0)
	Input.action_press("aim")
	await _seconds(0.8)
	var ads := _weapon.data.ads_position
	_check("ADS lerp still lands on ads_position", _weapon._view.position.distance_to(ads) < 0.002)
	_weapon._cooldown = 0.0
	_weapon.try_fire()
	_weapon._process(0.0)
	var kick_ads := _weapon._view.position.z - ads.z
	await _frames(150)
	_check("an ADS shot kicks less (%.4f < %.4f) and returns to ads_position" % [kick_ads, _weapon.data.view_kick_back],
		kick_ads < _weapon.data.view_kick_back and _weapon._view.position.distance_to(ads) < 0.002)
	Input.action_release("aim")
	await _frames(40)


func _test_camera_shake() -> void:
	print("== camera shake leaves the aim alone")
	_weapon.select(1)
	await _frames(20)
	var aim_camera := _player.get_node("Head/Camera3D") as Camera3D
	var aim_before := aim_camera.global_transform
	var fov_before := aim_camera.fov
	_check("the rendering camera is the current one", get_viewport().get_camera_3d() == _player.view_camera)
	_weapon._cooldown = 0.0
	_weapon.try_fire()
	var max_roll := 0.0
	var max_punch := 0.0
	var aim_moved := false
	for i in 20:
		await get_tree().process_frame
		max_roll = maxf(max_roll, _player.view_camera.transform.basis.get_euler().length())
		max_punch = maxf(max_punch, _player.view_camera.fov / aim_camera.fov - 1.0)
		# The recoil (separate from shake) moves the aim; compare against the
		# head, which carries that.
		if not aim_camera.global_transform.is_equal_approx(_player.get_node("Head").global_transform):
			aim_moved = true
	_check("the shot shakes the rendering camera (peak %.2f deg)" % rad_to_deg(max_roll), max_roll > deg_to_rad(0.02))
	_check("and punches the FOV (peak %.1f%%)" % (max_punch * 100.0), max_punch > 0.005)
	_check("the aim camera is never offset from the head by the shake", not aim_moved)
	_check("the aim camera's own FOV is not punched (%.2f)" % aim_camera.fov, absf(aim_camera.fov - fov_before) < 0.5)
	await _frames(40)
	_check("shake dies away to identity", _player.view_camera.transform.is_equal_approx(Transform3D.IDENTITY)
		and not _player.view_is_shaking())
	_check("and the FOV returns to the aimed value", absf(_player.view_camera.fov - aim_camera.fov) < 0.0001)
	# The ray itself, in the middle of a shake, starts from the aim camera.
	_weapon._cooldown = 0.0
	_weapon.try_fire()
	await get_tree().process_frame
	var head := _player.get_node("Head") as Node3D
	_check("mid-shake the ray origin / direction are still the head's",
		_weapon.camera.global_position.is_equal_approx(head.global_position)
		and (-_weapon.camera.global_basis.z).is_equal_approx(-head.global_basis.z))
	_check("aim transform before == after (%s)" % ("same" if aim_before.origin.is_equal_approx(aim_camera.global_transform.origin) else "moved"),
		aim_before.origin.is_equal_approx(aim_camera.global_transform.origin))
	await _frames(40)


func _test_scoped_shake() -> void:
	print("== sniper, scoped: a thump but no blur")
	_weapon.select(2)
	Input.action_press("aim")
	await _frames(40)
	_check("scoped", _weapon.is_scoped())
	var got := []
	var listener := func(degrees: float, punch: float, _duration: float) -> void:
		got.append([degrees, punch])
	_weapon.shake.connect(listener)
	_weapon._cooldown = 0.0
	_weapon.try_fire()
	_weapon.shake.disconnect(listener)
	_check("one shake signal", got.size() == 1)
	if got.size() == 1:
		_check("no rotation shake behind the scope", is_zero_approx(got[0][0]))
		_check("a small FOV punch remains (%.4f)" % got[0][1], got[0][1] > 0.0 and got[0][1] < _weapon.data.shake_fov_punch)
	await _frames(60)
	_check("the scoped aim camera is level", _player.view_camera.transform.is_equal_approx(Transform3D.IDENTITY))
	Input.action_release("aim")
	await _frames(40)


func _test_audio_voices() -> void:
	print("== audio: a burst does not cut the previous tail")
	# Let the earlier shots (the sniper rings for ~1 s) finish first.
	await _seconds(1.5)
	_weapon.select(0)
	_weapon._cooldown = 0.0
	_weapon.ammo = 30
	_weapon.try_fire()
	await get_tree().process_frame
	var first := _playing_voices()
	_weapon._cooldown = 0.0
	_weapon.try_fire()
	await get_tree().process_frame
	var second := _playing_voices()
	_check("shot 1 uses one voice (%d)" % first.size(), first.size() == 1)
	_check("shot 2 uses another and shot 1 is still ringing (%d)" % second.size(), second.size() == 2)
	_check("their pitches differ a little", not is_equal_approx(_weapon._shot_voices[first[0]].pitch_scale,
		_weapon._shot_voices[second[1] if second[0] == first[0] else second[0]].pitch_scale))
	# Reload / dry clicks use their own voice and leave the shots alone.
	_weapon.ammo = 25
	_weapon.try_reload()
	await get_tree().process_frame
	_check("starting a reload does not stop the gunshots", _playing_voices().size() >= 2)
	_check("the reload sound is on its own voice", _weapon._handling_voice.playing)
	_weapon._reload_left = 0.0
	# A voice that is playing is cut by assigning a stream: the reason for the pool.
	var probe := AudioStreamPlayer.new()
	add_child(probe)
	probe.stream = ProceduralAudio.generate("gun_sniper")
	probe.play()
	await get_tree().process_frame
	var was_playing := probe.playing
	probe.stream = ProceduralAudio.generate("gun_rifle")
	print("  (info) re-assigning a stream to a playing player: playing before=%s after=%s" % [was_playing, probe.playing])
	probe.queue_free()
	# Run out of voices: the pool wraps instead of erroring.
	for i in 12:
		_weapon._cooldown = 0.0
		_weapon.ammo = 30
		_weapon.try_fire()
		await get_tree().process_frame
	_check("twelve rapid shots on six voices do not error", true)


func _test_crosshair(scene: Node) -> void:
	print("== crosshair: centre dot, clamped gap, ADS, scope")
	var cross := scene.get_node("HUD/Crosshair") as Crosshair
	_weapon.select(0)
	Input.action_release("aim")
	await _seconds(0.6)
	var draws := cross.dot_draws
	await _frames(2)
	_check("hip: the crosshair is up with its lines", cross.visible and cross.show_lines)
	_check("hip: the centre dot is drawn every frame", cross.dot_draws > draws)
	_check("the lines are short and thin (%.0f px, %.1f px)" % [cross.line_length, cross.thickness],
		cross.line_length <= 6.0 and cross.thickness <= 1.5)
	_check("the dot is 2-3 px with a dark outline (%.1f px)" % cross.dot_size,
		cross.dot_size >= 2.0 and cross.dot_size <= 3.0 and cross.outline >= 1.0)
	cross.gap = 0.5
	_check("a tiny spread keeps the minimum gap (%.1f)" % cross.drawn_gap(), cross.drawn_gap() == cross.min_gap)
	cross.gap = 120.0
	_check("a huge spread is clamped to %.0f px (%.1f)" % [cross.max_gap, cross.drawn_gap()],
		cross.drawn_gap() == cross.max_gap and cross.max_gap <= 24.0)
	var real := cross.gap
	_player.velocity = Vector3(0, 6, 0)
	_weapon._spread = _weapon.data.max_spread
	await _frames(2)
	_check("the real spread still widens the gap (%.1f px, was %.1f)" % [cross.gap, real], cross.gap > 3.0)
	_check("but the drawn gap never exceeds the clamp (%.1f)" % cross.drawn_gap(), cross.drawn_gap() <= cross.max_gap)
	_player.velocity = Vector3.ZERO

	for index in 2:
		_weapon.select(index)
		Input.action_press("aim")
		await _seconds(0.7)
		draws = cross.dot_draws
		await _frames(2)
		var name := _weapon.data.display_name
		_check("%s ADS: the dot stays, the lines go" % name, cross.visible and not cross.show_lines
			and not _weapon.is_scoped())
		_check("%s ADS: the dot is still drawn" % name, cross.dot_draws > draws)
		Input.action_release("aim")
		await _seconds(0.6)

	_weapon.select(2)
	Input.action_press("aim")
	await _seconds(0.7)
	await _frames(2)
	_check("scoped: the scope reticle takes over, no crosshair", _weapon.is_scoped() and not cross.visible)
	Input.action_release("aim")
	await _seconds(0.6)
	await _frames(2)
	_check("scope down: the crosshair is back", cross.visible and cross.show_lines)
	_weapon.select(0)
	await _frames(2)


func _test_hitmarker(scene: Node) -> void:
	print("== hit confirmation: hitmarker and sounds")
	var hud := scene.get_node("HUD")
	var marker := hud.get_node("Hitmarker") as Label
	var body_ogg := hud.get_node("HitAudio") as AudioStreamPlayer
	_weapon.hit_landed.emit(false, false)
	var plain_pop := marker.scale.x
	_check("a plain hit pops the marker above rest (%.2f)" % plain_pop, plain_pop > 1.2)
	await _seconds(0.25)
	_check("and it settles to 1.0 (%.2f)" % marker.scale.x, absf(marker.scale.x - 1.0) < 0.05)
	await _seconds(0.4)
	_weapon.hit_landed.emit(true, false)
	_check("a headshot is gold and pops bigger (%.2f)" % marker.scale.x,
		marker.scale.x > plain_pop and marker.modulate.g > 0.7 and marker.modulate.b < 0.4)
	_check("a headshot plays the ogg and the tink layer together", body_ogg.playing and hud._tink_audio.playing)
	_check("a headshot is not a kill sound", not hud._kill_audio.playing)
	await _seconds(0.5)
	_weapon.hit_landed.emit(false, true)
	var kill_pop := marker.scale.x
	_check("a kill is red and the biggest pop (%.2f)" % kill_pop,
		kill_pop > marker.scale.x - 0.001 and kill_pop >= 2.0 and marker.modulate.r > 0.9 and marker.modulate.g < 0.4)
	_check("a kill plays its own distinct sound", hud._kill_audio.playing)
	_check("the kill sound is not the ogg hit stream", hud._kill_audio.stream != body_ogg.stream)
	await _seconds(0.3)
	_check("the kill marker settles larger than a plain hit (%.2f)" % marker.scale.x, marker.scale.x > 1.3)
	_check("headless: a kill does no hitstop", Engine.time_scale == 1.0 and not HitStop.is_active())
	await _seconds(1.0)


func _test_enemy_reaction(scene: Node) -> void:
	print("== enemy flash and flinch")
	var guard: Enemy
	for node in get_tree().get_nodes_in_group("enemy"):
		guard = node as Enemy
		break
	guard.health.max_health = 100000.0
	guard.health.health = 100000.0
	var reaction := guard.get_node("HitReaction") as HitReaction
	var meshes := guard.find_children("*", "MeshInstance3D", true, false)
	var head_box: Hitbox
	for node in guard.find_children("*", "Hitbox", true, false):
		head_box = node as Hitbox
		break
	(guard.get_node("Model/AnimationPlayer") as AnimationPlayer).pause()
	await get_tree().process_frame
	var hitbox_before := head_box.global_transform
	var snapshot := _ai_snapshot(guard)
	_player.global_position = guard.global_position + Vector3(0, 0, 6)
	var dealt := head_box.apply_hit(20.0, _player)
	_check("the hit landed (%.1f)" % dealt, dealt > 0.0)
	_check("a player hit starts the reaction", reaction.is_playing())
	var overlaid := meshes.filter(func(m: MeshInstance3D) -> bool: return m.material_overlay != null)
	_check("the model's meshes get a flash overlay (%d of %d)" % [overlaid.size(), meshes.size()], overlaid.size() == meshes.size())
	_check("the flash does not touch the meshes' own materials",
		meshes.all(func(m: MeshInstance3D) -> bool: return m.material_override == null))
	var moved := false
	var hitbox_moved := false
	for i in 6:
		await get_tree().process_frame
		for m in meshes:
			if not (m as MeshInstance3D).transform.is_equal_approx(reaction._rest[meshes.find(m)]):
				moved = true
		if not head_box.global_transform.is_equal_approx(hitbox_before):
			hitbox_moved = true
	_check("the meshes flinch", moved)
	_check("the hitboxes never move (bullets land where they always did)", not hitbox_moved)
	await _seconds(0.4)
	_check("everything is put back: no overlay, rest transforms", not reaction.is_playing()
		and meshes.all(func(m: MeshInstance3D) -> bool: return m.material_overlay == null)
		and meshes.all(func(m: MeshInstance3D) -> bool: return m.transform.is_equal_approx(reaction._rest[meshes.find(m)])))
	var after := _ai_snapshot(guard)
	for key in snapshot:
		if key == "health":
			continue
		_check("AI field %s unchanged by the reaction" % key, snapshot[key] == after[key])
	# The global random sequence: play() on its own consumes nothing.
	seed(777)
	var want := randi()
	seed(777)
	reaction.play(_player)
	_check("play() does not touch the global random sequence", randi() == want)
	await _seconds(0.3)
	# Friendly fire / no source does not flash.
	var flash_free := guard.get_node("HitReaction") as HitReaction
	flash_free._on_damaged(5.0, Hitbox.BodyPart.BODY, null)
	_check("damage with no player source shows nothing", not flash_free.is_playing())
	# The boss uses the same component with a smaller flinch.
	var boss: Enemy = load("res://actors/enemy/boss.tscn").instantiate()
	scene.add_child(boss)
	boss.set_physics_process(false)
	await get_tree().process_frame
	var boss_reaction := boss.get_node("HitReaction") as HitReaction
	_check("the boss has a reaction with a gentler flinch", boss_reaction.flinch_scale < 0.5)
	boss_reaction.play(_player, false)
	var boss_meshes := boss.find_children("*", "MeshInstance3D", true, false)
	_check("and it flashes the boss model (%d meshes)" % boss_meshes.size(),
		not boss_meshes.is_empty() and boss_meshes.all(func(m: MeshInstance3D) -> bool: return m.material_overlay != null))
	await _seconds(0.3)
	_check("then restores it", boss_meshes.all(func(m: MeshInstance3D) -> bool: return m.material_overlay == null))
	boss.queue_free()


func _ai_snapshot(enemy: Enemy) -> Dictionary:
	return {
		"state": enemy.state, "velocity": enemy.velocity, "position": enemy.global_position,
		"target": enemy.target, "react": enemy._react_left, "shots": enemy._shots_left,
		"shot_timer": enemy._shot_timer, "cover_left": enemy._cover_left,
		"cover_ready": enemy._cover_ready_at, "impact_left": enemy._impact_left,
		"seek_retry": enemy._seek_retry, "sight_timer": enemy._sight_timer,
		"firing_position": enemy.firing_position, "rotation": enemy.rotation,
		"health": enemy.health.health,
	}


func _test_impacts(scene: Node) -> void:
	print("== impact effects")
	var before := scene.get_child_count()
	Impact.spawn(scene, Vector3(0, 1, 0), Vector3.UP, true, true)
	_check("flesh impact with detail: puff + droplet burst (2 nodes)", scene.get_child_count() == before + 2)
	var flesh_burst := scene.get_child(scene.get_child_count() - 1) as DebrisBurst
	_check("the droplet burst has 6 droplets", flesh_burst != null and flesh_burst.get_child_count() == 6)
	Impact.spawn(scene, Vector3(0, 1, 0), Vector3.UP, false, true)
	var world_burst := scene.get_child(scene.get_child_count() - 1) as DebrisBurst
	_check("world impact: sparks + chips and dust (5 chips + 3 dust)", world_burst != null and world_burst.get_child_count() == 8)
	var count := scene.get_child_count()
	Impact.spawn(scene, Vector3(0, 1, 0), Vector3.UP, false, false)
	_check("detail off: just the sparks", scene.get_child_count() == count + 1)
	var flesh := scene.get_child(scene.get_child_count() - 1) as Impact
	var sparks := flesh.amount
	_check("sparks are denser than before (%d > 10)" % sparks, sparks > 10)
	# Nothing the bursts add draws from the global sequence.
	seed(31337)
	Impact.spawn(scene, Vector3(0, 1, 0), Vector3.UP, false, false)
	var without := randi()
	seed(31337)
	Impact.spawn(scene, Vector3(0, 1, 0), Vector3.UP, false, true)
	var with_detail := randi()
	_check("the droplet / chip / dust bits consume no global random numbers", without == with_detail)
	var moved_before: Vector3 = (world_burst.get_child(0) as Node3D).position
	await _seconds(0.2)
	_check("the chips fly", (world_burst.get_child(0) as Node3D).position != moved_before)
	await _seconds(1.3)
	_check("every effect frees itself", scene.get_child_count() <= before and DebrisBurst.alive == 0)


func _tracers() -> Array[Node]:
	return get_children().filter(func(n: Node) -> bool: return n is Tracer)


func _test_tracers() -> void:
	print("== tracers")
	_test_tracer_geometry()
	var start := Tracer.spawn(self, Vector3(0, 2, 0), Vector3(0, 2, -40))
	_check("a tracer flies along muzzle -> hit (%.0f m)" % start._distance, absf(start._distance - 40.0) < 0.01
		and start._direction.is_equal_approx(Vector3(0, 0, -1)))
	_check("a sliver of a path draws nothing", Tracer.spawn(self, Vector3.ZERO, Vector3(0, 0, -0.2)) == null)
	var far := Tracer.spawn(self, Vector3.ZERO, Vector3(0, 0, -5000))
	_check("a sky shot is capped (%.0f m)" % far._distance, far._distance <= Tracer.MAX_PATH)
	await _seconds(0.1)
	var thin := start.mesh as BoxMesh
	_check("it is a thin stretched box (thickness %.3f, length %.1f)" % [thin.size.x, start.scale.z],
		thin.size.x < 0.03 and start.scale.z > 1.0)
	await _seconds(1.6)
	_check("tracers free themselves", _tracers().is_empty())

	_weapon.select(0)
	Input.action_release("aim")
	await _seconds(0.5)
	_weapon._cooldown = 0.0
	_weapon.ammo = 30
	_weapon.try_fire()
	await get_tree().process_frame
	_check("one rifle shot draws one tracer (%d)" % _tracers().size(), _tracers().size() == 1)
	await _seconds(1.5)
	_check("the tracer is gone after its short life", _tracers().is_empty())
	_weapon.select(1)
	await _seconds(0.3)
	_weapon._cooldown = 0.0
	_weapon.ammo = 6
	_weapon.try_fire()
	await get_tree().process_frame
	_check("a shotgun blast draws at most %d of its 9 pellets (%d)" % [_weapon.data.max_tracers, _tracers().size()],
		_tracers().size() == _weapon.data.max_tracers)
	await _seconds(1.5)
	_weapon.select(2)
	Input.action_press("aim")
	await _seconds(0.8)
	_check("scoped", _weapon.is_scoped())
	_weapon._cooldown = 0.0
	_weapon.ammo = 5
	_weapon.try_fire()
	await get_tree().process_frame
	_check("scoped sniper still draws a tracer", _tracers().size() == 1)
	Input.action_release("aim")
	await _seconds(0.8)
	_weapon._cooldown = 0.0
	_weapon.ammo = 5
	_weapon.try_fire()
	await get_tree().process_frame
	_check("hip sniper draws a tracer", _tracers().size() == 1)
	await _seconds(1.5)
	# Bullet effects never touch the global random sequence.
	_weapon.select(0)
	await _seconds(1.5)
	_weapon.ammo = 30
	_weapon._cooldown = 0.0
	seed(2024)
	_weapon._tracers_left = 0
	var feel_before := _weapon._feel_rng.state
	_weapon.try_fire()
	var plain := randi()
	_weapon._cooldown = 0.0
	seed(2024)
	_weapon.try_fire()
	var with_effects := randi()
	_check("tracers add no global random draws", plain == with_effects)
	_check("they draw from the private generator instead", _weapon._feel_rng.state != feel_before)
	await _seconds(1.5)


func _test_tracer_geometry() -> void:
	# Observe face centres and widths of the actual mesh in world space. Merely
	# checking _direction misses a mesh stretched along the wrong coordinate axes.
	var cases := {
		"forward": Vector3.FORWARD,
		"yaw 45": Vector3.FORWARD.rotated(Vector3.UP, PI * 0.25),
		"yaw 90": Vector3.FORWARD.rotated(Vector3.UP, PI * 0.5),
		"yaw 135": Vector3.FORWARD.rotated(Vector3.UP, PI * 0.75),
		"pitch up": Vector3(-0.4, 0.6, -0.7).normalized(),
		"pitch down": Vector3(0.4, -0.6, -0.7).normalized(),
		"vertical up": Vector3.UP,
		"vertical down": Vector3.DOWN,
		"nearly vertical": Vector3(0.01, 1.0, -0.01).normalized(),
	}
	var origin := Vector3(4.5, 2.7, -9.3)
	for transformed_parent in [false, true]:
		var parent := Node3D.new()
		add_child(parent)
		if transformed_parent:
			parent.position = Vector3(3, -2, 1)
			parent.rotation = Vector3(0.3, -0.4, 0.25)
			parent.scale = Vector3(2.0, 0.6, 1.7)
		for label: String in cases:
			var direction: Vector3 = cases[label]
			var tracer := Tracer.spawn(parent, origin, origin + direction * 20.0)
			tracer.set_process(false)
			var context := "%s / %s parent" % [label, "rotated and scaled" if transformed_parent else "identity"]
			# At spawn the minimum 0.01m segment is centred on the muzzle. It
			# is shorter than THICKNESS, so explicitly measure the mesh's Z faces.
			_check_tracer_mesh(context + " / initial", tracer,
				origin + direction * 0.005, origin - direction * 0.005, direction)
			tracer._process(6.5 / Tracer.SPEED)
			_check_tracer_mesh(context + " / full flight", tracer,
				origin + direction * 6.5, origin + direction * 1.5, direction)
			tracer._process(16.0 / Tracer.SPEED)
			_check_tracer_mesh(context + " / shortened tail", tracer,
				origin + direction * 20.0, origin + direction * 17.5, direction)
			tracer.free()
		parent.free()


func _check_tracer_mesh(label: String, tracer: Tracer, expected_head: Vector3,
		expected_tail: Vector3, direction: Vector3) -> void:
	var bounds := tracer.mesh.get_aabb()
	var center := bounds.get_center()
	var transform := tracer.global_transform
	var head := transform * (center - Vector3(0, 0, bounds.size.z * 0.5))
	var tail := transform * (center + Vector3(0, 0, bounds.size.z * 0.5))
	var left := transform * (center - Vector3(bounds.size.x * 0.5, 0, 0))
	var right := transform * (center + Vector3(bounds.size.x * 0.5, 0, 0))
	var bottom := transform * (center - Vector3(0, bounds.size.y * 0.5, 0))
	var top := transform * (center + Vector3(0, bounds.size.y * 0.5, 0))
	var width := left.distance_to(right)
	var height := bottom.distance_to(top)
	var axis_dot := (head - tail).normalized().dot(direction)
	var endpoint_error := maxf(head.distance_to(expected_head), tail.distance_to(expected_tail))
	_check("%s: mesh axis %.6f, endpoint error %.6fm, width %.4f x %.4fm" % [
		label, axis_dot, endpoint_error, width, height],
		axis_dot > 0.99999 and endpoint_error < 0.0001
		and absf(width - Tracer.THICKNESS) < 0.0001 and absf(height - Tracer.THICKNESS) < 0.0001)


func _test_hitstop(scene: Node) -> void:
	print("== hitstop")
	_check("headless: HitStop refuses by default", not HitStop.request(get_tree(), 0.05)
		and Engine.time_scale == 1.0)
	HitStop.allow_headless = true
	Engine.time_scale = 0.8
	_check("when allowed, it starts", HitStop.request(get_tree(), 0.06))
	_check("and drops the time scale (%.2f)" % Engine.time_scale, Engine.time_scale < 0.1 and HitStop.is_active())
	_check("a second request while stopping is refused", not HitStop.request(get_tree(), 0.06))
	HitStop.restore()
	_check("restore() puts the scale back at once", Engine.time_scale == 0.8 and not HitStop.is_active())
	Engine.time_scale = 1.0
	# The HUD's own rule: a kill under a fixture never freezes the game.
	RunState.fixture = RunFixture.by_id("FX-001")
	_weapon.hit_landed.emit(false, true)
	_check("a kill under a fixture takes no hitstop", Engine.time_scale == 1.0 and not HitStop.is_active())
	RunState.fixture = null
	_weapon.hit_landed.emit(false, true)
	_check("a kill in an ordinary run does", HitStop.is_active() and Engine.time_scale < 0.1)
	HitStop.restore()
	Engine.time_scale = 0.8
	HitStop.request(get_tree(), 0.06)
	scene.free()
	_check("the scene vanishing mid-stop does not cancel the restore", HitStop.is_active())
	await get_tree().create_timer(0.3, true, false, true).timeout
	_check("it restores the previous scale on its own (%.2f)" % Engine.time_scale,
		is_equal_approx(Engine.time_scale, 0.8) and not HitStop.is_active())
	Engine.time_scale = 1.0
	# The HUD refuses it under a fixture. Build the HUD condition directly.
	HitStop.restore()
	_check("restore() is idempotent and safe", Engine.time_scale == 1.0)
	HitStop.allow_headless = false


func _playing_voices() -> Array[int]:
	var out: Array[int] = []
	for i in _weapon._shot_voices.size():
		if _weapon._shot_voices[i].playing:
			out.append(i)
	return out


func _seconds(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func _check(label: String, ok: bool) -> void:
	if not ok:
		_failures += 1
	print("  [%s] %s" % ["ok" if ok else "FAIL", label])
