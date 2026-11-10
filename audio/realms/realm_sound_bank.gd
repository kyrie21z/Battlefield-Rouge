class_name RealmSoundBank
extends RefCounted
## Original mathematical synthesis, cached PCM. No external samples or global RNG.
const RATE := 22050
const KINDS := [&"warm_pad",&"pendulum",&"heartbeat",&"gears",&"second_tick",&"delayed_burst"]
static var _cache: Dictionary = {}

static func get_sound(kind: StringName, loop := false) -> AudioStreamWAV:
	assert(KINDS.has(kind), "Unknown realm audio cue")
	var key := String(kind) + ("_loop" if loop else "")
	if _cache.has(key): return _cache[key]
	var duration := 4.0 if loop else 0.8
	var data := PackedByteArray()
	var count := int(RATE * duration)
	data.resize(count * 4)
	var rng := RandomNumberGenerator.new()
	rng.seed = 17600 + String(kind).hash()
	var low := 0.0
	for i in count:
		var t := float(i) / RATE
		var noise := rng.randf_range(-1.0, 1.0)
		low = lerpf(low, noise, 0.025)
		var value := sample(kind, t, noise, low)
		var envelope := 1.0 if loop else minf(t / 0.008, 1.0) * exp(-t * 5.0)
		# Seam window avoids a discontinuity when ambient loops wrap.
		if loop: envelope *= minf(t / 0.03, 1.0) * minf((duration-t)/0.03, 1.0)
		for channel in 2:
			data.encode_s16(i*4+channel*2, int(clampf(tanh(value)*envelope*0.5,-0.95,0.95)*32767))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.stereo = true
	stream.data = data
	if loop:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_end = count
	_cache[key] = stream
	return stream

static func sample(kind: StringName, t: float, noise: float, low: float) -> float:
	match kind:
		&"warm_pad": return sin(TAU*55*t)*0.25 + sin(TAU*82.5*t)*0.12 + low*0.5
		&"pendulum": return sin(TAU*440*t)*exp(-t*25)*0.7 + low*exp(-t*12)
		&"heartbeat": return sin(TAU*52*t)*exp(-fmod(t,0.16)*26)*0.7
		&"gears": return sin(TAU*130*t)*0.08 + noise*0.06 + sin(TAU*780*t)*0.06
		&"second_tick": return noise*exp(-t*65) + sin(TAU*2300*t)*exp(-t*55)*0.5
		&"delayed_burst": return sin(TAU*(65*t+25*(1-exp(-t*12))))*exp(-t*6)+low*4
	return low
