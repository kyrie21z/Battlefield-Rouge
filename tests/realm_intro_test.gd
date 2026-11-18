extends Node
## 领域机制说明不再是选卡前的一次性面板，而是每张卡自己的悬浮提示；
## 另外验证新一局开局会有一次三选一。

var checks := 0
var failures := 0


func _ready() -> void:
	await _check_offer_has_no_panel()
	await _check_tooltip_carries_realm_help()
	await _check_opening_choice()
	print("REALM INTRO: %d checks, %d failed" % [checks, failures])
	get_tree().quit(1 if failures else 0)


## 清房后应当直接开选卡界面，中间不再插一个"知道了"面板。
func _check_offer_has_no_panel() -> void:
	var stage := preload("res://maps/realms/sloth_1.tscn").instantiate() as RealmStage
	add_child(stage)
	await _frames(3)
	stage.enemies.clear()
	stage._check_clear()
	await _frames(3)
	_check(stage.orb_pending(), "orb waits before the offer")
	stage.claim_talent()
	await _frames(3)
	_check(_find_intro(stage) == null, "no separate mechanic panel before the offer")
	_check(is_instance_valid(stage.selection), "picker opens immediately")
	_check(get_tree().paused, "picker still pauses combat")
	stage.queue_free()
	await _frames(2)


## 每张卡的悬浮说明都带着它所属领域的机制要点；双重卡同时列两系。
func _check_tooltip_carries_realm_help() -> void:
	var stage := preload("res://maps/realms/sloth_1.tscn").instantiate() as RealmStage
	add_child(stage)
	await _frames(3)
	stage.enemies.clear()
	stage._check_clear()
	await _frames(3)
	stage.claim_talent()
	await _frames(3)
	var picker := stage.selection
	if is_instance_valid(picker) and picker._buttons.size() == picker._offered.size():
		var ok := picker._offered.size() > 0
		for index in picker._offered.size():
			var card: BoonData = picker._offered[index]
			var help: String = picker._help_for(card)
			ok = ok and not help.is_empty() \
				and help.contains(String(RealmIntro.INTRO[card.sin]["title"]))
		_check(ok, "each card explains its own realm")
		var dual := load("res://buffs/resources/dual/slumber_magma.tres") as BoonData
		var both: String = picker._help_for(dual)
		_check(both.contains(String(RealmIntro.INTRO[0]["title"]))
			and both.contains(String(RealmIntro.INTRO[2]["title"])),
			"dual card explains both realms")
		var hovered: BoonData = picker._offered[0]
		picker._hover_help(hovered)
		_check(picker._mechanic.text.contains(String(RealmIntro.INTRO[hovered.sin]["title"])),
			"hovering a card writes its realm into the mechanic bar")
		picker._reset_help()
		_check(picker._mechanic.text == picker.IDLE_HINT,
			"leaving the card restores the idle hint")
	else:
		_check(false, "picker exposes one explanation per offered card")
	if is_instance_valid(picker):
		picker.dismiss_for_transition()
	await _frames(2)
	stage.queue_free()
	await _frames(2)


## 新一局的第一关，进场就给一次三选一，且三张是同一领域的核心卡。
func _check_opening_choice() -> void:
	var stage := preload("res://maps/realms/sloth_1.tscn").instantiate() as RealmStage
	stage.campaign = true
	add_child(stage)
	await _frames(4)
	var opened := is_instance_valid(stage.selection) and stage._reward_context == "enter"
	_check(opened, "a new run opens one choice on its first room")
	if opened:
		var all_core := not stage.selection._offered.is_empty()
		var same_sin := true
		var first_sin := -1
		for card: BoonData in stage.selection._offered:
			all_core = all_core and card.core
			if first_sin < 0:
				first_sin = card.sin
			same_sin = same_sin and card.sin == first_sin
		_check(all_core and same_sin, "opening offer is one realm's three cores")
		stage.selection._choose(stage.selection._offered[0])
		await _frames(3)
		_check(not get_tree().paused, "choosing resumes combat")
		_check(not stage.exit_ready, "opening choice does not open the gate")
		_check(not stage.player.boons.all_equipped().is_empty(),
			"the opening card stays equipped after the choice")
	stage.queue_free()
	await _frames(2)


func _find_intro(stage: Node) -> RealmIntro:
	for child in stage.get_children():
		if child is RealmIntro:
			return child
	return null


func _check(passed: bool, label: String) -> void:
	checks += 1
	if not passed:
		failures += 1
	print(("[ok] " if passed else "[FAIL] ") + label)


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame
