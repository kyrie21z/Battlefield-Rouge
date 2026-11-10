extends Node3D
## Continuous return corridor; the same player and camera survive the climax.
var player: Player
var reassembly: BodyReassembly
var reconstituted := false
var _end_wall: StaticBody3D
func _ready()->void:
	var world:=WorldEnvironment.new()
	var settings:=Environment.new()
	settings.background_mode=Environment.BG_COLOR
	settings.background_color=Color("eff0ed")
	settings.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color=Color.WHITE
	settings.ambient_light_energy=0.48
	settings.tonemap_mode=Environment.TONE_MAPPER_FILMIC
	settings.glow_intensity=0.28
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
	_end_wall=_block(Vector3(0,3,-35),Vector3(8,6,0.7))
	_block(Vector3(0,-0.3,-50),Vector3(32,0.6,30))
	_block(Vector3(-16.4,3,-50),Vector3(0.8,6,30))
	_block(Vector3(16.4,3,-50),Vector3(0.8,6,30))
	_block(Vector3(0,3,-65),Vector3(32,6,0.6))
	player=preload("res://actors/player/player.tscn").instantiate()
	player.position=Vector3(0,0.1,9)
	add_child(player)
	player.health.died.connect(_on_player_died)
	reassembly=BodyReassembly.new()
	reassembly.setup(player)
	reassembly.completed.connect(_reconstituted)
	add_child(reassembly)
	var text:=Label3D.new()
	text.text="返程\n继续向前"
	text.font_size=70
	text.pixel_size=0.009
	text.position=Vector3(0,2.2,-33.8)
	text.modulate=Color("756a55")
	add_child(text)
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED

func _physics_process(_delta:float)->void:
	if not is_instance_valid(player) or player.health.is_dead():return
	if player.position.z < -4 and reassembly.phase==BodyReassembly.Phase.IDLE and player.fragments.shards.size()==4:
		reassembly.begin()

func _reconstituted()->void:
	reconstituted=true
	if is_instance_valid(_end_wall):_end_wall.queue_free()
	if RunDirector.active:RunDirector.capture_player(player)

func _on_player_died(_source:Node)->void:
	if RunDirector.active:
		RunDirector.record_death(&"threshold")
	var layer:=CanvasLayer.new()
	add_child(layer)
	var label:=Label.new()
	label.text="心智破碎 · 按 R 再次出发"
	label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	label.add_theme_font_size_override("font_size",28)
	layer.add_child(label)
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE

func _block(pos:Vector3,size:Vector3)->StaticBody3D:
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
	return body
