extends "res://tests/realm_player_effects_test.gd"
var shot: WrathProjectile
var impacts: Array = []
func _ready() -> void:
	Events.projectile_registered.connect(_registered)
	for mode in ["original", "body_zero_spread"]:
		for sample in range(1, 17):
			await _sample(mode, sample)
	print("DIAGNOSTIC COMPLETE")
	get_tree().quit()

func _registered(projectile: Node) -> void:
	if projectile is WrathProjectile:
		shot = projectile
		shot.impacted.connect(func(collider: Node, point: Vector3):
			impacts.append({"collider":str(collider.get_path()), "point":str(point)}))

func _sample(mode: String, sample: int) -> void:
	block(Vector3(0,-0.5,0),Vector3(30,1,30))
	block(Vector3(0,2,-5.5),Vector3(10,4,0.5))
	player=preload("res://actors/player/player.tscn").instantiate()
	add_child(player)
	var foe := preload("res://actors/enemy/enemy.tscn").instantiate() as Enemy
	foe.position=Vector3(0,0,-3)
	add_child(foe)
	foe.health.max_health=1000
	foe.health.health=1000
	player.boons.register_enemy(foe)
	player.boons.equip(preload("res://buffs/resources/wrath/wrath_gun_cannon.tres"))
	await frames(5)
	foe.apply_impact(Vector3.FORWARD,10,0.4)
	player.fragments.configure_deprivation([2])
	var head := foe.get_node("Model/CharacterArmature/Skeleton3D/HeadAttach/HeadHitbox") as Hitbox
	var body := foe.get_node("Model/CharacterArmature/Skeleton3D/TorsoAttach/TorsoHitbox") as Hitbox
	if mode == "body_zero_spread":
		player.aim_at(body.global_position)
		player.weapon.data = player.weapon.data.duplicate() as WeaponData
		player.weapon.data.hip_spread = 0.0
		player.weapon.data.ads_spread = 0.0
		player.weapon.data.spread_per_shot = 0.0
		player.weapon._spread = 0.0
	var row := {"mode":mode, "seed":sample, "eye":str(player.eye_position()), "forward":str(player.view_forward()), "foe":str(foe.global_position), "head":str(head.global_position), "body":str(body.global_position), "hp_before":foe.health.health, "spread_before":player.weapon.spread_degrees(), "impact_before":foe._impact_left}
	seed(sample)
	shot = null
	impacts = []
	row.fired = player.weapon.try_fire()
	row.spread_after = player.weapon.spread_degrees()
	row.shot_origin = str(shot.global_position)
	row.shot_direction = str(-shot.global_basis.z)
	row.speed = shot.speed
	var query := PhysicsRayQueryParameters3D.create(shot.global_position, shot.global_position - shot.global_basis.z * 20, CollisionLayers.WORLD | CollisionLayers.HITBOXES, shot.exclude)
	var ray := get_world_3d().direct_space_state.intersect_ray(query)
	row.initial_ray_collider = str(ray.collider.get_path()) if not ray.is_empty() else "none"
	row.initial_ray_point = str(ray.position) if not ray.is_empty() else "none"
	var trace: Array = []
	for frame in range(1,7):
		await frames(1)
		trace.append({"frame":frame,"physics_delta":get_physics_process_delta_time(),"hp":foe.health.health,"impact_left":foe._impact_left,"projectile_alive":is_instance_valid(shot),"position":str(shot.global_position) if is_instance_valid(shot) else "freed","travelled":shot._travelled if is_instance_valid(shot) else -1})
	row.trace = trace
	row.impacts = impacts.duplicate(true)
	print("DIAG " + JSON.stringify(row))
	for child in get_children(): child.free()
	await get_tree().process_frame
