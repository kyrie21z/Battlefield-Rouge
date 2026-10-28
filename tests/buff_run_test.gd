extends Node
## AC-04/08 integration fixture. Uses real UI inputs, damage, capture and scenes.
## --headless --path . res://tests/buff_run_test.tscn
## With a display, append -- --proof=res://docs/proof/ac-04-ac-08 to save screenshots.

const FIXTURE := "buff-two-small-zones-and-boss-20261027-seed-40408"
const EXPECTED_SCENES: Array[String] = [
	"res://maps/zone_1.tscn", "res://maps/zone_2.tscn", "res://maps/boss.tscn",
]
const EXPECTED_SELECTIONS: Array[String] = [
	"0:enter", "0:clear", "1:clear",
]
var _failures := 0
var _finished := false
var _elapsed := 0.0
var _proof := ""


func _ready() -> void:
	# Let the root finish attaching this scene before adding fixture siblings.
	await get_tree().process_frame
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--proof="):
			_proof = arg.trim_prefix("--proof=")
	if not _proof.is_empty():
		if DisplayServer.get_name() == "headless":
			push_error("Screenshot proof requires a native display")
			get_tree().quit(1)
			return
		_proof = ProjectSettings.globalize_path(_proof)
		if DirAccess.make_dir_recursive_absolute(_proof) != OK:
			push_error("Cannot create screenshot output directory")
			get_tree().quit(1)
			return
	await _run()
	_finished = true
	print("%s: %s (%d failed)" % [FIXTURE, "ALL PASSED" if _failures == 0 else "FAIL", _failures])
	get_tree().quit(0 if _failures == 0 else 1)


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed > 55.0 and not _finished:
		push_error("Fixture timed out or stopped at a script error")
		get_tree().quit(1)


func _run() -> void:
	print("FIXTURE: " + FIXTURE)
	_binding_checks()
	_catalog_checks()
	await _combat_checks()
	await _play_run([0, 1, 2], "mixed")
	await _restart_from_end()
	_check("restart resets buffs, unlocks and history", RunState.buffs.is_empty() and RunState.selection_history.is_empty() and RunState.zone_index == 0)
	await _play_existing_run([0, 0, 0], "firearm")
	await _restart_from_end()
	var director := _director()
	await _choose(director, 2)
	var player := get_tree().get_first_node_in_group("player") as Player
	player.health.apply_damage(99999.0, Hitbox.BodyPart.BODY)
	await get_tree().process_frame
	_check("death clears build and history", RunState.buffs.is_empty() and RunState.selection_history.is_empty() and RunState.zone_index == 0)
	_check("death shows end screen", director.get_children().any(func(n: Node): return n.has_signal("restart_pressed")))
	await _restart_from_end()
	_check("death restart opens exactly one entry choice", _director().selection_context == "enter" and _director().selection_count == 1)
	get_tree().paused = false
	get_tree().current_scene.queue_free()
	get_tree().current_scene = null
	await get_tree().process_frame


func _catalog_checks() -> void:
	print("== catalog, reachability and stacking")
	_check("run preserves main's two small maps and city-core Boss", RunState.ZONE_SCENES == EXPECTED_SCENES)
	_check("exactly nine buffs", BuffPool.ALL.size() == 9)
	var ids := {}
	var pixels := {}
	for buff in BuffPool.ALL:
		_check("unique identity: " + str(buff.id), not ids.has(buff.id) and not buff.id.is_empty())
		ids[buff.id] = true
		_check("school and effect text: " + buff.title, SchoolCatalog.find(buff.school_id) != null and not buff.description.is_empty())
		var img := buff.icon.get_image() if buff.icon != null else null
		_check("icon loads: " + buff.title, img != null and img.get_width() >= 32)
		if img != null:
			var digest := img.get_data().hex_encode().sha256_text()
			_check("different rendered icon: " + buff.title, not pixels.has(digest))
			pixels[digest] = true
		var stats := Stats.new()
		var before := stats.get_value(buff.stat)
		stats.apply_buff(buff)
		_check("first stack changes stat: " + buff.title, not is_equal_approx(before, stats.get_value(buff.stat)))
		stats.apply_buff(buff)
		_check("second stack compounds: " + buff.title, is_equal_approx(stats.get_value(buff.stat), (before + buff.add * 2.0) * buff.mul * buff.mul))
		if buff.school_id == &"skill":
			_check("any skill card unlocks shield", stats.get_value(Stats.SKILL_UNLOCKED) == 2.0)
		stats.free()
	for school_id in BuffPool.SCHOOL_IDS:
		_check("three cards in " + str(school_id), BuffPool.for_school(school_id).size() == 3)
	BuffPool.reset(40408)
	var seen := {}
	var offer_ids: Array[StringName] = []
	for round_index in 3:
		var offer := BuffPool.pick(3)
		_check("three choices", offer.size() == 3)
		if round_index == 0:
			_check("first offer contains the three playable cores", offer == [BuffPool.ALL[0], BuffPool.ALL[3], BuffPool.ALL[6]])
		for index in 3:
			_check("each offer has all three schools", offer[index].school_id == BuffPool.SCHOOL_IDS[index])
			seen[offer[index].id] = true
			offer_ids.append(offer[index].id)
	_check("all nine reachable within three offers", seen.size() == 9)
	BuffPool.reset(40408)
	var replay: Array[StringName] = []
	for round_index in 3:
		for buff in BuffPool.pick(3):
			replay.append(buff.id)
	_check("same seed reproduces offers", replay == offer_ids)
	_check("inspection pick clamps to nine unique cards", BuffPool.pick(99).size() == 9)
	_check("empty offer request", BuffPool.pick(0).is_empty())


func _combat_checks() -> void:
	print("== actual weapon, blade and shield effects")
	var arena := Node3D.new()
	get_tree().root.add_child(arena)
	var player := (load("res://actors/player/player.tscn") as PackedScene).instantiate() as Player
	arena.add_child(player)
	player.set_physics_process(false)
	player.weapon.set_process(false)
	player.melee.set_process(false)
	player.shield.set_process(false)
	_check("shield initially locked", not player.shield.try_activate())
	var old_mag := player.weapon.magazine_capacity()
	player.stats.apply_buff(BuffPool.ALL[2])
	_check("magazine buff changes weapon capacity", player.weapon.magazine_capacity() > old_mag)
	player.stats.apply_buff(BuffPool.ALL[0])
	player.stats.apply_buff(BuffPool.ALL[1])
	_check("gun damage and fire rate read Stats", player.stats.get_value(Stats.DAMAGE) > 1.0 and player.stats.get_value(Stats.FIRE_RATE) > 1.0)
	var target := Node3D.new()
	target.position = Vector3(0, 1.6, -2.2)
	var health := Health.new()
	health.max_health = 1000.0
	target.add_child(health)
	var hitbox := Hitbox.new()
	var collision := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.45
	collision.shape = shape
	hitbox.add_child(collision)
	target.add_child(hitbox)
	arena.add_child(target)
	for index in 3:
		await get_tree().physics_frame
	var original_health := health.health
	player.weapon._shoot_ray(player.get_node("Head/Camera3D").global_position, Vector3.FORWARD)
	_check("gun damage buff affects hit", is_equal_approx(original_health - health.health, player.weapon.data.damage * player.stats.get_value(Stats.DAMAGE)))
	for index in [3, 4, 5]:
		player.stats.apply_buff(BuffPool.ALL[index])
	var knife := player.melee.current()
	_check("blade upgrades damage, speed and reach",
		player.melee.strike_damage() > knife.damage * player.stats.get_value(Stats.DAMAGE)
		and player.melee.scaled_time(knife.windup) < knife.windup
		and player.melee.strike_reach() > knife.reach)
	# Knife reach is 1.8 m (2.16 m after the range card). The gun check above used
	# a 2.2 m target, which is past the blade's centre-distance test.
	target.position = Vector3(0, 1.6, -1.2)
	for index in 2:
		await get_tree().physics_frame
	original_health = health.health
	_check("V attack accepted", player.melee.swing_now())
	# Windup is shorter once fire-rate and blade-speed buffs apply, so the raw
	# `.tres` windup always finishes the phase. The strike lands 80% through active.
	player.melee._process(knife.windup)
	player.melee._process(player.melee.scaled_time(knife.active) * 0.85)
	_check("blade deals modified damage", is_equal_approx(original_health - health.health, player.melee.strike_damage()))
	_check("a swing in progress blocks another swing", not player.melee.swing_now())
	player.stats.apply_buff(BuffPool.ALL[6])
	player.stats.apply_buff(BuffPool.ALL[7])
	player.stats.apply_buff(BuffPool.ALL[8])
	_check("shield duration and cooldown upgraded", player.stats.get_value(Stats.SHIELD_DURATION) > 1.0 and player.shield.cooldown_duration() < 8.0)
	_check("unlocked shield activates", player.shield.try_activate() and player.shield.is_active())
	original_health = player.health.health
	player.health.apply_damage(50.0, Hitbox.BodyPart.BODY)
	_check("active shield blocks incoming damage", player.health.health == original_health)
	_check("cooldown prevents shield spam", not player.shield.try_activate())
	player.shield._process(player.shield.active_remaining + 0.01)
	player.health.apply_damage(10.0, Hitbox.BodyPart.BODY)
	_check("damage resumes after shield expires", is_equal_approx(player.health.health, original_health - 10.0))
	# The headless display cannot capture a mouse. A windowed proof also checks
	# the real Q/V action polling used by the player components.
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		player.shield._process(player.shield.cooldown_remaining + 0.01)
		player.shield.set_process(true)
		await get_tree().process_frame
		Input.action_press("shield")
		await get_tree().process_frame
		Input.action_release("shield")
		_check("G input activates shield in a game window", player.shield.is_active())
		if player.melee.is_swinging():
			player.melee.cancel()
		player.melee._cooldown = 0.0
		player.melee.set_process(true)
		original_health = health.health
		Input.action_press("melee")
		player.melee._process(0.001)
		Input.action_release("melee")
		player.melee._process(knife.windup)
		player.melee._process(player.melee.scaled_time(knife.active) * 0.85)
		_check("V input attacks in a game window", health.health < original_health)
	arena.queue_free()
	await get_tree().process_frame


func _play_run(indices: Array, label: String) -> void:
	RunState.start_new_run()
	BuffPool.reset(40408)
	var scene := load(RunState.zone_scene()).instantiate() as Node
	get_tree().root.add_child(scene)
	get_tree().current_scene = scene
	await _play_existing_run(indices, label)


func _play_existing_run(indices: Array, label: String) -> void:
	print("== complete " + label + " run")
	# Three picks: zone 0 enter, zone 0 clear, zone 1 clear. Zone 1 and the boss
	# have no entry offer. Restart still lands on zone 0, so its entry shot and
	# the check for selection_context == "enter" stay valid.
	var choice := 0
	for zone_index in RunState.ZONE_SCENES.size():
		var director := _director()
		_check("correct zone index", RunState.zone_index == zone_index)
		var boss_zone := zone_index == 2
		var expected_phase := ZoneDirector.Phase.BOSS_STANDING if boss_zone else ZoneDirector.Phase.CLEAR_GUARDS
		if zone_index == 0:
			_check("entry choice pauses before combat", get_tree().paused and director.selection_context == "enter" and director.phase == ZoneDirector.Phase.BUFF_SELECT)
			_check("guards have no target during entry", get_tree().get_nodes_in_group("enemy").all(func(e: Enemy): return e.target == null))
			await _shot("%s_%02d_entry" % [label, zone_index + 1])
			await _choose(director, indices[choice])
			choice += 1
			_check("entry chosen once and correct combat phase resumes", not get_tree().paused and director.phase == expected_phase)
		else:
			_check("later zone starts unpaused with no choice UI", not get_tree().paused and director.selection == null and director.selection_context.is_empty() and not director.get_children().any(func(c: Node): return c.has_signal("chosen")))
			_check("later zone is already in combat", director.phase == expected_phase)
			_check("guards already have a target", get_tree().get_nodes_in_group("enemy").all(func(e: Enemy): return e.target != null))
		var player := get_tree().get_first_node_in_group("player") as Player
		var expected := Stats.new()
		for buff: Buff in RunState.buffs:
			expected.apply_buff(buff)
		for stat: StringName in expected.base:
			_check("current scene preserves stacks: " + str(stat), is_equal_approx(expected.get_value(stat), player.stats.get_value(stat)))
		expected.free()
		if boss_zone:
			_check("this is the boss zone", director.is_boss_zone and director.boss != null)
			_check("the core stays shut while the Boss lives", director.phase == ZoneDirector.Phase.BOSS_STANDING and director.capture_point.locked and not director.boss.health.is_dead() and director.enemies_total == 7)
			for enemy: Enemy in get_tree().get_nodes_in_group("enemy"):
				enemy.set_physics_process(false)
			director.capture_point.player_in_reach = true
			director.capture_point.resolve_swing(2.5)
			_check("a hammer does nothing before the Boss falls", director.capture_point.progress == 0.0 and director.capture_point.locked)
			director.boss.health.apply_damage(99999.0, Hitbox.BodyPart.BODY)
			_check("the Boss's death opens the core with minions alive", director.phase == ZoneDirector.Phase.HAMMER_POINT and not director.capture_point.locked and get_tree().get_nodes_in_group("enemy").any(func(e: Enemy): return e != director.boss and not e.health.is_dead()))
			director.capture_point.resolve_swing(2.5)
		else:
			for enemy: Enemy in get_tree().get_nodes_in_group("enemy"):
				enemy.health.apply_damage(99999.0, Hitbox.BodyPart.BODY)
			_check("clear guards opens capture", director.phase == ZoneDirector.Phase.HAMMER_POINT)
			director.capture_point.player_in_reach = true
			for strike in 12:
				director.capture_point.resolve_swing(float(strike))
		_check("capture plants flag", director.phase == ZoneDirector.Phase.FLAG_PLANTED)
		# Repeated notification cannot create another reward screen.
		director._on_point_captured()
		if not RunState.is_last_zone():
			_check("flag does not open the reward by itself",
				director.selection == null and director.selection_context.is_empty() and not get_tree().paused)
			var pedestal := director.buff_pedestal
			_check("buff pedestal stands beside the flag", pedestal != null)
			player.global_position = pedestal.global_position
			Input.action_press("interact")
			await get_tree().physics_frame
			Input.action_release("interact")
			await get_tree().process_frame
			var expected_count := 2 if zone_index == 0 else 1
			_check("interact at the pedestal offers one reward", director.selection_context == "clear" and director.selection_count == expected_count)
			await _shot("%s_%02d_clear" % [label, zone_index + 1])
			await _choose(director, indices[choice])
			choice += 1
			for frame_index in 30:
				if get_tree().current_scene != null and _director().zone_index == zone_index + 1:
					break
				await get_tree().process_frame
		else:
			await get_tree().create_timer(ZoneDirector.FLAG_RAISE_TIME + 0.1).timeout
			var ending := _end_screen(director)
			_check("Boss ends with victory and no extra reward", director.selection_context.is_empty() and director.selection_count == 0 and ending != null)
			if ending != null:
				_check("one hammer wins after the Boss is dead", (ending.get_node("Center/Box/Title") as Label).text == "胜利" and director.boss.health.is_dead())
			await _shot(label + "_victory")
	var contexts: Array[String] = []
	for entry in RunState.selection_history:
		contexts.append("%d:%s" % [entry.zone_index, entry.context])
	_check("exactly three choices in expected order", contexts == EXPECTED_SELECTIONS and RunState.buffs.size() == 3)
	if label == "mixed":
		var schools := {}
		for buff: Buff in RunState.buffs:
			schools[buff.school_id] = true
		_check("mixed build keeps all three schools", schools.size() == 3)
	else:
		_check("linear build stays in selected school", RunState.buffs.all(func(b: Buff): return b.school_id == &"firearm"))
	print("SELECTION HISTORY " + label + ": " + str(contexts))


func _choose(director: ZoneDirector, index: int) -> void:
	var select := director.selection
	var choices := select.get_node("Center/Box/Choices")
	var count_before := RunState.buffs.size()
	var key := InputEventKey.new()
	key.physical_keycode = KEY_1 + index
	key.pressed = true
	Input.parse_input_event(key)
	# Synthetic events are accumulated just like platform events. Flush before
	# checking the synchronous result or the fallback click masks keyboard bugs.
	Input.flush_buffered_events()
	_check("number key selects card", RunState.buffs.size() == count_before + 1)
	# Repeated same-frame keyboard and mouse input must not add another buff.
	Input.parse_input_event(key.duplicate() as InputEventKey)
	Input.flush_buffered_events()
	(choices.get_child(index) as Button).pressed.emit()
	key = InputEventKey.new()
	key.physical_keycode = KEY_1 + index
	key.pressed = false
	Input.parse_input_event(key)
	Input.flush_buffered_events()
	_check("one selection despite duplicate input", RunState.buffs.size() == count_before + 1)
	await get_tree().process_frame


func _restart_from_end() -> void:
	var director := _director()
	for child in director.get_children():
		if child.has_signal("restart_pressed"):
			child.call("_on_restart")
			break
	for frame_index in 30:
		await get_tree().process_frame
		if get_tree().current_scene != null and _director().selection_context == "enter":
			return
	_check("restart reached entry", false)


func _end_screen(director: ZoneDirector) -> Node:
	for child in director.get_children():
		if child.has_signal("restart_pressed"):
			return child
	return null


func _director() -> ZoneDirector:
	return get_tree().current_scene.get_node("ZoneDirector") as ZoneDirector


func _shot(file_name: String) -> void:
	if _proof.is_empty():
		return
	for frame_index in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var path := _proof.path_join(file_name + ".png")
	_check("screenshot saved: " + file_name, get_viewport().get_texture().get_image().save_png(path) == OK)


func _binding_checks() -> void:
	print("== input bindings after the melee/shield merge")
	_check("Q cycles melee", _bound_key("switch_melee") == KEY_Q)
	_check("G is the shield", _bound_key("shield") == KEY_G)
	_check("F stays interact", _bound_key("interact") == KEY_F)
	_check("V swings the current melee", _bound_key("melee") == KEY_V)
	_check("E is still the capture hammer", _bound_key("hammer") == KEY_E)
	_check("R is still reload", _bound_key("reload") == KEY_R)
	_check("C throws the stored dangerous magazine", _bound_key("throw_magazine") == KEY_C)


func _bound_key(action: String) -> Key:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			return (event as InputEventKey).physical_keycode
	return KEY_NONE


func _check(label: String, ok: bool) -> void:
	if not ok:
		_failures += 1
	print("  [%s] %s" % ["ok" if ok else "FAIL", label])
