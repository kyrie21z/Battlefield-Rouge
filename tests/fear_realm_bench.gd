extends Node3D
## Explicit playable Fear slice: production player, geometry and all three actors.
var realm: FearRealm
var player: Player
var enemies: Array[FearRealmEnemy] = []
var status: Label
var navigation: NavigationRegion3D

func _ready() -> void:
	build_environment()
	navigation = NavigationRegion3D.new()
	navigation.navigation_mesh = NavigationMesh.new()
	navigation.navigation_mesh.agent_radius = 0.5
	navigation.navigation_mesh.agent_height = 2.0
	navigation.navigation_mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	navigation.navigation_mesh.geometry_collision_mask = CollisionLayers.WORLD
	add_child(navigation)
	realm = FearRealm.new()
	navigation.add_child(realm)
	navigation.bake_navigation_mesh(false)
	player = preload("res://actors/player/player.tscn").instantiate() as Player
	player.position = realm.player_spawn()
	add_child(player)
	for index in 3:
		var enemy := preload("res://actors/enemy/fear/fear_realm_enemy.tscn").instantiate() as FearRealmEnemy
		enemy.variant = index
		enemy.position = realm.spawn_points()[index]
		enemy.arena = realm
		add_child(enemy)
		enemy.setup(player, [])
		player.boons.register_enemy(enemy)
		enemies.append(enemy)
	var layer := CanvasLayer.new()
	add_child(layer)
	status = Label.new()
	status.position = Vector2(26, 22)
	status.add_theme_font_size_override("font_size", 22)
	status.add_theme_color_override("font_color", Color(0.85, 0.76, 0.98))
	layer.add_child(status)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func build_environment() -> void:
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.006, 0.004, 0.012)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(0.66, 0.62, 0.85)
	environment.environment.ambient_light_energy = 0.8
	environment.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.environment.glow_enabled = true
	add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50, -25, 0)
	light.light_energy = 1.4
	light.shadow_enabled = true
	add_child(light)

func _process(_delta: float) -> void:
	if status == null:
		return
	status.text = "FEAR / 恐惧之境   HP %d\n红线蓄力：直视窥视者打断；紫影瞬移；地块翻转后会跌落。\nWASD 移动 / 左键射击 / V 挥刃 / Shift 冲刺 / Esc 光标 / F6 重开" % player.health.health
	if player.health.is_dead():
		status.text += "\n深渊或敌人击败了你，按 F6 重开。"

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_F6:
			get_tree().reload_current_scene()
		elif event.physical_keycode == KEY_ESCAPE:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED
