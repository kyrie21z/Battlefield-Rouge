class_name ZoneDirector
extends Node
## Runs one zone from start to finish:
##   1. bakes navigation and applies old buffs. Only zone 0 offers an entry
##      buff; later zones start combat immediately;
##   2. when every guard is dead, opens the capture building for hammering.
##      The boss zone keeps the core shut until the boss dies, then one hammer
##      finishes it. The six small enemies do not gate that;
##   3. a small zone then spawns reinforcements from the rear. They never
##      close the building or move its progress. At 100% the flag goes up,
##      a shockwave sends every living minion running for the rear spawns,
##      and a pedestal appears. Interact at the pedestal offers the clear
##      buff; choosing it loads the next zone. The boss zone has none of
##      that: the flag wins the run;
##   4. on the player's death, shows the end screen and restarts from zone 1.
## Only this node and RunState change run state (see ARCHITECTURE.md).

## The two halves of a zone, then the finish (Cut-001b AC-01).
enum Phase { CLEAR_GUARDS, HAMMER_POINT, FLAG_PLANTED, BUFF_SELECT, BOSS_STANDING }

signal objective_changed(text: String)
signal phase_changed(phase: Phase)
signal enemies_changed(alive: int, total: int)
## A reinforcement was placed in the zone. Emitted after placement for
## listeners; it never changes the spawn order or the run's timing.
signal reinforcement_spawned(position: Vector3)

const BUFF_SELECT := preload("res://ui/buff_select.tscn")
const RUN_END := preload("res://ui/run_end.tscn")
const ENEMY_SCENE := preload("res://actors/enemy/enemy.tscn")
const BUFF_CHOICES := 3
## Seconds between the flag going up and the boss victory screen. A small zone
## does not pause on its own; the pedestal waits for interact.
const FLAG_RAISE_TIME := 1.4
## Beside the building, clear of the 2.4 m objective and inside a short walk.
const PEDESTAL_OFFSET := Vector3(3.0, 0.0, 2.2)

@export var navigation_region: NavigationRegion3D
@export var capture_point: CapturePoint
## The boss zone. The core stays locked while the boss lives. Its death opens
## the core; one hammer then plants the flag. The six small enemies do not
## gate it, and this zone never spawns reinforcements or a shockwave.
@export var is_boss_zone := false
## Small zones only. Null on the boss zone, which never spawns reinforcements.
@export var reinforcement_config: ReinforcementConfig

var objective := ""
var phase := Phase.CLEAR_GUARDS
var enemies_total := 0
## The zone's boss, if it has one. The HUD reads its health.
var boss: Enemy
## Zone number and buff count when this zone started, for the end screen;
## RunState is already reset by the time player_died reaches us.
var zone_index := 0
## "enter" only when zone 0 offers a buff before combat; "clear" after each
## small zone. Empty while fighting, or once the offer has been taken.
var selection_context := ""
var selection_count := 0
var selection: CanvasLayer
## Present after a small zone plants its flag, until the clear buff is taken.
var buff_pedestal: BuffPedestal
## World positions of reinforcements, in spawn order. Tests compare this.
var reinforcement_spawn_log: Array[Vector3] = []
## Guards placed with the scene. Only they gate the building. Reinforcements
## are tracked apart so a later wave cannot close it again.
var _guards: Array[Enemy] = []
var _reinforcements: Array[Enemy] = []
var _spawn_points: Array[Node3D] = []
var _cover_points: Array[CoverPoint] = []
## Shared by every enemy in this zone so two do not reserve the same spot.
var _firing_board := FiringPositionBoard.new()
var _player: Player
var _ended := false
var _combat_started := false
var _capture_handled := false
var _transitioning := false
var _reinforcing := false
var _reinforce_wait := 0.0
var _reinforcement_serial := 0
var _shockwave_played := false


func _enter_tree() -> void:
	add_to_group("zone_director")


func _ready() -> void:
	zone_index = RunState.zone_index
	# Nothing has drawn a random number yet; everything the zone draws from here
	# on follows from the run's seed, and every time in it counts from here (AC-07).
	seed(RunState.zone_seed())
	SimClock.restart()
	if navigation_region != null:
		navigation_region.bake_navigation_mesh(false)

	for node in get_tree().get_nodes_in_group("player"):
		if get_parent().is_ancestor_of(node):
			_player = node as Player
			break
	for buff: Buff in RunState.buffs:
		_player.stats.apply_buff(buff)

	for node in _nodes_in_zone("cover_point"):
		_cover_points.append(node as CoverPoint)
	for node in _nodes_in_zone("reinforcement_spawn"):
		_spawn_points.append(node as Node3D)
	# A hand sort, not sort_custom: that helper did not put the same names in
	# the same order on two loads of this scene, so the seeded pick drifted.
	for i in _spawn_points.size():
		for j in range(i + 1, _spawn_points.size()):
			if String(_spawn_points[j].name) < String(_spawn_points[i].name):
				var swap := _spawn_points[i]
				_spawn_points[i] = _spawn_points[j]
				_spawn_points[j] = swap
	for node in _nodes_in_zone("enemy"):
		var enemy := node as Enemy
		_guards.append(enemy)
		_watch_departure(enemy)
		if enemy.is_boss:
			boss = enemy
	enemies_total = _guards.size()

	Events.enemy_killed.connect(_on_enemy_killed)
	Events.player_died.connect(_on_player_died)
	capture_point.captured.connect(_on_point_captured)
	# One entry choice per run, on the first zone only. A fixture that starts
	# later (FX-002 opens on the boss) is not zone 0, so it fights immediately.
	# Enemies are earlier siblings, so their _ready and @onready nodes have
	# already finished; setup() only stores the player and cover points.
	# The clear choice pauses the tree and the entry UI used to unpause the
	# next zone. Zones that skip that UI must clear the pause themselves.
	if zone_index == 0:
		_offer_buff("enter")
	else:
		get_tree().paused = false
		_start_combat()


func _physics_process(delta: float) -> void:
	if _reinforcing and reinforcement_config != null:
		var interval := reinforcement_config.interval_seconds
		if interval > 0.0:
			_reinforce_wait += delta
			while _reinforce_wait + 0.000001 >= interval:
				_reinforce_wait -= interval
				_spawn_wave()
	# A press made during another node's physics step is visible to later nodes
	# through `is_action_pressed` immediately, but `is_action_just_pressed` stays
	# false until the next frame — and the fixture bot releases the key at the
	# start of that frame. A test that presses, awaits `physics_frame`, then
	# releases resumes before this step and clears the held state, while
	# `is_action_just_pressed` remains true for the frame. Accept either.
	if phase == Phase.FLAG_PLANTED and buff_pedestal != null and selection_context.is_empty() \
			and not _ended and not _transitioning and is_instance_valid(_player) \
			and not _player.health.is_dead() \
			and (Input.is_action_pressed(&"interact") or Input.is_action_just_pressed(&"interact")) \
			and buff_pedestal.in_range(_player):
		_offer_buff("clear")


func _start_combat() -> void:
	if _combat_started or _ended:
		return
	_combat_started = true
	for enemy in _guards:
		enemy.setup(_player, _cover_points, _firing_board)
	if is_boss_zone:
		_set_phase(Phase.BOSS_STANDING, "打倒 Boss")
	else:
		_set_phase(Phase.CLEAR_GUARDS, "消灭所有敌人")
		if _guards.is_empty():
			_open_capture_point()
	enemies_changed.emit(_guards.size(), enemies_total)


func _on_enemy_killed(enemy: Node) -> void:
	if enemy in _guards:
		_guards.erase(enemy)
		enemies_changed.emit(_guards.size(), enemies_total)
		if is_boss_zone:
			if enemy == boss and _combat_started and not _ended:
				_open_boss_core()
			return
		if _guards.is_empty() and _combat_started and not _ended:
			_open_capture_point()
		return
	if enemy in _reinforcements:
		_reinforcements.erase(enemy)


func _open_boss_core() -> void:
	if phase != Phase.BOSS_STANDING or _ended:
		return
	capture_point.open()
	_set_phase(Phase.HAMMER_POINT, "砸碎城市核心，按 E")


func _open_capture_point() -> void:
	if phase != Phase.CLEAR_GUARDS:
		return
	Events.zone_cleared.emit(zone_index)
	capture_point.open()
	_set_phase(Phase.HAMMER_POINT, "前往据点，按 E 挥锤砸点")
	_begin_reinforcements()


func _on_point_captured() -> void:
	if _ended or _capture_handled or not _combat_started or phase != Phase.HAMMER_POINT:
		return
	_capture_handled = true
	var flag_text := "旗已插上" if is_boss_zone else "旗已插上，到增益台按 F 领取增益"
	_set_phase(Phase.FLAG_PLANTED, flag_text)
	Events.point_captured.emit(zone_index)
	if not is_boss_zone:
		_stop_reinforcements()
		_play_shockwave()
		_spawn_pedestal()
	await get_tree().create_timer(FLAG_RAISE_TIME).timeout
	if _ended or _transitioning:
		return
	if RunState.is_last_zone():
		Events.run_won.emit()
		_show_end("胜利", "夺下城市核心，攻下全部 %d 个战区" % RunState.ZONE_SCENES.size())


## How many reinforcements are still in the scene, fleeing ones included.
func reinforcement_count() -> int:
	var count := 0
	for enemy in _reinforcements:
		if is_instance_valid(enemy) and enemy.state != Enemy.State.DEAD:
			count += 1
	return count


func _begin_reinforcements() -> void:
	if is_boss_zone or reinforcement_config == null or _spawn_points.is_empty() or _ended:
		return
	_reinforcing = true
	_reinforce_wait = 0.0
	_spawn_wave()


func _stop_reinforcements() -> void:
	_reinforcing = false


func _spawn_wave() -> void:
	if not _reinforcing or reinforcement_config == null or _spawn_points.is_empty():
		return
	var room := reinforcement_config.max_alive - reinforcement_count()
	var count := mini(reinforcement_config.per_wave, maxi(room, 0))
	for _i in count:
		_spawn_one()


func _spawn_one() -> void:
	var point: Node3D = _spawn_points.pick_random()
	var enemy := ENEMY_SCENE.instantiate() as Enemy
	_reinforcement_serial += 1
	enemy.name = "Reinforcement%d" % _reinforcement_serial
	get_parent().add_child(enemy)
	enemy.global_position = point.global_position
	enemy.rotation.y = PI
	_reinforcements.append(enemy)
	reinforcement_spawn_log.append(enemy.global_position)
	_watch_departure(enemy)
	enemy.setup(_player, _cover_points, _firing_board)
	enemy.begin_hunt()
	reinforcement_spawned.emit(enemy.global_position)


func _watch_departure(enemy: Enemy) -> void:
	if not enemy.departed.is_connected(_on_enemy_departed):
		enemy.departed.connect(_on_enemy_departed.bind(enemy))


func _on_enemy_departed(enemy: Enemy) -> void:
	_guards.erase(enemy)
	_reinforcements.erase(enemy)


func _play_shockwave() -> void:
	if _shockwave_played or is_boss_zone or _spawn_points.is_empty():
		return
	_shockwave_played = true
	var timeout := 14.0
	if reinforcement_config != null:
		timeout = reinforcement_config.flee_timeout_seconds
	for enemy in _living_minions():
		enemy.begin_retreat(_nearest_spawn(enemy.global_position), timeout)
	_spawn_shockwave_fx()


func _living_minions() -> Array[Enemy]:
	var found: Array[Enemy] = []
	for node in _nodes_in_zone("enemy"):
		var enemy := node as Enemy
		if enemy == null or enemy.is_boss or enemy.state == Enemy.State.DEAD:
			continue
		found.append(enemy)
	return found


## Every living enemy in this zone, guards, reinforcements (also while they
## flee) and the boss. Read-only.
func living_enemies() -> Array[Enemy]:
	var found := _living_minions()
	if boss != null and is_instance_valid(boss) and not boss.health.is_dead():
		found.append(boss)
	return found


## Groups are global. A test can have two zones for a frame; this zone must
## not adopt the other one's guards or spawn markers.
func _nodes_in_zone(group_name: StringName) -> Array[Node]:
	var found: Array[Node] = []
	var root := get_parent()
	for node in get_tree().get_nodes_in_group(group_name):
		if root != null and root.is_ancestor_of(node):
			found.append(node)
	return found


func _nearest_spawn(from: Vector3) -> Vector3:
	var best := _spawn_points[0]
	var best_distance := INF
	for point in _spawn_points:
		var distance := Vector2(point.global_position.x - from.x, point.global_position.z - from.z).length_squared()
		if distance < best_distance:
			best = point
			best_distance = distance
	return best.global_position


func _spawn_shockwave_fx() -> void:
	var ring := MeshInstance3D.new()
	ring.name = "Shockwave"
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.5
	mesh.bottom_radius = 0.5
	mesh.height = 0.2
	ring.mesh = mesh
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.75, 0.92, 1.0, 0.7)
	ring.material_override = material
	get_parent().add_child(ring)
	ring.global_position = capture_point.global_position + Vector3(0.0, 0.4, 0.0)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(ring, "scale", Vector3(48.0, 1.0, 48.0), 0.75)
	tween.tween_property(material, "albedo_color:a", 0.0, 0.75)
	tween.chain().tween_callback(ring.queue_free)
	var audio := AudioStreamPlayer3D.new()
	audio.name = "ShockwaveAudio"
	audio.stream = ProceduralAudio.generate("shockwave")
	audio.max_distance = 80.0
	capture_point.add_child(audio)
	audio.play()
	audio.finished.connect(audio.queue_free)


func _spawn_pedestal() -> void:
	if buff_pedestal != null:
		return
	buff_pedestal = BuffPedestal.new()
	buff_pedestal.name = "BuffPedestal"
	get_parent().add_child(buff_pedestal)
	buff_pedestal.global_position = capture_point.global_position + PEDESTAL_OFFSET


func _offer_buff(context: String) -> void:
	if _ended or _transitioning or not selection_context.is_empty():
		return
	selection_context = context
	selection_count += 1
	var stage_name := "Boss · 城市核心" if is_boss_zone else "小关 %d" % (zone_index + 1)
	var title := "进入%s前：选择一个增益" % stage_name if context == "enter" \
		else "%s已完成：选择通关增益" % stage_name
	_set_phase(Phase.BUFF_SELECT, title)
	selection = BUFF_SELECT.instantiate() as CanvasLayer
	add_child(selection)
	selection.call("setup", BuffPool.pick(BUFF_CHOICES), title)
	selection.connect("chosen", _on_buff_chosen)


func _on_buff_chosen(buff: Buff) -> void:
	if _ended or _transitioning or selection_context.is_empty():
		return
	var context := selection_context
	selection_context = ""
	selection = null
	RunState.record_selection(context, buff)
	Events.buff_chosen.emit(buff)
	if context == "enter":
		_player.stats.apply_buff(buff)
		_start_combat()
	else:
		_transitioning = true
		get_tree().paused = true
		if RunState.advance_zone():
			get_tree().change_scene_to_file.call_deferred(RunState.zone_scene())


func _on_player_died() -> void:
	_show_end("阵亡", "倒在第 %d 个战区，本局增益已清空" % (zone_index + 1))


func _show_end(title: String, subtitle: String) -> void:
	if _ended:
		return
	_ended = true
	selection_context = ""
	if is_instance_valid(selection):
		selection.queue_free()
	selection = null
	var screen := RUN_END.instantiate()
	add_child(screen)
	screen.setup(title, subtitle)
	screen.restart_pressed.connect(_restart)


func _restart() -> void:
	RunState.start_new_run()
	get_tree().change_scene_to_file.call_deferred(RunState.zone_scene())


func _set_phase(new_phase: Phase, text: String) -> void:
	phase = new_phase
	phase_changed.emit(new_phase)
	_set_objective(text)


func _set_objective(text: String) -> void:
	objective = text
	objective_changed.emit(text)
