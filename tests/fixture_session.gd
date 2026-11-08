extends Node
## The AC-07 check (Cut-001b: the same starting point can play a run again;
## docs/adr/0005-reproducible-runs.md). Plays each fixture in res://fixtures/
## with the bot, several times over, through the real game: zone scenes, buff
## choice, end screen, restart. For each run it writes a trace (events, and a
## snapshot of the player, the enemies and the capture every half second) and
## takes its hash. Runs of one fixture must have the same hash.
##
## Needs the fixed step, or the runs cannot be the same:
##   godot --headless --fixed-fps 60 --path . res://tests/fixture_test.tscn
## Options after `--`: --fixture=<id> plays only that one, --runs=<n> sets how
## many times each is played (default 2), --trace-dir=<dir> saves each trace,
## --sample-every=<ticks> sets how often the state is written to it (default 30).
## Exits 1 if a check failed or the run stopped early.
##
## It is added to the root by fixture_test.gd, because the zones change the
## current scene and would free it.

const FIXTURE_DIR := "res://fixtures"
const FIXED_DELTA := 1.0 / 60.0
## Longest a run may take before it is called a timeout: ten simulated minutes.
const MAX_TICKS := 60 * 60 * 10
const DEFAULT_SAMPLE_EVERY := 30

var _bot := FixtureBot.new()
var _trace := PackedStringArray()
var _start_frame := 0
var _watched_point: CapturePoint
var _delta_seen := 0.0
var _failures := 0
var _finished := false
var _only := ""
var _runs := 2
var _trace_dir := ""
var _sample_every := DEFAULT_SAMPLE_EVERY


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--fixture="):
			_only = arg.trim_prefix("--fixture=")
		elif arg.begins_with("--runs="):
			_runs = maxi(arg.trim_prefix("--runs=").to_int(), 1)
		elif arg.begins_with("--trace-dir="):
			_trace_dir = arg.trim_prefix("--trace-dir=")
		elif arg.begins_with("--sample-every="):
			_sample_every = maxi(arg.trim_prefix("--sample-every=").to_int(), 1)
	add_child(_bot)
	Events.enemy_killed.connect(func(enemy: Node): _log("kill %s" % enemy.name))
	Events.zone_cleared.connect(func(zone: int): _log("zone_cleared %d" % zone))
	Events.point_captured.connect(func(zone: int): _log("point_captured %d" % zone))
	Events.buff_chosen.connect(func(buff: Resource): _log("buff %s" % buff.resource_path.get_file()))
	Events.player_died.connect(func(): _log("player_died"))
	Events.run_won.connect(func(): _log("run_won"))
	await _run()
	await _cleanup()
	var ok := _failures == 0 and _finished
	print("%s (%d failed%s)" % ["ALL PASSED" if ok else "FAIL", _failures, "" if _finished else ", run did not finish"])
	get_tree().quit(0 if ok else 1)


## Trace recording is finished before this teardown. Fixed-fps headless frames
## can outpace the audio worker; release the last scene and let queued playback
## stops drain rather than quitting with the worker still holding WAV references.
func _cleanup() -> void:
	_bot.reset()
	get_tree().paused = false
	var scene := get_tree().current_scene
	if scene != null:
		get_tree().current_scene = null
		scene.free()
	await get_tree().process_frame
	OS.delay_msec(100)
	await get_tree().process_frame


func _process(delta: float) -> void:
	_delta_seen = delta


func _run() -> void:
	print("== the step is fixed")
	var physics_before := Engine.get_physics_frames()
	var process_before := Engine.get_process_frames()
	for i in 10:
		await get_tree().process_frame
	_check("each frame is exactly 1/60 s (run with --fixed-fps 60)", absf(_delta_seen - FIXED_DELTA) < 1e-9)
	_check("each frame is one physics tick",
		Engine.get_physics_frames() - physics_before == Engine.get_process_frames() - process_before)
	if _failures > 0:
		return

	print("== the session starts every zone")
	# `--fixture=` also asks the game to start that zone. On a test scene that
	# would be a throwaway run before the first, warming the navigation map, so
	# run 1 would move on its first tick while run 2 waits one tick (#39).
	_check("no zone runs before the session starts the first",
		get_tree().get_first_node_in_group("zone_director") == null)

	print("== the seed")
	_check("a zone seed is the same each time", _zone_seed_of(7, 1) == _zone_seed_of(7, 1))
	_check("another seed gives another zone seed", _zone_seed_of(7, 1) != _zone_seed_of(8, 1))
	_check("another zone gives another zone seed", _zone_seed_of(7, 1) != _zone_seed_of(7, 2))
	RunState.clear_fixture()
	RunState.start_new_run()
	var first_seed := RunState.run_seed
	RunState.start_new_run()
	_check("an ordinary run gets a new seed each time", RunState.run_seed != first_seed)

	var ids := _fixture_ids()
	_check("there is at least one fixture", not ids.is_empty())
	var hashes := {}
	for id in ids:
		var fixture := RunFixture.by_id(id)
		_check("fixtures/%s.tres loads and carries a matching id" % id,
			fixture != null and fixture.id.to_lower() == id.to_lower())
		if fixture == null:
			continue
		print("== %s  seed %d  zone %d  buffs %d  (%s)" % [fixture.id, fixture.run_seed, fixture.start_zone,
			fixture.buffs.size(), fixture.description])
		var results: Array[Dictionary] = []
		for n in _runs:
			results.append(await _play(fixture, n))
			var r := results[n]
			print("   run %d: %s after %d ticks (%.1f s), %d trace lines, hash %s" % [n + 1, r.result, r.ticks,
				r.ticks / 60.0, r.lines, r.hash])
		hashes[fixture.id] = results[0].hash
		for n in range(1, _runs):
			_check("%s run %d has the same hash as run 1" % [fixture.id, n + 1], results[n].hash == results[0].hash)
			_check("%s run %d ends the same way" % [fixture.id, n + 1],
				results[n].result == results[0].result and results[n].ticks == results[0].ticks)
			if results[n].hash != results[0].hash:
				print("   first difference: %s" % _first_difference(results[0].trace, results[n].trace))
		_check("%s run ends in a win or a death, not a timeout" % fixture.id, results[0].result != "超时")

		print("== %s again with another seed" % fixture.id)
		var other := fixture.duplicate() as RunFixture
		other.run_seed = fixture.run_seed + 1
		var changed := await _play(other, 0, "seed%d" % other.run_seed)
		print("   seed %d: %s after %d ticks, hash %s" % [other.run_seed, changed.result, changed.ticks, changed.hash])
		_check("%s with another seed is a different run" % fixture.id, changed.hash != results[0].hash)

	RunState.clear_fixture()
	RunState.start_new_run()
	print("== hashes")
	for id in hashes:
		print("   %s  %s" % [id, hashes[id]])
	_finished = true


## Plays `fixture` once and returns {result, ticks, lines, hash, trace}. The
## first run starts the fixture; every later one presses the end screen's
## restart button, which is what a player does after a death or a win.
func _play(fixture: RunFixture, run_number: int, label := "") -> Dictionary:
	_trace = PackedStringArray()
	_watched_point = null
	_bot.reset()
	_start_frame = Engine.get_physics_frames()
	var end := _end_screen()
	if run_number == 0 or end == null:
		get_tree().paused = false
		RunState.start_fixture(fixture)
		get_tree().change_scene_to_file(RunState.zone_scene())
	else:
		(end.get_node("Center/Box/Restart") as Button).pressed.emit()
	_check("%s run %d starts from the fixture" % [fixture.id, run_number + 1], _at_fixture_start(fixture))

	var title := ""
	var ticks := 0
	while ticks < MAX_TICKS:
		await get_tree().physics_frame
		ticks = Engine.get_physics_frames() - _start_frame
		_watch_capture()
		if ticks % _sample_every == 0:
			_trace.append(_snapshot(ticks))
		end = _end_screen()
		if end != null:
			title = (end.get_node("Center/Box/Title") as Label).text
			break
	var result := title if title != "" else "超时"
	_trace.append("%d end %s" % [ticks, result])
	var text := "\n".join(_trace)
	if _trace_dir != "":
		DirAccess.make_dir_recursive_absolute(_trace_dir)
		var name := label if label != "" else "run%d" % (run_number + 1)
		var file := FileAccess.open("%s/%s_%s.txt" % [_trace_dir, fixture.id, name], FileAccess.WRITE)
		file.store_string(text + "\n")
	return {"result": result, "ticks": ticks, "lines": _trace.size(), "hash": text.sha256_text().substr(0, 16),
		"trace": _trace.duplicate()}


func _at_fixture_start(fixture: RunFixture) -> bool:
	if RunState.zone_index != fixture.start_zone or RunState.run_seed != fixture.run_seed:
		return false
	if RunState.buffs.size() != fixture.buffs.size():
		return false
	for i in fixture.buffs.size():
		if RunState.buffs[i] != fixture.buffs[i]:
			return false
	return true


func _end_screen() -> Node:
	var director := get_tree().get_first_node_in_group("zone_director") as ZoneDirector
	if director == null:
		return null
	for child in director.get_children():
		if child.has_signal("restart_pressed"):
			return child
	return null


## Logs each hammer strike of the zone now being played.
func _watch_capture() -> void:
	var director := get_tree().get_first_node_in_group("zone_director") as ZoneDirector
	if director == null or director.capture_point == _watched_point:
		return
	_watched_point = director.capture_point
	_watched_point.struck.connect(func(perfect: bool, offset_ms: float, worth: float):
		_log("strike %s %+.3f ms +%.5f" % ["perfect" if perfect else "ordinary", offset_ms, worth]))


func _snapshot(tick: int) -> String:
	var player := get_tree().get_first_node_in_group("player") as Player
	var director := get_tree().get_first_node_in_group("zone_director") as ZoneDirector
	if player == null or director == null:
		return "%d S no zone" % tick
	var parts: PackedStringArray = ["%d S" % tick, "zone=%d" % RunState.zone_index, "phase=%d" % director.phase,
		"player=%s hp=%.4f ammo=%d/%d" % [_vec(player.global_position), player.health.health, player.weapon.ammo,
			player.weapon.reserve],
		"capture=%.5f" % director.capture_point.progress]
	for node in get_tree().get_nodes_in_group("enemy"):
		var enemy := node as Enemy
		parts.append("%s:%d:%s:%.3f" % [enemy.name, enemy.state, _vec(enemy.global_position), enemy.health.health])
	return " ".join(parts)


func _log(text: String) -> void:
	_trace.append("%d %s" % [Engine.get_physics_frames() - _start_frame, text])


func _fixture_ids() -> Array[String]:
	var ids: Array[String] = []
	if _only != "":
		ids.append(_only)
		return ids
	for file in DirAccess.get_files_at(FIXTURE_DIR):
		if file.ends_with(".tres"):
			ids.append(file.get_basename())
	ids.sort()
	return ids


func _first_difference(a: PackedStringArray, b: PackedStringArray) -> String:
	for i in mini(a.size(), b.size()):
		if a[i] != b[i]:
			return "line %d\n     run 1: %s\n     other: %s" % [i + 1, a[i], b[i]]
	return "one trace is longer (%d vs %d lines)" % [a.size(), b.size()]


func _zone_seed_of(run_seed: int, zone: int) -> int:
	var saved_seed := RunState.run_seed
	var saved_zone := RunState.zone_index
	RunState.run_seed = run_seed
	RunState.zone_index = zone
	var value := RunState.zone_seed()
	RunState.run_seed = saved_seed
	RunState.zone_index = saved_zone
	return value


func _vec(v: Vector3) -> String:
	return "%.5f,%.5f,%.5f" % [v.x, v.y, v.z]


func _check(label: String, ok: bool) -> void:
	if not ok:
		_failures += 1
	print("  [%s] %s" % ["ok" if ok else "FAIL", label])
