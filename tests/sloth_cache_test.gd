extends Node
## Cached geometry must never share mutable pose, material or fracture state.
var failures := 0
var checks := 0


func _ready() -> void:
	var arena := Node3D.new()
	add_child(arena)
	for kind in 3:
		var pair: Array[SlothEnemy] = []
		for index in 2:
			var actor := load("res://actors/enemy/sloth/sloth_enemy.tscn").instantiate() as SlothEnemy
			actor.kind = kind
			arena.add_child(actor)
			actor.position.x = index * 3.0
			actor.set_physics_process(false)
			pair.append(actor)
		var first := pair[0].visual
		var second := pair[1].visual
		var meshes := first._outfit.find_children("*","MeshInstance3D",true,false)
		var shared_geometry := not meshes.is_empty()
		for mesh in meshes:
			var other := second._outfit.get_node(first._outfit.get_path_to(mesh)) as MeshInstance3D
			shared_geometry = shared_geometry and mesh.mesh == other.mesh and mesh != other
		_check("cached variant %d reuses meshes but owns nodes" % kind,shared_geometry)
		first.set_cast(0.0)
		second.set_cast(1.0)
		_check("variant %d charge materials are independent" % kind,
			first._cloth != second._cloth and first._cloth.get_shader_parameter("cast_amount")==0.0
			and second._cloth.get_shader_parameter("cast_amount")==1.0)
		_check("variant %d bone followers belong to the right actor" % kind,
			second._bones.all(func(link:Dictionary)->bool:return second._outfit.is_ancestor_of(link.node)))
		if kind == 2:
			first.set_shell_open(0.0)
			second.set_shell_open(1.0)
			_check("cached cocoon hinges move independently",first._shell.size()==6 and second._shell.size()==6
				and first._shell[0].node.rotation != second._shell[0].node.rotation)
		pair[0].health.apply_damage(9999,Hitbox.BodyPart.HEAD)
		_check("cached variant %d preserves all 56 posed shards" % kind,
			first.shatter.fragments.size()==56 and first.shatter.fragments.all(
				func(fragment:Dictionary)->bool:return is_instance_valid(fragment.node) and fragment.node.visible))
		_check("killing cached variant %d leaves its peer visible and alive" % kind,
			not pair[1].health.is_dead() and second.model.visible and not second._dead)
	arena.queue_free()
	await get_tree().process_frame
	print("SLOTH_CACHE_COMPLETE checks=",checks," failures=",failures)
	get_tree().quit(0 if failures==0 and checks==16 else 1)


func _check(label: String, ok: bool) -> void:
	checks += 1
	if not ok: failures += 1
	print("  [", "ok" if ok else "FAIL", "] ",label)
