extends Node3D
## Epic 3 destination: a continuous white return corridor, ready for the climax.
var player: Player
func _ready()->void:
	var world:=WorldEnvironment.new()
	var settings:=Environment.new()
	settings.background_mode=Environment.BG_COLOR
	settings.background_color=Color("eff0ed")
	settings.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color=Color.WHITE
	settings.ambient_light_energy=0.7
	settings.glow_enabled=true
	world.environment=settings
	add_child(world)
	var light:=DirectionalLight3D.new()
	light.rotation_degrees=Vector3(-55,-20,0)
	light.light_energy=1.1
	light.shadow_enabled=true
	add_child(light)
	_block(Vector3(0,-0.3,-10),Vector3(8,0.6,50))
	for side in [-1.0,1.0]:
		_block(Vector3(side*4.4,3,-10),Vector3(0.8,6,50))
		for index in 7:
			_block(Vector3(side*3.9,2.5,9-index*6),Vector3(0.25,5,0.3))
	_block(Vector3(0,3,-35),Vector3(8,6,0.7))
	player=preload("res://actors/player/player.tscn").instantiate()
	player.position=Vector3(0,0.1,9)
	add_child(player)
	var text:=Label3D.new()
	text.text="返程\n继续向前"
	text.font_size=70
	text.pixel_size=0.009
	text.position=Vector3(0,2.2,-33.8)
	text.modulate=Color("756a55")
	add_child(text)
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED

func _block(pos:Vector3,size:Vector3)->void:
	var body:=StaticBody3D.new()
	body.position=pos
	body.collision_layer=CollisionLayers.WORLD
	var shape:=CollisionShape3D.new()
	var box:=BoxShape3D.new()
	box.size=size
	shape.shape=box
	body.add_child(shape)
	var visual:=MeshInstance3D.new()
	var mesh:=BoxMesh.new()
	mesh.size=size
	visual.mesh=mesh
	var mat:=StandardMaterial3D.new()
	mat.albedo_color=Color("e3e4df")
	mat.roughness=0.75
	visual.material_override=mat
	body.add_child(visual)
	add_child(body)
