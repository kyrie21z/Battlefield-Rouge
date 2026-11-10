class_name ClimaxSoundBank
extends RefCounted
## Original stereo shatter, molten-gold resonance and struck-string piano.
const RATE := 22050
static var _cache: Dictionary = {}

static func get_sound(kind: StringName, note := 293.6648) -> AudioStreamWAV:
	var key := "%s:%.4f" % [kind, note]
	if _cache.has(key): return _cache[key]
	var duration := 1.8 if kind == &"shatter" else 3.2
	var count := int(duration*RATE)
	var data := PackedByteArray()
	data.resize(count*4)
	var rng := RandomNumberGenerator.new()
	rng.seed = 180
	var lows := [0.0, 0.0]
	for i in count:
		var t := float(i)/RATE
		for channel in 2:
			var noise := rng.randf_range(-1, 1)
			lows[channel] += (noise-lows[channel])*0.045
			var value := 0.0
			match kind:
				&"shatter":
					value = sin(TAU*(75*t-12*t*t))*exp(-t*5)*0.42
					value += noise*exp(-t*12)*0.24 + lows[channel]*exp(-t*3)*0.5
					for shard in 9:
						var age := t - 0.012*shard - channel*0.006
						if age >= 0:
							value += sin(TAU*(1560+shard*739+channel*23)*age)*exp(-age*16)*0.036
				&"gold_flow":
					value = lows[channel]*0.25
					for ratio in [1.0, 1.5, 2.0, 3.0]:
						value += sin(TAU*146.8324*ratio*t + sin(t*6+channel)*0.1)*0.11/ratio
					value *= sin(PI*t/duration)
				_:
					# Hammer transient + slightly inharmonic, independently decaying strings.
					value = noise*exp(-t*180)*0.06
					for partial in range(1, 9):
						var frequency := note*partial*sqrt(1+0.00025*partial*partial)
						var detune := 1.0 + (0.0008 if channel==1 else -0.0008)
						value += sin(TAU*frequency*detune*t)*exp(-t*(1.15+partial*0.48))*0.42/pow(partial,1.6)
			var envelope := minf(t/0.003,1)*minf((duration-t)/0.12,1)
			data.encode_s16(i*4+channel*2, int(clampf(value*envelope,-0.92,0.92)*32767))
	var result := AudioStreamWAV.new()
	result.format = AudioStreamWAV.FORMAT_16_BITS
	result.mix_rate = RATE
	result.stereo = true
	result.data = data
	_cache[key] = result
	return result
