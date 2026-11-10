class_name WrathShockwave
extends Node3D
## Expanding ring/fan uses actual player distance, jump height and WORLD occlusion.
var source: Enemy
var target: CharacterBody3D
var max_radius := 18.0
var speed := 15.0
var damage := 16.0
var impulse := 9.0
var half_angle := PI
var direction := Vector3.FORWARD
var elapsed := 0.0
var radius := 0.0
var hit_player := false
var ring: MeshInstance3D

func _ready() -> void:
	ring = MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.85
	mesh.outer_radius = 1.0
	mesh.rings = 48
	mesh.ring_segments = 4
	ring.mesh = mesh
	if half_angle < PI:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for i in 32:
			var a := lerpf(-half_angle, half_angle, float(i) / 32.0)
			var b := lerpf(-half_angle, half_angle, float(i + 1) / 32.0)
			var outer_a := Vector3(sin(a), 0, -cos(a))
			var outer_b := Vector3(sin(b), 0, -cos(b))
			for v in [outer_a * 0.85, outer_a, outer_b, outer_a * 0.85, outer_b, outer_b * 0.85]:
				st.add_vertex(v)
		st.generate_normals()
		ring.mesh = st.commit()
		ring.rotation.y = atan2(-direction.x, -direction.z)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.15, 0.025)
	mat.emission_enabled = true
	mat.emission = mat.albedo_color
	mat.emission_energy_multiplier = 2.2
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	ring.material_override = mat
	ring.position.y = 0.22
	add_child(ring)

func _physics_process(delta: float) -> void:
	if not is_instance_valid(source) or source.health.is_dead():
		queue_free()
		return
	delta *= source.boon_time_scale
	if delta <= 0.0 or source.boon_stunned:
		return
	elapsed += delta
	radius = elapsed * speed
	ring.scale = Vector3(maxf(radius, 0.05), 1.0, maxf(radius, 0.05))
	if is_instance_valid(target) and not hit_player:
		var offset := target.global_position - global_position
		var flat := Vector3(offset.x, 0, offset.z)
		var distance := flat.length()
		var angle_ok := half_angle >= PI or flat.normalized().dot(direction) >= cos(half_angle)
		if distance <= radius + 0.5 and distance >= radius - speed * delta - 0.8 and offset.y < 0.7 and angle_ok:
			var ray := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 0.4, target.global_position + Vector3.UP * 0.4, CollisionLayers.WORLD)
			if get_world_3d().direct_space_state.intersect_ray(ray).is_empty():
				hit_player = true
				var hp := target.get_node_or_null("Health") as Health
				var dealt := 0.0
				if hp != null:
					dealt = hp.apply_damage(damage, Hitbox.BodyPart.BODY, source, {"tag": &"wrath_wave"})
				if dealt > 0.0 and target.has_method("apply_external_impulse"):
					target.call("apply_external_impulse", flat.normalized() + Vector3.UP * 0.35, impulse, 0.3)
	if radius > max_radius:
		queue_free()
