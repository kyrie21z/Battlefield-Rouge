class_name MetaProgressionStore
extends Node
## Local progression. Rewards arrive from the run controller, never from the UI.
signal changed
signal revived(player: Player)
const SAVE_PATH := "user://meta_progression.json"
const VERSION := 1
const IDS := ["resolve","reflex","defiance","focus","reroll","first_edge","keepsake_slots"]
const NAMES := {"resolve":"坚韧心智","reflex":"突触反射","defiance":"不屈意志","focus":"专注容量","reroll":"重构决意","first_edge":"初见锋芒","keepsake_slots":"高阶信物槽"}
const MAX_LEVEL := {"resolve":5,"reflex":3,"defiance":1,"focus":3,"reroll":2,"first_edge":1,"keepsake_slots":2}
const WILL_COST := {"resolve":20,"reflex":30,"defiance":50,"focus":25,"reroll":35,"first_edge":40,"keepsake_slots":0}
const ANCHOR_COST := {"resolve":0,"reflex":0,"defiance":1,"focus":0,"reroll":0,"first_edge":2,"keepsake_slots":3}
var override_path := ""
var will_shards := 0
var reality_anchors := 0
var levels: Dictionary = {}
var settled_runs: Array[String] = []
var load_status := "new"
var last_error := ""
var defiance_consumed := false
var active_run_id := ""
var _bound_player: WeakRef
var _read_only := false
var history := {"run_count":0,"last_depth":0,"death_cause":""}
var discovered_boons: Array[String] = []
var visited_realms: Array[int] = []
var defeated_realms: Array[int] = []
## Realms whose one-time mechanic card has already been shown. Kept separate
## from visited_realms because entering a realm is not the same as explaining it.
var introduced_realms: Array[int] = []
var reconciled := false
var codex_save_pending := false
var isolated_profile := false
var _cleanup_profile := false

func _init() -> void:
	for id in IDS:
		levels[id] = 0

func _ready() -> void:
	# Autoloads initialize before a test's _ready, so isolation must happen here.
	if override_path.is_empty():
		var args := OS.get_cmdline_args()
		var testing := DisplayServer.get_name() == "headless" or Engine.is_editor_hint()
		for arg in args:
			if arg.replace("\\","/").contains("/tests/") or arg.begins_with("--fixture="):
				testing = true
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("--meta-test-profile=user://meta_test_"):
				override_path = arg.trim_prefix("--meta-test-profile=")
				isolated_profile = true
		if override_path.is_empty() and testing:
			override_path = "user://meta_test_autoload_%d.json" % OS.get_process_id()
			isolated_profile = true
			_cleanup_profile = true
	load_save()
	if name == "MetaProgression":
		Events.boon_chosen.connect(func(card: Resource): record_discoveries([card]))

func _exit_tree() -> void:
	if _cleanup_profile:
		for suffix in ["",".bak",".tmp"]:
			if FileAccess.file_exists(override_path+suffix):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(override_path+suffix))

func record_history(count: int,depth: int,cause: String) -> bool:
	var old := _payload()
	history = {"run_count":maxi(0,count),"last_depth":clampi(depth,0,5),"death_cause":cause.left(128)}
	if not save():
		_restore(old)
		return false
	return true

func save_path() -> String:
	return override_path if not override_path.is_empty() else SAVE_PATH

func level(id: String) -> int:
	return int(levels.get(id,0))

func cost(id: String) -> Vector2i:
	if not IDS.has(id):
		return Vector2i.ZERO
	return Vector2i(WILL_COST[id]*(level(id)+1),ANCHOR_COST[id]*(level(id)+1))

func slots_used() -> int:
	return level("defiance")+level("first_edge")

func slots_capacity() -> int:
	return level("keepsake_slots")

func purchase_blocker(id: String) -> String:
	if _read_only:
		return "存档校验失败，原文件已保留"
	if not IDS.has(id):
		return "未知天赋"
	if level(id)>=MAX_LEVEL[id]:
		return "已达最高等级"
	if id in ["defiance","first_edge"] and slots_used()>=slots_capacity():
		return "需要空闲高阶信物槽"
	var price := cost(id)
	if will_shards<price.x or reality_anchors<price.y:
		return "货币不足"
	return ""

func purchase(id: String) -> bool:
	last_error = purchase_blocker(id)
	if not last_error.is_empty():
		return false
	var old := _payload()
	var price := cost(id)
	will_shards -= price.x
	reality_anchors -= price.y
	levels[id] = level(id)+1
	if not save():
		_restore(old)
		return false
	var player := _bound_player.get_ref() as Player if _bound_player != null else null
	if is_instance_valid(player):
		apply_to_player(player)
	changed.emit()
	return true

func begin_run(run_id: String) -> void:
	if active_run_id == run_id:
		return
	active_run_id = run_id
	defiance_consumed = false
	_bound_player = null

func settle_run(run_id: String,will: int,anchors: int,run_history: Dictionary = {}) -> bool:
	if run_id.is_empty() or run_id.length()>128 or will<0 or anchors<0 or _read_only:
		return false
	if settled_runs.has(run_id):
		return false
	if will_shards+will>1000000000 or reality_anchors+anchors>1000000000:
		return false
	var old := _payload()
	will_shards += will
	reality_anchors += anchors
	settled_runs.append(run_id)
	if not run_history.is_empty():
		history = run_history.duplicate()
	# Keep the complete ledger: evicting old IDs would make a replay payable again.
	if not save():
		_restore(old)
		return false
	changed.emit()
	return true

func maximum_health() -> float:
	return 100.0+10.0*level("resolve")

func starting_rerolls() -> int:
	return 1+level("reroll")

func starting_boon(rng: RandomNumberGenerator) -> BoonData:
	if level("first_edge")==0 or rng==null:
		return null
	var candidates: Array[BoonData] = []
	for card in BoonCatalog.all():
		if card.core and card.rarity==BoonData.Rarity.COMMON and card.prerequisites.is_empty() and card.prerequisite_any.is_empty() and card.required_sins.is_empty():
			candidates.append(card)
	return null if candidates.is_empty() else candidates[rng.randi_range(0,candidates.size()-1)]

func apply_to_player(player: Player) -> void:
	if not is_instance_valid(player):
		return
	_bound_player = weakref(player)
	var hp := player.health.health
	var reflex := level("reflex")
	player.stats.set_modifier(&"meta_talents",{
		Stats.MAX_HEALTH:{"add":10.0*level("resolve")},
		Stats.DASH_RECHARGE:{"mul":[1.0,1.1,1.2,1.25][reflex]},
		Stats.MAGAZINE_SIZE:{"add":float(level("focus"))/8.0},
		Stats.RELOAD_SPEED:{"add":0.1*level("focus")}})
	# Changing MAX_HEALTH normally heals by the delta; room rebinding must not heal.
	player.health.health = minf(hp,player.health.max_health)
	if not player.dash.has_meta("meta_base_capacity"):
		player.dash.set_meta("meta_base_capacity",player.dash.max_charges)
	player.dash.set_max_charges(int(player.dash.get_meta("meta_base_capacity"))+(1 if reflex>=3 else 0))
	player.health.lethal_guard = _prevent_death.bind(player)

func _prevent_death(_context: Dictionary,player: Player) -> float:
	if level("defiance")<=0 or defiance_consumed or active_run_id.is_empty():
		return 0.0
	defiance_consumed = true
	# Defer feedback until Health has restored HP and emitted accurate damage context.
	revived.emit.call_deferred(player)
	return player.health.max_health*0.4

func describe(id: String) -> String:
	match id:
		"resolve": return "初始生命上限 %d / 150 · 每级 +10" % maximum_health()
		"reflex": return "冲刺充能速率 +%d%% · 3级充能次数 +1" % [0,10,20,25][level(id)]
		"defiance": return "每局一次抵御致死打击，恢复40%生命；占1槽。深渊坠落除外。"
		"focus": return "弹匣 +%d 发 · 重组速度 +%d%%" % [level(id),level(id)*10]
		"reroll": return "每局重抽额度 %d / 3 次" % starting_rerolls()
		"first_edge": return "新局自带一枚随机基础心魔赐福；占1槽。"
		"keepsake_slots": return "解锁不屈意志 / 初见锋芒，已用 %d / %d 槽" % [slots_used(),slots_capacity()]
	return ""

func _payload() -> Dictionary:
	return {"version":VERSION,"will_shards":will_shards,"reality_anchors":reality_anchors,"levels":levels.duplicate(),"settled_runs":settled_runs.duplicate(),"history":history.duplicate(),"discovered_boons":discovered_boons.duplicate(),"archive":archive_snapshot()}

func _restore(payload: Dictionary) -> void:
	will_shards = int(payload.will_shards)
	reality_anchors = int(payload.reality_anchors)
	levels = payload.levels.duplicate()
	settled_runs.assign(payload.settled_runs)
	history = payload.get("history",{"run_count":0,"last_depth":0,"death_cause":""}).duplicate()
	discovered_boons.assign(payload.get("discovered_boons",[]))
	var archive: Dictionary = payload.get("archive",{})
	visited_realms.assign(archive.get("visited_realms",[]))
	defeated_realms.assign(archive.get("defeated_realms",[]))
	introduced_realms.assign(archive.get("introduced_realms",[]))
	reconciled = archive.get("reconciled",false)

func _checksum(payload: Dictionary) -> String:
	var normalized: Variant = JSON.parse_string(JSON.stringify(payload,"",true))
	return ("MindFreak.Meta.v1:"+JSON.stringify(normalized,"",true)).sha256_text()

func _read_payload(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path,FileAccess.READ)
	if file==null or file.get_length()>2000000:
		return {}
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		return {}
	var parsed: Variant = parser.data
	if not parsed is Dictionary or not parsed.get("payload") is Dictionary or not parsed.get("checksum") is String:
		return {}
	var data: Dictionary = parsed.payload
	if parsed.checksum!=_checksum(data) or not _valid_integer(data.get("version"),VERSION,VERSION):
		return {}
	if not _valid_integer(data.get("will_shards"),0,1000000000) or not _valid_integer(data.get("reality_anchors"),0,1000000000):
		return {}
	if not data.get("levels") is Dictionary or not data.get("settled_runs") is Array:
		return {}
	if data.levels.size()!=IDS.size():
		return {}
	for id in IDS:
		if not _valid_integer(data.levels.get(id),0,MAX_LEVEL[id]):
			return {}
	if int(data.levels.defiance)+int(data.levels.first_edge)>int(data.levels.keepsake_slots):
		return {}
	if data.has("history"):
		if not data.history is Dictionary or not _valid_integer(data.history.get("run_count"),0,1000000000) or not _valid_integer(data.history.get("last_depth"),0,5):
			return {}
		if not data.history.get("death_cause") is String or data.history.death_cause.length()>128:
			return {}
	if data.has("discovered_boons"):
		if not data.discovered_boons is Array or data.discovered_boons.size()>256:
			return {}
		var known := {}
		for id in data.discovered_boons:
			if not id is String or id.is_empty() or id.length()>128 or known.has(id):
				return {}
			known[id] = true
	if data.has("archive"):
		if not data.archive is Dictionary or not data.archive.get("reconciled") is bool:
			return {}
		for field in ["visited_realms","defeated_realms","introduced_realms"]:
			# A save written before a field existed simply does not carry it. Reading
			# it as corruption would have thrown away every older profile, so a
			# missing field means "empty list", not "damaged file".
			if not data.archive.has(field):
				continue
			var values: Variant = data.archive.get(field)
			if not values is Array or values.size()>4:
				return {}
			var seen_realms := {}
			for realm in values:
				if not _valid_integer(realm,0,3) or seen_realms.has(realm):
					return {}
				seen_realms[realm] = true
		for realm in data.archive.defeated_realms:
			if not data.archive.visited_realms.has(realm):
				return {}
	var seen := {}
	for id in data.settled_runs:
		if not id is String or id.is_empty() or id.length()>128 or seen.has(id):
			return {}
		seen[id] = true
	return data

func _valid_integer(value: Variant,low: int,high: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)==floor(float(value)) and value>=low and value<=high

func load_save() -> bool:
	var path := save_path()
	if not FileAccess.file_exists(path) and not FileAccess.file_exists(path+".bak"):
		load_status = "new"
		return true
	var data := _read_payload(path)
	load_status = "loaded"
	if data.is_empty():
		data = _read_payload(path+".bak")
		load_status = "recovered_backup"
	if data.is_empty():
		_read_only = true
		load_status = "invalid"
		last_error = "存档校验失败；原文件未覆盖"
		return false
	_restore(data)
	_read_only = false
	changed.emit()
	return true

func save() -> bool:
	if _read_only:
		return false
	var path := save_path()
	var absolute := ProjectSettings.globalize_path(path)
	if DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())!=OK:
		last_error = "无法创建存档目录"
		return false
	var payload := _payload()
	var file := FileAccess.open(path+".tmp",FileAccess.WRITE)
	if file==null:
		last_error = "无法写入临时存档"
		return false
	file.store_string(JSON.stringify({"payload":payload,"checksum":_checksum(payload)},"\t",true))
	file.flush()
	file.close()
	if _read_payload(path+".tmp").is_empty():
		last_error = "临时存档回读失败"
		return false
	if not _read_payload(path).is_empty():
		if DirAccess.copy_absolute(absolute,absolute+".bak")!=OK:
			last_error = "无法保存旧档备份"
			return false
	if DirAccess.rename_absolute(absolute+".tmp",absolute)!=OK:
		last_error = "无法原子替换存档"
		return false
	last_error = ""
	codex_save_pending = false
	return true


## Discovery is durable across runs; failed writes keep new knowledge in memory
## and any later successful save includes it without replaying rewards.
func record_discoveries(cards: Array) -> bool:
	var known := {}
	for authored in BoonCatalog.all():
		known[authored.id] = true
	var added := false
	for card in cards:
		if card is BoonData and known.has(card.id) and not discovered_boons.has(card.id):
			discovered_boons.append(card.id)
			added = true
	if added:
		codex_save_pending = true
		changed.emit()
	return save() if codex_save_pending else true


func archive_snapshot() -> Dictionary:
	return {"visited_realms":visited_realms.duplicate(),"defeated_realms":defeated_realms.duplicate(),"introduced_realms":introduced_realms.duplicate(),"reconciled":reconciled}

## Remembers that a realm's one-time mechanic card has been shown, so the player
## sees the explanation exactly once per save. Returns true when this call was the
## one that recorded it, which lets the caller skip the panel on replays.
func mark_realm_introduced(realm: int) -> bool:
	if realm < 0 or realm > 3 or introduced_realms.has(realm):
		return false
	introduced_realms.append(realm)
	codex_save_pending = true
	changed.emit()
	save()
	return true

## True when this realm has never had its mechanic card shown.
func realm_needs_intro(realm: int) -> bool:
	return realm >= 0 and realm <= 3 and not introduced_realms.has(realm)

## Only the campaign composition root calls this after real progression events.
func record_archive(realm: int = -1,was_defeated := false,was_reconciled := false) -> bool:
	if realm < -1 or realm > 3 or (realm == -1 and not was_reconciled):
		return false
	var added := false
	if realm >= 0 and not visited_realms.has(realm):
		visited_realms.append(realm)
		added = true
	if realm >= 0 and was_defeated and not defeated_realms.has(realm):
		defeated_realms.append(realm)
		added = true
	if was_reconciled and not reconciled:
		reconciled = true
		added = true
	if added:
		codex_save_pending = true
		changed.emit()
	return save() if codex_save_pending else true
