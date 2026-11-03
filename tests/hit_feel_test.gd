extends Node
## Headless check of the stronger hit / kill feedback and the softened gunshots:
##   godot --headless --path . res://tests/hit_feel_test.tscn
## It is all presentation: the enemy body and its hitboxes must not move, the
## gunshots must start soft and peak at a sane level, and every random effect is
## seeded by its own generator.

var _failures := 0
var _finished := false
var _player: Player
var _hud


func _ready() -> void:
	await _run()
	var ok := _failures == 0 and _finished
	print("%s (%d failed%s)" % ["ALL PASSED" if ok else "FAIL", _failures,
		"" if _finished else ", run did not finish"])
	get_tree().quit(0 if ok else 1)


func _run() -> void:
	_test_gunshot_shape()
	_test_weapon_values()

	var scene: Node = load("res://maps/zone_1.tscn").instantiate()
	add_child(scene)
	await get_tree().process_frame
	get_tree().paused = false
	_player = scene.get_node("Player") as Player
	_hud = scene.get_node("HUD")
	for node in get_tree().get_nodes_in_group("enemy"):
		(node as Enemy).set_physics_process(false)
	_player.global_rotation = Vector3.ZERO
	await _frames(3)

	await _test_kill_bursts()
	await _test_no_movement()
	await _test_kill_text()
	_test_hitstop()
	await _test_burst_determinism()
	# Let the last kill sounds finish before quitting.
	await _seconds(0.8)
	_finished = true


func _test_gunshot_shape() -> void:
	print("== softened gunshots")
	var first_ms := int(0.001 * ProceduralAudio.SAMPLE_RATE)
	for kind in ["gun_rifle", "gun_shotgun", "gun_sniper"]:
		var wav := ProceduralAudio.generate(kind)
		var peak := 0.0
		var early := 0.0
		for i in range(0, wav.data.size(), 2):
			var raw := wav.data[i] | (wav.data[i + 1] << 8)
			if raw >= 32768:
				raw -= 65536
			var value := absf(float(raw))
			peak = maxf(peak, value)
			if i / 2 < first_ms:
				early = maxf(early, value)
		var peak_db := 20.0 * log(peak / 32767.0) / log(10.0)
		_check("%s: soft attack (%.0f%% at 1 ms), peaks at -3 dBFS (%.1f dB)"
			% [kind, early / peak * 100.0, peak_db], early < peak * 0.5 and absf(peak_db + 3.0) <= 1.0)
	_check("gunshots are deterministic",
		ProceduralAudio.generate("gun_rifle").data == ProceduralAudio.generate("gun_rifle").data)
	_check("the headshot kill sound is its own stream",
		ProceduralAudio.generate("hit_kill").data != ProceduralAudio.generate("hit_kill_head").data)


func _test_weapon_values() -> void:
	print("== stronger visual recoil")
	# kick pitch / roll / back, then shake degrees / FOV punch
	var want := {
		"rifle": [1.3, 0.9, 0.026, 0.11, 0.011],
		"shotgun": [7.0, 2.0, 0.14, 0.55, 0.045],
		"sniper": [9.0, 2.5, 0.18, 0.75, 0.055]}
	for name in want:
		var gun := load("res://weapons/%s.tres" % name) as WeaponData
		var v: Array = want[name]
		_check("%s kick is up" % name, is_equal_approx(gun.view_kick_pitch, v[0])
			and is_equal_approx(gun.view_kick_roll, v[1]) and is_equal_approx(gun.view_kick_back, v[2]))
		_check("%s shake is up" % name, is_equal_approx(gun.shake_degrees, v[3])
			and is_equal_approx(gun.shake_fov_punch, v[4]))
		_check("%s still damps it while aiming" % name, gun.aim_feel_scale < 1.0)
	_check("a scope still drops the rotation shake", is_equal_approx(Weapon.SCOPED_PUNCH_SCALE, 0.5))


func _test_kill_bursts() -> void:
	print("== kill bursts")
	var body_enemy := _spawn_enemy(Vector3(-2, 0, -4))
	var head_enemy := _spawn_enemy(Vector3(2, 0, -4))
	body_enemy.health.apply_damage(1000.0, Hitbox.BodyPart.BODY, _player)
	head_enemy.health.apply_damage(1000.0, Hitbox.BodyPart.HEAD, _player)
	await _frames(2)
	var body_burst := (body_enemy.get_node("HitReaction") as HitReaction).death_burst
	var head_burst := (head_enemy.get_node("HitReaction") as HitReaction).death_burst
	_check("both kills make a death burst", body_burst != null and head_burst != null)
	if body_burst != null and head_burst != null:
		_check("the headshot burst is larger (%.2f > %.2f)" % [head_burst.scale_used, body_burst.scale_used],
			head_burst.scale_used > body_burst.scale_used)
		_check("and starts at head height (%.2f > %.2f)" % [head_burst.global_position.y, body_burst.global_position.y],
			head_burst.global_position.y > body_burst.global_position.y + 0.2)
		var lifetime := maxf(body_burst.lifetime(), head_burst.lifetime())
		_check("the chunks live for a moment (%.2f s)" % lifetime, lifetime > 0.3)
		await _seconds(lifetime + 0.4)
		_check("both bursts free themselves",
			not is_instance_valid(body_burst) and not is_instance_valid(head_burst))
	body_enemy.free()
	head_enemy.free()


func _test_no_movement() -> void:
	print("== the body and hitboxes never move")
	var enemy := _spawn_enemy(Vector3(0, 0, 3))
	var animation := enemy.get_node("Model/AnimationPlayer") as AnimationPlayer
	animation.pause()
	var body_before := enemy.global_transform
	var hitboxes := enemy.find_children("*", "Hitbox", true, false)
	var boxes_before: Array[Transform3D] = []
	for node in hitboxes:
		boxes_before.append((node as Hitbox).global_transform)
	# Non-lethal headshot: flinch + the head spark burst.
	enemy.health.apply_damage(10.0, Hitbox.BodyPart.HEAD, _player)
	await _frames(8)
	_check("a headshot flinch leaves the body still", enemy.global_transform.is_equal_approx(body_before))
	_check("and every hitbox still where it was", not _boxes_moved(hitboxes, boxes_before))
	# Kill: death lean, burst and light. The Death animation resets the pose when
	# it applies, so let it land for one frame, then prove the lean and the
	# burst do not move anything after that.
	enemy.health.apply_damage(1000.0, Hitbox.BodyPart.BODY, _player)
	await _frames(1)
	animation.pause()
	var boxes_at_death: Array[Transform3D] = []
	for node in hitboxes:
		boxes_at_death.append((node as Hitbox).global_transform)
	await _frames(8)
	_check("the death lean leaves the body still", enemy.global_transform.is_equal_approx(body_before))
	_check("the lean and burst leave the hitboxes alone", not _boxes_moved(hitboxes, boxes_at_death))
	enemy.free()


func _test_kill_text() -> void:
	print("== kill confirm text")
	_reset_combo()
	_hud._on_hit_landed(false, true)
	_check("a body kill says 击杀", _hud._kill_text.text == "击杀")
	_check("in white", _hud._kill_text.get_theme_color("font_color").g > 0.9
		and _hud._kill_text.modulate.a > 0.9)
	_hud._on_hit_landed(false, true)
	_check("a second kill inside 2.5 s says 双杀", _hud._kill_text.text == "双杀")
	await _seconds(2.6)
	_hud._on_hit_landed(false, true)
	_check("after 2.5 s the combo starts over", _hud._kill_text.text == "击杀")
	_reset_combo()
	_hud._on_hit_landed(true, true)
	_check("a headshot kill says 爆头击杀", _hud._kill_text.text == "爆头击杀")
	_check("in gold", _hud._kill_text.get_theme_color("font_color").g > 0.7
		and _hud._kill_text.get_theme_color("font_color").b < 0.4)
	await _seconds(0.8)
	_check("and the text has faded", _hud._kill_text.modulate.a <= 0.01)


func _test_hitstop() -> void:
	print("== kill hitstop")
	HitStop.last_requested = 0.0
	_hud._on_hit_landed(false, true)
	_check("a body kill asks for 0.05 s (%.3f)" % HitStop.last_requested,
		is_equal_approx(HitStop.last_requested, 0.05))
	_hud._on_hit_landed(true, true)
	_check("a headshot kill asks for 0.075 s (%.3f)" % HitStop.last_requested,
		is_equal_approx(HitStop.last_requested, 0.075))
	_check("headless still refuses to slow the game", not HitStop.is_active())


func _test_burst_determinism() -> void:
	print("== seeded bursts")
	var a := DebrisBurst.spawn_death(self, Vector3.ZERO, Vector3.FORWARD, 1.0, 7777)
	var b := DebrisBurst.spawn_death(self, Vector3.ZERO, Vector3.FORWARD, 1.0, 7777)
	var c := DebrisBurst.spawn_death(self, Vector3.ZERO, Vector3.FORWARD, 1.0, 7778)
	_check("the same seed makes the same chunks",
		a != null and b != null and a.bit_velocities() == b.bit_velocities())
	_check("a different seed makes different chunks", a != null and c != null
		and a.bit_velocities() != c.bit_velocities())
	seed(4242)
	var want := randi()
	seed(4242)
	var sparks := DebrisBurst.spawn_sparks(self, Vector3.ZERO, Vector3.UP, 1.0, 99)
	_check("the seeded bursts draw nothing from the global sequence", randi() == want)
	a.free()
	b.free()
	c.free()
	if sparks != null:
		sparks.free()


func _spawn_enemy(at: Vector3) -> Enemy:
	var enemy := load("res://actors/enemy/enemy.tscn").instantiate() as Enemy
	add_child(enemy)
	enemy.set_physics_process(false)
	enemy.global_position = at
	return enemy


func _boxes_moved(hitboxes: Array[Node], before: Array[Transform3D]) -> bool:
	for i in hitboxes.size():
		if not (hitboxes[i] as Hitbox).global_transform.is_equal_approx(before[i]):
			return true
	return false


func _reset_combo() -> void:
	_hud._kill_combo = 0
	_hud._kill_combo_left = 0.0
	_hud._kill_text_left = 0.0


func _seconds(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func _check(label: String, ok: bool) -> void:
	if not ok:
		_failures += 1
	print("  [%s] %s" % ["ok" if ok else "FAIL", label])
