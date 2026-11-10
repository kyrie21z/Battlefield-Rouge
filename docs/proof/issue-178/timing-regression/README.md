# Last-piercer reward-pause timing regression

Classification: shared project verification evidence. All logs are copied byte-for-byte from Godot 4.7.2 headless runs. Baseline commit: `2cea4f0ac595e77458196e9939bbb52ec55df680`. No enemy or Stage gameplay code was changed; the fixed-owner full-suite tree was left untouched.

## Original failure

The probe instantiates the real Wrath room, kills all but its PIERCER through Health, adds a deterministic WORLD wall, and starts the surviving actor's real attack. Normal engine physics produces the wall collision and self-death; Stage creates the actual paused BoonPicker. A real reward card button accepts the selection. The probe never writes wall_detonations/cue_counts or manually runs the audio director.

Before the fix, physical frame51/process74/t16700ms had one detonation and real death but zero heavy cues. The actual reward pause retained zero. A real card choice resumed play at process75/t21046ms, and only process77/t21154ms dispatched the impact: about4.45seconds after the collision. The decisive failure is the 0/0/1 cue count across pause/held/resumed states, not the cold UI construction time. See `before-diagnostic.log`.

## Repair and evidence

WrathAudioDirector now listens to existing `stage.enemy_defeated`, which is emitted synchronously before Stage's deferred reward pause. This handler and the original process poll use one consume helper: read the actor's real detonation delta, acknowledge it in the same dictionary, and route through unchanged play_cue pause/stop guards. Dynamic actors already registered by Stage use the same event. Ordinary enemy deaths with no detonation produce no cue.

The unchanged probe reports 1/1/1 after the fix, with one cue already present during the real death callback; there is no replay after the real card choice. See `after-diagnostic.log`. This verifies dispatch timing, not audio-device playback latency.

The production `wrath_audio_test` preserves all original34 checks and adds6 checks using the same last-enemy/death/picker/card path. It asserts one cue at the synchronous death and stage-cleared callbacks before pause, one while paused, and still one after four resumed process frames. Final result:40/40. The original `wrath_realm_test` remains28/28. Both exit0; all three fixed-run raw logs contain no ERROR/WARNING. Original failure evidence is retained unchanged.

The archived probe source uses `.txt` to avoid runtime resource/UID registration. In an isolated imported checkout, copy the two probe files into matching `tests/wrath_last_piercer_diagnostic.gd` and `.tscn` paths, then run `godot --headless --path . res://tests/wrath_last_piercer_diagnostic.tscn`. For the assertions, run `res://tests/wrath_audio_test.tscn`; no temporary probe is required. Tested production/test source hashes are recorded in `results.json`.
