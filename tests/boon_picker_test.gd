extends Node3D
## Real manager, paused CanvasLayer, input, cancellation, and world-marker proof.

var _failures := 0
var _player: Player
var _manager: BoonManager
var _picked := 0
var _proof := ""
var _elapsed := 0.0


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed > 60.0:
		push_error("Boon picker test timed out")
		get_tree().quit(1)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--proof="):
			_proof = arg.trim_prefix("--proof=")
	await get_tree().process_frame
	_player = preload("res://actors/player/player.tscn").instantiate()
	add_child(_player)
	_player.set_physics_process(false)
	_manager = _player.boons
	await _test_selection()
	await _test_markers()
	_player.queue_free()
	get_tree().paused = false
	await get_tree().process_frame
	OS.delay_msec(250)
	await get_tree().process_frame
	print("BOON PICKER: %s (%d failed)" % ["ALL PASSED" if _failures == 0 else "FAIL", _failures])
	get_tree().quit(0 if _failures == 0 else 1)


func _card(id: String, sin_type: int, slot: int, multiplier: float) -> BoonData:
	var data := BoonData.new()
	data.id = id
	data.name = ["滞后晶弹", "弱点凝视", "轰墙重击", "溶蚀涟漪"][sin_type]
	data.sin = sin_type
	data.slot = slot
	data.description = ["命中施加 1.5 秒滞后，减速 40%。到期爆发 60 点基础伤害；后续射击每次蓄压 +25。", "暴露敌人的实体破绽 4 秒。命中破绽造成 260% 暴击伤害，并将破绽转移到背后。", "近战扇形扩大 50%。强劲冲击将敌人轰向墙面，撞击眩晕 0.8 秒。", "每次命中附加 1 层溶蚀，每层承伤 +10%，最多 5 层。满层凝聚泪晶，拾取恢复 25 护盾。"][sin_type]
	data.stat_modifiers = {Stats.DAMAGE: {"mul": multiplier}}
	data.rarity = [BoonData.Rarity.RARE, BoonData.Rarity.EPIC, BoonData.Rarity.LEGENDARY, BoonData.Rarity.COMMON][sin_type]
	return data


func _picker(cards: Array[BoonData], charges: int = 2) -> BoonPicker:
	var picker := preload("res://ui/boon_picker/boon_picker.tscn").instantiate() as BoonPicker
	add_child(picker)
	picker.setup(cards, _manager, "穿过心魔的门扉", charges)
	picker.chosen.connect(func(_card_data): _picked += 1)
	return picker


func _test_selection() -> void:
	var sloth := _card("test_sloth", 0, 0, 1.2)
	var fear := _card("test_fear", 1, 0, 1.4)
	var wrath := _card("test_wrath", 2, 1, 1.6)
	var sorrow := _card("test_sorrow", 3, 2, 1.1)
	var picker := _picker([sloth, fear, wrath])
	_check("entry pauses combat and exposes three cards", get_tree().paused and picker._buttons.size() == 3)
	await get_tree().create_timer(0.85, true).timeout
	_check("entrance animation runs while combat paused", picker._buttons.all(func(button: Button): return button.scale.is_equal_approx(Vector2.ONE) and button.modulate.a > 0.99))
	await _shot("01-three-cards")
	var rerolls := [0]
	picker.reroll_requested.connect(func():
		rerolls[0] += 1
		picker.update_offer([sloth, wrath, sorrow], 1)
		picker.show_reroll_cost())
	picker._request_reroll()
	_check("reroll emits once and shows consumption", rerolls[0] == 1 and picker._charges == 1 and picker._notice.text.contains("−1"))
	picker.update_offer([sloth, fear, wrath], 0)
	picker._request_reroll()
	_check("empty reroll cannot spend", rerolls[0] == 1 and picker._reroll.disabled)
	picker._choose(sloth)
	picker._choose(wrath)
	_check("only one equip and resumes combat", _picked == 1 and _manager.has(sloth.id) and not _manager.has(wrath.id) and not get_tree().paused)
	await get_tree().process_frame
	picker = _picker([fear, wrath, sorrow])
	_check("occupied slot shows explicit red replacement", picker._buttons[0].get_children()[0].get_children().back().text.contains(sloth.name))
	picker._choose(fear)
	_check("replacement waits while keeping old effect", get_tree().paused and _manager.has(sloth.id) and not _manager.has(fear.id) and picker._confirmation.visible)
	picker._request_reroll()
	picker._choose(wrath)
	_check("confirmation blocks other choices and rerolls", _picked == 1 and not _manager.has(wrath.id))
	await get_tree().create_timer(0.8, true).timeout
	await _shot("02-replacement-confirm")
	picker.confirm_replacement(false)
	_check("cancel preserves old source modifier", is_equal_approx(_player.stats.get_value(Stats.DAMAGE), 1.2) and not picker._confirmation.visible)
	picker._choose(fear)
	picker.confirm_replacement(true)
	_check("confirmed replacement removes previous modifier", _picked == 2 and not _manager.has(sloth.id) and _manager.has(fear.id) and is_equal_approx(_player.stats.get_value(Stats.DAMAGE), 1.4))
	await get_tree().process_frame
	_manager.clear()
	picker = _picker([sloth, wrath, sorrow])
	await get_tree().create_timer(0.8, true).timeout
	await _shot("03-amber-red-blue")
	var key := InputEventKey.new()
	key.pressed = true
	key.physical_keycode = KEY_3
	Input.parse_input_event(key)
	Input.flush_buffered_events()
	_check("number key equips the intended third card", _manager.has(sorrow.id) and _picked == 3)
	key = key.duplicate() as InputEventKey
	key.pressed = false
	Input.parse_input_event(key)
	Input.flush_buffered_events()
	await get_tree().process_frame
	picker = _picker([sloth, fear, wrath])
	picker.queue_free()
	await get_tree().process_frame
	_check("dismissal releases owned pause", not get_tree().paused)
	picker = _picker([sloth, fear, wrath])
	picker.dismiss_for_transition()
	picker._choose(wrath)
	_check("transition rejects queued selection and keeps the incoming screen's pause", not _manager.has(wrath.id) and _picked == 3 and get_tree().paused)
	await get_tree().process_frame
	get_tree().paused = false
	picker = _picker([])
	_check("exhausted pool exposes a way to continue", get_tree().paused and picker._continue.visible and picker._reroll.disabled)
	picker._skip_empty()
	_check("exhausted pool cannot trap the game paused", not get_tree().paused)
	await get_tree().process_frame


func _test_markers() -> void:
	_player.hide()
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("101722")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color.WHITE
	settings.ambient_light_energy = 0.8
	environment.environment = settings
	add_child(environment)
	var camera := Camera3D.new()
	add_child(camera)
	camera.fov = 50.0
	camera.global_position = Vector3(0, 1.7, 11.6)
	camera.look_at(Vector3(0, 1.7, 0))
	camera.make_current()
	for i in 7:
		var marker := preload("res://zone/door/door_reward_marker.tscn").instantiate() as DoorRewardMarker
		marker.reward = i
		marker.hint = "房间收益"
		marker.position = Vector3((i - 1.5) * 4.2, 4.0, 0) if i < 4 else Vector3((i - 5) * 4.8, 0.0, 0)
		add_child(marker)
		_check("world reward %d has matching symbol and text" % i, marker._icon.texture != null and marker._title.text.begins_with(DoorRewardMarker.TITLES[i]))
		var pillar := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(1.8, 0.6, 0.7)
		pillar.mesh = mesh
		pillar.position = marker.position + Vector3(0, -1.5, 0)
		add_child(pillar)
	await get_tree().create_timer(0.3, true).timeout
	await _shot("04-seven-door-rewards")


func _shot(name: String) -> void:
	if _proof.is_empty() or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_proof))
	var result := get_viewport().get_texture().get_image().save_png(_proof.path_join(name + ".png"))
	_check("screenshot " + name, result == OK)


func _check(label: String, passed: bool) -> void:
	print(("PASS " if passed else "FAIL ") + label)
	if not passed:
		_failures += 1
