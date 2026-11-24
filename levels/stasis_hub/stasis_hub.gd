class_name StasisHub
extends Node3D
## The hall owns player interaction and presentation. RunDirector owns departure.
signal departure_requested
signal title_requested

const DEFAULT_ENV := preload("res://environments/default_env.tres")
const FORGE := preload("res://ui/meta_forge/crown_forge.tscn")
const INTERACT_RANGE := 3.0
const GATE_HALF_WIDTH := 2.8
const WHITE := Color("f4f4f3")
const GOLD := Color("9b773d")
const REALM_NAMES := ["怠惰", "恐惧", "愤怒", "悲伤"]

var hub_reason := ""
var run_count := 0
var last_death_depth := 0
var last_death_cause: StringName
var affordable_upgrade := false

var _settings := GameSettings.new()
var _base_sensitivity := 0.0
var _forge_crown: CrownModel
var _forge_light: OmniLight3D
var _pillar_bodies: Array[MeshInstance3D] = []
var _pillar_caps: Array[MeshInstance3D] = []
var _pillar_inlays: Array[Node3D] = []
var _white := CrownModel.material(WHITE, 0.0, 0.85)
var _stone := CrownModel.material(Color("d7d9db"), 0.0, 0.72)
var _elapsed := 0.0
var _departing := false
var _prompt: PanelContainer
var _prompt_label: Label
var _archive: StasisArchiveModal

@onready var player: Player = $Player
@onready var crown: CrownVoiceSystem = $Player/CrownVoiceSystem
@onready var _architecture: Node3D = $Architecture
@onready var _altar: Node3D = $ForgeAltar
@onready var _stele: Node3D = $ArchiveStele
@onready var _gate: Node3D = $DepartureGate


func _ready() -> void:
	_build_architecture()
	_build_forge()
	_build_archive()
	_build_gate()
	_build_interface()

	player.view_camera.make_current()

	MetaProgression.changed.connect(_refresh_progression)
	_refresh_progression()
	_announce_history()


func _announce_history() -> void:
	if hub_reason != "post_death":
		return
	await get_tree().create_timer(0.4, false).timeout
	if _departing or not is_inside_tree():
		return
	# The room-entry response is written for the upcoming attempt. Preview it
	# here without incrementing the stored count before the player departs.
	crown.configure_history(run_count + 1, last_death_depth, str(last_death_cause))


func _build_architecture() -> void:
	var world := WorldEnvironment.new()
	var environment := DEFAULT_ENV.duplicate() as Environment
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("e4e7e9")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("e5e8f0")
	environment.ambient_light_energy = 0.5
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment = environment
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -32, 0)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	add_child(sun)

	_slab(_architecture, Vector3(0, -0.35, -2), Vector3(16, 0.7, 22), _stone, true)
	_slab(_architecture, Vector3(0, 3, 8.9), Vector3(16, 6, 0.2), _white)
	_collider(_architecture, Vector3(0, 12, 8.9), Vector3(16, 24, 0.2))
	for side: float in [-1.0, 1.0]:
		_slab(_architecture, Vector3(side * 7.9, 0.65, -2), Vector3(0.2, 1.3, 22), _white)
		# Keep the open colonnade visible while stopping upward dashes at its edge.
		_collider(_architecture, Vector3(side * 8, 12, -2), Vector3(0.2, 24, 22))
		_slab(_architecture, Vector3(side * 7.05, 6.1, -2), Vector3(1.8, 0.6, 22), _white)
		for index in 5:
			var z := 6.2 - 4.1 * index
			_slab(_architecture, Vector3(side * 7.05, 2.95, z), Vector3(1.05, 5.9, 1.1), _white, true)
			_slab(_architecture, Vector3(side * 7.05, 0.12, z), Vector3(1.4, 0.24, 1.45), _white)
		_slab(_architecture, Vector3(side * 2.8, 0.006, -2), Vector3(0.025, 0.01, 17), _white)


func _build_forge() -> void:
	_facet(_altar, Vector3(0, 0.09, 0), 0.76, 0.8, 0.18, 6, _stone)
	_facet(_altar, Vector3(0, 0.6, 0), 0.58, 0.75, 0.84, 6, _white)
	_facet(_altar, Vector3(0, 1.08, 0), 0.48, 0.58, 0.12, 6, _white)
	_collider(_altar, Vector3(0, 0.56, 0), Vector3(1.02, 1.12, 1.02))

	_forge_crown = CrownModel.new()
	_forge_crown.name = "ForgeCrown"
	_forge_crown.position.y = 1.53
	_forge_crown.scale = Vector3.ONE * 1.65
	_altar.add_child(_forge_crown)
	_forge_light = OmniLight3D.new()
	_forge_light.name = "ForgeLight"
	_forge_light.position.y = 1.65
	_forge_light.omni_range = 2.2
	_altar.add_child(_forge_light)


func _build_archive() -> void:
	_slab(_stele, Vector3(0, 0.32, 0), Vector3(1.15, 0.64, 0.58), _white, true)
	var tablet := _slab(_stele, Vector3(0, 0.69, 0), Vector3(1.2, 0.1, 0.65), _stone)
	tablet.rotation.x = deg_to_rad(-12)

	for realm in REALM_NAMES.size():
		var pillar := Node3D.new()
		pillar.name = "Pillar%d" % realm
		pillar.position = Vector3((realm - 1.5) * 1.02, 0, -1.19)
		_stele.add_child(pillar)
		var body := _facet(pillar, Vector3(0, 1.38, 0), 0.33, 0.33, 2.65, 4, _white)
		body.name = "Crystal"
		body.rotation.y = PI / 4.0
		_pillar_bodies.append(body)
		var cap := _facet(pillar, Vector3(0, 2.78, 0), 0.11, 0.33, 0.15, 4, _white)
		cap.name = "Trim"
		cap.rotation.y = body.rotation.y
		_pillar_caps.append(cap)
		_collider(pillar, Vector3(0, 1.4, 0), Vector3(0.47, 2.8, 0.47))
		_world_label(pillar, Vector3(0, 0.6, 0.237), REALM_NAMES[realm], 0.0026)
		var inlay := Node3D.new()
		inlay.name = "Kintsugi"
		pillar.add_child(inlay)
		var gold := CrownModel.material(GOLD, 0.35, 0.45)
		var points := [Vector2(-0.22, 0.65), Vector2(-0.03, 1.24), Vector2(-0.08, 1.52), Vector2(0.22, 2.11)]
		for segment in points.size() - 1:
			var start: Vector2 = points[segment]
			var end: Vector2 = points[segment + 1]
			var center := (start + end) * 0.5
			var strip := _slab(inlay, Vector3(center.x, center.y, 0.235),
				Vector3(0.023, start.distance_to(end), 0.008), gold)
			strip.rotation.z = (end - start).angle() - PI / 2.0
		_pillar_inlays.append(inlay)


func _build_gate() -> void:
	for side: float in [-1.0, 1.0]:
		_slab(_gate, Vector3(side * 5.4, 3, 0), Vector3(5.2, 6, 0.38), _white)
		_collider(_gate, Vector3(side * 5.4, 12, 0), Vector3(5.2, 24, 0.38))
		_slab(_gate, Vector3(side * 3.24, 2.8, 0.18), Vector3(0.8, 5.6, 0.9), _white, true)
		# Both leaves are already swung toward the passage beyond the lintel.
		_slab(_gate, Vector3(side * 2.98, 2.8, -1.13), Vector3(0.28, 5.6, 2.6), _white, true)
	_slab(_gate, Vector3(0, 5.6, 0.06), Vector3(7.3, 0.66, 0.82), _white, true)
	_world_label(_gate, Vector3(0, 5.6, 0.49), "THRESHOLD / 心智之门", 0.0085)
	_slab(_gate, Vector3(0, 0.008, 0.1), Vector3(5.6, 0.015, 0.21), _white)
	_slab(_gate, Vector3(0, 0.008, -0.65), Vector3(5.6, 0.015, 0.045), _white)


func _build_interface() -> void:
	var ui := CanvasLayer.new()
	ui.name = "HubInterface"
	ui.layer = 10
	add_child(ui)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	center.offset_top = -218
	center.offset_bottom = -162
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(center)
	_prompt = PanelContainer.new()
	_prompt.name = "InteractionPrompt"
	_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt.add_theme_stylebox_override("panel", EditorialStyle.plaque(
		EditorialStyle.PAPER, EditorialStyle.INK, 1, Vector2(3, 3), Color(EditorialStyle.INK, 0.75), 18, 10))
	center.add_child(_prompt)
	_prompt_label = EditorialStyle.make_label("", 22, EditorialStyle.INK, 700)
	_prompt.add_child(_prompt_label)
	_prompt.hide()

	_archive = StasisArchiveModal.new()
	_archive.name = "StasisArchiveModal"
	ui.add_child(_archive)
	var pause_menu := PauseMenu.new()
	pause_menu.name = "PauseMenu"
	ui.add_child(pause_menu)
	if DisplayServer.get_name() != "headless":
		_settings.load_from(GameSettings.settings_path)
	_base_sensitivity = player.mouse_sensitivity
	_settings.changed.connect(_apply_settings)
	_apply_settings()
	pause_menu.setup(_settings, player)
	pause_menu.configure_exit_button(true)
	pause_menu.return_to_title_requested.connect(func(): title_requested.emit())


func _apply_settings() -> void:
	player.set_look_sensitivity(_base_sensitivity * _settings.mouse_sensitivity, _settings.ads_sensitivity)
	KeyBindings.apply(_settings.bindings)


func _refresh_progression() -> void:
	MetaProgression.apply_to_player(player)
	affordable_upgrade = MetaProgression.has_affordable_upgrade()
	_forge_light.light_color = GOLD if affordable_upgrade else WHITE
	_update_forge_visual()

	var archive := MetaProgression.archive_snapshot()
	for realm in REALM_NAMES.size():
		var accent := EditorialStyle.realm_accent(realm)
		_pillar_caps[realm].material_override = CrownModel.material(accent, 0.0, 0.52) \
			if archive.visited_realms.has(realm) else _white
		_pillar_bodies[realm].material_override = CrownModel.material(WHITE.lerp(accent, 0.66), 0.0, 0.62) \
			if archive.defeated_realms.has(realm) else _white
		_pillar_inlays[realm].visible = archive.reconciled


func _update_forge_visual() -> void:
	var pulse := 0.5 + 0.5 * sin(_elapsed * 2.2)
	_forge_crown.position.y = 1.53 + 0.055 * sin(_elapsed * 1.6)
	_forge_crown.rotation.y = _elapsed * 0.32
	_forge_crown.set_emission_strength(lerpf(0.46, 0.96, pulse) if affordable_upgrade else 0.15)
	_forge_light.light_energy = lerpf(0.45, 0.95, pulse) if affordable_upgrade else 0.18


func _physics_process(delta: float) -> void:
	if _departing:
		return
	_elapsed += delta
	_update_forge_visual()

	var point := player.position
	if point.z < _gate.position.z - 0.7 and absf(point.x) < GATE_HALF_WIDTH:
		_request_departure()
		return

	var target := _interaction_target()
	_prompt.visible = target != null
	if target == _altar:
		_prompt_label.text = "[ %s ] 皇冠锻造台" % KeyHint.of("interact")
	elif target == _stele:
		_prompt_label.text = "[ %s ] 心象档案与赐福图鉴" % KeyHint.of("interact")
	elif target == _gate:
		_prompt_label.text = "[ %s ] 穿过心智之门 · 开启挑战" % KeyHint.of("interact")


func _interaction_target() -> Node3D:
	for target: Node3D in [_altar, _stele, _gate]:
		var offset := target.global_position - player.global_position
		if offset.length_squared() > INTERACT_RANGE * INTERACT_RANGE:
			continue
		if target == _gate:
			if absf(offset.x) < GATE_HALF_WIDTH:
				return target
			continue
		var forward := player.view_forward()
		if Vector2(forward.x, forward.z).normalized().dot(Vector2(offset.x, offset.z).normalized()) > 0.45:
			return target
	return null


func _unhandled_input(event: InputEvent) -> void:
	if _departing or not event.is_action_pressed("interact") or event.is_echo():
		return
	var target := _interaction_target()
	if target == null:
		return
	get_viewport().set_input_as_handled()
	_prompt.hide()
	if target == _altar:
		var forge := FORGE.instantiate() as CrownForge
		forge.name = "CrownForge"
		add_child(forge)
		forge.setup(MetaProgression, player)
		forge.closed.connect(_refresh_progression, CONNECT_ONE_SHOT)
	elif target == _stele:
		_archive.setup(MetaProgression.archive_snapshot(), MetaProgression.discovered_boons)
		_archive.try_open()
	else:
		_request_departure()


func _request_departure() -> void:
	if _departing:
		return
	_departing = true
	_prompt.hide()
	departure_requested.emit()


func allow_departure_retry() -> void:
	# Move clear of the automatic trigger if beginning the new run failed.
	if player.position.z < _gate.position.z:
		player.recover_from_fall(_gate.position + Vector3(0, 0.02, 1.4))
	_departing = false


func _slab(parent: Node3D, point: Vector3, size: Vector3, material: Material,
		solid := false) -> MeshInstance3D:
	var slab := CrownModel.slab(size, material)
	slab.position = point
	parent.add_child(slab)
	if solid:
		_collider(parent, point, size)
	return slab


func _collider(parent: Node3D, point: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = point
	body.collision_layer = CollisionLayers.WORLD
	body.collision_mask = 0
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	parent.add_child(body)


func _facet(parent: Node3D, point: Vector3, top: float, bottom: float, height: float,
		sides: int, material: Material) -> MeshInstance3D:
	var mesh := SurfaceTool.new()
	mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	mesh.set_smooth_group(-1)
	var rise := Vector3.UP * height * 0.5
	for index in sides:
		var angle := TAU * index / sides
		var next := TAU * (index + 1) / sides
		var from := Vector3(cos(angle), 0, sin(angle))
		var to := Vector3(cos(next), 0, sin(next))
		var a := from * bottom - rise
		var b := to * bottom - rise
		var c := to * top + rise
		var d := from * top + rise
		for vertex: Vector3 in [a, b, c, a, c, d, rise, d, c, -rise, b, a]:
			mesh.add_vertex(vertex)
	mesh.generate_normals()
	var instance := MeshInstance3D.new()
	instance.mesh = mesh.commit()
	instance.material_override = material
	instance.position = point
	parent.add_child(instance)
	return instance


func _world_label(parent: Node3D, point: Vector3, content: String, pixel_size: float) -> void:
	var label := Label3D.new()
	label.text = content
	label.font = EditorialStyle.font_sans(700)
	label.font_size = 40
	label.pixel_size = pixel_size
	label.outline_size = 0
	label.modulate = EditorialStyle.INK
	label.position = point
	parent.add_child(label)
