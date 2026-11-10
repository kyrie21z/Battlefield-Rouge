extends Node
var checks := 0
var failures := 0
var files: Array[String] = []
var profile := ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().create_timer(90,true).timeout.connect(func():get_tree().quit(2))
	profile = "user://meta_152_test_%d.json" % OS.get_process_id()
	files.append(profile)
	var store := MetaProgressionStore.new()
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

func check(label: String,passed: bool) -> void:
	checks+=1
	if not passed:
		failures+=1
	print(("PASS " if passed else "FAIL ")+label)
