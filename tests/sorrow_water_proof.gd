extends Node3D
## Replays actual room actions. Captures contain no replacement models/materials.
var stage: RealmStage
var realm: SorrowRealm
var player: Player
var camera: Camera3D
var failures := 0

func _ready() -> void:
	stage = preload("res://maps/realms/sorrow_1.tscn").instantiate() as RealmStage
	add_child(stage)
	realm = stage.geometry as SorrowRealm
	player = stage.player
	player.health.invulnerable = true
	for actor in stage.enemies:
		actor.set_physics_process(false)
	stage.hud.hide()
	# Arrange the room's original actors without changing their rigs/materials.
	for i in stage.enemies.size():
		stage.enemies[i].position = Vector3(-4+i*4,0,-3)
	player.position = Vector3(0,0,7)
	await frames(12)
	camera = Camera3D.new()
	add_child(camera)
	camera.environment = realm.mirror_environment
	camera.position = Vector3(10,2.5,-14)
	camera.look_at(Vector3(1,0.7,-2))
	camera.fov = 62
	camera.current = true
	await frames(50)
	realm.set_physics_process(false)
	await capture("mirror-ssr-on")
	realm.mirror_environment.ssr_enabled = false
	await frames(6)
	await capture("mirror-ssr-off")
	realm.mirror_environment.ssr_enabled = true
	realm.set_physics_process(true)
	# A real enemy chases the actual player; it leaves water packets at its feet.
	var walker := stage.enemies[1] as SorrowRealmEnemy
	walker.position = Vector3(1,0,-4)
	walker.set_physics_process(true)
	player.position = Vector3(0,0,5)
	await frames(55)
	walker.set_physics_process(false)
	camera.position = Vector3(5,3.2,-7)
	camera.look_at(Vector3(0,0.15,-0.5))
	await capture("enemy-wake")
	# Return to production first-person rendering for the player's dash/tear shot.
	player.position = Vector3(0,0,9)
	player.aim_at(Vector3(0,0,2))
	await frames(5)
	player.view_camera.current = true
	player.dash.try_dash()
	await frames(10)
	await capture("player-dash")
	player.boons.equip(load("res://buffs/resources/sorrow/sorrow_gun_needles.tres"))
	player.boons.equip(load("res://buffs/resources/sorrow/sorrow_shards.tres"))
	var effect := player.boons.effect_for(load("res://buffs/effects/sorrow_effect.gd")) as SorrowEffect
	effect.spawn_tear(player.global_position+Vector3.FORWARD*2)
	await frames(4)
	player.aim_at(effect.tears.back().global_position)
	player.weapon.try_fire()
	await frames(12)
	await capture("tear-shot")
	if realm.tear_ripple_count < 2 or not effect.tears.is_empty(): failures += 1
	print("SORROW WATER NATIVE: movement=%d shots=%d tears=%d pool=%d checks_failed=%d profile=%s" % [realm.movement_ripple_count,realm.shot_ripple_count,realm.tear_ripple_count,realm._ripples.size(),failures,MetaProgression.save_path()])
	stage.queue_free()
	camera.queue_free()
	await frames(3)
	get_tree().quit(1 if failures else 0)

func frames(count: int) -> void:
	for i in count: await get_tree().physics_frame
func capture(name_value: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var error := get_viewport().get_texture().get_image().save_png("res://docs/proof/issue-169/"+name_value+".png")
	if error != OK: failures += 1
	print("NATIVE CAPTURE %s result=%d frame_ms=%.2f" % [name_value,error,Performance.get_monitor(Performance.TIME_PROCESS)*1000.0])
