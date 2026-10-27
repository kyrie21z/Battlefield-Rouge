extends Node
## Plays each melee weapon's swing in a real window and saves screenshots as
## proof for AC-05 (三把近战都能用，剪影可读). Needs a display, so no --headless.
## Run from the project root:
##   godot --path . res://tests/melee_proof.tscn -- --out=<dir>
## The guards are removed first so nothing stands between the camera and the
## weapon, and the rifle viewmodel is hidden because the melee props are what
## this proof is about.
##
## The swing is played back in slow motion (`SLOW`): reading back the frame and
## encoding a PNG costs more than the whole active window at normal speed, so a
## live swing would be over before the camera could take the shot.
##
## Every shot prints where the tip of the blade is on screen, in the same
## normalised coordinates the .tres aims are written in, so the log says whether
## the cut really crossed the frame and the picture shows whether it read.

const WEAPONS := ["knife", "axe", "tachi"]
const SETTLE_FRAMES := 3
## Proof shots are downscaled: they exist to show the silhouette, and the full
## 1280x720 frames are megabytes each.
const SHOT_WIDTH := 800
## Playback speed of the swings while shooting.
const SLOW := 0.08

var _out_dir := "res://docs/proof/melee"
var _player: Player


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out_dir = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(_out_dir)
	await _run()
	Engine.time_scale = 1.0
	get_tree().quit()


func _run() -> void:
	var scene: Node = load("res://maps/zone_1.tscn").instantiate()
	add_child(scene)
	await get_tree().process_frame
	_player = scene.get_node("Player") as Player
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for guard in get_tree().get_nodes_in_group("enemy"):
		(guard as Node).queue_free()
	for i in SETTLE_FRAMES:
		await get_tree().process_frame
	_player.global_rotation = Vector3.ZERO
	_player.weapon.set_drawn(false)

	for i in WEAPONS.size():
		var data: MeleeData = _player.melee.weapons[i]
		_player.melee.select(i)
		await get_tree().process_frame
		print("%s: %.0f dmg, %.1f m, %.0f° arc, wind-up %.2fs, cycle %.2fs, %d target(s)" % [
			data.display_name, data.damage, data.reach, data.arc_degrees,
			data.windup, data.cycle(), data.max_targets])

		# Three frames per weapon, all during the swing: the rest pose sits below
		# the frame on purpose (the weapon is only out while it cuts), so a rest
		# shot would show an empty screen.
		Engine.time_scale = SLOW
		_player.melee.swing_now()
		# End of the wind-up: the tip is on the start of the cut.
		await _wait(data.windup * 0.95)
		await _shot("%02d_%s_windup" % [i * 3 + 1, WEAPONS[i]])
		# Most of the way through the cut.
		await _wait(data.windup * 0.05 + data.active * 0.72)
		await _shot("%02d_%s_cut" % [i * 3 + 2, WEAPONS[i]])
		# The end of the cut, on the signal: it fires with the blade already at
		# its furthest point, so the frame is the pose and not a guess.
		await _player.melee.strike_finished
		await _shot("%02d_%s_strike" % [i * 3 + 3, WEAPONS[i]])
		while _player.melee.is_swinging():
			await get_tree().process_frame
		Engine.time_scale = 1.0
		await _wait(0.2)


func _shot(shot_name: String) -> void:
	# The player puts the rifle back on screen when a swing ends; this proof is
	# about the melee props, so it is kept out of every frame.
	_player.weapon.set_drawn(false)
	await RenderingServer.frame_post_draw
	var tip := _player.melee.tip_screen_position()
	var depth := _player.melee.tip_depth()
	var path := "%s/%s.png" % [_out_dir, shot_name]
	var image := get_viewport().get_texture().get_image()
	var height := roundi(float(SHOT_WIDTH) * image.get_height() / image.get_width())
	image.resize(SHOT_WIDTH, height, Image.INTERPOLATE_LANCZOS)
	image.save_png(path)
	print("== %s -> %s (tip %.2f, %.2f, %.2f m in front)" % [shot_name, path, tip.x, tip.y, depth])


## Waits in game time, so the slow motion playback and the waits stay in step.
func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
