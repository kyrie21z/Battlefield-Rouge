class_name FearSanctum
extends Node3D
## Architecture around compact Fear bridges; scenery never bakes navigation.
var chamber := 0
var boss_room := false
var environment: Environment
var scenery: Node3D
var combat: Node3D
var decor_instances := 0
var _boxes := {}
var _ivory: StandardMaterial3D
var _violet: StandardMaterial3D
var _dark: StandardMaterial3D
var ghosts: Array[Node3D] = []
var _ghost_origins: Array[Vector3] = []
var _ghost_time := 0.0

func _ready() -> void:
	_ivory = _material(Color(0.88,0.88,0.92))
	_violet = _material(Color(0.38,0.16,0.64),true)
	_dark = _material(Color(0.075,0.055,0.11))
	scenery = Node3D.new()
	scenery.name = "DistantArchitecture"
	scenery.add_to_group("fear_scenery")
	add_child(scenery)
	combat = Node3D.new()
	combat.name = "SideBalconies"
	add_child(combat)
	_build_environment()
	_colonnade()
	_watching_eye()
	_bridge_details()
	if not boss_room: _balconies()
	else: _boss_frame()
	_ghosts()

func _process(delta: float) -> void:
	_ghost_time += delta
	for index in ghosts.size():
		var phase := _ghost_time*0.32+index*1.7
		ghosts[index].position = _ghost_origins[index]+Vector3(sin(phase)*1.5,sin(phase*1.3)*0.65,cos(phase)*0.55)
		ghosts[index].rotation.y = sin(phase*0.7)*0.18

func _material(color: Color, luminous := false) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.82
	if luminous:
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 0.45
	return mat

func _build_environment() -> void:
	environment = preload("res://environments/default_env.tres").duplicate() as Environment
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_shader := Shader.new()
	sky_shader.code = "shader_type sky;\nvoid sky() { float horizon = pow(1.0 - clamp(abs(EYEDIR.y), 0.0, 1.0), 3.0); COLOR = mix(vec3(0.025, 0.020, 0.05), vec3(0.19, 0.145, 0.25), horizon); }"
	var sky_material := ShaderMaterial.new()
	sky_material.shader = sky_shader
	sky.sky_material = sky_material
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.72,0.68,0.84)
	environment.ambient_light_energy = 0.65
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.glow_enabled = true
	environment.glow_intensity = 0.25
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.18,0.145,0.25)
	environment.fog_density = 0.006

func _box_mesh(size_value: Vector3) -> BoxMesh:
	var key := str(size_value)
	if not _boxes.has(key):
		var mesh := BoxMesh.new()
		mesh.size = size_value
		_boxes[key] = mesh
	return _boxes[key]

func _box(parent: Node3D, label: String, point: Vector3, dimensions: Vector3, mat: Material, angles := Vector3.ZERO) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.name = label
	mesh.mesh = _box_mesh(dimensions)
	mesh.material_override = mat
	mesh.position = point
	mesh.rotation = angles
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mesh)
	decor_instances += 1
	return mesh

func _beam(label: String, start: Vector3, finish: Vector3, width: float, mat: Material) -> void:
	var mesh := _box(scenery,label,(start+finish)*0.5,Vector3(width,width,start.distance_to(finish)),mat)
	var up := Vector3.UP if absf((finish-start).normalized().y)<0.99 else Vector3.FORWARD
	mesh.look_at(scenery.to_global(finish),scenery.global_basis*up)

func _colonnade() -> void:
	for row in 3:
		var z := 11.0-row*16.0
		for side in [-1.0,1.0]:
			var x: float = side*17.0
			var broken: bool = chamber == 1 and row == 1 and side > 0
			var top := 9.0 if broken else 19.0
			_box(scenery,"PierBase",Vector3(x,-2,z),Vector3(5,4,5),_ivory)
			_box(scenery,"Pier",Vector3(x,(top-1)*0.5,z),Vector3(2.2,top+1,2.8),_ivory)
			_box(scenery,"Recess",Vector3(x-side*1.12,top*0.5,z+0.05),Vector3(0.05,top-3,1.15),_dark)
			_box(scenery,"VioletInlay",Vector3(x-side*1.16,top*0.5,z+0.08),Vector3(0.055,top*0.53,0.12),_violet)
			_box(scenery,"Capital",Vector3(x,top+0.1,z),Vector3(3.2,0.75,3.8),_ivory)
			_beam("FlyingButtress",Vector3(side*24,-5,z-3),Vector3(x,top-3,z),1.5,_ivory)
			if broken:
				_box(scenery,"SuspendedCapital",Vector3(x+2.5,16,z-1),Vector3(3.2,3.5,3.8),_ivory,Vector3(0.18,0.1,-0.32))
				_box(scenery,"FractureGlow",Vector3(x,9.5,z),Vector3(2.1,0.08,2.7),_violet)
			# Broken suspended walls provide parallax without expanding combat space.
			_box(scenery,"HangingWall",Vector3(side*24,4-row*3,z-4),Vector3(5,18,1.6),_ivory,Vector3(0,side*0.12,side*(0.10+row*0.045)))
			_box(scenery,"WallScar",Vector3(side*24,4-row*3,z-3.15),Vector3(0.15,13,0.08),_violet,Vector3(0,0,side*0.12))
		var arch := [Vector3(-17,18,z),Vector3(-12,26,z),Vector3(0,31,z),Vector3(12,26,z),Vector3(17,18,z)]
		for index in 4:
			# Chamber two has a broken upper rib rather than a repeated intact hall.
			if chamber == 1 and row == 1 and index == 1: continue
			if chamber == 1 and row == 1 and index == 3: continue
			_beam("PointedRib",arch[index],arch[index+1],1.05,_ivory)
	for side in [-1.0,1.0]:
		for index in 6:
			_box(scenery,"AbyssRemnant",Vector3(side*(15+index*2),-7-index*5,10-index*7),Vector3(3+index,9+index*2,4),_ivory,Vector3(0,0,side*0.15))
	# Entry side frames the player, with an open middle and no hidden blocking wall.
	for side in [-1.0,1.0]:
		_box(scenery,"EntryPylon",Vector3(side*7.2,5.5,19.5),Vector3(2,12,2.4),_ivory)
		_box(scenery,"EntryRecess",Vector3(side*7.2,5.7,20.72),Vector3(0.65,8,0.04),_dark)
		_box(scenery,"EntryRune",Vector3(side*7.2,6,20.76),Vector3(0.12,5,0.05),_violet)

func _watching_eye() -> void:
	var eye := Node3D.new()
	eye.name = "DistantWatchingEye"
	eye.position = Vector3(0,17,-31)
	eye.rotation.x = PI*0.5
	scenery.add_child(eye)
	for band in 2:
		var rim := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 7.0+band*1.4
		torus.outer_radius = 7.65+band*1.4
		torus.rings = 64
		torus.ring_segments = 6
		rim.mesh = torus
		rim.scale = Vector3(1.18,1,0.60)
		rim.material_override = _ivory
		rim.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		eye.add_child(rim)
	var hollow := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 6.95
	disc.bottom_radius = 6.95
	disc.height = 0.16
	disc.radial_segments = 64
	hollow.mesh = disc
	hollow.scale = Vector3(1.18,1,0.60)
	hollow.material_override = _dark
	hollow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	eye.add_child(hollow)
	_box(eye,"Iris",Vector3(0,0.15,0),Vector3(0.42,0.08,6.4),_violet)
	for side in [-1.0,1.0]:
		_box(scenery,"EyeSupport",Vector3(side*7.8,5,-31),Vector3(2,18,2),_ivory)
		_beam("BrokenCrown",Vector3(side*8,20,-31),Vector3(side*3,27,-31),0.85,_ivory)

func _bridge_details() -> void:
	for z in [10.0,7.45,2.5,-2.5,-10.5,-15.5]:
		var length := 1.0 if absf(z)<8 else 2.0
		for side in [-1.0,1.0]:
			_box(scenery,"BridgeInlay",Vector3(side*1.78,0.04,z),Vector3(0.065,0.02,length),_violet)
	for side in [-1.0,1.0]:
		for z in [-8.0,8.0]:
			_box(scenery,"IslandFascia",Vector3(side*7,-0.65,z),Vector3(7.3,0.20,7.3),_ivory)
			_box(scenery,"IslandUndercut",Vector3(side*7,-1.8,z),Vector3(4.7,2.2,4.7),_dark)
			_box(scenery,"VioletUnderside",Vector3(side*7,-0.83,z+3.48),Vector3(5,0.09,0.08),_violet)

func _solid(label: String, point: Vector3, dimensions: Vector3, angles := Vector3.ZERO) -> void:
	var body := StaticBody3D.new()
	body.name = label
	body.position = point
	body.rotation = angles
	body.collision_layer = CollisionLayers.WORLD
	body.collision_mask = 0
	body.add_to_group("navigation_geometry")
	body.set_meta("walkable_surface",label != "Cover")
	combat.add_child(body)
	_box(body,label+"Mesh",Vector3.ZERO,dimensions,_ivory)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = dimensions
	collision.shape = shape
	body.add_child(collision)

func _balconies() -> void:
	var angle := atan(1.2/4.0)
	for side in [-1.0,1.0]:
		_solid("Balcony",Vector3(side*9,1.08,0),Vector3(3,0.24,6))
		for end in [-1.0,1.0]:
			_solid("Ramp",Vector3(side*9,0.6-cos(angle)*0.1,end*5),Vector3(3,0.2,sqrt(17.44)),Vector3(end*angle,0,0))
		_solid("Cover",Vector3(side*7.7,1.7,0),Vector3(0.28,1,3.6))
		_box(scenery,"BalconySeam",Vector3(side*10.3,1.24,0),Vector3(0.06,0.02,5.7),_violet)
		if chamber == 1:
			_box(scenery,"BrokenSpire",Vector3(side*12.5,4,-9),Vector3(1.2,10,1.2),_ivory,Vector3(0,0,side*0.22))

func _boss_frame() -> void:
	# Scenery surrounds the existing dais; every combat sightline stays usable.
	for side in [-1.0,1.0]:
		_box(scenery,"BossApse",Vector3(side*12.5,6,-10),Vector3(2,14,8),_ivory)
		_box(scenery,"ApseScar",Vector3(side*11.45,7,-9),Vector3(0.06,9,0.22),_violet)
		_beam("ThroneRib",Vector3(side*12.5,13,-10),Vector3(side*5,21,-14),0.8,_ivory)

func _ghosts() -> void:
	# Shared low-poly shrouds: six atmospheric spirits, no actors or audio voices.
	var cloth := _material(Color(0.83,0.81,0.94,0.48),true)
	cloth.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cloth.cull_mode = BaseMaterial3D.CULL_DISABLED
	var robe := SurfaceTool.new()
	robe.begin(Mesh.PRIMITIVE_TRIANGLES)
	for segment in 12:
		var a := TAU*segment/12.0
		var b := TAU*(segment+1)/12.0
		var top_a := Vector3(cos(a)*0.34,0.65,sin(a)*0.34)
		var top_b := Vector3(cos(b)*0.34,0.65,sin(b)*0.34)
		var edge_a := Vector3(cos(a)*0.85,-0.8-(0.45 if segment%2 == 0 else 0.0),sin(a)*0.6)
		var edge_b := Vector3(cos(b)*0.85,-0.8-(0.45 if (segment+1)%2 == 0 else 0.0),sin(b)*0.6)
		for vertex in [top_a,edge_a,edge_b,top_a,edge_b,top_b]: robe.add_vertex(vertex)
	var robe_mesh := robe.commit()
	var hood := SphereMesh.new()
	hood.radius = 0.48
	hood.height = 1.05
	hood.radial_segments = 12
	hood.rings = 6
	for point in [Vector3(-12,7,6),Vector3(12,9,2),Vector3(-12,11,-13),Vector3(12,7,-15),Vector3(-5,13,-24),Vector3(6,12,-27)]:
		var ghost := Node3D.new()
		ghost.name = "DriftingGhost"
		ghost.position = point
		ghost.add_to_group("fear_ghost_scenery")
		scenery.add_child(ghost)
		ghosts.append(ghost)
		_ghost_origins.append(point)
		for part in 2:
			var mesh := MeshInstance3D.new()
			mesh.mesh = robe_mesh if part == 0 else hood
			mesh.position.y = 0.0 if part == 0 else 0.8
			mesh.material_override = cloth
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			ghost.add_child(mesh)
			decor_instances += 1
		# Dark hood aperture and violet eyes face back toward the arriving player.
		_box(ghost,"HollowFace",Vector3(0,0.83,0.40),Vector3(0.53,0.62,0.07),_dark)
		for side in [-1.0,1.0]:
			_box(ghost,"GhostEye",Vector3(side*0.15,0.93,0.45),Vector3(0.09,0.15,0.035),_violet)
