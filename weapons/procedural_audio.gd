class_name ProceduralAudio
extends RefCounted
## Original, license-free procedural SFX generated at runtime as 16-bit PCM.
## Ported from origin/sheji/systems/procedural_audio.gd (MIT).

const SAMPLE_RATE := 44100
## The one-pole coefficients below (0.65, 0.45, 0.24, 0.07, ...) were dialled in
## while this synth ran at 22050 Hz. `_legacy_alpha` re-derives them for the
## current rate, so their cutoff frequencies stay where the ear expects them
## instead of doubling along with the sample rate.
const LEGACY_SAMPLE_RATE := 22050
## Gunshots: the crack gets a short attack and a low-pass so it snaps instead of
## clicking, and a few early reflections give it a room instead of a dry pop.
const CRACK_ATTACK := 0.0025
const CRACK_LOWPASS := 0.65
## Black-crystal mineral transient: a 3.2-6.8 kHz noise band plus a few short
## inharmonic partials that give the pistol its glassy edge on top of the punch.
const MINERAL_LOW := 3200.0
const MINERAL_HIGH := 6800.0
const MINERAL_ATTACK := 0.0004
const MINERAL_PARTIALS := [3320.0, 4150.0, 5300.0, 6620.0]
const MINERAL_PARTIAL_GAINS := [0.44, 0.32, 0.24, 0.18]
const GUN_TAPS := [[0.023, 0.18], [0.037, 0.11], [0.061, 0.07]]
const GUN_MASTER_ATTACK := 0.003
## Every generated impact peaks here, so swapping sounds does not jump in level.
const PEAK_TARGET_DB := -3.0
const COMMON_KINDS := [
	"gun_pistol", "enemy_shot", "hit_kill", "hit_kill_head", "hit_tink",
	"brittle_glass", "player_hurt", "player_hurt_heavy", "heartbeat", "dry",
	"hit_flesh", "hit_metal", "melee_swing", "melee_hit", "dash",
	"clock_hit", "clock_perfect", "clock_break", "shockwave",
	"hit_block", "pistol_low_ammo",
]
static var _cache: Dictionary = {}


static func prepare_common() -> void:
	for kind in COMMON_KINDS:
		generate(kind)


static func generate(kind: String) -> AudioStreamWAV:
	if _cache.has(kind):
		return _cache[kind] as AudioStreamWAV
	var stream := _generate_uncached(kind)
	_cache[kind] = stream
	return stream


static func _generate_uncached(kind: String) -> AudioStreamWAV:
	match kind:
		# Layered player guns: a low thump, a bright crack, the body of the blast
		# and a tail. The older single-burst kinds below stay for enemies.
		"enemy_shot":
			return _layered_gunshot({
				"duration": 0.34, "seed": 11,
				"thump_from": 150.0, "thump_to": 58.0, "thump_decay": 30.0, "thump_amp": 0.72,
				"crack_decay": 110.0, "crack_amp": 0.38,
				"body_decay": 22.0, "body_amp": 0.82, "body_lp": 0.24,
				"tail_decay": 9.0, "tail_amp": 0.16, "tail_lp": 0.07})
		"gun_pistol":
			return _layered_gunshot({
				"duration": 0.20, "seed": 14,
				"thump_from": 165.0, "thump_to": 48.0, "thump_decay": 24.0, "thump_amp": 0.78,
				"crack_decay": 130.0, "crack_amp": 0.42,
				"body_decay": 26.0, "body_amp": 0.62, "body_lp": 0.24,
				"tail_decay": 13.0, "tail_amp": 0.11, "tail_lp": 0.07,
				"mineral_amp": 0.6, "mineral_decay": 100.0})
		"hit_kill":
			return _kill_confirm(false)
		"hit_kill_head":
			return _kill_confirm(true)
		"hit_tink":
			return _ping(0.16, [2900.0, 4300.0], 30.0)
		"brittle_glass":
			return _ping(0.24, [2700.0, 4250.0, 6150.0, 8310.0], 18.0)
		# Taking a hit: a low muffled thud with a little grit. The heavy variant
		# falls deeper and rings longer for big hits and headshots.
		"player_hurt":
			return _hurt_thump(0.18, 170.0, 62.0, 26.0, 0.55, 31)
		"player_hurt_heavy":
			return _hurt_thump(0.30, 120.0, 42.0, 15.0, 0.8, 32)
		"heartbeat":
			return _heartbeat()
		"dry":
			return _click_sequence([0.0], 0.04)
		"hit_flesh":
			return _noise_burst(0.06, 42.0, 0.4, 0.1)
		"hit_metal":
			return _noise_burst(0.09, 46.0, 0.5, 0.1)
		"melee_swing":
			return _knife_swing(0.22, 0.38, 0.55, 0.24)
		"melee_hit":
			return _knife_hit(0.15, 0.6)
		"hit_block":
			return _shield_block()
		"pistol_low_ammo":
			return _low_ammo_cue()
		"dash":
			return _knife_swing(0.24, 0.55, 0.6, 0.18)
		"clock_hit":
			return _clock_thud(false)
		"clock_perfect":
			return _clock_thud(true)
		"clock_break":
			return _clock_break()
		"shockwave":
			return _noise_burst(0.55, 6.0, 1.0, 0.08)
	return _noise_burst(0.1, 30.0, 0.5, 0.15)


## One-pole low-pass coefficient for `cutoff_hz` at the current mix rate.
static func _alpha(cutoff_hz: float) -> float:
	return 1.0 - exp(-TAU * cutoff_hz / SAMPLE_RATE)


## Translate a coefficient tuned at LEGACY_SAMPLE_RATE into the current rate by
## way of its cutoff frequency. Same RC time constant, same tone.
static func _legacy_alpha(alpha_at_legacy: float) -> float:
	return _alpha(-log(1.0 - alpha_at_legacy) * LEGACY_SAMPLE_RATE / TAU)


static func _noise_burst(duration: float, decay: float, amp: float, lp_factor: float) -> AudioStreamWAV:
	var sample_count := int(duration * SAMPLE_RATE)
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20240712
	var lp_alpha := _legacy_alpha(lp_factor)
	var lowpass := 0.0
	for i in sample_count:
		var t := float(i) / SAMPLE_RATE
		var envelope := exp(-t * decay)
		var white := rng.randf_range(-1.0, 1.0)
		lowpass += (white - lowpass) * lp_alpha
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
##  - mineral: optional 3.2-6.8 kHz noise band (the black-crystal edge),
##  - early taps at GUN_TAPS, fed back through the dry signal, so the shot is
##    not bone dry.
## Uses its own seeded generator, never the global one.
static func _layered_gunshot(p: Dictionary) -> AudioStreamWAV:
	var sample_count := int(p.duration * SAMPLE_RATE)
	var samples := PackedFloat32Array()
	samples.resize(sample_count)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20240712 + int(p.seed)
	var body_alpha := _legacy_alpha(p.body_lp)
	var tail_alpha := _legacy_alpha(p.tail_lp)
	var crack_hp_alpha := _legacy_alpha(0.45)
	var crack_lp_alpha := _legacy_alpha(CRACK_LOWPASS)
	var mineral_low_alpha := _alpha(MINERAL_LOW)
	var mineral_high_alpha := _alpha(MINERAL_HIGH)
	var mineral_amp := float(p.get("mineral_amp", 0.0))
	var mineral_decay := float(p.get("mineral_decay", 140.0))
	var body_lp := 0.0
	var tail_lp := 0.0
	var crack_lp := 0.0
	var crack_soft := 0.0
	var mineral_low_lp := 0.0
	var mineral_high_lp := 0.0
	var phase := 0.0
	for i in sample_count:
		var t := float(i) / SAMPLE_RATE
		var white := rng.randf_range(-1.0, 1.0)
		var freq := lerpf(p.thump_from, p.thump_to, 1.0 - exp(-t * 40.0))
		phase += TAU * freq / SAMPLE_RATE
		var thump: float = sin(phase) * exp(-t * p.thump_decay) * p.thump_amp
		crack_lp += (white - crack_lp) * crack_hp_alpha
		crack_soft += ((white - crack_lp) - crack_soft) * crack_lp_alpha
		var crack: float = crack_soft * minf(t / CRACK_ATTACK, 1.0) * exp(-t * p.crack_decay) * p.crack_amp
		body_lp += (white - body_lp) * body_alpha
		var body: float = body_lp * exp(-t * p.body_decay) * p.body_amp * 2.2
		tail_lp += (white - tail_lp) * tail_alpha
		var tail: float = tail_lp * exp(-t * p.tail_decay) * p.tail_amp * 3.5
		mineral_low_lp += (white - mineral_low_lp) * mineral_low_alpha
		mineral_high_lp += (white - mineral_high_lp) * mineral_high_alpha
		var mineral := 0.0
		if mineral_amp > 0.0:
			var band := mineral_low_lp - mineral_high_lp
			var crystal := band * 0.5
			for k in MINERAL_PARTIALS.size():
				crystal += sin(TAU * float(MINERAL_PARTIALS[k]) * t) * float(MINERAL_PARTIAL_GAINS[k])
			mineral = crystal * minf(t / MINERAL_ATTACK, 1.0) * exp(-t * mineral_decay) * mineral_amp
		# Soft clip, then a few ms of fade-in so the thump does not click on.
		samples[i] = tanh((thump + crack + body + tail + mineral) * 1.4) * minf(t / GUN_MASTER_ATTACK, 1.0)
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
	var snap_alpha := _legacy_alpha(0.3)
	var lp := 0.0
	for i in sample_count:
		var t := float(i) / SAMPLE_RATE
		phase += TAU * lerpf(punch_from, punch_to, 1.0 - exp(-t * 16.0)) / SAMPLE_RATE
		var punch := sin(phase) * exp(-t * 13.0) * 1.0
		lp += (rng.randf_range(-1.0, 1.0) - lp) * snap_alpha
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
	var grit_alpha := _legacy_alpha(0.12)
	var phase := 0.0
	var lowpass := 0.0
	for i in sample_count:
		var t := float(i) / SAMPLE_RATE
		phase += TAU * lerpf(from, to, 1.0 - exp(-t * 30.0)) / SAMPLE_RATE
		var thud := sin(phase) * exp(-t * decay) * 0.9
		lowpass += (rng.randf_range(-1.0, 1.0) - lowpass) * grit_alpha
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
	var lp_alpha := _legacy_alpha(lowpass_factor)
	var lowpass := 0.0
	var attack := 0.05

	for i in sample_count:
		var t := float(i) / SAMPLE_RATE
		var env := t / attack if t < attack else exp(-(t - attack) * 10.0)

		var white := rng.randf_range(-1.0, 1.0)
		lowpass += (white - lowpass) * lp_alpha
		var whoosh := lowpass * env * amp

		# High-frequency shimmer: subtract the lowpass from the raw noise and
		# fade it quickly for a metallic edge.
		var shimmer := (white - lowpass) * env * shimmer_amount * exp(-t * 16.0)

		var value := int(clampf(whoosh + shimmer, -1.0, 1.0) * 32767.0) & 0xFFFF
		data[i * 2] = value & 0xFF
		data[i * 2 + 1] = (value >> 8) & 0xFF
	return _make_wav(data)


## Knife impact: a low body punch falling 135 -> 50 Hz, a filtered crunch and a
## few short crystal slice partials. The punch carries the weight, the partials
## give the obsidian edge that a plain noise burst never had.
static func _knife_hit(duration: float, amp: float) -> AudioStreamWAV:
	var sample_count := int(duration * SAMPLE_RATE)
	var samples := PackedFloat32Array()
	samples.resize(sample_count)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20240712 + 99
	var crunch_alpha := _legacy_alpha(0.18)
	var partials := [3320.0, 4710.0, 6380.0]
	var phase := 0.0
	var lowpass := 0.0

	for i in sample_count:
		var t := float(i) / SAMPLE_RATE
		var white := rng.randf_range(-1.0, 1.0)

		phase += TAU * lerpf(135.0, 50.0, 1.0 - exp(-t * 34.0)) / SAMPLE_RATE
		var punch := sin(phase) * exp(-t * 22.0) * amp

		lowpass += (white - lowpass) * crunch_alpha
		var crunch := lowpass * exp(-t * 38.0) * amp * 0.9

		var slice := 0.0
		for k in partials.size():
			slice += sin(TAU * float(partials[k]) * t) * exp(-t * (46.0 + 26.0 * k))
		slice *= minf(t / 0.0008, 1.0) * amp * 0.4 / partials.size()

		samples[i] = tanh((punch + crunch + slice) * 1.3) * minf(t / 0.002, 1.0)
	return _make_normalised_wav(samples, 0.0)


## Shield block: a dull hard-crystal thud under a short inharmonic metal ring,
## so a parried bullet never sounds like a landed hit.
static func _shield_block() -> AudioStreamWAV:
	var duration := 0.30
	var sample_count := int(duration * SAMPLE_RATE)
	var samples := PackedFloat32Array()
	samples.resize(sample_count)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20240712 + 53
	var partials := [1390.0, 1930.0, 2870.0, 4520.0]
	var body_alpha := _legacy_alpha(0.24)
	var crack_alpha := _legacy_alpha(0.45)
	var phase := 0.0
	var body_lp := 0.0
	var crack_lp := 0.0
	for i in sample_count:
		var t := float(i) / SAMPLE_RATE
		var white := rng.randf_range(-1.0, 1.0)
		phase += TAU * lerpf(118.0, 52.0, 1.0 - exp(-t * 30.0)) / SAMPLE_RATE
		var thud := sin(phase) * exp(-t * 20.0) * 0.85
		body_lp += (white - body_lp) * body_alpha
		var body := body_lp * exp(-t * 42.0) * 0.8
		crack_lp += (white - crack_lp) * crack_alpha
		var crack := (white - crack_lp) * minf(t / 0.0012, 1.0) * exp(-t * 110.0) * 0.5
		var ring := 0.0
		for k in partials.size():
			ring += sin(TAU * float(partials[k]) * t) * exp(-t * (11.0 + 3.0 * k))
		ring *= minf(t / 0.002, 1.0) * 0.16
		samples[i] = tanh((thud + body + crack + ring) * 1.4) * minf(t / 0.002, 1.0)
	return _make_normalised_wav(samples, PEAK_TARGET_DB)


## Low-ammo cue: a tiny high crystal tick meant to layer over the last shots.
static func _low_ammo_cue() -> AudioStreamWAV:
	var duration := 0.055
	var sample_count := int(duration * SAMPLE_RATE)
	var samples := PackedFloat32Array()
	samples.resize(sample_count)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20240712 + 57
	var tick_alpha := _legacy_alpha(0.5)
	var click_lp := 0.0
	for i in sample_count:
		var t := float(i) / SAMPLE_RATE
		var white := rng.randf_range(-1.0, 1.0)
		click_lp += (white - click_lp) * tick_alpha
		var tick := (white - click_lp) * exp(-t * 320.0) * 0.5
		var chime := (sin(TAU * 4260.0 * t) * 0.55 + sin(TAU * 6320.0 * t) * 0.35) \
			* exp(-t * 95.0) * minf(t / 0.0005, 1.0)
		samples[i] = tanh((tick + chime) * 1.2) * minf(t / 0.001, 1.0)
	return _make_normalised_wav(samples, -6.0)


## Struck-metal ring: a few decaying sine partials over a short noise click.
## Clearly tonal, so a perfect blade strike never sounds like the dull thud of
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


## Blade on stone: a low thud, a short crack and a noise body. A perfect strike
## adds a bright bell on top so it reads even over the building's flash.
static func _clock_thud(bell: bool) -> AudioStreamWAV:
	var duration := 0.5 if bell else 0.22
	var sample_count := int(duration * SAMPLE_RATE)
	var samples := PackedFloat32Array()
	samples.resize(sample_count)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20240712 + (41 if bell else 40)
	var body_alpha := _legacy_alpha(0.12)
	var crack_alpha := _legacy_alpha(0.5)
	var phase := 0.0
	var body_lp := 0.0
	var crack_lp := 0.0
	for i in sample_count:
		var t := float(i) / SAMPLE_RATE
		var white := rng.randf_range(-1.0, 1.0)
		phase += TAU * lerpf(140.0, 52.0, 1.0 - exp(-t * 20.0)) / SAMPLE_RATE
		var thud := sin(phase) * exp(-t * 18.0) * 0.95
		body_lp += (white - body_lp) * body_alpha
		var body := body_lp * exp(-t * 26.0)
		crack_lp += (white - crack_lp) * crack_alpha
		var crack := (white - crack_lp) * minf(t / 0.002, 1.0) * exp(-t * 60.0) * 0.5
		var mixed := thud + body + crack
		if bell:
			for partial in [1320.0, 1760.0, 2640.0]:
				mixed += sin(TAU * partial * t) * exp(-t * 6.0) * 0.14
		samples[i] = tanh(mixed * 1.3) * minf(t / 0.002, 1.0)
	return _make_normalised_wav(samples, PEAK_TARGET_DB)


## The stopped clock breaking open: a heavy crunch, then a clock spring letting
## go (a fast falling tone) with a small metallic chime over it.
static func _clock_break() -> AudioStreamWAV:
	var duration := 0.95
	var sample_count := int(duration * SAMPLE_RATE)
	var samples := PackedFloat32Array()
	samples.resize(sample_count)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20240712 + 44
	var crunch_alpha := _legacy_alpha(0.28)
	var hiss_alpha := _legacy_alpha(0.7)
	var phase := 0.0
	var crunch_lp := 0.0
	var hiss_lp := 0.0
	for i in sample_count:
		var t := float(i) / SAMPLE_RATE
		var white := rng.randf_range(-1.0, 1.0)
		phase += TAU * lerpf(130.0, 38.0, 1.0 - exp(-t * 14.0)) / SAMPLE_RATE
		var thud := sin(phase) * exp(-t * 8.0)
		crunch_lp += (white - crunch_lp) * crunch_alpha
		var crunch := crunch_lp * exp(-t * 7.0) * 1.2
		hiss_lp += (white - hiss_lp) * hiss_alpha
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
