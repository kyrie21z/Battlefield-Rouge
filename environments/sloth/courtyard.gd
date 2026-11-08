extends "res://environments/sloth/architecture.gd"
## Shared two-room runtime shell; no preview camera, HUD, or encounter control.
@export_enum("Stagnant forecourt", "Anchored corridor") var room_index := 0
var room_geometry: Node3D

func _ready() -> void:
	_materials()
	_lighting()
	_clouds()
	_scenery_building = true
	_room_horizon()
	_scenery_building = false
	room_geometry = _group("RoomGeometry")
	_room_floor()
	# The huge precinct is scenery beyond the visibly bounded combat court.
	_scenery_building = true
	_room_arcade()
	_room_quiet_court()
	_scenery_building = false
	_room_covers()
	_register_navigation(self)

func _room_group(title: String) -> Node3D:
	var g := Node3D.new()
	g.name = title
	if _scenery_building:
		g.add_to_group("sloth_scenery")
	room_geometry.add_child(g)
	return g

func _flat_surface(title: String, bounds: Vector4, top: float, parent: Node3D, mass := true) -> MeshInstance3D:
	var center := Vector3((bounds.x+bounds.z)*0.5,top-0.15,(bounds.y+bounds.w)*0.5)
	var dimensions := Vector3(bounds.z-bounds.x,0.3,bounds.w-bounds.y)
	var floor_mesh := _box(center,dimensions,"bridge_floor",parent,true)
	floor_mesh.name = title
	floor_mesh.add_to_group("WalkableFloors")
	floor_mesh.set_meta("surface_kind","flat")
	floor_mesh.set_meta("surface_bounds",bounds)
	floor_mesh.set_meta("surface_top",top)
	if mass:
		# Structural faces stay below the only visible top face.
		_box(center-Vector3(0,1.0,0),Vector3(dimensions.x,1.6,dimensions.z),"base",parent)
	return floor_mesh

func _inclined_box(title: String, a: Vector3, b: Vector3, width: float, thickness: float, material: String, parent: Node3D, solid: bool) -> MeshInstance3D:
	var forward := (b-a).normalized()
	var right := Vector3.UP.cross(forward).normalized()
	var normal := forward.cross(right).normalized()
	var at := (a+b)*0.5-normal*thickness*0.5
	var mi := _box(at,Vector3(width,thickness,a.distance_to(b)),material,parent,solid)
	mi.name = title
	mi.basis = Basis(right,normal,forward)
	return mi

func _ramp(title: String, a: Vector3, b: Vector3, width: float, parent: Node3D, rails := false) -> MeshInstance3D:
	# a/b describe the actual top centerline, not the prism's center. Offsetting by
	# the exact normal keeps both walkable endpoints flush with adjoining floors.
	var slope := _inclined_box(title,a,b,width,0.3,"bridge_floor",parent,true)
	slope.add_to_group("WalkableFloors")
	slope.add_to_group("TerrainRamps")
	slope.set_meta("surface_kind","slope")
	slope.set_meta("surface_a",a)
	slope.set_meta("surface_b",b)
	slope.set_meta("surface_width",width)
	if rails:
		var right := Vector3.UP.cross((b-a).normalized()).normalized()
		for side in [-1.0,1.0]:
			var offset: Vector3 = right*(width*0.5-0.14)*side
			_inclined_box(title+"_Parapet",a+offset+Vector3.UP*1.1,b+offset+Vector3.UP*1.1,0.28,1.1,"chalk",parent,true)
			var barrier := _inclined_box(title+"_Safety",a+offset+Vector3.UP*2.7,b+offset+Vector3.UP*2.7,0.16,2.7,"chalk",parent,true)
			barrier.visible = false
	return slope

func _parapet(at: Vector3, size: Vector3, parent: Node3D, top_floor := 0.0) -> void:
	_box(at+Vector3.UP*(top_floor+0.6),Vector3(size.x,1.2,size.z),"chalk",parent,true)
	var safety_height := 30.0 if absf(at.x)>19.5 or absf(at.z)>23.5 else 3.0
	var safety_size := Vector3(size.x,safety_height,size.z)
	if size.x<size.z: safety_size.x *= 0.55
	else: safety_size.z *= 0.55
	var barrier := _box(at+Vector3.UP*(top_floor+safety_height*0.5),safety_size,"chalk",parent,true)
	barrier.visible = false

func _room_floor() -> void:
	# Only this 40 x 48 m court is playable. The surrounding precinct keeps its
	# monumental proportions without turning every visible arcade into a detour.
	set_meta("combat_bounds",Vector4(-20,-24,20,24))
	var g := _room_group("WalkableShell")
	_flat_surface("EntryCourt",Vector4(-20,8,20,24),0,g)
	_flat_surface("ExitCourt",Vector4(-20,-24,20,-8),0,g)
	for side in [-1.0,1.0]:
		var left: bool = side<0
		_flat_surface("MiddleLeftOuter" if left else "MiddleRightOuter",Vector4(-20,-8,-15,8) if left else Vector4(15,-8,20,8),0,g)
		for interval in [Vector2(-8,-2.5),Vector2(2.5,8)]:
			var inner := Vector4(-15,interval.x,-12,interval.y) if left else Vector4(12,interval.x,15,interval.y)
			_flat_surface(("MiddleLeftInner" if left else "MiddleRightInner")+str(interval.x),inner,0,g)
	_flat_surface("SunkenCourt",Vector4(-12,-4,12,4),-1.2,g)
	_ramp("CenterFrontRamp",Vector3(0,-1.2,4),Vector3(0,0,8),24,g)
	_ramp("CenterBackRamp",Vector3(0,0,-8),Vector3(0,-1.2,-4),24,g)
	_ramp("SunkenLeftRamp",Vector3(-15,0,0),Vector3(-9,-1.2,0),5,g,true)
	_ramp("SunkenRightRamp",Vector3(9,-1.2,0),Vector3(15,0,0),5,g,true)
	_flat_surface("LeftGallery",Vector4(-19,-8,-14,8),3,g,false)
	_flat_surface("RightGallery",Vector4(14,-8,19,8),4,g,false)
	_ramp("LeftGalleryFrontRamp",Vector3(-16.5,3,8),Vector3(-16.5,0,20),5,g,true)
	_ramp("LeftGalleryBackRamp",Vector3(-16.5,0,-20),Vector3(-16.5,3,-8),5,g,true)
	_ramp("RightGalleryFrontRamp",Vector3(16.5,4,8),Vector3(16.5,0,20),5,g,true)
	_ramp("RightGalleryBackRamp",Vector3(16.5,0,-20),Vector3(16.5,4,-8),5,g,true)
	_ramp("CrossCourtBridge",Vector3(-14,3,-1),Vector3(14,4,-1),4,g,true)
	for side in [-1.0,1.0]:
		var upper := 3.0 if side<0 else 4.0
		_parapet(Vector3(side*19,0,0),Vector3(0.28,0,16),g,upper)
		for interval in [Vector2(-8,-3),Vector2(1,8)]:
			_parapet(Vector3(side*14,0,(interval.x+interval.y)*0.5),Vector3(0.28,0,interval.y-interval.x),g,upper)
		for interval in [Vector2(-8,-2.5),Vector2(2.5,8)]:
			_parapet(Vector3(side*12.15,0,(interval.x+interval.y)*0.5),Vector3(0.3,0,interval.y-interval.x),g)
		# A visible low rim and an actual drop separate fighting space from the
		# floating architecture. The taller invisible part is only dash safety.
		_parapet(Vector3(side*19.7,0,0),Vector3(0.6,0,48),g)
		_parapet(Vector3(0,0,side*23.7),Vector3(40,0,0.6),g)
		for z in [-18.0,0.0,18.0]:
			_box(Vector3(side*18,-6,z),Vector3(1.5,11,2),"dark",g)

func _room_arcade() -> void:
	var g := _room_group("Arcade")
	for side in [-1.0,1.0]:
		_box(Vector3(side*41,-4,0),Vector3(20,3,128),"base",g)
	# A broken outer roof and two distinct gallery heights articulate the larger
	# shell; there is no near giant ring competing with the Boss sanctum.
	for side in [-1.0,1.0]:
		for i in range(5):
			var z := 56.0-i*28.0
			var height := (24.0+i%2) if room_index == 0 else (25.0+i%2*2)
			var at := Vector3(side*45,0,z)
			_box(at+Vector3(0,0.35,0),Vector3(4,0.7,4.6),"dark",g)
			_box(at+Vector3(0,height*0.5,0),Vector3(1.8,height,2.8),"ivory",g,true)
			_box(at+Vector3(0,height,0),Vector3(3.2,1,4.0),"chalk",g)
			var beam := _box(at+Vector3(-side*5.5,height+1.2,-9.0),Vector3(13,1.2,22),"ivory",g)
			if i == 1 or (i == 3 and room_index == 0):
				beam.position.y += 1.5
				beam.rotation_degrees.z = side*4
				floaters.append({"node":beam,"origin":beam.position,"phase":float(i)})
			var trim := _box(at+Vector3(-side*0.94,height*0.5,0),Vector3(0.06,height-2,0.14),"bronze",g)
			trim.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# The entrance is lower than the eventual Boss landmark; the exit is a clean
	# direction marker visible from both the lowered court and upper galleries.
	for z in [62.0,-62.0]:
		var height := 19.0 if z>0 else 20.0
		for x in [-10.0,10.0]:
			_box(Vector3(x,height*0.5,z),Vector3(3,height,4),"ivory",g,true)
			_box(Vector3(x,0.3,z),Vector3(4,0.6,5),"dark",g)
		_box(Vector3(0,height+0.8,z),Vector3(23,1.6,4),"chalk",g)
		var marker := _box(Vector3(0,height-0.1,z+2.04),Vector3(11,0.08,0.08),"cold",g)
		marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Sparse inner beams and floating blocks establish three sequential spaces.
	for z in [34.0,-32.0]:
		for side in [-1.0,1.0]:
			_box(Vector3(side*18,12,z),Vector3(5,1.1,7),"chalk",g)
			_box(Vector3(side*18,8.5,z),Vector3(1.0,6,1.4),"ivory",g)
	if room_index == 1:
		for z in [34.0,6.0,-22.0,-50.0]:
			_box(Vector3(-17.5,18.2,z),Vector3(24,1.1,2.3),"ivory",g)
			_box(Vector3(17.5,18.6,z),Vector3(24,1.1,2.3),"chalk",g)
			var fragment := _box(Vector3(0,20.7,z),Vector3(9,0.8,2.2),"ivory",g)
			fragment.rotation_degrees.z = 7
			floaters.append({"node":fragment,"origin":fragment.position,"phase":z})
	else:
		for side in [-1.0,1.0]:
			for i in range(5):
				var fragment := _box(Vector3(side*(53+i*2.5),12+i*2.0,28-i*15.0),Vector3(7,0.9,6),"ivory",g)
				fragment.rotation_degrees = Vector3(4,side*11,side*7)
				floaters.append({"node":fragment,"origin":fragment.position,"phase":float(i)})
	# Oblique frozen counterweights remain outside all required walking paths.
	for side in [-1.0,1.0]:
		for i in range(3):
			var slab := _box(Vector3(side*(43+i*2),8+i*2.2,-43),Vector3(2.5,0.9,6),"chalk",g)
			slab.rotation_degrees.z = side*(9-i*3)

func _cover(at: Vector3, size: Vector3, material: String, title: String) -> void:
	var g := room_geometry.get_node("Covers") as Node3D
	var piece := _box(at,size,material,g,true)
	piece.name = title
	piece.add_to_group("CoverPieces")
	piece.set_meta("cover_role","partial" if size.y<1.7 else "full")
	piece.set_meta("cover_height",size.y)
	_cover_markers(at,size)
	_box(at+Vector3(0,size.y*0.5+0.035,0),Vector3(size.x+0.12,0.07,size.z+0.12),"ivory",g)

func _room_covers() -> void:
	_room_group("Covers")
	# Full-size cover is rearranged around the old 22/24 m objective run-in;
	# it is not scaled with the scenery. The x=0 route stays unobstructed.
	for side in [-1.0,1.0]:
		_cover(Vector3(side*13.5,0.6,5.4),Vector3(2,1.2,1),"chalk","EntryLow_%s" % side)
		_cover(Vector3(side*7,0.6,-11.8),Vector3(2,1.2,1),"chalk","ExitLow_%s" % side)
		var lower_x: float = side*8.5 if room_index==1 else -8.5
		if room_index==1 or side<0:
			_cover(Vector3(lower_x,-0.6,0 if room_index==1 else -0.3),Vector3(2,1.2,1),"chalk","SunkenLow_%s" % side)
		_cover(Vector3(side*17,1.3,-1.5),Vector3(2.5,2.6,3),"ivory","SideFull_%s" % side)
		_cover(Vector3(side*8,0.6,-20),Vector3(3,1.2,1),"chalk","RearLow_%s" % side)
		var upper := 3.0 if side<0 else 4.0
		_cover(Vector3(side*18.2,upper+0.6,5),Vector3(1.2,1.2,1),"chalk","GalleryLow_%s" % side)
	if room_index==1:
		# Offset tall cover offers another angle without blocking the direct run.
		_cover(Vector3(5,-0.1,-2),Vector3(2,2.2,1.5),"ivory","SideDetour")

func _room_quiet_court() -> void:
	var g := _room_group("QuietCourt")
	var center := Vector3(-36,0,-57)
	_ring(center+Vector3(0,0.1,0),3.5,0.09,"bronze",g)
	_ring(center+Vector3(0,0.11,0),2.9,0.07,"warm" if room_index == 1 else "cold",g)
	for i in range(3):
		_box(center+Vector3(-4.1,0.32,-3+i*3),Vector3(1.2,0.64,2.0),"ivory",g,true)
	for z in [-61.5,-52.5]:
		_box(Vector3(-42.2,4,z),Vector3(0.8,8,0.8),"chalk",g,true)
	for i in range(5):
		var roof := _box(center+Vector3(-4.1+i*2.0,8.3,0),Vector3(1.6,0.5,11),"ivory",g)
		if i==2: roof.position.y += 0.9
	if room_index == 1:
		var gem := _cylinder(center+Vector3(0,1.5,0),0.4,1.0,"warm",g,false,0,4)
		gem.rotation_degrees.z = 180
		floaters.append({"node":gem,"origin":gem.position,"phase":0.0})
		var light := OmniLight3D.new()
		light.position = center+Vector3(0,2.4,0)
		light.light_color = Color("ffd291")
		light.light_energy = 3.8
		light.omni_range = 10
		g.add_child(light)

func _room_horizon() -> void:
	var g := _group("HorizonPrecincts")
	for item in [[-115.0,-100.0,3.0,0.9],[120.0,-150.0,12.0,1.1],[-170.0,-220.0,20.0,0.8],[180.0,-290.0,35.0,1.15]]:
		var island := Node3D.new()
		island.position = Vector3(item[0],item[2],item[1])
		island.scale = Vector3.ONE*float(item[3])
		g.add_child(island)
		_box(Vector3(0,-2,0),Vector3(24,4,20),"base",island)
		_cylinder(Vector3(0,-11,0),1.8,16,"dark",island,false,11,4).rotation_degrees.y = 45
		for x in [-9.0,0.0,9.0]:
			for z in [-6.5,6.5]:
				_box(Vector3(x,8,z),Vector3(1.6,16,1.6),"chalk",island)
		_box(Vector3(0,16.8,0),Vector3(26,1.6,21),"ivory",island)
		for i in range(4):
			_box(Vector3(16+i*2.0,2.0+i*1.2,-1),Vector3(3,0.5,5),"ivory",island)
	for side in [-1.0,1.0]:
		for i in range(12):
			_box(Vector3(side*(67+i*2.5),-2+i*1.4,62-i*7),Vector3(7,0.6,3.4),"chalk",g)
		for i in range(8):
			var fragment := _box(Vector3(side*(64+i*13),-14+i*3,-20-i*25),Vector3(3.5,8+i,4),"base",g)
			fragment.rotation_degrees = Vector3(i*3,side*i*11,-side*6)
	for side in [-1.0,1.0]:
		_box(Vector3(side*24,24,-310),Vector3(5,48,6),"chalk",g)
	_box(Vector3(0,49,-310),Vector3(52,3,6),"ivory",g)
