extends Node3D
## A real cast in the same studio as the model turntable. No AI or fake VFX.
var gallery: Node3D
var actors: Array[SlothEnemy] = []
var frames := 0
var shot := ""
var kind := 0
var stage := "locked"
var target: Player


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shot="):
			shot = arg.trim_prefix("--shot=")
		if arg.begins_with("--stage="):
			stage = arg.trim_prefix("--stage=")
		if arg.begins_with("--kind="):
			kind = int(arg.trim_prefix("--kind="))
	gallery = load("res://tools/sloth_enemies/gallery.tscn").instantiate() as Node3D
	add_child(gallery)
	gallery._shot = ""
	gallery._selection = -1
	gallery._update_camera()
	for visual in gallery._specimens:
		visual.hide()
	target = load("res://actors/player/player.tscn").instantiate() as Player
	add_child(target)
	target.position = Vector3(0,0,-3.2)
	target.set_physics_process(false)
	target.set_process_unhandled_input(false)
	target.hide()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	gallery._camera.make_current()
	for i in 3:
		var actor := load("res://actors/enemy/sloth/sloth_enemy.tscn").instantiate() as SlothEnemy
		actor.kind = i
		add_child(actor)
		actor.position = Vector3((1 - i) * 2.7,0.13,0)
		actor.set_physics_process(false)
		actor.setup(target, [])
		actors.append(actor)


func _process(_delta: float) -> void:
	frames += 1
	if frames == 25:
		if stage == "dodge":
			actors[0].evade_chance = 1.0
			var hitbox := actors[0].get_node("TorsoHitbox") as Hitbox
			hitbox.apply_hit_at(1.0, target, hitbox.global_position, Vector3.BACK, true)
		else:
			actors[kind].cast_attack()
	var capture_frame := 68
	if kind == 0:
		capture_frame = 128 if stage == "locked" else (147 if stage == "flight" else (32 if stage == "dodge" else 68))
	if frames == capture_frame and not shot.is_empty():
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(shot)
		print("SLOTH ABILITY: captured real cast/evasion stage: ", stage, "")
		get_tree().quit()
