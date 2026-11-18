extends Node
## 三张都只会替换现有核心卡时，界面必须给出"放弃这次馈赠"的出口，
## 而不是逼玩家每次拆掉一件构筑才能继续。

var checks := 0
var failures := 0


func _ready() -> void:
	var stage := preload("res://maps/realms/sloth_1.tscn").instantiate() as RealmStage
	add_child(stage)
	await _frames(3)
	var manager := stage.player.boons
	manager.equip(load("res://buffs/resources/fear/gaze_pierce.tres") as BoonData)
	manager.equip(load("res://buffs/resources/sloth/sloth_blade_cleave.tres") as BoonData)
	manager.equip(load("res://buffs/resources/fear/tremor_decoy.tres") as BoonData)

	var offer: Array[BoonData] = [
		load("res://buffs/resources/wrath/wrath_gun_cannon.tres") as BoonData,
		load("res://buffs/resources/wrath/wrath_blade_sweep.tres") as BoonData,
		load("res://buffs/resources/sorrow/sorrow_dash_ribbon.tres") as BoonData]
	var picker := preload("res://ui/boon_picker/boon_picker.tscn").instantiate() as BoonPicker
	add_child(picker)
	picker.setup(offer, manager, "替换测试", 0)
	await _frames(2)

	_check(picker._all_replacements(), "three replacement-only cards are recognised")
	_check(picker._continue.visible and picker._continue.text == "放弃这次馈赠",
		"the give-up button is offered")
	_check(picker._notice.text.contains("可以放弃"), "the footer explains the give-up option")

	var skipped := [0]
	picker.skipped.connect(func() -> void: skipped[0] += 1)
	picker._skip_empty()
	await _frames(3)
	_check(skipped[0] == 1, "giving up emits exactly one skip")
	_check(not get_tree().paused, "giving up resumes combat")

	# 只要有一张不是替换（特性卡），就不该出现放弃按钮。
	var stage_two := preload("res://maps/realms/sloth_1.tscn").instantiate() as RealmStage
	add_child(stage_two)
	await _frames(3)
	var manager_two := stage_two.player.boons
	manager_two.equip(load("res://buffs/resources/fear/gaze_pierce.tres") as BoonData)
	manager_two.equip(load("res://buffs/resources/sloth/sloth_blade_cleave.tres") as BoonData)
	manager_two.equip(load("res://buffs/resources/fear/tremor_decoy.tres") as BoonData)
	var mixed: Array[BoonData] = [
		load("res://buffs/resources/wrath/wrath_gun_cannon.tres") as BoonData,
		load("res://buffs/resources/sloth/sloth_inertia.tres") as BoonData]
	var second := preload("res://ui/boon_picker/boon_picker.tscn").instantiate() as BoonPicker
	add_child(second)
	second.setup(mixed, manager_two, "混合测试", 0)
	await _frames(2)
	_check(not second._all_replacements(), "a non-replacement card clears the flag")
	_check(not second._continue.visible, "no give-up button when a real choice exists")
	second.dismiss_for_transition()
	stage.queue_free()
	stage_two.queue_free()
	await _frames(3)
	print("BOON REPLACEMENT: %d checks, %d failed" % [checks, failures])
	get_tree().quit(1 if failures else 0)


func _check(passed: bool, label: String) -> void:
	checks += 1
	if not passed:
		failures += 1
	print(("[ok] " if passed else "[FAIL] ") + label)


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame
