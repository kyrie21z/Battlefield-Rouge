class_name BuffPool
## Each offer contains one firearm, one blade, and one skill upgrade.
## The first offer presents the three mechanics; the next two expose the rest.

const ALL: Array[Buff] = [
	preload("res://buffs/firearm_damage.tres"),
	preload("res://buffs/firearm_rate.tres"),
	preload("res://buffs/firearm_magazine.tres"),
	preload("res://buffs/blade_damage.tres"),
	preload("res://buffs/blade_speed.tres"),
	preload("res://buffs/blade_range.tres"),
	preload("res://buffs/skill_unlock.tres"),
	preload("res://buffs/skill_duration.tres"),
	preload("res://buffs/skill_cooldown.tres"),
]
const SCHOOL_IDS: Array[StringName] = [&"firearm", &"blade", &"skill"]

static var _initialized := false
static var _bags: Dictionary = {}
static var _next_school := 0


## Clear run-only bags. Gameplay randomness comes from the zone's global seed;
## a nonnegative seed is an explicit test override, never a new random source.
## Preparing bags is deferred until pick(), after the zone has seeded itself.
static func reset(seed_value: int = -1) -> void:
	if seed_value >= 0:
		seed(seed_value)
	_bags.clear()
	_next_school = 0
	_initialized = false


static func _prepare_bags() -> void:
	for school_id in SCHOOL_IDS:
		var bag := for_school(school_id)
		var core: Buff = bag.pop_front()
		_shuffle(bag)
		# pop_back() presents each school's core mechanic on its first draw.
		bag.append(core)
		_bags[school_id] = bag
	_initialized = true


## Cards are unique within an offer. Later offers can repeat the same card;
## RunState retains every selected instance and Stats multiplies its stacks.
static func pick(count: int) -> Array[Buff]:
	if not _initialized:
		_prepare_bags()
	var choices: Array[Buff] = []
	var amount := clampi(count, 0, ALL.size())
	for index in amount:
		var school_id := SCHOOL_IDS[(_next_school + index) % SCHOOL_IDS.size()]
		var chosen := _draw(school_id, choices)
		if chosen != null:
			choices.append(chosen)
	_next_school = (_next_school + amount) % SCHOOL_IDS.size()
	return choices


static func for_school(school_id: StringName) -> Array[Buff]:
	var result: Array[Buff] = []
	for buff in ALL:
		if buff.school_id == school_id:
			result.append(buff)
	return result


static func _draw(school_id: StringName, excluded: Array[Buff]) -> Buff:
	var bag: Array = _bags.get(school_id, [])
	var available: Array[Buff] = []
	for card: Buff in bag:
		if not excluded.has(card):
			available.append(card)
	if available.is_empty():
		bag.clear()
		for card in for_school(school_id):
			if not excluded.has(card):
				bag.append(card)
		_shuffle(bag)
	else:
		# Keep the bag order stable when a larger inspection offer skips cards.
		bag = available
	if bag.is_empty():
		return null
	var card: Buff = bag.pop_back()
	_bags[school_id] = bag
	return card


static func _shuffle(bag: Array) -> void:
	for index in range(bag.size() - 1, 0, -1):
		var other := randi_range(0, index)
		var swap: Buff = bag[index]
		bag[index] = bag[other]
		bag[other] = swap
