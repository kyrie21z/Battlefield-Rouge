extends Node3D
## Standalone playable boss slice; the production realm stage owns progression.
var realm: FearRealm
var player: Player
var boss: FearOculus
var status: Label
var shard: PsycheShardPickup

func _ready() -> void:
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.006, 0.004, 0.012)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(0.68, 0.62, 0.82)
	environment.environment.ambient_light_energy = 0.85
	environment.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.environment.glow_enabled = true
	add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-42, -20, 0)
	light.light_energy = 1.4
	light.shadow_enabled = true
	add_child(light)
	realm = FearRealm.new()
	realm.boss_arena = true
	add_child(realm)
	player = preload("res://actors/player/player.tscn").instantiate() as Player
	player.position = Vector3(0, 0.02, 10)
	add_child(player)
	boss = preload("res://actors/boss/fear_oculus/fear_oculus.tscn").instantiate() as FearOculus
	boss.position = Vector3(0, 0, -8)
	boss.arena = realm
	add_child(boss)
	boss.setup(player, [])
	player.boons.register_enemy(boss)
	boss.defeated.connect(_on_boss_defeated)
	var layer := CanvasLayer.new()
	add_child(layer)
	status = Label.new()
	status.position = Vector2(26, 22)
	status.add_theme_font_size_override("font_size", 22)
	status.add_theme_color_override("font_color", Color(0.86, 0.75, 1))
	layer.add_child(status)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _on_boss_defeated() -> void:
	# This bench performs the same explicit injected transition as RealmStage.
	player.fragments.configure_deprivation([PsycheFragments.FEAR])
	shard = preload("res://zone/psyche_shard_pickup.tscn").instantiate() as PsycheShardPickup
	shard.name = "ShardOfVigilance"
	shard.realm = PsycheFragments.FEAR
	shard.position = boss.position + Vector3(0, 0.05, 3)
	add_child(shard)
	shard.setup(player)

func _process(_delta: float) -> void:
	if status == null:
		return
	status.text = "审判之瞳 / SUSPENDED OCULUS   HP %d / %d\n你的生命 %d · 横移避开扫描/切割，跳过低位环波，恢复期射击眼瞳。\n左键射击 / 右键 ADS / V 挥刃 / Shift 冲刺 / F6 重开" % [boss.health.health, boss.health.max_health, player.health.health]
	if boss.health.is_dead():
		status.text += "\n审判之瞳已碎裂；本场所有危险预警已永久消失。走近眼瞳下方拾取警醒的碎片。"
	if player.fragments.has_shard(PsycheFragments.FEAR):
		status.text += "\n警醒已入库：暴击率 +15%、冲刺恢复 +20%；普通危险预警仍然关闭。"
	if player.health.is_dead():
		status.text += "\n失败。按 F6 再试。"

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_F6:
			get_tree().reload_current_scene()
		elif event.physical_keycode == KEY_ESCAPE:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED
