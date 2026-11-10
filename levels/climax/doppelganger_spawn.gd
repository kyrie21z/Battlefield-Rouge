class_name DoppelgangerSpawn
extends Node3D
signal defeated(crown: Node3D)
signal combat_started
const CROWN_SCRIPT := preload("res://actors/crown/crown_model.gd")
enum Phase { DROP, RANT, RISE, PRINT, SEAL, COMBAT, ANNIHILATE, COMPLETE }
var player: Player
var crown: Node3D
var boss: FlawlessDoppelganger
var phase := Phase.DROP
var phase_elapsed := 0.0
var carrier: RigidBody3D
var walls: Array[FlawlessFractureWall] = []
var voice: AudioStreamPlayer3D
var flash: ColorRect
var label: Label
var print_ring: MeshInstance3D
var nova: MeshInstance3D
var hud: ClimaxCombatHUD
var _player_mode := Node.PROCESS_MODE_INHERIT
var _controls_locked := false
var _rise_from := Vector3.ZERO
var _seal_from := Vector3.ZERO
var _seal_rotation := Quaternion.IDENTITY
var _complete_emitted := false

func _init() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
func setup(value: Player) -> void:
	player = value
func _ready() -> void:
	assert(player != null,"DoppelgangerSpawn requires setup(player) before add_child")
	_lock_player()
	var direction := global_position-player.global_position
	player.rotation.y = atan2(-direction.x,-direction.z)
	player._pitch = 0.0
	player._head.rotation.x = 0.0
	_build_walls()
	boss = preload("res://actors/boss/flawless_doppelganger/flawless_doppelganger.tscn").instantiate() as FlawlessDoppelganger
	boss.rotation.y = PI
	add_child(boss)
	boss.setup(player,[])
	boss.visual.shader_origin = global_position.y
	boss.visual.set_print_progress(0)
	player.boons.register_enemy(boss)
	boss.defeated.connect(_on_boss_defeated)
	crown = CROWN_SCRIPT.new() as Node3D
	carrier = _carrier()
	carrier.position = Vector3(0,4.4,0)
	carrier.add_child(crown)
	voice = AudioStreamPlayer3D.new()
	voice.stream = preload("res://assets/audio/climax/crown_breakdown.wav")
	voice.volume_db = -2
	voice.unit_size = 12
	voice.max_distance = 45
	add_child(voice)
	_build_effects()
	hud = ClimaxCombatHUD.new()
	hud.setup(player)
	add_child(hud)
func _carrier() -> RigidBody3D:
	var body := RigidBody3D.new()
	body.mass = 0.4
	body.collision_layer = 0
	body.collision_mask = CollisionLayers.WORLD
	body.contact_monitor = true
	body.max_contacts_reported = 4
	body.lock_rotation = true
	var collision := CollisionShape3D.new()
	var band := CylinderShape3D.new()
	band.radius = 0.125
	band.height = 0.085
	collision.shape = band
	body.add_child(collision)
	add_child(body)
	return body
func _build_walls() -> void:
	for side in [-1.0,1.0]:
		for z in [-7.0,6.0]:
			var wall := FlawlessFractureWall.new()
			wall.position = Vector3(side*13.5,1.5,z)
			add_child(wall)
			walls.append(wall)
	for z in [-13.0,13.0]:
		var wall := FlawlessFractureWall.new()
		wall.wall_size = Vector3(7.0,3.0,0.5)
		wall.position = Vector3(0,1.5,z)
		add_child(wall)
		walls.append(wall)
func _build_effects() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 45
	add_child(layer)
	flash = ColorRect.new()
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash.color = Color(1,1,1,0)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(flash)
	label = Label.new()
	label.position = Vector2(28,26)
	label.add_theme_font_size_override("font_size",26)
	label.add_theme_color_override("font_shadow_color",Color(0,0,0,0.95))
	label.add_theme_constant_override("shadow_offset_x",2)
	label.add_theme_constant_override("shadow_offset_y",2)
	layer.add_child(label)
	print_ring = MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.85
	ring.outer_radius = 1.05
	ring.rings = 64
	ring.ring_segments = 4
	print_ring.mesh = ring
	var material := StandardMaterial3D.new()
	material.albedo_color = Color.WHITE
	material.emission_enabled = true
	material.emission = Color.WHITE
	material.emission_energy_multiplier = 4
	print_ring.material_override = material
	print_ring.hide()
	add_child(print_ring)
	nova = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1
	nova.mesh = sphere
	var nova_mat := StandardMaterial3D.new()
	nova_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	nova_mat.albedo_color = Color(1,1,1,0.7)
	nova_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	nova.material_override = nova_mat
	nova.position.y = 1.2
	nova.hide()
	add_child(nova)
func _physics_process(delta: float) -> void:
	phase_elapsed += delta
	if is_instance_valid(crown):
		voice.global_position = crown.global_position
	if phase == Phase.DROP:
		label.text = ""
		if carrier.get_contact_count()>0:
			carrier.freeze = true
			phase = Phase.RANT
			phase_elapsed = 0
			voice.play()
	elif phase == Phase.RANT:
		label.text = "皇冠：你简直无药可救了！！"
		if phase_elapsed >= voice.stream.get_length()+0.3:
			_rise_from = carrier.position
			phase = Phase.RISE
			phase_elapsed = 0
	elif phase == Phase.RISE:
		carrier.position = _rise_from.lerp(Vector3(0,3.1,0),smoothstep(0,0.9,phase_elapsed))
		if phase_elapsed >= 0.9:
			phase = Phase.PRINT
			phase_elapsed = 0
			print_ring.show()
			crown.call("set_emission_strength",5.0)
	elif phase == Phase.PRINT:
		label.text = "完美替身"
		var amount := clampf(phase_elapsed/2.6,0,1)
		boss.visual.set_print_progress(amount)
		print_ring.position.y = lerpf(2.5,0.0,amount)
		flash.color.a = maxf(0.0,0.85-phase_elapsed*1.4)
		if amount >= 1:
			print_ring.hide()
			crown.reparent(boss.visual.crown_anchor,true)
			_seal_from = crown.position
			_seal_rotation = crown.quaternion
			crown.call("set_worn",true)
			carrier.queue_free()
			carrier = null
			phase = Phase.SEAL
			phase_elapsed = 0
	elif phase == Phase.SEAL:
		var seal_progress := smoothstep(0,0.6,phase_elapsed)
		crown.position = _seal_from.lerp(Vector3.ZERO,seal_progress)
		# keep_global preserves the hovering pose; finish in the real head axes.
		crown.quaternion = _seal_rotation.slerp(Quaternion.IDENTITY,seal_progress)
		crown.scale = boss.visual.crown_fit
		if phase_elapsed >= 0.6:
			crown.call("set_emission_strength",0.3)
			boss.set_combat_active(true)
			phase = Phase.COMBAT
			phase_elapsed = 0
			_unlock_player()
			hud.set_combat_visible(true)
			combat_started.emit()
	elif phase == Phase.COMBAT:
		var cooldown := player.fragments.resonance_cooldown
		label.text = "完美替身  %d / %d\n%s 沉睡共鸣 %s · 温润屏障 %d\n减速打断护盾 · 抓住破绽暴击 · 反震撞墙" % [boss.health.health,boss.health.max_health,KeyHint.of("psyche_resonance"),"就绪" if cooldown<=0 else "%.1f s"%cooldown,player.fragments.barrier]
	elif phase == Phase.ANNIHILATE:
		label.text = "完美，已经碎了。"
		flash.color.a = clampf(1.0-absf(phase_elapsed-0.25)/0.9,0,0.9)
		nova.scale = Vector3.ONE*(0.1+phase_elapsed*9)
		(nova.material_override as StandardMaterial3D).albedo_color.a = maxf(0,0.7-phase_elapsed*0.5)
		if phase_elapsed >= 2.2 and not _complete_emitted:
			_complete_emitted = true
			flash.color.a = 0
			nova.hide()
			boss.queue_free()
			phase = Phase.COMPLETE
			label.hide()
			hud.finish()
			_unlock_player()
			defeated.emit(crown)
func _on_boss_defeated() -> void:
	if phase != Phase.COMBAT:
		return
	_lock_player()
	hud.set_combat_visible(false)
	var point := crown.global_position
	carrier = _carrier()
	carrier.global_position = point
	crown.reparent(carrier,true)
	crown.call("set_worn",false)
	crown.call("set_emission_strength",0.05)
	phase = Phase.ANNIHILATE
	phase_elapsed = 0
	nova.position = to_local(boss.global_position)+Vector3.UP
	nova.show()
func _lock_player() -> void:
	if not _controls_locked and is_instance_valid(player):
		_player_mode = player.process_mode
		player.process_mode = Node.PROCESS_MODE_DISABLED
		_controls_locked = true
func _unlock_player() -> void:
	if _controls_locked and is_instance_valid(player):
		player.process_mode = _player_mode
		_controls_locked = false
func _exit_tree() -> void:
	_unlock_player()
	if is_instance_valid(voice):
		voice.stop()
		voice.stream = null
