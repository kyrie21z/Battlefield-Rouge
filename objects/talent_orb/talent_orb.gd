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
var _bob_enabled := true
var _bob_phase := 0.0
var _bob_clock := 0.0
var _pieces: Array[Dictionary] = []
var _piece_count := 0


func _ready() -> void:
	_build_models()
	_build_collision()


func _build_models() -> void:
	_shell = SHELL_SCENE.instantiate() as Node3D
	add_child(_shell)
	_core = CORE_SCENE.instantiate() as Node3D
	_core.position = Vector3(0.0, 0.0, CORE_FORWARD)
	add_child(_core)


## Solid body so the orb reads as a real object: the player cannot walk through it
## and bullets stop on it. It sits on WORLD, which is what player rays and
## projectiles already test. The radius is a touch under the visual shell so the
## plates still poke out, and it stays well inside INTERACT_RANGE so you can
## always reach the orb even while standing against it.
func _build_collision() -> void:
	_body = StaticBody3D.new()
	_body.name = "Body"
	_body.collision_layer = CollisionLayers.WORLD
	_body.collision_mask = 0
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
		_body.collision_layer = CollisionLayers.WORLD if value else 0


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
	if _shell == null:
		return
	var meshes := _shell.find_children("*", "MeshInstance3D", true, false)
	var i := 0
	for entry in meshes:
		var mi := entry as MeshInstance3D
		if mi == null:
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

		# own material copy so each piece can glow and cool down on its own
		var glow_mat: StandardMaterial3D = null
		var base := mi.get_active_material(0) as StandardMaterial3D
		if base != null:
			glow_mat = base.duplicate() as StandardMaterial3D
			glow_mat.emission_enabled = true
			glow_mat.emission = PIECE_GLOW
			glow_mat.emission_energy_multiplier = 3.6
			mi.material_override = glow_mat
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
			"material": glow_mat,
			"delay": slot,
			"reveal": slot,
		})
		i += 1


## Brings the pieces out of the void: each one drifts in from far away while its
## opacity comes up, one after another - never all at once. Returns how long the
## whole reveal takes so the zone can chain the assembly right after it.
func reveal_pieces(fade: float = 0.85) -> float:
	var total := 0.0
	for entry in _pieces:
		var mi := entry["node"] as MeshInstance3D
		if mi == null or not is_instance_valid(mi):
			continue
		var wait: float = entry["reveal"]
		total = maxf(total, wait + fade)
		var drift := create_tween().bind_node(mi)
		drift.tween_property(mi, "transform", entry["home"], fade) \
			.set_delay(wait) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		var appear := create_tween().bind_node(mi)
		appear.tween_property(mi, "transparency", 0.0, fade) \
			.set_delay(wait) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return total


## Flies every scattered piece back to its authored pose while its glow drains
## away, so each piece settles on its original material colour.
func assemble(duration: float = ASSEMBLE_TIME, start_delay: float = ASSEMBLE_START) -> void:
	for entry in _pieces:
		var mi := entry["node"] as MeshInstance3D
		if mi == null or not is_instance_valid(mi):
			continue
		var wait := start_delay + float(entry["delay"])
		var tween := create_tween().bind_node(mi)
		tween.tween_property(mi, "transform", entry["target"], duration) \
			.set_delay(wait) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		var mat := entry["material"] as StandardMaterial3D
		if mat != null:
			var cool := create_tween().bind_node(mi)
			cool.tween_property(mat, "emission_energy_multiplier", 0.0, duration * 1.2) \
				.set_delay(wait) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_pieces.clear()


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
		var offset := (position.y - base_height) / maxf(bob_height, 0.0001)
		_bob_phase = asin(clampf(offset, -1.0, 1.0))
		_bob_clock = SimClock.now()
	_bob_enabled = value


## Recolours the energy field and lamps so the orb matches the realm being
## offered. Called by the zone when the reward identity is known.
func set_accent(accent: Color) -> void:
	_accent = accent
	if _shell == null:
		return
	for node in _shell.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh == null or mesh.material_override is not StandardMaterial3D:
			continue
		var mat := mesh.material_override as StandardMaterial3D
		if mat.emission_enabled:
			mat.emission = accent
	if _core == null:
		return
	for node in _core.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh == null or mesh.material_override is not StandardMaterial3D:
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

	if _bob_enabled:
		# phase-locked so switching idle motion back on never snaps the height:
		# at the moment it resumes, sin() evaluates to wherever the orb already is
		position.y = base_height + sin((t - _bob_clock) * bob_speed + _bob_phase) * bob_height
	_turn_toward_player()

	if _core != null:
		_core.rotation.y = t * cube_spin
		_core.rotation.x = sin(t * cube_spin * 0.7) * cube_tumble


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
