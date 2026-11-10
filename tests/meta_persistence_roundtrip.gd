extends Node
const PROFILE := "user://meta_152_process_roundtrip.json"

func _ready() -> void:
	var writing := OS.get_cmdline_user_args().has("--write")
	if writing:
		cleanup()
	var store := MetaProgressionStore.new()
	store.override_path = PROFILE
	add_child(store)
	var passed := false
	if writing:
		passed = store.settle_run("separate-process",137,4) and store.purchase("resolve")
		print("META PROCESS WRITE: %s wallet=%d/%d rank=%d" % ["PASS" if passed else "FAIL",store.will_shards,store.reality_anchors,store.level("resolve")])
	else:
		passed = store.load_status=="loaded" and store.will_shards==117 and store.reality_anchors==4 and store.level("resolve")==1 and not store.settle_run("separate-process",137,4)
		print("META PROCESS READ: %s wallet=%d/%d rank=%d ledger=%d" % ["PASS" if passed else "FAIL",store.will_shards,store.reality_anchors,store.level("resolve"),store.settled_runs.size()])
		cleanup()
	store.queue_free()
	await get_tree().process_frame
	get_tree().quit(0 if passed else 1)

func cleanup() -> void:
	for suffix in ["",".tmp",".bak"]:
		if FileAccess.file_exists(PROFILE+suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(PROFILE+suffix))
