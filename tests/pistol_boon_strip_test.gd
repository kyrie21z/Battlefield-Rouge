extends Node

const PLAYER := preload("res://actors/player/player.tscn")
const GUN_IDS := ["sloth_gun_pulse", "fear_gaze_pierce", "wrath_gun_cannon", "sorrow_gun_needles"]

var _failures := 0
var _strips: Array[Array] = []
var _core: MeshInstance3D


func _ready() -> void:
	var player := PLAYER.instantiate() as Player
	add_child(player)
	player.set_physics_process(false)
	player.weapon.set_process(false)
	var view := player.weapon.find_child("ObsidianPistolView", false, false) as ObsidianPistolView
	view.set_process(false)
	_core = view.find_child("core_crystal", true, false) as MeshInstance3D
	for part_name in ["barrel_block", "slide_block"]:
		var piece := view.find_child(part_name, true, false) as MeshInstance3D
		for surface in piece.mesh.get_surface_count():
			if piece.mesh.surface_get_material(surface).resource_name == "Boon_Strip":
				_strips.append([piece, surface])
	_check("barrel and slide each have a strip surface",
		_strips.size() == 2 and _strips[0][0] != _strips[1][0])

	var cards := {}
	for card in BoonCatalog.all():
		cards[card.id] = card
	var boons := player.boons
	_check_off("new player")
	var sloth: BoonData = cards[GUN_IDS[0]]
	var wrath: BoonData = cards[GUN_IDS[2]]
	var blade: BoonData = cards["sloth_blade_cleave"]
	var dash: BoonData = cards["sloth_dash_ripple"]
	var trait_card: BoonData = cards["sloth_drowsy"]
	_check("blade equips without a gun core", boons.request_equip(blade))
	_check_off("blade only")
	_check("dash equips without a gun core", boons.request_equip(dash))
	_check_off("blade and dash")
	_check("trait equips without a gun core", boons.request_equip(trait_card))
	_check_off("blade, dash and trait")
	boons.clear()

	for id in GUN_IDS:
		var card: BoonData = cards[id]
		_check(id + " equips", boons.request_equip(card))
		_check_accent(card)
		_check(id + " starts at base energy", is_equal_approx(_strip_energy(), view.STRIP_BASE_ENERGY))
		_check(id + " removes", boons.remove(card.id))
		_check_off(id + " removed")

	_check("Sloth equips first", boons.request_equip(sloth))
	for card: BoonData in [blade, dash, trait_card]:
		_check(card.id + " equips alongside a gun", boons.request_equip(card))
		_check_accent(sloth)
	_check("Wrath requests confirmation", not boons.request_equip(wrath))
	_check_accent(sloth)
	_check("confirming replaces the gun core", boons.confirm_replace(true))
	_check_accent(wrath)

	boons.restore([cards[GUN_IDS[1]], dash])
	_check_accent(cards[GUN_IDS[1]])
	_check("a real shot kicks the equipped strip", player.weapon.try_fire())
	_check("shot immediately reaches peak energy", is_equal_approx(_strip_energy(), view.STRIP_PULSE_ENERGY))
	view._process(view.CORE_PULSE_TIME * 0.5)
	_check("strip decays toward its base", is_equal_approx(_strip_energy(),
		lerpf(view.STRIP_BASE_ENERGY, view.STRIP_PULSE_ENERGY, 0.5)))
	var shot_energy := _strip_energy()
	_check("replacement can be confirmed during the pulse",
		not boons.request_equip(sloth) and boons.confirm_replace(true))
	_check_accent(sloth)
	_check("replacement preserves the current pulse", is_equal_approx(_strip_energy(), shot_energy))
	view._process(view.CORE_PULSE_TIME)
	_check("strip decays to base", is_equal_approx(_strip_energy(), view.STRIP_BASE_ENERGY))

	seed(8520)
	var expected := randi()
	seed(8520)
	view.kick_fire()
	view.reset_fire_feedback()
	_check("firing presentation preserves global RNG", randi() == expected)
	_check("reset returns strip to base", is_equal_approx(_strip_energy(), view.STRIP_BASE_ENERGY))

	view.set_reassembly_progress(0.5)
	_check("reload bloom raises strip energy", _strip_energy() > view.STRIP_BASE_ENERGY)
	var bloom_energy := _strip_energy()
	boons.restore([wrath])
	_check_accent(wrath)
	_check("restoring during bloom keeps its current energy", is_equal_approx(_strip_energy(), bloom_energy))
	view.set_reassembly_progress(1.0)
	_check("closed reload returns strip to base", is_equal_approx(_strip_energy(), view.STRIP_BASE_ENERGY))

	boons.clear()
	_check_off("clear")
	boons.restore([sloth])
	_check_accent(sloth)
	# Let the real shot's voice finish before death tears it down.
	var shot_voice := player.weapon._shot_voices[0]
	if shot_voice.playing:
		await shot_voice.finished
	player.health.apply_damage(0.0, Hitbox.BodyPart.BODY, null, {"environmental_fatal": true})
	_check("death clears the gun slot", player.health.is_dead() and boons.slots[BoonData.Slot.GUN].data == null)
	_check_off("death")

	player.queue_free()
	await get_tree().process_frame
	print("%s (%d failed)" % ["ALL PASSED" if _failures == 0 else "FAILED", _failures])
	get_tree().quit(_failures)


func _check_off(label: String) -> void:
	var off := _strips.size() == 2
	for strip in _strips:
		off = off and strip[0].get_active_material(strip[1]) == ObsidianPistolView.OBSIDIAN_MATERIAL
	var material := _core.get_active_material(0) as StandardMaterial3D
	var amber := _core.mesh.surface_get_material(0) as StandardMaterial3D
	_check(label + " has black strips and amber core",
		off and material.albedo_color == amber.albedo_color and material.emission == amber.emission)


func _check_accent(card: BoonData) -> void:
	var expected := BoonPalette.COLORS[card.sin]
	var material := _get_strip_material()
	var strip_ok := _strips.size() == 2 and material != null
	for strip in _strips:
		strip_ok = strip_ok and strip[0].get_active_material(strip[1]) == material
	var core := _core.get_active_material(0) as StandardMaterial3D
	_check(card.id + " palette colors both strips and the core",
		strip_ok and material.emission_enabled and material.emission == expected
		and core.albedo_color == expected and core.emission == expected)


func _get_strip_material() -> StandardMaterial3D:
	if _strips.is_empty():
		return null
	return _strips[0][0].get_active_material(_strips[0][1]) as StandardMaterial3D


func _strip_energy() -> float:
	var material := _get_strip_material()
	return material.emission_energy_multiplier if material != null else 0.0


func _check(label: String, ok: bool) -> void:
	print("%s %s" % ["PASS" if ok else "FAIL", label])
	if not ok:
		_failures += 1
