extends Node
## Headless check of the hammer capture (Cut-001b AC-01 and AC-03). Run from
## the project root (it is a scene, not a --script, so the autoloads exist):
##   godot --headless --path . res://tests/capture_hammer_test.tscn
## Prints one line per check. Exits 1 if a check failed or if the run stopped
## before the last check (a script error inside it), so it cannot pass by accident.

const CONFIG_PATH := "res://zone/capture_config.tres"

var _failures := 0
var _finished := false
var _strikes: Array = []


func _ready() -> void:
	await _run()
	for voice in find_children("*", "AudioStreamPlayer", true, false):
		voice.stop()
		voice.stream = null
	for child in get_children():
		child.queue_free()
	get_tree().paused = false
	await get_tree().process_frame
	OS.delay_msec(100)
	await get_tree().process_frame
	var ok := _failures == 0 and _finished
	print("%s (%d failed%s)" % ["ALL PASSED" if ok else "FAIL", _failures, "" if _finished else ", run did not finish"])
	get_tree().quit(0 if ok else 1)


func _run() -> void:
	var scene: Node = load("res://maps/zone_1.tscn").instantiate()
	add_child(scene)
	await get_tree().process_frame
	_choose_entry(scene)
	var director := scene.get_node("ZoneDirector") as ZoneDirector
	_silence_reinforcements(director)
	var point := scene.get_node("CapturePoint") as CapturePoint
	var player := scene.get_node("Player") as Player
	point.struck.connect(func(perfect: bool, offset_ms: float, worth: float): _strikes.append([perfect, offset_ms, worth]))
	var captured_count := [0]
	point.captured.connect(func(): captured_count[0] += 1)

	print("== config (AC-03)")
	_check("config comes from %s" % CONFIG_PATH, point.config.resource_path == CONFIG_PATH)
	_check("window is 150 ms", is_equal_approx(point.config.perfect_window_ms, 150.0))
	_check("ordinary swing is 10%", is_equal_approx(point.config.normal_progress(), 0.10))
	_check("perfect multiplier is 2.0", is_equal_approx(point.config.perfect_multiplier, 2.0))
	_check("perfect swing is worth 20%", is_equal_approx(point.config.perfect_progress(), 0.20))

	print("== stage 1: clear the guards (AC-01)")
	_check("starts in CLEAR_GUARDS", director.phase == ZoneDirector.Phase.CLEAR_GUARDS)
	_check("building starts locked", point.locked)
	point.player_in_reach = true
	point.resolve_swing(2.0)
	_check("swinging at a locked building adds nothing", point.progress == 0.0 and _strikes.is_empty())
	point.player_in_reach = false
	var guards := get_tree().get_nodes_in_group("enemy")
	for i in guards.size():
		_check("building still locked with %d guards alive" % (guards.size() - i), point.locked)
		(guards[i] as Enemy).health.apply_damage(9999.0, Hitbox.BodyPart.BODY)
	_check("last guard down -> HAMMER_POINT", director.phase == ZoneDirector.Phase.HAMMER_POINT)
	_check("building is open", not point.locked)

	print("== stage 2: hammer the building (AC-01, AC-03)")
	point.resolve_swing(2.0)
	_check("a swing out of reach adds nothing", point.progress == 0.0 and _strikes.is_empty())
	player.global_position = point.global_position + Vector3(0.0, 0.0, 3.0)
	for i in 4:
		await get_tree().physics_frame
	_check("walking up to the building puts the player in reach", point.player_in_reach)

	point.resolve_swing(2.0)
	_expect_last("on the beat is perfect", true, 0.20)
	_check("progress is 20%", is_equal_approx(point.progress, 0.20))
	point.resolve_swing(3.14)
	_expect_last("+140 ms is perfect", true, 0.20)
	point.resolve_swing(3.86)
	_expect_last("-140 ms is perfect", true, 0.20)
	var before := point.progress
	point.resolve_swing(5.16)
	_expect_last("+160 ms is an ordinary swing", false, 0.10)
	point.resolve_swing(5.84)
	_expect_last("-160 ms is an ordinary swing", false, 0.10)
	point.resolve_swing(6.5)
	_expect_last("mid-way between beats is an ordinary swing", false, 0.10)
	_check("progress added matches the strikes", is_equal_approx(point.progress, before + 0.30))

	print("== feedback is separate (AC-03)")
	point.progress = 0.0
	point.resolve_swing(7.0)
	var perfect_stream := point._audio.stream as AudioStreamWAV
	var perfect_flash := point._material.emission
	point.resolve_swing(7.5)
	var normal_stream := point._audio.stream as AudioStreamWAV
	var normal_flash := point._material.emission
	_check("perfect and ordinary swings play different sounds", perfect_stream.data != normal_stream.data)
	_check("perfect and ordinary swings flash different colours", perfect_flash == CapturePoint.FLASH_PERFECT
		and normal_flash == CapturePoint.FLASH_HIT)
	_check("only a perfect strike fires the light burst", point._light.light_color == CapturePoint.FLASH_PERFECT)

	print("== numbers come from the config (AC-03)")
	var original := point.config
	var tuned := original.duplicate() as CaptureConfig
	tuned.perfect_window_ms = 50.0
	tuned.normal_progress_percent = 2.0
	tuned.perfect_multiplier = 3.0
	point.config = tuned
	point.resolve_swing(10.1)
	_expect_last("+100 ms is ordinary once the window is 50 ms", false, 0.02)
	point.resolve_swing(11.04)
	_expect_last("+40 ms is perfect with a 50 ms window (2% x 3.0)", true, 0.06)
	point.config = original

	print("== progress never drops")
	var held := point.progress
	player.global_position = point.global_position + Vector3(0.0, 0.0, 12.0)
	for i in 30:
		await get_tree().physics_frame
	_check("leaving the building does not lose progress", not point.player_in_reach and point.progress == held)

	print("== flag (AC-01)")
	player.global_position = point.global_position + Vector3(0.0, 0.0, 3.0)
	for i in 4:
		await get_tree().physics_frame
	var swings := 0
	while not point.is_captured() and swings < 40:
		point.resolve_swing(20.0 + swings)
		swings += 1
	_check("100% reached", point.is_captured() and point.progress == 1.0)
	_check("captured fired once", captured_count[0] == 1)
	_check("director is in FLAG_PLANTED", director.phase == ZoneDirector.Phase.FLAG_PLANTED)
	_check("a flag was planted on the building", point.get_node_or_null("Flag") != null)
	var strikes_at_capture := _strikes.size()
	point.resolve_swing(60.0)
	_check("swings after capture are ignored", _strikes.size() == strikes_at_capture and captured_count[0] == 1)

	print("== after the flag")
	_check("the reward does not open by itself", not director.get_children().any(func(c: Node): return c is CanvasLayer and c.has_signal("chosen")))
	_check("the run stays unpaused until interact", not get_tree().paused)
	var pedestal := director.buff_pedestal
	_check("a buff pedestal stands beside the flag", pedestal != null)
	_check("the objective points at the pedestal", "按 F" in director.objective)
	player.global_position = pedestal.global_position + Vector3(8.0, 0.0, 0.0)
	Input.action_press("interact")
	await get_tree().physics_frame
	Input.action_release("interact")
	_check("interact out of range does not open the reward", not director.get_children().any(func(c: Node): return c is CanvasLayer and c.has_signal("chosen")))
	player.global_position = pedestal.global_position
	Input.action_press("interact")
	await get_tree().physics_frame
	Input.action_release("interact")
	await get_tree().process_frame
	_check("interact at the pedestal opens the buff choice", director.get_children().any(func(c: Node): return c is CanvasLayer and c.has_signal("chosen")))
	get_tree().paused = false
	scene.queue_free()
	await get_tree().process_frame

	print("== real input path: E key -> Hammer -> CapturePoint")
	scene = load("res://maps/zone_2.tscn").instantiate()
	add_child(scene)
	await get_tree().process_frame
	_choose_entry(scene)
	_silence_reinforcements(scene.get_node("ZoneDirector") as ZoneDirector)
	point = scene.get_node("CapturePoint") as CapturePoint
	player = scene.get_node("Player") as Player
	_strikes.clear()
	point.struck.connect(func(perfect: bool, offset_ms: float, worth: float): _strikes.append([perfect, offset_ms, worth]))
	for guard in get_tree().get_nodes_in_group("enemy"):
		(guard as Enemy).health.apply_damage(9999.0, Hitbox.BodyPart.BODY)
	player.global_position = point.global_position + Vector3(0.0, 0.0, 3.0)
	for i in 4:
		await get_tree().physics_frame
	await _tap_hammer()
	_check("pressing E resolves one swing against the building", _strikes.size() == 1)
	await _tap_hammer()
	_check("a second press inside the swing cooldown is ignored", _strikes.size() == 1)
	await get_tree().create_timer(Hammer.SWING_COOLDOWN + 0.1).timeout
	await _tap_hammer()
	_check("after the cooldown the next press swings again", _strikes.size() == 2)
	scene.queue_free()
	await get_tree().process_frame

	print("== the building breaks apart as the bar fills")
	scene = load("res://maps/zone_1.tscn").instantiate()
	add_child(scene)
	await get_tree().process_frame
	_choose_entry(scene)
	_silence_reinforcements(scene.get_node("ZoneDirector") as ZoneDirector)
	point = scene.get_node("CapturePoint") as CapturePoint
	for guard in get_tree().get_nodes_in_group("enemy"):
		(guard as Enemy).health.apply_damage(9999.0, Hitbox.BodyPart.BODY)
	_check("eight blocks before the first quarter", point.fracture_stage == 0 and point.intact_block_count() == 8)
	point.add_capture_progress(0.25)
	_check("25% drops the first pair", point.fracture_stage == 1 and point.intact_block_count() == 6)
	point.struck.emit(false, 40.0, 0.10)
	_check("an ordinary hit throws chips", point.get_node_or_null("Chips") != null)
	point.add_capture_progress(0.25)
	_check("50% drops the next pair", point.fracture_stage == 2 and point.intact_block_count() == 4)
	point.add_capture_progress(0.25)
	_check("75% leaves one pair standing", point.fracture_stage == 3 and point.intact_block_count() == 2)
	point.add_capture_progress(0.25)
	_check("100% collapses the rest and plants the flag", point.fracture_stage == 4 and point.intact_block_count() == 0 and point.is_captured() and point.get_node_or_null("Flag") != null)
	for i in 70:
		await get_tree().physics_frame
	var flag := point.get_node("Flag") as Node3D
	_check("the flag stands on the ground, not where the roof was", absf(flag.position.y) < 0.05)
	_check("the collapsed building no longer blocks", (point.get_node("Objective/Shape") as CollisionShape3D).disabled)
	scene.queue_free()
	await get_tree().process_frame
	_finished = true


func _expect_last(label: String, perfect: bool, worth: float) -> void:
	var last: Array = _strikes.back() if not _strikes.is_empty() else []
	_check(label, not last.is_empty() and last[0] == perfect and is_equal_approx(last[2], worth))


## This scene is about the hammer, not the reinforcement pressure. A zero cap
## keeps the shared cadence resource intact and stops waves from shooting the
## scripted player during the waits below.
func _silence_reinforcements(director: ZoneDirector) -> void:
	if director.reinforcement_config == null:
		return
	var tuned := director.reinforcement_config.duplicate() as ReinforcementConfig
	tuned.max_alive = 0
	director.reinforcement_config = tuned


func _choose_entry(scene: Node) -> void:
	var director := scene.get_node("ZoneDirector") as ZoneDirector
	if is_instance_valid(director.selection):
		(director.selection.get_node("Center/Box/Choices/Choice1") as Button).pressed.emit()


func _check(label: String, ok: bool) -> void:
	if not ok:
		_failures += 1
	print("  [%s] %s" % ["ok" if ok else "FAIL", label])


## Presses and releases E. Waits for a frame boundary first: a timer resumes
## after the nodes' _process of its frame, and a press made then would be
## released before the hammer ever polls it.
func _tap_hammer() -> void:
	await get_tree().process_frame
	Input.action_press("hammer")
	await get_tree().process_frame
	Input.action_release("hammer")
