class_name FearReaperVisual
extends SlothVisual
## Reuses our authored torn cloak; the scythe is original procedural geometry.
var scythe: Node3D

func _build() -> void:
	if _built: return
	kind = 0
	super._build()
	FearShatter.prepare_templates()
	_cloth.set_shader_parameter("cloth_color",Color(0.045,0.022,0.075))
	_lining.set_shader_parameter("cloth_color",Color(0.18,0.065,0.29))
	_crystal.set_shader_parameter("base_color",Color(0.10,0.035,0.19))
	_crystal.set_shader_parameter("rim_color",Color(0.65,0.28,0.92))
	_crystal.set_shader_parameter("emission_color",Color(0.32,0.08,0.58))
	_light.albedo_color = Color(0.72,0.40,1.0)
	_light.emission = _light.albedo_color
	var hand := _follow("RightHand","ReaperScythe")
	scythe = Node3D.new()
	scythe.position = Vector3(0.64,1.0,-0.23)
	scythe.rotation.z = PI*0.5
	hand.add_child(scythe)
	var shape := Node3D.new()
	shape.position = -scythe.position
	scythe.add_child(shape)
	_line(shape,Vector3(0.64,0.08,-0.23),Vector3(0.64,2.62,-0.23),0.037,_dark)
	for y in [0.78,1.0,1.22,2.48]:
		_box(shape,Vector3(0.64,y,-0.23),Vector3(0.10,0.05,0.10),_metal)
	var outer := [Vector2(0.64,2.55),Vector2(0.25,2.86),Vector2(-0.35,2.82),Vector2(-0.88,2.43),Vector2(-1.12,1.96)]
	var inner := [Vector2(0.66,2.42),Vector2(0.25,2.58),Vector2(-0.25,2.59),Vector2(-0.70,2.32),Vector2(-1.12,1.96)]
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in 4:
		for side in [-1.0,1.0]:
			var z: float = -0.23+side*0.035
			var points := [Vector3(outer[index].x,outer[index].y,z),Vector3(inner[index].x,inner[index].y,z),Vector3(inner[index+1].x,inner[index+1].y,z),Vector3(outer[index+1].x,outer[index+1].y,z)]
			for vertex in ([0,1,2,0,2,3] if side < 0 else [0,2,1,0,3,2]): tool.add_vertex(points[vertex])
		for curve in [outer,inner]:
			var a: Vector2 = curve[index]
			var b: Vector2 = curve[index+1]
			for vertex in [Vector3(a.x,a.y,-0.265),Vector3(b.x,b.y,-0.265),Vector3(b.x,b.y,-0.195),Vector3(a.x,a.y,-0.265),Vector3(b.x,b.y,-0.195),Vector3(a.x,a.y,-0.195)]: tool.add_vertex(vertex)
	tool.generate_normals()
	var blade := MeshInstance3D.new()
	blade.name = "CurvedScytheBlade"
	blade.mesh = tool.commit()
	blade.material_override = _material(Color(0.20,0.12,0.30),0.65,0.30)
	shape.add_child(blade)
	var edge := PackedVector3Array()
	for point in inner: edge.append(Vector3(point.x,point.y,-0.272))
	_polyline(shape,edge,0.012,_light)
	_box(_outfit,Vector3(0,1.8,-0.19),Vector3(0.22,0.055,0.04),_light)
	FearShatter.prepare_for(self,_crystal)

func set_ritual(progress: float, melee: bool) -> void:
	set_cast(progress)
	if is_instance_valid(scythe): scythe.rotation.z = PI*0.5+sin(progress*PI)*(-0.65 if melee else 0.18)

func die(point := Vector3.INF, direction := Vector3.FORWARD) -> void:
	if _dead: return
	_dead = true
	if animation != null: animation.pause()
	var burst := FearShatter.take(self,_crystal)
	get_parent().get_parent().add_child(burst)
	burst.build(self,global_position+Vector3.UP if point == Vector3.INF else point,direction)
	model.hide()
	_outfit.hide()
