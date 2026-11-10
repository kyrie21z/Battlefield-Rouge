class_name WrathSpike
extends Node3D
## Piercing crystal shard: sweeps WORLD/Hitbox each frame and excludes every
## Hitbox belonging to an already pierced Health, so body parts cannot double hit.
var manager: BoonManager
var source: Node
var boon_time_scale := 1.0
var direction := Vector3.FORWARD
var speed := 30.0
var damage := 18.0
var proc_depth := 2
var _distance := 0.0
var _exclude: Array[RID] = []
var _hit: Dictionary = {}

static func launch(owner_manager: BoonManager, point: Vector3, forward: Vector3, depth: int) -> WrathSpike:
	var spike := WrathSpike.new()
	spike.manager = owner_manager
	spike.source = owner_manager.player
	spike.direction = forward.normalized()
	spike.proc_depth = depth
	owner_manager.player.get_parent().add_child(spike)
	spike.global_position = point
	spike.look_at(point + spike.direction, Vector3.UP)
	Events.projectile_registered.emit(spike)
	return spike

func _ready() -> void:
	var visual := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.0
	mesh.bottom_radius = 0.09
	mesh.height = 0.55
	mesh.radial_segments = 5
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.045, 0.012, 0.012)
	material.emission_enabled = true
	material.emission = Color(0.9, 0.06, 0.02)
	material.emission_energy_multiplier = 0.7
	material.roughness = 0.25
	mesh.material = material
	visual.mesh = mesh
	visual.rotation.x = PI * 0.5
	add_child(visual)

func _physics_process(delta: float) -> void:
	if not is_instance_valid(manager):
		queue_free()
		return
	if boon_time_scale <= 0.0:
		return
	var from := global_position
	var to := from + direction * speed * delta * boon_time_scale
	var space := get_world_3d().direct_space_state
	for _pass in 12:
		var query := PhysicsRayQueryParameters3D.create(from, to, CollisionLayers.WORLD | CollisionLayers.HITBOXES, _exclude)
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			break
		if not hit.collider is Hitbox:
			queue_free()
			return
		var box := hit.collider as Hitbox
		_exclude.append(box.get_rid())
		var health := box.health
		if health == null or _hit.has(health.get_instance_id()):
			continue
		_hit[health.get_instance_id()] = true
		if manager.is_enemy(health.get_parent()):
			manager.apply_damage(health.get_parent(), damage, {"tag": &"wrath_spike", "proc_depth": proc_depth,
				"position": hit.position, "direction": direction})
			manager.feedback(hit.position, WrathBoons.COLOR, 0.18)
	global_position = to
	_distance += from.distance_to(to)
	if _distance > 12.0:
		queue_free()
