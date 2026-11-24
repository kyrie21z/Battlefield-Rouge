extends Node
var checks := 0
var failures := 0
var files: Array[String] = []
var profile := ""
var store: MetaProgressionStore

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().create_timer(90,true).timeout.connect(func():get_tree().quit(2))
	profile = "user://meta_152_test_%d.json" % OS.get_process_id()
	files.append(profile)
	store = MetaProgressionStore.new()
	store.override_path = profile
	add_child(store)
	check("new test store never loads the real profile",store.will_shards==0 and store.reality_anchors==0 and store.load_status=="new")
	check("controller settlement returns all earned currency",store.settle_run("run-1",1200,30) and store.will_shards==1200 and store.reality_anchors==30)
	print("META WRITE STATUS: "+store.last_error)
	check("same run cannot settle twice",not store.settle_run("run-1",1200,30) and store.will_shards==1200)
	check("negative rewards cannot mutate the wallet",not store.settle_run("bad",-10,0) and store.will_shards==1200)
	check("high talent cannot be bought without a visible slot",not store.purchase("defiance") and store.purchase_blocker("defiance")=="需要空闲高阶信物槽")
	var before := store.will_shards
	check("successful purchase charges once and persists",store.purchase("resolve") and store.level("resolve")==1 and store.will_shards==before-20)
	var reload := MetaProgressionStore.new()
	reload.override_path = profile
	add_child(reload)
	check("restart loads balances, talent ranks and settlement ledger",reload.will_shards==store.will_shards and reload.level("resolve")==1 and not reload.settle_run("run-1",99,9))
	reload.queue_free()
	for i in 4:
		store.purchase("resolve")
	check("Resolve caps at 150 base HP",store.maximum_health()==150 and not store.purchase("resolve"))
	store.purchase("keepsake_slots")
	store.purchase("defiance")
	check("advanced talent consumes one unlocked slot",store.slots_used()==1 and store.slots_capacity()==1)
	check("second advanced talent refuses full slots",not store.purchase("first_edge"))
	store.purchase("keepsake_slots")
	store.purchase("first_edge")
	check("second slot unlocks the actual starter ability",store.slots_used()==2 and store.level("first_edge")==1)
	for i in 3:
		store.purchase("reflex")
		store.purchase("focus")
	store.purchase("reroll")
	store.purchase("reroll")
	check("rerolls cap at three",store.starting_rerolls()==3)
	var player := preload("res://actors/player/player.tscn").instantiate() as Player
	add_child(player)
	player.set_physics_process(false)
	store.begin_run("combat-1")
	store.apply_to_player(player)
	check("real Player Stats receive all numeric meta talents",player.health.max_health==150 and player.weapon.magazine_capacity()==11 and is_equal_approx(player.stats.get_value(Stats.RELOAD_SPEED),1.3) and is_equal_approx(player.stats.get_value(Stats.DASH_RECHARGE),1.25))
	check("dash capacity upgrade grants a real third charge",player.dash.max_charges==3 and player.dash.charges()==3)
	player.health.health = 41
	store.apply_to_player(player)
	check("repeated room binding neither stacks stats nor heals",player.health.max_health==150 and player.health.health==41 and player.weapon.magazine_capacity()==11)
	player.health.health = 100
	player.health.grant_shield(200)
	player.health.apply_damage(120,Hitbox.BodyPart.BODY,null)
	check("fully absorbed hit cannot consume the revival",not store.defiance_consumed and player.health.health==100)
	player.health.break_shield()
	var died := [0]
	player.health.died.connect(func(_source):died[0]+=1)
	player.health.apply_damage(999,Hitbox.BodyPart.BODY,null)
	check("final lethal damage restores 40 percent without emitting death",store.defiance_consumed and player.health.health==60 and died[0]==0 and player.health.last_damage_context.get("death_prevented",false))
	check("revival context reports actual life loss before restoration",player.health.last_damage_context.dealt==100 and player.health.last_damage_context.get("restored_health",0)==60)
	store.apply_to_player(player)
	player.health.apply_damage(999,Hitbox.BodyPart.BODY,null)
	check("rebinding cannot replenish a spent once-per-run revival",player.health.is_dead() and died[0]==1)
	player.queue_free()
	await frames(3)
	var next := preload("res://actors/player/player.tscn").instantiate() as Player
	add_child(next)
	next.set_physics_process(false)
	store.begin_run("combat-2")
	store.apply_to_player(next)
	check("new unique run resets the revival allowance",not store.defiance_consumed)
	next.health.apply_damage(1,Hitbox.BodyPart.BODY,null,{"environmental_fatal":true})
	check("abyss boundary remains fatal without consuming unsafe revival",next.health.is_dead() and not store.defiance_consumed)
	next.health.health = next.health.max_health
	var rng_a := RandomNumberGenerator.new()
	var rng_b := RandomNumberGenerator.new()
	rng_a.seed=152
	rng_b.seed=152
	var boon := store.starting_boon(rng_a)
	check("starter boon is seeded and actually equippable",boon!=null and boon==store.starting_boon(rng_b) and next.boons.can_equip(boon))
	var forge := preload("res://ui/meta_forge/crown_forge.tscn").instantiate() as CrownForge
	add_child(forge)
	forge.setup(store,next)
	check("forge shows real wallet and occupied slots",forge._wallet.text.contains(str(store.will_shards)) and forge._slots.text.contains("2 / 2") and forge._cards.defiance.button.disabled)
	var close_count := [0]
	forge.closed.connect(func():close_count[0]+=1)
	forge.close()
	forge.close()
	check("forge closes once and restores pause state",close_count[0]==1 and not get_tree().paused)
	await frames(2)
	# A modified main file must recover the previous verified backup, never trust edits.
	var corrupt := FileAccess.open(profile,FileAccess.WRITE)
	corrupt.store_string('{"payload":{"will_shards":999999},"checksum":"fake"}')
	corrupt.close()
	var recovered := MetaProgressionStore.new()
	recovered.override_path=profile
	add_child(recovered)
	check("tampered main profile falls back to a verified backup",recovered.load_status=="recovered_backup" and recovered.will_shards!=999999 and recovered.level("resolve")==5)
	var invalid_path := profile+".invalid"
	files.append(invalid_path)
	var invalid := FileAccess.open(invalid_path,FileAccess.WRITE)
	invalid.store_string("{broken")
	invalid.close()
	var blocked := MetaProgressionStore.new()
	blocked.override_path=invalid_path
	add_child(blocked)
	check("invalid profile without backup is preserved and locked",blocked.load_status=="invalid" and not blocked.settle_run("new",20,1) and FileAccess.get_file_as_string(invalid_path)=="{broken")
	var barrier := profile+".barrier"
	files.append(barrier)
	var file := FileAccess.open(barrier,FileAccess.WRITE)
	file.store_string("owned-test-file")
	file.close()
	var balance := recovered.will_shards
	recovered.override_path=barrier+"/cannot-save.json"
	check("failed disk transaction rolls back currency and run ledger",not recovered.settle_run("disk-failure",10,1) and recovered.will_shards==balance and not recovered.settled_runs.has("disk-failure"))
	var transaction := MetaProgressionStore.new()
	transaction.override_path = profile+".transaction"
	files.append(transaction.override_path)
	add_child(transaction)
	transaction.settle_run("purchase-disk-test",100,0)
	transaction.override_path = barrier+"/cannot-save.json"
	check("failed upgrade rolls back both payment and talent rank",not transaction.purchase("resolve") and transaction.will_shards==100 and transaction.level("resolve")==0)
	var legacy_path := profile+".legacy"
	files.append(legacy_path)
	var legacy_data := store._payload()
	legacy_data.erase("history")
	var legacy_file := FileAccess.open(legacy_path,FileAccess.WRITE)
	legacy_file.store_string(JSON.stringify({"payload":legacy_data,"checksum":store._checksum(legacy_data)}))
	legacy_file.close()
	var legacy := MetaProgressionStore.new()
	legacy.override_path=legacy_path
	add_child(legacy)
	check("pre-history valid profile retains talents and defaults safe run history",legacy.load_status=="loaded" and legacy.level("resolve")==5 and legacy.history.run_count==0)
	check("old profile upgrades history atomically without losing wallet",legacy.record_history(4,3,"abyss") and legacy.history.last_depth==3 and legacy.will_shards==store.will_shards)
	var malformed_path := profile+".history-invalid"
	files.append(malformed_path)
	var malformed := legacy._payload()
	malformed.history.run_count="not-an-integer"
	var malformed_file := FileAccess.open(malformed_path,FileAccess.WRITE)
	malformed_file.store_string(JSON.stringify({"payload":malformed,"checksum":store._checksum(malformed)}))
	malformed_file.close()
	var invalid_history := MetaProgressionStore.new()
	invalid_history.override_path=malformed_path
	add_child(invalid_history)
	check("valid checksum cannot bypass run history type validation",invalid_history.load_status=="invalid" and invalid_history.history.run_count==0)
	# --- Optional v1 fields: opening flag and the resumable run checkpoint ---
	var core_id := ""
	var trait_id := ""
	var conflicting_cores: Array = []
	var slot_owner := {}
	for card in BoonCatalog.all():
		if card.core and core_id.is_empty():
			core_id = card.id
		if not card.core and card.rarity != BoonData.Rarity.DUAL and trait_id.is_empty():
			trait_id = card.id
		if card.core:
			if slot_owner.has(card.slot) and conflicting_cores.is_empty():
				conflicting_cores = [slot_owner[card.slot],card.id]
			slot_owner[card.slot] = card.id
	check("catalog exposes a core and a trait for snapshot fixtures",not core_id.is_empty() and not trait_id.is_empty() and conflicting_cores.size()==2)
	var resume_store := MetaProgressionStore.new()
	resume_store.override_path = profile+".active"
	files.append(resume_store.override_path)
	add_child(resume_store)
	check("blank profile has no opening flag, no unfinished run and no profile",not resume_store.opening_completed and not resume_store.has_active_run() and not resume_store.has_profile())
	check("opening completion is a transactional write",resume_store.mark_opening_completed() and resume_store.opening_completed and resume_store.has_profile())
	check("blank wallet cannot afford any upgrade",not resume_store.has_affordable_upgrade())
	check("banked will makes at least one upgrade affordable",resume_store.settle_run("forge-ready",60,0) and resume_store.has_affordable_upgrade())
	var snapshot := active_snapshot({"boon_ids":[core_id,trait_id]})
	check("valid room snapshot is accepted",resume_store.save_active_run(snapshot) and resume_store.has_active_run() and resume_store.active_run_id=="active-run-77")
	check("snapshot with non-positive hp is rejected without touching the stored one",not resume_store.save_active_run(active_snapshot({"hp":0.0})) and is_equal_approx(float(resume_store.active_run.get("hp",0.0)),96.5))
	var tamper_cases := {
		"empty run id":{"run_id":""},
		"already settled run id":{"settled_run":true},
		"order is not a permutation":{"order":[1,0,2,2]},
		"floor above the return corridor":{"floor_index":5},
		"room above the boss room":{"room_index":3},
		"return corridor with a sub-room":{"floor_index":4,"room_index":1},
		"return corridor without four cores":{"floor_index":4,"room_index":0,"defeated":[0,1,2,3],"deprivations":[0,1,2,3],"shards":[0,1]},
		"duplicate defeated realm":{"defeated":[1,1]},
		"duplicate deprivation realm":{"deprivations":[1,1]},
		"duplicate shard realm":{"shards":[1,2,2]},
		"unknown boon id":{"boon_ids":["not_a_real_card"]},
		"two cores in one slot":{"boon_ids":conflicting_cores},
		"rerolls above the cap":{"rerolls":11},
		"negative pending will":{"earned_will":-1},
		"negative pending anchors":{"earned_anchors":-1},
		"entry claim is not a boolean":{"entry_reward_claimed":1},
		"defiance latch is not a boolean":{"defiance_consumed":"yes"},
		"fragment state is not numeric":{"fragment_state":{"barrier":"lots"}},
	}
	var tamper_index := 0
	for label in tamper_cases:
		var tampered_payload := resume_store._payload()
		var tampered_snapshot := active_snapshot(tamper_cases[label])
		if bool(tamper_cases[label].get("settled_run",false)):
			tampered_snapshot["run_id"] = "forge-ready"
		tampered_snapshot.erase("settled_run")
		tampered_payload.active_run = tampered_snapshot
		var tampered_path := profile+".tamper-%d" % tamper_index
		tamper_index += 1
		files.append(tampered_path)
		write_checksummed(tampered_path,tampered_payload)
		var tampered := MetaProgressionStore.new()
		tampered.override_path = tampered_path
		add_child(tampered)
		check("tampered checkpoint rejected: "+label,tampered.load_status=="invalid" and not tampered.has_active_run())
		tampered.queue_free()
	check("return-corridor checkpoint at 4:0 with every core is valid",resume_store.save_active_run(active_snapshot({"floor_index":4,"room_index":0,"defeated":[0,1,2,3],"deprivations":[0,1,2,3],"shards":[0,1,2,3],"selections":[]})))
	check("clear_active_run removes the checkpoint and its run binding",resume_store.clear_active_run() and not resume_store.has_active_run() and resume_store.active_run_id.is_empty())
	check("checkpoint and opening flag survive a restart",resume_store.save_active_run(snapshot))
	var journal := MetaProgressionStore.new()
	journal.override_path = resume_store.override_path
	add_child(journal)
	check("reloaded profile exposes the unfinished run",journal.opening_completed and journal.has_active_run() and journal.active_run_id=="active-run-77" and int(journal.active_run.get("floor_index",-1))==1 and int(journal.active_run.get("earned_will",-1))==145)
	journal.queue_free()
	check("settling a checkpointed run clears the checkpoint in the same write",resume_store.settle_run("active-run-77",5,1) and not resume_store.has_active_run() and resume_store.settled_runs.has("active-run-77"))
	check("a settled checkpoint id cannot be written or paid again",not resume_store.save_active_run(snapshot) and not resume_store.settle_run("active-run-77",9,9))
	# Legacy v1 files written before the two optional fields must load cleanly.
	var legacy_fields_path := profile+".v1-fields"
	files.append(legacy_fields_path)
	var legacy_fields_data := resume_store._payload()
	legacy_fields_data.erase("opening_completed")
	legacy_fields_data.erase("active_run")
	legacy_fields_data.history = {"run_count":2,"last_depth":1,"death_cause":"combat"}
	write_checksummed(legacy_fields_path,legacy_fields_data)
	var legacy_fields := MetaProgressionStore.new()
	legacy_fields.override_path = legacy_fields_path
	add_child(legacy_fields)
	check("legacy v1 without new fields infers a completed opening",legacy_fields.load_status=="loaded" and legacy_fields.opening_completed and not legacy_fields.has_active_run())
	check("legacy v1 keeps its wallet and talents",legacy_fields.will_shards==resume_store.will_shards and legacy_fields.has_profile())
	legacy_fields.queue_free()
	var blank_fields_data := legacy_fields_data.duplicate(true)
	blank_fields_data.history = {"run_count":0,"last_depth":0,"death_cause":""}
	blank_fields_data.settled_runs = []
	blank_fields_data.discovered_boons = []
	blank_fields_data.will_shards = 0
	blank_fields_data.reality_anchors = 0
	blank_fields_data.levels = {}
	for id in MetaProgressionStore.IDS:
		blank_fields_data.levels[id] = 0
	blank_fields_data.archive = {"visited_realms":[],"defeated_realms":[],"introduced_realms":[],"reconciled":false}
	var blank_fields_path := profile+".v1-blank"
	files.append(blank_fields_path)
	write_checksummed(blank_fields_path,blank_fields_data)
	var blank_fields := MetaProgressionStore.new()
	blank_fields.override_path = blank_fields_path
	add_child(blank_fields)
	check("legacy v1 with no progress keeps the opening pending",blank_fields.load_status=="loaded" and not blank_fields.opening_completed and not blank_fields.has_profile())
	blank_fields.queue_free()
	var visited_fields_data := blank_fields_data.duplicate(true)
	visited_fields_data.archive = {"visited_realms":[2],"defeated_realms":[],"introduced_realms":[],"reconciled":false}
	var visited_fields_path := profile+".v1-visited"
	files.append(visited_fields_path)
	write_checksummed(visited_fields_path,visited_fields_data)
	var visited_fields := MetaProgressionStore.new()
	visited_fields.override_path = visited_fields_path
	add_child(visited_fields)
	check("legacy v1 with a visited realm also implies a completed opening",visited_fields.opening_completed and visited_fields.has_profile())
	visited_fields.queue_free()
	# New game: the current valid file is preserved as .bak before the wipe.
	var reset_store := MetaProgressionStore.new()
	reset_store.override_path = profile+".reset"
	files.append(reset_store.override_path)
	add_child(reset_store)
	reset_store.settle_run("reset-run",80,2)
	reset_store.purchase("resolve")
	reset_store.mark_opening_completed()
	reset_store.save_active_run(active_snapshot({"run_id":"reset-active"}))
	var before_reset := FileAccess.get_file_as_string(reset_store.override_path)
	check("reset scenario starts with a real profile",reset_store.has_profile() and reset_store.has_active_run() and reset_store.level("resolve")==1)
	check("reset_profile wipes wallet, talents, history and the checkpoint",reset_store.reset_profile() and not reset_store.has_profile() and not reset_store.opening_completed and not reset_store.has_active_run() and reset_store.will_shards==0 and reset_store.reality_anchors==0 and reset_store.level("resolve")==0 and reset_store.settled_runs.is_empty())
	check("reset_profile backs the previous valid file up to .bak",FileAccess.get_file_as_string(reset_store.override_path+".bak")==before_reset)
	var reset_reload := MetaProgressionStore.new()
	reset_reload.override_path = reset_store.override_path
	add_child(reset_reload)
	check("reset profile persists as a brand new save",reset_reload.load_status=="loaded" and not reset_reload.has_profile() and not reset_reload.has_active_run())
	reset_reload.queue_free()
	legacy.queue_free()
	invalid_history.queue_free()
	transaction.queue_free()
	next.queue_free()
	forge=null
	store.queue_free()
	recovered.queue_free()
	blocked.queue_free()
	await frames(4)
	for path in files:
		for suffix in ["",".bak",".tmp"]:
			if FileAccess.file_exists(path+suffix):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(path+suffix))
	OS.delay_msec(250)
	print("META FORGE: %d checks, %d failed" % [checks,failures])
	get_tree().quit(1 if failures else 0)

func frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame

## A complete, valid room-start checkpoint. Cases override one field each so a
## rejection can only come from the field under test.
func active_snapshot(overrides: Dictionary = {}) -> Dictionary:
	var value := {
		"run_id":"active-run-77",
		"run_seed":91234,
		"order":[1,0,2,3],
		"floor_index":1,
		"room_index":1,
		"defeated":[1],
		"deprivations":[1],
		"shards":[1],
		"hp":96.5,
		"boon_ids":[],
		"fragment_state":{"barrier":40.0,"recovery":0.0,"counter":0.0,"charge":1,"since_combat":0.0,"resonance":0.0,"room_healed":0.0},
		"rerolls":2,
		"selections":[{"floor":1,"room":0,"realm":1,"boon_id":"dual_slumber_magma"}],
		"entry_reward_claimed":true,
		"earned_will":145,
		"earned_anchors":2,
		"defiance_consumed":false,
	}
	value.merge(overrides,true)
	return value

func write_checksummed(path: String, data: Dictionary) -> void:
	var file := FileAccess.open(path,FileAccess.WRITE)
	file.store_string(JSON.stringify({"payload":data,"checksum":store._checksum(data)}))
	file.close()

func check(label: String,passed: bool) -> void:
	checks+=1
	if not passed:
		failures+=1
	print(("PASS " if passed else "FAIL ")+label)
