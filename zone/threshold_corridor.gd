extends Node3D
## Continuous return corridor; the same player and camera survive the climax.
signal duel_requested(player: Player)
signal duel_defeated(crown: Node3D)
signal title_requested(stage: Node)
var player: Player
var reassembly: BodyReassembly
var pause_menu: PauseMenu
var _settings: GameSettings
var reconstituted := false
var duel_started := false
var encounter: Node3D
var ending_sequence: Node3D
var _end_wall: StaticBody3D
func _ready()->void:
	CrystalBurst.prepare(self)
	var world:=WorldEnvironment.new()
	var settings:= preload("res://environments/default_env.tres").duplicate() as Environment
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
	_setup_pause_menu()
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED

func _setup_pause_menu()->void:
	_settings=GameSettings.new()
	if DisplayServer.get_name()!="headless":
		_settings.load_from(GameSettings.settings_path)
	var ui_layer:=CanvasLayer.new()
	ui_layer.layer=30
	add_child(ui_layer)
	pause_menu=PauseMenu.new()
	ui_layer.add_child(pause_menu)
	pause_menu.setup(_settings,player,null)
	pause_menu.configure_exit_button(RunDirector.active,"进度已保存至本房间起点")
	pause_menu.return_to_title_requested.connect(func()->void:title_requested.emit(self))

func _physics_process(_delta:float)->void:
	if not is_instance_valid(player) or player.health.is_dead():return
	if player.position.z < -4 and reassembly.phase==BodyReassembly.Phase.IDLE and player.fragments.shards.size()==4:
		reassembly.begin()
	if reconstituted and not duel_started and player.position.z < -38:
		_start_duel()

func _reconstituted()->void:
	reconstituted=true
	if is_instance_valid(_end_wall):_end_wall.queue_free()
	if RunDirector.active:RunDirector.capture_player(player)

func _start_duel()->void:
	var path:="res://levels/climax/doppelganger_spawn.gd"
	if not ResourceLoader.exists(path):return
	duel_started=true
	var duel:Node3D=load(path).new()
	encounter=duel
	duel.position=Vector3(0,0,-50)
	duel.setup(player)
	duel.defeated.connect(_duel_defeated)
	add_child(duel)
	duel_requested.emit(player)

func _duel_defeated(crown:Node3D)->void:
	RunDirector.final_duel_defeated(self,encounter.boss)
	duel_defeated.emit(crown)
	var path:="res://levels/climax/reconciliation_sequence.gd"
	if not ResourceLoader.exists(path):return
	var ending:Node3D=load(path).new()
	ending_sequence=ending
	if is_instance_valid(pause_menu):
		pause_menu.close()
		pause_menu.configure_exit_button(false)
		pause_menu.process_mode=Node.PROCESS_MODE_DISABLED
	ending.setup(player,crown)
	ending.finished.connect(RunDirector.finish_campaign)
	add_child(ending)

func _on_player_died(_source:Node)->void:
	if RunDirector.active:
		RunDirector.record_death(&"doppelganger")
	var layer:=CanvasLayer.new()
	layer.layer=50
	add_child(layer)
	var backdrop:=ColorRect.new()
	backdrop.color=Color(0.05,0.06,0.08,0.72)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(backdrop)
	var panel:=PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left=-260
	panel.offset_right=260
	panel.offset_top=-90
	panel.offset_bottom=90
	var style:=EditorialStyle.plaque(EditorialStyle.PAPER,EditorialStyle.INK,2,Vector2(8,8),Color(EditorialStyle.INK,0.92),32,28)
	style.border_width_top=6
	style.border_color=EditorialStyle.WARNING
	panel.add_theme_stylebox_override("panel",style)
	layer.add_child(panel)
	var col:=VBoxContainer.new()
	col.alignment=BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation",14)
	panel.add_child(col)
	var title:=EditorialStyle.make_label("心智破碎",28,EditorialStyle.INK,800,false,2)
	title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var label:=EditorialStyle.make_label("按 R 再次出发",18,EditorialStyle.SLATE,700,true,1)
	label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(label)
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
