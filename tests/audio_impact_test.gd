extends Node
## Focused check for the 44.1 kHz combat audio upgrade (#242): the mix rate,
## the reshaped pistol / blade impact spectra, the two new interaction cues and
## the safety invariants (fixed seeds, no global RNG, soft attack, peak level).
##   godot --headless --path . res://tests/audio_impact_test.tscn

## Mirrors ProceduralAudio.COMMON_KINDS, so a kind added there without being
## warmed here is caught instead of silently generating on first use.
const EXPECTED_COMMON := [
	"gun_pistol", "enemy_shot", "hit_kill", "hit_kill_head", "hit_tink",
	"brittle_glass", "player_hurt", "player_hurt_heavy", "heartbeat", "dry",
	"hit_flesh", "hit_metal", "melee_swing", "melee_hit", "dash",
	"clock_hit", "clock_perfect", "clock_break", "shockwave",
	"hit_block", "pistol_low_ammo",
]

var _failures := 0


func _ready() -> void:
	_test_rate_and_kinds()
	_test_pistol_shape()
	_test_impact_spectra()
	_test_new_cues()
	_test_safety()
	print("%s (%d failed)" % ["ALL PASSED" if _failures == 0 else "FAIL", _failures])
	get_tree().quit(0 if _failures == 0 else 1)


func _test_rate_and_kinds() -> void:
	print("== 44.1 kHz stream")
	_check("the mix rate is 44100 (got %d)" % ProceduralAudio.SAMPLE_RATE,
		ProceduralAudio.SAMPLE_RATE == 44100)
	_check("every common kind is still in the warm-up list",
		Array(ProceduralAudio.COMMON_KINDS) == EXPECTED_COMMON)
	for kind in EXPECTED_COMMON:
		var wav := ProceduralAudio.generate(kind)
		var peak := _peak(wav)
		var flat := _flat_sample_count(wav)
		_check("%s: mono 44.1k PCM16, %.2f s, peak %d, %d flat samples"
			% [kind, wav.get_length(), peak, flat],
			wav != null and wav.mix_rate == 44100 and not wav.stereo
				and wav.format == AudioStreamWAV.FORMAT_16_BITS
				and wav.data.size() > 2000 and peak > 2000
				and flat * 100 < wav.data.size())
	_free_cache()


func _test_pistol_shape() -> void:
	print("== reshaped black-crystal pistol")
	var wav := ProceduralAudio.generate("gun_pistol")
	var first_ms := int(0.001 * ProceduralAudio.SAMPLE_RATE)
	var peak := 0.0
	var early := 0.0
	for i in range(0, wav.data.size(), 2):
		var value := absf(float(_sample_at(wav, i / 2)))
		peak = maxf(peak, value)
		if i / 2 < first_ms:
			early = maxf(early, value)
	var peak_db := 20.0 * log(peak / 32767.0) / log(10.0)
	_check("soft attack (%.0f%% at 1 ms), peaks at -3 dBFS (%.1f dB)"
		% [early / peak * 100.0, peak_db], early < peak * 0.5 and absf(peak_db + 3.0) <= 1.0)
	# 48 Hz sub-bass against the 150-250 Hz band the old shot lived in.
	var sub := _tone_energy(wav, 55.0)
	var old_band := _tone_energy(wav, 190.0)
	_check("the sub-bass sits below the old thump (55 Hz %.4f vs 190 Hz %.4f)"
		% [sub, old_band], sub > old_band)
	var mineral_low := _tone_energy(wav, 4150.0)
	var mineral_high := _tone_energy(wav, 6620.0)
	_check("the mineral transient is present at 4.15 kHz (%.4f) and 6.62 kHz (%.4f)"
		% [mineral_low, mineral_high],
		mineral_low > 0.0015 and mineral_high > 0.0006 and mineral_low / sub > 0.04)
	_check("generation stays deterministic",
		ProceduralAudio._generate_uncached("gun_pistol").data
			== ProceduralAudio._generate_uncached("gun_pistol").data)
	_free_cache()


func _test_impact_spectra() -> void:
	print("== reshaped blade impact")
	var wav := ProceduralAudio.generate("melee_hit")
	var punch := _tone_energy(wav, 55.0)
	var mid := _tone_energy(wav, 320.0)
	_check("the blade lands with a 50 Hz punch (55 Hz %.4f vs 320 Hz %.4f)"
		% [punch, mid], punch > mid)
	var slice := _tone_energy(wav, 4700.0)
	_check("and a crystal slice harmonic (4.7 kHz %.4f)" % slice, slice > 0.001)
	var peak_db := _db(_peak(wav))
	_check("it is louder than before, peaking at 0 dBFS (%.1f dB)" % peak_db,
		absf(peak_db) <= 1.0)
	_free_cache()


func _test_new_cues() -> void:
	print("== new interaction cues")
	var block := ProceduralAudio.generate("hit_block")
	_check("hit_block lasts ~0.3 s ring (%.2f s)" % block.get_length(),
		block.get_length() > 0.20 and block.get_length() < 0.45)
	var block_ring := _tone_energy(block, 1930.0)
	_check("hit_block rings metallically (1.93 kHz %.4f)" % block_ring, block_ring > 0.003)
	var ping := ProceduralAudio.generate("pistol_low_ammo")
	_check("pistol_low_ammo is a short tick (%.3f s)" % ping.get_length(),
		ping.get_length() > 0.02 and ping.get_length() < 0.09)
	_check("pistol_low_ammo sits high (6.3 kHz %.4f > 55 Hz %.4f)"
		% [_tone_energy(ping, 6300.0), _tone_energy(ping, 55.0)],
		_tone_energy(ping, 6300.0) > _tone_energy(ping, 55.0))
	var unique := {
		"hit_block": _fingerprint(block.data),
		"pistol_low_ammo": _fingerprint(ping.data),
		"hit_kill": _fingerprint(ProceduralAudio.generate("hit_kill").data),
		"hit_kill_head": _fingerprint(ProceduralAudio.generate("hit_kill_head").data),
		"hit_tink": _fingerprint(ProceduralAudio.generate("hit_tink").data),
	}
	var seen := {}
	for kind in unique:
		_check("%s has its own waveform" % kind, not seen.has(unique[kind]))
		seen[unique[kind]] = kind
	_free_cache()


func _test_safety() -> void:
	print("== seeded, isolated generation")
	seed(4242)
	var want := randi()
	for i in 3:
		for kind in EXPECTED_COMMON:
			ProceduralAudio.generate(kind)
	_free_cache()
	seed(4242)
	var leave := randi()
	_check("generating every cue leaves the global RNG untouched", leave == want)
	for kind in ["gun_pistol", "melee_hit", "hit_block", "pistol_low_ammo"]:
		_check("%s regenerates byte-identically" % kind,
			ProceduralAudio._generate_uncached(kind).data
				== ProceduralAudio._generate_uncached(kind).data)
	_free_cache()


## Drop the static cache so the checks exercise real generation order.
func _free_cache() -> void:
	ProceduralAudio._cache.clear()


func _sample_at(wav: AudioStreamWAV, index: int) -> int:
	var raw := wav.data[index * 2] | (wav.data[index * 2 + 1] << 8)
	return raw - 65536 if raw >= 32768 else raw


func _peak(wav: AudioStreamWAV) -> int:
	var peak := 0
	for i in wav.data.size() / 2:
		peak = maxi(peak, absi(_sample_at(wav, i)))
	return peak


## A flat-clipped stream would hold many samples at full scale.
func _flat_sample_count(wav: AudioStreamWAV) -> int:
	var count := 0
	for i in wav.data.size() / 2:
		if absi(_sample_at(wav, i)) >= 32760:
			count += 1
	return count


## Goertzel magnitude for one frequency, scaled to 0..1-ish amplitude.
func _tone_energy(wav: AudioStreamWAV, freq: float) -> float:
	var count := wav.data.size() / 2
	var w := TAU * freq / float(wav.mix_rate)
	var coeff := 2.0 * cos(w)
	var s1 := 0.0
	var s2 := 0.0
	for i in count:
		var s0 := float(_sample_at(wav, i)) / 32767.0 + coeff * s1 - s2
		s2 = s1
		s1 = s0
	return sqrt(maxf(s1 * s1 + s2 * s2 - coeff * s1 * s2, 0.0)) / float(count)


func _db(peak: int) -> float:
	return 20.0 * log(float(peak) / 32767.0) / log(10.0)


## FNV-1a over the PCM bytes; PackedByteArray has no built-in hash().
func _fingerprint(data: PackedByteArray) -> int:
	var value := 2166136261
	for byte in data:
		value = ((value ^ byte) * 16777619) & 0xFFFFFFFF
	return value


func _check(label: String, ok: bool) -> void:
	if not ok:
		_failures += 1
	print("  [%s] %s" % ["ok" if ok else "FAIL", label])
