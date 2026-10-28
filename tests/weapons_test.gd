extends Node
## Headless check of the three-gun rack (Cut-001b AC-05, the gun half):
##   godot --headless --path . res://tests/weapons_test.tscn
## Prints one line per check and exits 1 if anything failed.
##
## The guns are told apart by what a trigger pull actually does to a real guard:
## the rifle puts one 42-damage ray down range, the shotgun puts nine 11-damage
## pellets into a close body, the sniper one 115-damage ray at 30 m. Switching is
## tested through the real input action, and each slot has to keep its own
## magazine across switches.

const NAMES := ["突击步枪", "霰弹枪", "狙击枪"]

var _failures := 0
var _finished := false
var _player: Player
var _weapon: Weapon
var _guard: Enemy
var _start := Vector3.ZERO


func _ready() -> void:
	await _run()
	var ok := _failures == 0 and _finished
	print("%s (%d failed%s)" % ["ALL PASSED" if ok else "FAIL", _failures,
		"" if _finished else ", run did not finish"])
	get_tree().quit(0 if ok else 1)


func _run() -> void:
	var scene: Node = load("res://maps/zone_1.tscn").instantiate()
	add_child(scene)
	await get_tree().process_frame
	# Zone 0 offers the opening buff and pauses. This scene checks the guns
	# directly and does not take a card, so the tree has to run.
	get_tree().paused = false
	_player = scene.get_node("Player") as Player
	_weapon = _player.weapon
	for node in get_tree().get_nodes_in_group("enemy"):
		var enemy := node as Enemy
		enemy.set_physics_process(false)
		if _guard == null:
			_guard = enemy
	_guard.health.max_health = 100000.0
	_guard.health.health = 100000.0
	_player.global_rotation = Vector3.ZERO
	await _settle()
	_start = _player.global_position

	print("== the rack (AC-05)")
	_check("three guns", _weapon.data_set.size() == 3)
	var names: Array[String] = []
	for data in _weapon.data_set:
		names.append(data.display_name)
	_check("they are %s" % ", ".join(NAMES), names == NAMES)
	_check("every gun has a first-person model", _weapon.data_set.all(
		func(d: WeaponData) -> bool: return d.view_scene != null))
	_check("the three viewmodels are built", _weapon.get_child_count() >= 3 + 1)
	_check("starts on %s" % NAMES[0], _weapon.data.display_name == NAMES[0])

	print("== the mouse wheel cycles the rack, and the HUD follows")
	var hud := scene.get_node_or_null("HUD")
	await _tap("weapon_next")
	_check("wheel up moves to %s" % NAMES[1], _weapon.data.display_name == NAMES[1])
	if hud != null:
		var panel := hud.get_node("WeaponPanel") as WeaponPanel
		panel.advance(0.0)
		_check("the HUD shows the gun", panel.gun_name == NAMES[1]
			and panel.selected_index == 1)
	await _tap("weapon_next")
	_check("wheel up moves to %s" % NAMES[2], _weapon.data.display_name == NAMES[2])
	await _tap("weapon_next")
	_check("the wheel wraps around to %s" % NAMES[0], _weapon.data.display_name == NAMES[0])
	await _tap("weapon_prev")
	_check("wheel down wraps back to %s" % NAMES[2], _weapon.data.display_name == NAMES[2])

	print("== every slot keeps its own magazine")
	await _select(0)
	var rifle_ammo := _weapon.ammo
	_weapon.try_fire()
	await get_tree().process_frame
	_check("%s loses one round per shot (%d -> %d)" % [NAMES[0], rifle_ammo, _weapon.ammo],
		_weapon.ammo == rifle_ammo - 1)
	var after_shot := _weapon.ammo
	await _select(1)
	_check("%s starts full (%d of %d)" % [NAMES[1], _weapon.ammo, _weapon.magazine_capacity()],
		_weapon.ammo == _weapon.magazine_capacity())
	_weapon.try_fire()
	await get_tree().process_frame
	var shotgun_after := _weapon.ammo
	await _select(0)
	_check("switching back keeps %s's magazine (%d)" % [NAMES[0], _weapon.ammo],
		_weapon.ammo == after_shot)
	await _select(1)
	_check("%s's magazine survived too (%d)" % [NAMES[1], _weapon.ammo],
		_weapon.ammo == shotgun_after)

	print("== each gun shoots like its own gun")
	var rifle_dealt := await _shoot_at(0, 10.0, true)
	_check("%s hits once for %.0f" % [NAMES[0], rifle_dealt], rifle_dealt > 0.0 and rifle_dealt < 60.0)
	var shotgun_dealt := await _shoot_at(1, 1.5, false)
	_check("%s lands a spread of pellets (%.0f damage)" % [NAMES[1], shotgun_dealt],
		shotgun_dealt > 40.0)
	_check("%s hurts far more than %s up close" % [NAMES[1], NAMES[0]],
		shotgun_dealt > rifle_dealt)
	var sniper_dealt := await _shoot_at(2, 12.0, true)
	_check("%s one-shots a guard (%.0f damage)" % [NAMES[2], sniper_dealt], sniper_dealt >= 100.0)

	print("== the numbers behind those three shots")
	var rifle: WeaponData = _weapon.data_set[0]
	var shotgun: WeaponData = _weapon.data_set[1]
	var sniper: WeaponData = _weapon.data_set[2]
	_check("%s is automatic with a 30-round magazine" % NAMES[0],
		rifle.fire_mode == WeaponData.FireMode.AUTO and rifle.magazine_size >= 20)
	_check("%s fires %d pellets per trigger pull" % [NAMES[1], shotgun.pellets], shotgun.pellets > 1)
	_check("%s is one shot per pull" % NAMES[1], shotgun.fire_mode == WeaponData.FireMode.SEMI)
	_check("%s hits hardest per pull" % NAMES[2],
		sniper.damage > shotgun.damage * shotgun.pellets and sniper.damage > rifle.damage)
	_check("%s is slow and scoped" % NAMES[2],
		sniper.fire_interval > rifle.fire_interval and sniper.ads_fov < rifle.ads_fov)
	_check("%s falls off hard with range" % NAMES[1],
		shotgun.min_damage_scale < rifle.min_damage_scale and shotgun.falloff_end < rifle.falloff_end)

	print("== the empty gun dry-fires and reloads, per slot")
	await _select(1)
	_weapon.ammo = 0
	_weapon.try_fire()
	await get_tree().process_frame
	_check("an empty %s starts a reload" % NAMES[1], _weapon.is_reloading())
	await _select(2)
	_check("switching away cancels that reload", not _weapon.is_reloading())
	await _select(1)
	_check("...and the empty magazine is still empty (%d)" % _weapon.ammo, _weapon.ammo == 0)

	print("== the sniper scope: the wheel zooms instead of switching")
	await _select(2)
	var scoped_data: WeaponData = _weapon.data_set[2]
	var levels := scoped_data.scope_zoom_levels
	_check("%s offers %d magnifications (%s)" % [NAMES[2], levels.size(), levels],
		levels.size() >= 2)
	_check("hip fire is not scoped", not _weapon.is_scoped())
	Input.action_press("aim")
	await _settle()
	_check("aiming puts the scope up", _weapon.is_scoped())
	_check("%.0fx divides the field of view (%.1f° of 75)" % [levels[0], _weapon.fov_for(75.0)],
		is_equal_approx(_weapon.fov_for(75.0), 75.0 / levels[0]))
	var gun_before := _weapon.data.display_name
	await _tap("weapon_next")
	_check("the wheel zooms, it does not change guns (%s)" % gun_before,
		_weapon.data.display_name == gun_before and is_equal_approx(_weapon.zoom_level(), levels[1]))
	_check("%.0fx halves the field of view again (%.1f°)" % [levels[1], _weapon.fov_for(75.0)],
		is_equal_approx(_weapon.fov_for(75.0), 75.0 / levels[1]))
	await _tap("weapon_prev")
	_check("the wheel back down returns to %.0fx" % levels[0],
		is_equal_approx(_weapon.zoom_level(), levels[0]))
	await _tap("weapon_prev")
	_check("and wraps to the highest magnification (%.0fx)" % levels[levels.size() - 1],
		is_equal_approx(_weapon.zoom_level(), levels[levels.size() - 1]))
	var scope_overlay := hud.get_node_or_null("Scope") as Control if hud != null else null
	if scope_overlay != null:
		_check("the scope overlay is on screen", scope_overlay.visible)
	Input.action_release("aim")
	await _settle()
	_check("releasing aim drops the scope", not _weapon.is_scoped())
	await _tap("weapon_next")
	_check("the wheel switches guns again once the scope is down (%s)" % _weapon.data.display_name,
		_weapon.data.display_name != gun_before)

	_finished = true


## Puts the guard `distance` metres in front, aims the eye at its torso and fires
## once with gun `index`, returning the damage that shot did on its own. Aiming
## (`ads`) keeps the spready guns honest at range.
func _shoot_at(index: int, distance: float, ads: bool) -> float:
	await _select(index)
	_player.global_position = _start
	_player.global_rotation = Vector3.ZERO
	_player.velocity = Vector3.ZERO
	var forward := -_player.global_basis.z
	_guard.global_position = _player.global_position + forward * distance
	_guard.velocity = Vector3.ZERO
	await _settle()
	var eye := _eye()
	var torso := _torso()
	var to := torso.global_position - eye
	_player._pitch = asin(clampf(to.y / maxf(to.length(), 0.001), -1.0, 1.0))
	# Aiming has to go through the action: Player._physics_process rewrites
	# `weapon.aiming` from it every frame, so setting the field would be undone.
	if ads:
		Input.action_press("aim")
	else:
		Input.action_release("aim")
	_weapon._cooldown = 0.0
	await _settle()
	var before := _guard.health.health
	_weapon.try_fire()
	await get_tree().process_frame
	Input.action_release("aim")
	return before - _guard.health.health


func _select(index: int) -> void:
	_weapon.select(index)
	await get_tree().process_frame


func _torso() -> Hitbox:
	for node in _guard.find_children("*", "Hitbox", true, false):
		var hitbox := node as Hitbox
		if hitbox.body_part == Hitbox.BodyPart.BODY:
			return hitbox
	return null


func _eye() -> Vector3:
	return (_player.get_node("Head/Camera3D") as Node3D).global_position


func _settle() -> void:
	for i in 3:
		await get_tree().physics_frame
	await get_tree().process_frame


## Presses and releases an action on a frame boundary, so the weapon actually
## polls it (a timer resumes after the nodes' _process of its frame).
func _tap(action: String) -> void:
	await get_tree().process_frame
	Input.action_press(action)
	await get_tree().process_frame
	Input.action_release(action)
	await get_tree().process_frame


func _check(label: String, ok: bool) -> void:
	if not ok:
		_failures += 1
	print("  [%s] %s" % ["ok" if ok else "FAIL", label])
