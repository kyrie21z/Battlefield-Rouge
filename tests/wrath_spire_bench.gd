extends Node3D
var player: Player
var boss: WrathSpire
var realm: WrathRealm
var label: Label

func _ready() -> void:
	realm = WrathRealm.new()
	realm.boss_arena = true
	add_child(realm)
	player = preload("res://actors/player/player.tscn").instantiate()
	player.position = Vector3(0, 0, 16)
	add_child(player)
	boss = preload("res://actors/boss/wrath_spire/wrath_spire.tscn").instantiate()
	boss.position = Vector3(0, 0, -8)
	boss.arena = realm
	add_child(boss)
	boss.setup(player, [])
	player.boons.register_enemy(boss)
	boss.realm_defeated.connect(_on_defeat)
	var layer := CanvasLayer.new()
	add_child(layer)
	label = Label.new()
	label.position = Vector2(28, 24)
	label.add_theme_font_size_override("font_size", 26)
	layer.add_child(label)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _process(_delta: float) -> void:
	if is_instance_valid(boss) and is_instance_valid(player):
		label.text = "狂暴尖塔 · 击碎锋芒\nBoss %d / %d     生命 %d\n跳跃避开地裂 · 侧移避开旋风冲锋 · 利用收招窗口" % [boss.health.health, boss.health.max_health, player.health.health]
		if boss.health.is_dead():
			label.text += "\n熔炉已冷却。普通击退已剥夺；走近尖塔遗骸拾取锋芒碎片。"

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _on_defeat(_realm: int) -> void:
	player.fragments.configure_deprivation([2])
	var shard := preload("res://zone/psyche_shard_pickup.tscn").instantiate() as PsycheShardPickup
	shard.realm = 2
	shard.position = boss.position
	shard.setup(player)
	add_child(shard)
	shard.collected.connect(_on_collected)

func _on_collected(_realm: int) -> void:
	var guard := preload("res://actors/enemy/wrath/wrath_realm_enemy.tscn").instantiate() as WrathRealmEnemy
	guard.variant = 2
	guard.position = Vector3(-5,0,-8)
	add_child(guard)
	guard.setup(player,[])
	player.boons.register_enemy(guard)
