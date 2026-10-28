extends Node
## Windowed layout proof for issue #42: one angled top-down shot per map, with
## every guard labelled by its front / middle / point band. Needs a display, so
## no --headless. Run from the project root:
##   godot --path . res://tests/enemy_layout_proof.tscn -- --out=<dir>
## Saves three JPEGs (<300 KB each) into docs/proof/enemy-layout by default and
## prints the band table the README uses. The guards are frozen before their
## first physics tick, so the shot shows the positions written in the scene.

const MAPS := [
	{"path": "res://maps/zone_1.tscn", "zone": 0, "shot": "01_zone_1", "bands": [1, 1, 2],
		"size": 34.0, "band_x": 19.0},
	{"path": "res://maps/zone_2.tscn", "zone": 1, "shot": "02_zone_2", "bands": [2, 2, 2],
		"size": 34.0, "band_x": 19.0},
	{"path": "res://maps/boss.tscn", "zone": 2, "shot": "03_boss", "bands": [2, 2, 2], "boss": true,
		"size": 58.0, "band_x": 26.5},
]
const BAND_NAMES := ["FRONT", "MIDDLE", "POINT"]
const BAND_LETTERS := ["F", "M", "P"]
const BAND_COLORS := [Color(1.0, 0.84, 0.2), Color(0.3, 0.85, 1.0), Color(1.0, 0.4, 0.9)]
## 300 KB per shot, per the issue #42 proof requirement.
const MAX_BYTES := 300 * 1024
## A 70 degree downward view: 40 m up and 14.5 m back from the field centre.
const CAMERA_HEIGHT := 40.0
const CAMERA_BACK := 14.5
## Vertical extent in metres; each map sets its own (see MAPS): the small zones
## span ~22 m from spawn to core, the boss zone ~53 m.
const WINDOW := Vector2i(1440, 1080)

var _out_dir := "res://docs/proof/enemy-layout"
var _failures := 0
var _overlay: Node3D


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out_dir = arg.trim_prefix("--out=")
	_out_dir = ProjectSettings.globalize_path(_out_dir)
	if DisplayServer.get_name() == "headless":
		push_error("Enemy layout proof requires a native display")
		get_tree().quit(1)
		return
	if DirAccess.make_dir_recursive_absolute(_out_dir) != OK:
		push_error("Cannot create the enemy layout proof directory")
		get_tree().quit(1)
		return
	DisplayServer.window_set_size(WINDOW)
	for spec: Dictionary in MAPS:
		await _capture(spec)
	print("ENEMY LAYOUT PROOF %s" % ("PASSED" if _failures == 0 else "FAILED"))
	get_tree().quit(0 if _failures == 0 else 1)


func _capture(spec: Dictionary) -> void:
	var scene := await _open(spec)
	var file: String = (spec.path as String).get_file()
	var player := scene.get_node("Player") as Player
	var point := scene.get_node("CapturePoint") as CapturePoint
	var boss := scene.get_node_or_null("Boss") as Enemy
	var enemy_list := _enemies(scene)
	var small: Array[Enemy] = []
	for enemy in enemy_list:
		if enemy != boss:
			small.append(enemy)
	var spawn := player.global_position
	print("== %s: %d enemies, spawn (%.2f, %.2f), core (%.2f, %.2f)" % [file,
		enemy_list.size(), spawn.x, spawn.z, point.global_position.x, point.global_position.z])

	_overlay = Node3D.new()
	_overlay.name = "ProofOverlay"
	add_child(_overlay)
	_label("SPAWN", spawn + Vector3(0.0, 3.2, 0.0), Color.WHITE, 72, 0.02, 3)
	_label("CORE", point.global_position + Vector3(0.0, 4.8, 0.0), Color(1.0, 0.35, 0.35), 72, 0.02, 3)
	_add_bands(spawn.z, point.global_position.z, spec.band_x)

	var counts := [0, 0, 0]
	var per_band := [0, 0, 0]
	for enemy in small:
		var band := _band_of(enemy.global_position.z, spawn.z, point.global_position.z)
		counts[band] += 1
		per_band[band] += 1
		var cover := _nearest_cover(scene, enemy)
		print("   %s%d  %-8s (%6.2f, %6.2f)  yaw %6.1f  spawn %5.2f m  cover %4.2f m" % [
			BAND_LETTERS[band], per_band[band], enemy.name, enemy.global_position.x,
			enemy.global_position.z, _yaw(enemy), _flat(enemy.global_position, spawn),
			cover])
		_disc(enemy.global_position, BAND_COLORS[band], 0.7)
		_label("%s%d" % [BAND_LETTERS[band], per_band[band]], enemy.global_position + Vector3(0.0, 2.5, 0.0),
			BAND_COLORS[band], 64, 0.018, 2)
	if boss != null:
		print("   BOSS   Boss     (%6.2f, %6.2f)  yaw %6.1f  spawn %5.2f m" % [
			boss.global_position.x, boss.global_position.z, _yaw(boss),
			_flat(boss.global_position, spawn)])
		_disc(boss.global_position, Color(1.0, 0.3, 0.2), 1.5)
		_label("BOSS", boss.global_position + Vector3(0.0, 4.2, 0.0), Color(1.0, 0.3, 0.2), 96, 0.02, 3)
	var expected: Array = spec.bands
	_check("%s keeps the %s split (%d/%d/%d)" % [file, str(expected), counts[0], counts[1], counts[2]],
		counts == expected)

	var camera := _camera(spawn.z, point.global_position.z, spec.size)
	for i in 6:
		await get_tree().process_frame
	camera.current = true
	await _shot(spec.shot)

	camera.queue_free()
	_overlay.queue_free()
	await _close(scene)


## Loads one map with its guards frozen before the first physics tick.
func _open(spec: Dictionary) -> Node:
	get_tree().paused = false
	RunState.clear_fixture()
	RunState.zone_index = spec.zone
	RunState.buffs.clear()
	RunState.selection_history.clear()
	RunState.run_seed = 424242
	BuffPool.reset(RunState.run_seed)
	var scene := (load(spec.path) as PackedScene).instantiate()
	add_child(scene)
	for enemy in _enemies(scene):
		enemy.set_physics_process(false)
		enemy.set_process(false)
	var player := scene.get_node("Player") as Player
	player.set_physics_process(false)
	player.set_process(false)
	player.weapon.visible = false
	player.melee.visible = false
	player.hammer.visible = false
	(scene.get_node("HUD") as CanvasLayer).visible = false
	get_tree().paused = false
	var director := scene.get_node("ZoneDirector") as ZoneDirector
	if is_instance_valid(director.selection):
		director.selection.free()
		director.selection = null
		director.selection_context = ""
	for i in 8:
		await get_tree().physics_frame
	return scene


func _close(scene: Node) -> void:
	get_tree().paused = false
	scene.free()
	await get_tree().process_frame


func _camera(spawn_z: float, point_z: float, size: float) -> Camera3D:
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = size
	camera.near = 0.1
	camera.far = 200.0
	add_child(camera)
	var target := Vector3(0.0, 0.0, (spawn_z + point_z) * 0.5)
	camera.global_position = target + Vector3(0.0, CAMERA_HEIGHT, CAMERA_BACK)
	camera.look_at(target, Vector3.UP)
	camera.current = true
	return camera


## Two thin lines split the approach into the same thirds the layout test uses.
func _add_bands(spawn_z: float, point_z: float, band_x: float) -> void:
	for i in [1, 2]:
		var z := lerpf(spawn_z, point_z, float(i) / 3.0)
		var mesh := BoxMesh.new()
		mesh.size = Vector3(60.0, 0.02, 0.12)
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = Color(1.0, 1.0, 1.0, 0.8)
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mesh.material = material
		var strip := MeshInstance3D.new()
		strip.mesh = mesh
		strip.position = Vector3(0.0, 0.06, z)
		strip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_overlay.add_child(strip)
	for band in 3:
		var from := lerpf(spawn_z, point_z, float(band) / 3.0)
		var to := lerpf(spawn_z, point_z, float(band + 1) / 3.0)
		_label(BAND_NAMES[band], Vector3(band_x, 2.4, (from + to) * 0.5), BAND_COLORS[band], 64, 0.02, 1)


## A band-coloured disc at the enemy's feet; the character itself is only a few
## pixels tall at this camera distance.
func _disc(pos: Vector3, color: Color, radius: float) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = 0.04
	mesh.radial_segments = 32
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(color.r, color.g, color.b, 0.55)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material = material
	var disc := MeshInstance3D.new()
	disc.mesh = mesh
	disc.position = Vector3(pos.x, 0.04, pos.z)
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_overlay.add_child(disc)


func _label(text: String, pos: Vector3, color: Color, font_size: int, pixel: float, priority: int) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = font_size
	label.pixel_size = pixel
	label.modulate = color
	label.outline_size = 14
	label.outline_modulate = Color(0.0, 0.0, 0.0, 0.9)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.render_priority = priority
	label.position = pos
	_overlay.add_child(label)


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var path := "%s/%s.jpg" % [_out_dir, shot_name]
	var image := get_viewport().get_texture().get_image()
	var quality := 0.9
	var err := image.save_jpg(path, quality)
	var size := _file_size(path)
	if err == OK and size > MAX_BYTES:
		quality = 0.7
		err = image.save_jpg(path, quality)
		size = _file_size(path)
	_check("%s saved under %d KB (%d KB, q%.1f, %dx%d)" % [shot_name, MAX_BYTES / 1024,
		size / 1024, quality, image.get_width(), image.get_height()],
		err == OK and size > 0 and size <= MAX_BYTES)
	print("== %s -> %s" % [shot_name, path])


func _file_size(path: String) -> int:
	var file := FileAccess.open(path, FileAccess.READ)
	return 0 if file == null else file.get_length()


func _enemies(scene: Node) -> Array[Enemy]:
	var found: Array[Enemy] = []
	for node in get_tree().get_nodes_in_group("enemy"):
		if scene.is_ancestor_of(node):
			found.append(node as Enemy)
	return found


## 0 at the spawn, 1 at the capture point; same split as tests/enemy_layout_test.
func _band_of(z: float, spawn_z: float, point_z: float) -> int:
	var t := inverse_lerp(spawn_z, point_z, z)
	if t < 1.0 / 3.0:
		return 0
	if t < 2.0 / 3.0:
		return 1
	return 2


func _nearest_cover(scene: Node, enemy: Enemy) -> float:
	var best := INF
	for node in get_tree().get_nodes_in_group("cover_point"):
		if scene.is_ancestor_of(node):
			best = minf(best, _flat((node as Node3D).global_position, enemy.global_position))
	return best


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


## The generator's yaw, in [0, 360).
func _yaw(enemy: Enemy) -> float:
	return fposmod(rad_to_deg(enemy.rotation.y), 360.0)


func _check(label: String, ok: bool) -> void:
	if not ok:
		_failures += 1
	print("  [%s] %s" % ["ok" if ok else "FAIL", label])
