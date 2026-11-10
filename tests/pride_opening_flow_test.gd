extends SceneTree
## Compatibility entry for the replaced popup-flow regression command.
## The new production sequence owns its real Player, audio and walking gate test.
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	change_scene_to_file("res://tests/opening_sequence_test.tscn")
