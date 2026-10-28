extends Node
## Screenshots for the character models: the boss in the Hazmat model among the
## small enemies, and the player's shadow-only Soldier body standing and running.
## Needs a display, so no --headless. Run from the project root:
##   godot --path . res://tests/character_models_proof.tscn -- --out=<dir>

const BOSS_SCENE := "res://maps/boss.tscn"
## Straight in front of the boss, 16 m away, as in boss_proof.gd.
const SHOOTING_SPOT := Vector3(0.0, 0.0, -3.0)

var _out_dir := "user://proof"


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out_dir = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(_out_dir)
	RunState.zone_index = RunState.ZONE_SCENES.size() - 1
	var scene: Node = load(BOSS_SCENE).instantiate()
	add_child(scene)
	get_tree().paused = false
	await _frames(3)
	# Only their AI stops, so they stand still for the shot.
	for enemy: Enemy in get_tree().get_nodes_in_group("enemy"):
		enemy.set_process(false)
		enemy.set_physics_process(false)
	var player := scene.get_node("Player") as Player
	var boss := scene.get_node("Boss") as Enemy

	player.global_position = SHOOTING_SPOT
	await _frames(2)
	player.aim_at(boss.global_position + Vector3(0.0, 1.6, 0.0))
	await _frames(10)
	await _shot("01_boss_hazmat")

	# The sun shines towards -X -Z, so the shadow falls there.
	player.global_position = Vector3(6.0, 0.0, 4.0)
	await _frames(2)
	player.aim_at(player.global_position + Vector3(-1.4, 0.0, -1.4))
	await _frames(10)
	await _shot("02_player_shadow_idle")
	player.set_physics_process(false)
	player.velocity = Vector3(0.0, 0.0, -4.4)
	await get_tree().create_timer(0.6).timeout
	await _shot("03_player_shadow_run")
	print("boss health %d, headshot x%.2f" % [boss.health.max_health, boss.health.headshot_multiplier])
	get_tree().quit()


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var path := "%s/%s.png" % [_out_dir, shot_name]
	get_viewport().get_texture().get_image().save_png(path)
	print("== %s -> %s" % [shot_name, path])
