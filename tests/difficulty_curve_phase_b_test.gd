extends Node3D
## Ticket 05 (#270): Phase B end-to-end seam.
## RunDirector installs production RealmStage rooms for the depth-wave sweep,
## the legacy single-room entry and all four campaign bosses. BoonManager is
## then exercised through real SlothColossus, FlawlessDoppelganger, ordinary and
## elite targets.
##
## godot --headless --path . res://tests/difficulty_curve_phase_b_test.tscn

const PLAYER_SCENE := preload("res://actors/player/player.tscn")
const PLAIN_ENEMY_SCENE := preload("res://actors/enemy/enemy.tscn")
const COLOSSUS_SCENE := preload("res://actors/boss/sloth_colossus/sloth_colossus.tscn")
const FLAWLESS_SCENE := preload("res://actors/boss/flawless_doppelganger/flawless_doppelganger.tscn")
const SEED := 270005
const CAMERA_ORIGIN := Vector3(0, 60, 0)
const ELITE_LAYER := 1.10
const BOSS_PHASE_LAYER := 1.20

var checks := 0
var failures := 0
var _cc_arena: Node3D
var _cc_player: Player
var _cc: BoonManager


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	MetaProgression.introduced_realms.assign([0, 1, 2, 3])
	RunDirector.randomize_realm_order = false
	await get_tree().process_frame
	get_tree().current_scene = null
	RunDirector.begin_run(SEED)
	RunDirector.order.assign([0, 1, 2, 3])
	await _run_wave_density()
	await _run_reinforcement_trigger()
	await _run_legacy_single_room()
	await _run_boss_phases()
	await _run_boss_cc_dr()
	await _run_codex_regressions()
	await _finish()


func _run_wave_density() -> void:
	for depth in 4:
		var stage := await _install_campaign_room(depth, 0)
		if stage == null:
			continue
		var encounter := RealmEncounter.new(depth, 0, StringName(RealmStage.REALMS[stage.realm]))
		check("depth %d production room opens with the authored first density" % [depth + 1],
			stage.enemies.size() == encounter.wave_size(0))
		check("depth %d production room reports the authored wave total" % [depth + 1],
			stage.total_waves() == encounter.wave_count())
		check("depth %d production room tracks every remaining encounter enemy" % [depth + 1],
			stage.remaining_encounter_enemies() == encounter.total_enemies())
		var elites := 0
		for actor in stage.enemies:
			if actor.is_elite:
				elites += 1
		check("depth %d first wave carries the authored elite quota" % [depth + 1],
			elites == encounter.elite_count(0))
		if depth == 0:
			check("depth 1 sloth keeps a single authored wave",
				stage.total_waves() == 1 and not stage.has_pending_waves())
		if depth == 2:
			await _run_elite_contract(stage)
			await _check_depth_three_reinforcement(stage)
	await _drop_campaign_stage()


## Production wrath room 1 at depth 3 fields exactly one elite in its first
## wave. Its shield, tempo layer, regen and overhead bar are checked in place.
func _run_elite_contract(stage: RealmStage) -> void:
	var elite: Enemy = null
	for actor in stage.enemies:
		if actor.is_elite:
			elite = actor
			break
	var sibling: Enemy = null
	if elite != null:
		for actor in stage.enemies:
			if actor != elite and not actor.is_elite and actor.get("variant") == elite.get("variant"):
				sibling = actor
				break
	check("depth 3 wrath first wave promotes one real elite", elite != null and sibling != null)
	if elite == null or sibling == null:
		return
	check("elite max health is 1.25x the authored regular",
		is_equal_approx(elite.health.max_health, sibling.health.max_health * 1.25))
	check("elite crystal shield tracks the scaled maximum",
		is_equal_approx(elite.health.max_shield, roundf(elite.health.max_health * 0.65))
		and is_equal_approx(elite.health.shield_points, elite.health.max_shield)
		and is_equal_approx(elite.health.shield_regeneration_delay, 5.5)
		and is_equal_approx(elite.health.shield_regeneration_rate, elite.health.max_shield * 0.10))
	check("elite tempo layer joins the realm tempo exactly once",
		is_equal_approx(elite.elite_tempo_scale, ELITE_LAYER)
		and is_equal_approx(elite.effective_attack_scale(), elite.realm_tempo_scale * ELITE_LAYER)
		and is_equal_approx(elite.effective_windup_scale(), 1.0 / (elite.realm_tempo_scale * ELITE_LAYER)))

	var hp := elite.health
	var full_hp := hp.health
	hp.apply_damage(10.0, Hitbox.BodyPart.BODY, stage.player)
	check("the elite crystal shield absorbs a hit without touching HP",
		is_zero_approx(full_hp - hp.health) and is_equal_approx(hp.shield_points, hp.max_shield - 10.0))

	hp.set_physics_process(false)
	hp.break_shield()
	for index in 329:
		hp._physics_process(1.0 / 60.0)
	check("the elite shield stays empty through the 5.5 s recovery delay", is_zero_approx(hp.shield_points))
	for index in 61:
		hp._physics_process(1.0 / 60.0)
	check("the elite shield resumes at 10% of capacity per second",
		hp.shield_points > hp.max_shield * 0.08 and hp.shield_points < hp.max_shield * 0.12)

	stage.player.boons.set_status(elite, &"phase_b_block", 60.0, 1.0, 1.0, false, 1.0, true)
	hp.break_shield()
	for index in 420:
		hp._physics_process(1.0 / 60.0)
	check("the no-regen boon freezes elite shield recovery", is_zero_approx(hp.shield_points))
	stage.player.boons.clear_status(elite, &"phase_b_block")
	check("clearing the boon releases the elite shield", not hp.shield_regeneration_blocked)

	var realm_tempo := elite.realm_tempo_scale
	stage.configure_run(2, [0], [], -1.0, [])
	await _frames(2)
	check("the lost-Sloth refresh keeps the elite tempo and shield layers",
		is_equal_approx(elite.elite_tempo_scale, ELITE_LAYER)
		and is_equal_approx(elite.realm_tempo_scale, realm_tempo + RealmStage.SLOTH_HASTE)
		and is_equal_approx(elite.effective_attack_scale(), (realm_tempo + RealmStage.SLOTH_HASTE) * ELITE_LAYER))
	stage.player.boons.set_status(elite, &"phase_b_slow", 60.0, 1.0, 1.0, false, 1.3, false, 0.6)
	var hasted_tempo := elite.realm_tempo_scale
	check("a slow boon composes over the elite and realm layers",
		is_equal_approx(elite.effective_attack_scale(), 0.6 * hasted_tempo * ELITE_LAYER)
		and is_equal_approx(elite.effective_windup_scale(), 1.3 / (hasted_tempo * ELITE_LAYER)))
	stage.player.boons.clear_status(elite, &"phase_b_slow")

	await _check_elite_shield_bar(stage, elite, sibling)


## A pure shield hit never emits `damaged`, so the HUD reveal must ride the
## shield signal instead.
func _check_elite_shield_bar(stage: RealmStage, elite: Enemy, sibling: Enemy) -> void:
	elite.health.health = elite.health.max_health
	elite.health.shield_points = elite.health.max_shield
	elite.global_position = CAMERA_ORIGIN + Vector3(4, -1.5, -24)
	sibling.global_position = CAMERA_ORIGIN + Vector3(-4, -1.5, -24)
	stage.player.global_position = CAMERA_ORIGIN - Vector3(0, 1.5, 0)
	stage.player.view_camera.global_transform = Transform3D(Basis.IDENTITY, CAMERA_ORIGIN)
	stage.player.view_camera.make_current()
	var bars := EnemyHealthBars.new()
	add_child(bars)
	var tracked: Array[Enemy] = [elite, sibling]
	bars.setup(stage.player, stage, tracked)
	await _settle()
	check("full-health elites stay hidden outside damage", _bar(bars, elite).is_empty())
	var before := elite.health.shield_points
	elite.health.apply_damage(20.0, Hitbox.BodyPart.BODY, stage.player)
	await _settle()
	var bar := _bar(bars, elite)
	check("a shield-only hit reveals the elite bar at full HP",
		not bar.is_empty() and is_equal_approx(bar.health, elite.health.max_health)
		and bar.shield < before and is_equal_approx(bar.alpha, 1.0))
	check("the revealed elite entry carries the elite marker flag", bool(bar.get("elite", false)))
	check("an untouched regular sibling keeps its bar hidden", _bar(bars, sibling).is_empty())
	bars.queue_free()
	await _frames(2)


## Depth 3 (the third floor) adds a second wave without over-escalating the
## first: two survivors are enough to call the four-unit reinforcement.
func _check_depth_three_reinforcement(stage: RealmStage) -> void:
	var events: Array = []
	stage.wave_spawned.connect(func(_s: RealmStage, wave: int, total: int) -> void: events.append([wave, total]))
	check("depth 3 room 1 keeps its second wave pending",
		stage.total_waves() == 2 and stage.has_pending_waves() and stage.current_wave() == 1)
	await _kill_live(stage, 3)
	await _frames(3)
	check("depth 3 reinforcements trigger at two survivors",
		stage.current_wave() == 2 and stage.living_enemies() == 6 and events == [[2, 2]])
	await _clear_all_waves(stage)
	check("depth 3 room clears only after both waves",
		stage.cleared and is_instance_valid(stage.talent_orb))


func _run_reinforcement_trigger() -> void:
	var stage := await _install_campaign_room(1, 1)
	if stage != null:
		var events: Array = []
		stage.wave_spawned.connect(func(_s: RealmStage, wave: int, total: int) -> void:
			events.append([wave, total])
			for actor in stage.enemies:
				actor.set_physics_process(false))
		var clears: Array = []
		stage.stage_cleared.connect(func(_s: RealmStage) -> void: clears.append(1))
		check("depth 2 fear room 2 opens with five of nine enemies",
			stage.enemies.size() == 5 and stage.total_waves() == 2
			and stage.remaining_encounter_enemies() == 9)
		_kill(stage, stage.enemies[0])
		_kill(stage, stage.enemies[1])
		await _frames(2)
		check("three survivors keep the reinforcement wave pending",
			stage.enemies.size() == 5 and stage.current_wave() == 1 and not stage.cleared)
		_kill(stage, stage.enemies[2])
		await _frames(3)
		check("living enemies at two immediately trigger the next wave",
			stage.current_wave() == 2 and stage.enemies.size() == 9 and stage.living_enemies() == 6)
		check("wave_spawned reports one-based indices", events == [[2, 2]])
		check("reinforcements stay at least ten meters from the player",
			_reinforcements_safe(stage, 5))
		check("reinforcements never share or stack spawn points",
			_reinforcements_distinct(stage, 5))
		check("pending waves keep the gate and talent orb locked",
			not stage.cleared and clears.is_empty() and not is_instance_valid(stage.talent_orb))
		await _settle()
		check("the HUD counts the live reinforcement wave",
			stage.hud._objective.text == "第 2/2 波 · 剩余 6")
		check("the HUD announces the reinforcement toast",
			stage.hud._wave_notice.visible and stage.hud._wave_notice.text == "增援抵达 · 第 2/2 波")
		await _clear_all_waves(stage)
		check("clearing every wave opens the gate and drops the orb",
			stage.cleared and clears.size() == 1 and is_instance_valid(stage.talent_orb))
		await _drop_campaign_stage()

	var deep := await _install_campaign_room(3, 1)
	if deep != null:
		var waves: Array = []
		deep.wave_spawned.connect(func(_s: RealmStage, wave: int, total: int) -> void:
			waves.append([wave, total]))
		check("depth 4 sorrow room 2 opens with six of fifteen enemies",
			deep.enemies.size() == 6 and deep.total_waves() == 3
			and deep.remaining_encounter_enemies() == 15)
		await _kill_live(deep, 4)
		await _frames(3)
		check("depth 4 room 2 reaches its second wave with five living",
			deep.current_wave() == 2 and deep.living_enemies() == 7)
		await _settle()
		check("the HUD counts the second of three waves",
			deep.hud._objective.text == "第 2/3 波 · 剩余 11")
		await _kill_live(deep, 5)
		await _frames(3)
		check("depth 4 room 2 reaches its third and final wave",
			deep.current_wave() == 3 and deep.living_enemies() == 6 and not deep.has_pending_waves())
		check("each deep wave keeps its authored elite", _wave_elites_intact(deep, waves))
		await _clear_all_waves(deep)
		check("the three-wave room clears into the talent orb",
			deep.cleared and is_instance_valid(deep.talent_orb))
		await _drop_campaign_stage()


func _run_legacy_single_room() -> void:
	var stage := (load("res://maps/realms/fear_2.tscn") as PackedScene).instantiate() as RealmStage
	add_child(stage)
	stage.player.set_physics_process(false)
	stage.player.set_process_unhandled_input(false)
	for actor in stage.enemies:
		actor.set_physics_process(false)
	await _frames(3)
	check("the standalone room keeps its legacy five-enemy single wave",
		stage.enemies.size() == 5 and stage.total_waves() == 1 and not stage.has_pending_waves()
		and stage.remaining_encounter_enemies() == 5)
	check("the standalone room fields no elites", stage.enemies.all(func(actor: Enemy) -> bool: return not actor.is_elite))
	check("the standalone room keeps the signature reaper", stage.enemies[4] is FearReaper)
	stage.queue_free()
	await _frames(3)


func _run_boss_phases() -> void:
	for realm in 4:
		var stage := await _install_campaign_room(realm, RunDirector.ROOM_BOSS)
		if stage == null:
			continue
		var boss := stage.boss
		check("realm %d campaign boss room starts with the boss alone" % [realm],
			boss != null and stage.enemies.size() == 1 and stage.boss_escorts.is_empty())
		if boss == null:
			await _drop_campaign_stage()
			continue
		boss.set_physics_process(false)
		var phases := [0]
		boss.phase_changed.connect(func(_phase: int) -> void: phases[0] += 1)
		var expected_shield := roundf(boss.health.max_health * 0.15)
		boss.health.apply_damage(boss.health.health - boss.health.max_health * 0.5,
			Hitbox.BodyPart.BODY, stage.player, {"true_damage": true})
		await _frames(2)
		check("realm %d boss crosses half health into phase 2 once" % [realm],
			int(boss.get("boss_phase")) == 2 and phases[0] == 1)
		check("realm %d phase 2 grants a 15%% non-regenerating shield" % [realm],
			is_equal_approx(boss.health.max_shield, expected_shield)
			and is_equal_approx(boss.health.shield_points, expected_shield)
			and is_zero_approx(boss.health.shield_regeneration_rate))
		check("realm %d phase 2 tightens the boss clock to 1.20x" % [realm],
			is_equal_approx(boss.boss_phase_tempo_scale, BOSS_PHASE_LAYER)
			and is_equal_approx(boss.effective_attack_scale(), boss.realm_tempo_scale * BOSS_PHASE_LAYER)
			and is_equal_approx(boss.effective_windup_scale(), 1.0 / (boss.realm_tempo_scale * BOSS_PHASE_LAYER)))
		boss.health.apply_damage(1.0, Hitbox.BodyPart.BODY, stage.player, {"true_damage": true})
		check("realm %d further damage never re-triggers the transition" % [realm],
			phases[0] == 1 and int(boss.get("boss_phase")) == 2)
		check("realm %d phase 2 spawns exactly two campaign escorts" % [realm],
			stage.boss_escorts.size() == 2 and stage.boss_escorts.all(func(actor: Enemy) -> bool: return not actor.health.is_dead())
			and stage.enemies.size() == 3)
		await _settle()
		check("realm %d HUD shows the phase shield badge" % [realm],
			stage.hud._boss_state.visible and stage.hud._boss_state.text == "护盾")
		if realm == 0 and boss is SlothColossus:
			boss.start_attack(1)
			await _frames(90)
			check("the phase 2 colossus barrage widens to nine shots", _projectile_count(stage) == 9)
			boss.attack_finished()
		boss.health.break_shield()
		await _settle()
		var exposed := realm == 1 and (boss as FearOculus).phase == 2
		var expected_badge := "破绽" if exposed else "二阶段"
		check("realm %d HUD falls back to the %s badge" % [realm, expected_badge],
			stage.hud._boss_state.visible and stage.hud._boss_state.text == expected_badge)
		var escorts := stage.boss_escorts.duplicate()
		boss.health.apply_damage(boss.health.max_health * 10.0, Hitbox.BodyPart.BODY, stage.player, {"true_damage": true})
		await _frames(3)
		check("realm %d boss death force-clears the escorts" % [realm],
			stage.boss_defeated and stage.boss_escorts.is_empty()
			and escorts.all(func(actor: Enemy) -> bool: return actor.health.is_dead())
			and stage.living_enemies() == 0)
		check("realm %d shard still drops beside the cleared escorts" % [realm],
			is_instance_valid(stage.shard) and not stage.shard.consumed)
		if is_instance_valid(stage.shard):
			stage.player.global_position = stage.shard.global_position
			await _frames(4)
		check("realm %d shard pickup still opens the exit" % [realm],
			stage.player.fragments.has_shard(stage.realm) and stage.exit_ready)
		await _drop_campaign_stage()


func _run_boss_cc_dr() -> void:
	_cc_arena = Node3D.new()
	_cc_arena.name = "BossCCDR"
	add_child(_cc_arena)
	_build_floor(_cc_arena)
	_cc_player = PLAYER_SCENE.instantiate() as Player
	_cc_arena.add_child(_cc_player)
	_cc_player.global_position = Vector3(0, 0.05, 10)
	_cc_player.set_physics_process(false)
	_cc_player.set_process_unhandled_input(false)
	_cc_player.health.max_health = 100000.0
	_cc_player.health.health = 100000.0
	_cc = _cc_player.boons
	_cc.set_physics_process(false)
	await _frames(3)

	await _cc_ordinary_and_elite()
	await _cc_colossus()
	await _cc_flawless()

	_cc.clear()
	for child in _cc_arena.get_children():
		child.queue_free()
	_cc_arena.queue_free()
	await _frames(3)


func _cc_ordinary_and_elite() -> void:
	var plain := _spawn_plain(Vector3(-4, 0.05, -2))
	var elite := _spawn_plain(Vector3(4, 0.05, -2))
	elite.apply_elite()
	for index in 5:
		_cc.set_status(plain, StringName("plain_%d" % index), 3.0, 1.0, 0.0, true)
		_cc.set_status(elite, StringName("elite_%d" % index), 3.0, 1.0, 0.0, true)
	check("ordinary targets stack five full stuns without DR",
		plain.boon_stunned and is_zero_approx(plain.boon_time_scale)
		and _cc.boss_cc_stage(plain) == 0 and not _cc.boss_cc_immune(plain))
	check("elite targets stack five full stuns without DR",
		elite.boon_stunned and is_zero_approx(elite.boon_time_scale)
		and _cc.boss_cc_stage(elite) == 0 and not _cc.boss_cc_immune(elite))
	_cc._physics_process(3.01)
	check("ordinary and elite targets recover their full stun",
		not plain.boon_stunned and not elite.boon_stunned
		and is_equal_approx(plain.boon_time_scale, 1.0) and is_equal_approx(elite.boon_time_scale, 1.0))
	_cc.set_status(plain, &"plain_soft", 60.0, 1.0, 0.1, false, 3.0, false, 0.2)
	_cc.set_status(elite, &"elite_soft", 60.0, 1.0, 0.1, false, 3.0, false, 0.2)
	check("ordinary and elite targets keep the raw extreme slow",
		is_equal_approx(plain.boon_time_scale, 0.1) and is_equal_approx(plain.boon_attack_scale, 0.2)
		and is_equal_approx(plain.boon_windup_scale, 3.0)
		and is_equal_approx(elite.boon_time_scale, 0.1) and is_equal_approx(elite.boon_attack_scale, 0.2)
		and is_equal_approx(elite.boon_windup_scale, 3.0))
	_cc.clear_status(plain, &"plain_soft")
	_cc.clear_status(elite, &"elite_soft")
	plain.queue_free()
	elite.queue_free()
	await _frames(2)


func _cc_colossus() -> void:
	var boss := COLOSSUS_SCENE.instantiate() as SlothColossus
	_cc_arena.add_child(boss)
	boss.global_position = Vector3(-6, 0.05, 0)
	boss.setup(_cc_player, [])
	boss.set_physics_process(false)
	var plain := _spawn_plain(Vector3(0, 0.05, -4))
	var projectile := Projectile.spawn(_cc_arena, Vector3(0, 1, -6), Vector3.FORWARD, plain, 10.0, 20.0, [])
	projectile.set_physics_process(false)
	await _frames(3)
	check("the production colossus starts without DR memory",
		boss.is_boss and _cc.boss_cc_stage(boss) == 0 and not _cc.boss_cc_immune(boss))

	_cc.set_status(boss, &"cc_first", 5.0, 1.0, 0.0)
	check("the first boss hard CC caps at 2 s",
		_cc.boss_cc_stage(boss) == 1 and is_zero_approx(boss.boon_time_scale))
	_cc._physics_process(1.0)
	check("the first boss freeze still holds after 1 s", is_zero_approx(boss.boon_time_scale))
	_cc._physics_process(1.01)
	check("the first boss freeze ends at the 2 s cap",
		is_equal_approx(boss.boon_time_scale, 1.0) and _cc.boss_cc_stage(boss) == 1)

	_cc.set_status(boss, &"cc_second", 5.0, 1.0, 1.0, true)
	check("the second boss hard CC halves to 1 s",
		_cc.boss_cc_stage(boss) == 2 and boss.boon_stunned)
	_cc._physics_process(0.99)
	check("the second boss stun holds just under 1 s", boss.boon_stunned)
	_cc._physics_process(0.02)
	check("the second boss stun ends at 1 s",
		not boss.boon_stunned and _cc.boss_cc_stage(boss) == 2)

	_cc.freeze_world(5.0, &"cc_third")
	check("the third boss freeze quarters to 0.5 s and arms immunity",
		_cc.boss_cc_stage(boss) == 3 and _cc.boss_cc_immune(boss)
		and is_zero_approx(boss.boon_time_scale))
	check("freeze_world still freezes ordinary enemies fully",
		is_zero_approx(plain.boon_time_scale))
	check("freeze_world still freezes enemy projectiles", is_zero_approx(projectile.boon_time_scale))
	_cc._physics_process(0.51)
	check("the boss thaws after 0.5 s while the ordinary enemy stays frozen",
		is_equal_approx(boss.boon_time_scale, 1.0) and is_zero_approx(plain.boon_time_scale))

	_cc.set_status(boss, &"cc_fourth", 5.0, 1.0, 0.0, true, 1.0, true)
	check("the fourth boss hard CC is immune and never stuns",
		_cc.boss_cc_stage(boss) == 3 and _cc.boss_cc_immune(boss)
		and not boss.boon_stunned and is_equal_approx(boss.boon_time_scale, 1.0))
	check("the immune call still applies the non-hard shield block",
		boss.health.shield_regeneration_blocked)
	_cc._physics_process(1.0)
	check("the immune call never freezes the boss",
		is_equal_approx(boss.boon_time_scale, 1.0) and not boss.boon_stunned)

	get_tree().paused = true
	_cc._physics_process(30.0)
	get_tree().paused = false
	check("pause freezes the 12 s boss CC window", _cc.boss_cc_stage(boss) == 3)
	_cc._physics_process(10.4)
	check("the window still holds just under 12 s",
		_cc.boss_cc_stage(boss) == 3 and _cc.boss_cc_immune(boss))
	_cc._physics_process(0.2)
	check("12 s without hard CC resets the stage",
		_cc.boss_cc_stage(boss) == 0 and not _cc.boss_cc_immune(boss))

	_cc.set_status(boss, &"soft", 60.0, 1.0, 0.1, false, 3.0, false, 0.2)
	check("boss soft controls clamp to the safe floors",
		is_equal_approx(boss.boon_time_scale, BoonManager.BOSS_MIN_TIME_SCALE)
		and is_equal_approx(boss.boon_attack_scale, BoonManager.BOSS_MIN_ATTACK_SCALE)
		and is_equal_approx(boss.boon_windup_scale, BoonManager.BOSS_MAX_WINDUP_SCALE)
		and not boss.boon_stunned)
	_cc.set_status(boss, &"soft_freeze", 1.5, 1.0, 0.0)
	check("a hard freeze overrides the floor while active", is_zero_approx(boss.boon_time_scale))
	_cc._physics_process(1.51)
	check("the soft floor returns after the hard freeze",
		is_equal_approx(boss.boon_time_scale, BoonManager.BOSS_MIN_TIME_SCALE))
	_cc.clear_status(boss, &"soft")
	check("clearing boss controls restores full speed", is_equal_approx(boss.boon_time_scale, 1.0))
	projectile.queue_free()
	plain.queue_free()
	boss.queue_free()
	await _frames(2)


func _cc_flawless() -> void:
	var boss := FLAWLESS_SCENE.instantiate() as FlawlessDoppelganger
	_cc_arena.add_child(boss)
	boss.global_position = Vector3(8, 0.05, 0)
	boss.setup(_cc_player, [])
	boss.set_combat_active(true)
	boss.set_physics_process(false)
	await _frames(3)
	check("the final shell is a boss target", boss.is_boss)
	_cc.set_status(boss, &"final_first", 5.0, 1.0, 0.0)
	_cc.set_status(boss, &"final_second", 5.0, 1.0, 1.0, true)
	_cc.set_status(boss, &"final_third", 5.0, 1.0, 0.0)
	check("the final shell follows the same 1x/0.5x/0.25x ladder into immunity",
		_cc.boss_cc_stage(boss) == 3 and _cc.boss_cc_immune(boss))
	for source in [&"final_first", &"final_second", &"final_third"]:
		_cc.clear_status(boss, source)
	check("clearing the hard CC leaves the immune shell mobile",
		not boss.boon_stunned and is_equal_approx(boss.boon_time_scale, 1.0)
		and _cc.boss_cc_immune(boss))

	_cc_player.fragments.configure_deprivation([0, 1, 2, 3])
	for realm in 4:
		_cc_player.fragments.acquire(realm)
	_cc_player.global_position = boss.global_position + Vector3(0, 0.05, 4)
	await _frames(2)
	check("Slumber resonance still breaks an immune final shell",
		_cc_player.fragments.try_slumber_resonance()
		and boss.phase == FlawlessDoppelganger.Phase.EXPOSED
		and is_equal_approx(boss.tempo_multiplier(), 0.25))

	boss.resonance_left = 0.0
	boss.phase = FlawlessDoppelganger.Phase.GUARD
	boss.phase_left = 20.0
	boss.global_position = Vector3(11, 0.05, 0)
	_cc_player.global_position = Vector3(9, 0.05, 0)
	boss.set_physics_process(true)
	var wall := FlawlessFractureWall.new()
	wall.position = Vector3(13.5, 1.5, 0)
	_cc_arena.add_child(wall)
	await _frames(3)
	_cc_player.fragments.barrier = 0.0
	_cc_player.health.apply_damage(5.0, Hitbox.BodyPart.BODY, boss)
	var ticks := 0
	while not wall.broken and ticks < 180:
		await get_tree().physics_frame
		ticks += 1
	check("the innate wall break still exposes the immune final shell",
		wall.broken and boss.wall_breaks == 1
		and boss.phase == FlawlessDoppelganger.Phase.EXPOSED)
	check("the innate break leaves the CC memory untouched", _cc.boss_cc_immune(boss))
	_cc.set_status(boss, &"final_cleanup", 5.0, 1.0, 0.0, true)
	check("the cleanup request stays immune", _cc.boss_cc_stage(boss) == 3)
	_cc.clear()
	check("death and teardown cleanup clears the boss CC memory",
		_cc.boss_cc_stage(boss) == 0 and not _cc.boss_cc_immune(boss))
	boss.set_physics_process(false)
	boss.queue_free()
	wall.queue_free()
	await _frames(2)


func _install_campaign_room(depth: int, room: int) -> RealmStage:
	RunDirector.floor_index = depth
	RunDirector.room_index = room
	var err := RunDirector.install_stage(load(RunDirector.scene_path()))
	check("depth %d room %d production stage installs" % [depth + 1, room + 1], err == OK)
	await _frames(6)
	var stage := RunDirector.current_stage as RealmStage
	if stage == null:
		return null
	if is_instance_valid(stage.selection):
		var picker := stage.selection
		if not picker._offered.is_empty():
			picker._choose(picker._offered[0])
			picker.confirm_replacement(true)
		else:
			picker._skip_empty()
		await _frames(2)
	stage.player.set_physics_process(false)
	stage.player.set_process_unhandled_input(false)
	stage.player.health.max_health = 100000.0
	stage.player.health.health = 100000.0
	for actor in stage.enemies:
		actor.set_physics_process(false)
	return stage


func _drop_campaign_stage() -> void:
	if is_instance_valid(RunDirector.current_stage):
		RunDirector.current_stage.queue_free()
	RunDirector.current_stage = null
	get_tree().current_scene = null
	await _frames(3)


func _kill(stage: RealmStage, actor: Enemy) -> void:
	actor.health.apply_damage(100000, Hitbox.BodyPart.BODY, stage.player, {"true_damage": true})


## Kills an exact count of living enemies, leaving a frame for the deferred
## clear check to spawn the next wave.
func _kill_live(stage: RealmStage, count: int) -> void:
	var killed := 0
	var guard := 0
	while killed < count and guard < 40:
		for actor in stage.enemies:
			if is_instance_valid(actor) and not actor.health.is_dead():
				_kill(stage, actor)
				killed += 1
				break
		await _frames(2)
		guard += 1


func _clear_all_waves(stage: RealmStage) -> void:
	stage.wave_spawned.connect(func(s: RealmStage, _wave: int, _total: int) -> void:
		for actor in s.enemies:
			actor.set_physics_process(false))
	var guard := 0
	while (stage.living_enemies() > 0 or stage.has_pending_waves()) and guard < 16:
		for actor in stage.enemies:
			actor.set_physics_process(false)
			if is_instance_valid(actor) and not actor.health.is_dead():
				_kill(stage, actor)
		await _frames(4)
		guard += 1


func _reinforcements_safe(stage: RealmStage, from_index: int) -> bool:
	var origin := stage.player.global_position
	var space := stage.get_world_3d().direct_space_state
	var nav_map := stage._region.get_navigation_map()
	var player_nav := NavigationServer3D.map_get_closest_point(nav_map, origin)
	var query := PhysicsShapeQueryParameters3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.45
	capsule.height = 1.6
	query.shape = capsule
	query.collision_mask = CollisionLayers.WORLD
	for index in range(from_index, stage.enemies.size()):
		var point := stage.enemies[index].global_position
		if Vector2(point.x - origin.x, point.z - origin.z).length() < 10.0:
			return false
		query.transform = Transform3D(Basis.IDENTITY, point + Vector3.UP * 1.05)
		if not space.intersect_shape(query, 1).is_empty():
			return false
		var path := NavigationServer3D.map_get_path(nav_map, point, player_nav, true)
		if path.is_empty() or path[-1].distance_to(player_nav) > 2.5:
			return false
	return true


func _run_codex_regressions() -> void:
	# 1. Sorrow wave spawn preserves global RNG and avoids DrowningPlatform overlap.
	var sorrow_stage := await _install_campaign_room(3, 1)
	if sorrow_stage != null:
		var before_count := sorrow_stage.enemies.size()
		for idx in range(before_count - 2):
			_kill(sorrow_stage, sorrow_stage.enemies[idx])
		seed(987654)
		var expected_rng := randi()
		seed(987654)
		await _frames(4)
		var after_wave_rng := randi()
		check("sorrow reinforcement wave preserves global RNG", after_wave_rng == expected_rng)
		check("sorrow wave spawns clear of world geometry and on reachable navmesh",
			sorrow_stage.enemies.size() > before_count and _reinforcements_safe(sorrow_stage, before_count))
		# HUD wave banner countdown freezes across zero physics ticks.
		var left_before := sorrow_stage.hud._wave_notice_left
		sorrow_stage.hud._process(0.5)
		check("HUD wave banner timer does not drain in _process without physics ticks",
			is_equal_approx(sorrow_stage.hud._wave_notice_left, left_before))
		sorrow_stage.hud._physics_process(0.25)
		check("HUD wave banner timer advances in _physics_process",
			is_equal_approx(sorrow_stage.hud._wave_notice_left, maxf(0.0, left_before - 0.25)))
		await _drop_campaign_stage()

	# 2. Pre-ready elite on subclass snapshots authored HP, preserves damaged shield on repeat, and scales $Model.
	var arena := Node3D.new()
	add_child(arena)
	_build_floor(arena)
	var reaper := preload("res://actors/enemy/fear/fear_reaper.tscn").instantiate() as FearReaper
	reaper.apply_elite()
	arena.add_child(reaper)
	reaper.set_physics_process(false)
	reaper.apply_realm_scaling(1.2, 1.0, 1.0)
	check("pre-ready elite on FearReaper uses authored 140 base HP -> 210/137",
		is_equal_approx(reaper.health.max_health, 210.0) and is_equal_approx(reaper.health.max_shield, 137.0))
	var model := reaper.get_node("Model") as Node3D
	check("elite promotion applies subtle 1.12x visual scale on Model only",
		model != null and is_equal_approx(model.scale.x, Enemy.ELITE_MODEL_SCALE) and reaper.scale == Vector3.ONE)
	reaper.health.apply_damage(50.0, Hitbox.BodyPart.BODY, null)
	var damaged_shield := reaper.health.shield_points
	reaper.apply_elite()
	check("repeated apply_elite preserves damaged shield without refilling",
		is_equal_approx(reaper.health.shield_points, damaged_shield) and damaged_shield < reaper.health.max_shield)

	# 3. Same-source freeze_world respects the newly requested boss DR duration and exact 50% threshold.
	var player := PLAYER_SCENE.instantiate() as Player
	arena.add_child(player)
	player.set_physics_process(false)
	var colossus := COLOSSUS_SCENE.instantiate() as SlothColossus
	arena.add_child(colossus)
	colossus.set_physics_process(false)
	colossus.setup(player, [])
	colossus.health.apply_damage(colossus.health.max_health * 0.5 - 0.0005, Hitbox.BodyPart.BODY, player, {"true_damage": true})
	check("boss stays Phase 1 at half + 0.0005 HP", colossus.boss_phase == 1 and colossus.health.shield_points == 0.0)
	colossus.health.apply_damage(0.0005, Hitbox.BodyPart.BODY, player, {"true_damage": true})
	check("boss enters Phase 2 at exact 50% HP", colossus.boss_phase == 2 and colossus.health.shield_points > 0.0)
	player.boons.register_enemy(colossus)
	player.boons.freeze_world(2.0, &"same_freeze")
	player.boons.freeze_world(0.2, &"same_freeze")
	var status_left: float = player.boons._statuses[colossus.get_instance_id()].sources[&"same_freeze"].left
	check("same-source freeze_world uses new request duration for boss DR (0.10 s)",
		is_equal_approx(status_left, 0.10))
	arena.queue_free()
	await _frames(2)


func _reinforcements_distinct(stage: RealmStage, from_index: int) -> bool:
	var points: Array[Vector3] = []
	for index in range(from_index, stage.enemies.size()):
		points.append(stage.enemies[index].global_position)
	for index in points.size():
		for other in range(index):
			if points[index].distance_to(points[other]) < 1.2:
				return false
	return true


## Every deep wave carries its authored elite. Waves are identified by their
## spawn event count; the final wave owns the tail of the roster.
func _wave_elites_intact(stage: RealmStage, events: Array) -> bool:
	if events.size() != 2:
		return false
	var seen: Array[int] = [0, 0, 0]
	for actor in stage.enemies:
		if not actor.is_elite:
			continue
		var index_at := 0
		for index in stage.enemies.size():
			if stage.enemies[index] == actor:
				index_at = index
				break
		if index_at < 6:
			seen[0] += 1
		elif index_at < 11:
			seen[1] += 1
		else:
			seen[2] += 1
	return seen == [1, 1, 1]


func _projectile_count(root: Node) -> int:
	var count := 0
	for child in root.get_children():
		if child is SlothRealmProjectile and not child.is_queued_for_deletion():
			count += 1
	return count


func _spawn_plain(point: Vector3) -> Enemy:
	var enemy := PLAIN_ENEMY_SCENE.instantiate() as Enemy
	_cc_arena.add_child(enemy)
	enemy.global_position = point
	enemy.setup(_cc_player, [])
	enemy.set_physics_process(false)
	return enemy


func _build_floor(parent: Node3D) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = CollisionLayers.WORLD
	body.collision_mask = CollisionLayers.NONE
	body.position = Vector3(0, -0.5, 0)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(80, 1, 80)
	shape.shape = box
	body.add_child(shape)
	parent.add_child(body)


func _bar(bars: EnemyHealthBars, enemy: Enemy) -> Dictionary:
	return bars.visible_entries().get(enemy.get_instance_id(), {})


func _settle() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().process_frame
	await get_tree().process_frame


func _frames(count: int) -> void:
	for index in count:
		await get_tree().physics_frame


func _finish() -> void:
	await _drop_campaign_stage()
	RunDirector.finish_campaign()
	RunDirector.randomize_realm_order = true
	await _frames(3)
	OS.delay_msec(250)
	await get_tree().process_frame
	print("DIFFICULTY CURVE PHASE B: %s (%d checks, %d failed)" % [
		"ALL PASSED" if failures == 0 else "FAIL", checks, failures])
	get_tree().quit(0 if failures == 0 else 1)


func check(label: String, passed: bool) -> void:
	checks += 1
	if not passed:
		failures += 1
	print("%s %s" % ["PASS" if passed else "FAIL", label])
