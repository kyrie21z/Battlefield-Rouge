extends SceneTree
## Writes 10-second excerpts of each track and prints their stats for
## docs/proof/bgm/README.md:
##   godot --headless --path . --script tests/music_proof.gd

func _init() -> void:
	for track in ProceduralMusic.TRACKS:
		var t0 := Time.get_ticks_msec()
		var wav := ProceduralMusic._render(track)
		var ms := Time.get_ticks_msec() - t0
		var count := wav.data.size() / 2
		var peak := 0
		var sq := 0.0
		for i in count:
			var v := wav.data.decode_s16(i * 2)
			peak = maxi(peak, absi(v))
			sq += float(v) * v
		print("| %s | %d | %d | %.2f | %.2f | %.2f | %d |" % [track, ProceduralMusic.BPM[track],
			ProceduralMusic.BARS, wav.get_length(), linear_to_db(peak / 32767.0),
			linear_to_db(sqrt(sq / count) / 32767.0), ms])
		var excerpt := AudioStreamWAV.new()
		excerpt.format = wav.format
		excerpt.mix_rate = wav.mix_rate
		excerpt.data = wav.data.slice(0, mini(wav.data.size(), 10 * ProceduralMusic.SAMPLE_RATE * 2))
		excerpt.save_to_wav("res://docs/proof/bgm/%s_10s.wav" % track)
	quit()
