class_name FearWispVisual
extends Node3D
## Original shroud, expressive eyes and a continuous calm-to-maw transformation.
static var _shroud: ArrayMesh
static var _sphere: SphereMesh
static var _fang: CylinderMesh
static var _rim: TorusMesh
static var _tongue_mesh: ArrayMesh
static var _white: StandardMaterial3D
static var _dark: StandardMaterial3D
static var _lip: StandardMaterial3D
static var _ivory: StandardMaterial3D
var cloth: ShaderMaterial
var mouth: Node3D
var teeth: Node3D
var tongue: Node3D
var eyes: Array[Node3D] = []
var pupils: Array[MeshInstance3D] = []
var fang_meshes: Array[MeshInstance3D] = []
var tongue_material: ShaderMaterial
var threat := 0.0
var visual_time := 0.0

static func _material(color: Color, glow := 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.6
	mat.emission_enabled = glow > 0
	mat.emission = color
	mat.emission_energy_multiplier = glow
	return mat

static func prepare() -> void:
	if _shroud != null: return
	_sphere = SphereMesh.new()
	_sphere.radius = 1.0
	_sphere.height = 2.0
	_sphere.radial_segments = 20
	_sphere.rings = 12
	_fang = CylinderMesh.new()
	_fang.top_radius = 0
	_fang.bottom_radius = 0.12
	_fang.height = 0.65
	_fang.radial_segments = 8
	_rim = TorusMesh.new()
	_rim.inner_radius = 0.91
	_rim.outer_radius = 1.0
	_rim.rings = 32
	_rim.ring_segments = 8
	_white = _material(Color(0.83,0.76,1.0),0.25)
	_dark = _material(Color(0.018,0.012,0.045))
	_lip = _material(Color(0.57,0.34,0.86),0.03)
	_ivory = _material(Color(0.93,0.88,0.98))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(0)
	for ring in 32:
		for segment in 48:
			var points: Array[Vector3] = []
			for pair in [Vector2i(ring,segment),Vector2i(ring,segment+1),Vector2i(ring+1,segment+1),Vector2i(ring+1,segment)]:
				var a: float = TAU*pair.y/48.0
				var y: float = 0.56-pair.x/32.0
				var radius := 0.34*sqrt(maxf(0.0,1.0-pow((y-0.17)/0.39,2.0))) if y > 0.17 else 0.34+0.03*pow((0.17-y)/0.61,2)
				var hem := sin(a*5.0)*0.085 if pair.x == 32 else 0.0
				points.append(Vector3(sin(a)*radius,y+hem,cos(a)*radius))
			for index in [0,1,2,0,2,3]: st.add_vertex(points[index])
	st.generate_normals()
	_shroud = st.commit()
	st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(0)
	for ring in 16:
		for segment in 12:
			var vertices: Array[Vector3] = []
			for pair in [Vector2i(ring,segment),Vector2i(ring,segment+1),Vector2i(ring+1,segment+1),Vector2i(ring+1,segment)]:
				var t: float = pair.x/16.0
				var a: float = pair.y*TAU/12.0
				var center := _tongue_point(t)
				var tangent := (_tongue_point(t+0.01)-_tongue_point(t-0.01)).normalized()
				var side := tangent.cross(Vector3.UP).normalized()
				var normal := side.cross(tangent).normalized()
				var radius := lerpf(0.18,0.025,t)
				vertices.append(center+(side*cos(a)+normal*sin(a)*0.65)*radius)
			for index in [0,1,2,0,2,3]: st.add_vertex(vertices[index])
	st.generate_normals()
	_tongue_mesh = st.commit()

func _mesh(parent: Node3D, shape: Mesh, material: Material, point: Vector3, dimensions: Vector3) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.mesh = shape
	mesh.material_override = material
	mesh.position = point
	mesh.scale = dimensions
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mesh)
	return mesh

func _ready() -> void:
	prepare()
	cloth = ShaderMaterial.new()
	cloth.shader = preload("res://actors/enemy/fear/wisp_shroud.gdshader")
	_mesh(self,_shroud,cloth,Vector3.ZERO,Vector3.ONE)
	for side in [-1.0,1.0]:
		var eye := Node3D.new()
		eye.position = Vector3(side*0.13,0.19,-0.29)
		add_child(eye)
		eyes.append(eye)
		_mesh(eye,_sphere,_white,Vector3.ZERO,Vector3(0.085,0.12,0.055))
		pupils.append(_mesh(eye,_sphere,_dark,Vector3(0,0,-0.043),Vector3(0.047,0.082,0.028)))
	mouth = Node3D.new()
	mouth.name = "TransformingMaw"
	add_child(mouth)
	_mesh(mouth,_sphere,_dark,Vector3(0,0,0.35),Vector3(0.87,0.87,0.3))
	var lip := _mesh(mouth,_rim,_lip,Vector3.ZERO,Vector3.ONE)
	lip.rotation.x = PI*0.5
	teeth = Node3D.new()
	teeth.name = "Fangs"
	mouth.add_child(teeth)
	for side in [-1.0,1.0]:
		for upper in [false,true]:
			# Root stays embedded at the inner lip; only the inward length grows.
			var socket := Node3D.new()
			socket.position = Vector3(side*0.48,0.79 if upper else -0.79,0.015)
			socket.rotation.z = side*(-0.10 if upper else 0.12)
			teeth.add_child(socket)
			var tooth := _mesh(socket,_fang,_ivory,Vector3.ZERO,Vector3(0.8,1.0,0.8))
			if upper: tooth.rotation.z = PI
			tooth.set_meta("upper",upper)
			fang_meshes.append(tooth)
	tongue = Node3D.new()
	tongue.name = "CurledTongue"
	mouth.add_child(tongue)
	tongue_material = ShaderMaterial.new()
	tongue_material.shader = preload("res://actors/enemy/fear/wisp_tongue.gdshader")
	_mesh(tongue,_tongue_mesh,tongue_material,Vector3.ZERO,Vector3.ONE)
	advance(0.0,0.0,false)

func advance(delta: float, value: float, lunging: bool) -> void:
	visual_time += delta
	threat = smoothstep(0.0,1.0,clampf(value,0.0,1.0))
	cloth.set_shader_parameter("visual_time",visual_time)
	cloth.set_shader_parameter("threat",threat)
	tongue_material.set_shader_parameter("visual_time",visual_time)
	position.y = sin(visual_time*4.2)*0.035
	rotation.x = -threat*(0.18 if lunging else 0.08)
	var blink := 0.15 if fmod(visual_time,3.7) > 3.58 and threat < 0.1 else 1.0
	for index in 2:
		var side := -1.0 if index == 0 else 1.0
		eyes[index].position = Vector3(side*lerpf(0.13,0.21,threat),lerpf(0.19,0.48,threat),lerpf(-0.29,-0.39,threat))
		eyes[index].scale = Vector3(1.0+threat*0.35,blink+threat*0.25,1.0+threat*0.7)
		pupils[index].scale = Vector3(0.047,0.082,0.028)*lerpf(1.0,0.12,threat)
	mouth.position = Vector3(0,lerpf(-0.11,-0.08,threat),lerpf(-0.39,-0.44,threat))
	mouth.scale = Vector3(lerpf(0.12,0.30,threat),lerpf(0.035,0.39,threat),0.12)
	teeth.visible = threat > 0.1
	for tooth in fang_meshes:
		var upper := bool(tooth.get_meta("upper"))
		var length := (0.56 if upper else 0.34)*smoothstep(0.1,0.65,threat)
		tooth.position.y = (-0.5 if upper else 0.5)*length
		tooth.scale.y = maxf(0.001,length/0.65)
	tongue.visible = threat > 0.15
	tongue.scale = Vector3.ONE*threat

static func _tongue_point(t: float) -> Vector3:
	return Vector3(t*t*0.95,-0.52+sin(t*PI*0.7)*0.32,-0.10-t*1.4)
