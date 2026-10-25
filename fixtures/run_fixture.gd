class_name RunFixture
extends Resource
## A named starting point for a run (Cut-001b AC-07: the same starting point
## can play a run again). It fixes what a run depends on before the first
## input: which zone it starts in, which buffs the player already has, and the
## seed every random choice in the run comes from. The same fixture and the
## same inputs give the same run, at the fixed step (docs/adr/0005).
## One file per id in res://fixtures/, named after the id in lower case.

@export var id := ""
@export_multiline var description := ""
@export var run_seed := 0
## Index into RunState.ZONE_SCENES. 0 is a new run.
@export var start_zone := 0
## Buffs the player starts with, as if picked earlier in the run.
@export var buffs: Array[Buff] = []


## The fixture with this id, or null if there is none.
static func by_id(fixture_id: String) -> RunFixture:
	var path := "res://fixtures/%s.tres" % fixture_id.to_lower()
	if not ResourceLoader.exists(path):
		return null
	return load(path) as RunFixture
