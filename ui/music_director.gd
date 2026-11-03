class_name MusicDirector
extends Node
## Background music for a zone. The HUD creates one (not under fixtures or
## headless runs) and it reads the zone director it is given:
##  - CLEAR_GUARDS, or HAMMER_POINT while enemies are alive → "combat",
##  - BOSS_STANDING, or anything in the boss zone while the boss lives → "boss",
##  - otherwise "calm", but only after MIN_CALM seconds without combat, so a
##    lull between reinforcement waves does not flip the music back and forth.
## Tracks crossfade over CROSSFADE seconds between two players on the Music bus.
## BUFF_SELECT and the pause menu duck by DUCK_DB; death and victory fade out.
## Each track resumes where it left off when the next zone's HUD starts it, so
## a zone change does not restart the same loop from bar one.
## It runs while the tree is paused (buff screen, pause menu).

const BUS := &"Music"
const BASE_DB := -7.0
const CROSSFADE := 1.5
const MIN_CALM := 6.0
const DUCK_DB := -6.0
const DUCK_TIME := 0.4
const FADE_OUT := 2.0

## Tests set this to run the director in a headless run.
static var allow_headless := false
static var _resume := {}

var _director: ZoneDirector
var _players: Array[AudioStreamPlayer] = []
var _tracks: Array[String] = ["", ""]
var _gains: Array[float] = [0.0, 0.0]
var _active := 0
var _calm_for := 0.0
var _duck := 1.0
var _ending := false
var _end_gain := 1.0
var _wanted := ""


static func enabled() -> bool:
	return allow_headless or (DisplayServer.get_name() != "headless" and RunState.fixture == null)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 2:
		var player := AudioStreamPlayer.new()
		player.bus = BUS if AudioServer.get_bus_index(BUS) >= 0 else &"Master"
		player.volume_db = -80.0
		add_child(player)
		_players.append(player)
	Events.player_died.connect(fade_out)
	Events.run_won.connect(fade_out)
	ProceduralMusic.request_all()


func setup(director: ZoneDirector) -> void:
	_director = director


func _exit_tree() -> void:
	ProceduralMusic.finish_requests()


func _process(delta: float) -> void:
	if _director == null or not is_instance_valid(_director):
		return
	var want := desired_track(_director)
	var ducked := _director.phase == ZoneDirector.Phase.BUFF_SELECT or get_tree().paused
	step(delta, want, ducked)


## What the zone wants right now, before the calm hysteresis.
static func desired_track(director: ZoneDirector) -> String:
	if director.is_boss_zone and director.boss != null and is_instance_valid(director.boss) \
			and not director.boss.health.is_dead():
		return "boss"
	match director.phase:
		ZoneDirector.Phase.BOSS_STANDING:
			return "boss"
		ZoneDirector.Phase.CLEAR_GUARDS:
			return "combat"
		ZoneDirector.Phase.HAMMER_POINT:
			return "combat" if not director.living_enemies().is_empty() else "calm"
	return "calm"


## Advances the music by `delta` seconds towards `want`. Public for the tests.
func step(delta: float, want: String, ducked: bool) -> void:
	var current := current_track()
	if want == "calm" and current != "" and current != "calm":
		_calm_for += delta
		if _calm_for < MIN_CALM:
			want = current
	else:
		_calm_for = 0.0
	_wanted = want
	if want != _tracks[_active]:
		_switch_to(want)
	var fade := delta / CROSSFADE
	for i in 2:
		var target := 1.0 if i == _active and _players[i].playing else 0.0
		_gains[i] = move_toward(_gains[i], target, fade)
		if _gains[i] <= 0.0 and i != _active and _players[i].playing:
			_resume[_tracks[i]] = _players[i].get_playback_position()
			_players[i].stop()
	_duck = move_toward(_duck, db_to_linear(DUCK_DB) if ducked else 1.0, delta / DUCK_TIME)
	if _ending:
		_end_gain = move_toward(_end_gain, 0.0, delta / FADE_OUT)
	for i in 2:
		if _players[i].playing:
			_resume[_tracks[i]] = _players[i].get_playback_position()
		var linear := _gains[i] * _duck * _end_gain
		_players[i].volume_db = BASE_DB + linear_to_db(linear) if linear > 0.0001 else -80.0


## The track that is (or is about to start) playing in front, "" before any.
func current_track() -> String:
	return _tracks[_active]


func is_playing() -> bool:
	return _players[_active].playing


## The level the front track is heading to, in dB, for the tests.
func target_volume_db() -> float:
	var linear := (db_to_linear(DUCK_DB) if _duck < 1.0 else 1.0) * (0.0 if _ending else 1.0)
	return BASE_DB + linear_to_db(linear) if linear > 0.0 else -80.0


func front_gain() -> float:
	return _gains[_active] * _duck * _end_gain


func fade_out() -> void:
	_ending = true


func _switch_to(track: String) -> void:
	var stream := ProceduralMusic.cached(track)
	if stream == null:
		return  # Still generating; try again next frame.
	var other := 1 - _active
	if _tracks[other] == track and _players[other].playing:
		_active = other
		return
	if _players[other].playing:
		_resume[_tracks[other]] = _players[other].get_playback_position()
		_players[other].stop()
	_players[other].stream = stream
	_tracks[other] = track
	_gains[other] = 0.0
	var from: float = _resume.get(track, 0.0)
	_players[other].play(fmod(from, stream.get_length()))
	_active = other
