extends Node3D
## Catalog completeness, seeded draw boundaries, and real zone reroll economy.
var _failures := 0
var _elapsed := 0.0

func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed > 60.0:
		push_error("Boon offer test timed out")
		get_tree().quit(1)

func _ready() -> void:
	await get_tree().process_frame
	var player := preload("res://actors/player/player.tscn").instantiate() as Player
	add_child(player)
	player.set_physics_process(false)
	var manager := player.boons
	var cards := BoonCatalog.all()
	_check("Epic 2 catalog has 48 family cards and 6 duals", cards.size() == 54)
	var ids: Dictionary = {}
	var family_counts := [0, 0, 0, 0]
	var duals := 0
	for card in cards:
		_check("unique authored card " + card.id, not ids.has(card.id) and not card.name.is_empty() and not card.description.is_empty())
		ids[card.id] = true
		if card.rarity == BoonData.Rarity.DUAL:
			duals += 1
		else:
			family_counts[card.sin] += 1
	_check("each family has twelve cards", family_counts == [12, 12, 12, 12] and duals == 6)
	var rng := RandomNumberGenerator.new()
	rng.seed = 124
	var opening := BoonOffers.pick(manager, rng, 3, -1, [], true)
	_check("entry offers gun blade and dash cores", opening.size() == 3 and opening[0].slot == BoonData.Slot.GUN and opening[1].slot == BoonData.Slot.BLADE and opening[2].slot == BoonData.Slot.DASH)
	var changed := BoonOffers.pick(manager, rng, 3, -1, opening, true)
	_check("entry reroll produces alternatives", changed.size() == 3 and not changed.any(func(card): return opening.has(card)))
	# 每系每槽只有唯一一张核心卡，所以重抽必须换领域，否则会抽回同一张。
	for i in 8:
		var again_a := BoonOffers.pick(manager, rng, 3, -1, [], true)
		var again_b := BoonOffers.pick(manager, rng, 3, -1, again_a, true)
		_check("entry reroll always switches realm",
			again_a.size() == 3 and again_b.size() == 3 and again_a[0].sin != again_b[0].sin)
	rng.seed = 124
	_check("same seed reproduces authored choices", opening == BoonOffers.pick(manager, rng, 3, -1, [], true))
	seed(99124)
	var expected_global := randi()
	seed(99124)
	BoonOffers.pick(manager, rng)
	_check("offer inspection preserves combat RNG", randi() == expected_global)
	_check("no draw for zero count", BoonOffers.pick(manager, rng, 0).is_empty())
	for sin_type in 4:
		var offered := BoonOffers.pick(manager, rng, 3, sin_type)
		_check("door %d gives matching, eligible and unique cards" % sin_type,
			offered.size() == 3 and offered.all(func(card): return card.sin == sin_type and manager.can_equip(card))
			and offered[0] != offered[1] and offered[0] != offered[2] and offered[1] != offered[2])
	manager.equip(opening[0])
	for i in 20:
		_check("owned cards and missing prerequisites excluded", BoonOffers.pick(manager, rng).all(func(card): return manager.can_equip(card) and card.id != opening[0].id))
	player.queue_free()
	await get_tree().process_frame
	RunState.clear_fixture()
	RunState.start_new_run()
	RunState.run_seed = 124
	var zone := load(RunState.zone_scene()).instantiate() as Node
	get_tree().root.add_child(zone)
	var director := zone.get_node("ZoneDirector") as ZoneDirector
	var picker := director.selection as BoonPicker
	_check("production entry uses new paused picker", picker != null and get_tree().paused and picker._offered.size() == 3)
	await _proof("05-production-entry.png")
	var first_ids: Array[BoonData] = picker._offered.duplicate()
	picker._request_reroll()
	_check("zone spends exactly one reroll and refreshes cards", RunState.boon_rerolls == 1 and picker._charges == 1 and picker._offered != first_ids)
	picker._request_reroll()
	picker._request_reroll()
	_check("zone allowance cannot underflow", RunState.boon_rerolls == 0 and picker._reroll.disabled)
	picker._choose(picker._offered[0])
	_check("acceptance persists immediately and starts combat", RunState.boons.size() == 1 and RunState.selection_history.size() == 1 and not get_tree().paused)
	var stored_id: String = RunState.boons[0].id
	director._spawn_pedestal()
	_check("production reward creates matching portal and sigil", director.reward_marker != null and director.reward_marker.show_frame and director.reward_marker.reward == director.reward_sin)
	var camera := director._player.weapon.camera
	camera.global_position = director.reward_marker.global_position + Vector3(0, -0.5, 6)
	camera.look_at(director.reward_marker.global_position + Vector3(0, -0.6, 0))
	await _proof("06-production-door.png")
	zone.queue_free()
	await get_tree().process_frame
	_check("scene exit preserves current loadout", RunState.boons.size() == 1 and RunState.boons[0].id == stored_id)
	RunState.start_new_run()
	_check("new run restores reroll allowance and clears loadout", RunState.boon_rerolls == 2 and RunState.boons.is_empty())
	await get_tree().process_frame
	OS.delay_msec(250)
	await get_tree().process_frame
	print("BOON OFFERS: %s (%d failed)" % ["ALL PASSED" if _failures == 0 else "FAIL", _failures])
	get_tree().quit(0 if _failures == 0 else 1)

func _check(label: String, passed: bool) -> void:
	print(("PASS " if passed else "FAIL ") + label)
	if not passed:
		_failures += 1

func _proof(filename: String) -> void:
	var directory := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--proof-dir="):
			directory = argument.trim_prefix("--proof-dir=")
	if directory.is_empty():
		return
	var paused := get_tree().paused
	get_tree().paused = true
	for frame in 45:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	_check("native production proof " + filename, get_viewport().get_texture().get_image().save_png(directory.path_join(filename)) == OK)
	get_tree().paused = paused
