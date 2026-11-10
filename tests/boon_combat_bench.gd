extends "res://tests/combat_bench.gd"
## Explicit sandbox loadouts expose legendary/dual mechanics despite the short
## three-choice prototype run. No RunState writes, normal rooms do not load this.

var _build: OptionButton
var _boon_status: Label
var _sandbags: Array[Node3D] = []
var _respawn_left := 0.0


func _ready() -> void:
	super._ready()
	player.stats.base[Stats.MAX_HEALTH] = 10000.0
	player.health.max_health = 10000.0
	player.health.health = 10000.0
	player.boons.rng.seed = 124123
	for target in [melee_target, emitter, moving_target]:
		player.boons.register_enemy(target)
	_spawn_sandbags()
	var panel := PanelContainer.new()
	panel.position = Vector2(24, 260)
	panel.custom_minimum_size.x = 360
	panel.add_theme_stylebox_override("panel", BoonPresentation.panel(Color(0.04, 0.05, 0.08, 0.94), Color("c3ad7b")))
	get_node("CanvasLayer").add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	box.add_child(BoonPresentation.label("EPIC 2 · 赐福试炼", 24, Color.WHITE))
	box.add_child(BoonPresentation.label("Esc 释放鼠标 · 调试构筑跳过发牌前置", 16, Color("bfc4d2")))
	_build = OptionButton.new()
	for title in ["怠惰 · 完整12卡", "恐惧 · 完整12卡", "暴怒 · 完整12卡", "悲伤 · 完整12卡",
		"蓄压熔岩", "惊惧泪海", "绝望反噬", "凝滞注视", "沉溺泥沼", "惊狂反扑"]:
		_build.add_item(title)
	box.add_child(_build)
	var equip := Button.new()
	equip.text = "应用测试构筑"
	equip.pressed.connect(_apply_build)
	box.add_child(equip)
	var reset := Button.new()
	reset.text = "清除赐福与现场状态"
	reset.pressed.connect(func(): player.boons.clear())
	box.add_child(reset)
	_boon_status = BoonPresentation.label("", 17, Color("e9d39e"))
	_boon_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_boon_status.custom_minimum_size = Vector2(320, 90)
	box.add_child(_boon_status)


func _process(delta: float) -> void:
	super._process(delta)
	_status.text = _status.text.replace("EPIC 1 · 战斗测试台", "EPIC 2 · 赐福战斗试炼")
	_respawn_left -= delta
	if _respawn_left <= 0.0:
		_respawn_left = 3.0
		_spawn_sandbags()
	if is_instance_valid(_boon_status):
		var names: PackedStringArray = []
		for slot in player.boons.slots:
			if slot.data != null:
				names.append(slot.data.name)
		_boon_status.text = " / ".join(names) + "\n被动 %d · 临时护盾 %.0f\n前方测试敌人可真实击退、撞墙与重生" % [player.boons.traits.size(), player.boons.shield_amount]


func _apply_build() -> void:
	player.boons.clear()
	var cards := BoonCatalog.all()
	var choice := _build.selected
	if choice < 4:
		for card in cards:
			if card.sin == choice and card.rarity != BoonData.Rarity.DUAL:
				player.boons.equip(card)
	else:
		var ids: Array[String] = ["dual_slumber_magma", "dual_tearful_panic", "dual_spiteful_deluge", "dual_frozen_paranoia", "dual_suffocating_mire", "dual_hysterical_rampage"]
		var id := ids[choice - 4]
		var dual: BoonData
		for card in cards:
			if card.id == id:
				dual = card
		if dual == null:
			return
		for slot in 3:
			var sin_type: int = dual.required_sins[1 if slot == 1 else 0]
			for card in cards:
				if card.core and card.slot == slot and card.sin == sin_type:
					player.boons.equip(card)
		if id == "dual_spiteful_deluge":
			for card in cards:
				if card.id == "sorrow_buffer":
					player.boons.equip(card)
		player.boons.equip(dual)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _spawn_sandbags() -> void:
	_sandbags = _sandbags.filter(func(actor): return is_instance_valid(actor) and not actor.is_queued_for_deletion())
	for index in 3:
		var occupied := _sandbags.any(func(actor): return actor.get_meta("bench_slot", -1) == index and not actor.health.is_dead())
		if occupied:
			continue
		var enemy := (load("res://actors/enemy/sloth/sloth_enemy.tscn") as PackedScene).instantiate() as SlothEnemy
		enemy.evade_chance = 0.0
		enemy.position = Vector3(-5.0 + index * 4.0, 0.0, -19.0)
		enemy.set_meta("bench_slot", index)
		add_child(enemy)
		enemy.health.max_health = 1500.0
		enemy.health.health = 1500.0
		player.boons.register_enemy(enemy)
		_sandbags.append(enemy)
