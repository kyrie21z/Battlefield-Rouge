extends Node
## Headless check of the three melee weapons (Cut-001b AC-05). Run from the
## project root (a scene, not a --script, so the autoloads exist):
##   godot --headless --path . res://tests/melee_test.tscn
## Prints one line per check. Exits 1 if a check failed or if the run stopped
## before the last check, so it cannot pass by accident.
##
## Every check is against a real guard: the weapons are told apart by where they
## hit, how hard and how fast, not by reading their numbers back. Guards are
## frozen so the run is about the swing, not about their AI.
##
## The swing itself is checked on the projection: where the tip of the blade
## actually lands on screen at both ends of the cut. That is the only way to tell
## "crossed the whole screen" from "wobbled next to the crosshair".

const WEAPONS := ["匕首", "斧", "太刀"]
## Enough health that a damage sponge never dies mid-run. A dead hitbox takes
## itself off the hit layer, so reviving one would silently stop working.
const SPONGE_HEALTH := 100000.0
## How far from the requested screen point the measured tip may land, in
## normalised screen units (1.0 = half the screen).
const AIM_TOLERANCE := 0.18

var _failures := 0
var _finished := false
var _swings := 0
var _hits := 0
var _player: Player
var _melee: MeleeWeapon
## Where the player starts. Every placement puts them back here, so a run of
## swings does not lunge them across the map and into a wall.
var _player_start := Vector3.ZERO
## [0] and [1] are sponges, [2] keeps its 100 HP so a one-hit kill is testable.
var _guards: Array[Enemy] = []


func _ready() -> void:
	await _run()
	var ok := _failures == 0 and _finished
	print("%s (%d failed%s)" % ["ALL PASSED" if ok else "FAIL", _failures, "" if _finished else ", run did not finish"])
	get_tree().quit(0 if ok else 1)


func _run() -> void:
	var scene: Node = load("res://maps/zone_1.tscn").instantiate()
	add_child(scene)
	await get_tree().process_frame
	_player = scene.get_node("Player") as Player
	_melee = _player.melee
	_melee.swing_started.connect(func(_i: int, _s: int): _swings += 1)
	_melee.hit_landed.connect(func(_head: bool, _killed: bool): _hits += 1)
	for guard in get_tree().get_nodes_in_group("enemy"):
		var enemy := guard as Enemy
		enemy.set_physics_process(false)
		_guards.append(enemy)
	for i in mini(2, _guards.size()):
		_guards[i].health.max_health = SPONGE_HEALTH
		_guards[i].health.health = SPONGE_HEALTH
	_player.global_rotation = Vector3.ZERO
	await _settle()
	_player_start = _player.global_position

	print("== the loadout (AC-05)")
	_check("three melee weapons", _melee.weapons.size() == 3)
	var names: Array[String] = []
	for data in _melee.weapons:
		names.append(data.display_name)
	_check("they are %s" % ", ".join(WEAPONS), names == WEAPONS)
	_check("every weapon has a first-person model", _melee.weapons.all(
		func(d: MeleeData) -> bool: return d.view_scene != null))
	_check("the three viewmodels are built", _melee.get_node("Pivot").get_child_count() == 3)
	var models := 0
	for view in _melee.get_node("Pivot").get_children():
		if view.find_children("*", "MeshInstance3D", true, false).size() > 0:
			models += 1
	_check("each viewmodel carries a mesh", models == 3)

	print("== 快 / 慢 and 近 / 中 / 远 are real differences")
	var knife: MeleeData = _melee.weapons[0]
	var axe: MeleeData = _melee.weapons[1]
	var tachi: MeleeData = _melee.weapons[2]
	_check("匕首 is the fastest, 斧 the slowest", knife.cycle() < tachi.cycle() and tachi.cycle() < axe.cycle())
	_check("匕首 is the shortest, 太刀 the longest", knife.reach < axe.reach and axe.reach < tachi.reach)
	_check("斧 hits hardest, 匕首 least", knife.damage < tachi.damage and tachi.damage < axe.damage)
	_check("斧 is committed longest before it cuts", axe.windup > tachi.windup and tachi.windup > knife.windup)

	print("== Q cycles the loadout")
	_check("starts on 匕首", _melee.current().display_name == "匕首")
	await _tap("switch_melee")
	_check("Q moves to 斧", _melee.current().display_name == "斧")
	await _tap("switch_melee")
	_check("Q moves to 太刀", _melee.current().display_name == "太刀")
	await _tap("switch_melee")
	_check("Q wraps back to 匕首", _melee.current().display_name == "匕首")
	var hud := scene.get_node_or_null("HUD")
	if hud != null:
		_check("the HUD names the selected weapon", (hud.get_node("Melee") as Label).text.contains("匕首"))

	print("== each cut travels the screen the way its style promises")
	for i in WEAPONS.size():
		var data: MeleeData = _melee.weapons[i]
		await _select(i)
		await _clear_area()
		var cut := await _measure_cut(data)
		var from: Vector2 = cut["from_tip"]
		var to: Vector2 = cut["to_tip"]
		_check("%s starts within %.2f of its aim (%.2f, %.2f)" % [
			data.display_name, AIM_TOLERANCE, from.x, from.y],
			from.distance_to(data.cut_from_aim) <= AIM_TOLERANCE)
		_check("%s ends within %.2f of its aim (%.2f, %.2f)" % [
			data.display_name, AIM_TOLERANCE, to.x, to.y],
			to.distance_to(data.cut_to_aim) <= AIM_TOLERANCE)
		var style_ok := true
		match data.swing_style:
			MeleeData.SwingStyle.CHOP:
				# Two-handed, straight down the middle of the frame: top to bottom,
				# never off the centre line.
				style_ok = absf(from.x) < 0.2 and absf(to.x) < 0.2 \
					and from.y - to.y > 1.2 and from.y > 0.55 and to.y < -0.55
			MeleeData.SwingStyle.RISING_CUT:
				# Lower-left corner to upper-right corner, and the whole frame:
				# the tip has to touch both corners, not stop short of them.
				style_ok = to.x - from.x > 1.9 and to.y - from.y > 1.9 \
					and from.x < -0.9 and from.y < -0.9 and to.x > 0.9 and to.y > 0.9
			MeleeData.SwingStyle.FALLING_CUT:
				# Upper-left corner to lower-right corner.
				style_ok = to.x - from.x > 1.7 and from.y - to.y > 1.7 \
					and from.x < -0.8 and from.y > 0.8 and to.x > 0.8 and to.y < -0.8
		_check("%s covers the screen in its style (%.2f,%.2f -> %.2f,%.2f)" % [
			data.display_name, from.x, from.y, to.x, to.y], style_ok)
		# A tip behind the eye still has a picture coordinate, so the screen point
		# alone can vouch for a cut that is entirely clipped. Depth is the check
		# that the blade is really in front of the player at both ends.
		_check("%s keeps its tip in front of the eye (%.2f m / %.2f m)" % [
			data.display_name, cut["from_depth"], cut["to_depth"]],
			cut["from_depth"] > 0.3 and cut["to_depth"] > 0.3)
		# A blade held edge on is a line, not a silhouette. Where the swing starts
		# the blade has to read as a blade, but the follow-through is allowed to
		# finish edge on: there the edge-leading roll is the thing that matters, and
		# it wins wherever the cut really sweeps across the frame.
		if data.edge_side != 0:
			_check("%s shows its face where it reads (%.2f)" % [
				data.display_name, cut["from_facing"]], cut["from_facing"] > 0.5)
			# And the edge has to be the part that leads where the blade crosses
			# the frame. A blade showing its flat with the spine forward looks
			# like a slap, which is the bug this guards.
			_check("%s cuts edge first (%.2f)" % [data.display_name, cut["mid_edge"]],
				cut["mid_edge"] > 0.7)
		else:
			# A symmetric head has no edge to lead, but its blade plane still has to
			# stand the right way round: a two-handed chop straight down the middle
			# puts the head's plate in the *sagittal* plane, i.e. seen nearly edge
			# on, and a plate turned broadside reads as slapping the axe flat. The
			# .tres turns it with `*_roll`; keep it well under half face.
			_check("%s falls edge first, not flat (face %.2f / %.2f)" % [
				data.display_name, cut["from_facing"], cut["to_facing"]],
				cut["from_facing"] < 0.45 and cut["to_facing"] < 0.45)

	print("== V swings and damages a guard (real input path)")
	await _select(0)
	var guard := _guards[0]
	await _place_guard(guard, 1.3)
	var before := guard.health.health
	var hp_before: float = _player.health.health
	_swings = 0
	await _tap("melee")
	_check("pressing V starts exactly one swing", _swings == 1)
	await _wait(knife.windup + knife.active + 0.08)
	_check("the guard in front lost health", guard.health.health < before)
	_check("the player did not hit itself", is_equal_approx(_player.health.health, hp_before))
	await _wait_idle()

	print("== the swing has to finish before the next one")
	_melee.swing_now()
	_check("a swing during the recovery is refused", not _melee.swing_now())
	await _wait_idle()

	print("== 近 / 中 / 远 measured on a real guard")
	await _select(2)
	var dealt := await _place_and_swing(guard, tachi, 3.4)
	_check("3.4 m is out of reach for the longest weapon", is_zero_approx(dealt))
	dealt = await _place_and_swing(guard, tachi, 2.8)
	_check("2.8 m: 太刀 reaches", dealt > 0.0)
	await _select(1)
	dealt = await _place_and_swing(guard, axe, 2.8)
	_check("2.8 m: 斧 does not reach", is_zero_approx(dealt))
	dealt = await _place_and_swing(guard, axe, 2.2)
	_check("2.2 m: 斧 reaches", dealt > 0.0)
	await _select(0)
	dealt = await _place_and_swing(guard, knife, 2.2)
	_check("2.2 m: 匕首 does not reach", is_zero_approx(dealt))
	dealt = await _place_and_swing(guard, knife, 1.3)
	_check("1.3 m: 匕首 reaches", dealt > 0.0)

	print("== the arc is in front of the player, not around them")
	await _send_behind(guard)
	before = guard.health.health
	await _swing(knife)
	_check("a guard at the player's back is untouched", is_equal_approx(guard.health.health, before))

	print("== 斧 clears a group, 匕首 picks one body")
	var second := _guards[1]
	await _place_pair(guard, second)
	var first_before := guard.health.health
	var second_before := second.health.health
	_hits = 0
	await _swing(knife)
	var first_lost := guard.health.health < first_before
	var second_lost := second.health.health < second_before
	_check("匕首 hits exactly one body (%d hits, %s / %s)" % [
		_hits, first_lost, second_lost], _hits == 1 and first_lost != second_lost)
	await _select(1)
	await _place_pair(guard, second)
	first_before = guard.health.health
	second_before = second.health.health
	_hits = 0
	await _swing(axe)
	_check("斧 hits both bodies in the arc (%d hits, %.0f / %.0f lost)" % [
		_hits, first_before - guard.health.health, second_before - second.health.health],
		_hits == 2 and guard.health.health < first_before and second.health.health < second_before)

	print("== the swing animation actually moves the viewmodel")
	await _select(0)
	await _place_guard(guard, 1.4)
	var pivot := _melee.get_node("Pivot") as Node3D
	var rest := _melee.tip_screen_position()
	_melee.swing_now()
	await _wait(knife.windup + knife.active * 0.5)
	_check("the viewmodel leaves its rest pose while swinging",
		_melee.tip_screen_position().distance_to(rest) > 0.2)
	await _wait_idle()
	_check("it returns to rest and hides",
		_melee.tip_screen_position().distance_to(rest) < 0.05
		and not (pivot.get_child(0) as Node3D).visible)

	print("== 高 damage: the 斧 drops a 100 HP guard in one swing")
	var full_health := _guards[2]
	await _place_guard(full_health, 1.5)
	await _select(1)
	_check("the guard starts at full health", is_equal_approx(full_health.health.health, 100.0))
	await _swing(axe)
	_check("one 斧 swing kills", full_health.health.is_dead())

	print("== every melee dashes into a body that is already close")
	# Every other guard spawns within reach of the player, so "nothing nearby"
	# has to be arranged rather than assumed.
	await _clear_area()
	var step_from := _player.global_position
	var lunges := [0]
	_melee.lunge.connect(func(_d: Vector3, _s: float, _t: float): lunges[0] += 1)

	# Nothing in range, no movement key held: nobody moves, whatever the weapon.
	for i in WEAPONS.size():
		await _select(i)
		await _clear_area()
		step_from = _player.global_position
		lunges[0] = 0
		await _swing(_melee.weapons[i])
		_check("%s at empty air does not move the player (%d lunge)" % [
			_melee.weapons[i].display_name, lunges[0]],
			lunges[0] == 0 and step_from.distance_to(_player.global_position) < 0.05)

	# Facing a body, standing still: every weapon closes the gap and lands. This is
	# the "面朝敌人按 V，哪怕不动方向键" case.
	for i in WEAPONS.size():
		var weapon: MeleeData = _melee.weapons[i]
		await _select(i)
		await _place_guard(guard, 1.5, 0.3)
		step_from = _player.global_position
		var toward := guard.global_position - step_from
		toward.y = 0.0
		var hp_before_swing := guard.health.health
		lunges[0] = 0
		await _swing(weapon)
		var step := _player.global_position - step_from
		step.y = 0.0
		_check("%s dashes into a body (%d lunge, %.2f m)" % [
			weapon.display_name, lunges[0], step.length()],
			lunges[0] == 1 and step.length() > 0.15)
		_check("%s dashes toward the body, not the aim" % weapon.display_name,
			step.normalized().dot(toward.normalized()) > 0.7)
		_check("%s dash is a dash, not a teleport (%.2f m, at most %.2f)" % [
			weapon.display_name, step.length(), weapon.lunge + 0.2],
			step.length() <= weapon.lunge + 0.2)
		_check("%s lands after the dash" % weapon.display_name, guard.health.health < hp_before_swing)

	# The arc turns onto the body too: a guard ~43 degrees off the crosshair is
	# outside the 匕首's 70 degree cone, so without the snap this swing would whiff.
	await _select(0)
	await _place_guard(guard, 1.35, 0.75)
	var off_axis_before := guard.health.health
	await _swing(knife)
	_check("the arc snaps onto a body outside the swing cone (%.0f dmg)" % [
		off_axis_before - guard.health.health], guard.health.health < off_axis_before)

	# Out of magnet range but still inside the 太刀's reach: it cuts, it does not
	# dash. This is what "距离敌人较近时才有" means in numbers.
	await _select(2)
	await _place_guard(guard, 2.9)
	step_from = _player.global_position
	lunges[0] = 0
	var hit_before := guard.health.health
	await _swing(tachi)
	var far_step := _player.global_position - step_from
	far_step.y = 0.0
	_check("2.9 m: 太刀 cuts without dashing (%d lunge, %.2f m moved, %.0f dmg)" % [
		lunges[0], far_step.length(), hit_before - guard.health.health],
		lunges[0] == 0 and far_step.length() < 0.05 and guard.health.health < hit_before)

	print("== a swing at empty air moves nobody")
	await _select(2)
	await _clear_area()
	step_from = _player.global_position
	lunges[0] = 0
	await _swing(tachi)
	_check("no target, no dash",
		step_from.distance_to(_player.global_position) < 0.05 and lunges[0] == 0)

	print("== 斧 shoves the body it hits")
	await _select(1)
	await _place_guard(guard, 1.6)
	# Physics back on for one swing, so the shove is a real displacement.
	guard.set_physics_process(true)
	guard.apply_impact(Vector3.ZERO, 0.0, 0.0)
	var start := guard.global_position
	await _swing(axe)
	await get_tree().physics_frame
	var moved := Vector2(guard.global_position.x - start.x, guard.global_position.z - start.z).length()
	_check("the struck guard is pushed away from the player", moved > 0.05)
	guard.set_physics_process(false)

	_finished = true


## Selects a weapon, waiting for any swing in flight first: a switch mid-swing
## is refused on purpose.
func _select(index: int) -> void:
	await _wait_idle()
	_melee.select(index)
	_check("selected %s" % WEAPONS[index], _melee.current().display_name == WEAPONS[index])


## Swings and reports where the tip of the blade really was, on screen, at the
## start and at the end of the cut, how far in front of the eye it was, plus how
## much of the blade's flat showed and whether the edge was the part leading.
func _measure_cut(data: MeleeData) -> Dictionary:
	_melee.swing_now()
	await _wait(maxf(data.windup * 0.92, 0.002))
	var from := _melee.tip_screen_position()
	var from_depth := _melee.tip_depth()
	var from_facing := _melee.blade_facing()
	# Half way through the cut, where the blade crosses in front of the player.
	await _wait(data.windup * 0.08 + data.active * 0.5)
	var mid_edge := _melee.edge_leading()
	await _melee.strike_finished
	var to := _melee.tip_screen_position()
	var to_depth := _melee.tip_depth()
	var to_facing := _melee.blade_facing()
	await _wait_idle()
	return {
		"from_tip": from,
		"to_tip": to,
		"from_depth": from_depth,
		"to_depth": to_depth,
		"from_facing": from_facing,
		"to_facing": to_facing,
		"mid_edge": mid_edge,
	}


## Puts the guard's torso hitbox exactly `distance` metres from the player's eye,
## which is what `reach` is measured against. Placing the body by its origin
## instead is off by however far the model's chest sits from its feet.
func _place_guard(guard: Enemy, distance: float, sideways := 0.0) -> void:
	_player.global_position = _player_start
	_player.global_rotation = Vector3.ZERO
	_player.velocity = Vector3.ZERO
	# Drop any step still draining from the previous swing, so a measurement does
	# not start with the player already drifting.
	_player._lunge_left = 0.0
	var forward := -_player.global_basis.z
	var right := _player.global_basis.x
	guard.global_position = _player.global_position + forward * distance + right * sideways
	guard.velocity = Vector3.ZERO
	await _settle()
	var torso := _torso(guard)
	if torso == null:
		return
	for attempt in 2:
		var current := torso.global_position.distance_to(_eye())
		guard.global_position += forward * (distance - current)
		await _settle()


## Place, swing, and report how much health the guard lost. Every reach check
## goes through here: a swing lunges the player forward, so the geometry has to
## be reset for each measurement or the next one starts closer.
func _place_and_swing(guard: Enemy, data: MeleeData, distance: float) -> float:
	await _place_guard(guard, distance)
	var before := guard.health.health
	await _swing(data)
	return before - guard.health.health


## Two guards either side of the player's aim, both within every weapon's reach.
func _place_pair(first: Enemy, second: Enemy, distance := 1.3, spread := 0.32) -> void:
	await _place_guard(first, distance, -spread)
	await _place_guard(second, distance, spread)


func _torso(guard: Enemy) -> Hitbox:
	for node in guard.find_children("*", "Hitbox", true, false):
		var hitbox := node as Hitbox
		if hitbox.body_part == Hitbox.BodyPart.BODY:
			return hitbox
	return null


func _eye() -> Vector3:
	return (_player.get_node("Head/Camera3D") as Node3D).global_position


func _send_behind(guard: Enemy) -> void:
	_player.global_position = _player_start
	_player.velocity = Vector3.ZERO
	guard.global_position = _player.global_position + _player.global_basis.z * 1.2
	guard.velocity = Vector3.ZERO
	await _settle()


## Moves every guard well out of melee reach, so a swing really has no target.
func _clear_area() -> void:
	for i in _guards.size():
		var guard := _guards[i]
		guard.global_position = _player_start + Vector3(10.0 + i * 2.0, 0.0, 10.0)
		guard.velocity = Vector3.ZERO
	await _settle()


## One full swing, then wait out the recovery so the weapon is ready again.
func _swing(data: MeleeData) -> void:
	_melee.swing_now()
	await _wait(data.windup + data.active + 0.08)
	await _wait_idle()


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _wait_idle() -> void:
	var guard_frames := 0
	while _melee.is_swinging() and guard_frames < 600:
		await get_tree().process_frame
		guard_frames += 1
	await get_tree().process_frame


## Lets transforms and the physics state settle after a teleport, so the hitbox
## global positions the query reads are the new ones.
func _settle() -> void:
	for i in 3:
		await get_tree().physics_frame
	await get_tree().process_frame


## Presses and releases an action. Waits for a frame boundary first: a timer
## resumes after the nodes' _process of its frame, and a press made then would
## be released before the weapon ever polls it.
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
