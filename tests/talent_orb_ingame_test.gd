extends Node
## Verifies the talent orb really shows up in the shipping realm scenes:
## loads a real map, clears it the same way gameplay does, and checks the orb
## spawns in front of the exit gate with the right interaction radius.
##
## Run:  godot --headless --path . res://tests/talent_orb_ingame_test.tscn

var _fail := 0
var _ok := 0

const SCENES: Array[String] = [
	"res://maps/realms/sloth_1.tscn",
	"res://maps/realms/fear_1.tscn",
	"res://maps/realms/fear_2.tscn",
	"res://maps/realms/wrath_1.tscn",
	"res://maps/realms/sorrow_1.tscn",
]


func _ready() -> void:
	# the realm intro panel is a UI concern; these tests only care about the flow
	MetaProgression.introduced_realms.assign([0,1,2,3])
	for path in SCENES:
		await _check_scene(path)
	print("")
	if _fail == 0:
		print("ALL PASSED (%d checks, 0 failed)" % _ok)
	else:
		print("FAILED (%d checks, %d failed)" % [_ok, _fail])
	get_tree().quit(1 if _fail > 0 else 0)


func _check(ok: bool, label: String) -> void:
	if ok:
		_ok += 1
		print("  [ok] ", label)
	else:
		_fail += 1
		print("  [FAIL] ", label)


func _cast_down(stage: RealmStage, from: Vector3, length: float) -> Dictionary:
	var ray := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * length, CollisionLayers.WORLD)
	return stage.get_world_3d().direct_space_state.intersect_ray(ray)


func _check_scene(path: String) -> void:
	print("== ", path)
	var packed := load(path) as PackedScene
	_check(packed != null, "scene loads")
	if packed == null:
		return
	var stage: RealmStage = packed.instantiate() as RealmStage
	add_child(stage)
	await get_tree().process_frame
	await get_tree().process_frame

	_check(stage != null, "root instantiates as RealmStage")
	_check(is_instance_valid(stage.gate), "exit gate exists")
	_check(stage.talent_orb == null, "no orb while enemies are alive")

	# empty the roster the way a full clear leaves it, then let the stage run its
	# own clear check on the next frame
	for actor in stage.enemies:
		if is_instance_valid(actor):
			actor.queue_free()
	stage.enemies.clear()
	await get_tree().process_frame
	stage._check_clear()
	await get_tree().process_frame
	await get_tree().process_frame

	_check(stage.cleared, "stage reports cleared after the last kill")
	_check(is_instance_valid(stage.talent_orb), "talent orb spawned")
	_check(stage.orb_pending(), "orb is pending (awaiting F)")

	if is_instance_valid(stage.talent_orb):
		var orb: TalentOrb = stage.talent_orb
		var gap: float = orb.global_position.distance_to(stage.gate.global_position)
		print("     orb at %s, gate at %s, gap %.2f m" % [orb.global_position, stage.gate.global_position, gap])
		_check(gap > 0.5 and gap < 3.0, "orb stands in front of the gate (%.2f m)" % gap)
		_check(orb.global_position.y > 0.5, "orb hovers above the floor (y=%.2f)" % orb.global_position.y)

		# the player must be able to reach it
		var player_pos: Vector3 = stage.player.global_position
		var reach: float = player_pos.distance_to(orb.global_position)
		print("     player is %.1f m from the orb" % reach)
		_check(orb.player_in_range(stage.player) == (reach <= TalentOrb.INTERACT_RANGE),
			"range check agrees with real distance")

		# solid body: must exist, be on WORLD, and sit inside the interact range
		var body := orb.get_node_or_null("Body") as StaticBody3D
		_check(body != null, "orb has a solid body")
		if body != null:
			_check(body.collision_layer == CollisionLayers.WORLD, "body is on the WORLD layer")
			var cs := body.get_child(0) as CollisionShape3D
			var sphere := cs.shape as SphereShape3D
			_check(sphere != null and sphere.radius >= 0.4, "body has a sphere shape")
			_check(sphere.radius < TalentOrb.INTERACT_RANGE,
				"body radius (%.2f) is smaller than the interact range (%.2f)"
				% [sphere.radius, TalentOrb.INTERACT_RANGE])

		# Raised exit landings put the gate above the room floor. The orb has to
		# hover over the floor below it, never sink into stairs or masonry.
		var down := PhysicsRayQueryParameters3D.create(orb.global_position,
			orb.global_position + Vector3.DOWN * 9.0, CollisionLayers.WORLD)
		if body != null:
			down.exclude = [body.get_rid()]
		var floor_hit := stage.get_world_3d().direct_space_state.intersect_ray(down)
		_check(not floor_hit.is_empty() and (floor_hit["normal"] as Vector3).y >= 0.7,
			"walkable floor sits below the orb")
		if not floor_hit.is_empty():
			var floor_y: float = (floor_hit["position"] as Vector3).y
			var hover: float = orb.global_position.y - floor_y
			print("     orb hovers %.2f m over the floor (orb y=%.2f, floor y=%.2f)"
				% [hover, orb.global_position.y, floor_y])
			_check(absf(hover - orb.base_height) <= 0.35,
				"orb keeps its base height over the real floor (%.2f m)" % hover)

			# Stand the player on the floor in front of the orb, the way a real
			# clear leaves them, and make sure the stairs do not hide it.
			var toward_player: Vector3 = stage.player.global_position - orb.global_position
			toward_player.y = 0.0
			if toward_player.length() < 0.1:
				toward_player = Vector3(0.0, 0.0, 1.0)
			var approach := orb.global_position + toward_player.normalized() * 1.8
			var stand_hit := _cast_down(stage, approach + Vector3.UP * 1.5, 9.0)
			_check(not stand_hit.is_empty(), "walkable ground in front of the orb")
			if not stand_hit.is_empty():
				stage.player.global_position = (stand_hit["position"] as Vector3) + Vector3.UP * 0.1
				stage.player.velocity = Vector3.ZERO
				await get_tree().physics_frame
				await get_tree().physics_frame
				_check(orb.player_in_range(stage.player), "player standing in front can claim the orb")
				if body != null:
					var sight := PhysicsRayQueryParameters3D.create(stage.player.eye_position(),
						orb.global_position, CollisionLayers.WORLD)
					var blocker := stage.get_world_3d().direct_space_state.intersect_ray(sight)
					_check(blocker.is_empty() or blocker["collider"] == body,
						"stairs or walls do not hide the orb from the player")

			# Idle bobbing must keep the orb over its floor instead of snapping
			# back to a hard-coded height when the assembly finishes.
			orb.set_idle_enabled(true)
			for _i in 8:
				await get_tree().physics_frame
			var drift: float = absf(orb.global_position.y - (floor_y + orb.base_height))
			print("     idle bob drift %.2f m (bob %.2f m)" % [drift, orb.bob_height])
			_check(drift <= orb.bob_height + 0.05,
				"idle bobbing keeps the floor-relative hover")

		# claiming opens the normal three-card offer
		stage.claim_talent()
		await get_tree().process_frame
		_check(not stage.orb_pending(), "orb is consumed on claim")
		if is_instance_valid(orb):
			_check(orb.get_node_or_null("Body").collision_layer == 0,
				"claiming turns the solid body off")
		_check(is_instance_valid(stage.selection), "three-card picker opened")

	stage.queue_free()
	await get_tree().process_frame
