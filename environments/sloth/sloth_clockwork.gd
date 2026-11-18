class_name SlothClockwork
extends Node3D
## Pale suspended stonework and clock parts are purely scenic. Repeated faces
## use MultiMesh batches, with no collision, navigation or per-piece processing.
var _stone: Material
var _bronze: Material
var _shade: Material
var _light: Material
var _cloud: Material

func build(boss: bool, chamber: int, stone: Material, bronze: Material) -> void:
	_stone = stone
	_bronze = bronze
	_shade = SlothRealm.material(Color("5f6871"),0.31,0.63)
	_light = SlothRealm.material(Color("e8ac50"),0.22,0.31,1.1)
	_cloud = SlothRealm.material(Color("cdd8e0"),0.0,1.0,0.09)
	add_to_group("sloth_scenery")
	_build_clock(boss, chamber)
	_build_arches(boss)
	_build_skyline(chamber)
	_build_inlays(boss)

func _build_clock(boss: bool, chamber: int) -> void:
	var clock := Node3D.new()
	clock.name = "SuspendedMeridian"
	add_child(clock)
	clock.position = Vector3(0,20 if boss else 16.5,-37 if boss else -32)
	clock.rotation = Vector3(-0.16,0.18 if chamber == 0 else -0.22,0.08)
	var radius := 12.0 if boss else 10.0
	SlothRealm.torus(clock,Vector3.ZERO,radius,0.42,_stone).rotation.x = PI * 0.5
	SlothRealm.torus(clock,Vector3(0,0,0.28),radius - 0.22,0.105,_bronze).rotation.x = PI * 0.5
	SlothRealm.torus(clock,Vector3(0,0,0.31),radius - 1.62,0.13,_shade).rotation.x = PI * 0.5
	SlothRealm.torus(clock,Vector3(0,0,0.51),radius - 1.62,0.046,_light).rotation.x = PI * 0.5
	var ticks: Array[Transform3D] = []
	var stations: Array[Transform3D] = []
	for index in 48:
		var angle := float(index) * TAU / 48.0
		var radial := Vector3(sin(angle),cos(angle),0)
		var basis := Basis(Vector3.BACK,-angle)
		ticks.append(Transform3D(basis.scaled_local(Vector3(1,2.4 if index % 4 == 0 else 1,1)),radial * (radius - 0.95) + Vector3.BACK * 0.45))
		if index % 4 == 0:
			stations.append(Transform3D(basis,radial * (radius + 0.25)))
	_batch(clock,"HourMarkers",Vector3(0.14,0.24,0.15),_light,ticks)
	_batch(clock,"StoneHourCaps",Vector3(0.54,1.26,0.56),_stone,stations)
	_trim(clock,Vector3(0,radius-2.1,0),Vector3(0.13,2.65,0.25),_bronze)
	_trim(clock,Vector3(0,-0.9,0),Vector3(0.14,radius+1.8,0.19),_bronze)
	for side in [-1.0,1.0]:
		var hand := _trim(clock,Vector3(side * 1.45,0.93,0.25),Vector3(0.19,4.1,0.27),_shade)
		hand.rotation.z = -side * 0.84
		SlothRealm.line(clock,Vector3(side * (radius + 0.20),1.3,0),Vector3(side * 25,24,2),0.09,_bronze)
	var core := _trim(clock,Vector3(0,-0.95,0.6),Vector3(1.68,2.35,0.55),_bronze)
	core.rotation.z = PI * 0.25
	var jewel := _trim(clock,Vector3(0,-0.95,0.94),Vector3(1.13,1.55,0.14),_light)
	jewel.rotation.z = PI * 0.25
	for side in [-1.0,1.0]:
		var drift := Node3D.new()
		clock.add_child(drift)
		drift.position = Vector3(side * (radius + 4.4),-4.6,-3.8)
		drift.rotation = Vector3(0.15,side * 0.61,-side * 0.2)
		SlothRealm.torus(drift,Vector3.ZERO,3.0,0.2,_stone).rotation.x = PI * 0.5
		SlothRealm.torus(drift,Vector3.BACK * 0.13,2.58,0.045,_bronze).rotation.x = PI * 0.5

func _build_arches(boss: bool) -> void:
	for z in [7.0,-13.0]:
		for side in [-1.0,1.0]:
			var outer: float = side * 17.0
			var height := 11.0 if boss else 9.5
			_trim(self,Vector3(outer,height-0.7,z),Vector3(2.46,4.8,2.64),_stone)
			_trim(self,Vector3(outer,height+0.9,z),Vector3(2.75,0.50,2.90),_bronze)
			for fin in [-1.0,1.0]:
				_trim(self,Vector3(outer+fin*0.72,height-1.1,z+1.35),Vector3(0.16,3.25,0.15),_shade)
			var spine := [
				Vector3(outer,height+1.2,z), Vector3(side*15.0,height+4.8,z),
				Vector3(side*11.0,height+7.7,z), Vector3(side*7.5,height+8.45,z)
			]
			for index in 3:
				var a: Vector3 = spine[index]
				var b: Vector3 = spine[index+1]
				SlothRealm.line(self,a,b,0.62,_stone)
				SlothRealm.line(self,a+Vector3.BACK*0.48,b+Vector3.BACK*0.48,0.065,_bronze)
			_trim(self,spine[-1],Vector3(1.2,0.65,1.32),_shade)
			SlothRealm.line(self,spine[-1],spine[-1] - Vector3.UP * 3.8,0.025,_bronze)
			var lantern := _trim(self,spine[-1] - Vector3.UP * 4.0,Vector3(0.37,0.68,0.37),_light)
			lantern.rotation.z = PI * 0.25

func _build_skyline(chamber: int) -> void:
	for side in [-1.0,1.0]:
		for index in 4:
			var x: float = side * (29.0 + index*5.6)
			var z := -26.0 - index*10.5
			var height := 15.5 + float((index+chamber)%3)*3.0
			var base := Vector3(x,2.3+index*1.8,z)
			_trim(self,base,Vector3(9.8,1.7,6.8),_shade)
			_trim(self,base+Vector3.UP,Vector3(10.3,0.38,7.15),_stone)
			for pillar in [-1.0,1.0]:
				var foot := base+Vector3(pillar*2.7,1.1,0)
				_trim(self,foot+Vector3.UP*height*0.5,Vector3(1.27,height,1.65),_stone)
				_trim(self,foot+Vector3.UP*(height-1.35),Vector3(1.76,0.33,2.14),_bronze)
			_trim(self,base+Vector3.UP*(height+1.2),Vector3(7.7,0.65,2.2),_stone)
			var timepiece := _trim(self,base+Vector3(0,height*0.53,0.25),Vector3(0.84,3.5,0.7),_bronze)
			timepiece.rotation.z = side * 0.18
			var cloud := MeshInstance3D.new()
			var dome := SphereMesh.new()
			dome.radius = 1.0
			dome.height = 2.0
			dome.radial_segments = 16
			dome.rings = 7
			cloud.mesh = dome
			cloud.material_override = _cloud
			cloud.position = Vector3(side*(29.0+index*17.1),-18.0-index*2.0,z+12.0)
			cloud.scale = Vector3(22.0+index*4.0,3.7,17.0)
			cloud.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(cloud)

func _build_inlays(boss: bool) -> void:
	for side in [-1.0,1.0]:
		_trim(self,Vector3(side*2.15,0.028,-1),Vector3(0.055,0.014,35),_bronze)
		_trim(self,Vector3(side*2.33,0.029,-1),Vector3(0.025,0.012,35),_shade)
		for index in 10:
			_trim(self,Vector3(side*2.24,0.030,14.0-index*3.35),Vector3(0.24,0.018,0.11),_bronze)
	if not boss:
		return
	SlothRealm.torus(self,Vector3(0,0.06,-8),5.15,0.033,_bronze)
	SlothRealm.torus(self,Vector3(0,0.045,-8),5.45,0.025,_shade)

func _trim(parent: Node3D, point: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.material_override = mat
	instance.position = point
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	return instance

func _batch(parent: Node3D, label: String, size: Vector3, mat: Material, transforms: Array[Transform3D]) -> void:
	var instance := MultiMeshInstance3D.new()
	instance.name = label
	var mesh := BoxMesh.new()
	mesh.size = size
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.mesh = mesh
	batch.instance_count = transforms.size()
	for index in transforms.size():
		batch.set_instance_transform(index,transforms[index])
	instance.multimesh = batch
	instance.material_override = mat
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
