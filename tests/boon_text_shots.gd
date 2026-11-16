extends Node
## Captures the two new pieces of UI: the one-time realm mechanic card and a
## three-card offer rendered with the rewritten descriptions. Saves PNGs into
## docs/proof/boon-text/ and quits, so it can run without a human at the keyboard.

const OUT := "res://docs/proof/boon-text"
const SHOTS := [
	{"name": "intro-sloth", "kind": "intro", "realm": 0},
	{"name": "intro-fear", "kind": "intro", "realm": 1},
	{"name": "intro-wrath", "kind": "intro", "realm": 2},
	{"name": "intro-sorrow", "kind": "intro", "realm": 3},
	{"name": "cards-sloth", "kind": "cards", "realm": 0},
]

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	await _frames(2)
	for shot: Dictionary in SHOTS:
		await _capture(shot)
	print("BOON TEXT SHOTS: %d saved" % SHOTS.size())
	get_tree().quit()


func _capture(shot: Dictionary) -> void:
	var holder := Control.new()
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(holder)
	if shot["kind"] == "intro":
		var panel := RealmIntro.new()
		holder.add_child(panel)
		panel.setup(shot["realm"])
	else:
		var stage := preload("res://maps/realms/sloth_1.tscn").instantiate() as RealmStage
		holder.add_child(stage)
		await _frames(4)
		var picker := preload("res://ui/boon_picker/boon_picker.tscn").instantiate() as BoonPicker
		holder.add_child(picker)
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		var offer := BoonOffers.pick(stage.player.boons, rng, 3, shot["realm"], [], false)
		picker.setup(offer, stage.player.boons, "%s · 门扉馈赠" % RealmStage.TITLES[shot["realm"]], 0)
	await _frames(8)
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := "%s/%s.png" % [OUT, shot["name"]]
	img.save_png(ProjectSettings.globalize_path(path))
	print("SAVED ", ProjectSettings.globalize_path(path))
	holder.queue_free()
	get_tree().paused = false
	await _frames(2)


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame
