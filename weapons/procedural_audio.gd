class_name ProceduralAudio
extends RefCounted
## Original, license-free procedural SFX generated at runtime as 16-bit PCM.
## Ported from origin/sheji/systems/procedural_audio.gd (MIT).

const SAMPLE_RATE := 22050
## Gunshots: the crack gets a short attack and a low-pass so it snaps instead of
## clicking, and a few early reflections give it a room instead of a dry pop.
const CRACK_ATTACK := 0.0025
const CRACK_LOWPASS := 0.65
const GUN_TAPS := [[0.023, 0.18], [0.037, 0.11], [0.061, 0.07]]
const GUN_MASTER_ATTACK := 0.003
## Every generated impact peaks here, so swapping sounds does not jump in level.
const PEAK_TARGET_DB := -3.0


static func generate(kind: String) -> AudioStreamWAV:
	match kind:
		# Layered player guns: a low thump, a bright crack, the body of the blast
		# and a tail. The older single-burst kinds below stay for enemies.
		"gun_rifle":
			return _layered_gunshot({
				"duration": 0.34, "seed": 11,
				"thump_from": 150.0, "thump_to": 58.0, "thump_decay": 30.0, "thump_amp": 0.72,
				"crack_decay": 110.0, "crack_amp": 0.38,
				"body_decay": 22.0, "body_amp": 0.82, "body_lp": 0.24,
				"tail_decay": 9.0, "tail_amp": 0.16, "tail_lp": 0.07})
		"gun_shotgun":
			return _layered_gunshot({
				"duration": 0.62, "seed": 12,
				"thump_from": 110.0, "thump_to": 38.0, "thump_decay": 15.0, "thump_amp": 1.0,
				"crack_decay": 60.0, "crack_amp": 0.41,
				"body_decay": 15.0, "body_amp": 1.0, "body_lp": 0.17,
				"tail_decay": 6.0, "tail_amp": 0.24, "tail_lp": 0.05})
		"gun_sniper":
			return _layered_gunshot({
				"duration": 0.95, "seed": 13,
				"thump_from": 90.0, "thump_to": 30.0, "thump_decay": 9.0, "thump_amp": 1.08,
				"crack_decay": 80.0, "crack_amp": 0.56,
				"body_decay": 12.0, "body_amp": 0.9, "body_lp": 0.13,
				"tail_decay": 4.2, "tail_amp": 0.3, "tail_lp": 0.035})
		"gun_pistol":
			return _layered_gunshot({
				"duration": 0.20, "seed": 14,
				"thump_from": 150.0, "thump_to": 65.0, "thump_decay": 35.0, "thump_amp": 0.6,
				"crack_decay": 130.0, "crack_amp": 0.4,
				"body_decay": 28.0, "body_amp": 0.65, "body_lp": 0.24,
				"tail_decay": 15.0, "tail_amp": 0.1, "tail_lp": 0.07})
		"hit_kill":
			return _kill_confirm(false)
		"hit_kill_head":
			return _kill_confirm(true)
		"hit_tink":
			return _ping(0.16, [2900.0, 4300.0], 30.0)
		# Taking a hit: a low muffled thud with a little grit. The heavy variant
		# falls deeper and rings longer for big hits and headshots.
		"player_hurt":
			return _hurt_thump(0.18, 170.0, 62.0, 26.0, 0.55, 31)
		"player_hurt_heavy":
			return _hurt_thump(0.30, 120.0, 42.0, 15.0, 0.8, 32)
		"heartbeat":
			return _heartbeat()
		"gunshot_sniper":
			return _noise_burst(0.34, 20.0, 1.0, 0.2)
		"gunshot_shotgun":
			return _noise_burst(0.22, 26.0, 0.95, 0.16)
		"gunshot_rifle":
			return _noise_burst(0.24, 24.0, 0.95, 0.22)
		"gunshot_ak47":
			return _noise_burst(0.13, 26.0, 0.8, 0.2)
		"gunshot_medium":
			return _noise_burst(0.16, 30.0, 0.7, 0.18)
		"gunshot_deagle":
			return _noise_burst(0.14, 30.0, 0.85, 0.15)
		"gunshot_small":
			return _noise_burst(0.1, 36.0, 0.5, 0.14)
		"reload":
			return _click_sequence([0.0, 0.13, 0.26, 0.38], 0.055)
		"bolt":
			return _click_sequence([0.0, 0.16, 0.3], 0.05)
		"dry":
			return _click_sequence([0.0], 0.04)
		"hit_flesh":
			return _noise_burst(0.06, 42.0, 0.4, 0.1)
		"hit_metal":
			return _noise_burst(0.09, 46.0, 0.5, 0.1)
		"melee_swing":
			return _knife_swing(0.22, 0.38, 0.55, 0.24)
		"melee_swing_heavy":
			return _knife_swing(0.34, 0.5, 0.4, 0.2)
		"melee_hit":
			return _knife_hit(0.15, 0.6)
		"dash":
			return _knife_swing(0.24, 0.55, 0.6, 0.18)
		"hammer_hit":
			return _hammer_thud(false)
		"hammer_perfect":
			return _hammer_thud(true)
		"hammer_break":
			return _hammer_break()
		"shockwave":
			return _noise_burst(0.55, 6.0, 1.0, 0.08)
	return _noise_burst(0.1, 30.0, 0.5, 0.15)


static func gunshot_for(kind: String) -> String:
	match kind:
		"sniper":
			return "gunshot_sniper"
		"shotgun":
			return "gunshot_shotgun"
		"deagle":
			return "gunshot_deagle"
		"ak47":
			return "gunshot_ak47"
		"rifle_bolt", "rifle_semi":
			return "gunshot_rifle"
		"smg":
			return "gunshot_medium"
		"pistol":
			return "gunshot_small"
	return "gunshot_medium"


static func _noise_burst(duration: float, decay: float, amp: float, lp_factor: float) -> AudioStreamWAV:
	var sample_count := int(duration * SAMPLE_RATE)
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20240712
	var lowpass := 0.0
	for i in sample_count:
		var t := float(i) / SAMPLE_RATE
		var envelope := exp(-t * decay)
		var white := rng.randf_range(-1.0, 1.0)
		lowpass += (white - lowpass) * lp_factor
		var value := int(clampf(lowpass * amp * envelope, -1.0, 1.0) * 32767.0) & 0xFFFF
		data[i * 2] = value & 0xFF
		data[i * 2 + 1] = (value >> 8) & 0xFF
	return _make_wav(data)


## One gunshot out of four layers plus a few early reflections, soft-clipped
## and normalised to PEAK_TARGET_DB:
##  - thump: a sine falling from `thump_from` to `thump_to` Hz (the chest punch),
##  - crack: high-passed noise run through a low-pass with a short attack, so it
##    is a snap rather than a click,
##  - body: low-passed noise (the blast itself),
##  - tail: very dark noise that rings on (the room),
##  - early taps at GUN_TAPS, fed back through the dry signal, so the shot is
##    not bone dry.
## Uses its own seeded generator, never the global one.
static func _layered_gunshot(p: Dictionary) -> AudioStreamWAV:
	var sample_count := int(p.duration * SAMPLE_RATE)
	var samples := PackedFloat32Array()
	samples.resize(sample_count)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20240712 + int(p.seed)
	var body_lp := 0.0
	var tail_lp := 0.0
	var crack_lp := 0.0
	var crack_soft := 0.0
	var phase := 0.0
	for i in sample_count:
		var t := float(i) / SAMPLE_RATE
		var white := rng.randf_range(-1.0, 1.0)
		var freq := lerpf(p.thump_from, p.thump_to, 1.0 - exp(-t * 40.0))
		phase += TAU * freq / SAMPLE_RATE
		var thump: float = sin(phase) * exp(-t * p.thump_decay) * p.thump_amp
		crack_lp += (white - crack_lp) * 0.45
		crack_soft += ((white - crack_lp) - crack_soft) * CRACK_LOWPASS
		var crack: float = crack_soft * minf(t / CRACK_ATTACK, 1.0) * exp(-t * p.crack_decay) * p.crack_amp
		body_lp += (white - body_lp) * p.body_lp
		var body: float = body_lp * exp(-t * p.body_decay) * p.body_amp * 2.2
		tail_lp += (white - tail_lp) * p.tail_lp
		var tail: float = tail_lp * exp(-t * p.tail_decay) * p.tail_amp * 3.5
		# Soft clip, then a few ms of fade-in so the thump does not click on.
		samples[i] = tanh((thump + crack + body + tail) * 1.4) * minf(t / GUN_MASTER_ATTACK, 1.0)
	# Early reflections: a handful of taps off the dry signal, decaying.
	for tap in GUN_TAPS:
		var delay := int(float(tap[0]) * SAMPLE_RATE)
		var gain := float(tap[1])
		for i in range(delay, sample_count):
			samples[i] += samples[i - delay] * gain
	return _make_normalised_wav(samples, PEAK_TARGET_DB)


## Kill confirm: a low punch plus a short bright transient. The headshot version
## sits higher and rings a little longer, so a headshot kill never sounds like a
## body kill.
static func _kill_confirm(head: bool) -> AudioStreamWAV:
	var duration := 0.32 if head else 0.26
	var sample_count := int(duration * SAMPLE_RATE)
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20240712 + (22 if head else 21)
	var punch_from := 240.0 if head else 210.0
	var punch_to := 78.0 if head else 62.0
	var confirm := 1560.0 if head else 1180.0
	var overtone := 2340.0 if head else 1760.0
	var phase := 0.0
	var lp := 0.0
	for i in sample_count:
		var t := float(i) / SAMPLE_RATE
		phase += TAU * lerpf(punch_from, punch_to, 1.0 - exp(-t * 16.0)) / SAMPLE_RATE
		var punch := sin(phase) * exp(-t * 13.0) * 1.0
		lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.3
		var snap := lp * exp(-t * 80.0) * 0.35
		var ring := (sin(TAU * confirm * t) * 0.55 + sin(TAU * overtone * t) * 0.25) \
			* exp(-t * (15.0 if head else 18.0)) * minf(t / 0.003, 1.0)
		var mixed := tanh((punch + snap + ring) * 1.3) * minf(t / 0.002, 1.0)
		var value := int(clampf(mixed, -1.0, 1.0) * 32767.0) & 0xFFFF
		data[i * 2] = value & 0xFF
		data[i * 2 + 1] = (value >> 8) & 0xFF
	return _make_wav(data)


## Player hurt: a sine thud falling from `from` to `to` Hz with low-passed
## noise grit on top. The heavy variant starts lower and decays slower.
static func _hurt_thump(duration: float, from: float, to: float, decay: float,
		grit: float, seed: int) -> AudioStreamWAV:
	var sample_count := int(duration * SAMPLE_RATE)
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20240712 + seed
	var phase := 0.0
	var lowpass := 0.0
	for i in sample_count:
		var t := float(i) / SAMPLE_RATE
		phase += TAU * lerpf(from, to, 1.0 - exp(-t * 30.0)) / SAMPLE_RATE
		var thud := sin(phase) * exp(-t * decay) * 0.9
		lowpass += (rng.randf_range(-1.0, 1.0) - lowpass) * 0.12
		var dust := lowpass * exp(-t * 34.0) * grit * 1.6
		var mixed := tanh((thud + dust) * 1.2) * minf(t / 0.003, 1.0)
		var value := int(clampf(mixed, -1.0, 1.0) * 32767.0) & 0xFFFF
		data[i * 2] = value & 0xFF
		data[i * 2 + 1] = (value >> 8) & 0xFF
	return _make_wav(data)


## Low-health heartbeat: two soft low thumps ("lub-dub"). One beat is short so
## the caller can replay it at a health-dependent rate instead of pitching it.
static func _heartbeat() -> AudioStreamWAV:
	var duration := 0.42
	var beats := [0.0, 0.16]
	var sample_count := int(duration * SAMPLE_RATE)
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	for i in sample_count:
		var t := float(i) / SAMPLE_RATE
		var value := 0.0
		for b in beats.size():
			var local := t - float(beats[b])
			if local < 0.0:
				continue
			var freq := 56.0 if b == 0 else 46.0
			var amp := 0.9 if b == 0 else 0.65
			value += sin(TAU * freq * local) * exp(-local * 22.0) * amp * minf(local / 0.006, 1.0)
		var sample := int(clampf(tanh(value * 1.3), -1.0, 1.0) * 32767.0) & 0xFFFF
		data[i * 2] = sample & 0xFF
		data[i * 2 + 1] = (sample >> 8) & 0xFF
	return _make_wav(data)


static func _click_sequence(times: Array[float], click_duration: float) -> AudioStreamWAV:
	var total := times[times.size() - 1] + click_duration + 0.03
	var sample_count := int(total * SAMPLE_RATE)
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20240712
	for i in sample_count:
		var t := float(i) / SAMPLE_RATE
		var value := 0.0
		for click_time in times:
			var local_t := t - click_time
			if local_t >= 0.0 and local_t < click_duration:
				var envelope := exp(-local_t * 70.0)
				value += rng.randf_range(-1.0, 1.0) * envelope * 0.7
		value = clampf(value, -1.0, 1.0)
		var sample := int(value * 32767.0) & 0xFFFF
		data[i * 2] = sample & 0xFF
		data[i * 2 + 1] = (sample >> 8) & 0xFF
	return _make_wav(data)


## Knife swing built from two noise layers:
##  - a low "air whoosh" with a fast attack,
##  - a bright, short "blade shimmer" (high-frequency filtered noise).
## Heavy swings are longer, deeper and slower.
static func _knife_swing(duration: float, amp: float, shimmer_amount: float, lowpass_factor: float) -> AudioStreamWAV:
	var sample_count := int(duration * SAMPLE_RATE)
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20240712 + int(duration * 1000.0)
	var lowpass := 0.0
	var attack := 0.05

	for i in sample_count:
		var t := float(i) / SAMPLE_RATE
		var env := t / attack if t < attack else exp(-(t - attack) * 10.0)

		var white := rng.randf_range(-1.0, 1.0)
		lowpass += (white - lowpass) * lowpass_factor
		var whoosh := lowpass * env * amp

		# High-frequency shimmer: subtract the lowpass from the raw noise and
		# fade it quickly for a metallic edge.
		var shimmer := (white - lowpass) * env * shimmer_amount * exp(-t * 16.0)

		var value := int(clampf(whoosh + shimmer, -1.0, 1.0) * 32767.0) & 0xFFFF
		data[i * 2] = value & 0xFF
		data[i * 2 + 1] = (value >> 8) & 0xFF
	return _make_wav(data)


## Knife impact: a low-passed "thump" plus a very short bright click. Both are
## noise-based so they stay percussive instead of tonal.
static func _knife_hit(duration: float, amp: float) -> AudioStreamWAV:
	var sample_count := int(duration * SAMPLE_RATE)
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20240712 + 99
	var lowpass := 0.0

	for i in sample_count:
		var t := float(i) / SAMPLE_RATE
		var white := rng.randf_range(-1.0, 1.0)

		lowpass += (white - lowpass) * 0.18
		var thump := lowpass * exp(-t * 34.0) * amp

		var click := (white - lowpass) * exp(-t * 70.0) * amp * 0.8

		var value := int(clampf(thump + click, -1.0, 1.0) * 32767.0) & 0xFFFF
		data[i * 2] = value & 0xFF
		data[i * 2 + 1] = (value >> 8) & 0xFF
	return _make_wav(data)


## Struck-metal ring: a few decaying sine partials over a short noise click.
## Clearly tonal, so a perfect hammer strike never sounds like the dull thud of
## an ordinary one.
static func _ping(duration: float, partials: Array[float], decay: float) -> AudioStreamWAV:
	var sample_count := int(duration * SAMPLE_RATE)
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20240712 + 7
	for i in sample_count:
		var t := float(i) / SAMPLE_RATE
		var value := rng.randf_range(-1.0, 1.0) * exp(-t * 120.0) * 0.5
		for k in partials.size():
			value += sin(TAU * partials[k] * t) * exp(-t * decay * (1.0 + 0.4 * k)) * 0.8 / partials.size()
		var sample := int(clampf(value, -1.0, 1.0) * 32767.0) & 0xFFFF
		data[i * 2] = sample & 0xFF
		data[i * 2 + 1] = (sample >> 8) & 0xFF
	return _make_wav(data)


## Hammer on stone: a low thud, a short crack and a noise body. A perfect strike
## adds a bright bell on top so it reads even over the building's flash.
static func _hammer_thud(bell: bool) -> AudioStreamWAV:
	var duration := 0.5 if bell else 0.22
	var sample_count := int(duration * SAMPLE_RATE)
	var samples := PackedFloat32Array()
	samples.resize(sample_count)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20240712 + (41 if bell else 40)
	var phase := 0.0
	var body_lp := 0.0
	var crack_lp := 0.0
	for i in sample_count:
		var t := float(i) / SAMPLE_RATE
		var white := rng.randf_range(-1.0, 1.0)
		phase += TAU * lerpf(140.0, 52.0, 1.0 - exp(-t * 20.0)) / SAMPLE_RATE
		var thud := sin(phase) * exp(-t * 18.0) * 0.95
		body_lp += (white - body_lp) * 0.12
		var body := body_lp * exp(-t * 26.0)
		crack_lp += (white - crack_lp) * 0.5
		var crack := (white - crack_lp) * minf(t / 0.002, 1.0) * exp(-t * 60.0) * 0.5
		var mixed := thud + body + crack
		if bell:
			for partial in [1320.0, 1760.0, 2640.0]:
				mixed += sin(TAU * partial * t) * exp(-t * 6.0) * 0.14
		samples[i] = tanh(mixed * 1.3) * minf(t / 0.002, 1.0)
	return _make_normalised_wav(samples, PEAK_TARGET_DB)


## The stopped clock breaking open: a heavy crunch, then a clock spring letting
## go (a fast falling tone) with a small metallic chime over it.
static func _hammer_break() -> AudioStreamWAV:
	var duration := 0.95
	var sample_count := int(duration * SAMPLE_RATE)
	var samples := PackedFloat32Array()
	samples.resize(sample_count)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20240712 + 44
	var phase := 0.0
	var crunch_lp := 0.0
	var hiss_lp := 0.0
	for i in sample_count:
		var t := float(i) / SAMPLE_RATE
		var white := rng.randf_range(-1.0, 1.0)
		phase += TAU * lerpf(130.0, 38.0, 1.0 - exp(-t * 14.0)) / SAMPLE_RATE
		var thud := sin(phase) * exp(-t * 8.0)
		crunch_lp += (white - crunch_lp) * 0.28
		var crunch := crunch_lp * exp(-t * 7.0) * 1.2
		hiss_lp += (white - hiss_lp) * 0.7
		var hiss := (white - hiss_lp) * minf(t / 0.004, 1.0) * exp(-t * 26.0) * 0.45
		var spring := sin(TAU * lerpf(1500.0, 480.0, minf(t / 0.5, 1.0)) * t) \
			* exp(-t * 3.2) * (0.16 + 0.05 * sin(t * 90.0)) * minf(t / 0.01, 1.0)
		var chime := sin(TAU * 1980.0 * t) * exp(-t * 4.5) * 0.1
		samples[i] = tanh((thud + crunch + hiss + spring + chime) * 1.2) * minf(t / 0.002, 1.0)
	return _make_normalised_wav(samples, PEAK_TARGET_DB)


## Float samples scaled so the loudest one sits at `target_db`, then written as
## 16-bit PCM. Used to keep the three guns at the same level.
static func _make_normalised_wav(samples: PackedFloat32Array, target_db: float) -> AudioStreamWAV:
	var peak := 0.0
	for value in samples:
		peak = maxf(peak, absf(value))
	var gain := pow(10.0, target_db / 20.0) / maxf(peak, 0.0001)
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		var value := int(clampf(samples[i] * gain, -1.0, 1.0) * 32767.0) & 0xFFFF
		data[i * 2] = value & 0xFF
		data[i * 2 + 1] = (value >> 8) & 0xFF
	return _make_wav(data)


static func _make_wav(data: PackedByteArray) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = data
	return stream
