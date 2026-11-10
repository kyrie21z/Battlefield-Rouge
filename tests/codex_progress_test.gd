extends Node
var checks := 0
var failures := 0
var profile := ""
func check(title: String,value: bool) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("FAIL: "+title)
func _ready() -> void:
	profile = "user://meta_test_codex_%d.json" % OS.get_process_id()
	var store := MetaProgressionStore.new()
	store.override_path = profile
	add_child(store)
	var legacy := store._payload()
	legacy.erase("discovered_boons")
	var file := FileAccess.open(profile,FileAccess.WRITE)
	file.store_string(JSON.stringify({"payload":legacy,"checksum":store._checksum(legacy)}))
	file.close()
	check("v1 saves without discovery fields still load",store.load_save() and store.discovered_boons.is_empty())
	var cards := BoonCatalog.all()
	check("catalog contains 48 realm cards and six duos",cards.size()==54)
	check("chosen authored cards are discovered",store.record_discoveries([cards[0],cards[1]]) and store.discovered_boons.size()==2)
	check("repeated choices do not duplicate progress",store.record_discoveries([cards[0]]) and store.discovered_boons.size()==2)
	var fake := BoonData.new()
	fake.id = "not_an_authored_card"
	check("unknown card is ignored",store.record_discoveries([fake]) and store.discovered_boons.size()==2)
	var reload := MetaProgressionStore.new()
	reload.override_path = profile
	add_child(reload)
	check("discoveries survive reload",reload.discovered_boons==store.discovered_boons)
	var blocker := profile+".blocker"
	file = FileAccess.open(blocker,FileAccess.WRITE)
	file.store_string("file blocks directory")
	file.close()
	store.override_path = blocker+"/save.json"
	check("failed write reports pending without dropping discovery",not store.record_discoveries([cards[2]]) and store.codex_save_pending and store.discovered_boons.has(cards[2].id))
	store.override_path = profile
	check("retry saves all pending knowledge",store.save() and not store.codex_save_pending)
	reload.load_save()
	check("retry survives fresh read",reload.discovered_boons.size()==3)
	check("wallet remains unchanged",reload.will_shards==0 and reload.reality_anchors==0 and reload.settled_runs.is_empty())
	store.queue_free()
	reload.queue_free()
	for suffix in ["",".bak",".tmp",".blocker"]:
		if FileAccess.file_exists(profile+suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(profile+suffix))
	print("CODEX PROGRESS: %d checks, %d failed" % [checks,failures])
	get_tree().quit(0 if failures==0 else 1)
