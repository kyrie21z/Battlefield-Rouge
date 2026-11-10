extends Node3D
var player: Player
var realm: SorrowRealm
var actors: Array[SorrowRealmEnemy] = []
func _ready() -> void:
	realm = SorrowRealm.new()
	add_child(realm)
	player = preload("res://actors/player/player.tscn").instantiate()
	player.position = Vector3(0,0,16)
	add_child(player)
	realm.set_player(player)
	for i in 3:
		var actor := preload("res://actors/enemy/sorrow/sorrow_realm_enemy.tscn").instantiate() as SorrowRealmEnemy
		actor.variant = i
		actor.position = Vector3((i-1)*5,0,-4)
		actor.arena = realm
		add_child(actor)
		actor.setup(player,[])
		player.boons.register_enemy(actor)
		actors.append(actor)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var layer := CanvasLayer.new()
	add_child(layer)
	var label := Label.new()
	label.text = "悲伤镜潭 · WASD / 左键 / V / Shift\n溶蚀者潜水绕后 · 沉沦者压制跳跃冲刺 · 哀泣者延长换弹冷却"
	label.position = Vector2(24,24)
	label.add_theme_font_size_override("font_size",24)
	layer.add_child(label)
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
