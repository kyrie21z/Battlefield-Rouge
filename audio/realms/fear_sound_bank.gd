class_name FearSoundBank
extends RefCounted
## Original, deterministic stereo PCM; no samples or gameplay RNG consumption.
const RATE := 22050
const KINDS := [&"fear_abyss", &"fear_lock", &"fear_phase", &"fear_flaw_shatter"]
static var _cache: Dictionary = {}

static func boon_cues(event: StringName, context: Dictionary) -> Array[Dictionary]:
	if event == &"fear_flaw_broken" and context.has("position"):
		return [{"kind": &"fear_flaw_shatter", "position": context.position, "volume": -8.0}]
	return []

static func get_sound(kind: StringName, loop := false) -> AudioStreamWAV:
	var key := String(kind) + ("_loop" if loop else "")
	if _cache.has(key):
		return _cache[key]
	assert(KINDS.has(kind), "Unknown Fear audio cue")
	var duration := 4.0 if loop else (0.46 if kind == &"fear_phase" else 0.32)
	var count := int(RATE * duration)
	var data := PackedByteArray()
	data.resize(count * 4)
	var rng := RandomNumberGenerator.new()
	rng.seed = 17700 + String(kind).hash()
	var low := 0.0
	for i in count:
		var t := float(i) / RATE
		var noise := rng.randf_range(-1.0, 1.0)
		low = lerpf(low, noise, 0.012)
		var envelope := minf(t / 0.006, 1.0) * minf((duration - t) / 0.02, 1.0)
		for channel in 2:
			var value := 0.0
			match kind:
				&"fear_abyss":
					# 25/33/46 Hz, with a quiet audible 92 Hz overtone on small speakers.
					value = sin(TAU * 25 * t) * 0.30 + sin(TAU * 33 * t) * 0.20 + sin(TAU * 46 * t) * 0.12
					value += sin(TAU * 92 * t) * 0.035 + low * 0.4
					value *= 0.8 + 0.2 * sin(TAU * 0.5 * t + channel * 0.4)
				&"fear_lock":
					value = (sin(TAU * 1650 * t) * 0.32 + sin(TAU * 3300 * t) * 0.05) * (0.7 + 0.3 * cos(TAU * 8 * t))
				&"fear_phase":
					# Different chirp phase and swept comb per channel: real stereo, not two mono copies.
					var phase := channel * (0.7 + sin(TAU * 9 * t) * 1.4)
					value = (sin(TAU * (760 * t - 580 * t * t) + phase) * 0.5 + noise * sin(TAU * 31 * t + phase) * 0.2) * exp(-t * 7)
				&"fear_flaw_shatter":
					value = (sin(TAU * 1940 * t) * 0.42 + sin(TAU * 3163 * t) * 0.32 + sin(TAU * 4871 * t) * 0.20) * exp(-t * 27)
					value += (noise - low) * 0.5 * exp(-t * 45)
			data.encode_s16(i * 4 + channel * 2, int(clampf(value * envelope, -0.95, 0.95) * 32767))
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
