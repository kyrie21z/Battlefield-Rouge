extends Node3D
const ACTOR := preload("res://actors/enemy/sloth/sloth_realm_enemy.tscn")
const PLAYER := preload("res://actors/player/player.tscn")
var player: Player
var enemies: Array[SlothRealmEnemy] = []
var geometry: SlothRealm
var region: NavigationRegion3D
var _status: Label

func _init() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE

func _ready() -> void:
	seed(138)
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.80,0.79,0.73)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.95,0.90,0.80)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.42
	world.environment = env
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52,-28,0)
	sun.light_energy = 1.8
	sun.shadow_enabled = true
	add_child(sun)
	region = NavigationRegion3D.new()
	var nav := NavigationMesh.new()
	nav.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nav.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_GROUPS_WITH_CHILDREN
	nav.geometry_source_group_name = "navigation_geometry"
	nav.agent_radius = 0.5
	nav.agent_height = 2.0
	nav.cell_size = 0.5
	nav.cell_height = 0.25
	region.navigation_mesh = nav
	add_child(region)
	geometry = SlothRealm.new()
	geometry.boss_arena = bool(get_meta("boss_arena",false))
	region.add_child(geometry)
	region.bake_navigation_mesh(false)
	player = PLAYER.instantiate()
	player.position = Vector3(0,0,16)
	add_child(player)
	_spawn_encounter()
	var hud := CanvasLayer.new()
	add_child(hud)
	var title := Label.new()
	title.text = "SLOTH · STILLNESS\nLaggard / Anchor / Retreater"
	title.position = Vector2(24,22)
	title.add_theme_font_size_override("font_size",24)
	title.modulate = Color(0.21,0.14,0.06)
	hud.add_child(title)
	_status = Label.new()
	_status.position = Vector2(24,100)
	_status.add_theme_font_size_override("font_size",18)
	_status.modulate = Color(0.16,0.12,0.06)
	hud.add_child(_status)
	var crosshair := Label.new()
	crosshair.text = "+"
	crosshair.position = Vector2(630,350)
	hud.add_child(crosshair)
	get_tree().paused = false

func _process(_delta: float) -> void:
	if is_instance_valid(player):
		_status.text = "HP %d   Ammo %d   Shift dash · V blade · F8 restart" % [player.health.health,player.weapon.ammo]
	if Input.is_physical_key_pressed(KEY_F8):
		get_tree().reload_current_scene()

func _spawn_encounter() -> void:
	for i in 3:
		var actor := ACTOR.instantiate() as SlothRealmEnemy
		actor.variant = i
		actor.position = [Vector3(0,0,1),Vector3(-10,0,-9),Vector3(10,0,-9)][i]
		add_child(actor)
		actor.setup(player,[])
		player.boons.register_enemy(actor)
		enemies.append(actor)
