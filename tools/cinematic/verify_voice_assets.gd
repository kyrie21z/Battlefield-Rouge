extends SceneTree
## Run after Godot import. Use -- --issue=147 for an individual PR prefix.
var failed := 0
var checks := 0
var finished_count := 0
var sources: Array[AudioStreamPlayer] = []

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var file := FileAccess.open("res://tools/cinematic/voice_assets_manifest.json",FileAccess.READ)
	var manifest: Dictionary = JSON.parse_string(file.get_as_text())
	file.close()
	var selected_issue := 0
	for argument in OS.get_cmdline_user_args():
		if not argument.begins_with("--issue="):
			push_error("Unknown verification argument: " + argument)
			quit(2)
			return
		var value := argument.trim_prefix("--issue=")
		if value not in ["147","148","149","150"] or selected_issue != 0:
			push_error("Use one --issue=147, --issue=148, --issue=149 or --issue=150")
			quit(2)
			return
		selected_issue = int(value)
	var clips: Array = manifest.clips.filter(func(entry:Dictionary):return selected_issue == 0 or int(entry.issue) == selected_issue)
	if clips.is_empty():
		push_error("No voice clips match the requested issue")
		quit(2)
		return
	var expected := clips.size()
	print("VOICE SCOPE: %s, %d clips" % ["all" if selected_issue == 0 else "issue %d" % selected_issue,expected])
	var longest := 0.0
	for entry: Dictionary in clips:
		var path: String = "res://" + String(entry.path)
		var stream := load(path) as AudioStreamWAV
		_check("imported 24 kHz mono " + path,stream != null and stream.mix_rate == 24000 and not stream.stereo)
		if stream == null:
			continue
		_check("duration " + path,absf(stream.get_length()-float(entry.duration_seconds)) < 0.001)
		var source := AudioStreamPlayer.new()
		source.volume_db = -80 # Decoder lifecycle probe; no simultaneous audible mix.
		source.stream = stream
		source.finished.connect(func():finished_count += 1)
		root.add_child(source)
		sources.append(source)
		source.play()
		longest = maxf(longest,stream.get_length())
	await create_timer(0.5).timeout
	_check("all %d actual audio streams advance" % expected,sources.size() == expected and sources.all(func(source:AudioStreamPlayer):return source.playing and source.get_playback_position() > 0.05))
	await create_timer(longest+1.0).timeout
	_check("all %d decoded streams emit finished once" % expected,finished_count == expected)
	for source in sources:
		source.queue_free()
	sources.clear()
	await process_frame
	print("KOKORO VOICE ASSETS: %d checks, %d failed" % [checks,failed])
	quit(0 if failed == 0 else 1)

func _check(label:String, ok:bool) -> void:
	checks += 1
	failed += 0 if ok else 1
	print("%s %s" % ["PASS" if ok else "FAIL",label])
