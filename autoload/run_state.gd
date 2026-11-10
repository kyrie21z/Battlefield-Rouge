extends Node
## State of the current run: which zone the player is in and which buffs they
## have picked. Everything here is lost on death; nothing persists between runs.
## Only RunState and the zone director may change it. See ARCHITECTURE.md.

signal changed

## One scene per zone, in play order. Clearing the last one wins the run.
const ZONE_SCENES: Array[String] = [
	"res://maps/zone_1.tscn",
	"res://maps/zone_2.tscn",
	"res://maps/boss.tscn",
]

var zone_index := 0
var buffs: Array[Resource] = []
var boons: Array[Resource] = []
## Accepted choices in order, including the zone and entry/clear context (AC-04).
var selection_history: Array[Dictionary] = []
## Every random choice in a zone is drawn after the zone director seeds the
## generator from this, so the same seed and the same inputs give the same run
## (AC-07). An ordinary run gets a new one each time it starts.
var run_seed := 0
## The fixture this run started from, or null for an ordinary run. Starting
## over after a death or a win goes back to the same fixture start.
var fixture: RunFixture


func _ready() -> void:
	Events.player_died.connect(start_new_run)
	Events.buff_chosen.connect(add_buff)
	run_seed = randi()
	BuffPool.reset()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--fixture="):
			_start_from_command_line(arg.trim_prefix("--fixture="))


func start_new_run() -> void:
	if fixture != null:
		_apply(fixture)
		return
	zone_index = 0
	buffs.clear()
	boons.clear()
	selection_history.clear()
	run_seed = randi()
	BuffPool.reset()
	changed.emit()


## Puts the run at the fixture's starting point. The caller loads `zone_scene()`.
func start_fixture(start: RunFixture) -> void:
	fixture = start
	_apply(start)


## Drops the fixture, so the next start is an ordinary run again.
func clear_fixture() -> void:
	fixture = null


func add_buff(buff: Resource) -> void:
	buffs.append(buff)
	changed.emit()


func record_selection(context: String, buff: Buff) -> void:
	selection_history.append({
		"zone_index": zone_index,
		"context": context,
		"buff_id": buff.id,
		"buff_title": buff.title,
	})
	changed.emit()


## Moves to the next zone. Returns false once the last zone is done.
func advance_zone() -> bool:
	if zone_index + 1 >= ZONE_SCENES.size():
		return false
	zone_index += 1
	changed.emit()
	return true


func is_last_zone() -> bool:
	return zone_index == ZONE_SCENES.size() - 1


func zone_scene() -> String:
	return ZONE_SCENES[zone_index]


## The seed for the zone being played, so a zone's randomness does not depend
## on how much the earlier zones drew.
func zone_seed() -> int:
	return ("%d/%d" % [run_seed, zone_index]).hash()


func _apply(start: RunFixture) -> void:
	zone_index = start.start_zone
	buffs.assign(start.buffs)
	boons.clear()
	run_seed = start.run_seed
	selection_history.clear()
	BuffPool.reset()
	changed.emit()


## `--fixture=<id>` after `--` on the command line starts the game from that fixture.
func _start_from_command_line(fixture_id: String) -> void:
	var start := RunFixture.by_id(fixture_id)
	if start == null:
		push_error("No fixture with id '%s' in res://fixtures/" % fixture_id)
		return
	start_fixture(start)
	if zone_index != 0:
		_start_fixture_zone.call_deferred()


## Only a normal launch is redirected. A scene launched in place of the game's
## main scene (the fixture test) starts its own zones; starting one here too
## would run a throwaway zone first and warm the navigation map, so the first
## run would move on its first tick while every later one waits a tick.
func _start_fixture_zone() -> void:
	var current := get_tree().current_scene
	var main_scene := str(ProjectSettings.get_setting("application/run/main_scene"))
	if current != null and current.scene_file_path != main_scene:
		return
	get_tree().change_scene_to_file(zone_scene())
