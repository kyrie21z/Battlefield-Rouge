class_name RestSanctuary
extends Node3D
## Pre-boss rest room. Passive geometry: no save state, no enemy control, no RNG.
##
## A white-stone colonnade frames one sightline: entrance, altar, boss gate. The
## altar ("静息石座") offers a single full heal. Everything here is procedural so
## the sanctuary shares Mind Freak's architectural minimalist language without
## borrowing any asset from the legacy project.

@export_range(0, 3) var realm: int = 0
@export var boss_arena := false

const SPAWN_POINT := Vector3(0, 0, 11)
const EXIT_POINT := Vector3(0, 0, -13)
const ALTAR_POINT := Vector3(0, 0, -2)
const FLOOR_SIZE := Vector3(22.0, 0.6, 30.0)
const DAIS_HEIGHT := 0.35

const SKY_COLORS := [
	Color("e8ddc8"), Color("d8d2e6"), Color("e6d8d2"), Color("d6e0e8"),
]
const AMBIENT_COLORS := [
	Color("f4ecdc"), Color("e8e2f4"), Color("f6e6de"), Color("e2ecf4"),
]
const ACCENT_COLORS := [
	Color("e0a53f"), Color("a184dd"), Color("cf7a5f"), Color("6f8fb5"),
]
const LIGHT_COLORS := [
	Color("ffd79a"), Color("cdb6ff"), Color("ffb79a"), Color("bcd6ea"),
]

var player: Player
var void_fall: RealmVoid
var crystal: MeshInstance3D
var crystal_material: StandardMaterial3D
var altar_light: OmniLight3D
var altar_ring: MeshInstance3D
var altar_ring_material: StandardMaterial3D
var altar_label: Label3D
var _stone: StandardMaterial3D
var _accent_material: StandardMaterial3D
var _motes: Array[MeshInstance3D] = []
var _mote_base: Array[Vector3] = []
var _mote_phase: Array[float] = []
var _elapsed := 0.0
var _pulse := 0.0
var _consumed := false
var _audio: AudioStreamPlayer


func provides_stage_lighting() -> bool:
	return true


func player_spawn() -> Vector3:
	return SPAWN_POINT


func exit_position() -> Vector3:
	return EXIT_POINT


func rest_position() -> Vector3:
	return ALTAR_POINT + Vector3.UP * (DAIS_HEIGHT if realm == 3 else 0.0)


func set_player(value: Player) -> void:
	player = value
	if is_instance_valid(void_fall):
		void_fall.setup(value)


## The sanctuary is never gated by deprivation; the room itself is removed from
## the flow instead. A stray direct call still dims it rather than lying.
func set_deprivation(active: bool) -> void:
	if active:
		_dim(0.3)


func set_rest_consumed(consumed: bool) -> void:
	_consumed = consumed
	if consumed:
		_dim(0.35)
	else:
		_dim(1.0)


func play_rest_pulse() -> void:
	_pulse = 1.0
	if is_instance_valid(crystal):
		var tween := create_tween()
		tween.tween_property(crystal, "scale", Vector3.ONE * 1.3, 0.26) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_property(crystal, "scale", Vector3.ONE, 0.62) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_spawn_pulse_ring()
	_play_chime()


func _ready() -> void:
	_elapsed = 0.0
	_build_materials()
	_build_environment()
	_build_floor()
	_build_walls()
	_build_colonnade()
	_build_ceiling()
	_build_realm_accent()
	_build_altar()
	_install_void()


func _physics_process(delta: float) -> void:
	_elapsed += delta
	if is_instance_valid(crystal):
		var phase := sin(_elapsed * 0.9)
		crystal.position.y = _crystal_rest_height() + phase * 0.08
		crystal.rotation.y += delta * 0.35
	if _pulse > 0.0:
		_pulse = maxf(0.0, _pulse - delta)
		if is_instance_valid(altar_light):
			var resting := 1.8 * (0.35 if _consumed else 1.0)
			altar_light.light_energy = lerpf(resting, 3.4, _pulse)
	for index in _motes.size():
		if not is_instance_valid(_motes[index]):
			continue
		var base := _mote_base[index]
		_motes[index].position = base + Vector3(
			sin(_elapsed * 0.4 + _mote_phase[index]) * 0.18,
			sin(_elapsed * 0.7 + _mote_phase[index] * 1.7) * 0.16,
			cos(_elapsed * 0.35 + _mote_phase[index]) * 0.18)


func stop_audio() -> void:
	if is_instance_valid(_audio):
		_audio.stop()


func _exit_tree() -> void:
	stop_audio()
	if is_instance_valid(_audio):
		_audio.queue_free()
		_audio = null
	_motes.clear()
	_mote_base.clear()
	_mote_phase.clear()


func _build_materials() -> void:
	_stone = StandardMaterial3D.new()
	_stone.albedo_color = Color("f2ede3")
	_stone.roughness = 0.92
	_stone.metallic = 0.0
	_accent_material = StandardMaterial3D.new()
	_accent_material.albedo_color = ACCENT_COLORS[realm]
	_accent_material.roughness = 0.35
	_accent_material.metallic = 0.45
	_accent_material.emission_enabled = true
	_accent_material.emission = ACCENT_COLORS[realm]
	_accent_material.emission_energy_multiplier = 0.22


func _build_environment() -> void:
	var world := WorldEnvironment.new()
	world.name = "SanctuaryEnvironment"
	var environment := preload("res://environments/default_env.tres").duplicate() as Environment
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = SKY_COLORS[realm]
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = AMBIENT_COLORS[realm]
	environment.ambient_light_energy = 0.56
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.glow_enabled = true
	environment.glow_intensity = 0.34
	environment.fog_enabled = true
	environment.fog_light_color = SKY_COLORS[realm]
	environment.fog_density = 0.004
	environment.fog_sky_affect = 0.2
	world.environment = environment
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.name = "SanctuarySun"
	sun.rotation_degrees = Vector3(-54, -26, 0)
	sun.light_color = LIGHT_COLORS[realm]
	sun.light_energy = 1.18
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 60.0
	add_child(sun)


func _build_floor() -> void:
	_solid("Floor", Vector3(0, -0.3, 0), FLOOR_SIZE, _stone)


## Low parapets and the two end walls keep the player inside; the end openings
## line up with the spawn and the boss gate so the sightline stays honest.
func _build_walls() -> void:
	for side in [-1.0, 1.0]:
		_solid("Parapet%d" % int(side), Vector3(side * 11.0, 0.45, 0), Vector3(0.42, 0.9, 30.0), _stone, false)
		_visual("ParapetCap%d" % int(side), Vector3(side * 11.0, 0.94, 0), Vector3(0.52, 0.08, 30.2), _stone)
	for end in [1.0, -1.0]:
		for side in [-1.0, 1.0]:
			var center := Vector3(side * 7.0, 2.5, end * 15.0)
			_solid("EndWall%d_%d" % [int(end), int(side)], center, Vector3(8.0, 5.0, 0.45), _stone, false)
		_visual("EndLintel%d" % int(end), Vector3(0, 4.3, end * 15.0), Vector3(6.4, 0.9, 0.5), _stone)


func _build_colonnade() -> void:
	for side in [-1.0, 1.0]:
		for z in [9.0, 4.5, 0.0, -4.5, -9.0]:
			var x: float = float(side) * 8.2
			_solid("Plinth%s_%s" % [side, z], Vector3(x, 0.15, z), Vector3(1.0, 0.3, 1.0), _stone, false)
			_solid("Shaft%s_%s" % [side, z], Vector3(x, 2.4, z), Vector3(0.62, 4.2, 0.62), _stone, false)
			_visual("Capital%s_%s" % [side, z], Vector3(x, 4.62, z), Vector3(1.0, 0.24, 1.0), _stone)
			_visual("Impost%s_%s" % [side, z], Vector3(x, 4.86, z), Vector3(0.86, 0.24, 0.86), _stone)


func _build_ceiling() -> void:
	for z in [10.5, 5.0, -0.5, -6.0, -11.5]:
		_visual("Beam%s" % z, Vector3(0, 5.2, z), Vector3(20.4, 0.38, 0.55), _stone)
	_visual("SpineBeam", Vector3(0, 5.5, 0), Vector3(0.5, 0.32, 27.0), _stone)
	for end in [1.0, -1.0]:
		_visual("ArchBand%d" % int(end), Vector3(0, 4.92, end * 11.6), Vector3(20.4, 0.26, 0.42), _stone)


## Each realm gets one quiet architectural note, never a new gameplay rule.
func _build_realm_accent() -> void:
	match realm:
		0:
			_build_sloth_accent()
		1:
			_build_fear_accent()
		2:
			_build_wrath_accent()
		3:
			_build_sorrow_accent()


func _build_sloth_accent() -> void:
	var brass := StandardMaterial3D.new()
	brass.albedo_color = Color("b08b3f")
	brass.metallic = 0.85
	brass.roughness = 0.32
	for radius in [3.15, 4.3]:
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = radius - 0.055
		torus.outer_radius = radius
		ring.mesh = torus
		ring.material_override = brass
		ring.position = Vector3(0, 0.02, ALTAR_POINT.z)
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(ring)
	var lantern := Node3D.new()
	lantern.name = "RestLantern"
	lantern.position = Vector3(2.7, 3.1, ALTAR_POINT.z)
	add_child(lantern)
	var cage := StandardMaterial3D.new()
	cage.albedo_color = Color("7d6433")
	cage.metallic = 0.7
	cage.roughness = 0.4
	for offset in [Vector3(0, 0.34, 0), Vector3(0, -0.34, 0)]:
		_visual("LanternBand", offset, Vector3(0.46, 0.07, 0.46), cage, lantern)
	var core := StandardMaterial3D.new()
	core.albedo_color = Color("ffd79a")
	core.emission_enabled = true
	core.emission = Color("ffbe5e")
	core.emission_energy_multiplier = 1.8
	_visual("LanternCore", Vector3.ZERO, Vector3(0.3, 0.6, 0.3), core, lantern)
	var lantern_light := OmniLight3D.new()
	lantern_light.light_color = Color("ffc471")
	lantern_light.light_energy = 0.9
	lantern_light.omni_range = 6.0
	lantern.add_child(lantern_light)
	_build_dust_motes()


func _build_dust_motes() -> void:
	var mote := StandardMaterial3D.new()
	mote.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mote.albedo_color = Color(1.0, 0.84, 0.56, 0.55)
	mote.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mote.emission_enabled = true
	mote.emission = Color(1.0, 0.78, 0.45)
	mote.emission_energy_multiplier = 1.1
	var sphere := SphereMesh.new()
	sphere.radius = 0.022
	sphere.height = 0.044
	sphere.radial_segments = 6
	sphere.rings = 3
	for index in 14:
		var angle := TAU * float(index) / 14.0
		var base := Vector3(cos(angle) * 2.6, 0.7 + float(index % 5) * 0.4, ALTAR_POINT.z + sin(angle) * 2.6)
		var node := MeshInstance3D.new()
		node.name = "DustMote%d" % index
		node.mesh = sphere
		node.material_override = mote
		node.position = base
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(node)
		_motes.append(node)
		_mote_base.append(base)
		_mote_phase.append(angle)


func _build_fear_accent() -> void:
	var violet := OmniLight3D.new()
	violet.name = "VioletStainedLight"
	violet.position = Vector3(0, 4.5, ALTAR_POINT.z)
	violet.light_color = Color("b79bff")
	violet.light_energy = 1.05
	violet.omni_range = 15.0
	add_child(violet)
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.55, 0.42, 0.86, 0.42)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.emission_enabled = true
	glass.emission = Color("8d6fdc")
	glass.emission_energy_multiplier = 0.85
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	for side in [-1.0, 1.0]:
		for z in [4.5, 0.0, -4.5]:
			_visual("StainedGlass%s_%s" % [side, z], Vector3(side * 10.94, 3.2, z), Vector3(0.05, 3.0, 1.7), glass)
		_visual("VaultRib%s" % side, Vector3(side * 4.0, 5.02, 0), Vector3(0.22, 0.2, 26.0), _stone)


func _build_wrath_accent() -> void:
	var porcelain := StandardMaterial3D.new()
	porcelain.albedo_color = Color("fbf8f3")
	porcelain.roughness = 0.22
	porcelain.metallic = 0.05
	for side in [-1.0, 1.0]:
		_visual("PorcelainBand%s" % side, Vector3(side * 10.9, 1.5, 0), Vector3(0.08, 0.5, 28.0), porcelain)
	var hearth := StandardMaterial3D.new()
	hearth.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hearth.albedo_color = Color(1.0, 0.58, 0.32, 0.5)
	hearth.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	hearth.emission_enabled = true
	hearth.emission = Color("ff7a3c")
	hearth.emission_energy_multiplier = 0.9
	_visual("HearthStrip", Vector3(-10.6, 0.18, 0), Vector3(0.16, 0.2, 17.0), hearth)
	var hearth_light := OmniLight3D.new()
	hearth_light.light_color = Color("ffa46b")
	hearth_light.light_energy = 0.55
	hearth_light.omni_range = 9.0
	hearth_light.position = Vector3(-9.4, 0.7, 0)
	add_child(hearth_light)


func _build_sorrow_accent() -> void:
	_solid("AltarDais", Vector3(0, DAIS_HEIGHT * 0.5, ALTAR_POINT.z), Vector3(7.4, DAIS_HEIGHT, 7.4), _stone)
	# Three shallow descending treads face the entrance, each well under the
	# 0.25 m navigation climb so the baked mesh joins the dais without a ledge.
	for step in 3:
		var depth := 0.55
		var height := DAIS_HEIGHT - float(step + 1) * 0.09
		var edge := ALTAR_POINT.z + 3.7 + float(step) * depth
		_solid("DaisStep%d" % step, Vector3(0, height * 0.5, edge + depth * 0.5),
			Vector3(7.4, height, depth), _stone)
	var cobalt := StandardMaterial3D.new()
	cobalt.albedo_color = Color("3d5f86")
	cobalt.metallic = 0.92
	cobalt.roughness = 0.12
	cobalt.emission_enabled = true
	cobalt.emission = Color("2f4d73")
	cobalt.emission_energy_multiplier = 0.25
	for side in [-1.0, 1.0]:
		_visual("CobaltTrough%s" % side, Vector3(side * 3.62, DAIS_HEIGHT + 0.05, ALTAR_POINT.z),
			Vector3(0.36, 0.1, 7.2), cobalt)


func _build_altar() -> void:
	var altar := Node3D.new()
	altar.name = "RestAltar"
	var lift := DAIS_HEIGHT if realm == 3 else 0.0
	altar.position = ALTAR_POINT + Vector3.UP * lift
	add_child(altar)

	var lower := MeshInstance3D.new()
	var lower_mesh := CylinderMesh.new()
	lower_mesh.top_radius = 1.02
	lower_mesh.bottom_radius = 1.14
	lower_mesh.height = 0.16
	lower_mesh.radial_segments = 6
	lower.mesh = lower_mesh
	lower.position.y = 0.08
	lower.material_override = _stone
	altar.add_child(lower)

	var middle := MeshInstance3D.new()
	var middle_mesh := CylinderMesh.new()
	middle_mesh.top_radius = 0.7
	middle_mesh.bottom_radius = 0.94
	middle_mesh.height = 0.24
	middle_mesh.radial_segments = 6
	middle.mesh = middle_mesh
	middle.position.y = 0.28
	middle.material_override = _stone
	altar.add_child(middle)

	var upper := MeshInstance3D.new()
	var upper_mesh := CylinderMesh.new()
	upper_mesh.top_radius = 0.5
	upper_mesh.bottom_radius = 0.64
	upper_mesh.height = 0.5
	upper_mesh.radial_segments = 6
	upper.mesh = upper_mesh
	upper.position.y = 0.65
	upper.material_override = _accent_material
	altar.add_child(upper)

	crystal_material = StandardMaterial3D.new()
	crystal_material.albedo_color = ACCENT_COLORS[realm]
	crystal_material.roughness = 0.16
	crystal_material.metallic = 0.18
	crystal_material.emission_enabled = true
	crystal_material.emission = ACCENT_COLORS[realm]
	crystal_material.emission_energy_multiplier = 1.15
	crystal = MeshInstance3D.new()
	crystal.name = "CrystalPrism"
	var upper_spire := CylinderMesh.new()
	upper_spire.top_radius = 0.02
	upper_spire.bottom_radius = 0.28
	upper_spire.height = 0.56
	upper_spire.radial_segments = 6
	upper_spire.rings = 1
	crystal.mesh = upper_spire
	crystal.material_override = crystal_material
	crystal.position.y = _crystal_rest_height()
	crystal.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var lower_spire := MeshInstance3D.new()
	var lower_cone := CylinderMesh.new()
	lower_cone.top_radius = 0.28
	lower_cone.bottom_radius = 0.02
	lower_cone.height = 0.36
	lower_cone.radial_segments = 6
	lower_cone.rings = 1
	lower_spire.mesh = lower_cone
	lower_spire.material_override = crystal_material
	lower_spire.position.y = -0.46
	lower_spire.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	crystal.add_child(lower_spire)
	altar.add_child(crystal)

	altar_ring = MeshInstance3D.new()
	altar_ring.name = "AltarRing"
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 1.5
	ring_mesh.outer_radius = 1.64
	altar_ring.mesh = ring_mesh
	altar_ring_material = StandardMaterial3D.new()
	altar_ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	altar_ring_material.albedo_color = Color(ACCENT_COLORS[realm], 0.85)
	altar_ring_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	altar_ring_material.emission_enabled = true
	altar_ring_material.emission = ACCENT_COLORS[realm]
	altar_ring_material.emission_energy_multiplier = 1.4
	altar_ring.material_override = altar_ring_material
	altar_ring.position.y = 0.03
	altar_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	altar.add_child(altar_ring)

	altar_light = OmniLight3D.new()
	altar_light.name = "AltarLight"
	altar_light.position.y = 1.9
	altar_light.light_color = LIGHT_COLORS[realm]
	altar_light.light_energy = 1.8
	altar_light.omni_range = 9.0
	altar.add_child(altar_light)

	altar_label = Label3D.new()
	altar_label.name = "AltarLabel"
	altar_label.text = "宁息之源\n靠近后按 %s 恢复生命" % KeyHint.of("interact")
	altar_label.position.y = 2.35
	altar_label.pixel_size = 0.0026
	altar_label.font_size = 32
	altar_label.outline_size = 6
	altar_label.modulate = Color("f6f4ee")
	altar_label.outline_modulate = Color("111317")
	altar_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	altar.add_child(altar_label)


func _crystal_rest_height() -> float:
	return 1.68


func _dim(strength: float) -> void:
	if is_instance_valid(crystal_material):
		crystal_material.emission_energy_multiplier = 1.15 * strength
	if is_instance_valid(altar_ring_material):
		altar_ring_material.albedo_color.a = 0.85 * strength
		altar_ring_material.emission_energy_multiplier = 1.4 * strength
	if is_instance_valid(altar_light):
		altar_light.light_energy = 1.8 * strength
	if is_instance_valid(altar_label):
		altar_label.text = "心绪已平复\n前往前方首领门扉" if _consumed else "宁息之源\n靠近后按 %s 恢复生命" % KeyHint.of("interact")


func _spawn_pulse_ring() -> void:
	var ring := MeshInstance3D.new()
	ring.name = "RestPulseRing"
	var mesh := TorusMesh.new()
	mesh.inner_radius = 1.45
	mesh.outer_radius = 1.6
	ring.mesh = mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(ACCENT_COLORS[realm], 0.9)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.emission_enabled = true
	material.emission = LIGHT_COLORS[realm]
	material.emission_energy_multiplier = 2.0
	ring.material_override = material
	ring.position = ALTAR_POINT + Vector3.UP * (DAIS_HEIGHT if realm == 3 else 0.04)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(ring, "scale", Vector3(2.6, 1.0, 2.6), 1.1) \
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.tween_property(material, "albedo_color:a", 0.0, 1.1) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.chain().tween_callback(ring.queue_free)


func _play_chime() -> void:
	if not is_instance_valid(_audio):
		_audio = AudioStreamPlayer.new()
		_audio.name = "RestChime"
		_audio.volume_db = -8.0
		add_child(_audio)
	_audio.stream = _chime_stream()
	_audio.play()


## A quiet three-partial bell. Built sample by sample from a fixed formula, so
## it consumes no RNG and sounds identical on every visit.
func _chime_stream() -> AudioStreamWAV:
	var mix_rate := 22050
	var duration := 1.6
	var sample_count := int(mix_rate * duration)
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	for index in sample_count:
		var time := float(index) / float(mix_rate)
		var envelope := exp(-3.4 * time)
		var attack := minf(1.0, time / 0.02)
		var value := sin(TAU * 523.25 * time) * 0.55 \
			+ sin(TAU * 784.0 * time) * 0.3 \
			+ sin(TAU * 1046.5 * time) * 0.16
		value = clampf(value * envelope * attack * 0.6, -1.0, 1.0)
		data.encode_s16(index * 2, int(value * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = mix_rate
	stream.stereo = false
	stream.data = data
	return stream


func _install_void() -> void:
	void_fall = RealmVoid.new()
	void_fall.name = "VoidFall"
	void_fall.fall_height = -12.0
	void_fall.spawn_fallback = player_spawn()
	add_child(void_fall)


## Solid, walkable only where the stage asks: every callable collider joins the
## navigation geometry group so the room bakes exactly one surface plus its props.
func _solid(node_name: String, center: Vector3, size: Vector3, material: Material, walkable := true) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = center
	body.collision_layer = CollisionLayers.WORLD
	body.collision_mask = 0
	body.add_to_group("navigation_geometry")
	body.set_meta("walkable_surface", walkable)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = material
	body.add_child(mesh)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	add_child(body)
	return body


## Visual-only architecture: never joins the navigation group, never blocks a ray.
func _visual(node_name: String, center: Vector3, size: Vector3, material: Material, parent: Node3D = null) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.name = node_name
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = material
	mesh.position = center
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	(parent if parent != null else self).add_child(mesh)
	return mesh
