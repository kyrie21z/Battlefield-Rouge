class_name SorrowTide
extends Node3D
var source: Enemy
var target: Player
var water_level := 0.14
var radius := 0.0
var hit_player := false
var damage := 14.0
var ring: MeshInstance3D
func _ready() -> void:
	ring = MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.88
	mesh.outer_radius = 1.0
	mesh.rings = 64
	mesh.ring_segments = 6
	ring.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.08,0.42,0.56)
	mat.metallic = 0.6
	mat.roughness = 0.13
	mat.emission_enabled = true
	mat.emission = Color(0.02,0.13,0.2)
	ring.material_override = mat
	ring.position.y = water_level+0.18
	add_child(ring)
func _physics_process(delta: float) -> void:
	if not is_instance_valid(source) or source.health.is_dead():
		queue_free()
		return
	if source.boon_stunned:
		return
	delta *= source.boon_time_scale
	radius += delta*14
	ring.scale = Vector3(maxf(radius,0.05),1,maxf(radius,0.05))
	if is_instance_valid(target) and not hit_player:
		var flat := (target.global_position-global_position)*Vector3(1,0,1)
		var d := flat.length()
		if d <= radius+0.5 and d >= radius-delta*14-1 and target.global_position.y <= water_level+0.3:
			var ray := PhysicsRayQueryParameters3D.create(global_position+Vector3.UP*(water_level+0.4),target.global_position+Vector3.UP*0.4,CollisionLayers.WORLD)
			if get_world_3d().direct_space_state.intersect_ray(ray).is_empty():
				hit_player = true
				var dealt := target.health.apply_damage(damage,Hitbox.BodyPart.BODY,source,{"tag":&"sorrow_tide"})
				if dealt > 0:
					target.apply_external_impulse(flat.normalized()+Vector3.UP*0.1,11,0.35)
	if radius > 50:
		queue_free()
