extends Node
## Full-body fracture levels, original resources, per-player state and input.
const PLAYER := preload("res://actors/player/player.tscn")
var _failures := 0

func _ready() -> void:
	var first := PLAYER.instantiate() as Player
	var second := PLAYER.instantiate() as Player
	add_child(first)
	add_child(second)
	for player in [first, second]:
		player.set_physics_process(false)
		player.weapon.set_process(false)
		player.melee.set_process(false)
	var body := first.get_node("ShadowBody")
	var other := second.get_node("ShadowBody")
	var fracture := body.fracture as BodyFracture
	await get_tree().process_frame
	_check("full body has eleven fracture regions", fracture.source_meshes.size() == 11)
	var shared_color = BodyFracture.CRYSTAL.get_shader_parameter("base_color")
	var shared_emission = BodyFracture.CRYSTAL.get_shader_parameter("emission_strength")
	_check("all 56 authored shards retained", fracture.fragments.size() == 56)
	var library := BodyFracture.SHARDS.instantiate()
	for fragment in fracture.fragments:
		var piece := fragment.node as MeshInstance3D
		var original := library.find_child(piece.name, true, false) as MeshInstance3D
		if fragment.is_hand:
			var side := "Left" if fragment.part == "forearm_L" else "Right"
			_check("%s keeps the authored grip on its own hand bone" % piece.name,
				fragment.original_mesh != original.mesh and body._skeleton.get_bone_name(fragment.bone) == side + "Hand")
		else:
			_check("%s shares original shard geometry" % piece.name, original != null and fragment.original_mesh == original.mesh)
	library.free()
	_check("materials are isolated per player", fracture.fracture_materials[0] != other.fracture.fracture_materials[0])
	for level in 5:
		body.set_fracture_level(level)
		_check("level %d reaches full body uniform" % level, fracture.fracture_materials.all(func(m: ShaderMaterial) -> bool: return m.get_shader_parameter("fracture_level") == level))
		var fragments_visible := 0
		for fragment in fracture.fragments:
			var piece := fragment.node as MeshInstance3D
			if piece.visible:
				fragments_visible += 1
				_check("source and fragments never overlap", not fracture.source_meshes[fragment.part].node.visible)
		_check("level %d only peels late" % level, fragments_visible > 0 if level >= 3 else fragments_visible == 0)
		_check("head remains shadow-only at level %d" % level, fracture.source_meshes.head.node.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY)
	_check("original shared crystal material is unchanged", BodyFracture.CRYSTAL.get_shader_parameter("base_color") == shared_color and BodyFracture.CRYSTAL.get_shader_parameter("emission_strength") == shared_emission)
	_check("other player state is unchanged", other.fracture_level == 0 and other.fracture.fracture_level == 0)
	body.set_fracture_level(0)
	for part in fracture.source_meshes:
		var entry: Dictionary = fracture.source_meshes[part]
		_check("%s restores original pristine material" % part, entry.node.material_override == entry.original_material and entry.node.material_overlay == entry.original_overlay and entry.node.mesh == entry.original_mesh)
	body.set_fracture_level(99)
	_check("level clamps to four", body.fracture_level == 4)
	body.set_fracture_level(-1)
	_check("level clamps to zero", body.fracture_level == 0)
	var key := InputEventKey.new()
	key.physical_keycode = KEY_3
	key.pressed = true
	body._unhandled_key_input(key)
	_check("number keys disabled in production", body.fracture_level == 0)
	body.enable_debug_keys = true
	body._unhandled_key_input(key)
	_check("bench opt-in permits number keys", body.fracture_level == 3)
	Events.sin_defeated.emit(2)
	_check("narrative event controls every body", body.fracture_level == 2 and other.fracture_level == 2 and fracture.fracture_level == 2)
	first.queue_free()
	second.queue_free()
	await get_tree().process_frame
	Events.sin_defeated.emit(4)
	_check("destroyed bodies disconnect from event", Events.sin_defeated.get_connections().is_empty())
	print("BODY AWARENESS: %s (%d failed)" % ["ALL PASSED" if _failures == 0 else "FAIL", _failures])
	get_tree().quit(0 if _failures == 0 else 1)

func _check(label: String, ok: bool) -> void:
	if not ok:
		_failures += 1
	print("  [%s] %s" % ["ok" if ok else "FAIL", label])
