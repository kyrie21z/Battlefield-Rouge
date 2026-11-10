extends Node3D
## Independent demo profile; never changes the real progression file.
var store: MetaProgressionStore
var player: Player
var forge: CrownForge
var profile: String

func _ready() -> void:
	profile = "user://meta_forge_demo_%d.json" % OS.get_process_id()
	store = MetaProgressionStore.new()
	store.override_path = profile
	add_child(store)
	store.settle_run("demo-funding",1200,30)
	player = preload("res://actors/player/player.tscn").instantiate()
	add_child(player)
	player.set_physics_process(false)
	store.begin_run("demo-run")
	forge = preload("res://ui/meta_forge/crown_forge.tscn").instantiate()
	add_child(forge)
	forge.setup(store,player)
	forge.closed.connect(func():get_tree().quit())

func _exit_tree() -> void:
	for suffix in ["",".bak",".tmp"]:
		if FileAccess.file_exists(profile+suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(profile+suffix))
