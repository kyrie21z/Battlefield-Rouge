extends Node
## Headless check of the procedural background music:
##   godot --headless --path . res://tests/music_test.tscn
## The tracks are seamless, deterministic loops that never touch the global
## RNG; the director picks calm / combat / boss from the zone, waits before
## going back to calm, ducks for the buff screen and fades out at the end; the
## music volume setting round-trips and drives the Music bus.

const CONFIG := "user://music_test.cfg"

var _failures := 0
var _finished := false


func _ready() -> void:
	await _run()
	var ok := _failures == 0 and _finished
	print("%s (%d failed%s)" % ["ALL PASSED" if ok else "FAIL", _failures,
		"" if _finished else ", run did not finish"])
	get_tree().quit(0 if ok else 1)


func _run() -> void:
	_test_tracks()
	_test_global_rng()
	await _test_director()
	await _test_zone()
	_test_settings()
	_finished = true


func _test_tracks() -> void:
	print("== tracks")
	for track in ProceduralMusic.TRACKS:
		var wav := ProceduralMusic.generate(track)
		var count := wav.data.size() / 2
		var expected := ProceduralMusic.BARS * 4 * 60.0 / float(ProceduralMusic.BPM[track])
		_check("%s is %.2f s = 8 bars at %d BPM" % [track, wav.get_length(), ProceduralMusic.BPM[track]],
			absf(wav.get_length() - expected) < 0.01 and count == ProceduralMusic.samples_for(track))
		_check("%s loops over the whole buffer" % track,
			wav.loop_mode == AudioStreamWAV.LOOP_FORWARD and wav.loop_begin == 0 and wav.loop_end == count)
		var peak := 0
		var sq := 0.0
		for i in count:
			var v := wav.data.decode_s16(i * 2)
			peak = maxi(peak, absi(v))
			sq += float(v) * v
		var peak_db := linear_to_db(peak / 32767.0)
		var rms_db := linear_to_db(sqrt(sq / count) / 32767.0)
		print("    %s peak %.2f dBFS, rms %.2f dBFS" % [track, peak_db, rms_db])
		_check("%s peaks between -9 and -4 dBFS (%.2f)" % [track, peak_db], peak_db > -9.0 and peak_db < -4.0)
		_check("%s is not near silence (rms %.1f dBFS)" % [track, rms_db], rms_db > -30.0)
		var jump := absi(wav.data.decode_s16(0) - wav.data.decode_s16((count - 1) * 2))
		_check("%s has no click at the loop point (%d)" % [track, jump], jump < 3000)
		_check("%s is the same bytes when rendered again" % track,
			ProceduralMusic._render(track).data == wav.data)
	_check("generate() returns the cached stream",
		ProceduralMusic.generate("calm") == ProceduralMusic.generate("calm"))


func _test_global_rng() -> void:
	print("== the global RNG is untouched")
	seed(12345)
	var a := randi()
	seed(12345)
	ProceduralMusic._render("combat")
	_check("rendering a track does not consume randi()", randi() == a)


func _test_director() -> void:
	print("== director")
	MusicDirector.allow_headless = true
	var music := MusicDirector.new()
	add_child(music)
	await get_tree().process_frame
	music.step(0.1, "calm", false)
	_check("it starts the calm track", music.current_track() == "calm" and music.is_playing())
	_steps(music, 2.0, "calm", false)
	_check("which fades in to full (%.2f)" % music.front_gain(), is_equal_approx(music.front_gain(), 1.0))
	_check("at the base level (%.1f dB)" % music.target_volume_db(),
		is_equal_approx(music.target_volume_db(), MusicDirector.BASE_DB))

	_steps(music, 0.5, "combat", false)
	_check("combat crossfades in at once", music.current_track() == "combat")
	_check("halfway through the crossfade (%.2f)" % music.front_gain(),
		music.front_gain() > 0.2 and music.front_gain() < 0.5)
	_steps(music, 1.2, "combat", false)
	_check("the crossfade takes 1.5 s (%.2f)" % music.front_gain(), is_equal_approx(music.front_gain(), 1.0))

	_steps(music, 5.0, "calm", false)
	_check("5 s of calm keep the combat music", music.current_track() == "combat")
	_steps(music, 0.5, "combat", false)
	_steps(music, 5.5, "calm", false)
	_check("a fight in between restarts the 6 s wait", music.current_track() == "combat")
	_steps(music, 0.7, "calm", false)
	_check("after 6 s it goes back to calm", music.current_track() == "calm")
	print("    state log: calm → combat (0 s) → 5 s lull → combat → 6.2 s lull → calm")

	_steps(music, 0.2, "boss", false)
	_check("the boss track needs no wait", music.current_track() == "boss")
	_steps(music, 2.0, "boss", true)
	_check("the buff screen ducks by 6 dB (%.2f)" % music.front_gain(),
		absf(music.front_gain() - db_to_linear(MusicDirector.DUCK_DB)) < 0.01)
	_check("the target level says so (%.1f dB)" % music.target_volume_db(),
		is_equal_approx(music.target_volume_db(), MusicDirector.BASE_DB + MusicDirector.DUCK_DB))
	_steps(music, 1.0, "boss", false)
	_check("and comes back after (%.2f)" % music.front_gain(), is_equal_approx(music.front_gain(), 1.0))

	Events.player_died.emit()
	_steps(music, 1.0, "boss", false)
	_check("death fades the music (%.2f)" % music.front_gain(), music.front_gain() > 0.3 and music.front_gain() < 0.7)
	_steps(music, 1.1, "boss", false)
	_check("to silence within 2 s", music.front_gain() <= 0.0 and music.target_volume_db() <= -79.0)

	music.queue_free()
	await get_tree().process_frame
	print("    resume points: %s" % MusicDirector._resume)
	_check("a stopped track remembers where it was",
		MusicDirector._resume.has("boss") and MusicDirector._resume.has("calm"))
	MusicDirector._resume.clear()


func _test_zone() -> void:
	print("== in a zone")
	var scene: Node = load("res://maps/zone_1.tscn").instantiate()
	add_child(scene)
	await get_tree().process_frame
	var hud = scene.get_node("HUD")
	var director := scene.get_node("ZoneDirector") as ZoneDirector
	_check("the HUD creates the music director", hud.music != null)
	_check("the buff screen at the start is calm", MusicDirector.desired_track(director) == "calm")
	director.phase = ZoneDirector.Phase.CLEAR_GUARDS
	_check("clearing the guards is combat", MusicDirector.desired_track(director) == "combat")
	director.phase = ZoneDirector.Phase.CLOCK_POINT
	_check("hammering with enemies alive is combat (%d alive)" % director.living_enemies().size(),
		director.living_enemies().is_empty() or MusicDirector.desired_track(director) == "combat")
	director.phase = ZoneDirector.Phase.FLAG_PLANTED
	_check("the planted flag is calm", MusicDirector.desired_track(director) == "calm")
	director.phase = ZoneDirector.Phase.BOSS_STANDING
	_check("the boss phase is boss", MusicDirector.desired_track(director) == "boss")
	director.phase = ZoneDirector.Phase.BUFF_SELECT
	var bus := AudioServer.get_bus_index(&"Music")
	hud.settings.music_volume = 0.5
	hud.settings.changed.emit()
	_check("the HUD sets the Music bus from the setting (%.1f dB)" % AudioServer.get_bus_volume_db(bus),
		absf(AudioServer.get_bus_volume_db(bus) - linear_to_db(0.5)) < 0.01 and not AudioServer.is_bus_mute(bus))
	hud.settings.music_volume = 0.0
	hud.settings.changed.emit()
	_check("0% mutes it", AudioServer.is_bus_mute(bus))
	hud.settings.reset_defaults()
	scene.queue_free()
	# Let the audio server drop the freed players' playbacks before quitting.
	await get_tree().create_timer(0.3, true).timeout
	get_tree().paused = false
	MusicDirector.allow_headless = false
	MusicDirector._resume.clear()


func _test_settings() -> void:
	print("== music volume setting")
	var settings := GameSettings.new()
	_check("the default is 70%", is_equal_approx(settings.music_volume, 0.7))
	settings.music_volume = 0.35
	settings.save_to(CONFIG)
	var loaded := GameSettings.new()
	_check("it round-trips through the config file",
		loaded.load_from(CONFIG) and is_equal_approx(loaded.music_volume, 0.35))
	loaded.music_volume = 1.7
	loaded.clamp_values()
	_check("it is clamped to 100%", is_equal_approx(loaded.music_volume, 1.0))
	loaded.music_volume = -1.0
	loaded.clamp_values()
	_check("and to 0%", loaded.music_volume == 0.0)
	loaded.reset_defaults()
	_check("reset brings back 70%", is_equal_approx(loaded.music_volume, 0.7))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(CONFIG))
	_check("the Music bus exists and sends to Master",
		AudioServer.get_bus_index(&"Music") >= 0
		and AudioServer.get_bus_send(AudioServer.get_bus_index(&"Music")) == &"Master")


func _steps(music: MusicDirector, seconds: float, want: String, ducked: bool) -> void:
	var dt := 1.0 / 60.0
	for i in roundi(seconds / dt):
		music.step(dt, want, ducked)


func _check(label: String, ok: bool) -> void:
	if not ok:
		_failures += 1
	print("  [%s] %s" % ["ok" if ok else "FAIL", label])
