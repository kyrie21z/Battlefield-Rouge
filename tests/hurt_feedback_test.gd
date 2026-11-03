extends Node
## Headless check of the player hurt feedback (vignette, hurt sound, damage
## direction arcs, view flinch and the low-health state):
##   godot --headless --path . res://tests/hurt_feedback_test.tscn
## All of it is presentation. The aim camera must never move and a hit that
## was blocked must stay silent.

var _failures := 0
var _finished := false
var _player: Player
var _health: Health
var _hud
var _indicator: DamageIndicator


func _ready() -> void:
	await _run()
	var ok := _failures == 0 and _finished
	print("%s (%d failed%s)" % ["ALL PASSED" if ok else "FAIL", _failures,
		"" if _finished else ", run did not finish"])
	get_tree().quit(0 if ok else 1)


func _run() -> void:
	_test_sounds()

	var scene: Node = load("res://maps/zone_1.tscn").instantiate()
	add_child(scene)
	await get_tree().process_frame
	get_tree().paused = false
	_player = scene.get_node("Player") as Player
	_health = _player.health
	_hud = scene.get_node("HUD")
	_indicator = _hud.get_node("DamageIndicator") as DamageIndicator
	for node in get_tree().get_nodes_in_group("enemy"):
		(node as Enemy).set_physics_process(false)
	_player.global_rotation = Vector3.ZERO
	await _frames(3)

	await _test_vignette()
	await _test_indicator()
	await _test_merge()
	await _test_blocked()
	await _test_view_shake()
	await _test_low_health()
	_finished = true


func _test_sounds() -> void:
	print("== hurt sounds")
	for kind in ["player_hurt", "player_hurt_heavy", "heartbeat"]:
		var wav := ProceduralAudio.generate(kind)
		var peak := 0
		for i in range(0, wav.data.size(), 2):
			var v := wav.data[i] | (wav.data[i + 1] << 8)
			if v >= 32768:
				v -= 65536
			peak = maxi(peak, absi(v))
		_check("%s has samples (%.2f s) and is audible" % [kind, wav.get_length()],
			wav.data.size() > 1000 and peak > 4000)
	_check("the heavy hurt is longer than the light one",
		ProceduralAudio.generate("player_hurt_heavy").get_length()
			> ProceduralAudio.generate("player_hurt").get_length())
	_check("generation is deterministic",
		ProceduralAudio.generate("player_hurt").data == ProceduralAudio.generate("player_hurt").data)


func _test_vignette() -> void:
	print("== a hit at full HP lights the screen edge")
	await _reset_feedback()
	var plays: int = _hud.hurt_sound_plays
	_damage(10.0, Hitbox.BodyPart.BODY, null)
	_check("the edge lights on the same frame as the hit (%.2f)" % _hud._damage_flash.color.a,
		_hud._damage_flash.color.a >= 0.30)
	_check("and the hurt sound starts at once", _hud.hurt_sound_plays == plays + 1)
	await _seconds(0.1)
	var alpha: float = _hud._damage_flash.color.a
	_check("a 10-damage hit reaches at least 0.30 (%.2f)" % alpha, alpha >= 0.30)
	_check("and stays under the 0.90 cap", alpha <= 0.90)
	await _seconds(1.0)
	_check("it is gone within a second (%.3f)" % _hud._damage_flash.color.a, _hud._damage_flash.color.a <= 0.001)

	await _reset_feedback()
	_damage(45.0, Hitbox.BodyPart.BODY, null)
	alpha = _hud._damage_flash.color.a
	_check("a huge hit is capped at 0.90 (%.2f)" % alpha, alpha <= 0.90 and alpha > 0.85)
	await _seconds(1.0)


func _test_indicator() -> void:
	print("== damage direction arcs")
	await _reset_feedback()
	var behind := _source_at(Vector3(0, 0, 5))
	_damage(10.0, Hitbox.BodyPart.BODY, behind)
	await get_tree().process_frame
	_check("a hit from behind makes one arc", _indicator.entry_count() == 1)
	var angle := _indicator.entry_angle(0)
	_check("it points down (%.0f deg from ahead)" % rad_to_deg(angle),
		absf(absf(angle) - PI) <= deg_to_rad(10.0))
	behind.free()

	await _reset_feedback()
	var right := _source_at(Vector3(5, 0, 0))
	_damage(10.0, Hitbox.BodyPart.BODY, right)
	await get_tree().process_frame
	angle = _indicator.entry_angle(0) if _indicator.entry_count() == 1 else 0.0
	_check("a hit from the right points right (%.0f deg)" % rad_to_deg(angle),
		_indicator.entry_count() == 1 and absf(angle - PI * 0.5) <= deg_to_rad(10.0))
	right.free()

	await _reset_feedback()
	_damage(10.0, Hitbox.BodyPart.BODY, null)
	await _seconds(0.1)
	_check("a hit without a source draws nothing", _indicator.entry_count() == 0)

	await _reset_feedback()
	var away := _source_at(Vector3(0, 0, -5))
	_damage(5.0, Hitbox.BodyPart.BODY, away)
	await _seconds(1.1)
	_check("an arc fades away after a second", _indicator.entry_count() == 0)
	away.free()


func _test_merge() -> void:
	print("== a burst of hits is one impact")
	await _reset_feedback()
	var source := _source_at(Vector3(0, 0, -5))
	var plays: int = _hud.hurt_sound_plays
	for i in 5:
		_damage(2.0, Hitbox.BodyPart.BODY, source)
	_check("the flash uses the summed damage (%.2f)" % _hud._damage_flash.color.a,
		_hud._damage_flash.color.a > 0.45)
	await _seconds(0.1)
	_check("five hits on one frame play one hurt sound (%d)" % (_hud.hurt_sound_plays - plays),
		_hud.hurt_sound_plays == plays + 1)
	_check("and draw one arc (%d)" % _indicator.entry_count(), _indicator.entry_count() == 1)
	source.free()
	await _seconds(1.0)


func _test_blocked() -> void:
	print("== a blocked hit stays silent")
	await _reset_feedback()
	var source := _source_at(Vector3(5, 0, 0))
	var plays: int = _hud.hurt_sound_plays
	_health.invulnerable = true
	var dealt := _health.apply_damage(20.0, Hitbox.BodyPart.BODY, source)
	_health.invulnerable = false
	await _seconds(0.12)
	_check("the hit is blocked (%.1f dealt)" % dealt, dealt == 0.0)
	_check("no vignette (%.2f)" % _hud._damage_flash.color.a, _hud._damage_flash.color.a <= 0.001)
	_check("no hurt sound", _hud.hurt_sound_plays == plays)
	_check("no arc", _indicator.entry_count() == 0)
	source.free()


func _test_view_shake() -> void:
	print("== getting hit kicks the view, never the aim")
	await _reset_feedback()
	var aim := _player.get_node("Head/Camera3D") as Camera3D
	var aim_before := aim.global_transform
	var yaw_before := _player.rotation
	_damage(10.0, Hitbox.BodyPart.BODY, null)
	var peak := 0.0
	for i in 10:
		await get_tree().process_frame
		peak = maxf(peak, _player.view_camera.transform.basis.get_euler().length())
	_check("the rendering camera shakes (peak %.2f deg)" % rad_to_deg(peak), peak > deg_to_rad(0.05))
	_check("the aim camera's global transform is untouched", aim.global_transform.is_equal_approx(aim_before))
	_check("the player's yaw is untouched", _player.rotation.is_equal_approx(yaw_before))
	await _frames(40)
	_check("the shake settles back to identity", _player.view_camera.transform.is_equal_approx(Transform3D.IDENTITY))


func _test_low_health() -> void:
	print("== low health pulses the edge")
	await _reset_feedback()
	_health.health = 20.0
	await _frames(3)
	_check("20% health turns the low-health state on", _hud.low_hp_active())
	_check("the edge is lit (%.2f)" % _hud._damage_flash.color.a, _hud._damage_flash.color.a >= 0.30)
	_check("the heartbeat is running", _hud._heartbeat.playing)
	_health.health = 40.0
	await _frames(3)
	_check("40% health turns it off (hysteresis above 35%)", not _hud.low_hp_active())
	_check("the heartbeat stops", not _hud._heartbeat.playing)
	_health.health = _health.max_health
	await _frames(2)


## Back to a clean slate between cases: full health, no pending hit, no arcs.
func _reset_feedback() -> void:
	_health.health = _health.max_health
	_hud._hurt_flash = 0.0
	_hud._hurt_pending = 0.0
	_hud._hurt_merge_left = 0.0
	_hud._damage_flash.color.a = 0.0
	_indicator.clear()
	await get_tree().process_frame


func _damage(amount: float, part: Hitbox.BodyPart, source: Node) -> float:
	return _health.apply_damage(amount, part, source)


## A bare Node3D standing at `offset` from the player; it only marks where the
## hit came from, like an attacker that may die before the arc fades.
func _source_at(offset: Vector3) -> Node3D:
	var source := Node3D.new()
	add_child(source)
	source.global_position = _player.global_position + offset
	return source


func _seconds(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func _check(label: String, ok: bool) -> void:
	if not ok:
		_failures += 1
	print("  [%s] %s" % ["ok" if ok else "FAIL", label])
