extends "res://tests/flawless_bench.gd"
var checks := 0
var failed := 0
var starts := 0
var endings := 0
var returned_crown: Node3D
func _ready() -> void:
	PauseMenu.allow_headless = true
	GameSettings.settings_path = "user://doppelganger_hud_test.cfg"
	await _run()
	for child in get_children():
		child.queue_free()
	await get_tree().process_frame
	PauseMenu.allow_headless = false
	GameSettings.settings_path = GameSettings.DEFAULT_PATH
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://doppelganger_hud_test.cfg"))
	OS.delay_msec(250)
	await get_tree().process_frame
	print("DOPPELGANGER SPAWN: %d checks, %d failed" % [checks,failed])
	get_tree().quit(0 if failed==0 else 1)
func _run() -> void:
	check("autoload profile is isolated before scene initialization",MetaProgression.isolated_profile)
	build_arena()
	player = preload("res://actors/player/player.tscn").instantiate()
	player.position = Vector3(0,0,12)
	add_child(player)
	player.fragments.configure_deprivation([0,1,2,3])
	for realm in 4:
		player.fragments.acquire(realm)
	encounter = DoppelgangerSpawn.new()
	encounter.setup(player)
	add_child(encounter)
	encounter.combat_started.connect(func(): starts+=1)
	encounter.defeated.connect(func(value:Node3D): endings+=1; returned_crown=value)
	check("cinematic locks actual player subtree and starts a physical crown drop",player.process_mode==Node.PROCESS_MODE_DISABLED and encounter.carrier is RigidBody3D and not encounter.boss.visual.visible)
	check("cinematic hides combat HUD but owns a high pause layer",not encounter.hud.combat_root.visible and encounter.hud.pause_layer.layer > 45)
	await pause_key()
	check("Esc opens the real settings menu during cinematic lock",get_tree().paused and encounter.hud.pause_menu.is_open() and Input.mouse_mode==Input.MOUSE_MODE_VISIBLE)
	var drop_time := encounter.phase_elapsed
	await frames(4)
	check("cinematic and physical drop stop while paused",encounter.phase_elapsed==drop_time)
	await pause_key()
	check("Esc resumes cinematic without releasing its player lock",not get_tree().paused and not encounter.hud.pause_menu.is_open() and player.process_mode==Node.PROCESS_MODE_DISABLED)
	check("original spoken Chinese line is real nonempty audio",encounter.voice.stream.get_length()>2)
	var initial := encounter.carrier.position.y
	await frames(25)
	check("crown physically falls under gravity",encounter.carrier.position.y<initial-0.3)
	await until_phase(DoppelgangerSpawn.Phase.RANT)
	check("WORLD floor contact starts actual angry voice",encounter.phase==DoppelgangerSpawn.Phase.RANT and encounter.voice.playing and encounter.carrier.freeze)
	await until_phase(DoppelgangerSpawn.Phase.PRINT)
	check("printing lasts precisely 2.5 simulation seconds",is_equal_approx(DoppelgangerSpawn.PRINT_DURATION,2.5))
	check("crown projects real geometry and deterministic laser sound",encounter.print_projection.visible and encounter.print_projection.laser.playing and is_equal_approx(encounter.print_projection.laser.stream.get_length(),2.5))
	await frames(65)
	check("body prints progressively from top down",encounter.boss.visual.print_progress>0.3 and encounter.boss.visual.print_progress<0.6 and encounter.print_ring.visible)
	check("printing body cannot be shot or attack prematurely",not encounter.boss.combat_active and (encounter.boss.get_node("TorsoHitbox") as Hitbox).collision_layer==0)
	var print_visual := encounter.boss.visual
	check("original skinned model and weapons use hologram material during print",print_visual.skeleton.get_bone_count()==24 and print_visual._print_meshes.size()>11 and print_visual._print_meshes.all(func(mesh):return mesh.material_override==print_visual.print_material))
	check("laser ring and body share the same world scan plane",is_equal_approx(encounter.print_ring.position.y,lerpf(2.5,-0.2,print_visual.print_progress)))
	check("sparks follow the active scan plane",encounter.print_projection.sparks.emitting and is_equal_approx(encounter.print_projection.sparks.position.y,encounter.print_ring.position.y))
	check("print glare radiates from the actual projected crown",encounter.glare_layer.visible and encounter.crown_glare.get_shader_parameter("source_uv").is_equal_approx(get_viewport().get_camera_3d().unproject_position(encounter.crown.global_position)/get_viewport().get_visible_rect().size))
	var glare_time:float=encounter.crown_glare.get_shader_parameter("visual_time")
	var print_time: float = print_visual.print_material.get_shader_parameter("visual_time")
	var projection_time := encounter.print_projection.elapsed
	var progress := encounter.boss.visual.print_progress
	get_tree().paused = true
	for i in 4:
		await get_tree().process_frame
	check("pause freezes printed fraction and choreography",is_equal_approx(encounter.boss.visual.print_progress,progress))
	check("pause freezes boss glare clock",is_equal_approx(encounter.crown_glare.get_shader_parameter("visual_time"),glare_time))
	check("pause freezes both shader clocks and the projection",is_equal_approx(print_visual.print_material.get_shader_parameter("visual_time"),print_time) and is_equal_approx(encounter.print_projection.elapsed,projection_time))
	get_tree().paused = false
	(player.get_node("CrownVoiceSystem") as CrownVoiceSystem).reduced_motion = true
	await frames(2)
	check("reduced motion freezes grid pulses and removes falling sparks",print_visual.print_material.get_shader_parameter("reduced_motion") and not encounter.print_projection.sparks.emitting and is_zero_approx(encounter.flash.color.a))
	await until_phase(DoppelgangerSpawn.Phase.COMBAT)
	check("printing resources retire and original opaque battle material returns",not encounter.print_projection.visible and not encounter.print_projection.laser.playing and print_visual._print_meshes.all(func(mesh):return mesh.material_override==print_visual._crystal))
	check("crown seals onto actual animated head anchor",encounter.crown.get_parent()==encounter.boss.visual.crown_anchor and encounter.crown.get("worn"))
	check("seal removes reparent rotation and aligns the actual head axes",encounter.crown.quaternion.is_equal_approx(Quaternion.IDENTITY) and encounter.crown.global_basis.orthonormalized().is_equal_approx(encounter.boss.visual.crown_anchor.global_basis.orthonormalized()))
	var crown_box := crown_bounds()
	var head_box := encounter.boss.visual.head_bounds
	print("HEAD BOUNDS %s CROWN BOUNDS %s FIT %s" % [head_box,crown_box,encounter.crown.scale])
	check("worn crown matches actual head width and keeps its true height",crown_box.size.x>=head_box.size.x and crown_box.size.x<=head_box.size.x*1.45 and crown_box.size.z<=head_box.size.z*1.5 and is_equal_approx(encounter.crown.scale.y,1.0))
	var head_mesh := encounter.boss.visual.head_mesh
	check("white crystal head renders normally below the crown",head_mesh.visible and head_mesh.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_ON and crown_box.position.y > -0.06)
	check("combat begins once after complete print and controls restore",starts==1 and encounter.boss.combat_active and player.process_mode!=Node.PROCESS_MODE_DISABLED and encounter.boss.visual.print_progress==1)
	await frames(2)
	check("combat shows real crosshair vitals and eight-round ammunition",encounter.hud.combat_root.visible and encounter.hud.vitals.health_number==ceili(player.health.health) and encounter.hud.ammo.text.begins_with("8 / 8"))
	player.weapon.try_fire()
	await frames(2)
	check("actual shot immediately updates displayed ammunition",player.weapon.ammo==7 and encounter.hud.ammo.text.begins_with("7 / 8"))
	player.weapon.try_reload()
	await frames(2)
	check("actual pistol reassembly has visible reload feedback",player.weapon.is_reloading() and encounter.hud.ammo.text.contains("晶体重组"))
	await pause_key()
	var combat_time := encounter.phase_elapsed
	var reload_time := player.weapon.reload_progress()
	await frames(5)
	check("Esc pauses live boss combat and weapon reassembly",get_tree().paused and encounter.phase_elapsed==combat_time and player.weapon.reload_progress()==reload_time)
	encounter.hud.settings.crosshair_style = Crosshair.Style.RING
	encounter.hud.settings.mouse_sensitivity = 1.5
	encounter.hud.settings.changed.emit()
	check("pause settings bind actual crosshair and player look",encounter.hud.crosshair.style==Crosshair.Style.RING and is_equal_approx(player.mouse_sensitivity,0.0022*1.5))
	await pause_key()
	await frames(65)
	Input.action_press("aim")
	await frames(2)
	check("ADS tightens the reused production crosshair",encounter.hud.crosshair.focused and not encounter.hud.crosshair.show_lines)
	Input.action_release("aim")
	encounter.boss.phase = FlawlessDoppelganger.Phase.RECOVER
	encounter.boss.health.apply_damage(99999,Hitbox.BodyPart.BODY,player,{"true_damage":true})
	check("death enters actual white supernova and preserves crown",encounter.phase==DoppelgangerSpawn.Phase.ANNIHILATE and encounter.nova.visible and is_instance_valid(encounter.crown))
	await frames(18)
	check("supernova has rendered white flash and expanding sphere",encounter.flash.color.a>0.6 and encounter.nova.scale.x>2)
	await frames(120)
	check("ending retires the crown glare postprocess",not encounter.glare_layer.visible)
	check("death emits one ending event with surviving physical crown",endings==1 and is_instance_valid(returned_crown) and encounter.phase==DoppelgangerSpawn.Phase.COMPLETE)
	check("completion cleans boss and returns live player control",not is_instance_valid(encounter.boss) and player.process_mode!=Node.PROCESS_MODE_DISABLED)
	check("completion removes pause input and all battle overlays before ending",not encounter.hud.combat_root.visible and not is_instance_valid(encounter.hud.pause_menu) and not encounter.label.visible)
	encounter.queue_free()
	await frames(2)
	var aborted := DoppelgangerSpawn.new()
	aborted.setup(player)
	add_child(aborted)
	await pause_key()
	aborted.queue_free()
	await frames(2)
	check("early scene removal restores controls audio and owned pause",player.process_mode!=Node.PROCESS_MODE_DISABLED and not get_tree().paused)
func pause_key() -> void:
	var event := InputEventKey.new()
	event.physical_keycode = KEY_ESCAPE
	event.keycode = KEY_ESCAPE
	event.pressed = true
	Input.parse_input_event(event)
	await get_tree().process_frame
	var release := event.duplicate() as InputEventKey
	release.pressed = false
	Input.parse_input_event(release)
	await get_tree().process_frame
func crown_bounds() -> AABB:
	var inverse := encounter.boss.visual.crown_anchor.global_transform.affine_inverse()
	var bounds := AABB()
	var first := true
	for mesh:MeshInstance3D in encounter.crown.find_children("*","MeshInstance3D",true,false):
		var box := inverse*mesh.global_transform*mesh.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	return bounds
func until_phase(value:int) -> void:
	for i in 900:
		if encounter.phase==value:
			return
		await get_tree().physics_frame
	check("phase deadline %d" % value,false)
func frames(count:int) -> void:
	for i in count:
		await get_tree().physics_frame
func check(label:String,ok:bool) -> void:
	checks+=1
	failed+=0 if ok else 1
	print("%s %s" % ["PASS" if ok else "FAIL",label])
