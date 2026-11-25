class_name PsycheShardPickup
extends Node3D
## Physical world pickup: injected player, WORLD line of sight, one award only.
## Visuals are built in script so PsycheShardPickup.new() stays a complete shard.
signal collected(realm: int)
const TITLES := ["沉睡的碎片", "警醒的碎片", "锋芒的碎片", "温润的碎片"]
const CORE_SHADER := preload("res://assets/materials/psyche_shard_crystal.gdshader")
const HALO_SHADER := preload("res://assets/materials/psyche_shard_halo.gdshader")
const BLADE_VARIANTS := [0, 1, 2, 1]
const BLADE_REST_Y := [0.012, -0.026, 0.030, -0.008]
const BLADE_LEAN := [-0.10, 0.08, -0.06, 0.12]
const BLADE_TILT := [0.06, -0.10, 0.12, -0.05]

## Realm optics derived from the shared boon palette: bright cut core, deep
## mantle, crisp rim, emissive halo. Indexed 0..3 (Sloth / Fear / Wrath / Sorrow).
static var REALM_PROFILES: Array[Dictionary] = _build_realm_profiles()

@export_enum("Sloth","Fear","Wrath","Sorrow") var realm := 0:
	set(value):
		realm = clampi(value, 0, 3)
		if is_node_ready():
			_apply_realm_profile()
@export var pickup_radius := 1.3:
	set(value):
		pickup_radius = value
		if is_node_ready():
			_sync_halo_size()
var player: Player
var consumed := false

var _visual_root: Node3D
var _core: MeshInstance3D
var _mantle_pivot: Node3D
var _blades: Array[MeshInstance3D] = []
var _blade_rest: Array[Vector3] = []
var _blade_outward: Array[Vector3] = []
var _splinter_pivot: Node3D
var _splinters: Array[MeshInstance3D] = []
var _halo: MeshInstance3D
var _base_ring: MeshInstance3D
var _aura: OmniLight3D
var _label: Label3D
var _core_material: ShaderMaterial
var _mantle_material: ShaderMaterial
var _ring_material: ShaderMaterial
var _halo_material: ShaderMaterial
var _age := 0.0
var _pulse_time := 0.0
var _proximity := 0.0


static func _build_realm_profiles() -> Array[Dictionary]:
	var profiles: Array[Dictionary] = []
	for index in BoonIdentity.COLORS.size():
		var tint: Color = BoonIdentity.COLORS[index]
		var hue := tint.h
		var rich_sat := clampf(maxf(tint.s * 1.38, 0.78), 0.0, 1.0)
		var value := tint.v
		profiles.append({
			"core_color": Color.from_hsv(hue, clampf(rich_sat * 1.06, 0.0, 1.0), value * 0.84),
			"mantle_color": Color.from_hsv(hue, clampf(rich_sat * 1.08, 0.0, 1.0), value * 0.36),
			"rim_color": Color.from_hsv(hue, clampf(tint.s * 1.15, 0.0, 1.0), 1.0),
			"spec_color": Color.from_hsv(hue, clampf(tint.s * 0.65, 0.0, 1.0), 1.0),
			"halo_color": tint,
			"emission_strength": [0.40, 0.46, 0.44, 0.38][index],
			"inner_glow": [0.24, 0.30, 0.28, 0.24][index],
		})
	return profiles


func setup(value: Player) -> void:
	player = value


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_build_visuals()
	_apply_realm_profile()


func _process(delta: float) -> void:
	if consumed:
		return
	_age += delta
	_pulse_time += delta * (1.0 + _proximity * 0.60)
	var live := _player_alive()
	var target := 0.0
	if live and pickup_radius > 0.0:
		var reach := pickup_radius * 2.8
		target = clampf(1.0 - player.global_position.distance_to(global_position) / reach, 0.0, 1.0)
		target = target * target * (3.0 - 2.0 * target)
	_proximity = move_toward(_proximity, target, delta * 2.4)

	_visual_root.position.y = 0.92 + sin(_age * 1.55) * 0.055 \
		+ sin(_age * 2.7 + 1.1) * 0.012 + _proximity * 0.022
	_visual_root.rotation.y = _age * 0.22
	_core.rotation.y = _age * 0.50
	_core.scale = Vector3.ONE * (1.0 + sin(_pulse_time * 2.1) * 0.015 + _proximity * 0.03)
	_mantle_pivot.rotation.y = -_age * 0.34
	_mantle_pivot.rotation.x = sin(_age * 0.8) * 0.035

	for index in _blades.size():
		var blade := _blades[index]
		blade.position = _blade_rest[index] + _blade_outward[index] * (0.042 * _proximity) \
			+ Vector3(0.0, sin(_age * 1.25 + float(index) * 1.7) * 0.012, 0.0)
		blade.rotation.x = BLADE_LEAN[index] + sin(_age * 0.9 + float(index) * 2.1) * 0.035

	for index in _splinters.size():
		var phase := _age * 0.75 + float(index) * PsycheShardMesh.GOLDEN
		var radius := 0.30 + 0.045 * sin(float(index) * PsycheShardMesh.GOLDEN + 1.0) \
			+ sin(_age * 0.6 + float(index) * 1.3) * 0.028
		var height := sin(_age * 0.85 + float(index) * 2.1) * 0.075 + float(index % 3 - 1) * 0.030
		_splinters[index].position = Vector3(cos(phase) * radius, height, sin(phase) * radius)
		_splinters[index].rotation = Vector3(phase * 1.1, phase * 0.7 + float(index), phase * 0.4)

	_push_motion_uniforms()


func _physics_process(_delta: float) -> void:
	if consumed:
		return
	try_collect()


func try_collect() -> bool:
	if consumed or not _player_alive() or get_tree().paused:
		return false
	if player.global_position.distance_to(global_position) > pickup_radius:
		return false
	if not player.boons.line_clear(player.global_position + Vector3.UP * 0.8, global_position + Vector3.UP * 0.8):
		return false
	if not player.fragments.acquire(realm):
		return false
	consumed = true
	hide()
	collected.emit(realm)
	_spawn_pickup_feedback()
	queue_free()
	return true


func _player_alive() -> bool:
	return is_instance_valid(player) and player.is_node_ready() and not player.health.is_dead()


# --- hierarchy ---------------------------------------------------------------

func _build_visuals() -> void:
	_core_material = ShaderMaterial.new()
	_core_material.shader = CORE_SHADER
	_mantle_material = ShaderMaterial.new()
	_mantle_material.shader = CORE_SHADER
	_ring_material = ShaderMaterial.new()
	_ring_material.shader = CORE_SHADER
	_halo_material = ShaderMaterial.new()
	_halo_material.shader = HALO_SHADER

	_visual_root = Node3D.new()
	_visual_root.name = "VisualRoot"
	_visual_root.position.y = 0.92
	add_child(_visual_root)

	_core = MeshInstance3D.new()
	_core.name = "CoreMesh"
	_core.mesh = PsycheShardMesh.core_mesh()
	_core.material_override = _core_material
	_visual_root.add_child(_core)

	_mantle_pivot = Node3D.new()
	_mantle_pivot.name = "MantlePivot"
	_visual_root.add_child(_mantle_pivot)
	for index in 4:
		var angle := float(index) * TAU / 4.0 + 0.55
		var blade := MeshInstance3D.new()
		blade.name = "MantleBlade%d" % index
		blade.mesh = PsycheShardMesh.mantle_blade_mesh(BLADE_VARIANTS[index])
		blade.material_override = _mantle_material
		var rest := Vector3(cos(angle) * 0.22, BLADE_REST_Y[index], sin(angle) * 0.22)
		blade.position = rest
		blade.rotation = Vector3(BLADE_LEAN[index], PI * 0.5 - angle, BLADE_TILT[index])
		_mantle_pivot.add_child(blade)
		_blades.append(blade)
		_blade_rest.append(rest)
		_blade_outward.append(Vector3(cos(angle), 0.0, sin(angle)))

	_splinter_pivot = Node3D.new()
	_splinter_pivot.name = "SplinterPivot"
	_visual_root.add_child(_splinter_pivot)
	for index in 6:
		var splinter := MeshInstance3D.new()
		splinter.name = "Splinter%d" % index
		splinter.mesh = PsycheShardMesh.splinter_mesh()
		splinter.material_override = _core_material
		splinter.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_splinter_pivot.add_child(splinter)
		_splinters.append(splinter)

	_halo = MeshInstance3D.new()
	_halo.name = "GroundHalo"
	_halo.mesh = QuadMesh.new()
	_halo.material_override = _halo_material
	_halo.rotation.x = -PI * 0.5
	_halo.position.y = 0.025
	_halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_halo)
	_sync_halo_size()

	_base_ring = MeshInstance3D.new()
	_base_ring.name = "BaseRing"
	_base_ring.mesh = PsycheShardMesh.base_ring_mesh()
	_base_ring.material_override = _ring_material
	_base_ring.position.y = 0.04
	add_child(_base_ring)

	_aura = OmniLight3D.new()
	_aura.name = "AuraLight"
	_aura.position.y = 0.95
	_aura.omni_range = 4.2
	_aura.omni_attenuation = 1.35
	_aura.light_energy = 1.0
	_aura.light_specular = 0.35
	_aura.shadow_enabled = false
	add_child(_aura)

	_label = Label3D.new()
	_label.name = "Label3D"
	_label.position.y = 1.72
	_label.pixel_size = 0.0032
	_label.font_size = 40
	_label.outline_size = 10
	_label.outline_modulate = Color(0.03, 0.04, 0.06, 0.92)
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(_label)

	_push_motion_uniforms()


func _apply_realm_profile() -> void:
	if not is_node_ready() or _core_material == null:
		return
	var index := clampi(realm, 0, 3)
	var profile: Dictionary = REALM_PROFILES[index]
	var core_color: Color = profile["core_color"]
	var mantle_color: Color = profile["mantle_color"]
	var rim_color: Color = profile["rim_color"]
	var spec_color: Color = profile["spec_color"]
	var halo_color: Color = profile["halo_color"]
	var emission: float = profile["emission_strength"]
	var glow: float = profile["inner_glow"]

	_core_material.set_shader_parameter("base_color", core_color)
	_core_material.set_shader_parameter("emission_color", core_color)
	_core_material.set_shader_parameter("emission_strength", emission)
	_core_material.set_shader_parameter("rim_color", rim_color)
	_core_material.set_shader_parameter("rim_strength", 0.56)
	_core_material.set_shader_parameter("rim_power", 2.6)
	_core_material.set_shader_parameter("spec_color", spec_color)
	_core_material.set_shader_parameter("specular_amount", 0.32)
	_core_material.set_shader_parameter("roughness_value", 0.28)
	_core_material.set_shader_parameter("inner_glow", glow)
	_core_material.set_shader_parameter("pulse_strength", 0.14)
	_core_material.set_shader_parameter("facet_glint", 0.58)
	_core_material.set_shader_parameter("coat_strength", 0.18)
	_core_material.set_shader_parameter("body_emission", 0.92)

	_mantle_material.set_shader_parameter("base_color", mantle_color)
	_mantle_material.set_shader_parameter("emission_color", mantle_color)
	_mantle_material.set_shader_parameter("emission_strength", emission * 0.28)
	_mantle_material.set_shader_parameter("rim_color", rim_color)
	_mantle_material.set_shader_parameter("rim_strength", 0.54)
	_mantle_material.set_shader_parameter("rim_power", 2.9)
	_mantle_material.set_shader_parameter("spec_color", spec_color)
	_mantle_material.set_shader_parameter("specular_amount", 0.24)
	_mantle_material.set_shader_parameter("roughness_value", 0.34)
	_mantle_material.set_shader_parameter("inner_glow", glow * 0.38)
	_mantle_material.set_shader_parameter("pulse_strength", 0.08)
	_mantle_material.set_shader_parameter("facet_glint", 0.42)
	_mantle_material.set_shader_parameter("coat_strength", 0.12)
	_mantle_material.set_shader_parameter("body_emission", 0.86)

	_ring_material.set_shader_parameter("base_color", mantle_color.darkened(0.55))
	_ring_material.set_shader_parameter("emission_color", mantle_color.darkened(0.40))
	_ring_material.set_shader_parameter("emission_strength", 0.06)
	_ring_material.set_shader_parameter("rim_color", rim_color)
	_ring_material.set_shader_parameter("rim_strength", 0.42)
	_ring_material.set_shader_parameter("rim_power", 3.4)
	_ring_material.set_shader_parameter("spec_color", spec_color)
	_ring_material.set_shader_parameter("specular_amount", 0.25)
	_ring_material.set_shader_parameter("roughness_value", 0.42)
	_ring_material.set_shader_parameter("inner_glow", 0.0)
	_ring_material.set_shader_parameter("pulse_strength", 0.04)
	_ring_material.set_shader_parameter("facet_glint", 0.12)
	_ring_material.set_shader_parameter("coat_strength", 0.22)
	_ring_material.set_shader_parameter("body_emission", 0.25)

	_halo_material.set_shader_parameter("halo_color", halo_color)
	_halo_material.set_shader_parameter("accent_color", rim_color)
	_halo_material.set_shader_parameter("opacity", 0.85)

	_aura.light_color = halo_color
	_label.text = TITLES[index] + "\n走近拾取"
	_label.modulate = rim_color
	_push_motion_uniforms()


func _sync_halo_size() -> void:
	if _halo == null or _halo.mesh is not QuadMesh:
		return
	var valid := pickup_radius > 0.0
	_halo.visible = valid
	if valid:
		(_halo.mesh as QuadMesh).size = Vector2.ONE * (pickup_radius * 2.15)
	else:
		_proximity = 0.0
		_push_motion_uniforms()


func _push_motion_uniforms() -> void:
	if _core_material == null:
		return
	var materials: Array[ShaderMaterial] = [_core_material, _mantle_material, _ring_material, _halo_material]
	for material in materials:
		material.set_shader_parameter("pulse_time", _pulse_time)
		material.set_shader_parameter("proximity_boost", _proximity)


# --- pickup feedback ---------------------------------------------------------

func _spawn_pickup_feedback() -> void:
	var parent := get_parent()
	if not is_instance_valid(parent) or not parent.is_inside_tree():
		return
	var profile: Dictionary = REALM_PROFILES[clampi(realm, 0, 3)]
	var color: Color = profile["halo_color"]
	var pulse := _PickupPulse.new()
	pulse.name = "PsycheShardPulse"
	parent.add_child(pulse)
	pulse.global_position = global_position
	pulse.setup(color)
	if parent.has_meta("crystal_emitter_pool"):
		CrystalBurst.spawn(parent, global_position + Vector3.UP * 0.9, clampi(realm, 0, 3), &"death")


## Small self-contained burst that outlives the pickup: an expanding faceted
## ring plus a brief light flash. No RNG, no GPU particles, frees in 0.42 s.
class _PickupPulse extends Node3D:
	const DURATION := 0.42
	var elapsed := 0.0
	var ring: MeshInstance3D
	var flash: OmniLight3D
	var ring_material: StandardMaterial3D

	func setup(color: Color) -> void:
		process_mode = Node.PROCESS_MODE_PAUSABLE
		ring = MeshInstance3D.new()
		ring.name = "PulseRing"
		ring.mesh = PsycheShardMesh.base_ring_mesh()
		ring_material = StandardMaterial3D.new()
		ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		ring_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		ring_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		ring_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		ring_material.albedo_color = Color(color.r, color.g, color.b, 0.85)
		ring_material.emission_enabled = true
		ring_material.emission = color
		ring_material.emission_energy_multiplier = 1.4
		ring.material_override = ring_material
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ring.position.y = 0.05
		add_child(ring)

		flash = OmniLight3D.new()
		flash.name = "PulseFlash"
		flash.light_color = color
		flash.light_energy = 2.4
		flash.omni_range = 3.4
		flash.shadow_enabled = false
		flash.position.y = 0.45
		add_child(flash)

	func _process(delta: float) -> void:
		elapsed += delta
		var t := clampf(elapsed / DURATION, 0.0, 1.0)
		if is_instance_valid(ring):
			var spread := 1.0 + 1.75 * (1.0 - pow(1.0 - t, 2.0))
			ring.scale = Vector3.ONE * spread
			ring.position.y = 0.05 + t * 0.02
			ring_material.albedo_color.a = (1.0 - t) * 0.85
		if is_instance_valid(flash):
			flash.light_energy = 2.4 * pow(1.0 - t, 2.4)
		if t >= 1.0:
			queue_free()
