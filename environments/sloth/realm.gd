class_name SlothRealm
extends Node3D
## Generated maps instantiate this passive environment. Narrative state is injected.
@export var boss_arena := false
var rest_zones: Array[Node3D] = []
var rest_lights: Array[OmniLight3D] = []
var rings: Array[Node3D] = []
var rest_enabled := true
var deprived := false
var audio_managed := false
var clock_bpm := 0.0
var clock_ticks := 0
var _clock_left := 0.0
var _clock_audio: AudioStreamPlayer3D
var _industrial_audio: AudioStreamPlayer3D
var _stone: StandardMaterial3D
var _amber: StandardMaterial3D
var _rest_materials: Array[StandardMaterial3D] = []

func _ready() -> void:
	_stone = material(Color(0.88,0.88,0.85),0.05,0.72)
	_amber = material(Color(0.80,0.44,0.12),0.25,0.33,0.4)
	var dark := material(Color(0.10,0.085,0.06),0.1,0.8)
	box(self,Vector3(0,-0.6,0),Vector3(40,1.2,48),_stone,true)
	# Physical edges define the walkable floor. Scenery never enters navigation.
	for side in [-1.0,1.0]:
		box(self,Vector3(side*20,-0.1,0),Vector3(0.3,0.8,48),_stone,true)
		box(self,Vector3(0,-0.1,side*24),Vector3(40,0.8,0.3),_stone,true)
		for z in [-17.0,-7.0,5.0,17.0]:
			var tower := box(self,Vector3(side*17,3.5,z),Vector3(2.5,7,2.7),_stone,true)
			box(tower,Vector3(0,4.3,0),Vector3(3.6,0.5,3.6),_stone,false)
		for i in 6:
			var stair := box(self,Vector3(side*(21.0+i*1.7),1.5+i*0.65,-8+i*2.1),
				Vector3(2.5,0.35,2),_stone,false)
			stair.rotation.y = side*0.07*i
		for i in 5:
			var block := box(self,Vector3(side*(26+i*4),6+i*2,-22+i*6),
				Vector3(5+i*0.6,3.5,5),_stone,false)
			block.rotation = Vector3(0.07*i,0.15*i,0.05*side*i)
	# A readable central route remains open; cover is only on the flanks.
	if not boss_arena:
		for pos in [Vector3(-8,0.8,2),Vector3(8,0.8,-8),Vector3(-8,1.1,-13)]:
			box(self,pos,Vector3(3.2,pos.y*2,2),_stone,true)
	else:
		for side in [-1.0,1.0]:
			box(self,Vector3(side*10,0.65,-8),Vector3(3.5,1.3,3.5),_stone,true)
	for side in [-1.0,1.0]:
		var pivot := Node3D.new()
		pivot.position = Vector3(side*14,11,-17)
		add_child(pivot)
		var ring := torus(pivot,Vector3.ZERO,6.0,0.17,_stone)
		ring.rotation.x = PI*0.5
		torus(pivot,Vector3.ZERO,4.7,0.07,_amber).rotation.x = PI*0.5
		line(pivot,Vector3(0,5.8,0),Vector3(0,-4.8,0),0.055,_amber)
		box(pivot,Vector3(0,-4.8,0),Vector3(1.2,1.9,0.65),_amber,false).rotation.z = PI*0.25
		rings.append(pivot)
	for side in [-1.0,1.0]:
		for y in [4.0,7.0,10.0]:
			line(self,Vector3(side*18,y,19),Vector3(side*14,11,-17),0.018,_amber)
		_build_rest(Vector3(side*13,0,12),dark)
	var mist := CPUParticles3D.new()
	mist.name = "StillAmberMist"
	mist.amount = 42
	mist.lifetime = 14
	mist.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	mist.emission_box_extents = Vector3(18,0.3,22)
	mist.position.y = 0.35
	mist.direction = Vector3(1,0,0)
	mist.spread = 10
	mist.initial_velocity_min = 0.025
	mist.initial_velocity_max = 0.055
	mist.gravity = Vector3.ZERO
	var mote := SphereMesh.new()
	mote.radius = 0.045
	mote.height = 0.09
	mote.radial_segments = 4
	mote.rings = 2
	mote.material = material(Color(0.9,0.57,0.22,0.2),0,1,0.2)
	mist.mesh = mote
	add_child(mist)
	_clock_audio = AudioStreamPlayer3D.new()
	_clock_audio.name = "RunawayClock"
	_clock_audio.stream = clock_tone()
	_clock_audio.unit_size = 22
	_clock_audio.volume_db = -9
	_clock_audio.position = Vector3(0,8,-16)
	add_child(_clock_audio)
	_industrial_audio = AudioStreamPlayer3D.new()
	_industrial_audio.name = "IndustrialHum"
	_industrial_audio.stream = industrial_tone()
	_industrial_audio.unit_size = 30
	_industrial_audio.volume_db = -15
	add_child(_industrial_audio)
	set_deprivation(deprived)

func _build_rest(pos: Vector3,dark: Material) -> void:
	var area := Node3D.new()
	area.name = "RestZone%d" % rest_zones.size()
	area.position = pos
	add_child(area)
	var mat := material(Color(0.92,0.59,0.22),0.1,0.6,0.8)
	_rest_materials.append(mat)
	box(area,Vector3(0,0.04,0),Vector3(4,0.08,3.5),mat,false)
	box(area,Vector3(0,0.45,-0.8),Vector3(3,0.9,0.8),_stone,true)
	torus(area,Vector3(0,0.11,0),1.6,0.05,mat)
	var light := OmniLight3D.new()
	light.position.y = 1.3
	light.light_color = Color(1,0.62,0.24)
	light.light_energy = 1.8
	light.omni_range = 5
	area.add_child(light)
	rest_zones.append(area)
	rest_lights.append(light)
	area.set_meta("rest_radius",1.7)

func set_audio_managed(value: bool) -> void:
	audio_managed = value
	set_deprivation(deprived)

func set_deprivation(active: bool) -> void:
	deprived = active
	rest_enabled = not active
	clock_bpm = 148.0 if active else 0.0
	for light in rest_lights:
		light.light_energy = 0.0 if active else 1.8
	for mat in _rest_materials:
		mat.albedo_color = Color(0.035,0.03,0.025) if active else Color(0.92,0.59,0.22)
		mat.emission_energy_multiplier = 0.0 if active else 0.8
	if is_instance_valid(_industrial_audio):
		if active and not audio_managed:
			_industrial_audio.play()
		else:
			_industrial_audio.stop()
	if (not active or audio_managed) and is_instance_valid(_clock_audio):
		_clock_audio.stop()

func _physics_process(delta: float) -> void:
	if not deprived:
		return
	_clock_left -= delta
	while _clock_left <= 0.0:
		_clock_left += 60.0/clock_bpm
		clock_ticks += 1
		if not audio_managed: _clock_audio.play()
	for i in rings.size():
		rings[i].rotation.z += delta*(1.4 if i==0 else -1.9)

func _exit_tree() -> void:
	for audio in [_clock_audio,_industrial_audio]:
		if is_instance_valid(audio):
			audio.stop()
			audio.stream = null

static func material(color: Color,metallic: float,roughness: float,emission := 0.0) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.metallic = metallic
	result.roughness = roughness
	if color.a < 1:
		result.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	result.emission_enabled = emission>0
	result.emission = color
	result.emission_energy_multiplier = emission
	return result

static func box(parent: Node3D,pos: Vector3,size: Vector3,mat: Material,solid: bool) -> Node3D:
	var holder := StaticBody3D.new() if solid else Node3D.new()
	parent.add_child(holder)
	holder.position = pos
	var mesh := MeshInstance3D.new()
	var shape := BoxMesh.new()
	shape.size = size
	mesh.mesh = shape
	mesh.material_override = mat
	holder.add_child(mesh)
	if solid:
		(holder as StaticBody3D).collision_layer = CollisionLayers.WORLD
		(holder as StaticBody3D).collision_mask = 0
		holder.add_to_group("navigation_geometry")
		var collision := CollisionShape3D.new()
		var collision_shape := BoxShape3D.new()
		collision_shape.size = size
		collision.shape = collision_shape
		holder.add_child(collision)
	return holder

static func torus(parent: Node3D,pos: Vector3,radius: float,width: float,mat: Material) -> MeshInstance3D:
	var result := MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = radius-width
	mesh.outer_radius = radius+width
	mesh.rings = 48
	mesh.ring_segments = 6
	result.mesh = mesh
	result.material_override = mat
	result.position = pos
	parent.add_child(result)
	return result

static func line(parent: Node3D,a: Vector3,b: Vector3,width: float,mat: Material) -> MeshInstance3D:
	var result := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = width
	mesh.bottom_radius = width
	mesh.height = a.distance_to(b)
	mesh.radial_segments = 5
	result.mesh = mesh
	result.material_override = mat
	parent.add_child(result)
	result.position = (a+b)*0.5
	var up := (b-a).normalized()
	var side := up.cross(Vector3.FORWARD)
	if side.length_squared()<0.001:
		side = up.cross(Vector3.RIGHT)
	side = side.normalized()
	result.basis = Basis(side,up,side.cross(up).normalized())
	return result

static func clock_tone() -> AudioStreamWAV:
	return _tone(0.09,false)

static func industrial_tone() -> AudioStreamWAV:
	var wav := _tone(1.0,true)
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_end = wav.data.size()/2
	return wav

static func _tone(duration: float,low: bool) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 22050
	var data := PackedByteArray()
	var count := int(duration*22050)
	data.resize(count*2)
	for i in count:
		var t := float(i)/22050
		var value := (sin(TAU*48*t)*0.15 + sin(TAU*96*t)*0.06) if low else \
			(sin(TAU*1700*t)+sin(TAU*2700*t)*0.4)*exp(-t*65)*0.35
		data.encode_s16(i*2,int(clampf(value,-1,1)*32767))
	wav.data = data
	return wav
