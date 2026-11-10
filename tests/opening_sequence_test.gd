extends Node3D
var checks := 0
var failures := 0
var entries := 0
func check(label: String, passed: bool) -> void:
	checks += 1
	if not passed: failures += 1
	print("%s %s" % ["PASS" if passed else "FAIL", label])
func _ready() -> void:
	var sequence := preload("res://ui/cinematics/opening_sequence.tscn").instantiate() as OpeningSequence
	add_child(sequence)
	sequence.set_process(false)
	sequence.combat_entry_requested.connect(func(): entries += 1)
	var camera_id := sequence.camera.get_instance_id()
	var body := sequence.player.get_node("ShadowBody") as ProtagonistBody
	check("production Player retains authored 24-bone full crystal body", body._skeleton.get_bone_count() == 24 and sequence.camera == sequence.player.view_camera)
	check("all six speech clips contain recorded speech-length audio", sequence.clips.size() == 6 and sequence.clips.values().all(func(clip: AudioStream) -> bool: return clip.get_length() > 2.0))
	sequence.start()
	check("start enters reality blackout with real speech and no controls", sequence.phase == OpeningSequence.Phase.FALL and sequence.audio.playing and not sequence.player.is_physics_processing() and not sequence.player.weapon.visible)
	var elapsed := sequence.phase_time
	get_tree().paused = true
	sequence.advance(2.0)
	check("pause preserves the cinematic phase clock", sequence.phase_time == elapsed)
	get_tree().paused = false
	var phases: Array[int] = []
	var max_pitch_jump := 0.0
	var previous_pitch := sequence.player._pitch
	while sequence.phase != OpeningSequence.Phase.PLAYABLE:
		if not phases.has(sequence.phase): phases.append(sequence.phase)
		sequence.advance(0.05)
		max_pitch_jump = maxf(max_pitch_jump, absf(previous_pitch - sequence.player._pitch))
		previous_pitch = sequence.player._pitch
		if checks > 100: break
	check("all five cinematic phases advance in order", phases == [1,2,3,4,5])
	check("two blinks reveal a sharp view", sequence.blink_count == 2 and is_zero_approx(float(sequence.mask.get_shader_parameter("defocus"))))
	check("continuous body inspection never jumps the camera pitch", max_pitch_jump < deg_to_rad(5))
	check("no camera was replaced during the sequence", sequence.camera.get_instance_id() == camera_id and sequence.camera.current)
	check("interviewer and all five Crown lines actually enter the audio player", sequence.spoken == ["interview","wake","care","obstacle","better","invitation"])
	check("crowning releases the real player and fully assembles the real pistol", sequence.control_released and sequence.player.is_physics_processing() and sequence.player.weapon.visible and sequence.player.weapon._view.reassembly_progress == 1.0)
	check("both physical doors open without premature scene handoff", absf(sequence.doors[0].position.x) > 5 and entries == 0)
	Input.action_press("move_forward")
	for frame in 310:
		await get_tree().physics_frame
		sequence.advance(1.0 / 60)
	Input.action_release("move_forward")
	check("actual CharacterBody walks through the opened door and requests entry once", sequence.player.position.z < -13 and entries == 1)
	var worn_position := sequence.player._head.global_transform * CrownModel.WEAR_OFFSET
	check("the crowned model follows the player's actual head anchor", sequence.crown.get_parent() == sequence.player and sequence.crown.global_position.distance_to(worn_position) < 0.01)
	sequence.advance(99)
	sequence.skip()
	check("repeated completion cannot request duplicate scene entry", entries == 1)
	sequence.queue_free()
	await get_tree().process_frame
	var skipped := preload("res://ui/cinematics/opening_sequence.tscn").instantiate() as OpeningSequence
	add_child(skipped)
	skipped.set_process(false)
	skipped.reduced_motion = true
	skipped.start()
	skipped.advance(skipped.duration(OpeningSequence.Phase.FALL) + 0.1)
	skipped.advance(0.8)
	check("reduced motion disables actual screen blur", is_zero_approx(float(skipped.mask.get_shader_parameter("defocus"))))
	skipped.skip()
	check("skip reaches the same safe playable state and silences speech", skipped.control_released and not skipped.audio.playing and not skipped.stress_audio.playing)
	skipped.queue_free()
	await get_tree().process_frame
	OS.delay_msec(250)
	print("OPENING SEQUENCE: %s (%d checks, %d failures)" % ["ALL PASSED" if failures == 0 else "FAIL", checks, failures])
	get_tree().quit(0 if failures == 0 else 1)
