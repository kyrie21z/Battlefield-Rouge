extends Node
## Exercise every explicit sandbox preset through the production bench buttons.
var _failures := 0

func _ready() -> void:
	var bench := preload("res://tests/boon_combat_bench.tscn").instantiate()
	add_child(bench)
	bench.player.set_physics_process(false)
	await get_tree().physics_frame
	for preset in 10:
		bench._build.select(preset)
		bench._apply_build()
		await get_tree().physics_frame
		var manager: BoonManager = bench.player.boons
		_check("preset %d installs three actual core slots" % preset, manager.slots[0].data != null and manager.slots[1].data != null and manager.slots[2].data != null)
		if preset < 4:
			_check("family %d installs twelve cards" % preset, manager.all_equipped().size() == 12)
		else:
			var dual: BoonData = manager.traits.back()
			var effect := manager.effect_for(preload("res://buffs/dual/dual_boon_manager.gd")) as DualBoonManager
			_check("dual preset %d meets real active-core requirements" % preset, dual.rarity == BoonData.Rarity.DUAL and effect != null and effect._active(dual.id))
		manager.clear()
		_check("preset clear restores unmodified fire rate", is_equal_approx(bench.player.stats.get_value(Stats.FIRE_RATE), 1.0))
	_check("three physical wall-slam targets registered", bench._sandbags.size() == 3 and bench.player.boons.enemies().size() >= 3)
	bench._build.select(5)
	bench._apply_build()
	var proof := ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--proof="):
			proof = argument.trim_prefix("--proof=")
	if not proof.is_empty():
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		for frame in 12:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		_check("native bench proof saved", get_viewport().get_texture().get_image().save_png(proof) == OK)
	bench.player.boons.clear()
	bench.queue_free()
	await get_tree().process_frame
	OS.delay_msec(250)
	await get_tree().process_frame
	print("BOON BENCH: %s (%d failed)" % ["ALL PASSED" if _failures == 0 else "FAIL", _failures])
	get_tree().quit(0 if _failures == 0 else 1)

func _check(label: String, passed: bool) -> void:
	print(("PASS " if passed else "FAIL ") + label)
	if not passed:
		_failures += 1
