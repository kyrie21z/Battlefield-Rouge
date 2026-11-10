class_name WrathAudioDirector
extends RealmAudioDirector
var actor_voices: RealmActorAudioVoices
var _detonations: Dictionary = {}
var _next_metal := 3.5
var _metal_index := 0

func _ready() -> void:
	if stage.geometry.has_method("set_audio_managed"):
		stage.geometry.call("set_audio_managed", true)
	super._ready()
	actor_voices = RealmActorAudioVoices.new()
	add_child(actor_voices)
	stage.enemy_defeated.connect(_on_enemy_defeated)
	if not deprived:
		set_ambience(&"wrath_kiln")

func get_sound(kind: StringName, loop := false) -> AudioStreamWAV:
	if WrathSoundBank.KINDS.has(kind):
		return WrathSoundBank.get_sound(kind, loop)
	return super.get_sound(kind, loop)

func set_deprived(value: bool) -> void:
	super.set_deprived(value)
	if value and is_instance_valid(ambient):
		ambient.stop()
		ambient_tail.stop()
		if is_instance_valid(actor_voices):
			actor_voices.stop_all()

func _process(delta: float) -> void:
	if stopped or get_tree().paused:
		return
	super._process(delta)
	if not deprived and elapsed >= _next_metal:
		var side := -1.0 if _metal_index % 2 == 0 else 1.0
		play_cue(&"wrath_metal", player.global_position + Vector3(side * 14, 5, -8), 0.9 + (_metal_index % 3) * 0.1, -22.0)
		_next_metal = elapsed + 7.0
		_metal_index += 1
	actor_voices.begin_frame()
	var present: Array[int] = []
	for actor in stage.enemies:
		if not is_instance_valid(actor) or not actor is WrathRealmEnemy:
			continue
		var wrath := actor as WrathRealmEnemy
		var id := wrath.get_instance_id()
		present.append(id)
		_consume_wall_detonation(wrath)
		if wrath.health.is_dead() or wrath.state in [Enemy.State.DEAD, Enemy.State.FLEE] or wrath.boon_stunned or wrath.boon_time_scale <= 0.0 or not is_instance_valid(wrath.target):
			continue
		var rushing := wrath.attack_phase == WrathRealmEnemy.Attack.RUSH and Vector2(wrath.velocity.x, wrath.velocity.z).length() > 8.0
		if wrath.variant == WrathRealmEnemy.Variant.PIERCER:
			if wrath.attack_phase == WrathRealmEnemy.Attack.WINDUP and wrath.warnings_enabled:
				var duration := maxf(0.75 * wrath.boon_windup_scale, 0.001)
				var progress := 1.0 - clampf(wrath.attack_left / duration, 0.0, 1.0)
				actor_voices.sync_actor(wrath, get_sound(&"wrath_charge", true), lerpf(0.8, 1.6, progress), -15.0)
			elif rushing:
				actor_voices.sync_actor(wrath, get_sound(&"wrath_rush", true), 1.0, -13.0)
		elif wrath.variant == WrathRealmEnemy.Variant.AGGRESSOR:
			# No warning when deprived; powered saw is audible during actual motion/contact.
			if rushing or (wrath.attack_phase == WrathRealmEnemy.Attack.APPROACH and wrath.velocity.length() > 0.5):
				actor_voices.sync_actor(wrath, get_sound(&"wrath_saw", true), 1.4 if rushing else 0.85, -16.0)
			elif wrath.attack_phase == WrathRealmEnemy.Attack.WINDUP and wrath.warnings_enabled:
				actor_voices.sync_actor(wrath, get_sound(&"wrath_saw", true), 1.1, -21.0)
	actor_voices.end_frame()
	for id in _detonations.keys():
		if not present.has(id):
			_detonations.erase(id)

func _on_enemy_defeated(_room: RealmStage, actor: Enemy) -> void:
	if actor is WrathRealmEnemy:
		# Stage emits synchronously, before its deferred reward picker pauses us.
		_consume_wall_detonation(actor as WrathRealmEnemy)

func _consume_wall_detonation(actor: WrathRealmEnemy) -> void:
	var id := actor.get_instance_id()
	var previous := int(_detonations.get(id, 0))
	_detonations[id] = actor.wall_detonations
	if actor.wall_detonations > previous:
		# Share acknowledgement with polling; pause/stop rejection never replays later.
		play_cue(&"wrath_wall_slam", actor.global_position + Vector3.UP, 1.0, -7.0)

func stop_all() -> void:
	super.stop_all()
	if is_instance_valid(actor_voices):
		actor_voices.stop_all()
