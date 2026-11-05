class_name SlothVisual
extends Node3D
## Red crystal is the shared body. The added silhouettes are geometry, including
## the mantle's missing faces, sewn edges, doubled hood lip and hinged shell.
## This presentation component receives its state; it never reads game systems.

const BODY: PackedScene = preload("res://assets/models/characters/red_crystal_enemy_animated.glb")
const CRYSTAL: ShaderMaterial = preload("res://assets/materials/red_crystal_material_shader.tres")
const CLOTH: Shader = preload("res://assets/materials/sloth_cloth.gdshader")
static var _outfit_templates: Dictionary = {}

var kind := 0
var model: Node3D
var skeleton: Skeleton3D
var animation: AnimationPlayer
var _outfit: Node3D
var _cloth: ShaderMaterial
var _lining: ShaderMaterial
var _metal: StandardMaterial3D
var _edge: StandardMaterial3D
var _dark: StandardMaterial3D
var _light: StandardMaterial3D
var _crystal: ShaderMaterial
var _bones: Array[Dictionary] = []
var _shell: Array[Dictionary] = []
var _time := 0.0
var _cast := 0.0
var _opening := 0.0
var _dead := false
var _death_time := 0.0
var _built := false
var _mantle_open := 0.0
var _mantle: Node3D
var shatter: SlothShatter
var _evade_left := 0.0
var _evade_sign := 1.0
var _evade_origin := Vector3.ZERO
var _evade_rotation := 0.0
var _evade_label: Label3D


func configure(value: int) -> void:
	kind = clampi(value, 0, 2)
	if is_node_ready():
		_build()


func _ready() -> void:
	_build()


func _build() -> void:
	if _built:
		return
	_built = true
	SlothShatter.prepare_templates()
	_cloth = ShaderMaterial.new()
	_cloth.shader = CLOTH
	_cloth.set_shader_parameter("cloth_color", Color(0.025, 0.047, 0.115))
	_lining = ShaderMaterial.new()
	_lining.shader = CLOTH
	_lining.set_shader_parameter("cloth_color", Color(0.07, 0.12, 0.22))
	_lining.set_shader_parameter("sway", 0.018)
	_metal = _material(Color(0.22, 0.25, 0.27), 0.7, 0.34)
	_edge = _material(Color(0.49, 0.46, 0.42), 0.5, 0.42)
	_dark = _material(Color(0.025, 0.04, 0.085), 0.35, 0.67)
	_light = _material(Color(0.65, 0.84, 0.90), 0.2, 0.3)
	_light.emission_enabled = true
	_light.emission = Color(0.34, 0.68, 0.8)
	_light.emission_energy_multiplier = 0.45
	_crystal = CRYSTAL.duplicate() as ShaderMaterial
	_crystal.set_shader_parameter("base_color", Color(0.035, 0.075, 0.19))
	_crystal.set_shader_parameter("emission_color", Color(0.04, 0.08, 0.20))
	_crystal.set_shader_parameter("rim_color", Color(0.25, 0.48, 0.72))
	_crystal.set_shader_parameter("spec_color", Color(0.36, 0.52, 0.68))
	_crystal.set_shader_parameter("inner_glow", 0.06)
	_crystal.set_shader_parameter("roughness_value", 0.32)
	model = BODY.instantiate() as Node3D
	model.name = "RedCrystalBody"
	add_child(model)
	for child in model.find_children("*", "MeshInstance3D", true, false):
		(child as MeshInstance3D).material_override = _crystal
	for child in model.find_children("*", "Skeleton3D", true, false):
		skeleton = child as Skeleton3D
		break
	for child in model.find_children("*", "AnimationPlayer", true, false):
		animation = child as AnimationPlayer
		break
	if _outfit_templates.has(kind):
		_restore_outfit(_outfit_templates[kind])
	else:
		_outfit = Node3D.new()
		_outfit.name = "SlothOutfit"
		add_child(_outfit)
		match kind:
			0: _build_lingerer()
			1: _build_anchor()
			2: _build_recluse()
		_batch_meshes(_outfit)
		_cache_outfit()
	play_motion("idle")
	if animation != null:
		animation.advance(0.0)
	_update_bones()
	set_cast(_cast)
	set_shell_open(_opening)


func set_cast(amount: float) -> void:
	_cast = clampf(amount, 0.0, 1.0)
	if _cloth != null:
		_cloth.set_shader_parameter("cast_amount", _cast)
		_light.emission_energy_multiplier = 0.35 + _cast * 0.8
		_crystal.set_shader_parameter("emission_strength", 0.12 + _cast * 0.10)


func set_shell_open(amount: float) -> void:
	_opening = clampf(amount, 0.0, 1.0)
	for piece in _shell:
		var pivot := piece["node"] as Node3D
		pivot.rotation = piece["closed"] + piece["turn"] * _opening
		pivot.position = piece["origin"] + piece["slide"] * _opening


func play_motion(motion: String) -> void:
	if animation == null or _dead:
		return
	var clip := motion
	match motion:
		"idle": clip = "CowerIdle" if kind == 2 else "idle"
		"walk", "run": clip = "walk"
		"cast": clip = "ExitCower" if kind == 2 else "punch"
		"recover": clip = "CowerIdle" if kind == 2 else "idle"
	if not animation.has_animation(clip):
		clip = "idle"
	if animation.current_animation == clip:
		return
	if clip in ["idle", "walk", "CowerIdle"]:
		# Animation resources are shared with the player body. Change only a copy.
		var library := animation.get_animation_library("")
		var own := animation.get_animation(clip).duplicate() as Animation
		own.loop_mode = Animation.LOOP_LINEAR
		if library != null:
			var unique := library.duplicate() as AnimationLibrary
			unique.remove_animation(clip)
			unique.add_animation(clip, own)
			animation.remove_animation_library("")
			animation.add_animation_library("", unique)
	animation.play(clip, 0.18)


func crystal_material() -> ShaderMaterial:
	return _crystal


func set_mantle_open(amount: float) -> void:
	_mantle_open = clampf(amount, 0.0, 1.0)
	if _cloth != null:
		_cloth.set_shader_parameter("mantle_open", _mantle_open)
		_lining.set_shader_parameter("mantle_open", _mantle_open)


func die(point := Vector3.INF, direction := Vector3.FORWARD) -> void:
	if _dead:
		return
	_dead = true
	if is_instance_valid(_evade_label):
		_evade_label.hide()
	set_cast(0.0)
	if animation != null:
		animation.pause()
	shatter = SlothShatter.new()
	# Sibling of the actor, so removing a dead enemy does not orphan the burst.
	get_parent().get_parent().add_child(shatter)
	shatter.build(self, global_position + Vector3.UP if point == Vector3.INF else point, direction)
	model.hide()
	_outfit.hide()


func _process(delta: float) -> void:
	_time += delta
	_cloth.set_shader_parameter("visual_time", _time)
	_lining.set_shader_parameter("visual_time", _time)
	if not _dead:
		_update_bones()
		if _evade_left > 0.0:
			_evade_left = maxf(0.0, _evade_left - delta)
			var wave := sin(PI * (1.0 - _evade_left / 0.25))
			position = _evade_origin + Vector3.RIGHT * wave * 0.24 * _evade_sign
			rotation.z = _evade_rotation + wave * 0.08 * _evade_sign
			_crystal.set_shader_parameter("rim_strength", 0.55 + wave * 0.6)
			_evade_label.modulate.a = minf(1.0, _evade_left * 8.0)
			if _evade_left <= 0.0:
				position = _evade_origin
				rotation.z = _evade_rotation
				_evade_label.hide()


func _follow(bone: String, label: String) -> Node3D:
	var node := Node3D.new()
	node.name = label
	_outfit.add_child(node)
	if skeleton != null:
		var index := skeleton.find_bone(bone)
		if index >= 0:
			_bones.append({"node": node, "bone": index})
	return node


func _cache_outfit() -> void:
	# Cache immutable geometry and topology; each actor still owns its materials,
	# bone-follow nodes and hinges. Reinforcements avoid procedural remeshing.
	var materials := [_cloth,_lining,_metal,_edge,_dark,_light]
	for mesh in _outfit.find_children("*","MeshInstance3D",true,false):
		mesh.set_meta("sloth_material_slot",materials.find(mesh.material_override))
	_set_template_owner(_outfit)
	var packed := PackedScene.new()
	if packed.pack(_outfit) != OK:
		return
	var bones: Array[Dictionary] = []
	for link in _bones:
		bones.append({"path":_outfit.get_path_to(link.node),"bone":link.bone})
	var shell: Array[Dictionary] = []
	for hinge in _shell:
		var copy := hinge.duplicate()
		copy.path = _outfit.get_path_to(copy.node)
		copy.erase("node")
		shell.append(copy)
	_outfit_templates[kind] = {"scene":packed,"bones":bones,"shell":shell}


func _set_template_owner(parent: Node) -> void:
	for child in parent.get_children():
		child.owner = _outfit
		_set_template_owner(child)


func _restore_outfit(template: Dictionary) -> void:
	_outfit = (template.scene as PackedScene).instantiate() as Node3D
	add_child(_outfit)
	var materials := [_cloth,_lining,_metal,_edge,_dark,_light]
	for mesh in _outfit.find_children("*","MeshInstance3D",true,false):
		var slot := int(mesh.get_meta("sloth_material_slot",-1))
		if slot >= 0:
			mesh.material_override = materials[slot]
	for link in template.bones:
		_bones.append({"node":_outfit.get_node(link.path),"bone":link.bone})
	for hinge in template.shell:
		var copy: Dictionary = hinge.duplicate()
		copy.node = _outfit.get_node(copy.path)
		copy.erase("path")
		_shell.append(copy)


func _update_bones() -> void:
	if skeleton == null:
		return
	for link in _bones:
		var index: int = link["bone"]
		# All extra geometry is authored in the body's model space. A pose delta
		# follows the bone while preserving each garment's authored coordinates.
		(link["node"] as Node3D).transform = skeleton.get_bone_global_pose(index) \
			* skeleton.get_bone_global_rest(index).affine_inverse()


func _build_lingerer() -> void:
	var mantle := _follow("Spine", "TornMantle")
	_mantle = mantle
	var hood := _follow("Head", "HollowHood")
	_build_cape(mantle)
	_build_hood(hood)
	for side in [-1.0, 1.0]:
		var shoulder := _plate(mantle, Vector3(side * 0.27, 1.57, 0.05), Vector3(0.42, 0.17, 0.38), _cloth)
		shoulder.rotation.z = side * -0.2
	# The hourglass seam repeats on the suspended crystals; readable at range.
	for path in [[Vector3(-0.16,1.40,0.32),Vector3(0.16,1.40,0.32),Vector3(-0.16,1.07,0.39),Vector3(0.16,1.07,0.39),Vector3(-0.16,1.40,0.32)]]:
		_polyline(mantle, PackedVector3Array(path), 0.009, _edge)

	_polyline(mantle, PackedVector3Array([Vector3(-0.075,1.39,-0.25),Vector3(0.075,1.39,-0.25),
		Vector3(-0.075,1.27,-0.26),Vector3(0.075,1.27,-0.26),Vector3(-0.075,1.39,-0.25)]), 0.006, _light)
	# Split collar, double clasps and the hanging time seals leave the chest red.
	for side in [-1.0, 1.0]:
		var collar := _box(mantle, Vector3(side * 0.19, 1.49, -0.14), Vector3(0.20, 0.065, 0.07), _dark)
		collar.rotation.z = side * 0.16
		_torus(mantle, Vector3(side * 0.18, 1.46, -0.19), 0.041, 0.009, _edge, Vector3(PI / 2, 0, 0))
		_polyline(mantle, PackedVector3Array([
			Vector3(side * 0.18, 1.46, -0.195), Vector3(side * 0.10, 1.40, -0.225),
			Vector3(0, 1.39, -0.23)]), 0.008, _metal)
	# Three suspended pendulum seals are a silhouette cue for delayed shots.
	for i in 3:
		var x := float(i - 1) * 0.12
		var start := Vector3(x - 0.26, 1.38, 0.19)
		var end := start + Vector3(-0.035, -0.25 - i * 0.06, 0.08)
		_line(mantle, start, end, 0.006, _dark)
		var seal := _box(mantle, end, Vector3(0.055, 0.075, 0.018), _metal)
		seal.rotation.z = 0.16 * (i - 1)
		_box(mantle, end + Vector3(0, 0, -0.011), Vector3(0.005, 0.04, 0.003), _light)


func _cape_point(u: float, v: float, inner := false) -> Vector3:
	var angle := lerpf(-2.29, 2.29, u)
	var r := lerpf(0.43, 0.71, pow(v, 0.7))
	r += 0.034 * sin(u * 9.0 * TAU + v * 1.9) * sin(PI * v * 0.7)
	if inner:
		r -= 0.012
	var hem := 0.055 * sin(u * 37.0) + 0.038 * sin(u * 79.0 + 1.3)
	var y := lerpf(1.64 - 0.11 * absf(sin(angle)), 0.22 + hem, v)
	return Vector3(sin(angle) * r, y, cos(angle) * r * 0.60 + 0.035)


func _cape_hole(u: float, v: float) -> bool:
	# Missing cells create real see-through holes; no dark hole decals.
	for hole in [Vector4(0.25, 0.43, 0.047, 0.087), Vector4(0.60, 0.67, 0.06, 0.10), Vector4(0.79, 0.30, 0.035, 0.064)]:
		var p := Vector2((u - hole.x) / hole.z, (v - hole.y) / hole.w)
		if p.length_squared() < 1.0 + sin(u * 450.0 + v * 140.0) * 0.12:
			return true
	return (v > 0.87 and u > 0.42 and u < 0.455) or (v > 0.93 and u > 0.71 and u < 0.74)


func _build_cape(parent: Node3D) -> void:
	const COLS := 64
	const ROWS := 29
	var outer := SurfaceTool.new()
	var lining := SurfaceTool.new()
	var borders := SurfaceTool.new()
	for st in [outer, lining, borders]:
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in ROWS:
		for i in COLS:
			var u := float(i) / COLS
			var v := float(j) / ROWS
			var du := 1.0 / COLS
			var dv := 1.0 / ROWS
			if _cape_hole(u + du * 0.5, v + dv * 0.5):
				continue
			var uv := [Vector2(u, v), Vector2(u + du, v), Vector2(u + du, v + dv), Vector2(u, v + dv)]
			var front: Array[Vector3] = []
			var back: Array[Vector3] = []
			for p in uv:
				front.append(_cape_point(p.x, p.y))
				back.append(_cape_point(p.x, p.y, true))
			_quad(outer, front, uv)
			_quad(lining, [back[3], back[2], back[1], back[0]], [uv[3], uv[2], uv[1], uv[0]])
			# Bind the cut cloth: thickness is visible along every open edge.
			var neighbor := [Vector2(u + du * 0.5, v - dv * 0.5), Vector2(u + du * 1.5, v + dv * 0.5),
				Vector2(u + du * 0.5, v + dv * 1.5), Vector2(u - du * 0.5, v + dv * 0.5)]
			for k in 4:
				var p: Vector2 = neighbor[k]
				if p.x < 0 or p.x > 1 or p.y < 0 or p.y > 1 or _cape_hole(p.x, p.y):
					var next := (k + 1) % 4
					_quad(borders, [front[k], front[next], back[next], back[k]], [uv[k], uv[next], uv[next], uv[k]])
	_mesh(parent, outer, _cloth, "DoubleLayerMantle")
	_mesh(parent, lining, _lining, "WineGreyLining")
	_mesh(parent, borders, _edge, "WornCutEdges")
	# Long stitched hems frame the front opening and retain the shoulder shape.
	for u in [0.012, 0.988]:
		var points := PackedVector3Array()
		for j in 30:
			points.append(_cape_point(u, float(j) / 29) + Vector3(0, 0, -0.003))
		_polyline(parent, points, 0.006, _edge)
		for j in 18:
			var v := 0.04 + j * 0.05
			_line(parent, _cape_point(u - 0.006, v), _cape_point(u + 0.006, v + 0.01), 0.0025, _edge)
	# Damaged back panel is sewn in place, with irregularly spaced cross stitches.
	for j in 12:
		var v := 0.15 + j * 0.055
		var u := 0.47 + sin(j * 2.2) * 0.004
		_line(parent, _cape_point(u - 0.012, v), _cape_point(u + 0.012, v + 0.013), 0.003, _edge)


func _hood_point(angle: float, depth: float, inner := false) -> Vector3:
	var s := sin(angle)
	var width := lerpf(0.235, 0.0, pow(depth, 2.4))
	var height := lerpf(0.265, 0.0, pow(depth, 2.2))
	if inner:
		width -= 0.012
		height -= 0.012
	var peak := pow(maxf(0.0, s), 5.0)
	var y := 1.745 + s * height + peak * 0.075 * (1.0 - depth)
	return Vector3(cos(angle) * width * (1.0 - maxf(0.0, s) * 0.16), y,
		lerpf(-0.14 - peak * 0.10, 0.205, depth) + (0.009 if inner else 0.0))


func _build_hood(parent: Node3D) -> void:
	var outer := SurfaceTool.new()
	var inner := SurfaceTool.new()
	outer.begin(Mesh.PRIMITIVE_TRIANGLES)
	inner.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in 12:
		for i in 36:
			var a := TAU * i / 36.0
			var b := TAU * (i + 1) / 36.0
			var d := float(j) / 12
			var e := float(j + 1) / 12
			var uv := [Vector2(float(i) / 36, 0), Vector2(float(i + 1) / 36, 0), Vector2(float(i + 1) / 36, 0), Vector2(float(i) / 36, 0)]
			_quad(outer, [_hood_point(a, e), _hood_point(b, e), _hood_point(b, d), _hood_point(a, d)], uv)
			_quad(inner, [_hood_point(a, d, true), _hood_point(b, d, true), _hood_point(b, e, true), _hood_point(a, e, true)], uv)
	_mesh(parent, outer, _cloth, "SculptedHood")
	_mesh(parent, inner, _lining, "HoodInnerFold")
	var lip := PackedVector3Array()
	for i in 49:
		lip.append(_hood_point(TAU * i / 48, 0))
	_polyline(parent, lip, 0.012, _dark)
	for i in 28:
		var a := TAU * i / 28.0
		_line(parent, _hood_point(a - 0.018, 0.015), _hood_point(a + 0.018, 0.038), 0.0028, _edge)


func _build_anchor() -> void:
	var back := _follow("Spine", "AnchorHarness")
	# An incomplete double halo has a readable broken gap, with engraved ribs.
	for layer in 2:
		var center := Vector3(0, 1.38, 0.27 + layer * 0.045)
		_arc(back, center, 0.60 + layer * 0.055, 0.035 - layer * 0.009, 0.24, TAU - 0.48, _metal)
	for i in 15:
		var a := 0.36 + i * (TAU - 0.72) / 14.0
		var p := Vector3(sin(a) * 0.595, 1.38 + cos(a) * 0.595, 0.30)
		var rib := _box(back, p, Vector3(0.068, 0.024, 0.105), _edge)
		rib.rotation.z = -a
		if i % 3 == 0:
			var glow := _box(back, p + Vector3(0, 0, -0.061), Vector3(0.042, 0.008, 0.006), _light)
			glow.rotation.z = -a
	for side in [-1.0, 1.0]:
		# Layered shoulder plates sit outside the red upper arms.
		for j in 3:
			var plate := _plate(back, Vector3(side * (0.31 + j * 0.07), 1.52 - j * 0.07, 0.0), Vector3(0.29 - j * 0.018, 0.19, 0.30), _metal)
			plate.rotation.z = side * (0.12 + j * 0.10)
			_box(back, plate.position + Vector3(0, 0.043, -0.11), Vector3(0.12, 0.011, 0.018), _edge)
		var rail := _box(back, Vector3(side * 0.18, 1.30, -0.17), Vector3(0.055, 0.40, 0.06), _dark)
		rail.rotation.z = side * -0.16
		for i in 10:
			var t := float(i) / 9
			var chain := Vector3(side * (0.43 + 0.075 * sin(t * PI)), 1.16 - t * 0.94, 0.06 + t * 0.07)
			_torus(back, chain, 0.034, 0.008, _metal, Vector3(PI / 2, PI / 2 * (i % 2), 0))
		var weight := _plate(back, Vector3(side * 0.43, 0.19, 0.13), Vector3(0.17, 0.22, 0.15), _dark)
		weight.rotation.z = side * 0.25
	# A clock-seal cage makes the chest weak point legible without a gun prop.
	_torus(back, Vector3(0, 1.33, -0.195), 0.13, 0.018, _edge, Vector3(PI / 2, 0, 0))
	for side in [-1.0, 1.0]:
		_box(back, Vector3(side * 0.15, 1.33, -0.20), Vector3(0.04, 0.09, 0.07), _metal)
		_line(back, Vector3(side * 0.11, 1.44, -0.21), Vector3(side * 0.08, 1.22, -0.23), 0.008, _metal)
	_box(back, Vector3(0, 1.33, -0.216), Vector3(0.014, 0.105, 0.009), _light)
	# Split hoodless brow keeps Anchor's face visibly distinct from Lingerer.
	var head := _follow("Head", "AnchorBrow")
	for side in [-1.0, 1.0]:
		var brow := _box(head, Vector3(side * 0.105, 1.835, -0.135), Vector3(0.13, 0.035, 0.045), _metal)
		brow.rotation.z = side * 0.16


func _build_recluse() -> void:
	var frame := _follow("Spine", "SplitCocoon")
	# Six overlapping petals form a real volume; opening rotates and slides the
	# authored hinges to expose the red chest, with visible metal inner ribs.
	for i in 6:
		var side := -1.0 if i % 2 == 0 else 1.0
		var row := i / 2
		var pivot := Node3D.new()
		frame.add_child(pivot)
		pivot.name = "CocoonPetal%d" % i
		pivot.position = Vector3(side * 0.20, 1.44 - row * 0.29, 0)
		var petal := _plate(pivot, Vector3(side * 0.08, 0, -0.22), Vector3(0.37, 0.43 - row * 0.025, 0.18), _dark)
		petal.rotation.z = side * (-0.23 + row * 0.16)
		var rim := _box(pivot, Vector3(side * 0.08, 0.14, -0.315), Vector3(0.26, 0.016, 0.018), _edge)
		rim.rotation.z = petal.rotation.z
		_box(pivot, Vector3(side * 0.16, 0.02, -0.318), Vector3(0.015, 0.19, 0.012), _metal)
		for j in 3:
			var p := Vector3(side * (0.12 + j * 0.028), -0.085 + j * 0.035, -0.321)
			_box(pivot, p, Vector3(0.007, 0.032, 0.006), _light)
		_shell.append({"node": pivot, "origin": pivot.position, "closed": Vector3.ZERO,
			"turn": Vector3(0, side * -0.85, side * -0.27), "slide": Vector3(side * 0.21, 0.02, 0.11)})
	for side in [-1.0, 1.0]:
		for j in 3:
			var rib := _plate(frame, Vector3(side * (0.21 + j * 0.04), 1.53 - j * 0.28, 0.22), Vector3(0.30, 0.38, 0.19), _metal)
			rib.rotation.z = side * 0.25
		# Fastened straps and rivets explain how the cocoon is held onto the body.
		for j in 5:
			_sphere(frame, Vector3(side * 0.37, 1.45 - j * 0.13, -0.20), 0.013, _edge)
	# Cracked stone cowl is shorter than the cloth hood. The face stays exposed.
	var head := _follow("Head", "CocoonCowl")
	for side in [-1.0, 1.0]:
		var cheek := _plate(head, Vector3(side * 0.19, 1.79, 0.02), Vector3(0.11, 0.33, 0.27), _dark)
		cheek.rotation.z = side * 0.18
		_line(head, Vector3(side * 0.24, 1.92, -0.1), Vector3(side * 0.20, 1.65, -0.11), 0.008, _edge)
	var crown := _plate(head, Vector3(0, 2.005, 0.035), Vector3(0.41, 0.12, 0.32), _dark)
	crown.rotation.z = -0.06
	# Dark neutral carrier cloth links the open shell pieces visually.
	var lower := _box(frame, Vector3(0, 0.79, 0.10), Vector3(0.30, 0.25, 0.10), _dark)
	lower.rotation.x = 0.2


func _material(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = metallic
	mat.roughness = roughness
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat


func _box(parent: Node3D, pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var result := MeshInstance3D.new()
	result.mesh = mesh
	result.material_override = mat
	result.position = pos
	parent.add_child(result)
	return result


func _sphere(parent: Node3D, pos: Vector3, radius: float, mat: Material) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2
	mesh.radial_segments = 8
	mesh.rings = 4
	var result := MeshInstance3D.new()
	result.mesh = mesh
	result.material_override = mat
	result.position = pos
	parent.add_child(result)
	return result


func _torus(parent: Node3D, pos: Vector3, radius: float, thickness: float, mat: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = radius - thickness
	mesh.outer_radius = radius + thickness
	mesh.rings = 20
	mesh.ring_segments = 6
	var result := MeshInstance3D.new()
	result.mesh = mesh
	result.material_override = mat
	result.position = pos
	result.rotation = rot
	parent.add_child(result)
	return result


func _line(parent: Node3D, a: Vector3, b: Vector3, radius: float, mat: Material) -> void:
	if a.distance_squared_to(b) < 0.0000001:
		return
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = a.distance_to(b)
	mesh.radial_segments = 5
	mesh.rings = 1
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = mat
	parent.add_child(node)
	node.position = (a + b) * 0.5
	var up := (b - a).normalized()
	var right := up.cross(Vector3.FORWARD)
	if right.length_squared() < 0.001:
		right = up.cross(Vector3.RIGHT)
	right = right.normalized()
	node.basis = Basis(right, up, right.cross(up).normalized())


func _polyline(parent: Node3D, points: PackedVector3Array, radius: float, mat: Material) -> void:
	for i in points.size() - 1:
		_line(parent, points[i], points[i + 1], radius, mat)


func _arc(parent: Node3D, center: Vector3, radius: float, thickness: float, begin: float, end: float, mat: Material) -> void:
	var points := PackedVector3Array()
	for i in 65:
		var a := lerpf(begin, end, i / 64.0)
		points.append(center + Vector3(sin(a) * radius, cos(a) * radius, 0))
	_polyline(parent, points, thickness, mat)


func _plate(parent: Node3D, pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	# Beveled eight-sided slab, with a raised faceted ridge instead of a cube.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var contour := [Vector2(-0.34, -0.5), Vector2(0.30, -0.5), Vector2(0.5, -0.26), Vector2(0.5, 0.24),
		Vector2(0.30, 0.5), Vector2(-0.34, 0.5), Vector2(-0.5, 0.22), Vector2(-0.5, -0.30)]
	for i in 8:
		var next := (i + 1) % 8
		var a := Vector3(contour[i].x * size.x, contour[i].y * size.y, -size.z * 0.20)
		var b := Vector3(contour[next].x * size.x, contour[next].y * size.y, -size.z * 0.20)
		_triangle(st, a, b, Vector3(0, 0.02 * size.y, -size.z * 0.62), Vector2.ZERO, Vector2.ZERO, Vector2.ZERO)
		var c := Vector3(b.x * 0.90, b.y * 0.90, size.z * 0.4)
		var d := Vector3(a.x * 0.90, a.y * 0.90, size.z * 0.4)
		_quad(st, [a, d, c, b], [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])
		_triangle(st, d, Vector3(0, 0, size.z * 0.4), c, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO)
	var result := _mesh(parent, st, mat, "BeveledSlab")
	result.position = pos
	return result


func _triangle(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, ua: Vector2, ub: Vector2, uc: Vector2) -> void:
	var normal := (c - a).cross(b - a).normalized()
	for item in [[a, ua], [c, uc], [b, ub]]:
		st.set_normal(normal)
		st.set_uv(item[1])
		st.add_vertex(item[0])


func _quad(st: SurfaceTool, points: Array, uv: Array) -> void:
	_triangle(st, points[0], points[1], points[2], uv[0], uv[1], uv[2])
	_triangle(st, points[0], points[2], points[3], uv[0], uv[2], uv[3])


func _mesh(parent: Node3D, st: SurfaceTool, mat: Material, label: String) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = label
	node.mesh = st.commit()
	node.material_override = mat
	parent.add_child(node)
	return node


func _batch_meshes(parent: Node3D) -> void:
	# Keep each bone/hinge independent but merge static decorations sharing its
	# material. Hundreds of stitches and links cost a handful of outfit draws.
	var groups := {}
	for child in parent.get_children():
		if child is MeshInstance3D:
			var mesh_node := child as MeshInstance3D
			var key := mesh_node.material_override.get_instance_id()
			if not groups.has(key):
				groups[key] = []
			groups[key].append(mesh_node)
		elif child is Node3D:
			_batch_meshes(child)
	for key in groups:
		var nodes: Array = groups[key]
		if nodes.size() < 2:
			continue
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var mat: Material = nodes[0].material_override
		for child in nodes:
			st.append_from(child.mesh, 0, child.transform)
			child.free()
		_mesh(parent, st, mat, "OutfitDetailBatch")


func play_evade(side: float) -> void:
	if _dead:
		return
	_evade_origin = position
	_evade_rotation = rotation.z
	_evade_sign = side
	_evade_left = 0.25
	if not is_instance_valid(_evade_label):
		_evade_label = Label3D.new()
		_evade_label.text = "闪避"
		_evade_label.font_size = 36
		_evade_label.pixel_size = 0.003
		_evade_label.position = Vector3(0,2.16,0)
		_evade_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_evade_label.modulate = Color(0.72,0.87,1.0)
		add_child(_evade_label)
	_evade_label.show()
