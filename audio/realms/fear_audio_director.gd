class_name FearAudioDirector
extends RealmAudioDirector
## Only presentation: reads injected actors, never alters their attacks or campaign state.
var actor_voices: RealmActorAudioVoices
var _blinks: Dictionary = {}

func _ready() -> void:
	for kind in FearSoundBank.KINDS:
		FearSoundBank.get_sound(kind, kind in [&"fear_abyss", &"fear_lock"])
	super._ready()
	actor_voices = RealmActorAudioVoices.new()
	add_child(actor_voices)
	set_ambience(&"fear_abyss")

func get_sound(kind: StringName, loop := false) -> AudioStreamWAV:
	if FearSoundBank.KINDS.has(kind):
		return FearSoundBank.get_sound(kind, loop)
	return super.get_sound(kind, loop)

func set_deprived(value: bool) -> void:
	super.set_deprived(value)
	if value and is_instance_valid(actor_voices):
		actor_voices.stop_all()

func _process(delta: float) -> void:
	if stopped or get_tree().paused:
		return
	super._process(delta)
	actor_voices.begin_frame()
	var present: Array[int] = []
	for actor in stage.enemies:
		if is_instance_valid(actor) and actor is FearReaper:
			var reaper := actor as FearReaper
			if not deprived and reaper.warnings_enabled and not reaper.health.is_dead() and not reaper.boon_stunned and reaper.boon_time_scale > 0 and reaper.attack_elapsed >= 0:
				actor_voices.sync_actor(reaper,get_sound(&"fear_lock",true),0.65,-21.0)
			continue
		if not is_instance_valid(actor) or not actor is FearRealmEnemy:
			continue
		var fear := actor as FearRealmEnemy
		var id := fear.get_instance_id()
		present.append(id)
		var previous := int(_blinks.get(id, 0))
		if fear.blink_count > previous and not fear.health.is_dead():
			play_cue(&"fear_phase", fear.global_position, 1.0, -10.0)
		_blinks[id] = fear.blink_count
		if deprived or not fear.warnings_enabled or fear.health.is_dead() or fear.state in [Enemy.State.DEAD, Enemy.State.FLEE]:
			continue
		if fear.boon_stunned or fear.boon_time_scale <= 0.0 or not is_instance_valid(fear.target):
			continue
		if fear.variant == FearRealmEnemy.Variant.WATCHER and fear.attack_elapsed >= 0.0:
			var progress := clampf(fear.attack_elapsed / maxf(fear.windup(), 0.001), 0.0, 1.0)
			actor_voices.sync_actor(fear, get_sound(&"fear_lock", true), lerpf(0.7, 1.6, progress), lerpf(-23.0, -15.0, progress))
	actor_voices.end_frame()
	for id in _blinks.keys():
		if not present.has(id):
			_blinks.erase(id)

func stop_all() -> void:
	super.stop_all()
	if is_instance_valid(actor_voices):
		actor_voices.stop_all()
