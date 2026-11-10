extends Node3D
var checks := 0
var failures := 0
func check(label: String, passed: bool) -> void:
	checks += 1
	if not passed: failures += 1
	print("%s %s" % ["PASS" if passed else "FAIL", label])
func _ready() -> void:
	seed(168)
	var expected_unprepared := randf()
	seed(168)
	check("unprepared parent silently skips cosmetic burst",CrystalBurst.spawn(self,Vector3.ZERO,0)==null)
	check("unprepared parent preserves gameplay RNG",randf()==expected_unprepared)
	CrystalBurst.prepare(self)
	for i in 5: await get_tree().process_frame
	var player := preload("res://actors/player/player.tscn").instantiate() as Player
	add_child(player)
	player.set_physics_process(false)
	var paths := ["sloth", "fear", "wrath", "sorrow"]
	for index in paths.size():
		var scene := load("res://actors/enemy/%s/%s_realm_enemy.tscn" % [paths[index],paths[index]]) as PackedScene
		var enemy := scene.instantiate() as Enemy
		enemy.position = Vector3(index*4,0,-6)
		add_child(enemy)
		enemy.set_physics_process(false)
		var box := enemy.find_children("*","Hitbox",true,false)[0] as Hitbox
		check("realm %d owns correct identity"%index,enemy.sin_type==index)
		var point := enemy.global_position+Vector3(0.1,1.2,0.3)
		box.apply_hit_at(4.0,player,point,Vector3.FORWARD)
		check("resolved hit uses exact contact %d"%index,enemy.crystal_bursts==1 and enemy.health.last_damage_context.position==point)
		var before := enemy.crystal_bursts
		box.apply_hit(10.0,enemy)
		check("friendly fire creates no debris %d"%index,enemy.crystal_bursts==before)
		enemy.health.apply_damage(100000,Hitbox.BodyPart.BODY,player)
		check("one fatal burst at actual death %d"%index,enemy.crystal_bursts==before+1)
		box.apply_hit(100,player)
		check("dead enemy cannot retrigger debris %d"%index,enemy.crystal_bursts==before+1)
	var feedback := player.get_node("CrystalFeedback") as CrystalCombatFeedback
	for event in [&"sloth_burst",&"fear_flaw_broken",&"wall_slam",&"sorrow_tear_broken"]:
		player.boons.event_dispatched.emit(event,{"position":Vector3(0,1,0)})
	check("all four actual action event names create special feedback",feedback.bursts==4)
	var debris := get_children().filter(func(node):return node is CrystalBurst)
	check("debris uses flat 24-vertex mesh and GPU emitter",debris[0].particles is GPUParticles3D and debris[0].particles.draw_pass_1.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size()==24)
	seed(1234)
	var expected := randf()
	seed(1234)
	CrystalBurst.spawn(self,Vector3.ZERO,0)
	check("cosmetic debris preserves gameplay RNG",randf()==expected)
	for i in 100:
		CrystalBurst.spawn(self,Vector3.ZERO,i%4)
	check("burst storm stays bounded",CrystalBurst.active==CrystalBurst.MAX_ACTIVE)
	var effect := debris[0] as CrystalBurst
	get_tree().paused = true
	var before_time := effect.elapsed
	for i in 3: await get_tree().process_frame
	check("pause freezes cosmetic lifetime",effect.elapsed==before_time)
	get_tree().paused = false
	for node in get_children():
		if node is CrystalBurst: node._process(node.duration+0.2)
	await get_tree().process_frame
	check("expired bursts return all emitter leases",get_meta("crystal_emitter_pool").get_child_count()==48)
	seed(998)
	var expected_reuse := randf()
	seed(998)
	var reused := CrystalBurst.spawn(self,Vector3.ZERO,1)
	check("recycled emitter can fire without gameplay random draws",reused!=null and randf()==expected_reuse)
	for node in get_children(): node.queue_free()
	await get_tree().process_frame
	check("scene teardown releases emitter budget",CrystalBurst.active==0)
	print("CRYSTAL FEEDBACK: %d checks, %d failures" % [checks,failures])
	get_tree().quit(1 if failures else 0)
