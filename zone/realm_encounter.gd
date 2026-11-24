class_name RealmEncounter
extends RefCounted
## Deterministic depth-driven wave tables. Pure data: no nodes, no RNG, no timers.

const WAVES := [
	[[4],[6]],
	[[5],[5,4]],
	[[5,4],[6,5]],
	[[6,5],[6,5,4]],
]
const SLOTH_WAVES := [
	[[5],[7]],
	[[6],[5,4]],
	[[5,4],[6,5]],
	[[6,5],[6,5,4]],
]
const ELITES := [
	[[0],[0]],
	[[0],[0,1]],
	[[1,0],[1,1]],
	[[1,1],[1,1,1]],
]
const SLOTH_KIND_CYCLE := [0,1,2,0]

var depth := 0
var room_index := 0
var realm := &""

func _init(stage_depth: int, room: int, realm_name: StringName) -> void:
	depth = clampi(stage_depth,0,3)
	room_index = clampi(room,0,1)
	realm = realm_name

func wave_count() -> int:
	return _counts().size()

func wave_size(wave_index: int) -> int:
	return _counts()[wave_index]

func elite_count(wave_index: int) -> int:
	return ELITES[depth][room_index][wave_index]

func total_enemies() -> int:
	var total := 0
	for count in _counts(): total += count
	return total

## Slots are ordered: regular units first, signature unit last. Elite quota
## marks the trailing regular slots; signature units are never elite.
func wave_slots(wave_index: int) -> Array[Dictionary]:
	var slots: Array[Dictionary] = []
	var signature := _signature_unit(wave_index)
	var regular := wave_size(wave_index) - (1 if signature != &"" else 0)
	for index in regular:
		slots.append({"type": &"regular", "variant": _regular_variant(wave_index,index), "elite": false})
	if signature != &"":
		slots.append({"type": signature, "variant": 0, "elite": false})
	for index in elite_count(wave_index):
		slots[regular-1-index].elite = true
	return slots

func _counts() -> Array:
	var table: Array = SLOTH_WAVES if realm == &"sloth" else WAVES
	return table[depth][room_index]

func _signature_unit(wave_index: int) -> StringName:
	if wave_index == 0:
		if realm == &"fear": return &"fear_reaper"
		if realm == &"sloth": return &"sloth_mire"
	if wave_index == 1 and depth >= 2:
		if realm == &"fear" and room_index == 1: return &"fear_reaper"
		if realm == &"sloth": return &"sloth_mire"
	return &""

func _regular_variant(wave_index: int, index: int) -> int:
	if realm == &"sloth":
		return SLOTH_KIND_CYCLE[index%SLOTH_KIND_CYCLE.size()]
	if realm == &"wrath" and room_index == 1 and wave_index == 0 and index == 3:
		return 3
	return index%3