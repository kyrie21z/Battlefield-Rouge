class_name WrathSpireVisual
extends WrathVisual
## The six porcelain plates, four gun bays and flames share the spinning waist.

const PORCELAIN := preload("res://actors/boss/wrath_spire/spire_surface.gdshader")
const FIRE := preload("res://actors/boss/wrath_spire/spire_flame.gdshader")
const WAIST_HEIGHT := 2.08
const GUN_COUNT := 4
const GUN_RETRACT_SECONDS := 0.18

class GunPod:
	var socket: Node3D
	var hatch: Node3D
	var aim: Node3D
	var barrel: Node3D
	var muzzle: Marker3D
	var flash: MeshInstance3D
	var recoil := 0.0

var speed_factor := 1.0
var molten := 0.0
var deployment := 0.0
var _charge := 0.0
var _spin_speed := 0.0
var _hull: Node3D
var _waist: Node3D
var _crown: Node3D
var _ceramic: ShaderMaterial
var _fire: ShaderMaterial
var _iron: StandardMaterial3D
var _edge_iron: StandardMaterial3D
var _muzzle_light: StandardMaterial3D
var _plates: Array[Node3D] = []
var _teeth: Array[Node3D] = []
var _pods: Array[GunPod] = []
var _sparks: GPUParticles3D

func _build() -> void:
	if _built:
		return
	kind = 2
	super._build()
	# The hidden crystal rig still supplies the pooled death fragments.
	model.scale = Vector3.ONE * 2.6
	model.hide()
	_outfit.hide()
	if animation != null:
		animation.stop()

	_ceramic = _surface(Color(0.53, 0.11, 0.07), false)
	_iron = _material(Color(0.105, 0.092, 0.096), 0.45, 0.58)
	_edge_iron = _material(Color(0.27, 0.22, 0.20), 0.52, 0.50)
	_muzzle_light = _material(Color(1.0, 0.73, 0.29), 0.0, 1.0)
	_muzzle_light.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_muzzle_light.emission_enabled = true
	_muzzle_light.emission = Color(1.0, 0.39, 0.08)
	_muzzle_light.emission_energy_multiplier = 3.0
	_fire = ShaderMaterial.new()
	_fire.shader = FIRE

	_hull = _pivot(self, "SpireHull", Vector3(0, 0.07, 0))
	_build_spindle()
	_build_crown()
	_waist = _pivot(_hull, "RotatingWaist", Vector3.UP * WAIST_HEIGHT)
	_build_waist()
	_build_guns()
	_build_sparks()

func _build_spindle() -> void:
	var painted_iron := _surface(Color(0.15, 0.125, 0.122), true)
	var profile := PackedVector2Array([
		Vector2(0.018, 0.04), Vector2(0.47, 0.62), Vector2(0.49, 0.72),
		Vector2(0.73, 0.72), Vector2(0.87, 1.12), Vector2(0.92, 1.17),
		Vector2(1.20, 1.17), Vector2(1.42, 1.75), Vector2(0.018, 1.75),
	])
	_piece(_hull, _profile_mesh(profile, 12), painted_iron, Vector3.ZERO)
	for collar in [Vector3(0.49, 0.65, 0.09), Vector3(0.91, 1.12, 0.11), Vector3(1.37, 1.62, 0.13)]:
		_piece(_hull, _cylinder(collar.x, collar.x - 0.06, collar.z, 12), _edge_iron, Vector3.UP * collar.y)

func _build_crown() -> void:
	_piece(_hull, _cylinder(0.58, 0.92, 0.46, 8), _iron, Vector3.UP * 2.49)
	_piece(_hull, _cylinder(0.65, 0.70, 0.12, 10), _edge_iron, Vector3.UP * 2.66)
	_crown = _pivot(_hull, "BrokenCrown", Vector3.UP * 2.74)
	_piece(_crown, _cylinder(0.69, 0.54, 0.26, 8), _iron, Vector3.ZERO)
	for i in 5:
		var angle := i * TAU / 5.0
		var center := i == 0
		var height := 1.11 if center else 0.48 + 0.12 * float(i % 3)
		var size := 0.33 if center else 0.18
		var crystal := _piece(_crown, _cylinder(0.0, size, height, 5), _crystal,
			Vector3(sin(angle) * 0.39, height * 0.5 + 0.12, cos(angle) * 0.39))
		crystal.rotation.z = 0.15 * sin(angle)
	for i in 3:
		var height := [1.59, 1.20, 1.32][i] as float
		var shard_profile := PackedVector2Array([
			Vector2(0.03, 0.0), Vector2(0.33, 0.0), Vector2(0.47, 0.32),
			Vector2(0.35, height * 0.60), Vector2(0.022, height), Vector2(0.012, height),
		])
		var shard := _piece(_crown, _profile_mesh(shard_profile, 5), _ceramic,
			Vector3([-0.04, -0.63, 0.58][i], [0.53, 0.34, 0.31][i], [-0.23, 0.21, 0.13][i]))
		shard.rotation = Vector3(-0.12, i * 0.88, [0.17, 0.31, -0.33][i])

func _build_waist() -> void:
	var profile := PackedVector2Array([
		Vector2(1.22, -0.46), Vector2(1.56, -0.46), Vector2(1.82, -0.24),
		Vector2(1.82, 0.09), Vector2(1.60, 0.44), Vector2(1.25, 0.52), Vector2(1.18, 0.08),
	])
	var shell := _profile_mesh(profile, 3, -0.485, 0.97, Vector3(0, -0.38, -1.23))
	var tooth := _cylinder(0.012, 0.24, 0.64, 4)
	var flame := _flame_mesh()
	_piece(_waist, _cylinder(1.63, 1.55, 0.18, 12), _iron, Vector3.DOWN * 0.38)
	_piece(_waist, _cylinder(1.28, 1.40, 0.86, 12), _iron, Vector3.ZERO)
	for i in 6:
		var socket := _pivot(_waist, "Armor%d" % i)
		socket.rotation.y = i * TAU / 6.0
		var plate := _pivot(socket, "PorcelainHinge", Vector3(0, -0.38, -1.23))
		_piece(plate, shell, _ceramic, Vector3.ZERO)
		_box(plate, Vector3(0, 0.04, -0.45), Vector3(0.38, 0.15, 0.20), _edge_iron)
		_box(plate, Vector3(0, 0.26, -0.57), Vector3(0.30, 0.23, 0.10), _iron)
		for groove in [-0.08, 0.0, 0.08]:
			_box(plate, Vector3(groove, 0.27, -0.625), Vector3(0.027, 0.15, 0.025), _light)
		_plates.append(plate)
		var tooth_node := _piece(socket, tooth, _edge_iron, Vector3.ZERO)
		tooth_node.rotation = Vector3(-PI * 0.5, 0, PI * 0.25)
		tooth_node.hide()
		_teeth.append(tooth_node)
		var tongue := _piece(socket, flame, _fire, Vector3(-0.23, 0.31, -1.81))
		tongue.rotation.y = 0.42 * float(i % 3)
		tongue.scale = Vector3.ONE * (0.88 + 0.12 * float(i % 3))
		tongue.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _build_guns() -> void:
	var barrel_mesh := _cylinder(0.132, 0.155, 0.49, 8)
	var muzzle_mesh := _cylinder(0.18, 0.18, 0.13, 8)
	var flash_mesh := _flash_mesh()
	for i in GUN_COUNT:
		var pod := GunPod.new()
		pod.socket = _pivot(_waist, "GunBay%d" % i, Vector3(0, -0.18, 0))
		pod.socket.rotation.y = TAU * (float(i) + 0.5) / float(GUN_COUNT)
		_box(pod.socket, Vector3(0, 0.03, -1.61), Vector3(0.49, 0.40, 0.45), _iron)
		for side in [-1.0, 1.0]:
			_box(pod.socket, Vector3(0.18 * side, -0.13, -1.69), Vector3(0.07, 0.09, 0.38), _edge_iron)
		pod.hatch = _pivot(pod.socket, "Hatch", Vector3(0, 0.25, -1.87))
		_box(pod.hatch, Vector3(0, -0.23, 0), Vector3(0.51, 0.47, 0.12), _ceramic)
		_box(pod.hatch, Vector3(0, -0.43, -0.012), Vector3(0.47, 0.09, 0.13), _edge_iron)
		pod.aim = _pivot(pod.socket, "GunSlide", Vector3(0, 0.03, -1.48))
		pod.barrel = _pivot(pod.aim, "Recoil")
		_box(pod.barrel, Vector3(0, 0, -0.03), Vector3(0.32, 0.31, 0.34), _iron)
		_piece(pod.barrel, barrel_mesh, _edge_iron, Vector3(0, 0, -0.22)).rotation.x = -PI * 0.5
		_piece(pod.barrel, muzzle_mesh, _ceramic, Vector3(0, 0, -0.48)).rotation.x = -PI * 0.5
		var bore := _cylinder(0.093, 0.093, 0.008, 8)
		_piece(pod.barrel, bore, _iron, Vector3(0, 0, -0.549)).rotation.x = -PI * 0.5
		pod.muzzle = Marker3D.new()
		pod.muzzle.name = "Muzzle"
		pod.muzzle.position.z = -0.566
		pod.barrel.add_child(pod.muzzle)
		pod.flash = _piece(pod.muzzle, flash_mesh, _muzzle_light, Vector3.ZERO)
		pod.flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pod.flash.hide()
		pod.aim.hide()
		_pods.append(pod)

func _build_sparks() -> void:
	_sparks = GPUParticles3D.new()
	_sparks.name = "SpindleSparks"
	_sparks.position.y = 0.16
	_sparks.amount = 22
	_sparks.lifetime = 0.23
	_sparks.emitting = false
	_sparks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var motion := ParticleProcessMaterial.new()
	motion.direction = Vector3(0, 0.43, 1)
	motion.spread = 28.0
	motion.initial_velocity_min = 3.0
	motion.initial_velocity_max = 7.0
	motion.gravity = Vector3(0, -14, 0)
	motion.scale_min = 0.40
	_sparks.process_material = motion
	var streak := BoxMesh.new()
	streak.size = Vector3(0.032, 0.034, 0.14)
	streak.material = _muzzle_light
	_sparks.draw_pass_1 = streak
	add_child(_sparks)

func drive_combat_pose(delta: float, charge: float, rushing: bool, direction: Vector3,
		guns: float, aim_point: Vector3) -> void:
	_charge = move_toward(_charge, charge, 6.5 * delta)
	var spin_goal := 12.0 + 2.0 * speed_factor if rushing else (3.1 if charge > 0.0 else 0.0)
	_spin_speed = move_toward(_spin_speed, spin_goal, 42.0 * delta)
	_waist.rotate_y(_spin_speed * delta)
	var tilt := Vector3.UP
	if rushing:
		tilt += global_basis.inverse() * direction * 0.20
	_hull.quaternion = _hull.quaternion.slerp(Quaternion(Vector3.UP, tilt.normalized()), minf(1.0, 12.0 * delta))
	_crown.position.y = 2.74 - 0.19 * _charge
	_sparks.emitting = rushing
	if rushing:
		var local_direction := global_basis.inverse() * direction
		_sparks.rotation.y = atan2(-local_direction.x, -local_direction.z)

	deployment = maxf(guns, move_toward(deployment, 0.0, delta / GUN_RETRACT_SECONDS))
	var plates_closed := maxf(_charge, deployment * 0.56)
	for i in _plates.size():
		_plates[i].rotation.x = lerpf(-0.24, 0.0, plates_closed)
		_teeth[i].position = Vector3(0, -0.08, lerpf(-1.43, -2.02, _charge))
		_teeth[i].visible = _charge > 0.22

	for pod in _pods:
		pod.hatch.rotation.x = deployment * 1.50
		pod.aim.visible = deployment > 0.12
		pod.aim.position.z = lerpf(-1.28, -1.93, deployment)
		pod.recoil = move_toward(pod.recoil, 0.0, 1.95 * delta)
		pod.barrel.position.z = pod.recoil
		pod.flash.visible = pod.aim.visible and pod.recoil > 0.065
		if deployment > 0.12 and pod.recoil <= 0.015:
			var aim_direction := pod.aim.global_position.direction_to(aim_point)
			if (-pod.socket.global_basis.z).dot(aim_direction) > 0.16:
				_aim_pod(pod, aim_point)
			else:
				pod.aim.rotation = Vector3.ZERO

func aim_volley_gun(aim_direction: Vector3, aim_point: Vector3, shot: int) -> GunPod:
	var first: GunPod
	var second: GunPod
	var best := -INF
	var next := -INF
	for pod in _pods:
		var score := (-pod.socket.global_basis.z).dot(aim_direction)
		if score > best:
			second = first
			next = best
			first = pod
			best = score
		elif score > next:
			second = pod
			next = score
	var selected := second if shot % 2 == 1 and next > 0.16 else first
	_aim_pod(selected, aim_point)
	return selected

func fire_gun(pod: GunPod) -> void:
	pod.recoil = 0.13
	pod.flash.show()

func _aim_pod(pod: GunPod, point: Vector3) -> void:
	var direction := pod.aim.global_position.direction_to(point)
	if direction.is_zero_approx():
		return
	var up := Vector3.UP if absf(direction.y) < 0.97 else Vector3.FORWARD
	pod.aim.look_at(point, up)

func play_motion(_motion: String) -> void:
	pass

func _process(delta: float) -> void:
	if _dead:
		return
	var actor := get_parent() as Enemy
	var time_scale := 0.0 if actor.boon_stunned else actor.boon_time_scale
	_sparks.speed_scale = time_scale
	_time += delta * time_scale
	var heat := clampf(molten + _charge * 0.46, 0.0, 1.0)
	_ceramic.set_shader_parameter("heat", heat)
	_fire.set_shader_parameter("age", _time)
	_fire.set_shader_parameter("heat", heat)
	_fire.set_shader_parameter("curl", minf(_spin_speed / 20.0, 1.0))
	_light.emission_energy_multiplier = 0.38 + heat * 1.75
	_crystal.set_shader_parameter("emission_strength", 0.18 + heat * 1.28)
	_crystal.set_shader_parameter("inner_glow", 0.07 + heat * 0.54)

func die(point := Vector3.INF, direction := Vector3.FORWARD) -> void:
	super.die(point, direction)
	_sparks.emitting = false
	_sparks.hide()
	_hull.hide()

func _surface(color: Color, fire_livery: bool) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = PORCELAIN
	material.set_shader_parameter("surface_color", color)
	material.set_shader_parameter("fire_livery", fire_livery)
	return material

func _pivot(parent: Node3D, label: String, offset := Vector3.ZERO) -> Node3D:
	var node := Node3D.new()
	node.name = label
	node.position = offset
	parent.add_child(node)
	return node

func _piece(parent: Node3D, mesh: Mesh, material: Material, offset: Vector3) -> MeshInstance3D:
	var piece := MeshInstance3D.new()
	piece.mesh = mesh
	piece.material_override = material
	piece.position = offset
	parent.add_child(piece)
	return piece

func _cylinder(top: float, bottom: float, height: float, segments: int) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = segments
	mesh.rings = 1
	return mesh

func _profile_mesh(profile: PackedVector2Array, segments: int, start := 0.0, sweep := TAU,
		pivot := Vector3.ZERO) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_smooth_group(-1)
	for i in segments:
		var left := start + sweep * float(i) / float(segments)
		var right := start + sweep * float(i + 1) / float(segments)
		for j in profile.size():
			var lower := profile[j]
			var upper := profile[(j + 1) % profile.size()]
			var a := _profile_vertex(lower, left) - pivot
			var b := _profile_vertex(lower, right) - pivot
			var c := _profile_vertex(upper, right) - pivot
			var d := _profile_vertex(upper, left) - pivot
			for vertex in [a, b, c, a, c, d]:
				surface.add_vertex(vertex)
	if sweep < TAU - 0.001:
		for i in range(1, profile.size() - 1):
			for index in [0, i, i + 1]:
				surface.add_vertex(_profile_vertex(profile[index], start) - pivot)
			for index in [0, i + 1, i]:
				surface.add_vertex(_profile_vertex(profile[index], start + sweep) - pivot)
	surface.generate_normals()
	return surface.commit()

func _profile_vertex(point: Vector2, angle: float) -> Vector3:
	return Vector3(sin(angle) * point.x, point.y, -cos(angle) * point.x)

func _flame_mesh() -> ArrayMesh:
	var outline := PackedVector2Array([
		Vector2(-0.15, 0.00), Vector2(-0.20, 0.13), Vector2(-0.17, 0.28),
		Vector2(-0.13, 0.34), Vector2(-0.11, 0.51), Vector2(-0.06, 0.39),
		Vector2(-0.06, 0.27), Vector2(0.00, 0.34), Vector2(0.04, 0.52),
		Vector2(0.15, 0.69), Vector2(0.09, 0.51), Vector2(0.10, 0.36),
		Vector2(0.16, 0.29), Vector2(0.22, 0.37), Vector2(0.20, 0.18),
		Vector2(0.16, 0.08), Vector2(0.11, 0.00),
	])
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var edges := Geometry2D.triangulate_polygon(outline)
	for plane in 2:
		for index in edges:
			var point := outline[index]
			surface.set_uv(Vector2(point.x + 0.5, point.y / 0.69))
			var vertex := Vector3(point.x, point.y, 0).rotated(Vector3.UP, plane * PI * 0.5)
			surface.add_vertex(vertex)
	return surface.commit()

func _flash_mesh() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 12:
		var a := TAU * float(i) / 12.0
		var b := TAU * float(i + 1) / 12.0
		var r1 := 0.17 if i % 2 == 0 else 0.057
		var r2 := 0.17 if i % 2 == 1 else 0.057
		var edge := Vector3(cos(a) * r1, sin(a) * r1, -0.15)
		var next := Vector3(cos(b) * r2, sin(b) * r2, -0.15)
		for point in [Vector3.ZERO, edge, next, Vector3(0, 0, -0.39), next, edge]:
			surface.add_vertex(point)
	surface.generate_normals()
	return surface.commit()
