extends Node
## Regressions for the screen-space DamageNumbers layer inside CombatFeedbackLayer.
## Real pistol and blade hits on production enemies drive every tier; the boss
## rooms and the climax HUD prove the room scan, dynamic registration, the
## pre-combat transition and the static overlay cleanup.

const PLAYER := preload("res://actors/player/player.tscn")
const SLOTH_STAGE := preload("res://maps/realms/sloth_1.tscn")
const SLOTH_ENEMY := preload("res://actors/enemy/sloth/sloth_enemy.tscn")
const DOPPELGANGER := preload("res://actors/boss/flawless_doppelganger/flawless_doppelganger.tscn")
const BOSS_ROOMS := ["sloth_boss", "fear_boss", "wrath_boss", "sorrow_boss"]

var checks := 0
var failures := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_run")


func _run() -> void:
	await _weapon_and_melee_hits()
	await _damage_tiers_and_cleanup()
	await _boss_rooms()
	await _dynamic_wave_enemy()
	await _climax_transition()
	print("DAMAGE NUMBERS: %d checks, %d failed" % [checks, failures])
	get_tree().quit(1 if failures else 0)


func _weapon_and_melee_hits() -> void:
	var room := SLOTH_STAGE.instantiate() as RealmStage
	add_child(room)
	var player := room.player
	_hold_player(player)
	for enemy in room.enemies:
		enemy.set_physics_process(false)
		enemy.set_process(false)
	var layer := room.hud.combat_feedback
	var numbers := layer.damage_numbers
	_check("RealmHUD installs DamageNumbers inside CombatFeedbackLayer",
		numbers != null and numbers.get_parent() == layer
		and layer.mouse_filter == Control.MOUSE_FILTER_IGNORE)
	_check("a live HUD registers exactly one 2D overlay",
		FearCriticalFeedback._overlay_2d_count == 1)
	_check("a fresh layer holds no floating numbers", numbers.active_count() == 0)

	var enemy := room.enemies[1]
	player.global_position = Vector3(0, 40, 0)
	enemy.global_position = Vector3(0, 40.55, -2.0)
	enemy.health.health = 2000.0
	await get_tree().physics_frame
	await get_tree().physics_frame

	var torso := enemy.get_node("TorsoHitbox") as Hitbox
	player.aim_at(torso.global_position)
	var before := enemy.health.health
	var fired := player.weapon.try_fire()
	var body_context := enemy.health.last_damage_context.duplicate()
	var body_entry := numbers.latest_entry()
	_check("real pistol body hit pops NORMAL with the exact rounded damage",
		fired and enemy.health.health < before and body_entry != null
		and body_entry.kind == DamageNumbers.Kind.NORMAL
		and is_equal_approx(float(body_context.resolved_damage), 35.0)
		and body_entry.text == "35")

	await _seconds(0.22)
	var head := enemy.get_node("HeadHitbox") as Hitbox
	player.aim_at(head.global_position)
	var before_head := enemy.health.health
	var head_fired := player.weapon.try_fire()
	var head_context := enemy.health.last_damage_context.duplicate()
	var head_entry := numbers.latest_entry()
	_check("real pistol headshot pops HEADSHOT with the exact rounded damage",
		head_fired and enemy.health.health < before_head and head_entry != null
		and head_entry.kind == DamageNumbers.Kind.HEADSHOT
		and is_equal_approx(float(head_context.resolved_damage), 70.0)
		and head_entry.text == "70")
	_check("headshot numbers draw larger than body numbers",
		head_entry.font_size > body_entry.font_size)

	await _seconds(0.22)
	enemy.health.health = 2000.0
	enemy.global_position = Vector3(0, 40.55, -2.0)
	player.aim_at(torso.global_position)
	var swung := player.melee.swing_now()
	await _seconds(0.26)
	var melee_context := enemy.health.last_damage_context.duplicate()
	var melee_entry := numbers.latest_entry()
	_check("real blade swing pops a floating number (HP %.0f -> %.0f)"
		% [2000.0, enemy.health.health],
		swung and enemy.health.health < 2000.0 and melee_entry != null
		and melee_entry.kind in [DamageNumbers.Kind.NORMAL, DamageNumbers.Kind.HEADSHOT]
		and melee_entry.text == str(roundi(float(melee_context.resolved_damage))))
	await _leave_room(room)


func _damage_tiers_and_cleanup() -> void:
	var room := SLOTH_STAGE.instantiate() as RealmStage
	add_child(room)
	var player := room.player
	_hold_player(player)
	for enemy in room.enemies:
		enemy.set_physics_process(false)
		enemy.set_process(false)
	var numbers := room.hud.combat_feedback.damage_numbers
	var enemy := room.enemies[0]
	enemy.health.health = 2000.0

	numbers.clear()
	enemy.health.apply_damage(20.0, Hitbox.BodyPart.BODY, player)
	var normal := numbers.latest_entry()
	_check("a plain hit is NORMAL and carries the exact value",
		normal != null and normal.kind == DamageNumbers.Kind.NORMAL and normal.text == "20")

	numbers.clear()
	enemy.health.apply_damage(20.0, Hitbox.BodyPart.BODY, player, {"critical": true})
	var critical := numbers.latest_entry()
	_check("a critical hit uses CRITICAL, a trailing ! and a larger font",
		critical != null and critical.kind == DamageNumbers.Kind.CRITICAL
		and critical.text == "20!" and critical.font_size > normal.font_size
		and critical.color == DamageNumbers.COLOR_CRITICAL)

	numbers.clear()
	enemy.health.apply_damage(20.0, Hitbox.BodyPart.BODY, player,
		{"critical": true, "fear_critical": true})
	var fear := numbers.latest_entry()
	_check("a fear critical uses the purple FEAR_CRITICAL tier",
		fear != null and fear.kind == DamageNumbers.Kind.FEAR_CRITICAL
		and fear.text == "20!" and fear.color == DamageNumbers.COLOR_FEAR_CRIT
		and fear.font_size > critical.font_size)
	var label_effect := FearCriticalFeedback.spawn(room, enemy.global_position, 20.0, false)
	_check("the live 2D overlay hides the duplicate 3D fear label",
		label_effect._label != null and not label_effect._label.visible)
	label_effect.queue_free()

	numbers.clear()
	var hp_before := enemy.health.health
	enemy.health.max_shield = 40.0
	enemy.health.grant_shield(40.0)
	enemy.health.apply_damage(15.0, Hitbox.BodyPart.BODY, player)
	var shield := numbers.latest_entry()
	_check("a pure shield hit uses the cyan SHIELD tier and leaves HP intact",
		shield != null and shield.kind == DamageNumbers.Kind.SHIELD
		and shield.text == "15" and shield.color == DamageNumbers.COLOR_SHIELD
		and enemy.health.health == hp_before)
	enemy.health.break_shield()
	enemy.health.max_shield = 0.0

	var probe := numbers.spawn_number(enemy.global_position + Vector3.UP, 42.0)
	var scales: Array[float] = []
	for elapsed in [0.0, 0.08, 0.16, 0.24, 0.45, 0.70]:
		probe.elapsed = elapsed
		scales.append(DamageNumbers.growth_scale(probe))
	var growing := true
	for i in range(1, scales.size()):
		if scales[i] <= scales[i - 1]:
			growing = false
	_check("the growth curve expands monotonically from %.2f to %.2f"
		% [scales[0], scales[-1]], growing and scales[0] < 0.5 and scales[-1] > 1.0)

	numbers.clear()
	var before_pause := numbers.spawn_number(enemy.global_position + Vector3.UP, 30.0)
	var pause_elapsed := before_pause.elapsed
	var pause_offset := before_pause.screen_offset
	get_tree().paused = true
	await _seconds(0.12)
	_check("pause freezes active entries (elapsed and screen offset)",
		numbers.active_count() == 1 and before_pause.elapsed == pause_elapsed
		and before_pause.screen_offset == pause_offset)
	get_tree().paused = false
	await _seconds(0.05)
	_check("entries resume moving after unpause", before_pause.elapsed > pause_elapsed)

	seed(991)
	var expected := randi()
	seed(991)
	numbers.clear()
	numbers.spawn_number(enemy.global_position + Vector3.UP, 44.0)
	numbers._process(0.016)
	numbers.set_enabled(false)
	numbers.set_enabled(true)
	_check("damage numbers never consume the global RNG stream", randi() == expected)
	_check("the re-enabled layer registers one overlay", FearCriticalFeedback._overlay_2d_count == 1)

	numbers.set_enabled(false)
	_check("a disabled layer stops suppressing 3D fear labels",
		FearCriticalFeedback._overlay_2d_count == 0)
	numbers.set_enabled(true)
	await _leave_room(room)


func _boss_rooms() -> void:
	for room_name in BOSS_ROOMS:
		var room := load("res://maps/realms/%s.tscn" % room_name).instantiate() as RealmStage
		add_child(room)
		_hold_player(room.player)
		var boss := room.boss
		_check("%s spawns a real boss before the HUD scan" % room_name, is_instance_valid(boss))
		boss.set_physics_process(false)
		boss.set_process(false)
		var numbers := room.hud.combat_feedback.damage_numbers
		var before := boss.health.health
		boss.health.apply_damage(31.0, Hitbox.BodyPart.BODY, room.player, {"true_damage": true})
		var entry := numbers.latest_entry()
		_check("%s boss hit pops a floating number with the exact value" % room_name,
			boss.health.health < before and entry != null
			and entry.kind == DamageNumbers.Kind.NORMAL and entry.text == "31")
		await _leave_room(room)


func _dynamic_wave_enemy() -> void:
	var room := SLOTH_STAGE.instantiate() as RealmStage
	add_child(room)
	_hold_player(room.player)
	for enemy in room.enemies:
		enemy.set_physics_process(false)
		enemy.set_process(false)
	var numbers := room.hud.combat_feedback.damage_numbers
	numbers.clear()

	var wave := SLOTH_ENEMY.instantiate() as SlothEnemy
	wave.position = Vector3(0, 0.1, 6)
	room.add_child(wave)
	wave.set_physics_process(false)
	wave.set_process(false)
	await get_tree().process_frame
	wave.health.health = 500.0
	wave.health.apply_damage(12.0, Hitbox.BodyPart.BODY, room.player)
	var wave_entry := numbers.latest_entry()
	_check("an enemy registered after HUD setup is tracked and pops a number",
		wave_entry != null and wave_entry.kind == DamageNumbers.Kind.NORMAL
		and wave_entry.text == "12")
	_check("the dynamic enemy does not duplicate the overlay registration",
		FearCriticalFeedback._overlay_2d_count == 1)

	numbers.clear()
	wave.health.apply_damage(9999.0, Hitbox.BodyPart.BODY, room.player, {"true_damage": true})
	var kill_entry := numbers.latest_entry()
	_check("a lethal hit is marked as a kill and uses the kill colour",
		kill_entry != null and kill_entry.killed
		and kill_entry.color == DamageNumbers.COLOR_KILL)
	await _leave_room(room)


func _climax_transition() -> void:
	var arena := Node3D.new()
	add_child(arena)
	var player := PLAYER.instantiate() as Player
	player.position = Vector3(0, 0.1, 0)
	arena.add_child(player)
	_hold_player(player)
	var boss := DOPPELGANGER.instantiate() as FlawlessDoppelganger
	boss.position = Vector3(0, 0.1, -6)
	arena.add_child(boss)
	boss.set_physics_process(false)
	boss.set_process(false)
	boss.set_combat_active(true)
	var hud := ClimaxCombatHUD.new()
	hud.setup(player, boss)
	arena.add_child(hud)
	var numbers := hud.combat_feedback.damage_numbers
	_check("ClimaxCombatHUD installs DamageNumbers and stays unregistered pre-combat",
		numbers != null and FearCriticalFeedback._overlay_2d_count == 0)

	hud.set_combat_visible(true)
	_check("entering combat registers the 2D overlay", FearCriticalFeedback._overlay_2d_count == 1)
	boss.health.apply_damage(23.0, Hitbox.BodyPart.BODY, player, {"true_damage": true})
	var entry := numbers.latest_entry()
	_check("a FlawlessDoppelganger hit through the climax HUD pops a number",
		entry != null and entry.text == "23")

	hud.set_combat_visible(false)
	_check("leaving combat clears entries and releases the overlay",
		numbers.active_count() == 0 and FearCriticalFeedback._overlay_2d_count == 0)
	boss.health.apply_damage(23.0, Hitbox.BodyPart.BODY, player, {"true_damage": true})
	_check("pre-combat boss damage stays silent", numbers.active_count() == 0)

	hud.set_combat_visible(true)
	boss.health.apply_damage(23.0, Hitbox.BodyPart.BODY, player, {"true_damage": true})
	_check("re-entering combat pops numbers again",
		numbers.latest_entry() != null and FearCriticalFeedback._overlay_2d_count == 1)
	arena.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	_check("freeing the climax encounter releases the overlay cleanly",
		FearCriticalFeedback._overlay_2d_count == 0)


func _leave_room(room: Node) -> void:
	room.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	_check("freeing the room releases the 2D overlay", FearCriticalFeedback._overlay_2d_count == 0)


func _hold_player(player: Player) -> void:
	player.set_physics_process(false)
	player.set_process(false)
	player.dash.set_physics_process(false)
	player.health.health = player.health.max_health


func _seconds(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _check(label: String, passed: bool) -> void:
	checks += 1
	if not passed:
		failures += 1
	print("%s %s" % ["PASS" if passed else "FAIL", label])