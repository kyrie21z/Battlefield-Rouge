extends Node3D
## Headless check of Ticket 05: the obsidian pistol's firing presentation.
##   godot --headless --path . res://tests/obsidian_pistol_feel_test.tscn
## All of it is presentation: the recoil contract, damage and magazine stay put,
## and firing effects never draw from the global random sequence.

const PISTOL := preload("res://weapons/obsidian_pistol/obsidian_pistol.tres")

var _failed := 0
var _finished := false


func _ready() -> void:
	await _run()
	var ok := _failed == 0 and _finished
	print("%s (%d failed%s)" % ["ALL PASSED" if ok else "FAIL", _failed,
		"" if _finished else ", run did not finish"])
	for child in get_children():
		child.queue_free()
	await get_tree().process_frame
	OS.delay_msec(100)
	await get_tree().process_frame
	get_tree().quit(0 if ok else 1)


func _run() -> void:
	_test_data()
	await _test_fire_feedback()
	await _test_low_ammo()
	_test_tracer()
	_finished = true


func _test_data() -> void:
	print("== pistol presentation data")
	var gun := PISTOL as WeaponData
	_check("logic recoil contract is untouched",
		is_equal_approx(gun.camera_kick, 1.2) and is_equal_approx(gun.camera_yaw, 0.3)
		and is_equal_approx(gun.camera_return_time, 0.12) and gun.aim_feel_scale < 1.0)
	_check("camera shake beats the old 0.08 degree / 0.8 percent baseline",
		is_equal_approx(gun.shake_degrees, 0.38) and is_equal_approx(gun.shake_fov_punch, 0.020)
		and is_equal_approx(gun.shake_duration, 0.13))
	_check("view kick and spring use the tuned values",
		is_equal_approx(gun.view_kick_back, 0.042) and is_equal_approx(gun.view_kick_pitch, 3.4)
		and is_equal_approx(gun.view_kick_roll, 1.4) and is_equal_approx(gun.view_spring_stiffness, 520.0)
		and is_equal_approx(gun.view_spring_damping, 28.0))
	_check("damage, fire rate, magazine and falloff are unchanged",
		is_equal_approx(gun.damage, 35.0) and is_equal_approx(gun.fire_interval, 0.18)
		and gun.magazine_size == 8 and is_equal_approx(gun.falloff_start, 30.0)
		and is_equal_approx(gun.falloff_end, 90.0) and is_equal_approx(gun.min_damage_scale, 0.5))
	var spring := ViewSpring.new()
	spring.stiffness = gun.view_spring_stiffness
	spring.damping = gun.view_spring_damping
	spring.kick(Vector3(0.0, 0.0, gun.view_kick_back),
		Vector3(gun.view_kick_pitch, 0.0, gun.view_kick_roll))
	for i in 150:
		spring.step(1.0 / 60.0)
	_check("the tuned spring settles inside 150 frames (|p|=%.5f |r|=%.4f)"
		% [spring.position.length(), spring.rotation.length()], spring.is_at_rest())


func _test_fire_feedback() -> void:
	print("== firing kick, core flare and muzzle light")
	var weapon := _make_weapon()
	var view := weapon._view as ObsidianPistolView
	var slide := view._pieces[ObsidianPistolView.SLIDE_INDEX]
	var rest := view._rest[ObsidianPistolView.SLIDE_INDEX]
	var light := view.get_node_or_null("Muzzle/MuzzleLight") as OmniLight3D
	_check("the muzzle carries an unshadowed cold-blue light",
		light != null and not light.shadow_enabled and light.light_color.b > light.light_color.r)
	_check("every firing effect starts parked",
		slide.transform.is_equal_approx(rest) and not light.visible
		and is_equal_approx(view._core_material.emission_energy_multiplier,
			ObsidianPistolView.CORE_BASE_ENERGY))

	weapon._cooldown = 0.0
	_check("the shot lands", weapon.try_fire())
	var kick := slide.position.z - rest.origin.z
	_check("the slide snaps back +Z by 0.032 m (%.3f)" % kick,
		absf(kick - ObsidianPistolView.FIRE_KICK_BACK) < 0.0005
		and is_equal_approx(slide.position.x, rest.origin.x))
	_check("the core flares from 1.5 to 5.5",
		is_equal_approx(view._core_material.emission_energy_multiplier, ObsidianPistolView.CORE_PULSE_ENERGY))
	_check("the muzzle light is lit at once", light.visible and light.light_energy > 0.0)

	view._process(0.05)
	_check("past 45 ms the muzzle light is out", not light.visible and light.light_energy == 0.0)
	_check("the core is already falling back (%.2f)" % view._core_material.emission_energy_multiplier,
		view._core_material.emission_energy_multiplier < ObsidianPistolView.CORE_PULSE_ENERGY
		and view._core_material.emission_energy_multiplier > ObsidianPistolView.CORE_BASE_ENERGY)
	view._process(0.05)
	_check("past 90 ms the slide is exactly home", slide.transform.is_equal_approx(rest))
	_check("past 100 ms the core is back at 1.5",
		is_equal_approx(view._core_material.emission_energy_multiplier, ObsidianPistolView.CORE_BASE_ENERGY))

	weapon._cooldown = 0.0
	_check("a second shot lands", weapon.try_fire())
	get_tree().paused = true
	view._process(1.0)
	_check("a paused tree freezes the kick, flare and light",
		slide.position.z - rest.origin.z > ObsidianPistolView.FIRE_KICK_BACK * 0.9 and light.visible
		and is_equal_approx(view._core_material.emission_energy_multiplier, ObsidianPistolView.CORE_PULSE_ENERGY))
	get_tree().paused = false
	view._process(0.05)
	_check("unpausing lets the light die", not light.visible)
	view._process(0.06)
	_check("and the slide and core return", slide.transform.is_equal_approx(rest)
		and is_equal_approx(view._core_material.emission_energy_multiplier, ObsidianPistolView.CORE_BASE_ENERGY))

	weapon._cooldown = 0.0
	_check("a third shot lands", weapon.try_fire())
	weapon.try_reload()
	_check("reload start parks the slide, light and core",
		not light.visible and slide.transform.is_equal_approx(rest)
		and is_equal_approx(view._core_material.emission_energy_multiplier, ObsidianPistolView.CORE_BASE_ENERGY))
	_check("reload still runs its own 0.85 s clock", is_equal_approx(weapon._reload_left, 0.85))
	weapon.complete_reload()
	weapon._cooldown = 0.0
	_check("a post-reload shot lands", weapon.try_fire())
	_check("and kicks again", slide.position.z - rest.origin.z > 0.03 and light.visible)
	weapon.deactivate()
	_check("deactivation parks every firing effect", not light.visible
		and slide.transform.is_equal_approx(rest)
		and is_equal_approx(view._core_material.emission_energy_multiplier, ObsidianPistolView.CORE_BASE_ENERGY))

	seed(8520)
	var want := randi()
	seed(8520)
	view.kick_fire()
	_check("the firing presentation draws nothing from the global sequence", randi() == want)
	view.reset_fire_feedback()
	weapon.queue_free()
	await get_tree().process_frame


func _test_low_ammo() -> void:
	print("== low-ammo cue")
	var weapon := _make_weapon()
	var low := weapon._low_ammo_voice
	_check("the cue has its own voice, apart from shots and handling",
		low != null and low != weapon._handling_voice and not weapon._shot_voices.has(low)
		and low.stream == ProceduralAudio.generate("pistol_low_ammo"))
	for i in 5:
		weapon._cooldown = 0.0
		_check("shot %d lands with %d rounds left" % [i + 1, weapon.ammo - 1], weapon.try_fire())
		_check("no cue while more than two rounds remain", not low.playing)
	weapon._cooldown = 0.0
	_check("the shot that leaves two rounds lands", weapon.try_fire())
	_check("two rounds left: the crystal tick plays", low.playing)
	_check("and the gunshot tail keeps ringing", _playing_shot_voices(weapon) > 0)
	weapon._cooldown = 0.0
	_check("the shot that leaves one round lands", weapon.try_fire())
	_check("one round left still ticks", low.playing)
	weapon._cooldown = 0.0
	var last_light := weapon._view.get_node_or_null("Muzzle/MuzzleLight") as OmniLight3D
	_check("the last round fires and starts the reload",
		weapon.try_fire() and weapon.ammo == 0 and weapon.is_reloading())
	_check("even the last round ticks before the reload", low.playing)
	_check("final round keeps its brief muzzle light alive during auto-reload",
		last_light != null and last_light.visible and last_light.light_energy > 0.0)
	(weapon._view as ObsidianPistolView)._process(0.05)
	_check("final round muzzle light decays out cleanly", not last_light.visible)
	weapon.deactivate()
	_check("deactivation silences low-ammo voice immediately", not low.playing)
	weapon.queue_free()
	await get_tree().process_frame


func _test_tracer() -> void:
	print("== tracer readability")
	_check("tracers fly at 190 m/s", is_equal_approx(Tracer.SPEED, 190.0))
	_check("tracers are 20 mm wide and still under the 30 mm contract",
		is_equal_approx(Tracer.THICKNESS, 0.020) and Tracer.THICKNESS < 0.03)
	var tracer := Tracer.spawn(self, Vector3(0, 1, 0), Vector3(0, 1, -30))
	tracer.set_process(false)
	tracer._process(0.05)
	_check("50 ms of flight covers 9.5 m (%.2f)" % tracer._travelled,
		absf(tracer._travelled - 9.5) < 0.001 and absf(tracer.scale.z - Tracer.LENGTH) < 0.001)
	tracer._process(0.09)
	_check("the streak stays one 5 m segment (%.2f)" % tracer.scale.z,
		absf(tracer.scale.z - Tracer.LENGTH) < 0.001)
	tracer._process(0.10)
	_check("the tracer frees itself after reaching the target", tracer.is_queued_for_deletion())
	if is_instance_valid(tracer):
		tracer.free()


func _make_weapon() -> Weapon:
	var camera := Camera3D.new()
	add_child(camera)
	var weapon := Weapon.new()
	weapon.data = PISTOL
	weapon.camera = camera
	add_child(weapon)
	weapon.set_process(false)
	(weapon._view as Node).set_process(false)
	return weapon


func _playing_shot_voices(weapon: Weapon) -> int:
	var count := 0
	for voice in weapon._shot_voices:
		if voice.playing:
			count += 1
	return count


func _check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["ok" if ok else "FAIL", label])
	if not ok:
		_failed += 1