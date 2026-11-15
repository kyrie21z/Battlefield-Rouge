class_name SorrowAudioDirector
extends RealmAudioDirector
## Environment only. Cross-realm tears and damage belong to SorrowBoonAudio.
var _previous := Vector3.INF
var _travel := 0.0
var _step_left := 0.0
var _dashing := false
var _observed_tides := 0

func _ready() -> void:
	# Prepare motion cues during room load rather than the first footstep/dash.
	SorrowSoundBank.get_sound(&"water_step")
	SorrowSoundBank.get_sound(&"water_slide")
	if stage.geometry is SorrowRealm:
		stage.geometry.set_audio_managed(true)
		stage.geometry.tree_exiting.connect(stop_all)
	super._ready()

func get_sound(kind: StringName, loop := false) -> AudioStreamWAV:
	return SorrowSoundBank.get_sound(kind, loop) if SorrowSoundBank.KINDS.has(kind) else super.get_sound(kind, loop)

func set_deprived(value: bool) -> void:
	super.set_deprived(value)
	_travel = 0.0
	_previous = Vector3.INF
	if not is_instance_valid(ambient): return
	# A wet tail must not leak into the evaporated battlefield.
	ambient.stop()
	ambient_tail.stop()
	_fade_left = 0.0
	for voice in voices: voice.stop()
	if not value and not stopped: set_ambience(&"rain")

func _on_boon_event(event: StringName, _context: Dictionary) -> void:
	super._on_boon_event(event, _context)
	if event == &"dash_started": _dashing = true
	if event == &"dash_finished": _dashing = false

func _physics_process(delta: float) -> void:
	if stopped or deprived or not is_instance_valid(player) or player.health.is_dead(): return
	if not is_instance_valid(stage) or not is_instance_valid(stage.geometry):
		stop_all()
		return
	# Production rooms have no CapturePoint. The actual radial tide release is
	# this realm's water-bell beat; windup/cancellation never advances this count.
	if stage.boss is SorrowMonolith:
		var monolith := stage.boss as SorrowMonolith
		if monolith.tides_released > _observed_tides:
			_observed_tides = monolith.tides_released
			if not monolith.health.is_dead(): play_cue(&"water_bell",monolith.global_position)
	var point := player.global_position
	var distance := 0.0 if _previous == Vector3.INF else Vector2(point.x-_previous.x, point.z-_previous.z).length()
	_previous = point
	_step_left = maxf(0, _step_left-delta)
	var water := stage.geometry as SorrowRealm
	if water == null: return
	var local := water.to_local(point)
	var wet := not water.deprived and player.is_on_floor() and local.y <= water.water_level and local.y >= -0.2 and absf(local.x)<19.8 and absf(local.z)<23.8
	# Ignore teleports and dry/high-platform travel. Distance follows the body,
	# never input, so pushing against a wall or standing still cannot splash.
	if not wet or distance > 3.0:
		_travel = 0.0
		return
	_travel += distance
	if distance < 0.001 or _travel < 0.55 or _step_left > 0: return
	var sliding := _dashing
	play_cue(&"water_slide" if sliding else &"water_step", point, 1.0, SorrowSoundBank.MOTION_VOLUME_DB)
	_travel = 0.0
	_step_left = 0.14 if sliding else 0.3

func _exit_tree() -> void:
	super._exit_tree()
	if is_instance_valid(stage) and is_instance_valid(stage.geometry) and stage.geometry is SorrowRealm:
		stage.geometry.set_audio_managed(false)
