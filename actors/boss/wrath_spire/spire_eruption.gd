class_name SpireEruption
extends Node3D
## A locked ground warning, then one physical-radius crystal eruption.
var source: WrathSpire
var target: CharacterBody3D
var warning_seconds := 1.2
var radius := 1.6
var damage := 18.0
var elapsed := 0.0
var released := false
var hit_player := false
var marker: MeshInstance3D
var marker_material: StandardMaterial3D
var spikes: Node3D

func _ready() -> void:
	marker = MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = radius-0.12
	ring.outer_radius = radius
	ring.rings = 40
	ring.ring_segments = 4
	marker.mesh = ring
	marker.position.y = 0.05
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(1.0,0.13,0.025)
	material.emission_enabled = true
	material.emission = material.albedo_color
	material.emission_energy_multiplier = 0.6
	marker_material = material
	marker.material_override = material
	marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(marker)
	marker.visible = is_instance_valid(source) and source.warnings_enabled
	spikes = Node3D.new()
	for index in 5:
		var spike := MeshInstance3D.new()
		var mesh := PrismMesh.new()
		mesh.size = Vector3(0.35,2.2+index*0.12,0.45)
		spike.mesh = mesh
		spike.material_override = material
		var angle := index*TAU/5.0
		spike.position = Vector3(cos(angle)*0.6,mesh.size.y*0.5,sin(angle)*0.6)
		spikes.add_child(spike)
	add_child(spikes)
	spikes.hide()

func _physics_process(delta: float) -> void:
	if not is_instance_valid(source) or source.health.is_dead():
		queue_free()
		return
	if source.boon_stunned or source.boon_time_scale <= 0:
		return
	elapsed += delta*source.boon_time_scale*source.effective_attack_scale()
	marker.visible = source.warnings_enabled and not released
	if not released:
		var progress := clampf(elapsed/maxf(warning_seconds,0.001),0.0,1.0)
		var pulse := 0.5+0.5*sin(elapsed*(12.0+28.0*progress))
		marker_material.emission_energy_multiplier = 0.8+progress*2.4+pulse*(0.6+progress)
		marker.scale = Vector3.ONE*(1.0+0.06*pulse)
	if not released and elapsed >= warning_seconds:
		released = true
		marker_material.emission_energy_multiplier = 3.0
		marker.hide()
		spikes.show()
		try_hit()
	if released:
		spikes.scale.y = maxf(0.0,1.0-(elapsed-warning_seconds)/0.55)
	if elapsed >= warning_seconds+0.55:
		queue_free()

func try_hit() -> void:
	if hit_player or not is_instance_valid(target):
		return
	var offset := target.global_position-global_position
	if Vector2(offset.x,offset.z).length() > radius or offset.y > 0.45 or offset.y < -0.5:
		return
	var ray := PhysicsRayQueryParameters3D.create(global_position+Vector3.UP*0.3,target.global_position+Vector3.UP*0.8,CollisionLayers.WORLD)
	if not get_world_3d().direct_space_state.intersect_ray(ray).is_empty():
		return
	var health := target.get_node_or_null("Health") as Health
	if health != null:
		hit_player = true
		health.apply_damage(damage,Hitbox.BodyPart.BODY,source,{"tag":&"spire_eruption"})
