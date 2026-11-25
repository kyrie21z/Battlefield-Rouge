extends Node
## Starts the real campaign on its Fear-first diagnostic route.

func _ready() -> void:
	_enter_castle.call_deferred()


func _enter_castle() -> void:
	if not MetaProgression.isolated_profile:
		push_error("Fear Castle playtest needs its separate preview profile.")
		get_tree().quit(1)
		return
	RunDirector.randomize_realm_order = false
	if not RunDirector.begin_run(-1, false):
		push_error("Fear Castle playtest could not start a run.")
		get_tree().quit(1)
		return
	var path: String = RunDirector.scene_path()
	if RunDirector.install_stage(load(path) as PackedScene) != OK:
		push_error("Fear Castle playtest could not load " + path)
		get_tree().quit(1)
		return
	print("FEAR CASTLE PLAYTEST: %s | order %s | isolated save %s" %
		[path, RunDirector.order, MetaProgression.isolated_profile])
