class_name ZoneDirector
extends Node
## Runs one zone from start to finish:
##   1. bakes navigation, applies the run's buffs, hands enemies their target;
##   2. when every guard is dead, opens the capture building for hammering
##      (the boss zone opens it at once and its enemies do not gate it);
##   3. when the building is at 100% and the flag is planted, offers a buff and
##      loads the next zone, or wins the run;
##   4. on the player's death, shows the end screen and restarts from zone 1.
## Only this node and RunState change run state (see ARCHITECTURE.md).

## The two halves of a zone, then the finish (Cut-001b AC-01).
enum Phase { CLEAR_GUARDS, HAMMER_POINT, FLAG_PLANTED }

signal objective_changed(text: String)
signal phase_changed(phase: Phase)
signal enemies_changed(alive: int, total: int)

const BUFF_SELECT := preload("res://ui/buff_select.tscn")
const RUN_END := preload("res://ui/run_end.tscn")
const BUFF_CHOICES := 3
## Seconds between the flag going up and the pause screen freezing the scene.
const FLAG_RAISE_TIME := 1.4

@export var navigation_region: NavigationRegion3D
@export var capture_point: CapturePoint
## The boss zone: the city core opens as soon as the zone starts, and killing
## its enemies changes nothing (Cut-001b: no "clear first" for the boss).
@export var open_at_start := false

var objective := ""
var phase := Phase.CLEAR_GUARDS
var enemies_total := 0
## The zone's boss, if it has one. The HUD reads its health.
var boss: Enemy
## Zone number and buff count when this zone started, for the end screen;
## RunState is already reset by the time player_died reaches us.
var zone_index := 0
var _alive: Array[Enemy] = []
var _ended := false


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

	var player := get_tree().get_first_node_in_group("player") as Player
	for buff: Buff in RunState.buffs:
		player.stats.apply_buff(buff)

	var cover_points: Array[CoverPoint] = []
	for node in get_tree().get_nodes_in_group("cover_point"):
		cover_points.append(node as CoverPoint)
	for enemy: Enemy in get_tree().get_nodes_in_group("enemy"):
		enemy.setup(player, cover_points)
		_alive.append(enemy)
		if enemy.is_boss:
			boss = enemy
	enemies_total = _alive.size()

	Events.enemy_killed.connect(_on_enemy_killed)
	Events.player_died.connect(_on_player_died)
	capture_point.captured.connect(_on_point_captured)
	if open_at_start:
		capture_point.open()
		_set_phase(Phase.HAMMER_POINT, "砸开城市核心，按 E 挥锤")
	else:
		_set_phase(Phase.CLEAR_GUARDS, "消灭所有敌人")


func _on_enemy_killed(enemy: Node) -> void:
	if not enemy in _alive:
		return
	_alive.erase(enemy)
	enemies_changed.emit(_alive.size(), enemies_total)
	if _alive.is_empty() and phase == Phase.CLEAR_GUARDS:
		Events.zone_cleared.emit(zone_index)
		capture_point.open()
		_set_phase(Phase.HAMMER_POINT, "前往据点，按 E 挥锤砸点")


func _on_point_captured() -> void:
	_set_phase(Phase.FLAG_PLANTED, "旗已插上")
	Events.point_captured.emit(zone_index)
	await get_tree().create_timer(FLAG_RAISE_TIME).timeout
	if _ended:
		return
	if RunState.is_last_zone():
		Events.run_won.emit()
		_show_end("胜利", "夺下城市核心，攻下全部 %d 个战区" % RunState.ZONE_SCENES.size())
		return
	_set_objective("选择一个增益")
	var select := BUFF_SELECT.instantiate()
	add_child(select)
	select.setup(BuffPool.pick(BUFF_CHOICES))
	select.chosen.connect(_on_buff_chosen)


func _on_buff_chosen(buff: Buff) -> void:
	Events.buff_chosen.emit(buff)
	RunState.advance_zone()
	get_tree().change_scene_to_file.call_deferred(RunState.zone_scene())


func _on_player_died() -> void:
	_show_end("阵亡", "倒在第 %d 个战区，本局增益已清空" % (zone_index + 1))


func _show_end(title: String, subtitle: String) -> void:
	if _ended:
		return
	_ended = true
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
