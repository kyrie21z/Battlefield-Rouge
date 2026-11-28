extends Node3D
## Captures the production boss in the formal Wrath arena on its real attack clock.
const ARENA := preload("res://maps/realms/wrath_boss.tscn")
const OUTPUT := "res://docs/proof/wrath-spire-armor"

var _boss: WrathSpire
var _camera: Camera3D
var _failed := false

func _ready() -> void:
	var room := ARENA.instantiate() as RealmStage
	add_child(room)
	_boss = room.enemies[0] as WrathSpire
	_boss.position = Vector3(0, 0.05, -4)
	_boss.attack_phase = WrathRealmEnemy.Attack.RECOVER
	_boss.attack_left = 20.0
	room.player.position = Vector3(0, 0.05, 9)
	room.player.set_physics_process(false)
	room.player.set_process_input(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	room.hud.hide()

	_camera = Camera3D.new()
	_camera.fov = 46.0
	add_child(_camera)
	_camera.current = true
	_boss.global_position = Vector3(0, 0.05, -4)
	await get_tree().physics_frame
	_view_boss(Vector3(3.7, 3.85, 7.1))
	await _capture("01-idle")

	_boss.begin_move(WrathSpire.Move.VOLLEY)
	await _wait_for_rush()
	await _capture("02-guns")
	_failed = _failed or _boss.spawned_bullets == 0
	print("NATIVE VOLLEY: shells=%d deployment=%.2f" % [
		_boss.spawned_bullets, (_boss.visual as WrathSpireVisual).deployment])

	_boss._clear_bullets()
	_boss.begin_move(WrathSpire.Move.VORTEX)
	await _wait_for_rush()
	for i in 6:
		await get_tree().physics_frame
	_view_boss(Vector3(4.2, 3.55, 7.4))
	await _capture("03-vortex")
	print("NATIVE VORTEX: phase=%d speed=%.1f charge=%.2f" % [
		_boss.attack_phase, _boss.velocity.length(), (_boss.visual as WrathSpireVisual)._charge])
	await get_tree().process_frame
	room.queue_free()
	for i in 6:
		await RenderingServer.frame_post_draw
	get_tree().quit(1 if _failed else 0)

func _view_boss(offset: Vector3) -> void:
	_camera.global_position = _boss.global_position + offset
	_camera.look_at(_boss.global_position + Vector3.UP * 2.20)

func _wait_for_rush() -> void:
	for i in 180:
		if _boss.attack_phase == WrathRealmEnemy.Attack.RUSH:
			return
		await get_tree().physics_frame
	_failed = true

func _capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	var folder := ProjectSettings.globalize_path(OUTPUT)
	DirAccess.make_dir_recursive_absolute(folder)
	var result := get_viewport().get_texture().get_image().save_jpg(folder.path_join(label + ".jpg"), 0.92)
	print("NATIVE CAPTURE %s: %d" % [label, result])
	_failed = _failed or result != OK
