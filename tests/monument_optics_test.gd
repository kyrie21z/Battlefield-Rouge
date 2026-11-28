extends Node

var _fails := 0

func _ready() -> void:
	await _verify_stage("res://maps/realms/sloth_1.tscn", "sloth")
	await _verify_stage("res://maps/realms/fear_1.tscn", "fear")
	await _verify_stage("res://maps/realms/wrath_1.tscn", "wrath")
	await _verify_stage("res://maps/realms/sorrow_1.tscn", "sorrow")
	await _verify_stage("res://maps/realms/sloth_rest.tscn", "rest")
	await _verify_hub()

	if _fails == 0:
		print("ALL PASSED (monument_optics_test)")
		get_tree().quit(0)
	else:
		print("FAIL (%d failed in monument_optics_test)" % _fails)
		get_tree().quit(1)

func _check(label: String, ok: bool) -> void:
	if ok:
		print("  ok: " + label)
	else:
		_fails += 1
		printerr("  FAIL: " + label)

func _verify_stage(scene_path: String, tag: String) -> void:
	var packed := load(scene_path) as PackedScene
	var stage := packed.instantiate() as RealmStage
	add_child(stage)
	await get_tree().process_frame
	await get_tree().process_frame

	var envs := stage.find_children("*", "WorldEnvironment", true, false)
	_check(tag + " has WorldEnvironment", envs.size() >= 1)
	if envs.size() > 0:
		var env: Environment = (envs[0] as WorldEnvironment).environment
		_check(tag + " uses AgX tonemap", env.tonemap_mode == Environment.TONE_MAPPER_AGX)
		_check(tag + " uses Sky IBL", env.ambient_light_source == Environment.AMBIENT_SOURCE_SKY and env.sky != null)
		_check(tag + " enables fog and volumetric fog", env.fog_enabled and env.volumetric_fog_enabled)
		if tag == "sorrow":
			_check("sorrow keeps SSR with 128 steps", env.ssr_enabled and env.ssr_max_steps == 128)
	if tag == "wrath":
		_check("wrath keeps exactly 1 WorldEnvironment", envs.size() == 1)

	var probes := stage.find_children("*", "ReflectionProbe", true, false)
	_check(tag + " has MonumentReflectionProbe", probes.size() >= 1)
	_check(tag + " applies mind_monument_stone shader", _has_monument_shader(stage))

	stage.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame

func _verify_hub() -> void:
	var packed := load("res://levels/stasis_hub/stasis_hub.tscn") as PackedScene
	var hub := packed.instantiate() as Node3D
	add_child(hub)
	await get_tree().process_frame
	await get_tree().process_frame

	var envs := hub.find_children("*", "WorldEnvironment", true, false)
	_check("stasis_hub has WorldEnvironment", envs.size() == 1)
	if envs.size() > 0:
		var env: Environment = (envs[0] as WorldEnvironment).environment
		_check("stasis_hub uses AgX + Sky IBL", env.tonemap_mode == Environment.TONE_MAPPER_AGX and env.ambient_light_source == Environment.AMBIENT_SOURCE_SKY)
	var probes := hub.find_children("*", "ReflectionProbe", true, false)
	_check("stasis_hub has ReflectionProbe", probes.size() >= 1)
	_check("stasis_hub applies mind_monument_stone shader", _has_monument_shader(hub))

	hub.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame

func _has_monument_shader(root: Node) -> bool:
	for n in root.find_children("*", "GeometryInstance3D", true, false):
		var gi := n as GeometryInstance3D
		if gi.material_override is ShaderMaterial:
			var sm := gi.material_override as ShaderMaterial
			if sm.shader and sm.shader.resource_path.ends_with("mind_monument_stone.gdshader"):
				return true
	return false
