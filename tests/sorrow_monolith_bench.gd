extends Node3D
var player: Player
var boss: SorrowMonolith
var realm: SorrowRealm
var label: Label
func _ready() -> void:
	realm = SorrowRealm.new()
	realm.boss_arena = true
	add_child(realm)
	player = preload("res://actors/player/player.tscn").instantiate()
	player.position = Vector3(0,0,16)
	add_child(player)
	realm.set_player(player)
	boss = preload("res://actors/boss/sorrow_monolith/sorrow_monolith.tscn").instantiate()
	boss.position = Vector3(0,0,-8)
	boss.arena = realm
	add_child(boss)
	boss.setup(player,[])
	player.boons.register_enemy(boss)
	boss.realm_defeated.connect(_on_defeat)
	var layer := CanvasLayer.new()
	add_child(layer)
	label = Label.new()
	label.position = Vector2(28,24)
	label.add_theme_font_size_override("font_size",25)
	layer.add_child(label)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
func _process(_delta: float) -> void:
	if is_instance_valid(boss) and is_instance_valid(player):
		label.text = "哀泣巨碑 · 水位 %.2f m\nBoss %d / %d    生命 %d    温润屏障 %d\n离开落泪标记 · 登高躲浪 · 注意低台逐渐被淹没" % [realm.water_level,boss.health.health,boss.health.max_health,player.health.health,player.fragments.barrier]
		if boss.health.is_dead():
			label.text += "\n镜潭已蒸干、普通缓冲已剥夺；走近遗骸拾取温润碎片。"
func _on_defeat(_realm: int) -> void:
	player.fragments.configure_deprivation([3])
	var shard := preload("res://zone/psyche_shard_pickup.tscn").instantiate() as PsycheShardPickup
	shard.realm = 3
	shard.position = boss.position
	shard.setup(player)
	add_child(shard)
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
