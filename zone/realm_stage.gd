class_name RealmStage
extends Node3D
## A self-contained room. The run controller injects state and handles campaign exits.
signal stage_cleared(stage: RealmStage)
signal realm_defeated(stage: RealmStage)
signal exit_requested(stage: RealmStage)
signal reward_selected(stage: RealmStage, card: BoonData)
signal reroll_spent(stage: RealmStage)
signal player_fallen(stage: RealmStage, cause: StringName)
@export_range(0,3) var realm: int = 0
@export var room_index: int = 0
@export var boss_room := false
@export var campaign := false
@export var difficulty_multiplier := 1.0
const REALMS := ["sloth","fear","wrath","sorrow"]
const TITLES := ["怠惰 · 凝滞庭院","恐惧 · 破碎长廊","愤怒 · 焦灼竞技场","悲伤 · 泪海"]
const BOSSES := ["sloth_colossus","fear_oculus","wrath_spire","sorrow_monolith"]
const SHARD := preload("res://zone/psyche_shard_pickup.tscn")
const PLAYER := preload("res://actors/player/player.tscn")
const PICKER := preload("res://ui/boon_picker/boon_picker.tscn")
var player: Player
var geometry: Node3D
var enemies: Array[Enemy] = []
var boss: Enemy
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
var depth := 0
var deprivations: Array[int] = []
var saved_shards: Array[int] = []
var saved_hp := -1.0
var saved_boons: Array = []
var _offer_rng := RandomNumberGenerator.new()
var _region: NavigationRegion3D
var _gate_material: StandardMaterial3D
var run_seed := 13800
var rerolls_remaining := 2
var _reward_context := ""
var _reward_offer: Array[BoonData] = []

func _init() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE

func configure_run(value_depth: int, values: Array[int], shards: Array[int], hp: float, boons: Array) -> void:
	depth = maxi(0,value_depth)
	deprivations.assign(values)
	saved_shards.assign(shards)
	saved_hp = hp
	saved_boons = boons.duplicate()
	if is_node_ready():
		_apply_run()

func _ready() -> void:
	SimClock.restart()
	seed(run_seed + realm*100 + room_index + depth*1000)
	_offer_rng.seed = run_seed + 16338 + realm*100 + room_index + depth*1000
	_build_world()
	geometry = get_node_or_null("Geometry") as Node3D
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
	_apply_run()
	player.health.died.connect(_on_player_died)
	_spawn_encounter()
	_build_gate()
	hud = RealmHUD.new()
	hud.name = "RealmHUD"
	hud.stage = self
	add_child(hud)
	get_tree().paused = false

func _apply_run() -> void:
	player.boons.restore(saved_boons)
	player.fragments.configure_deprivation(deprivations)
	player.fragments.restore(saved_shards)
	if saved_hp >= 0:
		player.health.health = clampf(saved_hp,1.0,player.health.max_health)
	if geometry.has_method("set_deprivation"):
		geometry.call("set_deprivation",deprivations.has(realm))
	player.realm_effects.warnings_enabled = not deprivations.has(1)
	for actor in enemies:
		_apply_actor_deprivation(actor)

func _apply_actor_deprivation(actor: Enemy) -> void:
	if "warnings_enabled" in actor:
		actor.set("warnings_enabled",not deprivations.has(1))
	if actor.has_method("set_ordinary_impacts_enabled"):
		actor.call("set_ordinary_impacts_enabled",not deprivations.has(2))
	elif "ordinary_impacts_enabled" in actor:
		actor.set("ordinary_impacts_enabled",not deprivations.has(2))

func _spawn_encounter() -> void:
	if boss_room:
		_spawn_boss()
		return
	var path := "res://actors/enemy/%s/%s_realm_enemy.tscn" % [REALMS[realm],REALMS[realm]]
	if not ResourceLoader.exists(path):
		push_error("Missing realm enemy: " + path)
		return
	var points: Array = [Vector3(-8,0.1,3),Vector3(8,0.1,-4),Vector3(0,0.1,-12),Vector3(-11,0.1,-12),Vector3(11,0.1,-14)]
	if geometry.has_method("spawn_points"):
		points = geometry.call("spawn_points")
	var count := mini(points.size(),3 if room_index == 0 else 5)
	for i in count:
		var actor := (load(path) as PackedScene).instantiate() as Enemy
		actor.set("variant",i%3)
		actor.position = points[i]
		if "opening_delay" in actor:
			actor.set("opening_delay",1.0 + i*0.2)
		if "arena" in actor:
			actor.set("arena",geometry)
		add_child(actor)
		_register_actor(actor)

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

func _register_actor(actor: Enemy) -> void:
	var scale_value := maxf(0.1,difficulty_multiplier)
	actor.health.max_health *= scale_value
	actor.health.health = actor.health.max_health
	if "realm_damage_scale" in actor:
		actor.set("realm_damage_scale",scale_value)
	_apply_actor_deprivation(actor)
	actor.setup(player,[])
	player.boons.register_enemy(actor)
	enemies.append(actor)
	actor.health.died.connect(_on_enemy_died.bind(actor))

func _on_enemy_died(_source: Node, _actor: Enemy) -> void:
	# Health emits synchronously; finish after all death cleanup has run.
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
	if cleared or fallen or living_enemies() > 0:
		return
	if boss_room:
		_finish_boss_defeat()
		return
	cleared = true
	stage_cleared.emit(self)
	_offer_reward()

func _finish_boss_defeat() -> void:
	if boss_defeated:
		return
	boss_defeated = true
	if not deprivations.has(realm):
		deprivations.append(realm)
	player.fragments.configure_deprivation(deprivations)
	player.realm_effects.warnings_enabled = not deprivations.has(1)
	geometry.call("set_deprivation",true)
	for actor in enemies:
		_apply_actor_deprivation(actor)
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

func _offer_reward(entry := false) -> void:
	_reward_context = "enter" if entry else "clear"
	selection = PICKER.instantiate() as BoonPicker
	add_child(selection)
	_reward_offer = BoonOffers.pick(player.boons,_offer_rng,3,-1 if entry else realm,[],entry)
	selection.setup(_reward_offer,player.boons,"选择初始馈赠" if entry else "%s · 门扉馈赠" % TITLES[realm],rerolls_remaining)
	selection.reroll_requested.connect(_reroll_reward)
	selection.chosen.connect(_reward_chosen)
	selection.skipped.connect(_reward_skipped)

func _reroll_reward() -> void:
	if rerolls_remaining <= 0 or not is_instance_valid(selection):
		return
	rerolls_remaining -= 1
	var entry := _reward_context == "enter"
	_reward_offer = BoonOffers.pick(player.boons,_offer_rng,3,-1 if entry else realm,_reward_offer,entry)
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
		return
	exit_ready = true
	_gate_material.albedo_color = Color(0.55,0.82,0.77)
	_gate_material.emission = Color(0.25,0.8,0.66)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and request_exit():
		get_viewport().set_input_as_handled()
	elif fallen and event is InputEventKey and event.pressed and event.physical_keycode == KEY_R and not campaign:
		get_tree().paused = false
		get_tree().reload_current_scene()

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
	var suffix := "2" if room_index == 0 else "boss"
	var next_realm := realm
	if boss_room:
		next_realm = realm+1
		suffix = "1"
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
	next.run_seed = run_seed
	next.rerolls_remaining = rerolls_remaining
	get_tree().root.add_child(next)
	get_tree().current_scene = next
	queue_free()

func _on_player_died(_source: Node) -> void:
	if fallen:
		return
	fallen = true
	if is_instance_valid(selection):
		selection.dismiss_for_transition()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var cause: StringName = &"combat"
	if player.health.last_damage_context.get("environmental_fatal",false):
		cause = StringName(player.health.last_damage_context.get("tag",&"environment"))
	player_fallen.emit(self,cause)

func objective_text() -> String:
	if fallen:
		return "心智破碎 · 按 R 重试" if not campaign else "心智破碎"
	if transitioning:
		return "穿越门扉…"
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
	var world := WorldEnvironment.new()
	world.name = "RealmEnvironment"
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = [Color("bfb8a6"),Color("969faa"),Color("b9a1a0"),Color("a8b9c7")][realm]
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("e1e5ed")
	environment.ambient_light_energy = 0.48
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.glow_enabled = true
	environment.glow_intensity = 0.32
	world.environment = environment
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52,-28,0)
	sun.light_energy = 1.45
	sun.shadow_enabled = true
	add_child(sun)

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
	_gate_material.albedo_color = Color("423a30")
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
	var label := Label3D.new()
	label.text = "门 扉"
	label.position = Vector3(0,4.2,0)
	label.font_size = 56
	label.outline_size = 8
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	gate.add_child(label)
