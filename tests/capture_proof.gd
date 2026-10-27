extends Node
## Plays the AC-01 / AC-03 capture flow in a real window and saves screenshots
## as Proof for Issue #5. Needs a display, so no --headless. Run from the
## project root:
##   godot --path . res://tests/capture_proof.tscn -- --out=<dir>
## The guards are killed by damage rather than shot, and the hammer swings are
## real presses of the `hammer` action, timed against the hit moment.
## Each shot prints the debug bar text, so the log shows the same numbers.

const SETTLE_FRAMES := 3
## Seconds after a strike before the shot, so its flash and text are on screen.
const SHOT_DELAY_AFTER_STRIKE := 0.08
## Seconds either side of the aimed offset; well inside the 150 ms window.
const TIMING_TOLERANCE := 0.03

var _out_dir := "user://proof"
var _point: CapturePoint
var _debug: CaptureDebug
var _strikes: Array = []
var _last_swing_msec := -100000


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out_dir = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(_out_dir)
	await _run()
	get_tree().quit()


func _run() -> void:
	var scene: Node = load("res://maps/zone_1.tscn").instantiate()
	add_child(scene)
	_point = scene.get_node("CapturePoint") as CapturePoint
	_debug = scene.get_node("HUD/CaptureDebug") as CaptureDebug
	var player := scene.get_node("Player") as Player
	var director := scene.get_node("ZoneDirector") as ZoneDirector
	(director.selection.get_node("Center/Box/Choices/Choice1") as Button).pressed.emit()
	_point.struck.connect(func(perfect: bool, offset_ms: float, worth: float):
		_strikes.append([perfect, offset_ms, worth])
		print("struck %s %+d ms +%.0f%%" % ["perfect" if perfect else "ordinary", roundi(offset_ms), worth * 100.0]))
	for i in SETTLE_FRAMES:
		await get_tree().process_frame

	var f3 := InputEventAction.new()
	f3.action = "toggle_debug"
	f3.pressed = true
	Input.parse_input_event(f3)
	for i in SETTLE_FRAMES:
		await get_tree().process_frame
	await _shot("01_clear_guards")

	for guard in get_tree().get_nodes_in_group("enemy"):
		(guard as Enemy).health.apply_damage(9999.0, Hitbox.BodyPart.BODY)
	player.global_position = _point.global_position + Vector3(0.0, 0.0, 3.0)
	for i in 6:
		await get_tree().physics_frame
	await _shot("02_hammer_point_open")

	# Aim for the hit moment, then for the gap between two of them.
	await _swing_at(0.0)
	await get_tree().create_timer(SHOT_DELAY_AFTER_STRIKE).timeout
	await _shot("03_perfect_strike")
	await _swing_at(0.4)
	await get_tree().create_timer(SHOT_DELAY_AFTER_STRIKE).timeout
	await _shot("04_ordinary_strike")

	var swings := 0
	while not _point.is_captured() and swings < 40:
		await _swing_at(0.0)
		swings += 1
	# Step back so the flag is in view, and shoot before the choice screen pauses.
	player.global_position = _point.global_position + Vector3(0.0, 0.0, 7.0)
	await get_tree().create_timer(1.0).timeout
	await _shot("05_flag_planted")
	print("strikes: %d perfect, %d ordinary" % [
		_strikes.filter(func(s: Array): return s[0]).size(),
		_strikes.filter(func(s: Array): return not s[0]).size()])


## Presses `hammer` when the swing would land `offset_s` seconds after a hit
## moment (0.0 = on it, 0.4 = between two of them), to within a frame or two.
func _swing_at(offset_s: float) -> void:
	while Time.get_ticks_msec() - _last_swing_msec < int(Hammer.SWING_COOLDOWN * 1000.0) + 50 \
			or absf(CapturePoint.beat_offset(_point.beat_time()) - offset_s) > TIMING_TOLERANCE:
		await get_tree().process_frame
	_last_swing_msec = Time.get_ticks_msec()
	print("press at offset %+d ms, progress %.0f%%" % [roundi(CapturePoint.beat_offset(_point.beat_time()) * 1000.0), _point.progress * 100.0])
	Input.action_press("hammer")
	await get_tree().process_frame
	Input.action_release("hammer")


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var path := "%s/%s.png" % [_out_dir, shot_name]
	get_viewport().get_texture().get_image().save_png(path)
	print("== %s -> %s" % [shot_name, path])
	print(_debug.text)
