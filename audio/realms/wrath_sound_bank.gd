class_name WrathSoundBank
extends RefCounted
## Original kiln, fracture and powered-blade synthesis. Local seeded RNG only.
const RATE := 22050
const KINDS := [&"wrath_kiln", &"wrath_metal", &"wrath_charge", &"wrath_rush", &"wrath_saw", &"wrath_wall_slam", &"wrath_spike"]
static var _cache: Dictionary = {}

static func boon_cues(event: StringName, context: Dictionary) -> Array[Dictionary]:
	if event == &"wall_slam" and context.has("position"):
		return [{"kind": &"wrath_wall_slam", "position": context.position, "volume": -5.0}]
	return []

static func get_sound(kind: StringName, loop := false) -> AudioStreamWAV:
	var key := String(kind) + ("_loop" if loop else "")
	if _cache.has(key):
		return _cache[key]
	assert(KINDS.has(kind), "Unknown Wrath audio cue")
	var duration := 4.0 if loop else (1.1 if kind == &"wrath_wall_slam" else 0.75)
	var count := int(RATE * duration)
	var data := PackedByteArray()
	data.resize(count * 4)
	var rng := RandomNumberGenerator.new()
	rng.seed = 17800 + String(kind).hash()
	var low := 0.0
	var previous := 0.0
	for i in count:
		var t := float(i) / RATE
		var noise := rng.randf_range(-1.0, 1.0)
		low = lerpf(low, noise, 0.035)
		var high := noise - previous
		previous = noise
		var envelope := minf(t / 0.004, 1.0) * minf((duration - t) / 0.025, 1.0)
		for channel in 2:
			var value := 0.0
			match kind:
				&"wrath_kiln":
					var jet := pow(0.5 + 0.5 * sin(TAU * 0.5 * t + channel * 0.25), 4)
					value = sin(TAU * 48 * t) * 0.12 + low * 0.7 + high * (0.025 + jet * 0.16)
				&"wrath_metal":
					value = (sin(TAU * (1260 * t + 150 * t * t)) * 0.3 + sin(TAU * 2197 * t) * 0.2 + high * 0.13) * exp(-t * 5)
				&"wrath_charge":
					value = (sin(TAU * 135 * t) * 0.28 + high * 0.15) * (0.6 + 0.4 * sin(TAU * 16 * t))
				&"wrath_rush":
					value = low * 2.0 + high * 0.12 + sin(TAU * 85 * t) * 0.2
				&"wrath_saw":
					# Harmonic teeth and blade chatter; speed is driven by the real attack state.
					value = (sin(TAU * 175 * t) * 0.25 + sin(TAU * 525 * t) * 0.18 + sin(TAU * 1225 * t) * 0.10 + high * 0.07) * (0.75 + 0.25 * sin(TAU * 35 * t))
				&"wrath_wall_slam":
					# Falling 95->42 Hz body impact followed by rock grit; no flat clipping.
					var phase := TAU * (42 * t + 53.0 / 16.0 * (1.0 - exp(-16 * t)))
					value = sin(phase) * 0.68 * exp(-t * 6) + low * 2.5 * exp(-t * 8) + high * 0.22 * exp(-t * 15)
				&"wrath_spike":
					value = (high * 0.19 + sin(TAU * (2100 * t - 700 * t * t)) * 0.13) * exp(-t * 10)
			data.encode_s16(i * 4 + channel * 2, int(tanh(value) * envelope * 30000))
	var stream := AudioStreamWAV.new()
	stream.mix_rate = RATE
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.stereo = true
	stream.data = data
	if loop:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_end = count
	_cache[key] = stream
	return stream
