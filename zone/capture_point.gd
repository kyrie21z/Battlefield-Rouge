class_name CapturePoint
extends Area3D
## The objective building. Locked until the zone director calls open(); then
## the player strikes it with the mind blade. Every swing adds progress, and a swing that lands on
## a hit moment (within CaptureConfig.perfect_window_ms) adds more. Progress
## never goes down, so nothing that happens during the capture can undo it. At
## 100% a flag is planted and `captured` fires.
## Rules: docs/Cut-001b.md. Timing choices: docs/adr/0003-hammer-capture-timing.md.

signal progress_changed(progress: float)
## One swing resolved against the building. `offset_ms` is how far from the
## hit moment it landed (negative = early); `worth` is the progress it added.
signal struck(perfect: bool, offset_ms: float, worth: float)
## A quarter of the building broke off. Stages 1-3; the fourth quarter is the
## capture itself. The HUD adds the camera kick.
signal fractured(stage: int)
signal captured

## Seconds between hit moments. A rule of the strike rather than a playtest
## knob, so it is not part of CaptureConfig.
const BEAT_PERIOD := 1.0
const COLOR_LOCKED := Color(0.45, 0.45, 0.48)
const COLOR_OPEN := Color(0.25, 0.5, 0.9)
const COLOR_CAPTURED := Color(0.3, 0.85, 0.4)
const FLASH_HIT := Color(0.85, 0.9, 1.0)
const FLASH_PERFECT := Color(1.0, 0.8, 0.2)
const FLAG_HEIGHT := 3.5
## Progress counts as full once it is this close to 1, so float error in the
## configured steps cannot leave a capture stuck at 99.999%.
const FULL_EPSILON := 0.000001

## Blade-strike presentation. Progress, beats and the fracture mapping never
## read any of these; the collision shape never moves.
const BLOCK_SQUASH := Vector3(1.04, 0.94, 1.04)
const BLOCK_SQUASH_PERFECT := Vector3(1.07, 0.90, 1.07)
const BLOCK_PUNCH_TIME := 0.16
const BLOCK_PUNCH_TIME_PERFECT := 0.22
const BLOCK_JITTER := 0.02
const BLOCK_JITTER_PERFECT := 0.03
## Chips thrown by one strike.
const CHIPS_NORMAL := 14
const CHIPS_PERFECT := 30
const CHIP_SIZE := 0.10
const CHIP_SPEED_NORMAL := 3.0
const CHIP_SPEED_PERFECT := 4.5
## A strike's dust: a few big, soft quads.
const STRIKE_DUST := 4
## A quarter break's mid-size burst.
const BREAK_CHIPS := 12
const BREAK_DUST := 6
const BREAK_SPEED := 4.0
## The capture payoff: brass clock parts, a dust ring and a warm flash.
const GEAR_COUNT := 30
const MAX_GEARS := 40
const CAPTURE_SEED := 0xC10CC
const CAPTURE_LIGHT_TIME := 0.25
const CAPTURE_LIGHT_ENERGY := 8.0
const CAPTURE_LIGHT_RANGE := 12.0
const DUST_RING := 18
const GEAR_GRAVITY := 14.0
const GEAR_SETTLE_Y := 0.06
const BRASS := Color(0.788, 0.635, 0.29)
const DARK_METAL := Color(0.12, 0.1, 0.07)
## Private feel generator: the strike jitter must never move the run's RNG.
const FEEL_SEED := 0x4A3B
const PUFF := preload("res://assets/vfx/puff.png")

@export var config: CaptureConfig = preload("res://zone/capture_config.tres")

var locked := true
## 0..1. Only add_capture_progress() changes it.
var progress := 0.0
## True while the player is within blade reach of the building.
var player_in_reach := false

var _opened_at := 0.0
var _material := StandardMaterial3D.new()
var _flash_tween: Tween
var _hit_sound := ProceduralAudio.generate("clock_hit")
var _perfect_sound := ProceduralAudio.generate("clock_perfect")
var _audio := AudioStreamPlayer3D.new()
var _break_audio := AudioStreamPlayer3D.new()
var _light := OmniLight3D.new()
## How many quarter-steps of the building have broken off. 4 means it has collapsed.
var fracture_stage := 0
var _blocks: Array[MeshInstance3D] = []
var _broken: Array[MeshInstance3D] = []
var _debris: Array[Dictionary] = []
## Presentation state: rest poses of the blocks, and the chip/dust/gear bits
## that are not the eight blocks themselves.
var _feel_rng := RandomNumberGenerator.new()
var _block_rest: Dictionary = {}
var _block_tweens: Dictionary = {}
var _bits: Array[Dictionary] = []
var _gears: Array[Dictionary] = []
var _brass: StandardMaterial3D
var _dark_metal: StandardMaterial3D
var _stone: StandardMaterial3D
var _puff: StandardMaterial3D
## Where the blade lands (front face) and where the clock parts come from.
## Computed from the building in _build_fracture().
var _strike_point := Vector3(0.0, 1.0, 1.3)
var _gear_origin := Vector3(0.0, 1.2, 0.0)
## Chips thrown by the last strike. For tests.
var last_chip_count := 0

@onready var _building: MeshInstance3D = $Objective/Mesh


func _ready() -> void:
	collision_layer = 0
	collision_mask = CollisionLayers.ACTORS
	monitorable = false
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_feel_rng.seed = FEEL_SEED
	_build_materials()
	_building.material_override = _material
	_audio.position.y = 1.0
	_audio.max_distance = 60.0
	add_child(_audio)
	_break_audio.position.y = 1.0
	_break_audio.max_distance = 60.0
	_break_audio.stream = ProceduralAudio.generate("clock_break")
	add_child(_break_audio)
	_light.position.y = 2.5
	_light.omni_range = 10.0
	_light.light_energy = 0.0
	add_child(_light)
	_build_fracture()
	struck.connect(_on_struck_debris)
	struck.connect(_on_struck_shake)
	captured.connect(_on_captured_payoff)
	_update_color()


## Materials shared by every chip, puff and brass piece of the payoff.
func _build_materials() -> void:
	_brass = StandardMaterial3D.new()
	_brass.albedo_color = BRASS
	_brass.metallic = 0.8
	_brass.roughness = 0.35
	_brass.emission_enabled = true
	_brass.emission = BRASS
	_brass.emission_energy_multiplier = 0.25
	_dark_metal = StandardMaterial3D.new()
	_dark_metal.albedo_color = DARK_METAL
	_dark_metal.metallic = 0.6
	_dark_metal.roughness = 0.5
	_stone = StandardMaterial3D.new()
	_stone.albedo_color = Color(0.5, 0.52, 0.56)
	_stone.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_puff = StandardMaterial3D.new()
	_puff.albedo_texture = PUFF
	_puff.albedo_color = Color(0.62, 0.6, 0.56, 0.35)
	_puff.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_puff.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_puff.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED


func open() -> void:
	locked = false
	_opened_at = SimClock.now()
	_update_color()


func is_captured() -> bool:
	return progress >= 1.0 - FULL_EPSILON


## Seconds on the beat clock. Hit moments fall on whole multiples of
## BEAT_PERIOD; the first one comes half a period after open().
func beat_time() -> float:
	return SimClock.now() - _opened_at + BEAT_PERIOD * 0.5


## Signed seconds from `time` to the nearest hit moment (negative = early).
static func beat_offset(time: float) -> float:
	return fposmod(time + BEAT_PERIOD * 0.5, BEAT_PERIOD) - BEAT_PERIOD * 0.5


## Adds `amount`, a fraction of the whole capture, and plants the flag at 100%.
## Ignored while locked or once captured.
func add_capture_progress(amount: float) -> void:
	if locked or is_captured() or amount <= 0.0:
		return
	progress = minf(progress + amount, 1.0)
	progress_changed.emit(progress)
	_sync_fracture()
	_update_color()
	if is_captured():
		progress = 1.0
		_clear_ruin()
		_plant_flag()
		captured.emit()


## Resolves one blade swing made at `time` on the beat clock. A swing counts
## only while the building is open and the player is within reach.
func resolve_swing(time: float) -> void:
	if locked or is_captured() or not player_in_reach:
		return
	var offset_ms := beat_offset(time) * 1000.0
	var perfect := absf(offset_ms) <= config.perfect_window_ms
	var worth := config.progress_for_swing(perfect)
	_play_feedback(perfect)
	struck.emit(perfect, offset_ms, worth)
	Events.clock_struck.emit(global_position)
	add_capture_progress(worth)


func _on_body_entered(body: Node3D) -> void:
	if body is Player:
		player_in_reach = true
		var swung := (body as Player).melee.struck
		var callback := _on_swung.bind(body)
		if not swung.is_connected(callback):
			swung.connect(callback)


func _on_body_exited(body: Node3D) -> void:
	if body is Player:
		player_in_reach = false
		var swung := (body as Player).melee.struck
		var callback := _on_swung.bind(body)
		if swung.is_connected(callback):
			swung.disconnect(callback)


func _on_swung(player: Player) -> void:
	# Merely standing in the capture area is insufficient: the blade must face
	# the clock, and a wall between the player and clock blocks the strike.
	var eye := player.melee.camera
	# Measure the reachable face, not the centre of a large core. An actor can
	# already be inside its reach Area while still >4.2m from the core centre.
	var bounds := _building.get_aabb()
	var local_eye := _building.to_local(eye.global_position)
	var surface := _building.to_global(local_eye.clamp(bounds.position, bounds.end))
	var to_clock := surface - eye.global_position
	if to_clock.length() > player.melee.strike_reach():
		return
	if (-eye.global_basis.z).angle_to(to_clock) > deg_to_rad(55.0):
		return
	var query := PhysicsRayQueryParameters3D.create(eye.global_position,
		surface + (_building.global_position - surface).normalized() * 0.01, CollisionLayers.WORLD)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty() and not is_ancestor_of(hit.collider):
		return
	resolve_swing(beat_time())


## A perfect strike and an ordinary one differ in sound, flash colour, flash
## strength and a light burst, so the player can tell them apart without the HUD.
func _play_feedback(perfect: bool) -> void:
	_audio.stream = _perfect_sound if perfect else _hit_sound
	_audio.play()
	if perfect:
		_spawn_strike_ring()
	if _flash_tween != null:
		_flash_tween.kill()
	_material.emission_enabled = true
	_material.emission = FLASH_PERFECT if perfect else FLASH_HIT
	_light.light_color = FLASH_PERFECT
	_flash_tween = create_tween().set_parallel()
	_flash_tween.tween_property(_material, "emission_energy_multiplier", 0.0, 0.4 if perfect else 0.12) \
		.from(4.0 if perfect else 0.8)
	_flash_tween.tween_property(_light, "light_energy", 0.0, 0.4).from(8.0 if perfect else 0.0)


## Blocks still attached to the building. Tests watch this drop at each quarter.
func intact_block_count() -> int:
	return _blocks.size() - _broken.size()


func _physics_process(delta: float) -> void:
	for piece in _debris:
		if piece.settled:
			continue
		piece.time += delta
		piece.velocity.y -= 14.0 * delta
		var node := piece.node as Node3D
		node.position += piece.velocity * delta
		node.rotation += piece.spin * delta
		if node.position.y <= 0.12 or piece.time >= 1.05:
			node.position.y = 0.12
			piece.settled = true
	_update_bits(delta)
	_update_gears(delta)


## Chips/dust are manual quads, so no particle node is constructed (no global RNG draw).
func _update_bits(delta: float) -> void:
	for i in range(_bits.size() - 1, -1, -1):
		var bit := _bits[i]
		bit.age += delta
		var node := bit.node as Node3D
		if bit.age >= bit.life:
			node.queue_free()
			_bits.remove_at(i)
			continue
		bit.velocity.y -= 12.0 * delta
		node.position += bit.velocity * delta
		node.rotation += bit.spin * delta
		var t: float = float(bit.age) / float(bit.life)
		if bit.fade:
			node.transparency = t * t
		if bit.grow > 0.0:
			node.scale = Vector3.ONE * lerpf(1.0, bit.grow, t)


## The capture's brass parts: fly out, spin, fall and stay as litter.
func _update_gears(delta: float) -> void:
	for gear in _gears:
		if gear.settled:
			continue
		gear.velocity.y -= GEAR_GRAVITY * delta
		var node := gear.node as Node3D
		node.position += gear.velocity * delta
		node.rotation += gear.spin * delta
		if node.position.y <= GEAR_SETTLE_Y:
			node.position.y = GEAR_SETTLE_Y
			gear.settled = true


## Eight boxes in place of the single grey mesh. The collision box stays, so
## navigation and gun rays still see a solid building. The boxes themselves
## have no collision.
func _build_fracture() -> void:
	var box := _building.mesh as BoxMesh
	var size := box.size if box != null else _building.get_aabb().size
	var objective := _building.get_parent() as Node3D
	_strike_point = objective.position + Vector3(0.0, 0.0, size.z * 0.5 + 0.05)
	_gear_origin = objective.position + Vector3(0.0, 0.2, 0.0)
	_building.visible = false
	var cell := size / 2.0
	var index := 0
	for iy in 2:
		for iz in 2:
			for ix in 2:
				var block := MeshInstance3D.new()
				block.name = "Block%d" % index
				var part := BoxMesh.new()
				part.size = cell * 0.92
				block.mesh = part
				block.material_override = _material
				block.position = Vector3((float(ix) - 0.5) * cell.x, (float(iy) - 0.5) * cell.y, (float(iz) - 0.5) * cell.z)
				_block_rest[block] = block.transform
				var crack := MeshInstance3D.new()
				crack.name = "Crack"
				var crack_mesh := BoxMesh.new()
				crack_mesh.size = Vector3(cell.x * 0.84, 0.035, 0.025)
				crack.mesh = crack_mesh
				var dark := StandardMaterial3D.new()
				dark.albedo_color = Color(0.07, 0.07, 0.08)
				crack.material_override = dark
				crack.position = Vector3(0.0, cell.y * 0.12, cell.z * 0.42)
				crack.visible = false
				block.add_child(crack)
				_building.get_parent().add_child(block)
				_blocks.append(block)
				index += 1


func _sync_fracture() -> void:
	var stage := mini(int(floor(progress / 0.25)), 3)
	if progress >= 1.0 - FULL_EPSILON:
		stage = 4
	while fracture_stage < stage:
		fracture_stage += 1
		_break_stage(fracture_stage)
	for block in _blocks:
		if block in _broken:
			continue
		var crack := block.get_node_or_null("Crack") as MeshInstance3D
		if crack != null:
			crack.visible = fracture_stage > 0


func _break_stage(stage: int) -> void:
	var first := (stage - 1) * 2
	for offset in 2:
		var index := first + offset
		if index >= _blocks.size():
			return
		_detach(_blocks[index], index, stage == 4)
	if stage < 4:
		_spawn_break_burst()
		fractured.emit(stage)


func _detach(block: MeshInstance3D, index: int, collapse: bool) -> void:
	if block in _broken:
		return
	_broken.append(block)
	_kill_block_tween(block)
	block.scale = Vector3.ONE
	var rest: Transform3D = _block_rest.get(block, block.transform)
	block.transform = rest
	var crack := block.get_node_or_null("Crack") as MeshInstance3D
	if crack != null:
		crack.visible = false
	var origin := block.global_position
	block.reparent(self)
	block.global_position = origin
	var dull := _material.duplicate() as StandardMaterial3D
	dull.albedo_color = Color(0.22, 0.22, 0.24)
	dull.emission_enabled = false
	block.material_override = dull
	# Index-based offsets, not randf(), so a chip burst cannot move the run seed.
	var angle := float(index) * 1.7 + float(fracture_stage)
	var outward := Vector3(sin(angle), 0.85 if collapse else 1.35, cos(angle * 1.3))
	var speed := 2.4 if collapse else 1.5 + float(index % 3) * 0.35
	_debris.append({
		"node": block,
		"velocity": outward.normalized() * speed,
		"spin": Vector3(sin(angle), 0.4, cos(angle)) * (2.2 if collapse else 1.4),
		"time": 0.0,
		"settled": false,
	})


func _on_struck_debris(perfect: bool, _offset_ms: float, _worth: float) -> void:
	var bits := CPUParticles3D.new()
	bits.name = "Chips"
	bits.one_shot = true
	bits.explosiveness = 1.0
	bits.amount = CHIPS_PERFECT if perfect else CHIPS_NORMAL
	last_chip_count = bits.amount
	bits.lifetime = 0.45
	bits.use_fixed_seed = true
	bits.seed = fracture_stage * 17 + (3 if perfect else 1)
	var chip := BoxMesh.new()
	chip.size = Vector3.ONE * CHIP_SIZE
	bits.mesh = chip
	var chip_material := StandardMaterial3D.new()
	chip_material.albedo_color = Color(0.85, 0.88, 0.95) if perfect else Color(0.45, 0.47, 0.5)
	chip_material.emission_enabled = perfect
	chip_material.emission = Color(1.0, 0.85, 0.45)
	chip_material.emission_energy_multiplier = 2.0 if perfect else 0.0
	bits.material_override = chip_material
	bits.direction = Vector3(0.0, 1.0, 0.0)
	bits.spread = 55.0
	bits.initial_velocity_min = 1.5
	bits.initial_velocity_max = CHIP_SPEED_PERFECT if perfect else CHIP_SPEED_NORMAL
	bits.scale_amount_min = 1.0 if perfect else 0.9
	bits.scale_amount_max = 1.4 if perfect else 1.1
	bits.gravity = Vector3(0.0, -12.0, 0.0)
	# On the front face, where the blade lands: spawning inside the box would
	# hide the first tenth of a second behind the blocks.
	bits.position = _strike_point
	add_child(bits)
	bits.emitting = true
	bits.finished.connect(bits.queue_free)
	_spawn_dust(_strike_point, STRIKE_DUST, 0.3 if perfect else 0.22,
		0.5 if perfect else 0.4, 0.55 if perfect else 0.4)


## Blocks squash and jitter on a strike, then settle exactly back; collision never moves.
func _on_struck_shake(perfect: bool, _offset_ms: float, _worth: float) -> void:
	var squash := BLOCK_SQUASH_PERFECT if perfect else BLOCK_SQUASH
	var time := BLOCK_PUNCH_TIME_PERFECT if perfect else BLOCK_PUNCH_TIME
	var jitter := BLOCK_JITTER_PERFECT if perfect else BLOCK_JITTER
	for block in _blocks:
		if block in _broken or not is_instance_valid(block):
			continue
		_kill_block_tween(block)
		var rest: Transform3D = _block_rest[block]
		block.scale = Vector3.ONE
		block.position = rest.origin
		var jolt := Vector3(_feel_rng.randf_range(-jitter, jitter),
			_feel_rng.randf_range(-jitter, jitter), _feel_rng.randf_range(-jitter, jitter))
		var tween := create_tween()
		tween.tween_property(block, "scale", squash, time * 0.3).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(block, "position", rest.origin + jolt, time * 0.3).set_ease(Tween.EASE_OUT)
		tween.tween_property(block, "scale", Vector3.ONE, time * 0.7) \
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(block, "position", rest.origin, time * 0.7) \
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		_block_tweens[block] = tween


func _kill_block_tween(block: MeshInstance3D) -> void:
	var tween: Tween = _block_tweens.get(block)
	if tween != null and tween.is_valid():
		tween.kill()
	_block_tweens.erase(block)


## A quarter break: a mid-size spray of stone chips and dust.
func _spawn_break_burst() -> void:
	_spawn_chips(_strike_point, BREAK_CHIPS, BREAK_SPEED)
	_spawn_dust(_strike_point, BREAK_DUST, 0.35, 0.8, 0.7)


## Big soft quads with their own alpha, moved by _update_bits(), not a particle node.
func _spawn_dust(origin: Vector3, count: int, alpha: float, life: float, size: float) -> void:
	for i in count:
		var angle := TAU * float(i) / float(count) + _feel_rng.randf_range(-0.3, 0.3)
		var dir := Vector3(cos(angle), _feel_rng.randf_range(0.1, 0.5), sin(angle)).normalized()
		var puff := _make_puff(size, alpha)
		puff.position = origin + dir * 0.25
		add_child(puff)
		_bits.append({"node": puff, "velocity": dir * _feel_rng.randf_range(0.5, 1.4),
			"spin": Vector3.ZERO, "age": 0.0, "life": life, "fade": true, "grow": 2.4})


func _make_puff(size: float, alpha: float) -> MeshInstance3D:
	var quad := MeshInstance3D.new()
	var mesh := QuadMesh.new()
	mesh.size = Vector2.ONE * size
	quad.mesh = mesh
	var material := _puff.duplicate() as StandardMaterial3D
	material.albedo_color.a = alpha
	quad.material_override = material
	quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return quad


func _spawn_chips(origin: Vector3, count: int, speed: float) -> void:
	for i in count:
		var chip := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3.ONE * 0.09
		chip.mesh = mesh
		chip.material_override = _stone
		chip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		chip.position = origin
		add_child(chip)
		var angle := TAU * float(i) / float(count) + _feel_rng.randf_range(-0.2, 0.2)
		var dir := Vector3(cos(angle), _feel_rng.randf_range(0.5, 1.2), sin(angle)).normalized()
		_bits.append({"node": chip, "velocity": dir * _feel_rng.randf_range(1.5, speed),
			"spin": Vector3(_feel_rng.randf_range(-6.0, 6.0), 0.0, _feel_rng.randf_range(-6.0, 6.0)),
			"age": 0.0, "life": 1.0, "fade": true, "grow": 0.0})


## 100%: brass gears, rods and rings fly out with a warm flash and a dust ring.
func _on_captured_payoff() -> void:
	_spawn_gears()
	_spawn_dust_ring()
	_break_audio.play()
	var flash := OmniLight3D.new()
	flash.light_color = Color(1.0, 0.78, 0.42)
	flash.light_energy = CAPTURE_LIGHT_ENERGY
	flash.omni_range = CAPTURE_LIGHT_RANGE
	flash.position = Vector3(0.0, 2.0, 0.0)
	add_child(flash)
	var tween := create_tween()
	tween.tween_property(flash, "light_energy", 0.0, CAPTURE_LIGHT_TIME)
	tween.tween_callback(flash.queue_free)


func _spawn_gears() -> void:
	var specs := _gear_specs()
	for i in mini(specs.size(), MAX_GEARS - _gears.size()):
		var spec: Dictionary = specs[i]
		var offset: Vector3 = spec.offset
		var tilt: Vector3 = spec.tilt
		var velocity: Vector3 = spec.velocity
		var spin: Vector3 = spec.spin
		var node := _make_gear(spec, i)
		add_child(node)
		node.position = _gear_origin + offset
		node.rotation = tilt
		node.scale = Vector3.ONE * float(spec.size)
		_gears.append({"node": node, "velocity": velocity, "spin": spin, "settled": false})


## A fresh seeded generator each call: the same capture replays exactly.
func _gear_specs() -> Array[Dictionary]:
	var rng := RandomNumberGenerator.new()
	rng.seed = CAPTURE_SEED
	var specs: Array[Dictionary] = []
	for i in GEAR_COUNT:
		var angle := TAU * float(i) / float(GEAR_COUNT) + rng.randf_range(-0.1, 0.1)
		var outward := Vector3(cos(angle), 0.0, sin(angle))
		specs.append({
			"kind": i % 5,
			"radius": rng.randf_range(0.12, 0.26),
			"height": rng.randf_range(0.025, 0.05),
			"offset": outward * rng.randf_range(0.05, 0.6) + Vector3(0.0, rng.randf_range(-0.2, 0.5), 0.0),
			"velocity": outward * rng.randf_range(1.2, 3.2) + Vector3(0.0, rng.randf_range(2.5, 5.5), 0.0),
			"spin": Vector3(rng.randf_range(-7.0, 7.0), rng.randf_range(-7.0, 7.0), rng.randf_range(-7.0, 7.0)),
			"tilt": Vector3(rng.randf_range(-0.6, 0.6), rng.randf_range(0.0, TAU), rng.randf_range(-0.6, 0.6)),
			"size": rng.randf_range(0.85, 1.2),
		})
	return specs


## Brass disc + dark hub (teeth on every other), thin rod, or ring.
func _make_gear(spec: Dictionary, index: int) -> Node3D:
	var root := Node3D.new()
	root.name = "ClockPart%d" % index
	var radius := float(spec.radius)
	var height := float(spec.height)
	if int(spec.kind) == 3:
		var rod := MeshInstance3D.new()
		var rod_mesh := CylinderMesh.new()
		rod_mesh.top_radius = 0.025
		rod_mesh.bottom_radius = 0.025
		rod_mesh.height = 0.34
		rod.mesh = rod_mesh
		rod.material_override = _brass
		root.add_child(rod)
	elif int(spec.kind) == 4:
		var ring := MeshInstance3D.new()
		var ring_mesh := TorusMesh.new()
		ring_mesh.inner_radius = 0.05
		ring_mesh.outer_radius = 0.12
		ring_mesh.rings = 8
		ring_mesh.ring_segments = 10
		ring.mesh = ring_mesh
		ring.material_override = _brass
		root.add_child(ring)
	else:
		var disc := MeshInstance3D.new()
		var disc_mesh := CylinderMesh.new()
		disc_mesh.top_radius = radius
		disc_mesh.bottom_radius = radius
		disc_mesh.height = height
		disc_mesh.radial_segments = 12
		disc.mesh = disc_mesh
		disc.material_override = _brass
		root.add_child(disc)
		var hub := MeshInstance3D.new()
		var hub_mesh := CylinderMesh.new()
		hub_mesh.top_radius = radius * 0.28
		hub_mesh.bottom_radius = radius * 0.28
		hub_mesh.height = height * 1.4
		hub.mesh = hub_mesh
		hub.material_override = _dark_metal
		root.add_child(hub)
		if index % 2 == 0:
			for tooth in 8:
				var tooth_angle := TAU * float(tooth) / 8.0
				var box := MeshInstance3D.new()
				var box_mesh := BoxMesh.new()
				box_mesh.size = Vector3(radius * 0.28, height, radius * 0.16)
				box.mesh = box_mesh
				box.material_override = _brass
				box.position = Vector3(cos(tooth_angle), 0.0, sin(tooth_angle)) * radius * 1.05
				box.rotation.y = -tooth_angle
				root.add_child(box)
	return root


func _spawn_dust_ring() -> void:
	for i in DUST_RING:
		var angle := TAU * float(i) / float(DUST_RING)
		var dir := Vector3(cos(angle), 0.0, sin(angle))
		var puff := _make_puff(0.9, 0.28)
		puff.position = _gear_origin + dir * 0.7 - Vector3(0.0, 0.9, 0.0)
		add_child(puff)
		_bits.append({"node": puff, "velocity": dir * 2.6 + Vector3.UP * 0.2,
			"spin": Vector3.ZERO, "age": 0.0, "life": 1.2, "fade": true, "grow": 2.6})


## Number of brass pieces the capture threw. For tests and proofs.
func gear_piece_count() -> int:
	return _gears.size()


## The building has fallen to rubble at 100%, so its collision box goes with
## it: otherwise an invisible wall would stand where the building was.
func _clear_ruin() -> void:
	var shape := get_node_or_null("Objective/Shape") as CollisionShape3D
	if shape != null:
		shape.set_deferred("disabled", true)


## The flag stands in the rubble, not on the roof the building no longer has.
func _plant_flag() -> void:
	var ground := (_building.global_transform * _building.get_aabb()).position.y - global_position.y
	var flag := Node3D.new()
	flag.name = "Flag"
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.75, 0.75, 0.78)
	var pole := MeshInstance3D.new()
	var pole_mesh := CylinderMesh.new()
	pole_mesh.top_radius = 0.06
	pole_mesh.bottom_radius = 0.06
	pole_mesh.height = FLAG_HEIGHT
	pole.mesh = pole_mesh
	pole.material_override = metal
	pole.position.y = FLAG_HEIGHT * 0.5
	flag.add_child(pole)
	var cloth := MeshInstance3D.new()
	var cloth_mesh := BoxMesh.new()
	cloth_mesh.size = Vector3(1.1, 0.7, 0.05)
	cloth.mesh = cloth_mesh
	var cloth_material := StandardMaterial3D.new()
	cloth_material.albedo_color = COLOR_CAPTURED
	cloth.material_override = cloth_material
	cloth.position = Vector3(0.6, FLAG_HEIGHT - 0.45, 0.0)
	flag.add_child(cloth)
	# Start with the whole pole below the ground and raise it out of the rubble.
	flag.position.y = ground - FLAG_HEIGHT
	add_child(flag)
	create_tween().tween_property(flag, "position:y", ground, 0.9) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _update_color() -> void:
	if locked:
		_material.albedo_color = COLOR_LOCKED
	else:
		_material.albedo_color = COLOR_OPEN.lerp(COLOR_CAPTURED, progress)
		if fracture_stage > 0:
			_material.albedo_color = _material.albedo_color.lerp(Color(0.16, 0.16, 0.18), float(fracture_stage) / 4.0)


## A warm expanding clock chime, using the same successful strike as progress.
func _spawn_strike_ring() -> void:
	var ring := MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.46
	mesh.outer_radius = 0.5
	mesh.rings = 24
	mesh.ring_segments = 6
	ring.mesh = mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = FLASH_PERFECT
	material.emission_enabled = true
	material.emission = FLASH_PERFECT
	material.emission_energy_multiplier = 2.0
	ring.material_override = material
	ring.position = Vector3(0.0, 0.1, 0.0)
	add_child(ring)
	var tween := create_tween().set_parallel()
	tween.tween_property(ring, "scale", Vector3.ONE * 7.0, 0.35)
	tween.tween_property(material, "albedo_color:a", 0.0, 0.35)
	tween.chain().tween_callback(ring.queue_free)
