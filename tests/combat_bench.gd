extends Node3D
## Interactive Epic 1 acceptance arena. All combat uses production components.
var player: Player
var clock_point: CapturePoint
var emitter: CombatBenchTarget
var moving_target: CombatBenchTarget
var melee_target: CombatBenchTarget
var _shot_left := 2.0
var _status: Label
var _parries := 0
var _last_strike := "尚未敲钟"
var _time := 0.0

func _ready() -> void:
	CrystalBurst.prepare(self)
	seed(101106)
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color(0.85, 0.88, 0.9)
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color.WHITE
	world.environment.ambient_light_energy = 0.7
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -25, 0)
	sun.shadow_enabled = true
	add_child(sun)
	_box(Vector3(0, -0.25, -8), Vector3(24, 0.5, 28))
	_box(Vector3(0, 2, -22), Vector3(24, 4, 0.3))
	_box(Vector3(-12, 1, -8), Vector3(0.3, 2, 28))
	_box(Vector3(12, 1, -8), Vector3(0.3, 2, 28))
	melee_target = _target(Vector3(-4, 0, -2), false)
	_sign("01 意志短刃\nV / 鼠标侧键 · 4米吸附", Vector3(-4, 3.4, -2))
	emitter = _target(Vector3(0, 0, -12), false)
	_sign("02 慢速弹幕\n迎面挥刃 · 反弹命中发射者", Vector3(0, 3.5, -12))
	moving_target = _target(Vector3(6, 0, -16), true)
	_sign("03 移动靶道\n点射 / 右键ADS / R重组", Vector3(6, 3.5, -16))
	_build_clock()
	_sign("04 节拍之钟\n走近挥刃 · 金色±150ms", Vector3(6, 3.3, -3))
	player = load("res://actors/player/player.tscn").instantiate()
	player.position = Vector3(0, 0.1, 3)
	add_child(player)
	player.health.max_health = 10000.0
	player.health.health = 10000.0
	player.get_node("ShadowBody").enable_debug_keys = true
	Events.blade_parried.connect(_on_parry)
	var canvas := CanvasLayer.new()
	canvas.name = "CanvasLayer"
	add_child(canvas)
	_status = Label.new()
	_status.position = Vector2(24, 24)
	_status.add_theme_color_override("font_color", Color(0.08, 0.09, 0.13))
	_status.add_theme_font_size_override("font_size", 22)
	canvas.add_child(_status)
	var crosshair := Crosshair.new()
	crosshair.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	crosshair.name = "Crosshair"
	canvas.add_child(crosshair)
	for level in 5:
		var button := Button.new()
		button.text = "裂痕 %d" % level
		button.position = Vector2(24 + level * 100, 195)
		button.size = Vector2(92, 36)
		button.pressed.connect(func(): Events.sin_defeated.emit(level))
		canvas.add_child(button)

func _physics_process(delta: float) -> void:
	_time += delta
	_shot_left -= delta
	if _shot_left <= 0.0 and is_instance_valid(player):
		_shot_left = 2.0
		var origin := emitter.global_position + Vector3.UP * 1.4 + Vector3.BACK * 0.6
		var direction := (player.eye_position() - origin).normalized()
		Projectile.spawn(self, origin, direction, emitter, 35.0, 6.0,
			[(emitter.get_node("Hitbox") as Hitbox).get_rid()])

func _process(_delta: float) -> void:
	if not is_instance_valid(player) or not is_instance_valid(clock_point):
		return
	_status.text = "EPIC 1 · 战斗测试台\nWASD移动 / Shift冲刺 / V挥刃 / 左键射击 / 右键聚焦\n0–4 全身裂痕 · Esc释放鼠标点击等级按钮\n弹匣 %d/%d · 重组 %d%% · 弹反 %d\n敲钟 %d%% · %s · 距节拍 %.2fs" % [
		player.weapon.ammo, player.weapon.magazine_capacity(), player.weapon.reload_progress() * 100,
		_parries, clock_point.progress * 100, _last_strike, absf(CapturePoint.beat_offset(clock_point.beat_time()))]
	var crosshair := get_node("CanvasLayer/Crosshair") as Crosshair
	crosshair.focused = player.weapon.aiming
	crosshair.queue_redraw()

func _on_parry(_position: Vector3) -> void:
	_parries += 1
	HitStop.request(get_tree(), 0.05)

func _target(at: Vector3, moving: bool) -> CombatBenchTarget:
	var target := CombatBenchTarget.new()
	target.position = at
	target.moving = moving
	add_child(target)
	return target

func _box(at: Vector3, dimensions: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = at
	body.collision_layer = CollisionLayers.WORLD
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = dimensions
	shape.shape = box
	body.add_child(shape)
	var mesh := MeshInstance3D.new()
	var geometry := BoxMesh.new()
	geometry.size = dimensions
	mesh.mesh = geometry
	body.add_child(mesh)
	add_child(body)

func _sign(text: String, at: Vector3) -> void:
	var label := Label3D.new()
	label.text = text
	label.position = at
	label.modulate = Color(0.1, 0.12, 0.17)
	label.font_size = 48
	label.pixel_size = 0.007
	add_child(label)

func _build_clock() -> void:
	clock_point = CapturePoint.new()
	clock_point.position = Vector3(6, 0, -3)
	var reach := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = 3.2
	cylinder.height = 4.0
	reach.shape = cylinder
	reach.position.y = 1.0
	clock_point.add_child(reach)
	var objective := StaticBody3D.new()
	objective.name = "Objective"
	objective.collision_layer = CollisionLayers.WORLD
	objective.position.y = 1.0
	var mesh := MeshInstance3D.new()
	mesh.name = "Mesh"
	var geometry := BoxMesh.new()
	geometry.size = Vector3(2, 2, 2)
	mesh.mesh = geometry
	objective.add_child(mesh)
	var shape := CollisionShape3D.new()
	shape.name = "Shape"
	var box := BoxShape3D.new()
	box.size = geometry.size
	shape.shape = box
	objective.add_child(shape)
	clock_point.add_child(objective)
	add_child(clock_point)
	clock_point.open()
	clock_point.struck.connect(func(perfect: bool, _offset: float, _worth: float):
		_last_strike = "完美 +20%" if perfect else "普通 +10%")
	clock_point.captured.connect(func():
		get_tree().create_timer(3.0).timeout.connect(_reset_clock))

func _reset_clock() -> void:
	clock_point.queue_free()
	await get_tree().process_frame
	_build_clock()
