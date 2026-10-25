extends Node
## Plays the boss zone twice in a real window and saves screenshots as Proof
## for Issue #10 (AC-02): once to a victory, once to a defeat. Needs a display,
## so no --headless. Run from the project root:
##   godot --path . res://tests/boss_proof.tscn -- --out=<dir>
## Victory run: the enemies are frozen so the scripted player is not shot; the
## core is hammered with real presses of the `hammer` action, timed against the
## hit moment. Defeat run: the enemies fight as normal and the player stands
## still, so the boss and its six small enemies kill them.
## Each shot prints the debug bar text, and each ending prints its title.

const BOSS_SCENE := "res://maps/boss.tscn"
const SETTLE_FRAMES := 3
const TIMING_TOLERANCE := 0.03
## Longest the defeat run waits for the enemies to kill the player.
const DEFEAT_TIMEOUT := 60.0

var _out_dir := "user://proof"
var _point: CapturePoint
var _debug: CaptureDebug
var _last_swing_msec := -100000


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out_dir = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(_out_dir)
	await _victory_run()
	await _defeat_run()
	get_tree().quit()


func _victory_run() -> void:
	print("#### victory run")
	var scene := await _load_boss()
	var director := scene.get_node("ZoneDirector") as ZoneDirector
	var player := scene.get_node("Player") as Player
	await _show_debug_bar()
	await _shot("01_boss_zone_start")

	# Freeze the enemies and walk up to the boss, so the wave can be seen.
	for enemy: Enemy in get_tree().get_nodes_in_group("enemy"):
		enemy.process_mode = Node.PROCESS_MODE_DISABLED
	player.global_position = Vector3(0.0, 0.0, -3.0)
	await _frames(6)
	await _shot("02_boss_and_six_small")

	player.global_position = _point.global_position + Vector3(0.0, 0.0, 3.6)
	await _frames(6)
	await _swing_at(0.0)
	# Turn round once the strike lands, so the shot shows the enemies standing
	# behind the player while the progress bar reads 12%.
	await get_tree().create_timer(0.1).timeout
	player.rotation.y = PI
	await get_tree().create_timer(0.4).timeout
	await _shot("03_core_open_enemies_alive")
	player.rotation.y = 0.0

	var swings := 0
	while not _point.is_captured() and swings < 40:
		await _swing_at(0.0)
		swings += 1
	# Step back so the flag is in view, and shoot before the end screen pauses.
	player.global_position = Vector3(0.0, 0.0, -6.0)
	await get_tree().create_timer(1.0).timeout
	await _shot("04_flag_on_core")
	await get_tree().create_timer(ZoneDirector.FLAG_RAISE_TIME).timeout
	await _shot("05_victory")
	_print_ending(director)
	get_tree().paused = false
	scene.queue_free()
	await get_tree().process_frame


func _defeat_run() -> void:
	print("#### defeat run")
	var scene := await _load_boss()
	var director := scene.get_node("ZoneDirector") as ZoneDirector
	var player := scene.get_node("Player") as Player
	await _show_debug_bar()
	player.global_position = Vector3(0.0, 0.0, -4.0)
	var started := Time.get_ticks_msec()
	await get_tree().create_timer(1.3).timeout
	await _shot("06_under_fire")
	while not player.health.is_dead() and (Time.get_ticks_msec() - started) / 1000.0 < DEFEAT_TIMEOUT:
		await get_tree().process_frame
	print("player dead: %s after %.1f s" % [player.health.is_dead(), (Time.get_ticks_msec() - started) / 1000.0])
	await get_tree().create_timer(0.3).timeout
	await _shot("07_defeat")
	_print_ending(director)
	get_tree().paused = false
	scene.queue_free()
	await get_tree().process_frame


func _load_boss() -> Node:
	RunState.zone_index = RunState.ZONE_SCENES.size() - 1
	var scene: Node = load(BOSS_SCENE).instantiate()
	add_child(scene)
	_point = scene.get_node("CapturePoint") as CapturePoint
	_debug = scene.get_node("HUD/CaptureDebug") as CaptureDebug
	_last_swing_msec = -100000
	await _frames(SETTLE_FRAMES)
	return scene


func _show_debug_bar() -> void:
	var f3 := InputEventAction.new()
	f3.action = "toggle_debug"
	f3.pressed = true
	Input.parse_input_event(f3)
	await _frames(SETTLE_FRAMES)


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


## Presses `hammer` when the swing would land `offset_s` seconds after a hit
## moment (0.0 = on it), to within a frame or two.
func _swing_at(offset_s: float) -> void:
	while Time.get_ticks_msec() - _last_swing_msec < int(Hammer.SWING_COOLDOWN * 1000.0) + 50 \
			or absf(CapturePoint.beat_offset(_point.beat_time()) - offset_s) > TIMING_TOLERANCE:
		await get_tree().process_frame
	_last_swing_msec = Time.get_ticks_msec()
	Input.action_press("hammer")
	await get_tree().process_frame
	Input.action_release("hammer")


func _print_ending(director: ZoneDirector) -> void:
	for child in director.get_children():
		if child.has_signal("restart_pressed"):
			print("ending: %s / %s" % [(child.get_node("Center/Box/Title") as Label).text,
				(child.get_node("Center/Box/Subtitle") as Label).text])
			return
	print("ending: none")


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var path := "%s/%s.png" % [_out_dir, shot_name]
	get_viewport().get_texture().get_image().save_png(path)
	print("== %s -> %s" % [shot_name, path])
	print(_debug.text)
