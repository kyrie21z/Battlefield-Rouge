class_name SorrowSoundBank
extends RefCounted
## Original deterministic PCM. Local noise generator never advances gameplay RNG.
const KINDS := [&"rain", &"water_bell", &"tear_return", &"tear_spray", &"glass", &"water_step", &"water_slide"]
const RATE := 22050
const RAIN_SECONDS := 4.0
const RAIN_OVERLAP := 0.25
static var _cache: Dictionary = {}

static func get_sound(kind: StringName, loop := false) -> AudioStreamWAV:
	var key := String(kind) + ("_loop" if loop else "")
	if _cache.has(key): return _cache[key]
	if kind == &"rain":
		_cache[key] = _rain_bed(loop)
		return _cache[key]
	var duration := 0.6
	match kind:
		&"water_bell": duration = 2.4
		&"tear_return": duration = 1.1
		&"tear_spray": duration = 0.65
		&"water_slide": duration = 0.65
		&"glass": duration = 0.42
	var rng := RandomNumberGenerator.new()
	rng.seed = 179
	var data := PackedByteArray()
	var count := int(RATE * duration)
	data.resize(count * 2)
	var low := 0.0
	for i in count:
		var t := float(i) / RATE
		var noise := rng.randf_range(-1.0, 1.0)
		low += (noise - low) * 0.16
		var value := 0.0
		match kind:
			&"water_bell":
				for harmonic in [1.0, 2.76, 4.07, 5.43]:
					value += sin(TAU * 196.0 * harmonic * t + 0.015 * sin(t * 19.0)) * exp(-t * (1.8 + harmonic)) * 0.3 / sqrt(harmonic)
			&"tear_return":
				value = low * sin(PI * t / duration) * 0.3
				for frequency in [392.0, 587.33, 783.99]:
					value += sin(TAU * (frequency * t - 40.0 * t * t)) * sin(PI * t / duration) * exp(-t * 2.0) * 0.18
			&"tear_spray":
				# Three water jets follow the actual three-projectile tear volley.
				for onset in [0.0, 0.035, 0.07]:
					var age: float = t - float(onset)
					if age >= 0:
						value += (noise - low) * exp(-age * 16.0) * 0.24 + sin(TAU * (950.0 * age - 580.0 * age * age)) * exp(-age * 23.0) * 0.12
			&"glass":
				for frequency in [2700.0, 4250.0, 6150.0, 8310.0]:
					value += sin(TAU * frequency * t) * exp(-t * 18.0) * 0.15
				for onset in [0.0, 0.037, 0.083, 0.146]:
					if t >= onset: value += (noise - low) * exp(-(t-onset)*75.0) * 0.19
			_:
				var slide := kind == &"water_slide"
				value = low * exp(-t * (7.0 if slide else 15.0)) * 0.85
				value += sin(TAU * (260.0*t-160.0*t*t)) * exp(-t*24.0) * 0.22
		var attack := minf(t / 0.003, 1.0)
		var release := minf((duration-t) / 0.025, 1.0)
		if loop: attack = 1.0; release = 1.0
		data.encode_s16(i*2, int(clampf(value*attack*release, -0.9, 0.9)*32767))
	var sound := AudioStreamWAV.new()
	sound.format = AudioStreamWAV.FORMAT_16_BITS
	sound.mix_rate = RATE
	sound.data = data
	if loop:
		sound.loop_mode = AudioStreamWAV.LOOP_FORWARD
		sound.loop_end = count
	_cache[key] = sound
	return sound

static func _rain_bed(loop: bool) -> AudioStreamWAV:
	# Continuous diffuse rain, without the old 13 regularly struck resonances.
	# Generate an extra tail and overlap it into the head to make the wrap soft.
	var count := int(RATE*RAIN_SECONDS)
	var overlap := int(RATE*RAIN_OVERLAP)
	var samples := PackedFloat32Array()
	samples.resize(count+overlap)
	var rng := RandomNumberGenerator.new()
	rng.seed = 179
	var soft := 0.0
	var low := 0.0
	for index in samples.size():
		var noise := rng.randf_range(-1,1)
		soft += (noise-soft)*0.18
		low += (noise-low)*0.035
		var phase := TAU*float(index)/count
		var swell := 0.85+0.10*sin(phase)+0.05*cos(phase*2)
		samples[index] = (soft*0.19+low*0.24)*swell*0.85
	var data := PackedByteArray()
	data.resize(count*2)
	for index in count:
		var value := samples[index]
		if loop and index < overlap:
			value = lerpf(samples[count+index],value,smoothstep(0,1,float(index)/overlap))
		elif not loop:
			value *= minf(float(index)/(RATE*0.12),1)*minf(float(count-index)/(RATE*0.20),1)
		data.encode_s16(index*2,int(clampf(value,-0.9,0.9)*32767))
	var sound := AudioStreamWAV.new()
	sound.format = AudioStreamWAV.FORMAT_16_BITS
	sound.mix_rate = RATE
	sound.data = data
	if loop:
		sound.loop_mode = AudioStreamWAV.LOOP_FORWARD
		sound.loop_end = count
	return sound
