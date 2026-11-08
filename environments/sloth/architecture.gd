extends Node3D
## Runtime Sloth architecture. Built before the director's synchronous nav bake.
## Rendering uses a private fixed seed; it never consumes gameplay randomness.
const STONE = preload("res://environments/sloth/stone.gdshader")
var mats: Dictionary = {}
var environment: Environment
var halo: Node3D
var floaters: Array[Dictionary] = []
var _cover_serial := 0
## Scenic modules never create bodies, even if their reusable authoring calls
## request a solid mesh. They cannot leave nav islands or queued-deletion walls.
var _scenery_building := false

func _ready() -> void:
	_materials()
	_lighting()
	_clouds()
	_scenery_building = true
	_bridge()
	_sanctuary_surround()
	_great_halo()
	_rest_garden()
	_distant_architecture()
	_scenery_building = false
	_boss_arena()
	_boss_combat_covers()
	_boss_safety()
	_register_navigation(self)

func _materials() -> void:
	for pair in [["ivory","e4e1d6"],["chalk","c6cbd0"],["base","8997a1"],["dark","465966"],["floor","bdc4c4"],["edge","6d818e"]]:
		var m := ShaderMaterial.new()
		m.shader = STONE
		m.set_shader_parameter("stone_color",Color(pair[1]))
		mats[pair[0]] = m
	for key in ["floor", "bridge_floor"]:
		var m := ShaderMaterial.new()
		m.shader = preload("res://environments/sloth/floor.gdshader")
		m.set_shader_parameter("stone_color",Color("bdc4c4") if key=="floor" else Color("e4e1d6"))
		m.set_shader_parameter("radial_mode",key=="floor")
		mats[key] = m
	for pair in [["bronze","94816a"],["ink","344954"],["gold","d5aa66"]]:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(pair[1])
		m.metallic = 0.48
		m.roughness = 0.4
		mats[pair[0]] = m
	var warm := StandardMaterial3D.new()
	warm.albedo_color = Color("ffe2a3")
	warm.emission_enabled = true
	warm.emission = Color("ffcc7b")
	warm.emission_energy_multiplier = 2.4
	mats["warm"] = warm
	var cold := StandardMaterial3D.new()
	cold.albedo_color = Color("bddee6")
	cold.emission_enabled = true
	cold.emission = Color("a8d5e0")
	cold.emission_energy_multiplier = 0.65
	mats["cold"] = cold

func _group(title: String) -> Node3D:
	var g := Node3D.new()
	g.name = title
	if _scenery_building:
		g.add_to_group("sloth_scenery")
	add_child(g)
	return g

func _mesh(mesh: Mesh, at: Vector3, material: String, parent: Node3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = at
	mi.material_override = mats[material]
	parent.add_child(mi)
	return mi

func _box(at: Vector3, size: Vector3, material: String, parent: Node3D, solid := false) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = size
	var mi := _mesh(b,at,material,parent)
	if solid and not _scenery_building:
		var shape := BoxShape3D.new()
		shape.size = size
		_collider(mi,shape)
	return mi

func _cylinder(at: Vector3, radius: float, height: float, material: String, parent: Node3D, solid := false, top := -1.0, segments := 64) -> MeshInstance3D:
	var b := CylinderMesh.new()
	b.bottom_radius = radius
	b.top_radius = radius if top < 0 else top
	b.height = height
	b.radial_segments = segments
	var mi := _mesh(b,at,material,parent)
	if solid and not _scenery_building:
		var shape := CylinderShape3D.new()
		shape.radius = radius
		shape.height = height
		_collider(mi,shape)
	return mi

func _collider(parent: Node3D, shape: Shape3D) -> void:
	var body := StaticBody3D.new()
	var c := CollisionShape3D.new()
	c.shape = shape
	body.add_child(c)
	parent.add_child(body)

func _ring(at: Vector3, radius: float, thickness: float, material: String, parent: Node3D, vertical := false) -> MeshInstance3D:
	var t := TorusMesh.new()
	t.inner_radius = radius - thickness * 0.5
	t.outer_radius = radius + thickness * 0.5
	t.rings = 128
	t.ring_segments = 8
	var mi := _mesh(t,at,material,parent)
	if thickness < 0.2:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if vertical: mi.rotation_degrees.x = 90
	return mi

func _rod(a: Vector3, b: Vector3, width: float, material: String, parent: Node3D) -> MeshInstance3D:
	var r := _box((a+b)*0.5,Vector3(width,width,a.distance_to(b)),material,parent)
	r.look_at_from_position((a+b)*0.5,b,Vector3.RIGHT if absf((b-a).normalized().y)>0.99 else Vector3.UP)
	return r

func _lighting() -> void:
	var world := WorldEnvironment.new()
	world.name = "Atmosphere"
	environment = Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := ShaderMaterial.new()
	sm.shader = preload("res://environments/sloth/sanctum_sky.gdshader")
	sky.sky_material = sm
	sky.radiance_size = Sky.RADIANCE_SIZE_256
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("9aafc1")
	environment.ambient_light_energy = 0.32
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.tonemap_exposure = 0.85
	environment.fog_enabled = true
	environment.fog_light_color = Color("bacbd4")
	environment.fog_density = 0.00085
	environment.fog_sky_affect = 0.16
	environment.fog_aerial_perspective = 0.32
	environment.ssao_enabled = true
	environment.ssao_radius = 3.0
	environment.ssao_intensity = 1.5
	environment.glow_enabled = true
	environment.glow_intensity = 0.36
	world.environment = environment
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.name = "LateMorningSun"
	sun.rotation_degrees = Vector3(-32,-38,0)
	sun.light_color = Color("fff0d4")
	sun.light_energy = 1.05
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 280.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.shadow_bias = 0.08
	sun.shadow_normal_bias = 1.5
	# A fixed PCF shadow avoids the noisy wide PCSS penumbra on pale paving.
	sun.light_angular_distance = 0.0
	add_child(sun)

func _clouds() -> void:
	var g := _group("CloudSea")
	var p := PlaneMesh.new()
	p.size = Vector2(18000,18000)
	var mi := MeshInstance3D.new()
	mi.mesh = p
	mi.position.y = -46
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://environments/sloth/cloud_sea.gdshader")
	var noise := FastNoiseLite.new()
	noise.seed = 11042026
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.014
	noise.fractal_octaves = 5
	var texture := NoiseTexture2D.new()
	texture.width = 512
	texture.height = 512
	texture.seamless = true
	texture.noise = noise
	mat.set_shader_parameter("cloud_noise",texture)
	mi.material_override = mat
	g.add_child(mi)

func _bridge() -> void:
	var g := _group("ArrivalBridge")
	_box(Vector3(0,-1.42,78),Vector3(14,2.40,72),"base",g)
	# The former long arrival walk remains a monumental broken approach outside
	# the short combat disk. It is scenery, with no player or navigation surface.
	var paving := _box(Vector3(0,-0.08,78),Vector3(14,0.22,72),"bridge_floor",g,true)
	paving.name = "ApproachFloor"
	paving.add_to_group("WalkableFloors")
	for s in [-1.0,1.0]:
		_box(Vector3(s*7.0,0.48,78),Vector3(0.45,0.96,72),"chalk",g,true)
		_box(Vector3(s*7.0,1.13,78),Vector3(0.55,0.12,72),"ivory",g)
		for i in range(6):
			var z := 51.0+i*11.0
			_box(Vector3(s*7.0,0.85,z),Vector3(0.82,1.7,0.85),"ivory",g)
			_box(Vector3(s*7.0,1.74,z),Vector3(0.57,0.07,0.60),"cold",g)
			_box(Vector3(s*5.5,-10,z),Vector3(1.3,20,2.0),"base",g)
		# A monumental gate frames the first view without filling the skyline.
		_box(Vector3(s*13,9,98),Vector3(3.0,22,5.0),"ivory",g)
		_box(Vector3(s*13,0.2,98),Vector3(5,0.4,7),"dark",g)
		_box(Vector3(s*13,20.4,98),Vector3(3.7,0.8,5.8),"chalk",g)
	_box(Vector3(0,22.5,98),Vector3(29,2.8,5),"ivory",g)
	_box(Vector3(0,20.95,100.55),Vector3(24,0.09,0.12),"bronze",g)
	_box(Vector3(0,0.1,113.5),Vector3(14,0.2,1),"dark",g,true)

func _sanctuary_surround() -> void:
	var g := _group("SanctuarySurround")
	# A lower broken precinct, separated by an open moat from the combat disk.
	# No continuous same-height floor suggests a long route to the objective.
	_cylinder(Vector3(0,-5.08,0),46,3.84,"base",g)
	_ring(Vector3(0,-3.12,0),44.8,3.0,"chalk",g)
	_cylinder(Vector3(0,-7.0,0),42,6,"dark",g,false,44)
	_cylinder(Vector3(0,-12.0,0),33,5,"base",g,false,42)
	for i in range(48):
		var a := TAU*i/48.0
		# Gaps articulate the monumental outer precinct. The entire module is
		# scenic, so neither roofs nor former rim pieces enter navigation.
		var opening := absf(a) < 0.15 or a > TAU-0.15 \
			or (absf(sin(a))>0.9 and cos(a)*45.7>-6.0 and cos(a)*45.7<16.0)
		if not opening:
			var edge := _box(Vector3(sin(a)*45.7,0.34,cos(a)*45.7),Vector3(5.9,0.68,0.6),"chalk",g,true)
			edge.rotation.y = a
		if i%2==0:
			var rib := _box(Vector3(sin(a)*42,-7.5,cos(a)*42),Vector3(1.3,13,2.0),"chalk",g)
			rib.rotation.y = a
	# The arcade reads as a ring through repetition and large negative spaces.
	for i in range(24):
		var a := TAU*i/24.0
		if cos(a)>0.80: continue
		var pos := Vector3(sin(a)*48,0,cos(a)*48)
		var height := 25.0 + (4.0 if cos(a)<-0.5 else 0.0)
		_box(pos+Vector3(0,-0.5,0),Vector3(6,1,6),"dark",g)
		_box(pos+Vector3(0,height*0.5,0),Vector3(2.6,height,3.4),"ivory",g,true).rotation.y = a
		_box(pos+Vector3(0,2.0,0),Vector3(3.4,4,4.2),"chalk",g).rotation.y = a
		_box(pos+Vector3(0,height,0),Vector3(4,1.3,4.8),"ivory",g).rotation.y = a
		var crown := _box(pos+Vector3(0,height+1.4,0),Vector3(12.8,1.4,4.8),"chalk",g)
		crown.rotation.y = a
		_box(pos+Vector3(0,height*0.5,1.76),Vector3(0.08,height-3,0.06),"bronze",g)
		# Suspended counterweights, frozen before they reach the ground.
		if i%3==0:
			var float_at := pos*1.25+Vector3(0,13,0)
			var b := _box(float_at,Vector3(5,2,5),"ivory",g)
			b.rotation_degrees = Vector3(9,i*13,8)
			floaters.append({"node":b,"origin":float_at,"phase":float(i)})
	# Broad outer terraces keep their original scale beyond the combat rim.
	for side in [-1.0,1.0]:
		var terrace := _box(Vector3(side*43,-1.05,5),Vector3(28,1.9,24),"base",g,true)
		terrace.add_to_group("WalkableFloors")
		_box(Vector3(side*43,0.025,5),Vector3(27.8,0.05,23.7),"ivory",g)
		_box(Vector3(side*56.7,0.55,5),Vector3(0.6,1.1,24),"chalk",g,true)
		for z in [-6.7,16.7]:
			_box(Vector3(side*47,0.55,z),Vector3(20,1.1,0.6),"chalk",g,true)

func _boss_arena() -> void:
	var g := _group("Sanctuary")
	set_meta("combat_radius",25.0)
	_cylinder(Vector3(0,-2.08,0),25,3.84,"base",g)
	var arena_floor := _cylinder(Vector3(0,-0.08,0),25,0.16,"floor",g,true)
	arena_floor.name = "ArenaFloor"
	arena_floor.add_to_group("WalkableFloors")
	# Low central dais reached by shallow, walkable steps.
	for i in range(3):
		_cylinder(Vector3(0,0.075+i*0.15,0),10.5-i*0.65,0.15,"ivory",g)
	# Smooth collision follows the shallow steps, so walking never needs a jump.
	var ramp := _cylinder(Vector3(0,0.23,0),11.3,0.46,"ivory",g,false,8.9)
	ramp.name = "DaisWalkRamp"
	ramp.add_to_group("WalkableFloors")
	# This entire low dais is walkable relief, not an obstacle. Its continuous
	# arena floor below is the navigation proxy; the core's solid body remains
	# navigation geometry and still makes agents route around the objective.
	# Rasterizing a second surface only 0.46 m above it creates a raised
	# slope portal whose 3D closest point can sit behind a grounded actor.
	# Keep the real shallow collision, while agents follow the seamless floor.
	ramp.set_meta("navigation_floor_below",true)
	ramp.create_trimesh_collision()
	ramp.visible = false
	_ring(Vector3(0,0.48,0),8.7,0.07,"bronze",g)
	_cylinder(Vector3(0,0.5,0),3.8,0.12,"dark",g)
	_ring(Vector3(0,0.58,0),3.55,0.065,"cold",g)

	# The continuous short rim visibly ends the combat disk; the huge bridge,
	# outer terraces and halo beyond it remain scenery at their original scale.
	for i in range(48):
		var a := TAU*i/48.0
		var edge := _box(Vector3(sin(a)*24.7,0.34,cos(a)*24.7),Vector3(3.35,0.68,0.6),"chalk",g,true)
		edge.rotation.y = a
	_ring(Vector3(0,0.03,0),23.8,0.08,"bronze",g)

func _great_halo() -> void:
	var g := _group("GreatHalo")
	halo = Node3D.new()
	halo.position = Vector3(0,39,-48)
	g.add_child(halo)
	# Segmented rectangular voussoirs make a silhouette distinct from a smooth torus.
	for i in range(80):
		var a := TAU*i/80.0
		var radius := 36.0
		var at := Vector3(sin(a)*radius,cos(a)*radius,0)
		var slab := _box(at,Vector3(2.70,3.3,2.6),"ivory",halo)
		slab.rotation.z = -a
		if i%5==0:
			var trim := _box(Vector3(sin(a)*36,cos(a)*36,1.34),Vector3(0.12,2.4,0.06),"bronze",halo)
			trim.rotation.z = -a
	_ring(Vector3(0,0,-1.8),39,0.13,"bronze",halo,true)
	_ring(Vector3(0,0,1.45),33.9,0.10,"gold",halo,true)
	# Fixed pendulum; it only moves if the optional motion study is enabled.
	_rod(Vector3(0,73,-48),Vector3(0,29,-48),0.17,"ink",g)
	var weight := _box(Vector3(0,24,-48),Vector3(6.0,6.0,2.2),"chalk",g)
	weight.rotation_degrees.z = 45
	var face := _box(Vector3(0,24,-46.87),Vector3(4.4,4.4,0.08),"dark",g)
	face.rotation_degrees.z = 45
	_box(Vector3(0,24,-46.79),Vector3(0.09,3.8,0.07),"cold",g)
	# Tall separated uprights hold the lower skyline while leaving the ring open.
	for side in [-1.0,1.0]:
		_box(Vector3(side*29,12,-48),Vector3(4,26,5),"ivory",g)
		_box(Vector3(side*29,0,-48),Vector3(7,1,8),"dark",g)
		for j in range(4):
			var slab := _box(Vector3(side*(34+j*4),29+j*6,-49-j*3),Vector3(7,1.2,5),"ivory",g)
			slab.rotation_degrees = Vector3(j*2,side*j*7,side*6)
			floaters.append({"node":slab,"origin":slab.position,"phase":float(j+2)})

func _rest_garden() -> void:
	var g := _group("QuietCourt")
	var center := Vector3(-45,0.06,5)
	_cylinder(center+Vector3(0,0.03,0),6.6,0.05,"dark",g)
	_ring(center+Vector3(0,0.05,0),6.4,0.09,"bronze",g)
	_ring(center+Vector3(0,0.08,0),4.2,0.07,"warm",g)
	# Empty circular seats: a visual proposal only, with no recovery rule attached.
	for i in range(7):
		var a := -2.8+i*0.4
		var at := center+Vector3(sin(a)*5.3,0.33,cos(a)*5.3)
		var seat := _box(at,Vector3(1.9,0.6,0.8),"ivory",g,true)
		seat.rotation.y = a
	var gem := _cylinder(center+Vector3(0,1.15,0),0.5,1.35,"warm",g,false,0.0,4)
	gem.rotation_degrees.z = 180
	floaters.append({"node":gem,"origin":gem.position,"phase":0.0})
	var light := OmniLight3D.new()
	light.position = center+Vector3(0,2.7,0)
	light.light_color = Color("ffd591")
	light.light_energy = 5.5
	light.omni_range = 12
	g.add_child(light)
	# Open roof with deliberately missing slabs, held at the moment of separation.
	for i in range(6):
		var roof := _box(center+Vector3(-2.5+i,8.5+absf(2.5-i)*0.18,0),Vector3(0.85,0.45,13),"ivory",g)
		if i==1 or i==4: roof.position.y += 1.7
	for z in [-5.5,5.5]:
		_box(center+Vector3(-5,4,z),Vector3(0.8,8,0.8),"chalk",g,true)
		_box(center+Vector3(5,4,z),Vector3(0.8,8,0.8),"chalk",g,true)

func _distant_architecture() -> void:
	var g := _group("FloatingPrecincts")
	var rng := RandomNumberGenerator.new()
	rng.seed = 11042026
	# Large satellite sanctums, silhouetted at several depths rather than scattered cubes.
	for item in [[-126.0,-82.0,13.0,1.05],[132.0,-116.0,25.0,1.3],[-217.0,-225.0,38.0,1.15],[224.0,-284.0,55.0,1.8],[-91.0,-277.0,67.0,0.75],[86.0,-320.0,80.0,1.05]]:
		var island := Node3D.new()
		island.position = Vector3(item[0],item[2],item[1])
		island.scale = Vector3.ONE*float(item[3])
		g.add_child(island)
		_box(Vector3(0,-3,0),Vector3(34,5,25),"base",island)
		_box(Vector3(0,0,0),Vector3(36,1,27),"ivory",island)
		_cylinder(Vector3(0,-14,0),2,22,"dark",island,false,16,4).rotation_degrees.y = 45
		for x in [-12.0,-4.0,4.0,12.0]:
			for z in [-8.0,8.0]:
				_box(Vector3(x,11,z),Vector3(2.2,22,2.2),"ivory",island)
		_box(Vector3(0,23,0),Vector3(35,2,25),"chalk",island)
		_box(Vector3(0,26,0),Vector3(25,0.8,16),"ivory",island)
		_ring(Vector3(0,36,0),9,0.65,"chalk",island,true)
		for j in range(7):
			_box(Vector3(19+j*1.6,2+j*1.4,0),Vector3(3,0.5,5),"ivory",island)
	# Vertical fragments underneath and around the precinct create a deep silhouette.
	for i in range(65):
		var a := rng.randf_range(0,TAU)
		var r := rng.randf_range(80,280)
		var at := Vector3(sin(a)*r,rng.randf_range(-25,30),cos(a)*r-95)
		if at.z>30 and absf(at.x)<45: continue
		var shard := _box(at,Vector3(rng.randf_range(2,7),rng.randf_range(3,15),rng.randf_range(2,7)),"chalk",g)
		shard.rotation_degrees = Vector3(rng.randf_range(-14,14),rng.randf_range(0,90),rng.randf_range(-9,9))
		if i%7==0: _rod(at+Vector3(0,-18,0),at,0.055,"dark",g)
	# Unfinished stairs stop in midair; none are on the walkable route.
	for side in [-1.0,1.0]:
		for j in range(19):
			_box(Vector3(side*(62+j*2),5+j*1.45,32-j*2),Vector3(9,0.6,2.5),"ivory",g)

func _register_navigation(parent: Node) -> void:
	# Only real movement collision enters Recast. Floating art has no body and
	# the invisible player-only rim never becomes a phantom navigation wall.
	if parent is StaticBody3D:
		var body := parent as StaticBody3D
		var visual := body.get_parent() as MeshInstance3D
		var walkable := visual != null and visual.is_in_group("WalkableFloors")
		if visual != null and not visual.visible and not walkable:
			body.collision_layer = CollisionLayers.BOUNDARY
			body.collision_mask = CollisionLayers.ACTORS
		else:
			body.collision_layer = CollisionLayers.WORLD
			body.collision_mask = 0
			if visual == null or not visual.get_meta("navigation_floor_below",false):
				body.add_to_group("navigation_geometry")
			if walkable:
				body.add_to_group("sloth_walkable")
				body.set_meta("walkable_surface",true)
			if visual != null and visual.is_in_group("CoverPieces"):
				body.add_to_group("sloth_cover")
				body.set_meta("combat_cover",true)
	for child in parent.get_children():
		_register_navigation(child)

func _cover_markers(at: Vector3, size: Vector3) -> void:
	var holder := get_node_or_null("CoverPoints") as Node3D
	if holder == null:
		holder = _group("CoverPoints")
	for offset in [Vector3(size.x*0.5+0.85,0,0),Vector3(-size.x*0.5-0.85,0,0),Vector3(0,0,size.z*0.5+0.85),Vector3(0,0,-size.z*0.5-0.85)]:
		_cover_serial += 1
		var point := CoverPoint.new()
		point.name = "Cover%03d" % _cover_serial
		point.position = Vector3(at.x,at.y-size.y*0.5,at.z)+offset
		point.add_to_group("cover_point")
		holder.add_child(point)

func _boss_combat_covers() -> void:
	var g := _group("CombatCovers")
	for side in [-1.0,1.0]:
		for z in [-14.0,9.6]:
			var at := Vector3(side*12,0.6,z)
			var dimensions := Vector3(4,1.2,1.2)
			var cover := _box(at,dimensions,"chalk",g,true)
			cover.add_to_group("CoverPieces")
			_cover_markers(at,dimensions)
		var at := Vector3(side*18,1.3,1)
		var dimensions := Vector3(3,2.6,4)
		var cover := _box(at,dimensions,"ivory",g,true)
		cover.add_to_group("CoverPieces")
		_cover_markers(at,dimensions)

func _boss_safety() -> void:
	var g := _group("PlayerRim")
	for i in range(48):
		var a := TAU*i/48.0
		var barrier := _box(Vector3(sin(a)*24.9,15,cos(a)*24.9),Vector3(3.45,30,0.14),"chalk",g,true)
		barrier.rotation.y = a
		barrier.visible = false
