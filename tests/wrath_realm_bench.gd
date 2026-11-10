extends Node3D
const ENEMY := preload("res://actors/enemy/wrath/wrath_realm_enemy.tscn")
var player: Player
var actors: Array[WrathRealmEnemy] = []
var realm: WrathRealm
var label: Label

func _ready() -> void:
	realm = WrathRealm.new()
	add_child(realm)
	player = preload("res://actors/player/player.tscn").instantiate()
	add_child(player)
	player.position = Vector3(0, 0, 16)
	for i in 3:
		var actor := ENEMY.instantiate() as WrathRealmEnemy
		actor.variant = i
		actor.position = Vector3((i - 1) * 7, 0, -2 - i * 2)
		add_child(actor)
		actor.setup(player, [])
		player.boons.register_enemy(actor)
		actors.append(actor)
	var layer := CanvasLayer.new()
	add_child(layer)
	label = Label.new()
	label.position = Vector2(28, 24)
	label.add_theme_font_size_override("font_size", 24)
	layer.add_child(label)
	var cross := Label.new()
	cross.text = "+"
	cross.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	layer.add_child(cross)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _process(_delta: float) -> void:
	if player != null:
		label.text = "愤怒 · 熔炉断壁\n左：突刺者 | 中：蓄压体 | 右：侵犯者\nWASD 移动 · 左键射击 · V 挥刃 · Shift 冲刺 · Esc 释放鼠标\n生命 %d / %d" % [player.health.health, player.health.max_health]

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
