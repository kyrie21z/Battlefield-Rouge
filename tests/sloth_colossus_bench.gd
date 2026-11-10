extends "res://tests/sloth_realm_bench.gd"
const BOSS := preload("res://actors/boss/sloth_colossus/sloth_colossus.tscn")
var colossus: SlothColossus
var shard: PsycheShardPickup

func _init() -> void:
	set_meta("boss_arena",true)

func _ready() -> void:
	super._ready()
	for canvas in get_children():
		if canvas is CanvasLayer:
			for child in canvas.get_children():
				if child is Label and child.text.begins_with("SLOTH"):
					child.text = "SLOTH · SLEEPING COLOSSUS\nDefeat the titan · Recover the Shard of Slumber"

func _spawn_encounter() -> void:
	colossus = BOSS.instantiate()
	colossus.position = Vector3(0,0,-8)
	colossus.arena = geometry
	add_child(colossus)
	colossus.setup(player,[])
	player.boons.register_enemy(colossus)
	enemies.append(colossus)
	colossus.realm_defeated.connect(_on_realm_defeated)

func _process(delta: float) -> void:
	super._process(delta)
	if is_instance_valid(colossus) and is_instance_valid(_status):
		_status.text += "\nSLEEPING COLOSSUS: %d HP · Rest %s · Clock %.0f bpm" % [
			colossus.health.health,"dark" if geometry.deprived else "warm",geometry.clock_bpm]

func _on_realm_defeated(_realm: int) -> void:
	player.fragments.configure_deprivation([0])
	shard = (load("res://zone/psyche_shard_pickup.tscn") as PackedScene).instantiate() as PsycheShardPickup
	shard.realm = 0
	shard.position = colossus.global_position + Vector3(2,0,2)
	shard.setup(player)
	add_child(shard)
