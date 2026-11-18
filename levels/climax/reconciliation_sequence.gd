class_name ReconciliationSequence
extends Node3D
## After the fight, physical pickup becomes a gentle first-person coronation.
signal finished
enum Phase { APPROACH, LIFT, FADE, REALITY, CREDITS }
var player: Player
var crown: Node3D
var phase := Phase.APPROACH
var elapsed := 0.0
var fallen_crown: RigidBody3D
var _start: Transform3D
var _camera_start: Transform3D
var _caption: Label
var _black: ColorRect
var _credits: VBoxContainer
var _ambience: AudioStreamPlayer
var _pickup_origin:=Vector3.ZERO
var reality_room: Node3D
var _body_pose: SkeletonModifier3D
var _body_pose_active := true
var _player_mode := Node.PROCESS_MODE_INHERIT
var _controls_locked := false

func _init()->void:
	process_mode=Node.PROCESS_MODE_PAUSABLE

func setup(value:Player, model:Node3D)->void:
	player=value
	crown=model

func _ready()->void:
	player.weapon.deactivate()
	player.weapon.hide()
	player.melee.deactivate()
	player.melee.hide()
	player.shield.cancel()
	for name_value in ["CrownVoiceSystem","CrownRadiance"]:
		var old:=player.get_node_or_null(name_value)
		if old!=null:
			old.process_mode=Node.PROCESS_MODE_DISABLED
			if old.has_method("set_cinematic_hidden"):old.set_cinematic_hidden(true)
			for sound in old.find_children("*","AudioStreamPlayer",true,false):sound.stop()
			for layer in old.find_children("*","CanvasLayer",true,false):layer.hide()
			if old is Node3D:old.hide()
	if crown.has_method("set_emission_strength"):crown.set_emission_strength(0.02)
	if crown.has_method("set_worn"):crown.set_worn(false)
	_start=crown.global_transform
	fallen_crown=RigidBody3D.new()
	fallen_crown.mass=0.25
	fallen_crown.collision_layer=0
	fallen_crown.collision_mask=CollisionLayers.WORLD
	fallen_crown.linear_damp=2
	fallen_crown.angular_damp=3
	var collision:=CollisionShape3D.new()
	var box:=BoxShape3D.new()
	box.size=Vector3(0.24,0.15,0.28)
	collision.shape=box
	fallen_crown.add_child(collision)
	add_child(fallen_crown)
	fallen_crown.global_position=_start.origin
	crown.reparent(fallen_crown,false)
	crown.transform=Transform3D(Basis.IDENTITY.scaled(_start.basis.get_scale()),Vector3.ZERO)
	fallen_crown.angular_velocity=Vector3(0.3,0.1,0.2)
	_build_ui()
	_ambience=AudioStreamPlayer.new()
	_ambience.stream=_breathing_wind()
	_ambience.volume_db=-35
	add_child(_ambience)
	_ambience.play()

func _build_ui()->void:
	var layer:=CanvasLayer.new()
	layer.layer=55
	add_child(layer)
	_black=ColorRect.new()
	_black.color=Color(0,0,0,0)
	_black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_black.mouse_filter=Control.MOUSE_FILTER_IGNORE
	layer.add_child(_black)
	_caption=Label.new()
	_caption.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_caption.offset_top=-140
	_caption.offset_bottom=-70
	_caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	_caption.add_theme_font_size_override("font_size",28)
	_caption.add_theme_constant_override("outline_size",5)
	_caption.text="走近皇冠 · %s 轻轻拾起"%KeyHint.of("reconcile")
	layer.add_child(_caption)
	_credits=VBoxContainer.new()
	_credits.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_credits.offset_left=-240
	_credits.offset_right=240
	_credits.offset_top=-130
	_credits.offset_bottom=180
	_credits.add_theme_constant_override("separation",24)
	_credits.hide()
	layer.add_child(_credits)
	for text_value in ["MIND FREAK","不再完美，但终于完整。","创作与开发\nkyrie21z · KADG777 · MRTODAYY\n引擎 · Godot\n谢谢你，愿意接纳自己。"]:
		var label:=Label.new()
		label.text=text_value
		label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size",42 if text_value=="MIND FREAK" else 28)
		_credits.add_child(label)
	var button:=Button.new()
	button.text="返回标题"
	button.pressed.connect(func():get_tree().change_scene_to_file("res://ui/ending_menu.tscn"))
	_credits.add_child(button)

func _unhandled_input(event:InputEvent)->void:
	if event.is_action_pressed("reconcile") and try_pickup():get_viewport().set_input_as_handled()

func try_pickup()->bool:
	if phase!=Phase.APPROACH or get_tree().paused or player.health.is_dead():return false
	if player.global_position.distance_to(fallen_crown.global_position)>1.7:return false
	var ray:=PhysicsRayQueryParameters3D.create(player.eye_position(),fallen_crown.global_position+Vector3.UP*0.15,CollisionLayers.WORLD)
	if not get_world_3d().direct_space_state.intersect_ray(ray).is_empty():return false
	phase=Phase.LIFT
	elapsed=0
	fallen_crown.freeze=true
	fallen_crown.collision_mask=0
	_pickup_origin=fallen_crown.global_position
	_camera_start=player.view_camera.global_transform
	player.cancel_forced_movement()
	_player_mode=player.process_mode
	_controls_locked=true
	# Skeleton modifiers run after animation, including when the Player's own
	# processing is disabled. Suspend the weapon pose while carrying the crown.
	_body_pose=player.get_node("ShadowBody")._skeleton.get_node("BodyPose") as SkeletonModifier3D
	_body_pose_active=_body_pose.active
	_body_pose.active=false
	player.process_mode=Node.PROCESS_MODE_DISABLED
	_caption.text="我们不必再证明什么。"
	return true

func _physics_process(_delta:float)->void:
	if phase==Phase.APPROACH and player.global_position.distance_to(fallen_crown.global_position)<1.05:
		try_pickup()

func _process(delta:float)->void:
	elapsed+=delta
	_ambience.volume_db=move_toward(_ambience.volume_db,-16,delta*4)
	if phase==Phase.LIFT:
		var progress:=smoothstep(0.0,3.6,elapsed)
		# Keep the shared grip inside both authored arm chains' physical reach.
		var held:=player.global_transform*Vector3(0,1.3,-0.30)
		var worn:=CrownModel.worn_transform(player._head)
		fallen_crown.global_position=_pickup_origin.lerp(held,smoothstep(0.0,0.5,progress)).lerp(worn.origin,smoothstep(0.5,1.0,progress))
		fallen_crown.rotation=fallen_crown.rotation.lerp(Vector3.ZERO,delta*4)
		_pose_hands(fallen_crown.global_position)
		var camera_transform:=_camera_start
		camera_transform.origin.y-=sin(progress*PI)*0.22
		camera_transform.basis=camera_transform.basis*Basis(Vector3.RIGHT,-sin(progress*PI)*0.22)
		player.view_camera.global_transform=camera_transform
		if elapsed>=3.6:
			if crown.has_method("set_worn"):crown.set_worn(true)
			crown.reparent(player,true)
			crown.global_transform=worn
			fallen_crown.queue_free()
			phase=Phase.FADE
			elapsed=0
	elif phase==Phase.FADE:
		_black.color.a=smoothstep(0.0,2.0,elapsed)
		if elapsed>=2.2:
			_build_reality()
			phase=Phase.REALITY
			elapsed=0
			_caption.text="深呼吸。你仍然在这里。"
	elif phase==Phase.REALITY:
		_black.color.a=1.0-smoothstep(0.0,2.5,elapsed)
		player.view_camera.position.y=sin(elapsed*1.2)*0.005
		if elapsed>=7:
			phase=Phase.CREDITS
			_caption.hide()
			_black.color=Color(0.03,0.04,0.05,1.0)
			_credits.show()
			Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
			finished.emit()

func _pose_hands(point:Vector3)->void:
	var body:=player.get_node("ShadowBody")
	var skeleton:Skeleton3D=body._skeleton
	var inverse:=skeleton.global_transform.affine_inverse()
	for side in ["Left","Right"]:
		var sign_x:float=-1 if side=="Left" else 1
		var target:Vector3=inverse*(point+player.global_basis.x*sign_x*0.105-Vector3.UP*0.025)
		var hand_basis:Basis=skeleton.global_basis.orthonormalized().inverse()*player.global_basis*body._hand_basis[side]
		body._solve_arm(side,target,hand_basis,Vector3(sign_x*0.5,-0.5,0.1))
	skeleton.force_update_all_bone_transforms()

func _exit_tree()->void:
	if is_instance_valid(_body_pose):
		_body_pose.active=_body_pose_active
	if _controls_locked and is_instance_valid(player):
		player.process_mode=_player_mode

func _build_reality()->void:
	reality_room=Node3D.new()
	reality_room.position=Vector3(100,0,0)
	add_child(reality_room)
	_reality_box(Vector3(0,-0.2,0),Vector3(12,0.4,16),Color("a7aa9f"))
	_reality_box(Vector3(0,3,-7),Vector3(12,6,0.3),Color("dad5c9"))
	_reality_box(Vector3(0,3,-6.8),Vector3(5.6,2.5,0.08),Color("e5e1d6"))
	for side in [-1.0,1.0]:
		_reality_box(Vector3(side*6,3,0),Vector3(0.2,6,16),Color("c2c7c0"))
		for z in [-3.0,0.0,3.0]:
			_reality_box(Vector3(side*3.5,0.5,z),Vector3(3.2,0.14,0.8),Color("6d4f37"))
			_reality_box(Vector3(side*3.5,0.94,z+0.36),Vector3(3.2,0.8,0.1),Color("826249"))
			for dx in [-1.2,1.2]:
				_reality_box(Vector3(side*3.5+dx,0.23,z),Vector3(0.1,0.46,0.5),Color("484b49"))
	_reality_box(Vector3(0,0.5,4.7),Vector3(3.4,0.15,0.75),Color("6d4f37"))
	_reality_box(Vector3(0,0.7,-2.5),Vector3(1.6,1.4,0.8),Color("76523b"))
	_reality_box(Vector3(0,1.5,-2.5),Vector3(1.9,0.1,1.0),Color("946b49"))
	_reality_box(Vector3(0.5,1.72,-2.5),Vector3(0.025,0.38,0.025),Color("30383a"))
	_reality_box(Vector3(0.5,1.9,-2.55),Vector3(0.08,0.055,0.18),Color("30383a"))
	var text:=Label3D.new()
	text.text="学术交流\n请慢慢来"
	text.font_size=65
	text.pixel_size=0.008
	text.position=Vector3(0,2.6,-6.7)
	text.modulate=Color("353f47")
	reality_room.add_child(text)
	player.global_position=Vector3(100,0,4)
	player.get_node("ShadowBody").hide()
	crown.hide()
	player._head.transform=Transform3D(Basis.IDENTITY,Vector3(0,1.25,0))
	player.view_camera.transform=Transform3D.IDENTITY

func _reality_box(point:Vector3,size:Vector3,color:Color)->void:
	var mesh:=MeshInstance3D.new()
	var box:=BoxMesh.new()
	box.size=size
	mesh.mesh=box
	mesh.position=point
	var material:=StandardMaterial3D.new()
	material.albedo_color=color
	material.roughness=0.85
	mesh.material_override=material
	reality_room.add_child(mesh)

static func _breathing_wind()->AudioStreamWAV:
	var rate:=22050
	var count:=rate*8
	var bytes:=PackedByteArray()
	bytes.resize(count*2)
	var rng:=RandomNumberGenerator.new()
	rng.seed=151
	var filtered:=0.0
	for index in count:
		var t:=float(index)/rate
		filtered=lerpf(filtered,rng.randf_range(-1,1),0.06)
		var breath:=pow(maxf(0,sin(t*TAU/4.0)),1.4)
		bytes.encode_s16(index*2,int(clampf(filtered*(0.08+breath*0.42),-1,1)*32767))
	var stream:=AudioStreamWAV.new()
	stream.format=AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate=rate
	stream.data=bytes
	stream.loop_mode=AudioStreamWAV.LOOP_FORWARD
	stream.loop_end=count
	return stream
