class_name BodyReassembly
extends Node3D
## Physically releases the same authored 56 shards, then reunites their poses.
signal phase_changed(value: int)
signal line_started(index: int, text: String)
signal completed
enum Phase { IDLE, SHATTER, CRIES, REBUILD, STAND, COMPLETE }
const KINTSUGI := preload("res://actors/player/shaders/kintsugi_gold.gdshader")
const COLORS := [Color("e6a23a"),Color("a45cde"),Color("dc4141"),Color("3cc6d9")]
const LINES := ["我想睡觉……我已经很累了。","我好害怕……我也需要被保护。","我好生气！我不想再被推着走！","我好难过……让我哭一次吧。","我不想再变得完美了。我只想做我自己！"]
const CLIPS := ["slumber","fear","spite","sorrow","acceptance"]
var player: Player
var phase := Phase.IDLE
var elapsed := 0.0
var visual_time := 0.0
var pieces: Array[RigidBody3D] = []
var targets: Array[Transform3D] = []
var rebuild_origins: Array[Transform3D] = []
var spoken: Array[int] = []
var seam_materials: Array[ShaderMaterial] = []
var soundscape: ClimaxAudio
var _subtitle: Label
var _camera_start: Transform3D
var _camera_low: Transform3D
var _old_mode: ProcessMode
var _line_index := -1
var _line_left := 0.0
var _lights: Array[OmniLight3D] = []

func _init()->void:
	process_mode=Node.PROCESS_MODE_PAUSABLE

func setup(value: Player)->void:
	player=value

func _ready()->void:
	soundscape=ClimaxAudio.new()
	soundscape.setup(self,player)
	add_child(soundscape)
	var layer:=CanvasLayer.new()
	layer.layer=40
	add_child(layer)
	_subtitle=Label.new()
	_subtitle.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_subtitle.offset_top=-145
	_subtitle.offset_bottom=-55
	_subtitle.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
	_subtitle.add_theme_font_size_override("font_size",30)
	_subtitle.add_theme_color_override("font_outline_color",Color(0.05,0.04,0.03))
	_subtitle.add_theme_constant_override("outline_size",6)
	var font:=SystemFont.new()
	font.font_names=PackedStringArray(["Microsoft YaHei","Noto Sans CJK SC"])
	_subtitle.add_theme_font_override("font",font)
	layer.add_child(_subtitle)

func begin()->bool:
	if phase!=Phase.IDLE or not is_instance_valid(player) or player.health.is_dead():return false
	_old_mode=player.process_mode
	player.cancel_forced_movement()
	player.process_mode=Node.PROCESS_MODE_DISABLED
	player.weapon.hide()
	player.melee.hide()
	_camera_start=player.view_camera.global_transform
	_camera_low=_camera_start
	_camera_low.origin=player.global_position+Vector3(0.45,0.22,1.25)
	_camera_low=_camera_low.looking_at(player.global_position+Vector3(0,0.75,0),Vector3.UP)
	_camera_low.basis=_camera_low.basis*Basis(Vector3.FORWARD,0.23)
	var body:=player.get_node("ShadowBody")
	var fracture:=body.fracture as BodyFracture
	fracture._update_pose()
	for fragment in fracture.fragments:
		var skeleton:=fracture._skeleton
		var delta:=skeleton.get_bone_global_pose(fragment.bone)*skeleton.get_bone_global_rest(fragment.bone).affine_inverse()
		var transform_value:Transform3D=skeleton.global_transform*delta*fragment.rest
		var rigid:=RigidBody3D.new()
		rigid.mass=0.12
		rigid.collision_layer=0
		rigid.collision_mask=CollisionLayers.WORLD
		rigid.linear_damp=0.7
		rigid.angular_damp=1.2
		var mesh:=MeshInstance3D.new()
		mesh.mesh=fragment.node.mesh
		for shape in mesh.get_blend_shape_count():
			mesh.set_blend_shape_value(shape,fragment.node.get_blend_shape_value(shape))
		var material:=ShaderMaterial.new()
		material.shader=KINTSUGI
		material.set_shader_parameter("restored",0.0)
		material.set_shader_parameter("accent",COLORS[pieces.size()%4])
		mesh.material_override=material
		mesh.scale=transform_value.basis.get_scale()
		rigid.add_child(mesh)
		var collision:=CollisionShape3D.new()
		collision.shape=(fragment.original_mesh as Mesh).create_convex_shape()
		collision.scale=mesh.scale
		rigid.add_child(collision)
		add_child(rigid)
		rigid.global_transform=Transform3D(transform_value.basis.orthonormalized(),transform_value.origin)
		var index:=pieces.size()
		rigid.linear_velocity=Vector3(sin(index*2.4)*2.1,1.8+float(index%4)*0.25,cos(index*2.4)*2.1)
		rigid.angular_velocity=Vector3(cos(index),sin(index*1.7),0.5)*3.5
		pieces.append(rigid)
		targets.append(rigid.global_transform)
		seam_materials.append(material)
	body.hide()
	var crown:=player.get_node_or_null("CrownVoiceSystem")
	if crown!=null:
		crown.set_cinematic_hidden(true)
		for sound in crown.find_children("*","AudioStreamPlayer",true,false):sound.stop()
	_set_phase(Phase.SHATTER)
	return true

func _set_phase(value:Phase)->void:
	phase=value
	elapsed=0.0
	phase_changed.emit(phase)

func _process(delta:float)->void:
	if phase==Phase.IDLE:return
	elapsed+=delta
	visual_time+=delta
	var crown:=player.get_node_or_null("CrownVoiceSystem") as CrownVoiceSystem
	for material in seam_materials:
		material.set_shader_parameter("visual_time",visual_time)
		material.set_shader_parameter("reduced_motion",is_instance_valid(crown) and crown.reduced_motion)
	if phase==Phase.COMPLETE:
		_subtitle.modulate.a=1.0-smoothstep(0.0,2.5,elapsed)
		if elapsed>=2.5:_subtitle.text=""
		return
	match phase:
		Phase.SHATTER:
			player.view_camera.global_transform=_camera_start.interpolate_with(_camera_low,smoothstep(0.0,0.85,elapsed))
			if elapsed>=1.1:
				_set_phase(Phase.CRIES)
				_next_line()
		Phase.CRIES:
			_line_left-=delta
			if _line_left<=0.0:_next_line()
		Phase.REBUILD:
			var progress:=smoothstep(0.0,3.2,elapsed)
			for index in pieces.size():
				var target:=targets[index]
				var current:=rebuild_origins[index].interpolate_with(target,progress)
				current.origin.y+=sin(progress*PI)*0.3
				pieces[index].global_transform=current
				seam_materials[index].set_shader_parameter("restored",progress)
			for index in _lights.size():
				_lights[index].position=player.position+Vector3(sin(elapsed*2+index*PI*0.5)*(1-progress),0.2+progress*1.5,cos(elapsed*2+index*PI*0.5)*(1-progress))
			if elapsed>=3.2:
				apply_kintsugi(player)
				player.get_node("ShadowBody").show()
				for piece in pieces:piece.hide()
				_set_phase(Phase.STAND)
		Phase.STAND:
			player.view_camera.global_transform=_camera_low.interpolate_with(_camera_start,smoothstep(0.0,1.6,elapsed))
			if elapsed>=1.6:
				for piece in pieces:piece.queue_free()
				pieces.clear()
				seam_materials.clear()
				for light in _lights:light.queue_free()
				_lights.clear()
				_subtitle.text="不再完美，但终于完整。"
				player.weapon.show()
				player.melee.hide()
				player.process_mode=_old_mode
				player.set_meta("kintsugi_complete",true)
				_set_phase(Phase.COMPLETE)
				completed.emit()

func _next_line()->void:
	_line_index+=1
	if _line_index>=LINES.size():
		for piece in pieces:
			piece.freeze=true
			piece.collision_mask=0
			rebuild_origins.append(piece.global_transform)
		for color in COLORS:
			var light:=OmniLight3D.new()
			light.light_color=color
			light.omni_range=3.0
			light.light_energy=1.2
			add_child(light)
			_lights.append(light)
		_set_phase(Phase.REBUILD)
		return
	_line_left=soundscape.line_duration(_line_index)
	_subtitle.text=LINES[_line_index]
	spoken.append(_line_index)
	line_started.emit(_line_index,LINES[_line_index])

static func apply_kintsugi(value: Player)->void:
	var body:=value.get_node("ShadowBody")
	body.set_fracture_level(0)
	var fracture:=body.fracture as BodyFracture
	var old_flow:=body.get_node_or_null("KintsugiFlow")
	if old_flow!=null:
		body.remove_child(old_flow)
		old_flow.queue_free()
	var flow:=KintsugiFlow.new()
	flow.name="KintsugiFlow"
	flow.crown=value.get_node_or_null("CrownVoiceSystem") as CrownVoiceSystem
	body.add_child(flow)
	var index:=0
	for part in fracture.source_meshes:
		var entry:Dictionary=fracture.source_meshes[part]
		var material:=ShaderMaterial.new()
		material.shader=KINTSUGI
		material.set_shader_parameter("accent",COLORS[index%4])
		entry.node.mesh=entry.seam_mesh
		entry.node.material_override=material
		entry.node.material_overlay=null
		flow.materials.append(material)
		index+=1
	flow._process(0.0)
	value.set_meta("kintsugi_complete",true)
