extends Node3D
## Ticket 05 (#261): Phase A campaign integration seam.
## RunDirector installs production RealmStage rooms at depths 0..3 and the same
## public seam checks the three-axis depth vector, the lost-Sloth global haste,
## the boon/tempo orthogonality (no tempo²), the final FlawlessDoppelganger
## tuning and the fragment sustain bounds across a real room change.
##
## godot --headless --path . res://tests/difficulty_curve_phase_a_test.tscn

const HP_CURVE: Array[float] = [1.0, 1.35, 1.85, 2.45]
const DAMAGE_CURVE: Array[float] = [1.0, 1.15, 1.32, 1.50]
const TEMPO_CURVE: Array[float] = [1.0, 1.08, 1.18, 1.28]
const SLOTH_HASTE := 0.12
const SEED := 261005
const PLAYER_SCENE := preload("res://actors/player/player.tscn")
const BOSS_SCENE := preload("res://actors/boss/flawless_doppelganger/flawless_doppelganger.tscn")
const WISP_SCENE := preload("res://actors/enemy/fear/fear_wisp.tscn")

var checks := 0
var failures := 0
var _arena: Node3D


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	MetaProgression.introduced_realms.assign([0,1,2,3])
	RunDirector.randomize_realm_order = false
	await _run_final_boss()
	await _free_arena()
	get_tree().current_scene = null
	RunDirector.begin_run(SEED)
	RunDirector.order.assign([0,1,2,3])
	await _run_depth_curve()
	var hasted_fear := await _run_sloth_haste()
	await _run_boon_orthogonality(hasted_fear)
	await _run_review_edge_guards()
	await _run_fragment_sustain()
	await _finish()


func _run_final_boss() -> void:
	_arena = Node3D.new()
	_arena.name = "BossArena"
	add_child(_arena)
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = CollisionLayers.WORLD
	floor_body.collision_mask = CollisionLayers.NONE
	floor_body.position = Vector3(0,-0.5,0)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(80,1,80)
	shape.shape = box
	floor_body.add_child(shape)
	_arena.add_child(floor_body)

	var player := PLAYER_SCENE.instantiate() as Player
	_arena.add_child(player)
	player.position = Vector3(0,0.05,8)
	player.set_physics_process(false)
	player.set_process_unhandled_input(false)
	player.health.max_health = 100000.0
	player.health.health = 100000.0
	await _frames(3)

	var boss := BOSS_SCENE.instantiate() as FlawlessDoppelganger
	_arena.add_child(boss)
	boss.position = Vector3.ZERO
	boss.setup(player,[])
	player.boons.register_enemy(boss)
	boss.set_combat_active(true)
	await _frames(3)

	check("final shell enters with the endgame body",
		is_equal_approx(boss.health.max_health,FlawlessDoppelganger.BASE_HEALTH)
		and is_equal_approx(boss.health.health,FlawlessDoppelganger.BASE_HEALTH)
		and is_equal_approx(FlawlessDoppelganger.BASE_HEALTH,3600.0))
	check("final gun and blade carry the 14 / 28 endgame damage",
		is_equal_approx(FlawlessDoppelganger.GUN_DAMAGE,14.0)
		and is_equal_approx(FlawlessDoppelganger.SLASH_DAMAGE,28.0))

	boss.locked_point = player.global_position+Vector3.UP
	var before := player.health.health
	boss._fire()
	await _frames(18)
	check("a real final bullet removes 14 HP", is_equal_approx(before-player.health.health,14.0))

	boss.position = Vector3.ZERO
	player.position = Vector3(0,0.05,8)
	boss.begin_move(FlawlessDoppelganger.Move.DASH_BLADE)
	before = player.health.health
	await _frames(60)
	check("a real final slash and crescent remove 28 + 16 HP", is_equal_approx(before-player.health.health,FlawlessDoppelganger.SLASH_DAMAGE+FlawlessDoppelganger.CRESCENT_DAMAGE) and boss.slashes==1)

	boss.health.health = boss.health.max_health
	boss._recover()
	check("readable recover window holds above 55% HP",
		boss.phase==FlawlessDoppelganger.Phase.RECOVER and is_equal_approx(boss.phase_left,0.85))
	boss.phase_left = 0.0
	await _frames(1)
	check("readable wait gap holds above 55% HP",
		boss.phase==FlawlessDoppelganger.Phase.WAIT and is_equal_approx(boss.phase_left,0.25))
	boss.health.health = boss.health.max_health*0.56
	boss._recover()
	check("56% HP still keeps the readable recover window", is_equal_approx(boss.phase_left,0.85))
	boss.health.health = boss.health.max_health*0.55
	boss._recover()
	check("exact 55% HP still keeps the readable recover window", is_equal_approx(boss.phase_left,0.85))
	boss.health.health = boss.health.max_health*0.54
	boss._recover()
	check("below 55% HP compresses the recover window to 0.55 s",
		boss.phase==FlawlessDoppelganger.Phase.RECOVER and is_equal_approx(boss.phase_left,0.55))
	boss.phase_left = 0.0
	await _frames(1)
	check("below 55% HP compresses the wait gap to 0.15 s",
		boss.phase==FlawlessDoppelganger.Phase.WAIT and is_equal_approx(boss.phase_left,0.15))

	boss._expose(1.6,&"spite_wall")
	await _frames(6)
	check("high pressure does not shorten the EXPOSED punish window (%.3f)" % boss.phase_left,
		absf(boss.phase_left-1.5)<0.015)

	boss.health.health = boss.health.max_health
	boss.set_realm_tempo(1.4)
	boss.begin_move(FlawlessDoppelganger.Move.GUN)
	var hasted_windup := 0
	while boss.phase == FlawlessDoppelganger.Phase.WINDUP and hasted_windup < 60:
		await get_tree().physics_frame
		hasted_windup += 1
	check("explicit 1.4x realm tempo shortens final boss gun windup (%d frames)" % hasted_windup,
		hasted_windup >= 18 and hasted_windup <= 22)
	boss.set_realm_tempo(1.0)
	boss.phase = FlawlessDoppelganger.Phase.RECOVER
	boss.health.health = boss.health.max_health
	boss.phase_left = 1.0
	await _frames(1)
	var calm_start := boss.phase_left
	await _frames(10)
	var calm_clock := calm_start-boss.phase_left
	boss.health.health = boss.health.max_health*0.5
	boss.phase_left = 1.0
	await _frames(1)
	var pressure_start := boss.phase_left
	await _frames(10)
	var pressure_clock := pressure_start-boss.phase_left
	check("high pressure advances the phase clock at 1.30x (%.3f)" % (pressure_clock/calm_clock),
		absf(pressure_clock/calm_clock-1.30)<0.03)


func _free_arena() -> void:
	if is_instance_valid(_arena):
		_arena.free()
	_arena = null
	await _frames(2)


func _run_depth_curve() -> void:
	var realms: Array[int] = []
	for depth in 4:
		RunDirector.floor_index = depth
		RunDirector.room_index = 1
		var err := RunDirector.install_stage(load(RunDirector.scene_path()))
		check("depth %d production realm room installs through RunDirector" % [depth+1], err==OK)
		await _frames(6)
		var stage := RunDirector.current_stage as RealmStage
		if stage==null:
			check("depth %d production realm stage exists" % [depth+1],false)
			continue
		realms.append(stage.realm)
		stage.player.set_physics_process(false)
		stage.player.set_process_unhandled_input(false)
		for actor in stage.enemies:
			actor.set_physics_process(false)
		var profile := RunDirector.difficulty_profile(depth)
		var tempo := float(profile["tempo_scale"])
		var vector_ok := not stage.enemies.is_empty()
		var health_ok := vector_ok
		var speed_ok := vector_ok
		for actor in stage.enemies:
			vector_ok = vector_ok \
				and is_equal_approx(actor.realm_hp_scale,float(profile["hp_scale"])) \
				and is_equal_approx(actor.realm_damage_scale,float(profile["damage_scale"])) \
				and is_equal_approx(actor.realm_tempo_scale,tempo)
			var authored := _authored_base_stats(actor)
			var elite_hp := 1.25 if actor.is_elite else 1.0
			health_ok = health_ok and is_equal_approx(actor.health.max_health,float(authored["hp"])*elite_hp*float(profile["hp_scale"]))
			var base_speed := float(authored["speed"])
			var elite_tempo := actor.elite_tempo_scale if actor.is_elite else 1.0
			var expected := 0.0 if is_zero_approx(base_speed) else base_speed*(1.0+((tempo*elite_tempo)-1.0)*0.5)
			speed_ok = speed_ok and is_equal_approx(actor.run_speed,expected)
		check("depth %d actors carry the hp/damage/tempo vector" % [depth+1],vector_ok)
		check("depth %d real max health follows %.2fx for elites and regulars" % [depth+1,float(profile["hp_scale"])],health_ok)
		check("depth %d run speed follows half-strength tempo with the elite layer" % [depth+1],speed_ok)
		check("depth %d keeps the scalar damage entry at %.2f" % [depth+1,float(profile["damage_scale"])],
			is_equal_approx(RunDirector.difficulty(depth),float(profile["damage_scale"])))
	check("four depths host all four realms in production rooms",realms==[0,1,2,3])
	var canonical := RunDirector.difficulty_profile(2)
	RunDirector.order.assign([3,2,1,0])
	check("the depth vector does not depend on realm identity",RunDirector.difficulty_profile(2)==canonical)
	RunDirector.order.assign([0,1,2,3])
	check("the depth curves match the locked Phase A table",
		RunDirector.hp_scale(0)==HP_CURVE[0] and RunDirector.hp_scale(3)==HP_CURVE[3]
		and RunDirector.damage_scale(0)==DAMAGE_CURVE[0] and RunDirector.damage_scale(3)==DAMAGE_CURVE[3]
		and RunDirector.tempo_scale(0,[])==TEMPO_CURVE[0] and RunDirector.tempo_scale(3,[])==TEMPO_CURVE[3])


func _run_sloth_haste() -> RealmStage:
	var calm := await _install_run_room(1,[],1)
	var calm_watcher := await _prepare_watcher(calm)
	if calm_watcher==null:
		check("production fear room owns a real watcher",false)
		return calm
	var calm_cycle := await _measure_watcher_cycle(calm_watcher)
	check("depth 2 without Sloth keeps tempo %.2f" % calm_watcher.realm_tempo_scale,
		is_equal_approx(calm_watcher.realm_tempo_scale,TEMPO_CURVE[1]))
	check("unhasted watcher windup matches its authored 1.6 s at 1/tempo (%d frames)" % calm_cycle.windup,
		absf(float(calm_cycle.windup)-60.0*1.6/calm_watcher.realm_tempo_scale)<=4.0)

	var hasted := await _install_run_room(1,[0],1)
	var hasted_watcher := await _prepare_watcher(hasted)
	if hasted_watcher==null:
		check("hasted production fear room owns a real watcher",false)
		return hasted
	var hasted_cycle := await _measure_watcher_cycle(hasted_watcher)
	check("lost Sloth adds exactly +0.12 to the same room tempo",
		is_equal_approx(hasted_watcher.realm_tempo_scale,TEMPO_CURVE[1]+SLOTH_HASTE))
	check("the room never folds the lost-Sloth haste twice",
		is_equal_approx(hasted.tempo_multiplier,TEMPO_CURVE[1]+SLOTH_HASTE)
		and hasted.tempo_includes_sloth_haste
		and is_equal_approx(RunDirector.tempo_scale(1,[0]),TEMPO_CURVE[1]+SLOTH_HASTE))
	check("lost Sloth completes the same windup in fewer physics frames (%d vs %d)" % [hasted_cycle.windup,calm_cycle.windup],
		hasted_cycle.windup>0 and hasted_cycle.windup<calm_cycle.windup)
	check("lost Sloth completes the same cooldown in fewer physics frames (%d vs %d)" % [hasted_cycle.cooldown,calm_cycle.cooldown],
		hasted_cycle.cooldown>0 and hasted_cycle.cooldown<calm_cycle.cooldown)
	var expected_ratio := (TEMPO_CURVE[1]+SLOTH_HASTE)/TEMPO_CURVE[1]
	var windup_ratio := float(calm_cycle.windup)/float(hasted_cycle.windup)
	check("the lost-Sloth windup ratio is one tempo step, not tempo² (%.3f)" % windup_ratio,
		absf(windup_ratio-expected_ratio)<0.06 and windup_ratio<1.19)
	check("hasted watcher windup stays at 1/tempo, not 1/tempo² (%d frames)" % hasted_cycle.windup,
		absf(float(hasted_cycle.windup)-60.0*1.6/hasted_watcher.realm_tempo_scale)<=4.0)
	return hasted


func _run_boon_orthogonality(hasted_fear: RealmStage) -> void:
	var watcher := _find_watcher(hasted_fear)
	if watcher==null:
		check("the hasted production room still owns its watcher",false)
		return
	var tempo := watcher.realm_tempo_scale

	hasted_fear.player.boons.set_status(watcher,&"phase_a_slow",60.0,1.0,1.0,false,1.0,false,0.6)
	check("boon slow composes with realm tempo instead of replacing it",
		is_equal_approx(watcher.realm_tempo_scale,tempo)
		and is_equal_approx(watcher.effective_attack_scale(),0.6*tempo))
	hasted_fear.player.boons.clear_status(watcher,&"phase_a_slow")
	check("clearing the slow restores the full realm cadence",
		is_equal_approx(watcher.realm_tempo_scale,tempo)
		and is_equal_approx(watcher.effective_attack_scale(),tempo))

	hasted_fear.player.boons.set_status(watcher,&"phase_a_windup",60.0,1.0,1.0,false,1.3)
	check("plain-delta watcher exposes boon-only windup over a single tempo",
		is_equal_approx(watcher.boon_windup_scale,1.3)
		and is_equal_approx(watcher.windup(),1.6*1.3/tempo))
	var plain_with_boon := await _measure_watcher_windup(watcher)
	hasted_fear.player.boons.clear_status(watcher,&"phase_a_windup")
	check("clearing the watcher boon keeps realm tempo and restores one compression",
		is_equal_approx(watcher.realm_tempo_scale,tempo)
		and is_equal_approx(watcher.boon_windup_scale,1.0)
		and is_equal_approx(watcher.windup(),1.6/tempo))
	var plain_without := await _measure_watcher_windup(watcher)
	check("plain-delta windup expands by exactly the boon factor (%d vs %d frames)" % [plain_with_boon,plain_without],
		plain_with_boon>0 and plain_without>0
		and absf(float(plain_with_boon)/float(plain_without)-1.3)<0.09)
	check("plain-delta windup keeps a single 1/tempo compression (%d vs %.1f frames)" % [plain_without,60.0*1.6/tempo],
		absf(float(plain_without)-60.0*1.6/tempo)<=4.0)

	var summoner := _find_watcher(hasted_fear)
	var wisp := WISP_SCENE.instantiate()
	add_child(wisp)
	wisp.activate(hasted_fear.player.global_position+Vector3(0,0.05,2),summoner,hasted_fear.player)
	wisp.set_physics_process(false)
	var summoner_tempo := summoner.realm_tempo_scale
	check("FearWisp health follows the summoner's realm hp scale (%.2f)" % wisp.health.max_health,
		is_equal_approx(wisp.health.max_health,18.0*summoner.realm_hp_scale))
	check("FearWisp inherits the summoner's damage and tempo axes",
		is_equal_approx(wisp.realm_damage_scale,summoner.realm_damage_scale)
		and is_equal_approx(wisp.realm_tempo_scale,summoner_tempo))
	check("FearWisp chase speed follows half-strength tempo",
		is_equal_approx(wisp.run_speed,FearWisp.SPEED*(1.0+(summoner_tempo-1.0)*0.5)))
	check("FearWisp windup divides the realm tempo exactly once",
		is_equal_approx(FearWisp.WINDUP*wisp.effective_windup_scale(),FearWisp.WINDUP/summoner_tempo))
	wisp.queue_free()
	await _frames(2)

	var wrath := await _install_run_room(2,[0],1)
	var piercer := await _prepare_piercer(wrath)
	if piercer==null:
		check("production wrath room owns a real piercer",false)
		return
	var clock_tempo := piercer.realm_tempo_scale
	wrath.player.boons.set_status(piercer,&"phase_a_windup",60.0,1.0,1.0,false,1.3)
	check("clock-multiplied piercer keeps the boon windup outside the clock",
		is_equal_approx(piercer.realm_tempo_scale,clock_tempo)
		and is_equal_approx(piercer.boon_windup_scale,1.3)
		and is_equal_approx(piercer.effective_windup_scale(),1.3/clock_tempo))
	var clock_with_boon := await _measure_piercer_windup(piercer)
	wrath.player.boons.clear_status(piercer,&"phase_a_windup")
	check("clearing the piercer boon keeps realm tempo intact",
		is_equal_approx(piercer.realm_tempo_scale,clock_tempo)
		and is_equal_approx(piercer.boon_windup_scale,1.0))
	var clock_without := await _measure_piercer_windup(piercer)
	check("piercer windup expands by exactly the boon factor (%d vs %d frames)" % [clock_with_boon,clock_without],
		clock_with_boon>0 and clock_without>0
		and absf(float(clock_with_boon)/float(clock_without)-1.3)<0.12)
	check("piercer windup keeps a single 1/tempo compression (%d vs %.1f frames)" % [clock_without,60.0*0.75/clock_tempo],
		absf(float(clock_without)-60.0*0.75/clock_tempo)<=3.0)


func _run_fragment_sustain() -> void:
	var stage := await _install_run_room(2,[],0,[0,3],40.0)
	if stage==null:
		check("production fragment room installs",false)
		return
	var player := stage.player
	player.set_process_unhandled_input(false)
	player.boons.clear()
	RunDirector.boons.clear()
	player.health.max_health = 1000.0
	player.health.health = 40.0
	for actor in stage.enemies:
		actor.set_physics_process(false)
	await _clear_all_waves(stage)
	check("the Sorrow shard restores the 40 point Tenderness barrier",
		is_equal_approx(player.fragments.barrier,PsycheFragments.TENDERNESS_CAPACITY)
		and is_equal_approx(PsycheFragments.TENDERNESS_CAPACITY,40.0))
	check("the Tenderness recovery delay is 6.5 s",
		is_equal_approx(PsycheFragments.TENDERNESS_RECOVERY_DELAY,6.5))

	player.fragments.barrier = PsycheFragments.TENDERNESS_CAPACITY
	player.health.apply_damage(40,Hitbox.BodyPart.BODY)
	check("absorbing a hit empties the barrier and starts the 6.5 s delay",
		is_zero_approx(player.fragments.barrier)
		and is_equal_approx(player.fragments._barrier_recovery,6.5))
	await _frames(300)
	check("the barrier stays empty through the first five seconds",is_zero_approx(player.fragments.barrier))
	player.health.apply_damage(1,Hitbox.BodyPart.BODY)
	check("a hit while Tenderness is empty resets the 6.5 s delay",
		is_zero_approx(player.fragments.barrier)
		and is_equal_approx(player.fragments._barrier_recovery,6.5))
	await _frames(360)
	check("the barrier stays empty through six seconds after the second hit",is_zero_approx(player.fragments.barrier))
	await _frames(60)
	check("the barrier resumes after the six and a half second delay",
		player.fragments.barrier>1.0 and player.fragments.barrier<10.0)

	player.health.health = 40.0
	player.fragments.room_healed = PsycheFragments.SLUMBER_ROOM_HEAL_CAP-1.0
	player.fragments.mark_combat()
	player.fragments.since_combat = 5.0
	await _frames(90)
	check("Slumber stops at the 30 HP per-room cap",
		player.health.health>40.99 and player.health.health<41.01
		and is_equal_approx(player.fragments.room_healed,PsycheFragments.SLUMBER_ROOM_HEAL_CAP))
	var capped_hp := player.health.health
	await _frames(60)
	check("an exhausted Slumber budget keeps idling HP frozen",
		is_equal_approx(player.health.health,capped_hp)
		and is_equal_approx(player.fragments.room_healed,PsycheFragments.SLUMBER_ROOM_HEAL_CAP))

	player.fragments.barrier = 30.0
	player.health.apply_damage(10,Hitbox.BodyPart.BODY)
	var saved_barrier := player.fragments.barrier
	check("a fresh absorbed hit re-arms the cross-room Tenderness delay",
		is_equal_approx(saved_barrier,20.0) and is_equal_approx(player.fragments._barrier_recovery,6.5))
	RunDirector.capture_player(player)
	check("the same-room snapshot keeps the used Slumber budget",
		is_equal_approx(float(RunDirector.fragment_state.get("room_healed",-1.0)),PsycheFragments.SLUMBER_ROOM_HEAL_CAP))
	check("the same-room snapshot carries the Tenderness delay",
		is_equal_approx(float(RunDirector.fragment_state.get("recovery",-1.0)),6.5))

	var revived := PLAYER_SCENE.instantiate() as Player
	add_child(revived)
	revived.set_physics_process(false)
	RunDirector.restore_player(revived)
	check("a same-room restore keeps the used Slumber budget",
		is_equal_approx(revived.fragments.room_healed,PsycheFragments.SLUMBER_ROOM_HEAL_CAP))
	check("a same-room restore keeps the barrier and its recovery delay",
		is_equal_approx(revived.fragments.barrier,saved_barrier)
		and is_equal_approx(revived.fragments._barrier_recovery,6.5))
	revived.free()

	check("advancing a room clears only the Slumber budget",
		RunDirector.advance_room() and RunDirector.room_index==1
		and is_zero_approx(float(RunDirector.fragment_state.get("room_healed",-1.0))))
	check("advancing a room keeps the Tenderness barrier and delay",
		is_equal_approx(float(RunDirector.fragment_state.get("barrier",-1.0)),saved_barrier)
		and is_equal_approx(float(RunDirector.fragment_state.get("recovery",-1.0)),6.5))

	var next := await _install_current_room()
	if next==null:
		check("the next production room installs",false)
		return
	var next_player := next.player
	check("the next room arrives with a fresh Slumber budget",
		is_zero_approx(next_player.fragments.room_healed))
	check("the next room keeps the independent shards",
		next_player.fragments.shards.has(0) and next_player.fragments.shards.has(3))
	check("the next room keeps the Tenderness barrier and 6.5 s delay",
		is_equal_approx(next_player.fragments.barrier,saved_barrier)
		and is_equal_approx(next_player.fragments._barrier_recovery,6.5))
	next_player.set_process_unhandled_input(false)
	for actor in next.enemies:
		actor.set_physics_process(false)
	next_player.health.max_health = 1000.0
	await _frames(60)
	check("the carried Tenderness delay blocks early recharge in the new room",
		is_equal_approx(next_player.fragments.barrier,saved_barrier))


func _run_review_edge_guards() -> void:
	var reaper_probe := preload("res://actors/enemy/fear/fear_reaper.tscn").instantiate() as FearReaper
	reaper_probe.set_realm_tempo(1.4)
	add_child(reaper_probe)
	await _frames(2)
	check("pre-ready tempo uses FearReaper authored 2.4 base speed (%.2f)" % reaper_probe.run_speed,
		is_equal_approx(reaper_probe.run_speed,2.4*(1.0+(1.4-1.0)*0.5)))
	reaper_probe.queue_free()
	await _frames(2)

	var fear_stage := await _install_run_room(1,[],1)
	_guard_player(fear_stage)
	var live_reaper: FearReaper = null
	for actor in fear_stage.enemies:
		actor.set_physics_process(false)
		if actor is FearReaper:
			live_reaper = actor as FearReaper
	var live_wisp: FearWisp = null
	if live_reaper != null:
		live_reaper._summon()
		var wisps := live_reaper.living_wisps()
		if not wisps.is_empty():
			live_wisp = wisps[0]
			live_wisp.set_physics_process(false)
	fear_stage.configure_run(1,[0],[],100.0,[])
	check("live Sloth deprivation refresh propagates to active FearWisp",
		live_reaper != null and live_wisp != null
		and is_equal_approx(live_reaper.realm_tempo_scale,TEMPO_CURVE[1]+SLOTH_HASTE)
		and is_equal_approx(live_wisp.realm_tempo_scale,TEMPO_CURVE[1]+SLOTH_HASTE))
	fear_stage.configure_run(1,[],[],100.0,[])
	check("clearing Sloth deprivation restores base room tempo on reaper and wisp",
		live_reaper != null and live_wisp != null
		and is_equal_approx(live_reaper.realm_tempo_scale,TEMPO_CURVE[1])
		and is_equal_approx(live_wisp.realm_tempo_scale,TEMPO_CURVE[1]))

	var wrath_boss := await _install_run_room(2,[0],2)
	_guard_player(wrath_boss)
	var spire := wrath_boss.boss as WrathSpire
	if spire != null:
		spire.set_realm_tempo(1.4)
		wrath_boss.player.global_position = Vector3(0,0.05,4)
		await _frames(1)
		spire.begin_move(WrathSpire.Move.ERUPTION)
		var windup_ticks := 0
		var hit_ticks := 0
		var hp_before := wrath_boss.player.health.health
		for tick in range(1,90):
			await get_tree().physics_frame
			if windup_ticks == 0 and spire.attack_phase != WrathRealmEnemy.Attack.WINDUP:
				windup_ticks = tick
			if hit_ticks == 0 and wrath_boss.player.health.health < hp_before:
				hit_ticks = tick
				break
		check("WrathSpire eruption hits in lockstep with 1.4x windup (%d vs %d ticks, spawned=%d)" % [hit_ticks,windup_ticks,spire.spawned_eruptions],
			spire.spawned_eruptions > 0 and windup_ticks >= 39 and windup_ticks <= 43 and abs(hit_ticks-windup_ticks) <= 2)

	var sloth_boss := await _install_run_room(0,[0],2)
	_guard_player(sloth_boss)
	var colossus := sloth_boss.boss as SlothColossus
	if colossus != null:
		colossus.set_realm_tempo(1.4)
		colossus.attack_finished()
		var before_attacks := colossus.attacks_started
		var wait_ticks := 0
		while colossus.attacks_started == before_attacks and wait_ticks < 110:
			await get_tree().physics_frame
			wait_ticks += 1
		check("SlothColossus recovery scales with 1.4x tempo (%d ticks)" % wait_ticks,
			wait_ticks >= 39 and wait_ticks <= 43)


func _authored_base_stats(actor: Enemy) -> Dictionary:
	if actor is SlothEnemy:
		var k := (actor as SlothEnemy).kind
		return {"hp":[90.0,140.0,180.0][k],"speed":[2.8,2.1,2.4][k]}
	if actor is SlothMire:
		return {"hp":105.0,"speed":2.45}
	if actor is FearReaper:
		return {"hp":140.0,"speed":2.4}
	if actor is FearRealmEnemy:
		var v := (actor as FearRealmEnemy).variant
		return {"hp":[65.0,85.0,115.0][v],"speed":[0.0,3.4,5.0][v]}
	if actor is WrathRealmEnemy:
		var v := (actor as WrathRealmEnemy).variant
		return {"hp":[110.0,220.0,160.0,90.0][v],"speed":[3.6,1.6,5.0,WrathRealmEnemy.READER_WALK_SPEED][v]}
	if actor is SorrowRealmEnemy:
		var v := (actor as SorrowRealmEnemy).variant
		return {"hp":[110.0,230.0,130.0][v],"speed":[2.7,1.6,0.7][v]}
	return {"hp":actor.health.max_health,"speed":actor.run_speed}


func _clear_all_waves(stage: RealmStage) -> void:
	stage.wave_spawned.connect(func(s: RealmStage, _wave: int, _total: int) -> void:
		for actor in s.enemies:
			actor.set_physics_process(false))
	var guard := 0
	while (stage.living_enemies() > 0 or stage.has_pending_waves()) and guard < 16:
		for actor in stage.enemies:
			actor.set_physics_process(false)
			if is_instance_valid(actor) and not actor.health.is_dead():
				actor.health.apply_damage(100000,Hitbox.BodyPart.BODY,stage.player,{"true_damage":true})
		await _frames(4)
		guard += 1


func _install_run_room(depth: int, deprivations: Array, room: int,
		shards: Array = [], hp: float = -1.0) -> RealmStage:
	RunDirector.begin_run(SEED)
	RunDirector.order.assign([0,1,2,3])
	RunDirector.deprivations.assign(deprivations)
	RunDirector.shards.assign(shards)
	if hp>=0.0:
		RunDirector.hp = hp
	RunDirector.floor_index = depth
	RunDirector.room_index = room
	var err := RunDirector.install_stage(load(RunDirector.scene_path()))
	check("production room %s installs" % RunDirector.scene_path().get_file(),err==OK)
	await _frames(6)
	return RunDirector.current_stage as RealmStage


func _install_current_room() -> RealmStage:
	var err := RunDirector.install_stage(load(RunDirector.scene_path()))
	check("next production room %s installs" % RunDirector.scene_path().get_file(),err==OK)
	return RunDirector.current_stage as RealmStage


func _guard_player(stage: RealmStage) -> void:
	var player := stage.player
	player.set_physics_process(false)
	player.set_process_unhandled_input(false)
	player.boons.clear()
	player.health.max_health = 100000.0
	player.health.health = 100000.0


func _prepare_watcher(stage: RealmStage) -> FearRealmEnemy:
	_guard_player(stage)
	for actor in stage.enemies:
		actor.set_physics_process(false)
	var watcher := _find_watcher(stage)
	if watcher==null:
		return null
	stage.player.global_position = Vector3(0,0.2,0)
	stage.player.rotation.y = 0.0
	watcher.global_position = Vector3(0,0.05,10)
	watcher.set_physics_process(true)
	await _frames(3)
	return watcher


func _prepare_piercer(stage: RealmStage) -> WrathRealmEnemy:
	_guard_player(stage)
	for actor in stage.enemies:
		actor.set_physics_process(false)
	var piercer := _find_piercer(stage)
	if piercer==null:
		return null
	stage.player.global_position = Vector3(0,0.2,0)
	stage.player.rotation.y = 0.0
	piercer.global_position = Vector3(0,0.05,-6)
	piercer.set_physics_process(true)
	await _frames(3)
	return piercer


func _find_watcher(stage: RealmStage) -> FearRealmEnemy:
	if stage==null:
		return null
	for actor in stage.enemies:
		if actor is FearRealmEnemy and (actor as FearRealmEnemy).variant==FearRealmEnemy.Variant.WATCHER:
			return actor as FearRealmEnemy
	return null


func _find_piercer(stage: RealmStage) -> WrathRealmEnemy:
	if stage==null:
		return null
	for actor in stage.enemies:
		if actor is WrathRealmEnemy and (actor as WrathRealmEnemy).variant==WrathRealmEnemy.Variant.PIERCER:
			return actor as WrathRealmEnemy
	return null


func _measure_watcher_cycle(watcher: FearRealmEnemy) -> Dictionary:
	watcher.attack_elapsed = -1.0
	watcher.attack_cooldown = 0.0
	if not watcher.start_attack():
		return {"windup":-1,"cooldown":-1}
	var frames := 0
	while watcher.attack_elapsed>=0.0 and frames<400:
		await get_tree().physics_frame
		frames += 1
	var windup := frames
	frames = 0
	while watcher.attack_cooldown>0.0 and frames<400:
		await get_tree().physics_frame
		frames += 1
	return {"windup":windup,"cooldown":frames}


func _measure_watcher_windup(watcher: FearRealmEnemy) -> int:
	watcher.attack_elapsed = -1.0
	watcher.attack_cooldown = 0.0
	if not watcher.start_attack():
		return -1
	var frames := 0
	while watcher.attack_elapsed>=0.0 and frames<300:
		await get_tree().physics_frame
		frames += 1
	return frames


func _measure_piercer_windup(piercer: WrathRealmEnemy) -> int:
	piercer.attack_phase = WrathRealmEnemy.Attack.APPROACH
	piercer.attack_left = 0.0
	piercer.start_attack()
	var frames := 0
	while piercer.attack_phase==WrathRealmEnemy.Attack.WINDUP and frames<200:
		await get_tree().physics_frame
		frames += 1
	return frames


func _finish() -> void:
	if is_instance_valid(RunDirector.current_stage):
		RunDirector.current_stage.free()
	RunDirector.current_stage = null
	get_tree().current_scene = null
	RunDirector.finish_campaign()
	RunDirector.randomize_realm_order = true
	await _frames(3)
	OS.delay_msec(250)
	await get_tree().process_frame
	print("DIFFICULTY CURVE PHASE A: %s (%d checks, %d failed)" % [
		"ALL PASSED" if failures==0 else "FAIL",checks,failures])
	get_tree().quit(0 if failures==0 else 1)


func _frames(count: int) -> void:
	for index in count:
		await get_tree().physics_frame


func check(label: String,passed: bool) -> void:
	checks += 1
	if not passed:
		failures += 1
	print("%s %s" % ["PASS" if passed else "FAIL",label])
