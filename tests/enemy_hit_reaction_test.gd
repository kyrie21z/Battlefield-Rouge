extends Node
## Headless coverage of the shared realm/boss hit reaction and the randomised
## crystal impact:
##   godot --headless --path . res://tests/enemy_hit_reaction_test.tscn
## Every actor is hit with a real nonlethal Health signal; the checks are the
## visible contract (flash, flinch, sparks, authored death) plus the safety
## invariants (body, hitboxes, materials, AI state and global randomness).

const REALM_SCENES := {
	"sloth realm guard": "res://actors/enemy/sloth/sloth_realm_enemy.tscn",
	"sloth mire": "res://actors/enemy/sloth/sloth_mire.tscn",
	"fear realm enemy": "res://actors/enemy/fear/fear_realm_enemy.tscn",
	"fear reaper": "res://actors/enemy/fear/fear_reaper.tscn",
	"fear wisp": "res://actors/enemy/fear/fear_wisp.tscn",
	"wrath realm enemy": "res://actors/enemy/wrath/wrath_realm_enemy.tscn",
	"sorrow realm enemy": "res://actors/enemy/sorrow/sorrow_realm_enemy.tscn",
}
const BOSS_SCENES := {
	"sloth colossus": "res://actors/boss/sloth_colossus/sloth_colossus.tscn",
	"fear oculus": "res://actors/boss/fear_oculus/fear_oculus.tscn",
	"wrath spire": "res://actors/boss/wrath_spire/wrath_spire.tscn",
	"sorrow monolith": "res://actors/boss/sorrow_monolith/sorrow_monolith.tscn",
	"flawless doppelganger": "res://actors/boss/flawless_doppelganger/flawless_doppelganger.tscn",
}

class Source extends Node3D:
	var team := 0

var _failures := 0
var _finished := false
var _root: Node3D
var _source: Source


func _ready() -> void:
	await _run()
	for child in get_children():
		child.queue_free()
	await get_tree().process_frame
	OS.delay_msec(100)
	await get_tree().process_frame
	var ok := _failures == 0 and _finished
	print("%s (%d failed%s)" % ["ALL PASSED" if ok else "FAIL", _failures,
		"" if _finished else ", run did not finish"])
	get_tree().quit(0 if ok else 1)


func _run() -> void:
	_root = Node3D.new()
	_root.name = "TestWorld"
	add_child(_root)
	_source = Source.new()
	_source.name = "Source"
	_root.add_child(_source)
	_source.global_position = Vector3(0, 0, 12)
	for label in REALM_SCENES:
		await _check_actor(label, REALM_SCENES[label], false)
	for label in BOSS_SCENES:
		await _check_actor(label, BOSS_SCENES[label], true)
	await _test_late_model()
	await _test_crystal_impact()
	_finished = true


func _check_actor(label: String, path: String, boss: bool) -> void:
	print("== " + label)
	var stage := Node3D.new()
	stage.name = label.replace(" ", "_")
	_root.add_child(stage)
	var actor := (load(path) as PackedScene).instantiate() as Enemy
	stage.add_child(actor)
	# Standalone wisps dismiss themselves without a summoner; freeze it and every
	# other actor before the first physics tick.
	actor.set_physics_process(false)
	actor.global_position = Vector3(0, 0.1, 0)
	await _frames(2)
	if actor.has_method("set_combat_active"):
		actor.call("set_combat_active", true)
	_freeze_visual(actor.get_node_or_null("Model") as Node3D)
	var reaction := actor.get_node_or_null("HitReaction") as HitReaction
	_check("%s: hit reaction is installed" % label, reaction != null)
	if reaction == null:
		stage.queue_free()
		await _frames(1)
		return
	var model := actor.get_node_or_null("Model") as Node3D
	_check("%s: death is left to the authored shatter" % label, not reaction.death_effects_enabled)
	if boss:
		_check("%s: boss flinch stays composed (%.2f < 0.5)" % [label, reaction.flinch_scale],
			reaction.flinch_scale < 0.5 and is_equal_approx(reaction.flinch_scale, Enemy.BOSS_FLINCH_SCALE))
	actor.health.max_health = 100000.0
	actor.health.health = 100000.0
	var meshes: Array[MeshInstance3D] = []
	var rest: Array[Transform3D] = []
	var own_materials: Array[Material] = []
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		meshes.append(mesh)
		rest.append(mesh.transform)
		own_materials.append(mesh.material_override)
	var boxes: Array[Hitbox] = []
	var boxes_before: Array[Transform3D] = []
	for node in actor.find_children("*", "Hitbox", true, false):
		boxes.append(node as Hitbox)
		boxes_before.append(node.global_transform)
	_check("%s: has a visible model (%d meshes)" % [label, meshes.size()], not meshes.is_empty())
	var body_before := actor.global_transform
	var state_before := actor.state
	seed(9001)
	var want := randi()
	seed(9001)
	reaction.play(_source)
	_check("%s: flash and flinch draw nothing from the global sequence" % label, randi() == want)
	_check("%s: every model mesh flashes (alpha %.2f)" % [label, HitReaction.FLASH_ALPHA],
		_all_flashing(meshes))
	_check("%s: the body stays put" % label, actor.global_transform.is_equal_approx(body_before))
	_check("%s: every hitbox stays put" % label, _boxes_at(boxes, boxes_before))
	_check("%s: the AI state is untouched" % label, actor.state == state_before)
	await _frames(2)
	_check("%s: meshes lean during the flinch" % label, _any_moved(meshes, rest))
	await _seconds(0.35)
	_check("%s: overlay clears when the flash ends" % label, _no_flash_left(meshes))
	_check("%s: mesh rest transforms are restored" % label, _all_restored(meshes, rest))
	_check("%s: original materials are untouched" % label, _materials_kept(meshes, own_materials))
	# A real headshot through Health must lean harder and throw the gold sparks.
	var bursts_before := _debris_count(stage)
	seed(777)
	var want_head := randi()
	seed(777)
	actor.health.apply_damage(5.0, Hitbox.BodyPart.HEAD, _source)
	_check("%s: a headshot plays the reaction and its spark burst" % label,
		reaction.is_playing() and _debris_count(stage) > bursts_before)
	_check("%s: the spark burst draws nothing from the global sequence" % label, randi() == want_head)
	await _seconds(0.55)
	# Death: the authored shatter runs, the legacy chunk burst never fires.
	actor.health.apply_damage(1.0e9, Hitbox.BodyPart.BODY, _source)
	# Wisps free themselves on death, so read the result before the next frame.
	var dead_now := actor.health.is_dead()
	var authored_death := reaction.death_burst == null and _debris_count(stage) == 0
	await _frames(1)
	_check("%s: death uses the authored show, not the legacy burst" % label,
		dead_now and authored_death)
	stage.queue_free()
	await _frames(2)


func _test_late_model() -> void:
	print("== a model that appears after the first hit")
	var stage := Node3D.new()
	_root.add_child(stage)
	var body := Node3D.new()
	body.name = "Body"
	stage.add_child(body)
	var health := Health.new()
	health.name = "Health"
	body.add_child(health)
	var model := Node3D.new()
	model.name = "Model"
	body.add_child(model)
	var reaction := HitReaction.new()
	reaction.name = "HitReaction"
	body.add_child(reaction)
	await _frames(1)
	reaction.play(_source)
	_check("an empty model does not fake a flash", not reaction.is_playing())
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	model.add_child(mesh)
	reaction.play(_source)
	_check("the next hit picks up the late mesh", reaction.is_playing() and mesh.material_overlay != null)
	await _seconds(0.3)
	_check("and the late mesh returns to its rest transform",
		mesh.material_overlay == null and mesh.transform.is_equal_approx(Transform3D.IDENTITY))
	stage.queue_free()
	await _frames(2)


func _test_crystal_impact() -> void:
	print("== crystal impact")
	var effects := Node3D.new()
	_root.add_child(effects)
	seed(31337)
	var want := randi()
	seed(31337)
	var first := CrystalImpact.spawn(effects, Vector3.ZERO, Vector3.UP) as CrystalImpact
	var second := CrystalImpact.spawn(effects, Vector3.ZERO, Vector3.UP) as CrystalImpact
	_check("impact shards draw nothing from the global sequence", randi() == want)
	_check("consecutive hits pick different private seeds",
		first != null and second != null and first.seed_used != second.seed_used)
	_check("consecutive hits throw different shard velocities",
		first != null and second != null and first.shard_velocities() != second.shard_velocities())
	_check("the authored shard count is intact", first != null and first.get_child_count() == CrystalImpact.SHARDS)
	var glints := _glints(effects)
	_check("the hit point lights a brief unshadowed glint (%d)" % glints.size(),
		not glints.is_empty() and glints.all(func(light: OmniLight3D) -> bool: return not light.shadow_enabled))
	var head := CrystalImpact.spawn(effects, Vector3.ZERO, Vector3.UP, true) as CrystalImpact
	_check("a headshot spray is larger and faster", head != null and first != null and head.scale_used > first.scale_used)
	if first != null:
		first._process(CrystalImpact.LIFETIME + 0.01)
	if second != null:
		second._process(CrystalImpact.LIFETIME + 0.01)
	if head != null:
		head._process(CrystalImpact.LIFETIME + 0.01)
	await _frames(1)
	_check("impacts free themselves at the end of their life",
		not is_instance_valid(first) and not is_instance_valid(second) and not is_instance_valid(head))
	await _seconds(CrystalImpact.GLINT_TIME + 0.1)
	_check("the glint frees itself", _glints(effects).is_empty())
	effects.queue_free()
	await _frames(2)


func _freeze_visual(model: Node3D) -> void:
	if model == null:
		return
	model.set_process(false)
	for node in model.find_children("*", "Node", true, false):
		node.set_process(false)
	for node in model.find_children("*", "AnimationPlayer", true, false):
		(node as AnimationPlayer).pause()


func _boxes_at(boxes: Array[Hitbox], before: Array[Transform3D]) -> bool:
	for i in boxes.size():
		if not boxes[i].global_transform.is_equal_approx(before[i]):
			return false
	return true


func _all_flashing(meshes: Array[MeshInstance3D]) -> bool:
	if meshes.is_empty():
		return false
	for mesh in meshes:
		if not is_instance_valid(mesh) or mesh.material_overlay == null:
			return false
	return true


func _no_flash_left(meshes: Array[MeshInstance3D]) -> bool:
	for mesh in meshes:
		if not is_instance_valid(mesh) or mesh.material_overlay != null:
			return false
	return true


func _any_moved(meshes: Array[MeshInstance3D], rest: Array[Transform3D]) -> bool:
	for i in meshes.size():
		if not is_instance_valid(meshes[i]):
			return false
		if not meshes[i].transform.is_equal_approx(rest[i]):
			return true
	return false


func _all_restored(meshes: Array[MeshInstance3D], rest: Array[Transform3D]) -> bool:
	for i in meshes.size():
		if not is_instance_valid(meshes[i]) or not meshes[i].transform.is_equal_approx(rest[i]):
			return false
	return true


func _materials_kept(meshes: Array[MeshInstance3D], own: Array[Material]) -> bool:
	for i in meshes.size():
		if not is_instance_valid(meshes[i]) or meshes[i].material_override != own[i]:
			return false
	return true


func _debris_count(stage: Node) -> int:
	var count := 0
	for child in stage.get_children():
		if child is DebrisBurst:
			count += 1
	return count


func _glints(effects: Node) -> Array[OmniLight3D]:
	var out: Array[OmniLight3D] = []
	for child in effects.get_children():
		if child is OmniLight3D:
			out.append(child as OmniLight3D)
	return out


func _check(label: String, passed: bool) -> void:
	if not passed:
		_failures += 1
	print("%s %s" % ["PASS" if passed else "FAIL", label])


func _frames(count: int) -> void:
	for index in count:
		await get_tree().process_frame


func _seconds(value: float) -> void:
	await get_tree().create_timer(value).timeout
