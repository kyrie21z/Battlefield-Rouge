extends Node
## Production catalog, manager/equip signals and UI. No writes to progression.
const CODEX := preload("res://ui/codex/dual_boon_codex.tscn")
const GUNS := ["sloth_gun_pulse", "fear_gaze_pierce", "wrath_gun_cannon", "sorrow_gun_needles"]
const BLADES := ["sloth_blade_cleave", "fear_flash_backstab", "wrath_blade_sweep", "sorrow_blade_tide"]
var _failures := 0
var _checks := 0
var _codex: DualBoonCodex
var _player: Player
var _manager: BoonManager
var _cards: Dictionary = {}
var _proof := ""
var _elapsed := 0.0

func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed > 90:
		push_error("Codex test timeout")
		get_tree().quit(1)

func _ready() -> void:
	get_window().size = Vector2i(1280, 720)
	get_window().content_scale_size = Vector2i(1280, 720)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--proof="):
			_proof = arg.trim_prefix("--proof=")
	await get_tree().process_frame
	_check("autoload profile isolated before test", MetaProgression.isolated_profile and MetaProgression.save_path() != MetaProgression.SAVE_PATH)
	_player = preload("res://actors/player/player.tscn").instantiate() as Player
	add_child(_player)
	_player.set_physics_process(false)
	_player.weapon.set_process(false)
	_player.melee.set_process(false)
	_player.dash.set_physics_process(false)
	_manager = _player.boons
	_manager.set_physics_process(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for card in BoonCatalog.all():
		_cards[card.id] = card
	_check("real catalog contains 54 unique cards", _cards.size() == 54)
	var layer := CanvasLayer.new()
	add_child(layer)
	_codex = CODEX.instantiate() as DualBoonCodex
	_codex.setup(_manager, ["sloth_gun_pulse", "dual_slumber_magma"])
	layer.add_child(_codex)
	await _frames()
	_check("setup before tree populates six dual routes", _codex._buttons.size() == 6 and _codex._topology._edges.size() == 6)
	_check("setup does not pause the tree", not get_tree().paused)
	_check("discovery distinct from loadout", _codex._buttons["dual_slumber_magma"].text.contains("已发现") and _codex._buttons["dual_tearful_panic"].text.contains("未发现"))
	_check("all six duals start ineligible", _codex._topology.eligible.values().all(func(value): return not value))
	await _shot("01-empty-routes")
	for dual: BoonData in _codex._duals:
		_manager.clear()
		_codex._select(dual)
		_check(dual.id + " missing both authored core families", _codex._requirements.text.count("还缺少：") == 2)
		_equip(GUNS[dual.required_sins[0]])
		_check(dual.id + " single core remains ineligible", not _codex._topology.eligible[dual.id] and _codex._requirements.text.count("还缺少：") == 1)
		_equip(GUNS[dual.required_sins[1]])
		_check(dual.id + " same-slot replacement cannot satisfy pair", not _codex._topology.eligible[dual.id])
		_equip(BLADES[dual.required_sins[0]])
		_check(dual.id + " two distinct slots light the real route", _manager.can_equip(dual) and _codex._topology.eligible[dual.id] and _codex._requirements.text.count("还缺少：") == 0)
		_check(dual.id + " current cores highlighted", _codex._topology.cores.has(dual.required_sins[0]) and _codex._topology.cores.has(dual.required_sins[1]))
		_check(dual.id + " obtains through manager request", _manager.request_equip(dual))
		_check(dual.id + " owned card stops availability glow", not _codex._topology.eligible[dual.id] and _codex._detail_status.text.contains("当前已持有"))
		_manager.remove(BLADES[dual.required_sins[0]])
		_check(dual.id + " owned card still explains lost current core", _codex._requirements.text.contains("还缺少："))
	_manager.clear()
	_equip("sloth_blade_cleave")
	_equip("wrath_gun_cannon")
	_codex._select(_cards["dual_slumber_magma"])
	await _frames()
	await _shot("02-magma-eligible")
	await _test_pages()
	await _test_requirements()
	await _test_lifecycle(layer)
	await _test_layout()
	await _test_hosted_page()
	_check("UI never changed equipment during browsing", _manager.has("sloth_blade_cleave") and _manager.has("wrath_gun_cannon"))
	get_tree().paused = false
	_codex.queue_free()
	_manager.clear()
	_player.queue_free()
	await _frames()
	print("DUAL BOON CODEX: %s (%d checks, %d failed)" % ["ALL PASSED" if _failures == 0 else "FAIL", _checks, _failures])
	get_tree().quit(0 if _failures == 0 else 1)

func _test_pages() -> void:
	var visited := {}
	for page in range(1, 5):
		_shoulder(JOY_BUTTON_RIGHT_SHOULDER)
		_check("RB switches to family %d" % page, _codex._page == page)
		_check("family page has all twelve real cards", _codex._buttons.size() == 12)
		await _frames()
		for id in _codex._buttons:
			visited[id] = true
			_codex._buttons[id].grab_focus()
			_check(id + " focus exposes original effect even undiscovered", _codex._detail_body.text == _cards[id].description and _codex._selected.id == id)
			_check(id + " matches manager eligibility", _codex._detail_status.text.contains("当前可获得") == _manager.can_equip(_cards[id]))
		await _frames()
		_check("focus-follow keeps last card visible", (_codex._list_scroll.scroll_vertical > 0 or _codex._grid.size.y <= _codex._list_scroll.size.y))
		_codex._tabs[page].grab_focus()
		_shoulder(JOY_BUTTON_DPAD_DOWN)
		await _frames()
		_check("D-pad down enters card grid", _codex.get_viewport().gui_get_focus_owner() == _codex._buttons[_codex._page_cards()[0].id])
		for row in 5:
			_shoulder(JOY_BUTTON_DPAD_DOWN)
			await _frames(1)
		_check("D-pad follows card rows with scrolling", _codex._selected == _codex._page_cards()[10] and (_codex._list_scroll.scroll_vertical > 0 or _codex._grid.size.y <= _codex._list_scroll.size.y))
		_shoulder(JOY_BUTTON_DPAD_DOWN)
		await _frames()
		_check("D-pad reaches scrollable detail", _codex._detail_scroll.has_focus())
		_check("last card has detail focus route", _codex._buttons[_codex._page_cards().back().id].focus_neighbor_bottom == _codex._detail_scroll.get_path())
		await _shot("03-family-%d-last-card" % page)
	_check("all 48 real family cards browsed", visited.size() == 48)
	_shoulder(JOY_BUTTON_RIGHT_SHOULDER)
	_check("RB wraps to dual page", _codex._page == 0)
	_shoulder(JOY_BUTTON_LEFT_SHOULDER)
	_check("LB wraps to sorrow", _codex._page == 4)
	_codex.hide()
	_shoulder(JOY_BUTTON_RIGHT_SHOULDER)
	_check("hidden codex ignores shoulder", _codex._page == 4)
	_codex.show()
	_codex._topology.card_selected.emit(_cards["dual_slumber_magma"])
	_check("map selection opens matching page and details", _codex._page == 0 and _codex._selected.id == "dual_slumber_magma")

func _test_requirements() -> void:
	var catalog := BoonCatalog.all()
	var any_card: BoonData = _cards["sloth_descent"]
	var text := "\n".join(CodexRequirements.describe(any_card, _manager, catalog))
	_check("real OR requirement names both alternatives and current success", text.contains("已满足任选一项") and text.contains("沉眠重劈") and text.contains("延爆脉冲"))
	var legend: BoonData = _cards["sloth_eternal"]
	text = "\n".join(CodexRequirements.describe(legend, _manager, catalog))
	_check("real legendary trait count is explained", text.contains("0 / 2") and text.contains("还需 2 张"))
	_equip("sloth_inertia")
	_equip("sloth_stillness")
	text = "\n".join(CodexRequirements.describe(legend, _manager, catalog))
	_check("real legendary becomes eligible with two family traits", _manager.can_equip(legend) and text.contains("✓ 怠惰特质 2 / 2"))
	_manager.remove("sloth_inertia")
	_manager.remove("sloth_stillness")
	# No authored strict-AND IDs currently exist; verify that field without replacing catalog tests.
	var strict := BoonData.new()
	strict.prerequisites.assign(["sloth_blade_cleave", "fear_gaze_pierce"])
	text = "\n".join(CodexRequirements.describe(strict, _manager, catalog))
	_check("strict AND field explains each held and missing ID", text.contains("✓ 已持有：怠惰·刀·沉眠重劈") and text.contains("还缺少：恐惧·枪·凝视穿刺"))

func _test_lifecycle(layer: CanvasLayer) -> void:
	var second := BoonManager.new()
	add_child(second)
	_codex.setup(second, [])
	_check("rebinding detaches old manager", not _manager.changed.is_connected(_codex.refresh) and second.changed.is_connected(_codex.refresh))
	_codex.setup(_manager, ["dual_slumber_magma"])
	_codex.setup(_manager, ["dual_slumber_magma"])
	_check("repeated setup does not duplicate connection", _manager.changed.get_connections().filter(func(connection): return connection.callable == _codex.refresh).size() == 1)
	_check("setup after tree updates discovery", _codex._buttons["dual_slumber_magma"].text.contains("已发现"))
	second.queue_free()
	var standalone := CODEX.instantiate() as DualBoonCodex
	layer.add_child(standalone)
	standalone.setup(null, [])
	_check("null manager remains fully browsable", standalone._buttons.size() == 6 and standalone._requirements.text.contains("尚未接入"))
	standalone.queue_free()
	await _frames()
	get_tree().paused = true
	_codex.process_mode = Node.PROCESS_MODE_ALWAYS # host owns paused UI processing
	_shoulder(JOY_BUTTON_RIGHT_SHOULDER)
	_check("host-paused codex pages while preserving pause", get_tree().paused and _codex._page == 1)
	_codex._set_page(0)
	var phase := _codex._topology._phase
	await _frames()
	_check("availability pulse advances under host pause", _codex._topology._phase != phase)
	get_tree().paused = false

func _test_layout() -> void:
	for resolution in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		get_window().size = resolution
		get_window().content_scale_size = resolution
		await _frames(5)
		_codex._select(_cards["dual_slumber_magma"])
		await _frames()
		_check("layout root fits %s" % resolution, _codex.size.x <= resolution.x + 1 and _codex.size.y <= resolution.y + 1)
		_check("map and footer fit %s" % resolution, _codex._core_summary.get_global_rect().end.y <= _codex.size.y - 20)
		_check("detail fits %s" % resolution, _codex._detail_scroll.get_global_rect().end.y <= _codex.size.y - 20)
		_check("cards do not overflow horizontally %s" % resolution, _codex._grid.get_global_rect().end.x <= _codex.size.x - 20)
		await _shot("04-layout-%dx%d" % [resolution.x, resolution.y])

func _test_hosted_page() -> void:
	get_window().size = Vector2i(1280, 720)
	get_window().content_scale_size = Vector2i(1280, 720)
	# Reproduce the host's extra navigation/header budget without depending on its implementation.
	_codex.offset_top = 88
	_codex.refresh()
	await _frames(5)
	_check("hosted page fits below 88px host header", _codex._core_summary.get_global_rect().end.y <= 700 and _codex._detail_scroll.get_global_rect().end.y <= 700)
	_codex._select(_cards["dual_tearful_panic"])
	_codex._detail_scroll.grab_focus()
	await _frames()
	_codex._detail_scroll.scroll_vertical = int(_codex._detail_scroll.get_v_scroll_bar().max_value)
	await _frames()
	_check("long missing-core explanation can scroll to end", _codex._detail_scroll.scroll_vertical > 0)
	await _shot("05-hosted-missing-core-details")
	_codex.offset_top = 0

func _equip(id: String) -> void:
	_manager.equip(_cards[id])

func _shoulder(index: int) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = index
	event.pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func _frames(count: int = 3) -> void:
	for i in count:
		await get_tree().process_frame

func _shot(label: String) -> void:
	if _proof.is_empty() or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_proof))
	_check("native screenshot " + label, get_viewport().get_texture().get_image().save_png(_proof.path_join(label + ".png")) == OK)

func _check(label: String, passed: bool) -> void:
	_checks += 1
	print(("PASS " if passed else "FAIL ") + label)
	if not passed:
		_failures += 1
