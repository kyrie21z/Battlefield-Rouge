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
	"res://maps/realms/wrath_1.tscn",
	"res://maps/realms/sorrow_1.tscn",
]


func _ready() -> void:
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

		# claiming opens the normal three-card offer
		stage.claim_talent()
		await get_tree().process_frame
		_check(not stage.orb_pending(), "orb is consumed on claim")
		_check(is_instance_valid(stage.selection), "three-card picker opened")

	stage.queue_free()
	await get_tree().process_frame
