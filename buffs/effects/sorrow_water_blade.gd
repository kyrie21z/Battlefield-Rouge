class_name SorrowWaterBlade
extends Node3D
## Visible, swept, piercing homing crystal. One hit per Health; WORLD blocks it.
var manager: BoonManager
var source: Node
var damage := 14.0
var speed := 22.0
var remaining := 3.0
var boon_time_scale := 1.0
var _hits: Dictionary = {}
var _direction := Vector3.FORWARD


func _ready() -> void:
	var crystal := MeshInstance3D.new()
	crystal.mesh = TearCrystal._crystal_mesh()
	crystal.scale = Vector3(0.7, 1.8, 0.7)
	crystal.rotation.x = PI * 0.5
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = ErosionStatus.CYAN
	material.emission_enabled = true
	material.emission = ErosionStatus.CYAN
	material.emission_energy_multiplier = 1.4
	crystal.material_override = material
	add_child(crystal)
	manager.register_projectile(self)


func _physics_process(delta: float) -> void:
	if manager == null or not is_instance_valid(manager) or manager.health.is_dead():
		queue_free()
		return
	delta *= boon_time_scale
	remaining -= delta
	if remaining <= 0.0:
		queue_free()
		return
	var best: Node3D
	var nearest := INF
	for enemy: Node3D in manager.enemies():
		var health := manager.health_of(enemy)
		if not manager.is_enemy(enemy) or health.is_dead() or _hits.has(health.get_instance_id()):
			continue
		var point := enemy.global_position + Vector3.UP
		var distance := global_position.distance_squared_to(point)
		if distance < nearest and manager.line_clear(global_position, point):
			nearest = distance
			best = enemy
	if is_instance_valid(best):
		_direction = (best.global_position + Vector3.UP - global_position).normalized()
	var from := global_position
	var end := from + _direction * speed * delta
	var wall := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, end, CollisionLayers.WORLD))
	if not wall.is_empty():
		end = wall.position
	for enemy: Node3D in manager.enemies():
		var health := manager.health_of(enemy)
		if not manager.is_enemy(enemy) or health.is_dead() or _hits.has(health.get_instance_id()):
			continue
		var point := enemy.global_position + Vector3.UP
		if Geometry3D.get_closest_point_to_segment(point, from, end).distance_to(point) <= 0.55 and manager.line_clear(from, point):
			_hits[health.get_instance_id()] = true
			manager.apply_damage(enemy, damage, {"tag": &"sorrow_water_blade", "proc_depth": 2})
	global_position = end
	if _direction.length_squared() > 0.001:
		look_at(end + _direction, Vector3.UP if absf(_direction.y) < 0.99 else Vector3.FORWARD)
	if not wall.is_empty():
		queue_free()
