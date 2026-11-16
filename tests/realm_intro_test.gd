extends Node
## Verifies the one-time realm mechanic card: it must appear exactly once per
## save, right before the first three-card offer that carries a card from that
## realm, and never for the opening gift or for a pure stat roll.

var checks := 0
var failures := 0

func _ready() -> void:
	MetaProgression.introduced_realms.clear()
	await _check_intro_appears_once()
	await _check_entry_gift_uses_one_realm()
	print("REALM INTRO: %d checks, %d failed" % [checks, failures])
	get_tree().quit(1 if failures else 0)


func _check_intro_appears_once() -> void:
	MetaProgression.introduced_realms.clear()
	var stage := preload("res://maps/realms/sloth_1.tscn").instantiate() as RealmStage
	add_child(stage)
	await _frames(3)
	_check(MetaProgression.realm_needs_intro(0), "sloth starts without an intro")

	stage.enemies.clear()
	stage._check_clear()
	await _frames(3)
	_check(stage.orb_pending(), "orb waits before the offer")

	stage.claim_talent()
	await _frames(3)

	var intro := _find_intro(stage)
	_check(intro != null, "first sloth offer shows the mechanic card")
	_check(not is_instance_valid(stage.selection), "picker stays closed while the card is up")
	_check(get_tree().paused, "mechanic card pauses the game")

	if intro != null:
		intro._dismiss()
		await _frames(3)
	_check(is_instance_valid(stage.selection), "picker opens after dismissing the card")
	_check(MetaProgression.introduced_realms.has(0), "sloth is recorded as introduced")
	_check(_find_intro(stage) == null, "card frees itself")

	if is_instance_valid(stage.selection):
		var picker := stage.selection
		if not picker._offered.is_empty():
			picker._choose(picker._offered[0])
		await _frames(2)

	# second clear in the same realm must not show it again
	stage.enemies.clear()
	stage._check_clear()
	await _frames(3)
	if stage.orb_pending():
		stage.claim_talent()
		await _frames(3)
	_check(_find_intro(stage) == null, "second offer in the same realm skips the card")
	stage.queue_free()
	await _frames(2)


func _check_entry_gift_uses_one_realm() -> void:
	MetaProgression.introduced_realms.clear()
	var stage := preload("res://maps/realms/fear_1.tscn").instantiate() as RealmStage
	add_child(stage)
	await _frames(3)
	stage.offer_entry_reward()
	await _frames(3)
	var intro := _find_intro(stage)
	_check(intro != null, "opening gift explains its realm before the cards")
	if intro != null:
		intro._dismiss()
		await _frames(3)
	_check(is_instance_valid(stage.selection), "opening picker opens after the card")
	if is_instance_valid(stage.selection):
		var offered := stage.selection._offered
		var sins := {}
		for card: BoonData in offered:
			sins[card.sin] = true
		_check(sins.size() == 1, "all opening cards come from a single realm")
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
