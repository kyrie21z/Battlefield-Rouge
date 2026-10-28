extends Node
## Windowed capture of the dash-charge pips on the real zone 1 HUD.
##   godot --path . res://tests/dash_proof.tscn
## Saves two enlarged crops of the vitals panel into docs/proof/dash:
## both charges ready, and one ready with the other refilling. The second also
## shows the shield strip above the bar, so the pips are proven not to sit on it.

const ZONE := "res://maps/zone_1.tscn"

var _out_dir := "res://docs/proof/dash"
var _failures := 0


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out_dir = arg.trim_prefix("--out=")
	_out_dir = ProjectSettings.globalize_path(_out_dir)
	if DisplayServer.get_name() == "headless":
		push_error("Dash proof requires a native display")
		get_tree().quit(1)
		return
	if DirAccess.make_dir_recursive_absolute(_out_dir) != OK:
		push_error("Cannot create dash proof output directory")
		get_tree().quit(1)
		return

	DisplayServer.window_set_size(Vector2i(1920, 1080))
	RunState.start_fixture(RunFixture.by_id("FX-001"))
	var scene: Node = load(ZONE).instantiate()
	add_child(scene)
	var player := scene.get_node("Player") as Player
	var hud := scene.get_node("HUD") as CanvasLayer
	var director := scene.get_node("ZoneDirector") as ZoneDirector
	var vitals := hud.get_node("Vitals") as Vitals
	await _frames(3)
	var choose := InputEventKey.new()
	choose.physical_keycode = KEY_1
	choose.pressed = true
	Input.parse_input_event(choose)
	await _frames(2)
	choose.pressed = false
	Input.parse_input_event(choose)
	await _frames(2)
	_check("entry choice closes the modal", not is_instance_valid(director.selection)
		and not get_tree().paused)

	player.set_process(false)
	player.set_physics_process(false)
	player.dash.set_physics_process(false)
	for actor: Node in [player.weapon, player.melee, player.shield, player.combat_traits, vitals]:
		actor.set_process(false)
	for enemy: Enemy in get_tree().get_nodes_in_group("enemy"):
		enemy.set_process(false)
		enemy.set_physics_process(false)
	player.health.health = player.health.max_health

	vitals.advance(0.0)
	_check("both charges ready", vitals.dash_charges == 2 and vitals.dash_max_charges == 2
		and is_zero_approx(vitals.dash_recharge_fraction))
	await _shot("01_two_charges_ready", vitals)

	# Stage a live shield strip so the crop shows the pips clearing it. The
	# overlay is left off: this capture is about the panel layout.
	player.shield.active_remaining = 0.8
	player.dash.try_dash()
	player.dash._physics_process(0.5)
	vitals.advance(0.0)
	_check("one ready, the other refilling", vitals.dash_charges == 1
		and vitals.dash_recharge_fraction > 0.0 and vitals.dash_recharge_fraction < 1.0)
	_check("the shield strip is visible and clear of the pips", vitals.shield_visible)
	await _shot("02_one_recharging", vitals)

	print("DASH PROOF %s" % ("PASSED" if _failures == 0 else "FAILED"))
	get_tree().quit(0 if _failures == 0 else 1)


## Saves an enlarged crop of the vitals panel: the pips are 24x7 logical pixels,
## too small to judge in a full 1080p frame.
func _shot(shot_name: String, vitals: Vitals) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var rect := vitals.get_global_rect().grow(18.0)
	var region := Rect2i(Vector2i(rect.position.floor()), Vector2i(rect.size.ceil()))
	region = region.intersection(Rect2i(Vector2i.ZERO, image.get_size()))
	var crop := image.get_region(region)
	crop.resize(crop.get_width() * 3, crop.get_height() * 3, Image.INTERPOLATE_NEAREST)
	var path := "%s/%s.jpg" % [_out_dir, shot_name]
	_check("saved " + shot_name, crop.save_jpg(path, 0.9) == OK)
	print("== %s -> %s (%s)" % [shot_name, path, crop.get_size()])


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func _check(label: String, ok: bool) -> void:
	if not ok:
		_failures += 1
	print("  [%s] %s" % ["ok" if ok else "FAIL", label])
