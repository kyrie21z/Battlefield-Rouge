extends Node

const PLAYER := preload("res://actors/player/player.tscn")
const REALMS := ["sloth", "fear", "wrath", "sorrow"]
const BOSS_NAMES := ["沉眠巨像", "审判之瞳", "狂暴尖塔", "哀泣巨碑"]

var checks := 0
var failures := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_run")


func _run() -> void:
	for realm in REALMS:
		for suffix in ["1", "boss"]:
			await _room("%s_%s" % [realm, suffix])
	await _climax()
	print("COMBAT HIT FEEL: %d checks, %d failed" % [checks, failures])
	get_tree().quit(1 if failures else 0)


func _room(room_name: String) -> void:
	var room := load("res://maps/realms/%s.tscn" % room_name).instantiate() as RealmStage
	add_child(room)
	var player := room.player
	_hold_player(player)
	for enemy in room.enemies:
		enemy.set_physics_process(false)
		enemy.set_process(false)
	var layer := room.hud.combat_feedback
	_check(room_name + " installs a HUD-only feedback layer", layer != null
		and layer.mouse_filter == Control.MOUSE_FILTER_IGNORE)
	if room.boss_room:
		await _boss_bar(room_name, room)
	else:
		_check(room_name + " has no visible boss bar", not room.hud._boss_bar.visible)
	await _outgoing_hits(room_name, player, layer)
	if room_name == "sloth_1":
		await _fire_and_swing(room)
	await _player_hurt(room_name, player, layer)
	if room.boss_room:
		var health := room.boss.health
		health.apply_damage(health.max_health, Hitbox.BodyPart.BODY, player, {"true_damage": true})
		_check(room_name + " boss death hides bar and name",
			not room.hud._boss_bar.visible and not room.hud._boss_name.visible)
	room.queue_free()
	await get_tree().process_frame
	_check(room_name + " frees the feedback layer with the room", not is_instance_valid(layer))


func _climax() -> void:
	var player := PLAYER.instantiate() as Player
	add_child(player)
	_hold_player(player)
	player.weapon.add_user_signal("hit_blocked", [{"name": "position", "type": TYPE_VECTOR3}])
	player.melee.add_user_signal("hit_blocked")
	var hud := ClimaxCombatHUD.new()
	hud.setup(player)
	seed(243)
	var expected := randi()
	seed(243)
	add_child(hud)
	var layer := hud.combat_feedback
	_check("climax feedback setup preserves global RNG", randi() == expected)
	player.weapon.hit_landed.emit(false, true)
	_check("climax pre-combat suppresses hit feedback", layer.hitmarker.modulate.a == 0.0
		and not layer.hit_audio.playing and not layer.kill_audio.playing)
	hud.set_combat_visible(true)
	await _outgoing_hits("climax", player, layer)
	player.weapon.emit_signal(&"hit_blocked", Vector3.ZERO)
	_check("climax connects the optional weapon block signal", layer.blocked_audio.playing)
	layer.blocked_audio.stop()
	player.melee.emit_signal(&"hit_blocked")
	_check("climax connects the optional melee block signal", layer.blocked_audio.playing)
	hud.set_combat_visible(false)
	_check("climax transition immediately clears active feedback", layer.hitmarker.modulate.a == 0.0
		and not layer.blocked_audio.playing)
	hud.set_combat_visible(true)
	await _player_hurt("climax", player, layer)
	hud.finish()
	hud.queue_free()
	player.queue_free()
	await get_tree().process_frame
	_check("climax frees its feedback with the encounter HUD", not is_instance_valid(layer))


func _outgoing_hits(label: String, player: Player, layer: CombatFeedbackLayer) -> void:
	seed(243)
	var expected := randi()
	seed(243)
	var marker := layer.hitmarker
	HitStop.last_requested = 0.0
	player.weapon.hit_landed.emit(false, false)
	var body_pop := marker.scale.x
	_check(label + " body hit pops white and plays the body OGG", marker.modulate == Color.WHITE
		and body_pop > 1.0 and layer.hit_audio.playing
		and layer.hit_audio.stream.resource_path.ends_with("/hit_body.ogg"))
	player.weapon.hit_landed.emit(true, false)
	_check(label + " head hit pops gold with OGG and tink", marker.modulate.g > 0.8
		and marker.modulate.b < 0.4 and marker.scale.x > body_pop
		and layer.hit_audio.stream.resource_path.ends_with("/hit_head.ogg")
		and layer.hit_audio.playing and layer.tink_audio.playing)
	_check(label + " non-lethal firearm hits do not request hitstop", HitStop.last_requested == 0.0)
	_check(label + " consecutive hit layers rise by 0.03", is_equal_approx(layer.hit_audio.pitch_scale, 1.03)
		and is_equal_approx(layer.tink_audio.pitch_scale, 1.03))
	for hit in 8:
		player.weapon.hit_landed.emit(false, false)
	_check(label + " hit pitch caps at +0.15", is_equal_approx(layer.hit_audio.pitch_scale, 1.15))
	layer.hit_audio.stop()
	layer.on_hit_blocked()
	_check(label + " block uses a muted marker and separate audio", layer.blocked_audio.playing
		and not layer.hit_audio.playing and marker.modulate.r < 0.7)

	player.weapon.hit_landed.emit(false, true)
	_check(label + " default headless reports a kill without slowing time", not HitStop.is_active()
		and Engine.time_scale == 1.0 and is_equal_approx(HitStop.last_requested, 0.05))
	_check(label + " body kill pops red, layers its own sound and displays 击杀",
		marker.modulate.r == 1.0 and marker.modulate.g < 0.3 and marker.scale.x > body_pop
		and layer.hit_audio.playing and layer.kill_audio.playing and layer.kill_text.text == "击杀"
		and layer.kill_text.modulate.a == 1.0 and layer.kill_text.scale.x > 1.0)
	HitStop.allow_headless = true
	player.weapon.hit_landed.emit(true, true)
	_hitstop(label + " headshot kill", 0.075)
	_check(label + " headshot kill layers the head confirm and shows 双杀", layer.hit_audio.playing
		and layer.tink_audio.playing and layer.kill_head_audio.playing and layer.kill_text.text == "双杀")
	player.weapon.hit_landed.emit(false, true)
	_hitstop(label + " body kill", 0.05)
	_check(label + " third kill displays 三杀", layer.kill_text.text == "三杀")
	player.weapon.hit_landed.emit(false, true)
	HitStop.restore()
	_check(label + " fourth kill displays 连杀 ×4", layer.kill_text.text == "连杀 ×4")
	player.melee.hit_landed.emit(false, false)
	_hitstop(label + " non-lethal melee", 0.025)
	Events.blade_parried.emit(Vector3.ZERO)
	_hitstop(label + " blade parry", 0.05)

	RunState.fixture = RunFixture.by_id("FX-001")
	_no_hitstop(label + " fixture", player)
	RunState.fixture = null
	var alpha := marker.modulate.a
	var marker_scale := marker.scale
	var text_left := layer.kill_text_left
	get_tree().paused = true
	_no_hitstop(label + " paused", player)
	_check(label + " combat callbacks preserve global RNG", randi() == expected)
	await _seconds(0.13)
	_check(label + " pause freezes marker and kill text animation", marker.modulate.a == alpha
		and marker.scale == marker_scale and layer.kill_text_left == text_left)
	get_tree().paused = false
	HitStop.allow_headless = false

	await _seconds(0.66)
	_check(label + " marker and kill text fade after resuming", marker.modulate.a <= 0.001
		and layer.kill_text.modulate.a <= 0.001)
	if label == "climax":
		seed(244)
		var expected_after_frames := randi()
		seed(244)
		await _seconds(2.0)
		_check("climax timed feedback preserves global RNG", randi() == expected_after_frames)
		player.weapon.hit_landed.emit(true, true)
		_check("climax first kill after timeout displays 爆头击杀", layer.kill_text.text == "爆头击杀")
		_check("climax first hit after timeout returns to base pitch", is_equal_approx(layer.hit_audio.pitch_scale, 1.0))


func _player_hurt(label: String, player: Player, layer: CombatFeedbackLayer) -> void:
	var health := player.health
	var max_hp := health.max_health
	var plays := layer.hurt_sound_plays
	health.invulnerable = true
	health.apply_damage(max_hp * 0.3, Hitbox.BodyPart.HEAD)
	health.invulnerable = false
	health.grant_shield(max_hp * 0.5)
	health.apply_damage(max_hp * 0.3, Hitbox.BodyPart.BODY)
	health.break_shield()
	await _seconds(0.09)
	_check(label + " invulnerability and full shielding leave hurt audio silent",
		health.health == max_hp and layer.hurt_sound_plays == plays)
	health.apply_damage(max_hp * 0.05, Hitbox.BodyPart.BODY)
	await _seconds(0.09)
	_check(label + " a light HP hit plays the light hurt sound", layer.hurt_sound_plays == plays + 1
		and layer.hurt_audio.playing and not layer.hurt_heavy_audio.playing)
	health.apply_damage(max_hp * 0.10, Hitbox.BodyPart.BODY)
	health.apply_damage(max_hp * 0.11, Hitbox.BodyPart.BODY)
	get_tree().paused = true
	await _seconds(0.10)
	_check(label + " pause freezes the pending hurt merge", layer.hurt_sound_plays == plays + 1)
	get_tree().paused = false
	await _seconds(0.09)
	_check(label + " merged damage above 20% plays one heavy hurt sound",
		layer.hurt_sound_plays == plays + 2 and layer.hurt_heavy_audio.playing)
	health.apply_damage(max_hp * 0.01, Hitbox.BodyPart.HEAD)
	await _seconds(0.09)
	_check(label + " small headshot plays heavy hurt", layer.hurt_sound_plays == plays + 3
		and layer.hurt_heavy_audio.playing)

	health.health = max_hp * 0.30
	await _seconds(0.03)
	_check(label + " 30% HP stays outside the heartbeat state", not layer.low_hp and not layer.heartbeat.playing)
	health.health = max_hp * 0.29
	await _seconds(0.03)
	_check(label + " below 30% HP starts the heartbeat", layer.low_hp and layer.heartbeat.playing)
	var pulse := layer.low_health_alpha
	get_tree().paused = true
	await _seconds(0.12)
	_check(label + " pause freezes the heartbeat pulse and stream", layer.low_health_alpha == pulse
		and layer.heartbeat.stream_paused)
	get_tree().paused = false
	health.health = max_hp * 0.35
	await _seconds(0.03)
	_check(label + " heartbeat persists at 35% HP", layer.low_hp)
	health.health = max_hp * 0.36
	await _seconds(0.03)
	_check(label + " above 35% HP stops the heartbeat", not layer.low_hp and not layer.heartbeat.playing)
	health.health = max_hp * 0.10
	await _seconds(0.03)
	health.apply_damage(max_hp * 0.01, Hitbox.BodyPart.BODY)
	health.apply_damage(max_hp, Hitbox.BodyPart.BODY, null, {"true_damage": true})
	_check(label + " death clears heartbeat, attack and hurt feedback immediately",
		health.is_dead() and not layer.low_hp and not layer.heartbeat.playing
		and not layer.hurt_audio.playing and not layer.hurt_heavy_audio.playing
		and not layer.hit_audio.playing and layer.kill_text.modulate.a == 0.0)
	HitStop.allow_headless = true
	_no_hitstop(label + " dead player", player)
	HitStop.allow_headless = false
	await _seconds(0.09)
	_check(label + " death discards queued hurt audio", layer.hurt_sound_plays == plays + 3)


func _boss_bar(label: String, room: RealmStage) -> void:
	var bar := room.hud._boss_bar
	var health := room.boss.health
	var full := health.health
	_check(label + " starts with the named boss bar at full health", bar.visible
		and room.hud._boss_name.visible and room.hud._boss_name.text == BOSS_NAMES[room.realm]
		and bar.trail.current == full and bar.trail.delayed == full)
	health.apply_damage(48.0, Hitbox.BodyPart.BODY, room.player, {"true_damage": true})
	var current := health.health
	_check(label + " real boss damage leaves delayed health and shakes immediately", current < full
		and bar.trail.current == current and bar.trail.delayed == full and absf(bar.shake_offset) > 0.0)
	var shake := bar.shake_offset
	get_tree().paused = true
	await _seconds(0.45)
	_check(label + " pause freezes boss trail and shake", bar.trail.delayed == full and bar.shake_offset == shake)
	get_tree().paused = false
	await _seconds(0.15)
	_check(label + " shake settles in ~0.12s with trail still held", bar.shake_offset == 0.0
		and bar.trail.delayed == full)
	await _seconds(0.34)
	_check(label + " boss trail drains toward current health after the hold", bar.trail.delayed < full
		and bar.trail.delayed > current)
	await _seconds(0.45)
	_check(label + " boss trail settles at current health", is_equal_approx(bar.trail.delayed, current))


func _fire_and_swing(room: RealmStage) -> void:
	var player := room.player
	var enemy := room.enemies[1]
	var layer := room.hud.combat_feedback
	player.global_position = Vector3(0, 40, 0)
	enemy.global_position = Vector3(0, 40.55, -2.0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var torso := enemy.get_node("TorsoHitbox") as Hitbox
	player.aim_at(torso.global_position)
	var before := enemy.health.health
	var fired := player.weapon.try_fire()
	_check("sloth_1 real pistol shot damages a production enemy and flashes the HUD",
		fired and enemy.health.health < before and layer.hitmarker.modulate.a > 0.0 and layer.hit_audio.playing)
	enemy.health.health = before
	player.aim_at(torso.global_position)
	HitStop.last_requested = 0.0
	var swung := player.melee.swing_now()
	await _seconds(0.26)
	_check("sloth_1 real blade swing damages a production enemy and requests melee hitstop (HP %.1f → %.1f, stop %.3fs)"
		% [before, enemy.health.health, HitStop.last_requested],
		swung and enemy.health.health < before and not enemy.health.is_dead()
		and is_equal_approx(HitStop.last_requested, 0.025))


func _hold_player(player: Player) -> void:
	player.set_physics_process(false)
	player.set_process(false)
	player.dash.set_physics_process(false)
	player.health.health = player.health.max_health


func _hitstop(label: String, expected: float) -> void:
	_check(label + " requests %.3fs hitstop" % expected, is_equal_approx(HitStop.last_requested, expected)
		and HitStop.is_active() and Engine.time_scale < 0.1)
	HitStop.restore()


func _no_hitstop(label: String, player: Player) -> void:
	HitStop.last_requested = 0.0
	player.weapon.hit_landed.emit(true, true)
	player.melee.hit_landed.emit(false, false)
	Events.blade_parried.emit(Vector3.ZERO)
	_check(label + " skips hitstop entirely", HitStop.last_requested == 0.0
		and not HitStop.is_active() and Engine.time_scale == 1.0)


func _seconds(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _check(label: String, passed: bool) -> void:
	checks += 1
	if not passed:
		failures += 1
	print("%s %s" % ["PASS" if passed else "FAIL", label])
