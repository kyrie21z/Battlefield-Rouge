extends Node3D
## Preview of the talent orb standing in front of the next-room gate, playing the
## same arrival flourish RealmStage uses. Auto-captures and quits.
##
## Run with:  godot --path . res://tests/talent_gate_preview.tscn

const OUT_DIR := "res://docs/proof/talent-orb"
const SHOT_FRAMES: Array[int] = [24, 90, 190, 350]

var _orb: TalentOrb
var _fake_player: Node3D
var _camera: Camera3D
var _frame := 0
var _shot := 0
var _angle := 0.0
var _gate_pos := Vector3.ZERO


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	_build_room()
	_build_gate()
	_spawn_orb()
	_build_camera()


func _build_room() -> void:
	var we := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.05, 0.055, 0.075)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.5, 0.55, 0.72)
	e.ambient_light_energy = 1.5
	e.glow_enabled = true
	e.glow_intensity = 0.7
	e.glow_hdr_threshold = 1.1
	e.tonemap_mode = Environment.TONE_MAPPER_ACES
	we.environment = e
	add_child(we)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-48, 40, 0)
	key.light_energy = 2.2
	key.shadow_enabled = true
	add_child(key)

	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-10, -155, 0)
	rim.light_energy = 1.2
	rim.light_color = Color(0.55, 0.7, 1.0)
	add_child(rim)

	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(20, 20)
	floor_mesh.mesh = plane
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.08, 0.085, 0.10)
	fm.roughness = 0.9
	floor_mesh.material_override = fm
	add_child(floor_mesh)


func _build_gate() -> void:
	_gate_pos = Vector3(0.0, 0.0, -2.6)
	var gate := Node3D.new()
	gate.position = _gate_pos
	add_child(gate)
	var frame_mat := StandardMaterial3D.new()
	frame_mat.albedo_color = Color("8568a8")
	frame_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	frame_mat.emission_enabled = true
	frame_mat.emission = Color("58432c")
	frame_mat.emission_energy_multiplier = 0.4
	for side in [-1.0, 1.0]:
		var f := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.22, 3.8, 0.3)
		f.mesh = bm
		f.position = Vector3(side * 1.5, 1.9, 0)
		f.material_override = frame_mat
		gate.add_child(f)
	var lintel := MeshInstance3D.new()
	var beam := BoxMesh.new()
	beam.size = Vector3(3.22, 0.22, 0.3)
	lintel.mesh = beam
	lintel.position.y = 3.8
	lintel.material_override = frame_mat
	gate.add_child(lintel)

	var portal_mat := StandardMaterial3D.new()
	portal_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	portal_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	portal_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	portal_mat.albedo_color = Color(0.55, 0.35, 0.8, 0.13)
	portal_mat.emission_enabled = true
	portal_mat.emission = Color(0.4, 0.2, 0.7)
	var portal := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(2.8, 3.6)
	portal.mesh = quad
	portal.position.y = 1.8
	portal.material_override = portal_mat
	portal.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gate.add_child(portal)

	var label := Label3D.new()
	label.text = "下一关门扉\n击碎守卫并领取馈赠后开启"
	label.position = Vector3(0, 4.5, 0)
	label.font_size = 48
	label.outline_size = 8
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	gate.add_child(label)

	_fake_player = Node3D.new()
	_fake_player.position = Vector3(0.0, 0.0, 2.2)
	add_child(_fake_player)


func _spawn_orb() -> void:
	_orb = TalentOrb.new()
	_orb.name = "TalentOrb"
	_orb.set_player(_fake_player)
	_orb.position = _gate_pos + Vector3(0.0, 0.0, 1.95)
	_orb.position.y = _orb.base_height
	_orb.set_idle_enabled(false)
	add_child(_orb)
	_orb.set_core_visible(false)
	_orb.scatter(1.9)
	_orb.set_accent(Color(1.0, 0.62, 0.18))
	_play_arrival()


## Mirrors RealmStage._play_orb_arrival so the preview shows the real flourish.
func _play_arrival() -> void:
	var origin := _orb.position

	var halo_mesh := TorusMesh.new()
	halo_mesh.inner_radius = 0.55
	halo_mesh.outer_radius = 0.68
	var halo := MeshInstance3D.new()
	halo.mesh = halo_mesh
	halo.position = origin + Vector3(0.0, 0.06, 0.0)
	halo.scale = Vector3(0.25, 1.0, 0.25)
	var halo_mat := StandardMaterial3D.new()
	halo_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	halo_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	halo_mat.albedo_color = Color(0.55, 0.95, 1.0, 0.95)
	halo_mat.emission_enabled = true
	halo_mat.emission = Color(0.5, 0.9, 1.0)
	halo_mat.emission_energy_multiplier = 2.5
	halo.material_override = halo_mat
	add_child(halo)

	var column := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.42
	cyl.bottom_radius = 0.78
	cyl.height = 4.5
	column.mesh = cyl
	column.position = origin + Vector3(0.0, 2.25, 0.0)
	var col_mat := StandardMaterial3D.new()
	col_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	col_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	col_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	col_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	col_mat.albedo_color = Color(0.5, 0.9, 1.0, 0.14)
	col_mat.emission_enabled = true
	col_mat.emission = Color(0.45, 0.85, 1.0)
	col_mat.emission_energy_multiplier = 1.6
	column.material_override = col_mat
	column.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(column)

	var burst := OmniLight3D.new()
	burst.position = origin + Vector3(0.0, 1.3, 0.0)
	burst.light_color = Color(0.65, 0.95, 1.0)
	burst.light_energy = 0.0
	burst.omni_range = 9.0
	add_child(burst)

	var tween := create_tween()
	tween.set_parallel(true)
	_orb.reveal_pieces()
	_orb.assemble()
	var shell_done := _orb.assembly_seconds() - 0.35
	var core_tween := create_tween()
	core_tween.tween_interval(maxf(0.6, shell_done))
	core_tween.tween_callback(func() -> void:
		if is_instance_valid(_orb):
			_orb.fade_core_in(0.55)
			_orb.set_idle_enabled(true)
	)
	tween.tween_property(halo, "scale", Vector3(3.4, 1.0, 3.4), 3.2) \
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.tween_property(halo_mat, "albedo_color:a", 0.0, 3.2) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(burst, "light_energy", 7.0, 0.30)
	tween.tween_property(burst, "light_energy", 0.0, 5.2).set_delay(0.30)
	tween.tween_property(col_mat, "albedo_color:a", 0.0, 5.4).set_delay(0.40)
	tween.chain().tween_callback(func() -> void:
		halo.queue_free()
		column.queue_free()
		burst.queue_free()
	)


func _build_camera() -> void:
	_camera = Camera3D.new()
	_camera.fov = 55.0
	_camera.near = 0.03
	add_child(_camera)
	_camera.current = true
	var a := deg_to_rad(6.0) + _angle
	_camera.global_position = Vector3(sin(a) * 4.5, 1.7, cos(a) * 4.5 + 1.0)
	_camera.look_at(Vector3(0, 1.5, -1.2), Vector3.UP)


func _process(delta: float) -> void:
	_frame += 1
	_angle += delta * 0.10
	if _camera != null:
		_build_camera_look()

	if _shot < SHOT_FRAMES.size() and _frame >= SHOT_FRAMES[_shot]:
		_shot += 1
		var img := get_viewport().get_texture().get_image()
		var path := "%s/gate-%d.png" % [OUT_DIR, _shot]
		img.save_png(path)
		print("SAVED ", ProjectSettings.globalize_path(path))
		if _shot >= SHOT_FRAMES.size():
			await get_tree().process_frame
			get_tree().quit()


func _build_camera_look() -> void:
	var a := deg_to_rad(6.0) + _angle
	_camera.global_position = Vector3(sin(a) * 4.5, 1.7, cos(a) * 4.5 + 1.0)
	_camera.look_at(Vector3(0, 1.5, -1.2), Vector3.UP)


func _ready_camera_deferred() -> void:
	pass
