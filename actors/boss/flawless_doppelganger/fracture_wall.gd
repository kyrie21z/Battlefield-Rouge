class_name FlawlessFractureWall
extends StaticBody3D
var broken := false
var pieces := 0
var wall_size := Vector3(0.5,3.0,5.0)
func _ready() -> void:
	collision_layer = CollisionLayers.WORLD
	collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = wall_size
	shape.shape = box
	add_child(shape)
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = wall_size
	visual.mesh = mesh
	visual.material_override = _material()
	add_child(visual)
func _material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.88,0.91,0.94)
	mat.metallic = 0.3
	mat.roughness = 0.23
	return mat
func fracture(point: Vector3,normal: Vector3) -> void:
	if broken:
		return
	broken = true
	collision_layer = 0
	for child in get_children():
		if child is MeshInstance3D:
			child.hide()
	var debris := Node3D.new()
	get_parent().add_child(debris)
	for i in 12:
		var body := RigidBody3D.new()
		body.collision_layer = 0
		body.collision_mask = CollisionLayers.WORLD
		body.mass = 0.15
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.22,0.45,0.55)
		var visual := MeshInstance3D.new()
		visual.mesh = mesh
		visual.material_override = _material()
		body.add_child(visual)
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = mesh.size
		collision.shape = shape
		body.add_child(collision)
		debris.add_child(body)
		body.global_position = point+Vector3(sin(i*2.4)*0.35,float(i%4)*0.4,cos(i*2.4)*0.5)
		body.linear_velocity = normal*3+Vector3(sin(i),2.5,cos(i))*2
		body.angular_velocity = Vector3(1,sin(i),cos(i))*4
		pieces += 1
	get_tree().create_timer(1.8,false).timeout.connect(debris.queue_free)
