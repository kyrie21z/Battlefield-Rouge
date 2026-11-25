class_name TalentOrb
extends Node3D
## The reclaimed-talent orb: a faceted obsidian geode whose aperture always turns
## toward the player, with a realm-lit cut-crystal core, an octagonal ground halo
## and crystal motes drifting inside the shell.
##
## Every motion is driven by SimClock, never by wall-clock time, so a fixture
## replays the exact same frames (Cut-001b AC-07). Because SimClock counts
## physics frames, pausing the tree also freezes the orb for free.

const SHELL_SCENE := preload("res://objects/talent_orb/orb_shell.glb")
const CORE_SCENE := preload("res://objects/talent_orb/orb_core.glb")
const SHELL_SHADER := preload("res://assets/materials/talent_orb_shell.gdshader")
const CORE_SHADER := preload("res://assets/materials/psyche_shard_crystal.gdshader")
const HALO_SHADER := preload("res://assets/materials/psyche_shard_halo.gdshader")

## Where the crystal core sits relative to the orb centre, along the mouth axis.
const CORE_FORWARD := -0.205

## How close the player has to be for interact to claim the talent.
const INTERACT_RANGE := 2.8

## HDR colour a scattered piece glows with before it cools back to its material.
const PIECE_GLOW := Color(1.6, 1.15, 0.62)

## Timing of the arrival sequence. assembly_seconds() combines these, so the zone
## can pop the cube in exactly when the shell is whole.
const PIECE_STEP := 0.020
const ASSEMBLE_START := 0.70
const ASSEMBLE_TIME := 1.60

## Heat pushed into a fresh shell shard, then drained to zero by assemble().
const SCATTER_HEAT := 2.8
## Seam strength for the crystal inlays that fill the aperture and plate notches.
const SEAM_GLOW := 0.95
## Golden angle the scatter and the mote orbit both step by; index driven, no RNG.
const GOLDEN := 2.399963

const MOTE_COUNT := 8
const HALO_SIZE := 2.35
const HALO_LIFT := 0.03
const AURA_ENERGY := 1.05
const HALO_OPACITY := 0.85

## Cut-crystal tuning for the core gem and for its detached bladelets. Both ride
## the psyche_shard_crystal shader; the bladelets sit darker and glossier so they
## flash as specular glints while the gem body carries the realm colour.
const CORE_TUNING := {
	"base_darken": 0.0, "emission_scale": 1.0, "rim_strength": 0.56,
	"rim_power": 2.6, "specular_amount": 0.32, "roughness_value": 0.28,
	"pulse_strength": 0.14, "facet_glint": 0.58, "coat_strength": 0.18,
	"body_emission": 0.92,
}
const SHARD_TUNING := {
	"base_darken": 0.22, "emission_scale": 0.78, "rim_strength": 0.86,
	"rim_power": 3.1, "specular_amount": 0.44, "roughness_value": 0.18,
	"pulse_strength": 0.10, "facet_glint": 0.88, "coat_strength": 0.42,
	"body_emission": 0.72,
}

@export var bob_height := 0.16
@export var bob_speed := 0.9
@export var turn_speed := 2.2
@export var cube_spin := 0.55
@export var cube_tumble := 0.32
@export var base_height := 1.28

var _shell: Node3D
var _core: Node3D
var _mote_pivot: Node3D
var _body: StaticBody3D
var _ground_halo: MeshInstance3D
var _aura: OmniLight3D
var _player_ref: WeakRef
var _accent := Color(1.0, 0.62, 0.18)
var _ground_height := 0.0
var _bob_enabled := true
var _bob_phase := 0.0
var _bob_clock := 0.0
var _energy := 1.0
var _core_visible := true
var _collision_on := true
var _pieces: Array[Dictionary] = []
var _piece_count := 0
var _shell_meshes: Array[MeshInstance3D] = []
var _shell_materials: Array[ShaderMaterial] = []
var _heat := PackedFloat32Array()
var _core_meshes: Array[MeshInstance3D] = []
var _motes: Array[MeshInstance3D] = []
var _core_material: ShaderMaterial
var _core_shard_material: ShaderMaterial
var _halo_material: ShaderMaterial
var _anim_reveal := false
var _reveal_start := 0.0
var _reveal_fade := 0.85
var _anim_assemble := false
var _assemble_start := 0.0
var _assemble_duration := ASSEMBLE_TIME


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	prepare()
	_sync_ground_halo()


func prepare() -> void:
	_build_models()
	_build_collision()


## Floor height under the orb, in the parent's space. base_height stays the
## hover offset above it, so a raised landing lifts the whole rig instead of
## burying it in the masonry below the door.
func set_ground_height(height: float) -> void:
	_ground_height = height
	_sync_ground_halo()


func hover_height() -> float:
	return _ground_height + base_height


## Realm optics for any accent, on the same HSV curve PsycheShardPickup bakes for
## the four boons. Keeps the cut core rich and saturated instead of clipping to
## flat white under bright realm lighting.
static func _profile_for_accent(accent: Color) -> Dictionary:
	var hue := accent.h
	var rich_sat := clampf(maxf(accent.s * 1.38, 0.78), 0.0, 1.0)
	var value := accent.v
	var index := BoonIdentity.COLORS.find(accent)
	return {
		"core_color": Color.from_hsv(hue, clampf(rich_sat * 1.06, 0.0, 1.0), value * 0.84),
		"mantle_color": Color.from_hsv(hue, clampf(rich_sat * 1.08, 0.0, 1.0), value * 0.36),
		"rim_color": Color.from_hsv(hue, clampf(accent.s * 1.15, 0.0, 1.0), 1.0),
		"spec_color": Color.from_hsv(hue, clampf(accent.s * 0.65, 0.0, 1.0), 1.0),
		"halo_color": accent,
		"emission_strength": [0.40, 0.46, 0.44, 0.38][index] if index >= 0 else 0.42,
		"inner_glow": [0.24, 0.30, 0.28, 0.24][index] if index >= 0 else 0.26,
	}


# --- hierarchy ---------------------------------------------------------------

func _build_models() -> void:
	if _shell != null:
		return
	_shell = SHELL_SCENE.instantiate() as Node3D
	add_child(_shell)
	_shell_meshes.clear()
	_shell_materials.clear()
	for node in _shell.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi == null:
			continue
		var mat := ShaderMaterial.new()
		mat.shader = SHELL_SHADER
		mat.set_shader_parameter("seam_glow", SEAM_GLOW if _is_inlay(mi.name) else 0.0)
		mat.set_shader_parameter("cavity", 1.0 if _is_cavity(mi.name) else 0.0)
		mat.set_shader_parameter("accent_rim", 0.28)
		mi.material_override = mat
		_shell_meshes.append(mi)
		_shell_materials.append(mat)
	_heat.resize(_shell_materials.size())
	_heat.fill(0.0)

	_core = CORE_SCENE.instantiate() as Node3D
	_core.position = Vector3(0.0, 0.0, CORE_FORWARD)
	add_child(_core)
	_core_material = ShaderMaterial.new()
	_core_material.shader = CORE_SHADER
	_core_shard_material = ShaderMaterial.new()
	_core_shard_material.shader = CORE_SHADER
	_core_meshes.clear()
	for node in _core.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi == null:
			continue
		mi.material_override = _core_shard_material if mi.name.begins_with("CORE_shard_") else _core_material
		_core_meshes.append(mi)

	_mote_pivot = Node3D.new()
	_mote_pivot.name = "Motes"
	_mote_pivot.position = Vector3(0.0, 0.0, CORE_FORWARD)
	add_child(_mote_pivot)
	_motes.clear()
	for index in MOTE_COUNT:
		var mote := MeshInstance3D.new()
		mote.name = "Mote%d" % index
		mote.mesh = PsycheShardMesh.splinter_mesh()
		mote.material_override = _core_material
		mote.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_mote_pivot.add_child(mote)
		_motes.append(mote)

	_halo_material = ShaderMaterial.new()
	_halo_material.shader = HALO_SHADER
	_ground_halo = MeshInstance3D.new()
	_ground_halo.name = "GroundHalo"
	var quad := QuadMesh.new()
	quad.size = Vector2(HALO_SIZE, HALO_SIZE)
	_ground_halo.mesh = quad
	_ground_halo.material_override = _halo_material
	_ground_halo.rotation.x = -PI * 0.5
	_ground_halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ground_halo)

	_aura = OmniLight3D.new()
	_aura.name = "AuraLight"
	_aura.position = Vector3(0.0, 0.0, CORE_FORWARD)
	_aura.omni_range = 4.0
	_aura.omni_attenuation = 1.4
	_aura.light_energy = AURA_ENERGY
	_aura.shadow_enabled = false
	add_child(_aura)

	_apply_accent()


static func _is_inlay(piece_name: String) -> bool:
	return piece_name.begins_with("INSET_") or piece_name.begins_with("SHROUD_lamp_")


## Interior bowl steps stay a black void; only the outer armour mirrors the studio.
static func _is_cavity(piece_name: String) -> bool:
	return piece_name.begins_with("SHELL_backcap") or piece_name.begins_with("SHELL_under_") \
		or piece_name.begins_with("SHELL_band_")


## Solid body so the orb reads as a real object: the player cannot walk through it
## and bullets stop on it. It sits on WORLD, which is what player rays and
## projectiles already test. The radius is a touch under the visual shell so the
## plates still poke out, and it stays well inside INTERACT_RANGE so you can
## always reach the orb even while standing against it.
func _build_collision() -> void:
	if _body != null:
		return
	_body = StaticBody3D.new()
	_body.name = "Body"
	_body.collision_layer = CollisionLayers.WORLD
	_body.collision_mask = CollisionLayers.NONE
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.52
	shape.shape = sphere
	_body.add_child(shape)
	add_child(_body)


## Turns the solid body off the moment the orb is claimed, so the shrink animation
## cannot leave an invisible wall behind. The ground ring and the aura go with it:
## the claim tween lifts and shrinks the rig, and a floor sigil riding that rise
## would peel off the masonry and hang in the air.
func set_collision_enabled(value: bool) -> void:
	_collision_on = value
	if _body != null:
		_body.collision_layer = CollisionLayers.WORLD if value else CollisionLayers.NONE
	if _ground_halo != null:
		_ground_halo.visible = value
	if _aura != null:
		_aura.visible = value and _core_visible


## The zone director injects the player; the orb never searches the tree for it.
func set_player(player: Node3D) -> void:
	_player_ref = weakref(player)


func player_in_range(player: Node3D) -> bool:
	if player == null or not is_instance_valid(player):
		return false
	return global_position.distance_to(player.global_position) <= INTERACT_RANGE


## True while the cube is still turning - the zone uses it to gate the prompt.
func is_ready() -> bool:
	return _bob_enabled


## Blows the whole shell apart - every mesh piece takes part, big ones included.
## Each piece keeps its own material, so the zone can reveal them one at a time
## and drain the scatter heat back to the realm accent.
## Large parts only drift a short way so they don't read as debris crossing the
## room, while the bolted-on inlays scatter further.
## Everything is deterministic (index-driven golden angle, no randf), so a fixture
## replay assembles into the identical pose (AC-07).
func scatter(radius: float = 1.9) -> void:
	_pieces.clear()
	_anim_reveal = false
	_anim_assemble = false
	if _shell == null:
		return
	var count := _shell_meshes.size()
	for i in count:
		var mi := _shell_meshes[i]
		if mi == null or not is_instance_valid(mi):
			continue
		var target := mi.transform
		# big shells barely move; small inlays fly further out
		var extent := mi.get_aabb().size.length()
		var weight := clampf(1.15 - extent * 0.55, 0.22, 1.0)
		var ang := float(i) * GOLDEN
		var tilt := float(i % 11) * 0.33
		var dir := Vector3(cos(ang) * cos(tilt), 0.26 + sin(tilt) * 0.55, sin(ang) * cos(tilt)).normalized()
		var spread := radius * weight * (0.6 + 0.4 * float(i % 5) / 4.0)
		var basis := target.basis.rotated(Vector3.UP, ang * 1.7).rotated(Vector3.RIGHT, tilt)
		mi.transform = Transform3D(basis.scaled(Vector3.ONE * lerpf(1.0, 0.78, weight)), target.origin + dir * spread)

		_set_heat(i, SCATTER_HEAT)
		# it starts fully transparent far out in the void, well past its scatter
		# position, and drifts in while fading up
		var home := mi.transform
		var far := Transform3D(home.basis, home.origin + dir * spread * 2.0)
		mi.transform = far
		mi.transparency = 1.0
		mi.visible = true
		# one shared schedule per piece: it starts fading in at `reveal` and starts
		# flying home a moment later, so no piece ever hovers waiting for the rest
		var slot := float(i) * PIECE_STEP
		_pieces.append({
			"index": i,
			"node": mi,
			"target": target,
			"home": home,
			"far": far,
			"slot": slot,
		})
	# every mesh takes part, so the count is the full piece total - assembly_seconds()
	# needs it to report the real duration
	_piece_count = _pieces.size()


## Brings the pieces out of the void: each one drifts in from far away while its
## opacity comes up, one after another - never all at once. Returns how long the
## whole reveal takes so the zone can chain the assembly right after it.
func reveal_pieces(fade: float = 0.85) -> float:
	if _pieces.is_empty():
		return 0.0
	_reveal_start = SimClock.now()
	_reveal_fade = maxf(fade, 0.001)
	_anim_reveal = true
	return float(_piece_count - 1) * PIECE_STEP + fade


## Flies every scattered piece back to its authored pose while its scatter heat
## drains away, so each piece settles on its own obsidian facet again.
func assemble(duration: float = ASSEMBLE_TIME, start_delay: float = ASSEMBLE_START) -> void:
	if _pieces.is_empty():
		return
	_assemble_start = SimClock.now() + start_delay
	_assemble_duration = maxf(duration, 0.001)
	_anim_assemble = true


## How long the whole reveal-then-assemble sequence runs. The zone uses it to line
## its light show up with the shell, and to pop the cube in the moment the shell is
## whole instead of waiting for the slowest fade.
## Must stay in sync with PIECE_STEP, ASSEMBLE_START and ASSEMBLE_TIME.
func assembly_seconds() -> float:
	return float(_piece_count) * PIECE_STEP + ASSEMBLE_START + ASSEMBLE_TIME


## Hides or shows the glowing core, its orbiting motes and its aura. The zone
## keeps them hidden while the shell is still flying together.
func set_core_visible(value: bool) -> void:
	_core_visible = value
	if _core != null:
		_core.visible = value
	if _mote_pivot != null:
		_mote_pivot.visible = value
	if _aura != null:
		_aura.visible = value and _collision_on


## Pops the core in with a small overshoot instead of hard-switching it on.
func fade_core_in(duration: float = 0.55) -> void:
	if _core == null:
		return
	set_core_visible(true)
	_core.scale = Vector3.ONE * 0.45
	var tween := create_tween()
	tween.tween_property(_core, "scale", Vector3.ONE, duration) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Freezes the idle motion during the arrival / absorb animation so the tween owns
## the transform instead of fighting _process.
##
## Turning it back on picks the bob phase up from wherever the orb currently sits,
## so the height never jumps when the assembly finishes (that snap was the small
## sideways step visible at the end of the animation).
func set_idle_enabled(value: bool) -> void:
	if value and not _bob_enabled:
		var offset := (position.y - hover_height()) / maxf(bob_height, 0.0001)
		_bob_phase = asin(clampf(offset, -1.0, 1.0))
		_bob_clock = SimClock.now()
	_bob_enabled = value


## Recolours the seam inlays, the crystal core, the motes, the aura and the ground
## halo so the orb matches the realm being offered. Called by the zone when the
## reward identity is known.
func set_accent(accent: Color) -> void:
	_accent = accent
	_apply_accent()


## Brightness of the whole rig, 1 = normal. Used to dim the orb while it fades in.
func set_energy(scale: float) -> void:
	_energy = clampf(scale, 0.0, 1.0)
	var fade := 1.0 - _energy
	for mi in _shell_meshes:
		mi.transparency = fade
	for mi in _core_meshes:
		mi.transparency = fade
	for mote in _motes:
		mote.transparency = fade
	for mat in _shell_materials:
		mat.set_shader_parameter("energy_scale", _energy)
	if _ground_halo != null:
		_ground_halo.transparency = fade
	if _halo_material != null:
		_halo_material.set_shader_parameter("opacity", HALO_OPACITY * _energy)
	if _aura != null:
		_aura.light_energy = AURA_ENERGY * _energy


# --- frame loop --------------------------------------------------------------

func _process(_delta: float) -> void:
	var t := SimClock.now()

	if _anim_reveal or _anim_assemble:
		_step_pieces(t)

	if _bob_enabled:
		# phase-locked so switching idle motion back on never snaps the height:
		# at the moment it resumes, sin() evaluates to wherever the orb already is
		position.y = hover_height() + sin((t - _bob_clock) * bob_speed + _bob_phase) * bob_height
	_turn_toward_player()
	_sync_ground_halo()

	if _core != null:
		_core.rotation.y = t * cube_spin
		_core.rotation.x = sin(t * cube_spin * 0.7) * cube_tumble
	_orbit_motes(t)
	_push_pulse(t)


## The ring belongs to the floor, not to the rig: it is re-pinned every frame so
## bobbing, a raised landing under the gate or the claim rise never drags it off
## the ground.
func _sync_ground_halo() -> void:
	if _ground_halo == null:
		return
	_ground_halo.position = Vector3(0.0, _ground_height - position.y + HALO_LIFT, 0.0)


## The motes circle the gem inside the aperture, just clear of its facets and
## just inside the lip, so they read as splinters drifting in the mouth instead
## of debris flying in front of the orb.
func _orbit_motes(t: float) -> void:
	for index in _motes.size():
		var phase := t * 0.55 + float(index) * GOLDEN
		var radius := 0.228 + 0.010 * sin(float(index) * GOLDEN + 1.0)
		var height := sin(t * 0.8 + float(index) * 2.1) * 0.062
		var mote := _motes[index]
		mote.position = Vector3(cos(phase) * radius, height, sin(phase) * radius)
		mote.rotation = Vector3(phase * 1.1, phase * 0.7 + float(index), phase * 0.5)


## Every shader pulse is fed from SimClock, so the whole rig freezes with the tree.
func _push_pulse(t: float) -> void:
	var proximity := _player_proximity()
	for mat in _shell_materials:
		mat.set_shader_parameter("pulse_time", t)
	if _core_material != null:
		_core_material.set_shader_parameter("pulse_time", t)
		_core_material.set_shader_parameter("proximity_boost", proximity)
	if _core_shard_material != null:
		_core_shard_material.set_shader_parameter("pulse_time", t)
		_core_shard_material.set_shader_parameter("proximity_boost", proximity)
	if _halo_material != null:
		_halo_material.set_shader_parameter("pulse_time", t)
		_halo_material.set_shader_parameter("proximity_boost", proximity)


func _player_proximity() -> float:
	if not _collision_on or _player_ref == null:
		return 0.0
	var player := _player_ref.get_ref() as Node3D
	if player == null or not is_instance_valid(player):
		return 0.0
	var reach := INTERACT_RANGE * 2.2
	var raw := clampf(1.0 - global_position.distance_to(player.global_position) / reach, 0.0, 1.0)
	return raw * raw * (3.0 - 2.0 * raw)


func _step_pieces(t: float) -> void:
	var reveal_done := true
	var assemble_done := true
	for entry in _pieces:
		var mi := entry["node"] as MeshInstance3D
		if mi == null or not is_instance_valid(mi):
			continue
		var index: int = entry["index"]
		var slot: float = entry["slot"]
		var assembling_this := false
		if _anim_assemble:
			var dt := t - (_assemble_start + slot)
			if dt >= 0.0:
				assembling_this = true
				var v := clampf(dt / _assemble_duration, 0.0, 1.0)
				var home_xf: Transform3D = entry["home"]
				var target_xf: Transform3D = entry["target"]
				if v >= 1.0:
					mi.transform = target_xf
				else:
					var vm1 := v - 1.0
					var w := 1.0 + 2.70158 * vm1 * vm1 * vm1 + 1.70158 * vm1 * vm1
					var origin := home_xf.origin.lerp(target_xf.origin, w)
					var rot := home_xf.basis.orthonormalized().get_rotation_quaternion().slerp(
						target_xf.basis.orthonormalized().get_rotation_quaternion(), clampf(w, 0.0, 1.0))
					var sc := home_xf.basis.get_scale().lerp(target_xf.basis.get_scale(), w)
					mi.transform = Transform3D(Basis(rot).scaled_local(sc), origin)
				var vc := clampf(dt / (_assemble_duration * 1.2), 0.0, 1.0)
				_set_heat(index, SCATTER_HEAT * clampf(0.5 + 0.5 * cos(PI * vc), 0.0, 1.0))
				if v < 1.0 or vc < 1.0:
					assemble_done = false
			else:
				assemble_done = false
		if _anim_reveal:
			var u := clampf((t - (_reveal_start + slot)) / _reveal_fade, 0.0, 1.0)
			mi.transparency = 1.0 - (0.5 - 0.5 * cos(PI * u))
			if not assembling_this:
				var far_xf: Transform3D = entry["far"]
				var home_xf: Transform3D = entry["home"]
				mi.transform = far_xf.interpolate_with(home_xf, sin(u * PI * 0.5))
			if u < 1.0:
				reveal_done = false
	if reveal_done:
		_anim_reveal = false
	if _anim_assemble and assemble_done:
		_anim_assemble = false
		_anim_reveal = false
		var fade := 1.0 - _energy
		for entry in _pieces:
			var piece := entry["node"] as MeshInstance3D
			if piece != null and is_instance_valid(piece):
				piece.transparency = fade
			_set_heat(entry["index"], 0.0)
		_pieces.clear()


# --- material plumbing -------------------------------------------------------

func _apply_accent() -> void:
	var profile := _profile_for_accent(_accent)
	for index in _shell_materials.size():
		_push_shell_accent(index)
	if _core_material != null:
		_apply_crystal(_core_material, profile, CORE_TUNING)
	if _core_shard_material != null:
		_apply_crystal(_core_shard_material, profile, SHARD_TUNING)
	if _halo_material != null:
		_halo_material.set_shader_parameter("halo_color", _accent)
		_halo_material.set_shader_parameter("accent_color", profile["rim_color"])
		_halo_material.set_shader_parameter("opacity", HALO_OPACITY * _energy)
	if _aura != null:
		_aura.light_color = _accent
		_aura.light_energy = AURA_ENERGY * _energy


func _apply_crystal(mat: ShaderMaterial, profile: Dictionary, tuning: Dictionary) -> void:
	var body: Color = (profile["core_color"] as Color).darkened(float(tuning["base_darken"]))
	mat.set_shader_parameter("base_color", body)
	mat.set_shader_parameter("emission_color", body)
	mat.set_shader_parameter("emission_strength", float(profile["emission_strength"]) * float(tuning["emission_scale"]))
	mat.set_shader_parameter("rim_color", profile["rim_color"])
	mat.set_shader_parameter("spec_color", profile["spec_color"])
	mat.set_shader_parameter("inner_glow", float(profile["inner_glow"]) * float(tuning["emission_scale"]))
	for key in ["rim_strength", "rim_power", "specular_amount", "roughness_value",
			"pulse_strength", "facet_glint", "coat_strength", "body_emission"]:
		mat.set_shader_parameter(key, float(tuning[key]))


## Fresh shards glow realm-hot: the accent is pulled toward PIECE_GLOW while the
## scatter heat is high, and settles back on the accent as it cools.
func _set_heat(index: int, heat: float) -> void:
	if index < 0 or index >= _shell_materials.size():
		return
	_heat[index] = heat
	_shell_materials[index].set_shader_parameter("scatter_glow", heat)
	_push_shell_accent(index)


func _push_shell_accent(index: int) -> void:
	var mat := _shell_materials[index]
	if mat == null:
		return
	var mix_weight := 0.55 * clampf(_heat[index] / SCATTER_HEAT, 0.0, 1.0)
	mat.set_shader_parameter("accent_color", _accent.lerp(PIECE_GLOW, mix_weight))


func _turn_toward_player() -> void:
	var player := _player_ref.get_ref() as Node3D if _player_ref != null else null
	if player == null or not is_instance_valid(player):
		return
	var d := player.global_position - global_position
	d.y = 0.0
	if d.length_squared() <= 0.0001:
		return
	var target_yaw := atan2(-d.x, -d.z)
	rotation.y = lerp_angle(rotation.y, target_yaw, clampf(turn_speed * _delta_ratio(), 0.0, 1.0))


## SimClock advances in physics ticks; at 60 Hz one frame is 1/60 s. Using the
## fixed step keeps the turn identical in a fixture replay.
func _delta_ratio() -> float:
	return 1.0 / float(maxi(Engine.physics_ticks_per_second, 1))
