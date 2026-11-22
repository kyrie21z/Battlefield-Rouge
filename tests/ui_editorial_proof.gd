extends Node
## Native Godot 4.7.2 proof capture for Scheme B (Architectural Editorial) UI/HUD redesign.
## Saves crisp 1280x720 screenshots into docs/proof/ui-editorial/ (or --out=<dir>).

var _out_dir := "res://docs/proof/ui-editorial"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out_dir = arg.trim_prefix("--out=")
	var abs_out := ProjectSettings.globalize_path(_out_dir) if _out_dir.begins_with("res://") else _out_dir
	DirAccess.make_dir_recursive_absolute(abs_out)
	await _frames(3)

	await _shot_sloth_hud(abs_out)
	await _shot_wrath_hud(abs_out)
	await _shot_boss_bar(abs_out)
	await _shot_boon_picker(abs_out)
	await _shot_build_inspector(abs_out)
	await _shot_crown_forge(abs_out)
	await _shot_pause_menu(abs_out)
	await _shot_opening_title(abs_out)

	print("UI EDITORIAL PROOF: 8 screenshots saved to ", abs_out)
	get_tree().quit(0)


func _shot_sloth_hud(out: String) -> void:
	var stage := preload("res://maps/realms/sloth_1.tscn").instantiate() as RealmStage
	add_child(stage)
	await _frames(6)
	_equip_sample_build(stage.player)
	stage.player.weapon.ammo = 6
	stage.player.health.apply_damage(26.0, Hitbox.BodyPart.BODY, null)
	stage.hud.hurt_feedback.hide()
	stage.hud.vitals.advance(0.05)
	stage.hud.vitals.dash_charges = 1
	stage.hud.vitals.dash_recharge_fraction = 0.58
	stage.hud.vitals.queue_redraw()
	await _frames(4)
	await _save(out, "01-sloth-hud.png")
	stage.queue_free()
	await _frames(3)


func _shot_wrath_hud(out: String) -> void:
	var stage := preload("res://maps/realms/wrath_1.tscn").instantiate() as RealmStage
	add_child(stage)
	await _frames(6)
	_equip_sample_build(stage.player)
	stage.player.weapon.ammo = 2
	stage.player.health.apply_damage(18.0, Hitbox.BodyPart.BODY, null)
	stage.hud.hurt_feedback.hide()
	stage.hud.vitals.advance(0.05)
	await _frames(4)
	await _save(out, "02-wrath-hud.png")
	stage.queue_free()
	await _frames(3)


func _shot_boss_bar(out: String) -> void:
	var stage := preload("res://maps/realms/sloth_boss.tscn").instantiate() as RealmStage
	add_child(stage)
	await _frames(6)
	_equip_sample_build(stage.player)
	if is_instance_valid(stage.boss):
		stage.boss.health.apply_damage(stage.boss.health.max_health * 0.32, Hitbox.BodyPart.BODY, stage.player)
	await _frames(4)
	await _save(out, "03-boss-bar.png")
	stage.queue_free()
	await _frames(3)


func _shot_boon_picker(out: String) -> void:
	var stage := preload("res://maps/realms/sloth_1.tscn").instantiate() as RealmStage
	add_child(stage)
	await _frames(5)
	_equip_sample_build(stage.player)
	var picker := preload("res://ui/boon_picker/boon_picker.tscn").instantiate() as BoonPicker
	stage.selection = picker
	add_child(picker)
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var offer := BoonOffers.pick(stage.player.boons, rng, 3, PsycheFragments.SLOTH, [], false)
	picker.setup(offer, stage.player.boons, "怠惰 · 凝滞庭院 · 门扉馈赠", 2)
	await get_tree().create_timer(0.5, true).timeout
	await _frames(4)
	await _save(out, "04-boon-picker.png")
	picker.dismiss_for_transition()
	stage.queue_free()
	get_tree().paused = false
	await _frames(3)


func _shot_build_inspector(out: String) -> void:
	var stage := preload("res://maps/realms/sloth_1.tscn").instantiate() as RealmStage
	add_child(stage)
	await _frames(5)
	_equip_sample_build(stage.player)
	stage.player.fragments.acquire(PsycheFragments.SLOTH)
	stage.player.fragments.acquire(PsycheFragments.WRATH)
	stage.hud.inspector.try_open()
	await get_tree().create_timer(0.2, true).timeout
	await _frames(4)
	await _save(out, "05-build-inspector.png")
	stage.hud.inspector.close(true)
	stage.queue_free()
	get_tree().paused = false
	await _frames(3)


func _shot_crown_forge(out: String) -> void:
	var forge := preload("res://ui/meta_forge/crown_forge.tscn").instantiate() as CrownForge
	add_child(forge)
	forge.setup(MetaProgression)
	await _frames(5)
	await _save(out, "06-crown-forge.png")
	forge.close()
	get_tree().paused = false
	await _frames(3)


func _shot_pause_menu(out: String) -> void:
	var stage := preload("res://maps/realms/sloth_1.tscn").instantiate() as RealmStage
	add_child(stage)
	await _frames(5)
	PauseMenu.allow_headless = true
	stage.hud.pause_menu.try_open()
	await _frames(5)
	await _save(out, "07-pause-menu.png")
	stage.hud.pause_menu.close()
	PauseMenu.allow_headless = false
	stage.queue_free()
	get_tree().paused = false
	await _frames(3)


func _shot_opening_title(out: String) -> void:
	var opening := preload("res://ui/cinematics/opening_sequence.tscn").instantiate() as OpeningSequence
	add_child(opening)
	await _frames(6)
	await _save(out, "08-opening-title.png")
	opening.queue_free()
	await _frames(3)


func _equip_sample_build(player: Player) -> void:
	var catalog := BoonCatalog.all()
	var filled := {}
	for card in catalog:
		if card.core and not filled.has(card.slot) and card.slot < 3:
			if (card.slot == 0 and card.sin == PsycheFragments.WRATH) \
					or (card.slot == 1 and card.sin == PsycheFragments.SLOTH) \
					or (card.slot == 2 and card.sin == PsycheFragments.FEAR):
				player.boons.equip(card)
				filled[card.slot] = true
	for card in catalog:
		if not card.core and card.sin == PsycheFragments.SLOTH and player.boons.can_equip(card):
			player.boons.equip(card)
			break


func _save(out: String, filename: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var full := out.path_join(filename)
	img.save_png(full)
	print("SAVED ", full)


func _frames(count: int) -> void:
	for _i in count:
		await get_tree().process_frame
