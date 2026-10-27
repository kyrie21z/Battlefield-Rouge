class_name SchoolCatalog
## The three MVP build directions. Identity is separate from buff effects.


const ICON_BERSERKER: Texture2D = preload("res://assets/ui/schools/berserker.svg")
const ICON_ARMS_DEALER: Texture2D = preload("res://assets/ui/schools/arms_dealer.svg")
const ICON_SKILL: Texture2D = preload("res://assets/ui/buffs/skill_unlock.svg")

static var _all: Array[School] = []


static func all() -> Array[School]:
	if _all.is_empty():
		_all = [
			_make(&"firearm", "枪械加持", "枪伤·射速·弹匣", "F5C400", "8A6800", ICON_ARMS_DEALER),
			_make(&"blade", "刀具加持", "刀伤·刀速·刀距", "E0242A", "6E1218", ICON_BERSERKER),
			_make(&"skill", "技能获得", "主动护盾", "B36CFF", "5D2A8C", ICON_SKILL),
		]
	return _all


static func find(id: StringName) -> School:
	for school in all():
		if school.id == id:
			return school
	return null


static func get_school(id: StringName) -> School:
	return find(id)


static func _make(id: StringName, title: String, direction: String, accent: String, shade: String, icon: Texture2D) -> School:
	var school := School.new()
	school.id = id
	school.title = title
	school.direction = direction
	school.accent = Color.html(accent)
	school.shade = Color.html(shade)
	school.icon = icon
	return school
