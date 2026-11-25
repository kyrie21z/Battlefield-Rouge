class_name TalentOrb
extends Node3D
## The reclaimed-talent orb: a plated sphere whose mouth always turns toward the
## player, with a framed cube spinning inside it and the whole rig bobbing.
##
## Every motion is driven by SimClock, never by wall-clock time, so a fixture
## replays the exact same frames (Cut-001b AC-07). Because SimClock counts
## physics frames, pausing the tree also freezes the orb for free.

const SHELL_SCENE := preload("res://objects/talent_orb/orb_shell.glb")
const CORE_SCENE := preload("res://objects/talent_orb/orb_core.glb")

## Where the cube sits relative to the orb centre, along the mouth axis.
const CORE_FORWARD := -0.205

## How close the player has to be for interact to claim the talent.
const INTERACT_RANGE := 2.8

## HDR colour a scattered piece glows with before it cools back to its own material.
const PIECE_GLOW := Color(1.6, 1.15, 0.62)

## Timing of the arrival sequence. assembly_seconds() combines these, so the zone
## can pop the cube in exactly when the shell is whole.
const PIECE_STEP := 0.020
const ASSEMBLE_START := 0.70
const ASSEMBLE_TIME := 1.60

@export var bob_height := 0.16
@export var bob_speed := 0.9
@export var turn_speed := 2.2
@export var cube_spin := 0.55
@export var cube_tumble := 0.32
@export var base_height := 1.28

var _shell: Node3D
var _core: Node3D
var _body: StaticBody3D
var _player_ref: WeakRef
var _accent := Color(1.0, 0.62, 0.18)
var _ground_height := 0.0
var _bob_enabled := true
var _bob_phase := 0.0
var _bob_clock := 0.0
var _pieces: Array[Dictionary] = []
var _piece_count := 0
var _shell_meshes: Array[MeshInstance3D] = []
var _shell_materials: Array[StandardMaterial3D] = []
var _core_meshes: Array[MeshInstance3D] = []
var _anim_reveal := false
var _reveal_start := 0.0
var _reveal_fade := 0.85
var _anim_assemble := false
var _assemble_start := 0.0
var _assemble_duration := ASSEMBLE_TIME


func _ready() -> void:
	prepare()


func prepare() -> void:
	_build_models()
	_build_collision()


## Floor height under the orb, in the parent's space. base_height stays the
## hover offset above it, so a raised landing lifts the whole rig instead of
## burying it in the masonry below the door.
func set_ground_height(height: float) -> void:
	_ground_height = height


func hover_height() -> float:
	return _ground_height + base_height


func _build_models() -> void:
	if _shell != null:
		return
	_shell = SHELL_SCENE.instantiate() as Node3D
	add_child(_shell)
	_core = CORE_SCENE.instantiate() as Node3D
	_core.position = Vector3(0.0, 0.0, CORE_FORWARD)
	add_child(_core)
	_shell_meshes.clear()
	_shell_materials.clear()
	for node in _shell.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi == null:
			continue
		var base := mi.get_active_material(0) as StandardMaterial3D
		var mat := base.duplicate() as StandardMaterial3D if base != null else null
		if mat != null:
			mi.material_override = mat
		_shell_meshes.append(mi)
		_shell_materials.append(mat)
	_core_meshes.clear()
	for node in _core.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi == null:
			continue
		_core_meshes.append(mi)


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
## cannot leave an invisible wall behind.
func set_collision_enabled(value: bool) -> void:
	if _body != null:
		_body.collision_layer = CollisionLayers.WORLD if value else CollisionLayers.NONE


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
## Each piece is hidden and gets its own glowing material copy, so the zone can
## reveal them one at a time and drain the glow back to the original colour.
## Large parts only drift a short way so they don't read as debris crossing the
## room, while the bolted-on armour bits scatter further.
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
		# big shells barely move; small armour blocks fly further out
		var extent := mi.get_aabb().size.length()
		var weight := clampf(1.15 - extent * 0.55, 0.22, 1.0)
		var ang := float(i) * 2.399963
		var tilt := float(i % 11) * 0.33
		var dir := Vector3(cos(ang) * cos(tilt), 0.26 + sin(tilt) * 0.55, sin(ang) * cos(tilt)).normalized()
		var spread := radius * weight * (0.6 + 0.4 * float(i % 5) / 4.0)
		var basis := target.basis.rotated(Vector3.UP, ang * 1.7).rotated(Vector3.RIGHT, tilt)
		mi.transform = Transform3D(basis.scaled(Vector3.ONE * lerpf(1.0, 0.78, weight)), target.origin + dir * spread)

		# pre-cloned material copy glows and cools down without runtime duplication
		var glow_mat := _shell_materials[i] if i < _shell_materials.size() else null
		if glow_mat != null:
			glow_mat.emission_enabled = true
			glow_mat.emission = PIECE_GLOW
			glow_mat.emission_energy_multiplier = 3.6
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
			"node": mi,
			"target": target,
			"home": home,
			"far": far,
			"material": glow_mat,
			"slot": slot,
		})
	# every mesh takes part, so the count is the full piece total - assembly_seconds()
	# needs it to report the real duration (113 pieces -> ~4.56 s, not 2.30 s)
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


## Flies every scattered piece back to its authored pose while its glow drains
## away, so each piece settles on its original material colour.
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


## Hides or shows the glowing cube. The zone keeps it hidden while the shell is
## still flying together, then pops it in at the centre.
func set_core_visible(value: bool) -> void:
	if _core != null:
		_core.visible = value


## Pops the cube in with a small overshoot instead of hard-switching it on.
func fade_core_in(duration: float = 0.55) -> void:
	if _core == null:
		return
	_core.visible = true
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


## Recolours the energy field and lamps so the orb matches the realm being
## offered. Called by the zone when the reward identity is known.
func set_accent(accent: Color) -> void:
	_accent = accent
	for mat in _shell_materials:
		if mat != null and mat.emission_enabled:
			mat.emission = accent
	for mesh in _core_meshes:
		if mesh == null or not is_instance_valid(mesh) or mesh.material_override is not StandardMaterial3D:
			continue
		var mat := mesh.material_override as StandardMaterial3D
		if mat.emission_enabled and mat.emission.b > 0.5 and mat.emission.r < 0.6:
			mat.emission = accent.lerp(Color(0.55, 0.5, 1.0), 0.5)


## Brightness of the whole rig, 1 = normal. Used to dim the orb while it fades in.
func set_energy(scale: float) -> void:
	if _shell == null:
		return
	for node in _shell.get_children():
		var g := node as GeometryInstance3D
		if g != null:
			g.transparency = clampf(1.0 - scale, 0.0, 1.0)


func _process(_delta: float) -> void:
	var t := SimClock.now()

	if _anim_reveal or _anim_assemble:
		_step_pieces(t)

	if _bob_enabled:
		# phase-locked so switching idle motion back on never snaps the height:
		# at the moment it resumes, sin() evaluates to wherever the orb already is
		position.y = hover_height() + sin((t - _bob_clock) * bob_speed + _bob_phase) * bob_height
	_turn_toward_player()

	if _core != null:
		_core.rotation.y = t * cube_spin
		_core.rotation.x = sin(t * cube_spin * 0.7) * cube_tumble


func _step_pieces(t: float) -> void:
	var reveal_done := true
	var assemble_done := not _anim_assemble
	for entry in _pieces:
		var mi := entry["node"] as MeshInstance3D
		if mi == null or not is_instance_valid(mi):
			continue
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
				var mat := entry["material"] as StandardMaterial3D
				var vc := clampf(dt / (_assemble_duration * 1.2), 0.0, 1.0)
				if mat != null:
					mat.emission_energy_multiplier = lerpf(3.6, 0.0, 0.5 - 0.5 * cos(PI * vc))
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
		_pieces.clear()


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
