extends Node
## Depth wave tables, safe spawn pools, multi-wave scheduling and clear gating.
var checks := 0
var failures := 0

func check(label: String, passed: bool) -> void:
	checks += 1
	if not passed: failures += 1
	print("%s %s" % ["PASS" if passed else "FAIL",label])

func frames(count: int) -> void:
	for index in count: await get_tree().process_frame

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_check_tables()
	_check_spawn_pools()
	var first_positions := await _check_wrath_multi_wave()
	await _check_fear_signatures()
	await _check_sloth_depth_zero()
	await _check_determinism(first_positions)
	await _check_legacy_single_wave()
	OS.delay_msec(250)
	print("REALM WAVE ENCOUNTER: %d checks, %d failed" % [checks,failures])
	get_tree().quit(1 if failures else 0)

func _check_tables() -> void:
	var expected := [[[4],[6]],[[5],[5,4]],[[5,4],[6,5]],[[6,5],[6,5,4]]]
	var sloth_expected := [[[5],[7]],[[6],[5,4]],[[5,4],[6,5]],[[6,5],[6,5,4]]]
	var elites := [[[0],[0]],[[0],[0,1]],[[1,0],[1,1]],[[1,1],[1,1,1]]]
	var table_ok := true
	var elite_ok := true
	var signature_ok := true
	for depth in 4:
		for room in 2:
			for realm in [&"fear",&"wrath",&"sorrow",&"sloth"]:
				var encounter := RealmEncounter.new(depth,room,realm)
				var want: Array = sloth_expected[depth][room] if realm == &"sloth" else expected[depth][room]
				if encounter.wave_count() != want.size():
					table_ok = false
				for wave in encounter.wave_count():
					if encounter.wave_size(wave) != want[wave]:
						table_ok = false
					var slots := encounter.wave_slots(wave)
					if slots.size() != want[wave]:
						table_ok = false
					var marked := 0
					for slot in slots:
						if slot.elite:
							marked += 1
							if slot.type != &"regular": elite_ok = false
					if marked != elites[depth][room][wave] or encounter.elite_count(wave) != elites[depth][room][wave]:
						elite_ok = false
					var last: StringName = slots[-1].type
					if wave == 0 and realm == &"fear" and last != &"fear_reaper": signature_ok = false
					if wave == 0 and realm == &"sloth" and last != &"sloth_mire": signature_ok = false
					if wave == 1 and realm == &"fear" and room == 1 and (last == &"fear_reaper") != (depth >= 2): signature_ok = false
					if wave == 1 and realm == &"sloth" and (last == &"sloth_mire") != (depth >= 2): signature_ok = false
					if realm == &"wrath" and room == 1 and wave == 0 and slots[3].variant != 3: signature_ok = false
	check("wave counts match the depth table for all realms",table_ok)
	check("elite quotas mark only regular trailing slots",elite_ok)
	check("signature reapers, mires and the wrath READER follow the spec",signature_ok)
	check("depth four room two totals fifteen enemies",RealmEncounter.new(3,1,&"wrath").total_enemies() == 15)
	check("depth clamps into the authored range",RealmEncounter.new(9,-2,&"fear").wave_count() == RealmEncounter.new(3,0,&"fear").wave_count())

func _check_spawn_pools() -> void:
	var fear := FearRealm.new()
	var fear_points := fear.spawn_points()
	check("fear exposes eight spawn points",fear_points.size() == 8)
	check("fear keeps the four legacy island points first",fear_points.slice(0,4) == [Vector3(-7,0,8),Vector3(7,0,8),Vector3(-7,0,-8),Vector3(7,0,-8)])
	fear.free()
	var wrath := WrathRealm.new()
	var wrath_points := wrath.spawn_points()
	check("wrath exposes nine spawn points",wrath_points.size() == 9)
	check("wrath keeps the five legacy points first",wrath_points.slice(0,5) == [Vector3(-8,0.1,3),Vector3(8,0.1,-4),Vector3(0,0.1,-12),Vector3(-11,0.1,-12),Vector3(11,0.1,-14)])
	wrath.free()
	var sorrow := SorrowRealm.new()
	var sorrow_points := sorrow.spawn_points()
	check("sorrow exposes nine spawn points",sorrow_points.size() == 9)
	check("sorrow keeps clear basin anchor points first",sorrow_points.slice(0,5) == [Vector3(-8,0.1,3),Vector3(11.5,0.1,-4),Vector3(0,0.1,-12),Vector3(-11,0.1,-12),Vector3(11,0.1,-14)])
	sorrow.free()
	var sloth := SlothRealm.new()
	check("sloth wave pool covers nine court and terrace points",sloth.wave_spawn_points().size() == 9)
	check("sloth guard positions stay authored for style zero",sloth.guard_positions().size() == 5)
	sloth.chamber_style = 1
	check("sloth guard positions stay authored for style one",sloth.guard_positions().size() == 7)
	sloth.free()

func _make_stage(map: String, depth: int, hp: float, damage: float, tempo: float) -> RealmStage:
	var stage := (load(map) as PackedScene).instantiate() as RealmStage
	stage.campaign = true
	stage.hp_multiplier = hp
	stage.difficulty_multiplier = damage
	stage.tempo_multiplier = tempo
	stage.configure_run(depth,[],[],-1,[])
	add_child(stage)
	stage.player.set_physics_process(false)
	stage.player.set_process_unhandled_input(false)
	for actor in stage.enemies:
		actor.set_physics_process(false)
	return stage

func _kill(stage: RealmStage, actor: Enemy) -> void:
	actor.health.apply_damage(100000,Hitbox.BodyPart.BODY,stage.player,{"true_damage":true})

func _check_wrath_multi_wave() -> Array[Vector3]:
	var stage := _make_stage("res://maps/realms/wrath_2.tscn",1,1.35,1.15,1.08)
	await frames(4)
	var events: Array = []
	stage.wave_spawned.connect(func(s: RealmStage, wave: int, total: int) -> void:
		events.append([wave,total])
		for actor in s.enemies: actor.set_physics_process(false))
	var clears: Array = []
	stage.stage_cleared.connect(func(_s: RealmStage) -> void: clears.append(1))
	check("wave one spawns five enemies with the READER mixed in",stage.enemies.size() == 5 and (stage.enemies[3] as WrathRealmEnemy).variant == WrathRealmEnemy.Variant.READER)
	check("wave one reports two total waves and nine remaining",stage.current_wave() == 1 and stage.total_waves() == 2 and stage.has_pending_waves() and stage.remaining_encounter_enemies() == 9)
	check("wave one carries realm vector scaling without elites",is_equal_approx(stage.enemies[0].realm_hp_scale,1.35) and is_equal_approx(stage.enemies[0].realm_damage_scale,1.15) and is_equal_approx(stage.enemies[0].realm_tempo_scale,1.08) and not stage.enemies[0].is_elite)
	_kill(stage,stage.enemies[0])
	_kill(stage,stage.enemies[1])
	await frames(2)
	check("three survivors do not trigger reinforcements yet",stage.enemies.size() == 5 and stage.current_wave() == 1)
	_kill(stage,stage.enemies[2])
	await frames(3)
	check("two survivors trigger the second wave immediately",stage.enemies.size() == 9 and stage.living_enemies() == 6 and stage.current_wave() == 2)
	check("wave_spawned reports one-based indices",events == [[2,2]])
	check("no pending waves remain after the last wave",not stage.has_pending_waves() and stage.remaining_encounter_enemies() == 6)
	var elite := stage.enemies[8]
	check("the wave two quota elites exactly one regular",elite.is_elite and not stage.enemies[5].is_elite and not stage.enemies[6].is_elite and not stage.enemies[7].is_elite)
	check("elite shield tracks the scaled maximum",is_equal_approx(elite.health.max_shield,roundf(elite.health.max_health*0.65)) and elite.health.max_health > stage.enemies[5].health.max_health)
	var origin := stage.player.global_position
	var far_ok := true
	var distinct_ok := true
	var positions: Array[Vector3] = []
	for index in range(5,9):
		var point: Vector3 = stage.enemies[index].global_position
		positions.append(point)
		if Vector2(point.x-origin.x,point.z-origin.z).length() < 10.0: far_ok = false
		for other in positions.slice(0,-1):
			if point.distance_to(other) < 1.2: distinct_ok = false
	check("reinforcements land at least ten meters from the player",far_ok)
	check("reinforcements never share or stack spawn points",distinct_ok)
	check("pending reinforcements block the clear gate",not stage.cleared and clears.is_empty() and not is_instance_valid(stage.talent_orb))
	await frames(2)
	check("hud objective shows the wave counter",stage.hud._objective.text == "第 2/2 波 · 剩余 6")
	check("hud shows a non-blocking reinforcement toast",stage.hud._wave_notice.visible and stage.hud._wave_notice.text == "增援抵达 · 第 2/2 波")
	get_tree().paused = true
	var notice_left := stage.hud._wave_notice_left
	await frames(4)
	check("pause freezes the reinforcement toast",stage.hud._wave_notice_left == notice_left)
	get_tree().paused = false
	for index in range(3,9):
		_kill(stage,stage.enemies[index])
	await frames(3)
	check("clearing every wave opens the gate and drops the orb",stage.cleared and clears.size() == 1 and is_instance_valid(stage.talent_orb))
	stage.queue_free()
	await frames(4)
	return positions

func _check_fear_signatures() -> void:
	var stage := _make_stage("res://maps/realms/fear_2.tscn",2,1.85,1.32,1.18)
	await frames(4)
	check("fear wave one embeds the reaper within six total",stage.enemies.size() == 6 and stage.enemies[5] is FearReaper and stage.remaining_encounter_enemies() == 11)
	check("fear wave one elites one regular beside the reaper",stage.enemies[4].is_elite and not (stage.enemies[5] as FearReaper).is_elite)
	for index in 4:
		_kill(stage,stage.enemies[index])
	await frames(3)
	check("fear wave two adds a flank reaper within five total",stage.enemies.size() == 11 and stage.enemies[10] is FearReaper and stage.living_enemies() == 7)
	var reapers := 0
	var elites := 0
	for actor in stage.enemies:
		if actor is FearReaper: reapers += 1
		if actor.is_elite: elites += 1
	check("fear room two fields two reapers and two elites overall",reapers == 2 and elites == 2)
	stage.queue_free()
	await frames(4)

func _check_sloth_depth_zero() -> void:
	var stage := _make_stage("res://maps/realms/sloth_1.tscn",0,1.0,1.0,1.0)
	await frames(4)
	check("depth zero sloth keeps a single wave of five with a mire",stage.enemies.size() == 5 and stage.enemies[4] is SlothMire and stage.total_waves() == 1 and not stage.has_pending_waves())
	check("depth zero fields no elites",not stage.enemies[0].is_elite)
	for actor in stage.enemies.duplicate():
		_kill(stage,actor)
	await frames(3)
	check("single-wave depth zero still clears into the orb",stage.cleared and is_instance_valid(stage.talent_orb))
	stage.queue_free()
	await frames(4)

func _check_determinism(expected: Array[Vector3]) -> void:
	var stage := _make_stage("res://maps/realms/wrath_2.tscn",1,1.35,1.15,1.08)
	await frames(4)
	stage.wave_spawned.connect(func(s: RealmStage, _wave: int, _total: int) -> void:
		for actor in s.enemies: actor.set_physics_process(false))
	_kill(stage,stage.enemies[0])
	_kill(stage,stage.enemies[1])
	await frames(2)
	_kill(stage,stage.enemies[2])
	await frames(3)
	var same := stage.enemies.size() == 9
	if same:
		for index in 4:
			if stage.enemies[5+index].global_position.distance_to(expected[index]) > 0.001:
				same = false
	check("reinforcement selection replays identically without RNG",same)
	stage.queue_free()
	await frames(4)

func _check_legacy_single_wave() -> void:
	var stage := (load("res://maps/realms/wrath_2.tscn") as PackedScene).instantiate() as RealmStage
	add_child(stage)
	stage.player.set_physics_process(false)
	stage.player.set_process_unhandled_input(false)
	for actor in stage.enemies:
		actor.set_physics_process(false)
	await frames(2)
	check("standalone rooms keep the legacy single wave",stage.enemies.size() == 5 and stage.total_waves() == 1 and not stage.has_pending_waves() and stage.remaining_encounter_enemies() == 5)
	for actor in stage.enemies.duplicate():
		_kill(stage,actor)
	await frames(3)
	check("standalone rooms clear without wave gating",stage.cleared and is_instance_valid(stage.talent_orb))
	stage.queue_free()
	await frames(4)