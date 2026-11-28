class_name RealmStage
extends Node3D
## A self-contained room. The run controller injects state and handles campaign exits.
signal stage_cleared(stage: RealmStage)
signal enemy_defeated(stage: RealmStage, actor: Enemy)
signal realm_defeated(stage: RealmStage)
signal exit_requested(stage: RealmStage)
signal reward_selected(stage: RealmStage, card: BoonData)
signal reroll_spent(stage: RealmStage)
signal player_fallen(stage: RealmStage, cause: StringName)
signal retry_requested(stage: RealmStage)
signal hub_requested(stage: RealmStage)
signal title_requested(stage: RealmStage)
signal wave_spawned(stage: RealmStage, wave_index: int, total_waves: int)
signal rest_healed(stage: RealmStage, amount: float)
@export_range(0,3) var realm: int = 0
@export var room_index: int = 0
@export var boss_room := false
## The pre-boss sanctuary: no enemies, an open boss gate and a single full heal.
@export var rest_room := false
@export var campaign := false
## Damage multiplier. Kept under the historical name so standing callers work.
@export var difficulty_multiplier := 1.0
## Health multiplier, split out of the old single scalar.
@export var hp_multiplier := 1.0
## Enemy tempo multiplier: attack cooldowns and windups tighten with depth.
@export var tempo_multiplier := 1.0
## True when tempo_multiplier already carries the lost-Sloth haste because the
## run director folded it in before this room was installed.
@export var tempo_includes_sloth_haste := false
const SLOTH_HASTE := 0.12
const REALMS := ["sloth","fear","wrath","sorrow"]
const TITLES := ["怠惰 · 凝滞庭院","恐惧 · 破碎长廊","愤怒 · 焦灼竞技场","悲伤 · 泪海"]
const BOSSES := ["sloth_colossus","fear_oculus","wrath_spire","sorrow_monolith"]
const ESCORT_SCENES := [
	"res://actors/enemy/sloth/sloth_enemy.tscn",
	"res://actors/enemy/fear/fear_realm_enemy.tscn",
	"res://actors/enemy/wrath/wrath_realm_enemy.tscn",
	"res://actors/enemy/sorrow/sorrow_realm_enemy.tscn",
]
const SHARD := preload("res://zone/psyche_shard_pickup.tscn")
const PLAYER := preload("res://actors/player/player.tscn")
const PICKER := preload("res://ui/boon_picker/boon_picker.tscn")
var player: Player
var geometry: Node3D
var enemies: Array[Enemy] = []
var boss: Enemy
var boss_escorts: Array[Enemy] = []
var boss_drop_position := Vector3.ZERO
var shard: PsycheShardPickup
var boss_defeated := false
var hud: RealmHUD
var selection: BoonPicker
var gate: Node3D
var cleared := false
var exit_ready := false
var transitioning := false
var fallen := false
var rest_used := false
var _floor_has_rest := true
const REST_INTERACT_RANGE := 3.2
var depth := 0
var deprivations: Array[int] = []
var saved_shards: Array[int] = []
var saved_hp := -1.0
var saved_boons: Array = []
var _offer_rng := RandomNumberGenerator.new()
var _region: NavigationRegion3D
var _gate_material: StandardMaterial3D
var _portal_material: StandardMaterial3D
var _gate_label: Label3D
var run_seed := 13800
var rerolls_remaining := 2
## Injected by the run director when resuming a run whose opening three-card
## choice was already taken: the room must not offer the same gift again.
var skip_entry_reward := false
var _reward_context := ""
var _reward_offer: Array[BoonData] = []
## True when a stage wired before the vector split only set the legacy scalar
## and never injected health or tempo. Those stages scaled health with it.
var _legacy_scalar_scaling := false
var _encounter: RealmEncounter
var _waves_spawned := 0
## The reclaimed-talent orb that appears in front of the exit gate once the room
## is clear. The player walks up and presses interact to open the reward offer.
var talent_orb: TalentOrb
var _orb_ready := false
var _prepared_orb: TalentOrb
var _prepared_picker: BoonPicker
static var _orb_halo_mesh: TorusMesh
static var _orb_column_mesh: CylinderMesh


class RewardShaderWarmup extends Node3D:
	var _frames := 0

	func _process(_delta: float) -> void:
		_frames += 1
		if _frames >= 4:
			queue_free()

func _init() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE

func configure_run(value_depth: int, values: Array[int], shards: Array[int], hp: float, boons: Array) -> void:
	depth = maxi(0,value_depth)
	deprivations.assign(values)
	_floor_has_rest = rest_room or not deprivations.has(PsycheFragments.SLOTH)
	saved_shards.assign(shards)
	saved_hp = hp
	saved_boons = boons.duplicate()
	if is_node_ready():
		_apply_run()

func _ready() -> void:
	_floor_has_rest = rest_room or not deprivations.has(PsycheFragments.SLOTH)
	_legacy_scalar_scaling = is_equal_approx(hp_multiplier,1.0) \
		and is_equal_approx(tempo_multiplier,1.0) \
		and not is_equal_approx(difficulty_multiplier,1.0)
	CrystalBurst.prepare(self)
	BoonCatalog.all()
	SimClock.restart()
	seed(run_seed + realm*100 + room_index + depth*1000)
	_offer_rng.seed = run_seed + 16338 + realm*100 + room_index + depth*1000
	geometry = get_node_or_null("Geometry") as Node3D
	if geometry == null and rest_room:
		var sanctuary := RestSanctuary.new()
		sanctuary.name = "Geometry"
		sanctuary.realm = realm
		sanctuary.boss_arena = false
		add_child(sanctuary)
		geometry = sanctuary
	if not (geometry and geometry.has_method("provides_stage_lighting") and geometry.call("provides_stage_lighting")):
		_build_world()
	if geometry == null:
		var provider := "res://environments/%s/realm.gd" % REALMS[realm]
		if not ResourceLoader.exists(provider):
			push_error("Missing realm geometry: " + provider)
			return
		geometry = load(provider).new()
		geometry.name = "Geometry"
		geometry.set("boss_arena",boss_room)
		add_child(geometry)
	_bake_navigation()
	player = get_node_or_null("Player") as Player
	if player == null:
		player = PLAYER.instantiate()
		player.name = "Player"
		player.position = Vector3(0,0.1,16)
		add_child(player)
	if geometry.has_method("player_spawn"):
		player.position = geometry.call("player_spawn") + Vector3.UP*0.1
	if geometry.has_method("set_player"):
		geometry.call("set_player",player)
	if geometry is SorrowRealm:
		(geometry as SorrowRealm).start_whirlpools(run_seed, room_index)
	_apply_run()
	player.health.died.connect(_on_player_died)
	if not rest_room:
		_spawn_encounter()
	_build_gate()
	if rest_room:
		# A sanctuary is already "cleared": its boss door opens on arrival and
		# no waves, reward orb or encounter bookkeeping ever starts.
		cleared = true
		_unlock_gate("首领门扉\n靠近后按 %s 进入" % KeyHint.of("interact"))
	hud = RealmHUD.new()
	hud.name = "RealmHUD"
	hud.stage = self
	add_child(hud)
	get_tree().paused = false
	_install_audio()
	if not boss_room and not rest_room:
		_prepare_room_rewards()
	# Opening three-card choice. Deferred on purpose: the run controller restores
	# the saved loadout right after add_child, and that restore replaces the whole
	# card set. Choosing here would be erased by it.
	if campaign and depth == 0 and room_index == 0 and not skip_entry_reward:
		offer_entry_reward.call_deferred()

func _install_audio() -> void:
	var path := "res://audio/realms/%s_audio_director.gd" % REALMS[realm]
	var audio := load(path).new() as RealmAudioDirector if ResourceLoader.exists(path) else RealmAudioDirector.new()
	audio.name = "RealmAudio"
	audio.setup(self)
	add_child(audio)

func _apply_run() -> void:
	player.boons.restore(saved_boons)
	player.fragments.configure_deprivation(deprivations)
	player.fragments.restore(saved_shards)
	if saved_hp >= 0:
		player.health.health = clampf(saved_hp,1.0,player.health.max_health)
	if geometry.has_method("set_deprivation"):
		geometry.call("set_deprivation",deprivations.has(realm))
	player.realm_effects.warnings_enabled = not deprivations.has(1)
	var audio := get_node_or_null("RealmAudio") as RealmAudioDirector
	if audio != null:
		audio.set_deprived(deprivations.has(realm))
	for actor in enemies:
		_apply_actor_deprivation(actor)
	_refresh_enemy_tempo()

## Runs after deprivations change: tighten or relax the living actors without
## touching their health again.
func _refresh_enemy_tempo() -> void:
	var tempo := _effective_tempo()
	for actor in enemies:
		if is_instance_valid(actor) and not actor.health.is_dead():
			actor.set_realm_tempo(tempo)

func _effective_tempo() -> float:
	_fold_sloth_haste()
	return maxf(0.25,tempo_multiplier)

## A boss killed inside this room adds the Sloth haste here. When the run
## director already included it, the flag keeps it from stacking twice.
func _fold_sloth_haste() -> void:
	if not campaign:
		return
	var has_sloth := deprivations.has(0)
	if has_sloth and not tempo_includes_sloth_haste:
		tempo_multiplier += SLOTH_HASTE
		tempo_includes_sloth_haste = true
	elif not has_sloth and tempo_includes_sloth_haste:
		tempo_multiplier = maxf(0.25,tempo_multiplier - SLOTH_HASTE)
		tempo_includes_sloth_haste = false

func _apply_actor_deprivation(actor: Enemy) -> void:
	if "warnings_enabled" in actor:
		actor.set("warnings_enabled",not deprivations.has(1))
	if actor.has_method("set_ordinary_impacts_enabled"):
		actor.call("set_ordinary_impacts_enabled",not deprivations.has(2))
	elif "ordinary_impacts_enabled" in actor:
		actor.set("ordinary_impacts_enabled",not deprivations.has(2))

## Production run wiring always injects the depth vector; deeper floors carry
## a health or damage scale. Tempo is excluded because the Sloth haste fold
## mutates it before encounters spawn. Unwired campaign stages keep the
## authored single wave.
func _multi_wave_enabled() -> bool:
	if not campaign or boss_room or _legacy_scalar_scaling:
		return false
	return depth == 0 or not is_equal_approx(hp_multiplier,1.0) \
		or not is_equal_approx(difficulty_multiplier,1.0)

func _spawn_encounter() -> void:
	if boss_room:
		_spawn_boss()
		return
	if _multi_wave_enabled():
		_encounter = RealmEncounter.new(depth,room_index,StringName(REALMS[realm]))
		_spawn_wave(0)
		return
	if geometry is SlothRealm:
		_spawn_sloth_encounter(geometry as SlothRealm)
		return
	var path := "res://actors/enemy/%s/%s_realm_enemy.tscn" % [REALMS[realm],REALMS[realm]]
	if not ResourceLoader.exists(path):
		push_error("Missing realm enemy: " + path)
		return
	var points: Array = [Vector3(-8,0.1,3),Vector3(8,0.1,-4),Vector3(0,0.1,-12),Vector3(-11,0.1,-12),Vector3(11,0.1,-14)]
	if geometry.has_method("spawn_points"):
		points = geometry.call("spawn_points")
	if geometry is FearRealm:
		points = points.slice(0,4)
	var count := mini(points.size(),3 if room_index == 0 else 5)
	for i in count:
		var actor := (load(path) as PackedScene).instantiate() as Enemy
		if actor is WrathRealmEnemy and room_index == 1 and i == 3:
			actor.variant = WrathRealmEnemy.Variant.READER
		else:
			actor.set("variant",i%3)
		actor.position = points[i]
		if "opening_delay" in actor:
			actor.set("opening_delay",1.0 + i*0.2)
		if "arena" in actor:
			actor.set("arena",geometry)
		add_child(actor)
		_register_actor(actor)
	if realm == 1:
		var reaper := preload("res://actors/enemy/fear/fear_reaper.tscn").instantiate() as FearReaper
		reaper.position = Vector3(7,0.05,-8) if room_index == 0 else Vector3(-9.8,1.25,0)
		add_child(reaper)
		_register_actor(reaper)

func _spawn_sloth_encounter(court: SlothRealm) -> void:
	var positions := court.guard_positions()
	var roster := [SlothEnemy.Kind.LINGERER, SlothEnemy.Kind.ANCHOR, SlothEnemy.Kind.RECLUSE, SlothEnemy.Kind.LINGERER]
	if court.chamber_style == 1:
		roster.append_array([SlothEnemy.Kind.ANCHOR, SlothEnemy.Kind.LINGERER])
	for i in roster.size():
		var guardian := preload("res://actors/enemy/sloth/sloth_enemy.tscn").instantiate() as SlothEnemy
		guardian.kind = roster[i]
		guardian.realm_encounter = true
		guardian.opening_delay = 0.75 + i * 0.22
		guardian.position = positions[i]
		add_child(guardian)
		_register_actor(guardian)
	var mire := preload("res://actors/enemy/sloth/sloth_mire.tscn").instantiate() as SlothMire
	mire.position = positions[-1]
	add_child(mire)
	_register_actor(mire)

func current_wave() -> int:
	return maxi(1,_waves_spawned)

func total_waves() -> int:
	return _encounter.wave_count() if _encounter != null else 1

func has_pending_waves() -> bool:
	return _encounter != null and _waves_spawned < _encounter.wave_count()

func remaining_encounter_enemies() -> int:
	var total := living_enemies()
	if _encounter != null:
		for index in range(_waves_spawned,_encounter.wave_count()):
			total += _encounter.wave_size(index)
	return total

func _spawn_wave(wave_index: int) -> void:
	var slots := _encounter.wave_slots(wave_index)
	var points := _wave_points(wave_index,slots.size())
	for i in slots.size():
		var actor := _instantiate_slot(slots[i])
		actor.position = points[i]
		if actor is SlothEnemy:
			(actor as SlothEnemy).opening_delay = (0.75 + i*0.22) if wave_index == 0 else (0.35 + i*0.12)
		elif "opening_delay" in actor:
			actor.set("opening_delay",(1.0 + i*0.2) if wave_index == 0 else (0.5 + i*0.15))
		if "arena" in actor:
			actor.set("arena",geometry)
		add_child(actor)
		_register_actor(actor)
		if slots[i].elite:
			actor.apply_elite()
		if wave_index > 0:
			CrystalBurst.spawn(self,points[i] + Vector3.UP*1.1,realm,&"spawn")
	_waves_spawned = wave_index + 1
	wave_spawned.emit(self,_waves_spawned,total_waves())

func _instantiate_slot(slot: Dictionary) -> Enemy:
	match slot.type:
		&"fear_reaper":
			return preload("res://actors/enemy/fear/fear_reaper.tscn").instantiate() as FearReaper
		&"sloth_mire":
			return preload("res://actors/enemy/sloth/sloth_mire.tscn").instantiate() as SlothMire
	if realm == 0:
		var guardian := preload("res://actors/enemy/sloth/sloth_enemy.tscn").instantiate() as SlothEnemy
		guardian.kind = slot.variant as int
		guardian.realm_encounter = true
		return guardian
	var path := "res://actors/enemy/%s/%s_realm_enemy.tscn" % [REALMS[realm],REALMS[realm]]
	var actor := (load(path) as PackedScene).instantiate() as Enemy
	actor.set("variant",slot.variant)
	return actor

func _wave_pool() -> Array[Vector3]:
	if geometry is SlothRealm:
		return (geometry as SlothRealm).wave_spawn_points()
	return geometry.call("spawn_points")

func _wave_points(wave_index: int, count: int) -> Array[Vector3]:
	if wave_index == 0:
		return _wave_pool().slice(0,count)
	return _pick_reinforcement_points(count)

## Deterministic selection: far unoccupied points first, then nearer free
## points, then occupied ones. Consumes no global RNG.
func _pick_reinforcement_points(count: int) -> Array[Vector3]:
	var origin := player.global_position
	var far: Array[Vector3] = []
	var near: Array[Vector3] = []
	var occupied: Array[Vector3] = []
	for point in _wave_pool():
		if _point_occupied(point):
			occupied.append(point)
		elif _flat_distance(point,origin) >= 10.0:
			far.append(point)
		else:
			near.append(point)
	var chosen: Array[Vector3] = []
	for group in [far,near,occupied]:
		group.sort_custom(func(a: Vector3,b: Vector3) -> bool:
			var da := _flat_distance(a,origin)
			var db := _flat_distance(b,origin)
			if is_equal_approx(da,db):
				return a.x < b.x if not is_equal_approx(a.x,b.x) else a.z < b.z
			return da > db)
		for point in group:
			if chosen.size() >= count:
				return chosen
			chosen.append(point)
	return chosen

func _flat_distance(a: Vector3,b: Vector3) -> float:
	return Vector2(a.x-b.x,a.z-b.z).length()

func _point_occupied(point: Vector3) -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.6
	capsule.height = 2.0
	query.shape = capsule
	query.transform = Transform3D(Basis.IDENTITY,point + Vector3.UP*1.0)
	query.collision_mask = CollisionLayers.ENEMIES
	query.collide_with_bodies = true
	query.collide_with_areas = false
	return not get_world_3d().direct_space_state.intersect_shape(query,1).is_empty()

func _spawn_boss() -> void:
	var path := "res://actors/boss/%s/%s.tscn" % [BOSSES[realm],BOSSES[realm]]
	if not ResourceLoader.exists(path):
		push_error("Missing realm boss: " + path)
		return
	boss = (load(path) as PackedScene).instantiate() as Enemy
	boss.name = "RealmBoss"
	boss.position = Vector3(0,0,-8)
	if "arena" in boss:
		boss.set("arena",geometry)
	add_child(boss)
	_register_actor(boss)
	if campaign and boss.has_signal("phase_changed"):
		boss.connect("phase_changed",Callable(self,"_on_boss_phase_changed"))

func _on_boss_phase_changed(new_phase: int) -> void:
	if new_phase != 2 or not campaign or not boss_room or fallen or boss_defeated:
		return
	if not boss_escorts.is_empty():
		return
	_spawn_boss_escorts()

## Two flank minions arrive the moment the campaign boss crosses half health.
## They are real registered enemies but never gate the boss-defeat settlement.
func _spawn_boss_escorts() -> void:
	var path: String = ESCORT_SCENES[realm]
	if not ResourceLoader.exists(path):
		return
	var to_player := player.global_position-boss.global_position
	to_player.y = 0.0
	if to_player.length() < 0.1:
		to_player = Vector3.FORWARD
	to_player = to_player.normalized()
	var side := to_player.cross(Vector3.UP).normalized()
	for i in 2:
		var actor := (load(path) as PackedScene).instantiate() as Enemy
		if actor is SlothEnemy:
			(actor as SlothEnemy).kind = SlothEnemy.Kind.LINGERER
			(actor as SlothEnemy).realm_encounter = true
		elif "variant" in actor:
			actor.set("variant",i%3)
		if "opening_delay" in actor:
			actor.set("opening_delay",0.5+i*0.2)
		if "arena" in actor:
			actor.set("arena",geometry)
		var desired := boss.global_position+side*(5.0 if i == 0 else -5.0)+to_player*2.0
		var landing := NavigationServer3D.map_get_closest_point(_region.get_navigation_map(),desired)
		actor.position = landing+Vector3.UP*0.1
		add_child(actor)
		_register_actor(actor)
		boss_escorts.append(actor)

func _clear_boss_escorts() -> void:
	for escort in boss_escorts:
		if is_instance_valid(escort) and not escort.health.is_dead():
			escort.health.apply_damage(escort.health.max_health+escort.health.shield_points+1.0,
				Hitbox.BodyPart.BODY,boss,{"true_damage":true,"allow_friendly_fire":true})
	boss_escorts.clear()

func _register_actor(actor: Enemy) -> void:
	var damage_scale := maxf(0.1,difficulty_multiplier)
	var hp_scale := maxf(0.1,hp_multiplier)
	if _legacy_scalar_scaling:
		hp_scale = damage_scale
	actor.apply_realm_scaling(hp_scale,damage_scale,_effective_tempo())
	_apply_actor_deprivation(actor)
	actor.setup(player,[])
	player.boons.register_enemy(actor)
	enemies.append(actor)
	actor.health.died.connect(_on_enemy_died.bind(actor))

func _on_enemy_died(_source: Node, _actor: Enemy) -> void:
	# Health emits synchronously; finish after all death cleanup has run.
	enemy_defeated.emit(self,_actor)
	if _actor == boss:
		boss_drop_position = _actor.global_position
	_check_clear.call_deferred()

func living_enemies() -> int:
	var count := 0
	for actor in enemies:
		if is_instance_valid(actor) and not actor.health.is_dead():
			count += 1
	return count

func _check_clear() -> void:
	if cleared or fallen:
		return
	if boss_room:
		if not is_instance_valid(boss) or boss.health.is_dead():
			_finish_boss_defeat()
		return
	if has_pending_waves():
		if living_enemies() <= 2:
			_spawn_wave(_waves_spawned)
		return
	if living_enemies() > 0:
		return
	cleared = true
	stage_cleared.emit(self)
	_spawn_talent_orb()

func _finish_boss_defeat() -> void:
	if boss_defeated:
		return
	boss_defeated = true
	_clear_boss_escorts()
	if not deprivations.has(realm):
		deprivations.append(realm)
	player.fragments.configure_deprivation(deprivations)
	player.realm_effects.warnings_enabled = not deprivations.has(1)
	geometry.call("set_deprivation",true)
	for actor in enemies:
		_apply_actor_deprivation(actor)
	_refresh_enemy_tempo()
	realm_defeated.emit(self)
	# Revisited debug maps can already own the shard; do not create an uncollectable gate.
	if player.fragments.has_shard(realm):
		_on_shard_collected(realm)
		return
	shard = SHARD.instantiate() as PsycheShardPickup
	shard.realm = realm
	var desired := boss_drop_position + Vector3(2,0,2)
	var landing := NavigationServer3D.map_get_closest_point(_region.get_navigation_map(),desired)
	shard.position = landing + Vector3.UP*0.1
	shard.setup(player)
	shard.collected.connect(_on_shard_collected)
	add_child(shard)

func _on_shard_collected(value: int) -> void:
	if value != realm or cleared or fallen:
		return
	cleared = true
	_reward_context = "shard"
	_finish_reward()
	stage_cleared.emit(self)

func offer_entry_reward() -> void:
	if not cleared and not fallen and not is_instance_valid(selection):
		_offer_reward(true)


## Where the orb stands, in stage-local space: between the door and the player,
## on the walkable floor below. Raised exits put the door on stairs or a landing,
## so the height comes from a downward probe instead of assuming y=0.
func _orb_spawn_position() -> Dictionary:
	var anchor := gate.position if is_instance_valid(gate) else Vector3.ZERO
	var away := to_local(player.global_position) - anchor
	away.y = 0.0
	if away.length() < 0.1:
		away = Vector3(0.0, 0.0, 1.0)
	away = away.normalized()
	for candidate in [anchor + away * 1.95, anchor + Vector3(0.0, 0.0, 1.95)]:
		var from := to_global(Vector3(candidate.x, anchor.y + 3.0, candidate.z))
		var to := to_global(Vector3(candidate.x, anchor.y - 3.0, candidate.z))
		var ray := PhysicsRayQueryParameters3D.create(from, to, CollisionLayers.WORLD)
		var hit := get_world_3d().direct_space_state.intersect_ray(ray)
		if hit.is_empty() or (hit["normal"] as Vector3).y < 0.7:
			continue
		var floor_point := to_local(hit["position"] as Vector3)
		return {"position": Vector3(candidate.x, floor_point.y, candidate.z), "ground_y": floor_point.y}
	return {"position": anchor + Vector3(0.0, 0.0, 1.95), "ground_y": anchor.y}


## The talent orb arrives in front of the exit gate the moment the room is clear.
## It is deliberately NOT a paused UI: the player walks over and presses interact,
## which is what opens the three-card offer.
func _spawn_talent_orb() -> void:
	if is_instance_valid(talent_orb) or fallen:
		return
	_orb_ready = true
	if is_instance_valid(_prepared_orb):
		talent_orb = _prepared_orb
		_prepared_orb = null
	else:
		talent_orb = TalentOrb.new()
	talent_orb.name = "TalentOrb"
	talent_orb.set_player(player)
	var spawn := _orb_spawn_position()
	var spot: Vector3 = spawn["position"]
	talent_orb.set_ground_height(spawn["ground_y"])
	talent_orb.position = Vector3(spot.x, talent_orb.hover_height(), spot.z)
	talent_orb.set_idle_enabled(false)
	add_child(talent_orb)
	# shatter the shell into its own armour pieces, then fly them back together
	talent_orb.set_core_visible(false)
	talent_orb.scatter(1.9)
	talent_orb.set_accent(BoonIdentity.COLORS[realm])
	_play_orb_arrival()


## Arrival flourish: a light column drops onto the spot, the shell flies together
## out of its scattered armour pieces, and the cube ignites at the centre.
func _play_orb_arrival() -> void:
	var origin := talent_orb.position

	# ground halo
	if _orb_halo_mesh == null:
		_orb_halo_mesh = TorusMesh.new()
		_orb_halo_mesh.inner_radius = 0.55
		_orb_halo_mesh.outer_radius = 0.68
	var halo := MeshInstance3D.new()
	halo.mesh = _orb_halo_mesh
	halo.position = origin + Vector3(0.0, 0.06, 0.0)
	halo.scale = Vector3(0.25, 1.0, 0.25)
	var halo_mat := StandardMaterial3D.new()
	halo_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	halo_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	halo_mat.albedo_color = Color(0.55, 0.95, 1.0, 0.95)
	halo_mat.emission_enabled = true
	halo_mat.emission = Color(0.5, 0.9, 1.0)
	halo_mat.emission_energy_multiplier = 2.5
	halo.material_override = halo_mat
	add_child(halo)

	# light column
	var column := MeshInstance3D.new()
	if _orb_column_mesh == null:
		_orb_column_mesh = CylinderMesh.new()
		_orb_column_mesh.top_radius = 0.42
		_orb_column_mesh.bottom_radius = 0.78
		_orb_column_mesh.height = 4.5
	column.mesh = _orb_column_mesh
	column.position = origin + Vector3(0.0, 2.25, 0.0)
	var col_mat := StandardMaterial3D.new()
	col_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	col_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	col_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	col_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	col_mat.albedo_color = Color(0.5, 0.9, 1.0, 0.14)
	col_mat.emission_enabled = true
	col_mat.emission = Color(0.45, 0.85, 1.0)
	col_mat.emission_energy_multiplier = 1.6
	column.material_override = col_mat
	column.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(column)

	# burst light
	var burst := OmniLight3D.new()
	burst.position = origin + Vector3(0.0, 1.3, 0.0)
	burst.light_color = Color(0.65, 0.95, 1.0)
	burst.light_energy = 0.0
	burst.omni_range = 9.0
	add_child(burst)

	var tween := create_tween()
	tween.set_parallel(true)
	# each piece fades in and then immediately flies home - no all-hands pause
	talent_orb.reveal_pieces()
	talent_orb.assemble()
	# ignite the core the moment the shell is whole (~4.6 s), not when the slow
	# light column finishes fading (~5.8 s) - that gap was the empty ring
	var shell_done := talent_orb.assembly_seconds() - 0.35
	var core_tween := create_tween()
	core_tween.tween_interval(maxf(0.6, shell_done))
	core_tween.tween_callback(func() -> void:
		if is_instance_valid(talent_orb):
			talent_orb.fade_core_in(0.55)
			talent_orb.set_idle_enabled(true)
	)
	# halo blooms out and fades
	tween.tween_property(halo, "scale", Vector3(3.4, 1.0, 3.4), 3.2) \
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.tween_property(halo_mat, "albedo_color:a", 0.0, 3.2) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	# column flares then vanishes
	tween.tween_property(burst, "light_energy", 7.0, 0.30)
	tween.tween_property(burst, "light_energy", 0.0, 5.2).set_delay(0.30)
	tween.tween_property(col_mat, "albedo_color:a", 0.0, 5.4).set_delay(0.40)
	tween.chain().tween_callback(func() -> void:
		halo.queue_free()
		column.queue_free()
		burst.queue_free()
	)


## True while the orb is on the ground waiting to be claimed; the HUD uses it to
## decide whether the prompt should point at the orb or at the door.
func orb_pending() -> bool:
	return _orb_ready and is_instance_valid(talent_orb)


## True while the altar can still be used: the HUD reads it for the prompt.
func rest_altar_pending() -> bool:
	return rest_room and not rest_used and not fallen \
		and geometry != null and geometry.has_method("rest_position")


## Shared reach + WORLD line-of-sight guard so HUD prompt and interaction agree.
func can_interact_rest() -> bool:
	if not rest_altar_pending() or transitioning or get_tree().paused:
		return false
	if not is_instance_valid(player):
		return false
	var altar: Vector3 = geometry.to_global(geometry.call("rest_position"))
	if player.global_position.distance_to(altar) > REST_INTERACT_RANGE:
		return false
	var ray := PhysicsRayQueryParameters3D.create(player.eye_position(),altar+Vector3.UP,CollisionLayers.WORLD)
	return get_world_3d().direct_space_state.intersect_ray(ray).is_empty()


## Single-use full heal at the sanctuary altar.
func request_rest() -> bool:
	if not can_interact_rest():
		return false
	var before := player.health.health
	player.health.health = player.health.max_health
	var healed := player.health.health - before
	rest_used = true
	if geometry.has_method("set_rest_consumed"):
		geometry.call("set_rest_consumed",true)
	if geometry.has_method("play_rest_pulse"):
		geometry.call("play_rest_pulse")
	rest_healed.emit(self,healed)
	return true


## Read-only HUD captions. Floor room count is latched on floor entry so killing
## Sloth inside its own boss room never rewrites the current floor from 4 to 3.
func has_rest_room_in_floor() -> bool:
	return _floor_has_rest

func total_floor_rooms() -> int:
	return 4 if has_rest_room_in_floor() else 3

func display_room_number() -> int:
	if boss_room:
		return total_floor_rooms()
	if rest_room:
		return 3
	return room_index + 1

func room_badge_text() -> String:
	if rest_room:
		return "休息室 3/4"
	if boss_room:
		return "首领 %d/%d" % [total_floor_rooms(),total_floor_rooms()]
	return "房间 %d/%d" % [display_room_number(),total_floor_rooms()]


## Called when the player presses interact next to the orb: swallow the orb, then
## open the ordinary three-card offer.
func claim_talent() -> void:
	if not _orb_ready or not is_instance_valid(talent_orb):
		return
	_orb_ready = false
	var orb := talent_orb
	talent_orb = null
	orb.set_collision_enabled(false)
	orb.set_idle_enabled(false)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(orb, "scale", Vector3.ONE * 0.02, 0.3) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(orb, "position", orb.position + Vector3.UP * 1.6, 0.3) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(orb.queue_free)
	_offer_reward()

func _offer_reward(entry := false) -> void:
	_reward_context = "enter" if entry else "clear"
	# Reward draws from the whole pool: the room no longer filters to its own sin.
	_reward_offer = BoonOffers.pick(player.boons,_offer_rng,3,-1,[],entry)
	_build_picker()


## 领域机制说明从选卡前的一次性面板，改成了卡片自己的悬浮提示（见
## BoonPresentation.realm_help_inline）。面板类仍保留给截图与独立诊断，但正式
## 流程不再弹出，也就不再需要"这个领域已经介绍过"的存档状态。
func _prepare_room_rewards() -> void:
	if _orb_halo_mesh == null:
		_orb_halo_mesh = TorusMesh.new()
		_orb_halo_mesh.inner_radius = 0.55
		_orb_halo_mesh.outer_radius = 0.68
	if _orb_column_mesh == null:
		_orb_column_mesh = CylinderMesh.new()
		_orb_column_mesh.top_radius = 0.42
		_orb_column_mesh.bottom_radius = 0.78
		_orb_column_mesh.height = 4.5
	if not is_instance_valid(_prepared_orb):
		_prepared_orb = TalentOrb.new()
		_prepared_orb.prepare()
	if not is_instance_valid(_prepared_picker):
		_prepared_picker = PICKER.instantiate() as BoonPicker
		_prepared_picker.prebuild_ui()
	if not has_meta("reward_shader_warmed"):
		set_meta("reward_shader_warmed", true)
		var warmup := RewardShaderWarmup.new()
		warmup.name = "RewardShaderWarmup"
		var halo := MeshInstance3D.new()
		halo.mesh = _orb_halo_mesh
		halo.scale = Vector3.ONE * 0.001
		halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		halo.extra_cull_margin = 16384.0
		var halo_mat := StandardMaterial3D.new()
		halo_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		halo_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		halo_mat.albedo_color = Color(0.55, 0.95, 1.0, 0.0)
		halo_mat.emission_enabled = true
		halo.material_override = halo_mat
		warmup.add_child(halo)
		var col := MeshInstance3D.new()
		col.mesh = _orb_column_mesh
		col.scale = Vector3.ONE * 0.001
		col.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		col.extra_cull_margin = 16384.0
		var col_mat := StandardMaterial3D.new()
		col_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		col_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		col_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		col_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		col_mat.albedo_color = Color(0.5, 0.9, 1.0, 0.0)
		col_mat.emission_enabled = true
		col.material_override = col_mat
		warmup.add_child(col)
		if not _prepared_orb._shell_meshes.is_empty():
			var orb_mi := MeshInstance3D.new()
			orb_mi.mesh = _prepared_orb._shell_meshes[0].mesh
			orb_mi.scale = Vector3.ONE * 0.001
			orb_mi.transparency = 0.99
			orb_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			orb_mi.extra_cull_margin = 16384.0
			# the shell is a ShaderMaterial now: warm the scatter-heat path, which
			# is the branch that first appears when the orb shatters into pieces
			var warm_shell := ShaderMaterial.new()
			warm_shell.shader = TalentOrb.SHELL_SHADER
			warm_shell.set_shader_parameter("scatter_glow", 1.0)
			warm_shell.set_shader_parameter("seam_glow", 1.0)
			orb_mi.material_override = warm_shell
			warmup.add_child(orb_mi)
		if not _prepared_orb._core_meshes.is_empty():
			var core_mi := MeshInstance3D.new()
			core_mi.mesh = _prepared_orb._core_meshes[0].mesh
			core_mi.scale = Vector3.ONE * 0.001
			core_mi.transparency = 0.99
			core_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			core_mi.extra_cull_margin = 16384.0
			core_mi.material_override = _prepared_orb._core_material
			warmup.add_child(core_mi)
		var halo_quad := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2(TalentOrb.HALO_SIZE, TalentOrb.HALO_SIZE)
		halo_quad.mesh = quad
		halo_quad.rotation.x = -PI * 0.5
		halo_quad.scale = Vector3.ONE * 0.001
		halo_quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		halo_quad.extra_cull_margin = 16384.0
		var warm_halo := ShaderMaterial.new()
		warm_halo.shader = TalentOrb.HALO_SHADER
		halo_quad.material_override = warm_halo
		warmup.add_child(halo_quad)
		add_child(warmup)


func _exit_tree() -> void:
	if is_instance_valid(_prepared_orb) and not _prepared_orb.is_inside_tree():
		_prepared_orb.queue_free()
	_prepared_orb = null
	if is_instance_valid(_prepared_picker) and not _prepared_picker.is_inside_tree():
		_prepared_picker.queue_free()
	_prepared_picker = null


func _build_picker() -> void:
	if is_instance_valid(_prepared_picker):
		selection = _prepared_picker
		_prepared_picker = null
	else:
		selection = PICKER.instantiate() as BoonPicker
	add_child(selection)
	var entry := _reward_context == "enter"
	selection.setup(_reward_offer,player.boons,"选择初始馈赠" if entry else "%s · 门扉馈赠" % TITLES[realm],rerolls_remaining)
	selection.reroll_requested.connect(_reroll_reward)
	selection.chosen.connect(_reward_chosen)
	selection.skipped.connect(_reward_skipped)

func _reroll_reward() -> void:
	if rerolls_remaining <= 0 or not is_instance_valid(selection):
		return
	rerolls_remaining -= 1
	var entry := _reward_context == "enter"
	_reward_offer = BoonOffers.pick(player.boons,_offer_rng,3,-1,_reward_offer,entry)
	selection.update_offer(_reward_offer,rerolls_remaining)
	selection.show_reroll_cost()
	reroll_spent.emit(self)

func _reward_chosen(card: BoonData) -> void:
	Events.boon_chosen.emit(card)
	reward_selected.emit(self,card)
	_finish_reward()

func _reward_skipped() -> void:
	_finish_reward()

func _finish_reward() -> void:
	selection = null
	var completed := _reward_context
	_reward_context = ""
	if completed == "enter":
		if not boss_room and not is_instance_valid(_prepared_picker):
			_prepared_picker = PICKER.instantiate() as BoonPicker
			_prepared_picker.prebuild_ui()
		return
	_unlock_gate()

## Turns the exit gate green and interactive. The sanctuary supplies its own
## caption because the next room is always the boss floor.
func _unlock_gate(label_text := "") -> void:
	exit_ready = true
	_gate_material.albedo_color = Color(0.55,0.82,0.77)
	_gate_material.emission = Color(0.25,0.8,0.66)
	_portal_material.albedo_color = Color(0.35,0.9,0.75,0.24)
	_portal_material.emission = Color(0.2,0.8,0.6)
	_gate_label.text = label_text if not label_text.is_empty() else "下一关\n靠近后按 %s 进入" % KeyHint.of("interact")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		# the orb takes priority over the door while it is still unclaimed
		if _orb_ready and is_instance_valid(talent_orb) and talent_orb.player_in_range(player):
			claim_talent()
			get_viewport().set_input_as_handled()
			return
		if request_rest():
			get_viewport().set_input_as_handled()
			return
		if request_exit():
			get_viewport().set_input_as_handled()
	elif fallen and event is InputEventKey and event.pressed and event.physical_keycode == KEY_R and not campaign:
		retry()

func retry() -> void:
	if not fallen:
		return
	if campaign:
		retry_requested.emit(self)
	elif get_tree().current_scene == self:
		get_tree().paused = false
		get_tree().reload_current_scene.call_deferred()

func request_hub() -> void:
	hub_requested.emit(self)

func request_title() -> void:
	title_requested.emit(self)

func request_exit() -> bool:
	if not exit_ready or fallen or transitioning or get_tree().paused:
		return false
	if player.global_position.distance_to(gate.global_position) > 3.0:
		return false
	var ray := PhysicsRayQueryParameters3D.create(player.eye_position(),gate.global_position+Vector3.UP,CollisionLayers.WORLD)
	if not get_world_3d().direct_space_state.intersect_ray(ray).is_empty():
		return false
	transitioning = true
	exit_requested.emit(self)
	if not campaign and get_tree().current_scene == self:
		_standalone_next.call_deferred()
	return true

func _standalone_next() -> void:
	var next_realm := realm
	var suffix := "1"
	match room_index:
		0:
			suffix = "2"
		1:
			suffix = "boss" if deprivations.has(PsycheFragments.SLOTH) else "rest"
		2:
			suffix = "boss"
		_:
			next_realm = realm+1
	if next_realm >= REALMS.size():
		transitioning = false
		return
	var path := "res://maps/realms/%s_%s.tscn" % [REALMS[next_realm],suffix]
	if not ResourceLoader.exists(path):
		transitioning = false
		return
	var next := (load(path) as PackedScene).instantiate() as RealmStage
	next.configure_run(depth,deprivations,player.fragments.shards,player.health.health,player.boons.all_equipped())
	next.difficulty_multiplier = difficulty_multiplier
	next.hp_multiplier = hp_multiplier
	next.tempo_multiplier = tempo_multiplier
	next.run_seed = run_seed
	next.rerolls_remaining = rerolls_remaining
	get_tree().root.add_child(next)
	get_tree().current_scene = next
	queue_free()

func _on_player_died(_source: Node) -> void:
	if fallen:
		return
	fallen = true
	if geometry != null and geometry.has_method("stop_audio"):
		geometry.call("stop_audio")
	if is_instance_valid(selection):
		selection.dismiss_for_transition()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var cause: StringName = &"combat"
	if player.health.last_damage_context.get("environmental_fatal",false) or player.health.last_damage_context.get("environmental_penalty",false):
		cause = StringName(player.health.last_damage_context.get("tag",&"environment"))
	player_fallen.emit(self,cause)

func objective_text() -> String:
	if fallen:
		return "心智破碎 · 按 R 重新挑战"
	if transitioning:
		return "穿越门扉…"
	if rest_room:
		if rest_used:
			return "心绪已平复 · 前往首领门扉按 %s" % KeyHint.of("interact")
		return "静息石座 · 靠近后按 %s 恢复生命" % KeyHint.of("interact")
	if exit_ready:
		return "前往门扉 · 靠近后按 %s" % KeyHint.of("interact")
	if boss_defeated and not cleared:
		return "拾取%s · 走近获得独立能力" % PsycheShardPickup.TITLES[realm]
	if cleared:
		return "接受心魔的馈赠"
	if boss_room:
		return "击败聚合体 · 留意招式间隙"
	return "击碎领域守卫 · 剩余 %d" % living_enemies()

func _build_world() -> void:
	var preset := MonumentOptics.realm_preset(REALMS[realm] if realm >= 0 and realm < REALMS.size() else "sloth")
	var world := WorldEnvironment.new()
	world.name = "RealmEnvironment"
	var environment := preload("res://environments/default_env.tres").duplicate() as Environment
	MonumentOptics.configure_environment(environment, preset["env"])
	world.environment = environment
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.name = "RealmSun"
	MonumentOptics.configure_sun(sun, preset["sun_rot"], preset["sun_color"], preset["sun_energy"])
	add_child(sun)
	MonumentOptics.add_reflection_probe(self)
	if realm == 0:
		MonumentOptics.add_volumetric_shaft(
			self, Vector3(-4.0, 18.0, -18.0), Vector3(0.5, 0.0, 3.0),
			Color("ffd59c"), 12.5, 4.5, 52.0, 30.0, true
		)
		var cool_rim := DirectionalLight3D.new()
		cool_rim.name = "SkyBounceRim"
		cool_rim.rotation_degrees = Vector3(-32.0, 142.0, 0.0)
		cool_rim.light_color = Color("7aa8db")
		cool_rim.light_energy = 0.36
		cool_rim.shadow_enabled = false
		add_child(cool_rim)

func _bake_navigation() -> void:
	_region = NavigationRegion3D.new()
	_region.name = "NavigationRegion"
	var nav := NavigationMesh.new()
	nav.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nav.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_GROUPS_WITH_CHILDREN
	nav.geometry_source_group_name = "navigation_geometry"
	nav.agent_radius = 0.5
	nav.agent_height = 2.0
	nav.cell_size = 0.5
	nav.cell_height = 0.25
	_region.navigation_mesh = nav
	add_child(_region)
	_region.bake_navigation_mesh(false)

func _build_gate() -> void:
	gate = Node3D.new()
	gate.name = "ExitGate"
	gate.position = geometry.call("exit_position") if geometry.has_method("exit_position") else Vector3(0,0,-20)
	add_child(gate)
	_gate_material = StandardMaterial3D.new()
	_gate_material.albedo_color = Color("b1843c") if realm == 0 else Color("8568a8")
	_gate_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_gate_material.emission_enabled = true
	_gate_material.emission = Color("58432c")
	_gate_material.emission_energy_multiplier = 0.4
	for side in [-1.0,1.0]:
		var frame := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.22,3.8,0.3)
		frame.mesh = mesh
		frame.position = Vector3(side*1.5,1.9,0)
		frame.material_override = _gate_material
		gate.add_child(frame)
	var lintel := MeshInstance3D.new()
	var beam := BoxMesh.new()
	beam.size = Vector3(3.22,0.22,0.3)
	lintel.mesh = beam
	lintel.position.y = 3.8
	lintel.material_override = _gate_material
	gate.add_child(lintel)
	_portal_material = StandardMaterial3D.new()
	_portal_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_portal_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_portal_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_portal_material.albedo_color = Color(0.83,0.60,0.25,0.13) if realm == 0 else Color(0.55,0.35,0.8,0.13)
	_portal_material.emission_enabled = true
	_portal_material.emission = Color("a37131") if realm == 0 else Color(0.4,0.2,0.7)
	var portal := MeshInstance3D.new()
	var surface := QuadMesh.new()
	surface.size = Vector2(2.8,3.6)
	portal.mesh = surface
	portal.position.y = 1.8
	portal.material_override = _portal_material
	portal.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gate.add_child(portal)
	_gate_label = Label3D.new()
	_gate_label.text = "下一关门扉\n%s" % ("击败聚合体并拾取碎片后开启" if boss_room else "击碎守卫并领取馈赠后开启")
	_gate_label.position = Vector3(0,4.5,0)
	_gate_label.font_size = 48
	_gate_label.outline_size = 8
	_gate_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	gate.add_child(_gate_label)
