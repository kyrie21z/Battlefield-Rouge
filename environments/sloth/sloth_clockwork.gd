class_name SlothClockwork
extends Node3D
## This sculpture is built in the live rooms. Only its hands, drive and pendulum
## animate; the masonry, chains and hanging fragments share static batches.
const STALL_PERIOD := 8.4
const START_HAND_ANGLE := 0.26
const STOP_HAND_ANGLE := 0.065

var rings: Array[Node3D] = []
var minute_hand: Node3D
var pendulum: Node3D
var deprived := false
var _time := 0.0
var _reset_motion := false
var _stone: ShaderMaterial
var _ashlar: ShaderMaterial
var _brass: StandardMaterial3D
var _rim: StandardMaterial3D
var _iron: StandardMaterial3D
var _notch: StandardMaterial3D
var _unit_box := BoxMesh.new()
var _parts: Dictionary = {}


func build(boss: bool, chamber: int) -> void:
	_stone = _weathered(Color("d6cbb4"))
	_ashlar = _weathered(Color("9b9383"))
	_brass = SlothRealm.material(Color("af8250"), 0.48, 0.58)
	_rim = SlothRealm.material(Color("d2ae71"), 0.46, 0.44)
	_iron = SlothRealm.material(Color("3a332b"), 0.28, 0.65)
	_notch = SlothRealm.material(Color("c68e3e"), 0.24, 0.45, 0.40)
	add_to_group("sloth_scenery")
	_build_clock(boss, chamber)
	_build_precinct(boss, chamber)
	_finish_batches()


func _weathered(color: Color) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://environments/sloth/stone.gdshader")
	mat.set_shader_parameter("stone_color", color)
	mat.set_shader_parameter("weathered", true)
	return mat


func _build_clock(boss: bool, chamber: int) -> void:
	var clock := _group(self, "SuspendedMeridian", Vector3(0, 17.8 if boss else 14.35, -34.0 if boss else -28.5))
	clock.rotation = Vector3(-0.11, 0.10 if chamber == 0 else -0.15, 0.018)
	var radius := 12.05 if boss else 9.65
	_band(clock, Vector3(0, 0, -0.25), radius - 0.40, radius + 0.52, 1.43, _stone)
	_band(clock, Vector3(0, 0, -0.92), radius - 0.66, radius + 0.16, 0.24, _ashlar)
	_band(clock, Vector3(0, 0, 0.57), radius - 0.72, radius + 0.09, 0.31, _brass)
	_band(clock, Vector3(0, 0, 0.79), radius + 0.01, radius + 0.18, 0.15, _rim)
	_band(clock, Vector3(0, 0, 0.38), radius - 1.71, radius - 0.74, 0.48, _iron)
	_band(clock, Vector3(0, 0, 0.68), radius - 1.84, radius - 1.66, 0.14, _brass)
	_band(clock, Vector3(0, 0, -0.78), radius - 2.42, radius - 2.19, 0.42, _ashlar)
	_build_dial(clock, radius)
	_build_drive(clock, radius)
	_build_pendulum(clock, radius)
	for side: float in [-1.0, 1.0]:
		var bracket := Vector3(side * (radius + 0.35), radius * 0.31, -0.35)
		_box(clock, bracket, Vector3(1.17, 2.22, 2.12), _ashlar, Basis(Vector3.BACK, side * 0.20))
		_pin(clock, bracket + Vector3.BACK * 1.10, 0.27, 0.17, _brass, 10)
		var anchor := Vector3(side * (radius + 12.5), radius + 8.1, -4.5)
		_chain(clock, bracket + Vector3.UP * 0.84, anchor, 0.34)
		_chain(clock, bracket + Vector3.FORWARD * 0.71, anchor + Vector3.FORWARD * 1.15, 0.24)
		_build_anchor(clock, anchor, side)
		var rear := Vector3(side * (radius * 0.65), -radius * 0.73, -1.25)
		var foot := Vector3(side * (radius + 9.4), -radius * 0.51, -6.7)
		_rod(clock, rear, foot, 0.17, _iron)
		_box(clock, foot + Vector3.DOWN * 2.15, Vector3(2.2, 4.95, 2.6), _stone)
		_box(clock, foot + Vector3.UP * 0.12, Vector3(2.65, 0.46, 3.05), _ashlar)


func _build_anchor(clock: Node3D, point: Vector3, side: float) -> void:
	_box(clock, point + Vector3.UP * 0.52, Vector3(3.4, 1.25, 2.8), _ashlar)
	_box(clock, point + Vector3.UP * 1.30, Vector3(4.0, 0.41, 3.25), _stone)
	_box(clock, point + Vector3.UP * 0.06, Vector3(2.90, 0.15, 2.95), _brass)
	_pin(clock, point + Vector3.BACK * 1.47 + Vector3.UP * 0.47, 0.41, 0.13, _iron, 8)
	var turn := point + Vector3(side * 3.86, 3.29, -1.28)
	var end := point + Vector3(side * 7.63, 7.54, -3.13)
	_rod(clock, point + Vector3.UP * 0.91, turn, 1.03, _stone)
	_rod(clock, turn, end, 1.03, _stone)
	_rod(clock, point + Vector3(0, 0.91, 0.56), turn + Vector3.BACK * 0.55, 0.16, _brass)
	_box(clock, end, Vector3(1.55, 1.12, 1.54), _ashlar)


func _build_dial(clock: Node3D, radius: float) -> void:
	for index in 60:
		var angle := PI * 0.5 - float(index) * TAU / 60.0
		var radial := Vector3(cos(angle), sin(angle), 0)
		var major := index % 5 == 0
		var dial_basis := Basis(Vector3.BACK, angle - PI * 0.5)
		_box(clock, radial * (radius - 1.23) + Vector3.BACK * 0.66,
			Vector3(0.145 if major else 0.073, 0.58 if major else 0.27, 0.16),
			_rim if major else _brass, dial_basis)
		if major:
			_box(clock, radial * (radius + 0.23) + Vector3.BACK * 0.57,
				Vector3(0.34, 0.94, 0.45), _ashlar, dial_basis)
			_box(clock, radial * (radius + 0.19) + Vector3.BACK * 0.82,
				Vector3(0.11, 0.59, 0.07), _brass, dial_basis)
			for stagger: float in [-1.0, 1.0]:
				var screw := radial * (radius - 0.43) + dial_basis.x * stagger * 0.22 + Vector3.BACK * 0.79
				_box(clock, screw, Vector3(0.11, 0.11, 0.11), _iron, dial_basis)
	# Raised, isolated stop has just enough light to read against the aged brass.
	_box(clock, Vector3(0, radius - 1.34, 1.02), Vector3(0.27, 0.78, 0.37), _notch)
	_box(clock, Vector3(0, radius - 1.76, 0.69), Vector3(0.54, 0.12, 0.48), _rim)
	for index in 4:
		var cardinal: Vector3 = [Vector3.UP, Vector3.RIGHT, Vector3.DOWN, Vector3.LEFT][index]
		var text := Label3D.new()
		text.name = "CastNumeral"
		text.text = ["XII", "III", "VI", "IX"][index]
		text.pixel_size = 0.021
		text.font_size = 46
		text.outline_size = 0
		text.modulate = Color("debd83")
		text.position = cardinal * (radius - 2.30) + Vector3.BACK * 0.32
		clock.add_child(text)


func _build_drive(clock: Node3D, radius: float) -> void:
	for angle: float in [0.23, 1.18, 2.39, 3.38, 4.57, 5.55]:
		var radial := Vector3(cos(angle), sin(angle), 0)
		_rod(clock, radial * (radius - 0.67) + Vector3.FORWARD * 0.85,
			radial * 0.88 + Vector3.FORWARD * 1.04, 0.25, _iron)
		_rod(clock, radial * (radius - 0.67) + Vector3.FORWARD * 1.16,
			radial * 1.28 + Vector3.FORWARD * 1.36, 0.065, _brass)
	var gap := radius * 0.315
	rings.append(_gear(clock, "WestDrive", Vector3(-gap, -0.26, -0.63), radius * 0.30, 26))
	rings.append(_gear(clock, "EastDrive", Vector3(gap, 0.43, -0.70), radius * 0.265, 23))
	_gear(clock, "Escapement", Vector3(0.80, -radius * 0.45, -0.78), radius * 0.187, 17)
	_pin(clock, Vector3(0, 0, -0.19), 0.94, 1.05, _iron, 16)
	_pin(clock, Vector3(0, 0, 0.43), 0.67, 0.38, _brass, 12)
	var hour := _group(clock, "HourHand", Vector3(0, 0, 0.75))
	hour.rotation.z = 1.05
	_hand(hour, radius * 0.52, 0.50, _brass)
	minute_hand = _group(clock, "StalledMinuteHand", Vector3(0, 0, 1.08))
	minute_hand.rotation.z = START_HAND_ANGLE
	_hand(minute_hand, radius - 1.47, 0.39, _iron)
	_pin(clock, Vector3(0, 0, 1.34), 0.52, 0.38, _rim, 8)
	_pin(clock, Vector3(0, 0, 1.57), 0.24, 0.22, _brass, 8)


func _hand(parent: Node3D, length: float, width: float, metal: Material) -> void:
	_box(parent, Vector3(0, (length - 1.05) * 0.5, 0), Vector3(width, length + 0.36, 0.29), metal)
	_box(parent, Vector3(0, length * 0.41, 0.176), Vector3(width * 0.29, length - 0.40, 0.063), _rim)
	_box(parent, Vector3(0, length - 0.49, 0), Vector3(width * 1.37, 0.94, 0.30), metal)
	_pin(parent, Vector3(0, -1.0, 0.06), width * 1.28, 0.32, metal, 6)


func _gear(parent: Node3D, label: String, point: Vector3, radius: float, teeth: int) -> Node3D:
	var gear := _group(parent, label, point)
	_band(gear, Vector3.ZERO, radius * 0.73, radius, 0.55, _iron)
	_band(gear, Vector3.BACK * 0.33, radius * 0.78, radius * 0.89, 0.19, _brass)
	for index in teeth:
		var angle := float(index) * TAU / teeth
		var radial := Vector3(cos(angle), sin(angle), 0)
		_box(gear, radial * (radius + 0.095), Vector3(0.26, 0.38, 0.48), _brass,
			Basis(Vector3.BACK, angle - PI * 0.5))
	for index in 6:
		var angle := float(index) * TAU / 6
		var radial := Vector3(cos(angle), sin(angle), 0)
		_rod(gear, radial * 0.24, radial * (radius - 0.27), radius * 0.13, _ashlar)
	_pin(gear, Vector3.ZERO, radius * 0.28, 0.54, _iron, 12)
	_pin(gear, Vector3.BACK * 0.34, radius * 0.17, 0.20, _rim, 8)
	return gear


func _build_pendulum(clock: Node3D, radius: float) -> void:
	pendulum = _group(clock, "ShortSwingPendulum", Vector3(0, -radius * 0.37, 0.63))
	var stem := radius * 0.73
	_box(pendulum, Vector3(0, -stem * 0.47, 0), Vector3(0.23, stem, 0.27), _iron)
	_box(pendulum, Vector3(0, -stem * 0.45, 0.173), Vector3(0.086, stem * 0.9, 0.065), _brass)
	for index in 4:
		_box(pendulum, Vector3(0, -stem * (0.2 + index * 0.19), 0),
			Vector3(0.43, 0.13, 0.45), _rim)
	var weight := Vector3(0, -stem, 0.16)
	_pin(pendulum, weight, 1.03, 0.82, _iron, 8)
	_pin(pendulum, weight + Vector3.BACK * 0.44, 0.87, 0.26, _brass, 8)
	_pin(pendulum, weight + Vector3.BACK * 0.61, 0.61, 0.17, _ashlar, 8)
	_box(pendulum, weight + Vector3.BACK * 0.72, Vector3(0.09, 1.12, 0.07), _rim)


func _build_precinct(boss: bool, chamber: int) -> void:
	var precinct := _group(self, "BrokenBelfries", Vector3.ZERO)
	for side: float in [-1.0, 1.0]:
		# The nearer stone piers already exist as real combat geometry.
		for z: float in [-17.0, -7.0, 5.0, 17.0]:
			_dress_pier(precinct, side, z)
		_half_arch(precinct, side, -17.0, 0.52 if chamber == 1 and side > 0.0 else 1.0)
		_half_arch(precinct, side, 5.0, 0.66)
		for tier in 3:
			var origin := Vector3(side * (24.8 + tier * 10.4),
				-4.0 + tier * 5.45 + (1.8 if chamber == 1 and side < 0 else 0.0),
				-9.0 - tier * 18.0 + side * 3.5)
			_belfry(precinct, origin, side, tier, (tier + chamber + (1 if side > 0.0 else 0)) % 3 == 1)
		for index in 7:
			var offset := float(index)
			var point := Vector3(side * (23.8 + offset * 2.93), 4.8 + offset * 0.88, -8.5 - offset * 2.7)
			if index != 3:
				_box(precinct, point, Vector3(2.9, 0.53, 3.2), _stone, Basis(Vector3.BACK, side * offset * 0.038))
				_box(precinct, point + Vector3.DOWN * 0.31, Vector3(2.67, 0.14, 2.97), _ashlar)
		var post := Vector3(side * 6.25, 3.10, -24.85)
		_box(precinct, post, Vector3(1.85, 6.20, 2.55), _stone)
		_box(precinct, post + Vector3.UP * 2.9, Vector3(2.53, 0.58, 2.95), _ashlar)
		_box(precinct, post + Vector3.UP * 0.04 + Vector3.BACK * 1.30, Vector3(0.12, 4.17, 0.085), _brass)
		_rod(precinct, post + Vector3.UP * 3.18, Vector3(side * 3.7, 7.8, -25.0), 0.51, _ashlar)
		_rod(precinct, Vector3(side * 3.7, 7.8, -25.0), Vector3(side * 0.8, 8.65, -25.0), 0.49, _stone)
		for index in 6:
			var z := 13.4 - index * 4.95
			_box(precinct, Vector3(side * 3.9, 0.014, z), Vector3(0.52, 0.016, 0.069), _brass)
	if boss:
		_band(precinct, Vector3(0, 0.029, -8), 5.76, 5.82, 0.012, _rim, Basis(Vector3.RIGHT, PI * 0.5))
		_band(precinct, Vector3(0, 0.024, -8), 6.08, 6.12, 0.009, _brass, Basis(Vector3.RIGHT, PI * 0.5))
	_build_clouds()


func _half_arch(parent: Node3D, side: float, z: float, rise: float) -> void:
	var knees := [
		Vector3(side * 17.0, 7.96, z),
		Vector3(side * 15.65, 10.3 + rise * 0.45, z),
		Vector3(side * (15.0 - rise * 2.1), 11.22 + rise * 2.75, z),
		Vector3(side * (14.4 - rise * 4.3), 11.85 + rise * 3.10, z),
	]
	for i in knees.size() - 1:
		var start: Vector3 = knees[i]
		var end: Vector3 = knees[i + 1]
		_rod(parent, start, end, 0.92, _stone)
		_rod(parent, start + Vector3.BACK * 0.51, end + Vector3.BACK * 0.51, 0.095, _brass)
		_box(parent, end, Vector3(0.91, 0.67, 1.06), _ashlar)
	var end: Vector3 = knees[-1]
	_rod(parent, end, end + Vector3.DOWN * 2.45, 0.047, _iron)
	_box(parent, end + Vector3.DOWN * 2.58, Vector3(0.38, 0.71, 0.36), _brass,
		Basis(Vector3.BACK, side * 0.37))


func _dress_pier(parent: Node3D, side: float, z: float) -> void:
	var x := side * 17.0
	for y: float in [0.27, 1.05, 6.17, 6.83, 7.30]:
		var width := 3.16 if y == 0.27 or y == 6.83 else 2.66
		_box(parent, Vector3(x, y, z), Vector3(width, 0.21, width + 0.19), _ashlar if y < 1.1 else _stone)
		_box(parent, Vector3(x, y + 0.126, z), Vector3(width + 0.05, 0.062, width + 0.24), _brass)
	for df: float in [-0.73, 0.73]:
		_box(parent, Vector3(x - side * 1.275, 3.47, z + df), Vector3(0.095, 4.56, 0.14), _ashlar)
		_box(parent, Vector3(x - side * 1.343, 3.52, z + df), Vector3(0.045, 2.77, 0.075), _brass)
	_box(parent, Vector3(x - side * 1.278, 4.75, z), Vector3(0.07, 1.33, 0.71), _iron)
	_box(parent, Vector3(x - side * 1.337, 4.75, z), Vector3(0.05, 0.92, 0.16), _rim)


func _belfry(parent: Node3D, origin: Vector3, side: float, tier: int, broken: bool) -> void:
	var tower := _group(parent, "Belfry", origin)
	tower.rotation.z = side * (0.045 if tier == 0 else 0.105) * (-1 if broken else 0.45)
	var height := 12.9 + 1.55 * tier
	_box(tower, Vector3(0, -1, 0), Vector3(7.8, 2.0, 5.85), _ashlar)
	_box(tower, Vector3(0, 0.24, 0), Vector3(8.1, 0.49, 6.14), _stone)
	_box(tower, Vector3(0, 0.58, 0), Vector3(7.05, 0.22, 5.38), _brass)
	var belfry_base := height - 4.9
	for x: float in [-2.72, 2.72]:
		for z: float in [-1.85, 1.85]:
			var h := belfry_base if broken and x > 0.0 and z < 0.0 else height
			_box(tower, Vector3(x, h * 0.5 + 0.65, z), Vector3(1.32, h, 1.42), _stone)
			_box(tower, Vector3(x, h + 0.75, z), Vector3(1.78, 0.42, 1.80), _ashlar)
			_box(tower, Vector3(x, h + 0.97, z), Vector3(1.79, 0.09, 1.81), _brass)
			_box(tower, Vector3(x, belfry_base + 0.22, z), Vector3(2.02, 0.32, 2.0), _ashlar)
	for z: float in [-1.85, 1.85]:
		_box(tower, Vector3(0, belfry_base, z), Vector3(6.45, 0.55, 1.42), _ashlar)
		for sign_value: float in [-1.0, 1.0]:
			_rod(tower, Vector3(sign_value * 2.8, belfry_base + 0.6, z),
				Vector3(sign_value * 0.84, height + (0.36 if not broken else -1.40), z), 0.41, _stone)
	if not broken:
		_box(tower, Vector3(0, height + 1.21, 0), Vector3(7.4, 0.90, 5.75), _stone)
		_box(tower, Vector3(0, height + 1.76, 0), Vector3(6.8, 0.30, 5.24), _ashlar)
		_box(tower, Vector3(0, height + 1.96, 0), Vector3(5.12, 0.15, 4.16), _brass)
	else:
		_box(tower, Vector3(-1.87, height + 0.73, 0.08), Vector3(3.78, 0.86, 5.23), _stone,
			Basis(Vector3.BACK, side * 0.14))
		_box(tower, Vector3(3.57, height + 2.83, -1.12), Vector3(2.2, 0.72, 3.3), _ashlar,
			Basis.from_euler(Vector3(0.28, side * 0.31, -side * 0.31)))
	_rod(tower, Vector3(-2.78, height - 0.60, 0), Vector3(2.79, height - 0.60, 0), 0.25, _iron)
	_bell(tower, Vector3(0, height - 2.02, 0))
	_rod(tower, Vector3(0, height - 3.0, 0), Vector3(0, height - 4.2, 0), 0.12, _iron)


func _bell(parent: Node3D, point: Vector3) -> void:
	for data: Vector4 in [Vector4(0.75, 0.53, 0.51, 0.66), Vector4(0.00, 0.99, 0.65, 0.86),
			Vector4(-0.67, 0.38, 0.85, 1.17), Vector4(-0.91, 0.14, 1.16, 1.24)]:
		var part := CylinderMesh.new()
		part.height = data.y
		part.top_radius = data.z
		part.bottom_radius = data.w
		part.radial_segments = 16
		part.cap_bottom = false
		_mesh(parent, "BellCasting", part, _brass, point + Vector3.UP * data.x)
	var clapper := SphereMesh.new()
	clapper.radius = 0.24
	clapper.height = 0.48
	clapper.radial_segments = 10
	clapper.rings = 6
	_mesh(parent, "Clapper", clapper, _iron, point + Vector3.DOWN * 1.08)


func _build_clouds() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(2600, 2600)
	var noise := FastNoiseLite.new()
	noise.seed = 9327
	noise.frequency = 0.028
	var texture := NoiseTexture2D.new()
	texture.width = 128
	texture.height = 128
	texture.seamless = true
	texture.noise = noise
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://environments/sloth/cloud_sea.gdshader")
	mat.set_shader_parameter("cloud_noise", texture)
	_mesh(self, "SeaOfClouds", plane, mat, Vector3(0, -24, 0))


func _process(delta: float) -> void:
	if minute_hand == null:
		return
	_time += delta
	if deprived:
		minute_hand.rotation.z -= delta * 2.10
		pendulum.rotation.z = sin(_time * 4.45) * 0.15
		rings[0].rotation.z += delta * 1.40
		rings[1].rotation.z -= delta * 1.90
		_reset_motion = true
		return
	if _reset_motion:
		_time = 0.0
		_reset_motion = false
	var phase := fposmod(_time, STALL_PERIOD)
	var attempt := smoothstep(0.62, 2.10, phase) * (1.0 - smoothstep(2.72, 3.26, phase))
	var slip := sin((phase - 3.26) * 25.0) * (1.0 - smoothstep(3.26, 3.80, phase)) if phase > 3.26 else 0.0
	minute_hand.rotation.z = lerpf(START_HAND_ANGLE, STOP_HAND_ANGLE, attempt) + slip * 0.039
	rings[0].rotation.z = attempt * -0.24
	rings[1].rotation.z = attempt * 0.27
	pendulum.rotation.z = sin(phase * TAU / STALL_PERIOD) * 0.043


func _group(parent: Node3D, label: String, point: Vector3) -> Node3D:
	var node := Node3D.new()
	node.name = label
	node.position = point
	parent.add_child(node, true)
	return node


func _box(parent: Node3D, point: Vector3, size: Vector3, mat: Material, basis := Basis.IDENTITY) -> void:
	if not _parts.has(parent):
		_parts[parent] = {}
	var by_material: Dictionary = _parts[parent]
	if not by_material.has(mat):
		by_material[mat] = []
	by_material[mat].append(Transform3D(basis * Basis.from_scale(size), point))


func _finish_batches() -> void:
	for parent in _parts:
		for mat in _parts[parent]:
			var transforms: Array = _parts[parent][mat]
			var batch := MultiMesh.new()
			batch.transform_format = MultiMesh.TRANSFORM_3D
			batch.mesh = _unit_box
			batch.instance_count = transforms.size()
			for i in transforms.size():
				batch.set_instance_transform(i, transforms[i])
			var node := MultiMeshInstance3D.new()
			node.name = "MachinedParts"
			node.multimesh = batch
			node.material_override = mat
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			parent.add_child(node, true)
	_parts.clear()


func _rod(parent: Node3D, start: Vector3, finish: Vector3, width: float, mat: Material) -> void:
	var direction := (start - finish).normalized()
	var up := Vector3.FORWARD if absf(direction.y) > 0.98 else Vector3.UP
	_box(parent, (start + finish) * 0.5, Vector3(width, width, start.distance_to(finish) + width * 0.15),
		mat, Basis.looking_at(direction, up))


func _chain(parent: Node3D, start: Vector3, finish: Vector3, width: float) -> void:
	_rod(parent, start, finish, width * 0.34, _iron)
	var direction := (start - finish).normalized()
	var frame := Basis.looking_at(direction, Vector3.UP)
	var links := ceili(start.distance_to(finish) / (width * 1.48))
	for index in links:
		var point := start.lerp(finish, (index + 0.5) / links)
		var basis := frame * Basis(Vector3.BACK, PI * 0.5 if index % 2 == 0 else 0.0)
		for side: float in [-1.0, 1.0]:
			_box(parent, point + basis.x * side * width * 0.39, Vector3(width * 0.20, width * 0.23, width * 1.53), _iron, basis)
			_box(parent, point + basis.z * side * width * 0.71, Vector3(width * 0.87, width * 0.23, width * 0.23), _brass, basis)


func _pin(parent: Node3D, point: Vector3, radius: float, length: float, mat: Material, sides: int) -> void:
	var shape := CylinderMesh.new()
	shape.height = length
	shape.top_radius = radius
	shape.bottom_radius = radius
	shape.radial_segments = sides
	_mesh(parent, "CastHub", shape, mat, point).rotation.x = PI * 0.5


func _band(parent: Node3D, point: Vector3, inner: float, outer: float, depth: float,
		mat: Material, orientation := Basis.IDENTITY) -> void:
	var bevel := minf((outer - inner) * 0.19, depth * 0.29)
	var profile := [
		Vector2(inner, -depth * 0.5 + bevel), Vector2(inner, depth * 0.5 - bevel),
		Vector2(inner + bevel, depth * 0.5), Vector2(outer - bevel, depth * 0.5),
		Vector2(outer, depth * 0.5 - bevel), Vector2(outer, -depth * 0.5 + bevel),
		Vector2(outer - bevel, -depth * 0.5), Vector2(inner + bevel, -depth * 0.5),
	]
	var mesh := SurfaceTool.new()
	mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	mesh.set_smooth_group(-1)
	var segments := 72 if outer > 5.0 else 40
	for index in segments:
		var a := Vector2.from_angle(index * TAU / segments)
		var b := Vector2.from_angle((index + 1) * TAU / segments)
		for side in profile.size():
			var low: Vector2 = profile[side]
			var high: Vector2 = profile[(side + 1) % profile.size()]
			var p0 := Vector3(a.x * low.x, a.y * low.x, low.y)
			var p1 := Vector3(b.x * low.x, b.y * low.x, low.y)
			var p2 := Vector3(b.x * high.x, b.y * high.x, high.y)
			var p3 := Vector3(a.x * high.x, a.y * high.x, high.y)
			for vertex: Vector3 in [p0, p1, p2, p0, p2, p3]:
				mesh.add_vertex(vertex)
	mesh.generate_normals()
	var band := _mesh(parent, "BevelledRing", mesh.commit(), mat, point)
	band.basis = orientation


func _mesh(parent: Node3D, label: String, shape: Mesh, mat: Material, point: Vector3) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = label
	node.mesh = shape
	node.position = point
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node, true)
	return node
