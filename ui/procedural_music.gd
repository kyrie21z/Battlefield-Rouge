class_name ProceduralMusic
extends RefCounted
## Original, license-free background music synthesised at runtime: three
## seamless D-minor loops for the clockwork city ("停摆之钟").
##  - calm   84 BPM: slow pad, sparse bells and a tick-tock that stalls at the
##    end of every fourth bar,
##  - combat 128 BPM: kick, clock ticks, a driving bass, a plucked arpeggio and
##    a short minor motif,
##  - boss   140 BPM: four-on-the-floor, 16th ticks, a pumping bass, low stabs
##    and a phrygian Dm-Eb turn.
## Mono 16-bit at SAMPLE_RATE, LOOP_FORWARD over the whole buffer, normalised to
## PEAK_DB. Every note is rendered once and mixed in; tails that run past the
## end wrap around to the start, so the loop point is seamless. Only a private
## RandomNumberGenerator with a fixed seed is used (never the global RNG), so
## the same track is the same bytes on every call and never touches a run.

const SAMPLE_RATE := 22050
const PEAK_DB := -6.0
const TRACKS: Array[String] = ["calm", "combat", "boss"]
const BPM := {"calm": 84.0, "combat": 128.0, "boss": 140.0}
const BARS := 8
const BEATS_PER_BAR := 4

const _TABLE_SIZE := 2048
const _TABLE_MASK := 2047

## Chords as MIDI voicings for the pad and the bass root (one per bar).
const _CHORDS := {
	"Dm": {"pad": [50, 57, 62, 65], "root": 38, "tones": [62, 65, 69]},
	"Bb": {"pad": [46, 53, 58, 62], "root": 34, "tones": [58, 62, 65]},
	"Gm": {"pad": [43, 50, 55, 58], "root": 31, "tones": [55, 58, 62]},
	"A": {"pad": [45, 52, 57, 61], "root": 33, "tones": [57, 61, 64]},
	"Eb": {"pad": [51, 55, 58, 63], "root": 39, "tones": [63, 67, 70]},
}

static var _cache := {}
static var _mutex := Mutex.new()
static var _task_id := -1
static var _joined := false
static var _sine := PackedFloat32Array()
static var _saw := PackedFloat32Array()


## The track, generated on first use and cached. Thread-safe.
static func generate(track: String) -> AudioStreamWAV:
	_mutex.lock()
	var cached: AudioStreamWAV = _cache.get(track)
	_mutex.unlock()
	if cached != null:
		return cached
	var wav := _render(track)
	_mutex.lock()
	if not _cache.has(track):
		_cache[track] = wav
	wav = _cache[track]
	_mutex.unlock()
	return wav


## The cached track, or null while it is still being generated.
static func cached(track: String) -> AudioStreamWAV:
	_mutex.lock()
	var wav: AudioStreamWAV = _cache.get(track)
	_mutex.unlock()
	return wav


## Starts generating every track (calm first) on a worker thread, once per
## launch. Generation takes a few seconds, so playback never waits on the
## main thread; the director starts each track when cached() has it.
static func request_all() -> void:
	if _task_id >= 0:
		return
	_task_id = WorkerThreadPool.add_task(_generate_all, false, "ProceduralMusic")


## Joins the worker task once it is no longer needed (the director leaving the
## tree); only blocks if generation is somehow still running.
static func finish_requests() -> void:
	if _task_id >= 0 and not _joined:
		WorkerThreadPool.wait_for_task_completion(_task_id)
		_joined = true


static func _generate_all() -> void:
	for track in TRACKS:
		generate(track)


static func samples_for(track: String) -> int:
	return int(round(BARS * BEATS_PER_BAR * 60.0 / float(BPM[track]) * SAMPLE_RATE))


static func _render(track: String) -> AudioStreamWAV:
	_build_tables()
	var buf := PackedFloat32Array()
	buf.resize(samples_for(track))
	var rng := RandomNumberGenerator.new()
	rng.seed = {"calm": 0x6A11, "combat": 0x6A12, "boss": 0x6A13}[track]
	match track:
		"calm":
			_compose_calm(buf, rng)
		"combat":
			_compose_combat(buf, rng)
		"boss":
			_compose_boss(buf, rng)
	return _to_wav(buf)


# --- arrangements -------------------------------------------------------------

static func _compose_calm(buf: PackedFloat32Array, rng: RandomNumberGenerator) -> void:
	var beat := 60.0 / BPM["calm"] * SAMPLE_RATE
	var bar := beat * BEATS_PER_BAR
	var progression := ["Dm", "Bb", "Gm", "A", "Dm", "Bb", "Gm", "A"]
	var notes := {}
	for b in BARS:
		var chord: Dictionary = _CHORDS[progression[b]]
		for m: int in chord["pad"]:
			_mix(buf, _note(notes, "pad", m, bar / SAMPLE_RATE, rng, 0.9, 1.2), int(b * bar), 0.16)
		_mix(buf, _note(notes, "bass", chord["root"] + 12, bar / SAMPLE_RATE * 0.9, rng), int(b * bar), 0.22)
	# Bells: a sparse, falling D-minor line, [beat, midi].
	var melody := [[0, 74], [3, 69], [6, 70], [7, 69], [8, 67], [10, 70], [12, 73], [14, 69],
		[16, 74], [18, 77], [19, 76], [22, 74], [24, 70], [26, 67], [28, 69], [30, 73]]
	for n in melody:
		_mix(buf, _note(notes, "bell", n[1], 2.2, rng), int(n[0] * beat), 0.20)
	# The clock: tick on odd beats, tock on even ones; it stalls on the last beat
	# of bars 4 and 8.
	for i in BARS * BEATS_PER_BAR:
		if i % 16 == 15:
			continue
		var kind := "tick" if i % 2 == 0 else "tock"
		_mix(buf, _note(notes, kind, 0, 0.0, rng), int(i * beat), 0.16)


static func _compose_combat(buf: PackedFloat32Array, rng: RandomNumberGenerator) -> void:
	var step := 60.0 / BPM["combat"] / 4.0 * SAMPLE_RATE
	var bar := step * 16.0
	var progression := ["Dm", "Bb", "Gm", "A", "Dm", "Bb", "Gm", "A"]
	var bass_offsets := [0, 0, 12, 0, 0, 12, 7, 0]
	var notes := {}
	for b in BARS:
		var chord: Dictionary = _CHORDS[progression[b]]
		var at := b * bar
		for m: int in chord["pad"]:
			_mix(buf, _note(notes, "pad", m, bar / SAMPLE_RATE, rng, 0.25, 0.4), int(at), 0.07)
		for s in [0, 6, 8] + ([14] if b % 4 == 3 else []):
			_mix(buf, _note(notes, "kick", 0, 0.0, rng), int(at + s * step), 0.75)
		for s in [4, 12]:
			_mix(buf, _note(notes, "clank", 0, 0.0, rng), int(at + s * step), 0.32)
		for s in 16:
			if s % 2 == 0:
				_mix(buf, _note(notes, "tick", 0, 0.0, rng), int(at + s * step), 0.10 if s % 4 == 0 else 0.16)
			elif b >= 4:
				_mix(buf, _note(notes, "tick", 0, 0.0, rng), int(at + s * step), 0.06)
		for e in 8:
			var m: int = chord["root"] + bass_offsets[e]
			_mix(buf, _note(notes, "bass", m, step * 2.0 / SAMPLE_RATE * 0.95, rng), int(at + e * 2 * step), 0.42)
		var tones: Array = chord["tones"]
		for e in 8:
			var m: int = tones[[0, 1, 2, 1, 0, 2, 1, 2][e]] + 12
			_mix(buf, _note(notes, "pluck", m, 0.0, rng), int(at + e * 2 * step + step), 0.16)
	# The motif on the first and the fifth bar, answered on the third and seventh.
	var motif := {0: [[0, 74], [3, 77], [4, 76], [6, 74], [10, 69]],
		2: [[0, 70], [3, 74], [4, 72], [6, 70]],
		3: [[0, 73], [4, 76], [8, 73]]}
	for b in BARS:
		if not motif.has(b % 4):
			continue
		for n in motif[b % 4]:
			_mix(buf, _note(notes, "bell", n[1] - 12, 0.9, rng), int(b * bar + n[0] * step), 0.18)


static func _compose_boss(buf: PackedFloat32Array, rng: RandomNumberGenerator) -> void:
	var step := 60.0 / BPM["boss"] / 4.0 * SAMPLE_RATE
	var bar := step * 16.0
	var progression := ["Dm", "Eb", "Dm", "Eb", "Gm", "A", "Bb", "A"]
	var notes := {}
	for b in BARS:
		var chord: Dictionary = _CHORDS[progression[b]]
		var at := b * bar
		for m: int in chord["pad"]:
			_mix(buf, _note(notes, "pad", m - 12, bar / SAMPLE_RATE, rng, 0.15, 0.3), int(at), 0.08)
			_mix(buf, _note(notes, "stab", m, bar / SAMPLE_RATE * 0.22, rng), int(at), 0.11)
			_mix(buf, _note(notes, "stab", m, bar / SAMPLE_RATE * 0.12, rng), int(at + 10 * step), 0.08)
		for s in [0, 4, 8, 10, 12]:
			_mix(buf, _note(notes, "kick", 0, 0.0, rng), int(at + s * step), 0.8)
		for s in [4, 12] + ([14, 15] if b % 2 == 1 else []):
			_mix(buf, _note(notes, "clank", 0, 0.0, rng), int(at + s * step), 0.38 if s < 13 else 0.22)
		for s in 16:
			_mix(buf, _note(notes, "tick", 0, 0.0, rng), int(at + s * step), 0.14 if s % 2 == 1 else 0.08)
		for s in 16:
			var m: int = chord["root"] + (12 if s % 8 == 7 else 0)
			_mix(buf, _note(notes, "bass", m, step / SAMPLE_RATE * 0.9, rng), int(at + s * step),
				0.42 if s % 4 == 0 else 0.3)
		_mix(buf, _note(notes, "bell", chord["root"] + 24, 2.4, rng), int(at), 0.2)


# --- instruments --------------------------------------------------------------

## One rendered note, cached per arrangement by instrument, pitch and length.
static func _note(cache: Dictionary, kind: String, midi: int, length: float,
		rng: RandomNumberGenerator, attack := 0.02, release := 0.1) -> PackedFloat32Array:
	var key := "%s:%d:%.3f:%.2f" % [kind, midi, length, attack]
	if cache.has(key):
		return cache[key]
	var out: PackedFloat32Array
	match kind:
		"pad":
			out = _pad(_freq(midi), length, attack, release)
		"stab":
			out = _pad(_freq(midi), length, 0.008, 0.08)
		"bass":
			out = _bass(_freq(midi), length)
		"bell":
			out = _bell(_freq(midi), length)
		"pluck":
			out = _pluck(_freq(midi), 0.45, rng)
		"kick":
			out = _kick()
		"tick":
			out = _tick(0.035, 0.55, 260.0, 2600.0, rng)
		"tock":
			out = _tick(0.06, 0.22, 110.0, 900.0, rng)
		"clank":
			out = _clank(rng)
	cache[key] = out
	return out


static func _pad(freq: float, length: float, attack: float, release: float) -> PackedFloat32Array:
	var count := int((length + release) * SAMPLE_RATE)
	var hold := int(length * SAMPLE_RATE)
	var att := maxi(1, int(attack * SAMPLE_RATE))
	var rel := maxi(1, count - hold)
	var out := PackedFloat32Array()
	out.resize(count)
	var inc_a := freq * _TABLE_SIZE / SAMPLE_RATE * 1.004
	var inc_b := freq * _TABLE_SIZE / SAMPLE_RATE * 0.996
	var pa := 0.0
	var pb := 517.0
	for i in count:
		var env := 1.0
		if i < att:
			env = float(i) / att
		elif i >= hold:
			env = 1.0 - float(i - hold) / rel
		out[i] = (_saw[int(pa) & _TABLE_MASK] + _saw[int(pb) & _TABLE_MASK]) * 0.5 * env
		pa += inc_a
		pb += inc_b
	return out


static func _bass(freq: float, length: float) -> PackedFloat32Array:
	var count := int((length + 0.03) * SAMPLE_RATE)
	var out := PackedFloat32Array()
	out.resize(count)
	var inc := freq * _TABLE_SIZE / SAMPLE_RATE
	var phase := 0.0
	var env := 1.0
	var decay := exp(-3.0 / (length * SAMPLE_RATE))
	var att := int(0.004 * SAMPLE_RATE)
	var end := int(length * SAMPLE_RATE)
	for i in count:
		var a := minf(1.0, float(i) / att)
		if i > end:
			a *= maxf(0.0, 1.0 - float(i - end) / (0.03 * SAMPLE_RATE))
		var s := _sine[int(phase) & _TABLE_MASK]
		var s2 := _sine[int(phase * 2.0) & _TABLE_MASK]
		out[i] = (s * 0.8 + s2 * 0.3 + _saw[int(phase) & _TABLE_MASK] * 0.15) * env * a
		phase += inc
		env *= decay
	return out


static func _bell(freq: float, length: float) -> PackedFloat32Array:
	var count := int(length * SAMPLE_RATE)
	var out := PackedFloat32Array()
	out.resize(count)
	var partials := [[1.0, 1.0, 2.2], [2.76, 0.45, 4.5], [5.4, 0.22, 8.0], [0.5, 0.25, 1.6]]
	for p in partials:
		var inc: float = freq * p[0] * _TABLE_SIZE / SAMPLE_RATE
		var env: float = p[1]
		var decay := exp(-float(p[2]) / SAMPLE_RATE)
		var phase := 0.0
		for i in count:
			out[i] += _sine[int(phase) & _TABLE_MASK] * env
			phase += inc
			env *= decay
	var att := int(0.003 * SAMPLE_RATE)
	for i in att:
		out[i] *= float(i) / att
	var fade := int(0.05 * SAMPLE_RATE)
	for i in fade:
		out[count - 1 - i] *= float(i) / fade
	return out


## Karplus-Strong: a noise burst through a damped delay line.
static func _pluck(freq: float, length: float, rng: RandomNumberGenerator) -> PackedFloat32Array:
	var count := int(length * SAMPLE_RATE)
	var period := maxi(2, int(SAMPLE_RATE / freq))
	var line := PackedFloat32Array()
	line.resize(period)
	for i in period:
		line[i] = rng.randf_range(-1.0, 1.0)
	var out := PackedFloat32Array()
	out.resize(count)
	var idx := 0
	for i in count:
		var nxt := (idx + 1) % period
		var v := (line[idx] + line[nxt]) * 0.497
		out[i] = line[idx]
		line[idx] = v
		idx = nxt
	var fade := int(0.04 * SAMPLE_RATE)
	for i in fade:
		out[count - 1 - i] *= float(i) / fade
	return out


static func _kick() -> PackedFloat32Array:
	var count := int(0.32 * SAMPLE_RATE)
	var out := PackedFloat32Array()
	out.resize(count)
	var phase := 0.0
	for i in count:
		var t := float(i) / SAMPLE_RATE
		var f := 45.0 + 95.0 * exp(-t * 28.0)
		phase += f * _TABLE_SIZE / SAMPLE_RATE
		var env := exp(-t * 11.0) * minf(1.0, t / 0.002)
		out[i] = _sine[int(phase) & _TABLE_MASK] * env
	return out


## A clock tick: high-passed noise with a short resonant ping.
static func _tick(length: float, noise: float, decay_hz: float, ping: float,
		rng: RandomNumberGenerator) -> PackedFloat32Array:
	var count := int(length * SAMPLE_RATE)
	var out := PackedFloat32Array()
	out.resize(count)
	var last := 0.0
	var inc := ping * _TABLE_SIZE / SAMPLE_RATE
	var phase := 0.0
	for i in count:
		var t := float(i) / SAMPLE_RATE
		var w := rng.randf_range(-1.0, 1.0)
		var hp := w - last
		last = w
		out[i] = (hp * noise + _sine[int(phase) & _TABLE_MASK] * 0.6) * exp(-t * decay_hz)
		phase += inc
	return out


## A metallic backbeat: noise and two inharmonic partials.
static func _clank(rng: RandomNumberGenerator) -> PackedFloat32Array:
	var count := int(0.22 * SAMPLE_RATE)
	var out := PackedFloat32Array()
	out.resize(count)
	var lp := 0.0
	var pa := 0.0
	var pb := 0.0
	for i in count:
		var t := float(i) / SAMPLE_RATE
		lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.45
		var tone := _sine[int(pa) & _TABLE_MASK] * 0.5 + _sine[int(pb) & _TABLE_MASK] * 0.3
		out[i] = (lp * exp(-t * 22.0) + tone * exp(-t * 30.0)) * minf(1.0, t / 0.001)
		pa += 185.0 * _TABLE_SIZE / SAMPLE_RATE
		pb += 431.0 * _TABLE_SIZE / SAMPLE_RATE
	return out


# --- plumbing -----------------------------------------------------------------

static func _freq(midi: int) -> float:
	return 440.0 * pow(2.0, (midi - 69) / 12.0)


static func _build_tables() -> void:
	_mutex.lock()
	if _sine.is_empty():
		var sine := PackedFloat32Array()
		var saw := PackedFloat32Array()
		sine.resize(_TABLE_SIZE)
		saw.resize(_TABLE_SIZE)
		for i in _TABLE_SIZE:
			var x := TAU * i / _TABLE_SIZE
			sine[i] = sin(x)
			# A soft, dark saw: eight harmonics rolled off faster than 1/n.
			var v := 0.0
			for h in range(1, 9):
				v += sin(x * h) / pow(h, 1.4)
			saw[i] = v * 0.6
		_saw = saw
		_sine = sine
	_mutex.unlock()


## Adds `note` into `buf` from `start`, wrapping past the end to the start.
static func _mix(buf: PackedFloat32Array, note: PackedFloat32Array, start: int, gain: float) -> void:
	var n := buf.size()
	start = posmod(start, n)
	var first := mini(note.size(), n - start)
	for j in first:
		buf[start + j] += note[j] * gain
	var k := 0
	for j in range(first, note.size()):
		buf[k] += note[j] * gain
		k += 1
		if k >= n:
			k = 0


static func _to_wav(buf: PackedFloat32Array) -> AudioStreamWAV:
	var peak := 0.0
	for v in buf:
		peak = maxf(peak, absf(v))
	var scale := db_to_linear(PEAK_DB) / peak if peak > 0.0 else 0.0
	var data := PackedByteArray()
	data.resize(buf.size() * 2)
	for i in buf.size():
		data.encode_s16(i * 2, int(clampf(buf[i] * scale, -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = data
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = buf.size()
	return stream
