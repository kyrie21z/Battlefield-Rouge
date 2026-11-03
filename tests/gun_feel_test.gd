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
	for kind in ["gun_rifle", "gun_shotgun", "gun_sniper", "hit_kill", "hit_tink", "shell"]:
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
