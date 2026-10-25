class_name SchoolCatalog
## The three school identities (AC-06). Slices call all() or find().
## Icons are project art in assets/ui/schools/. No effect numbers.


const ICON_BERSERKER: Texture2D = preload("res://assets/ui/schools/berserker.svg")
const ICON_ARMS_DEALER: Texture2D = preload("res://assets/ui/schools/arms_dealer.svg")
const ICON_HAWKEYE: Texture2D = preload("res://assets/ui/schools/hawkeye.svg")

static var _all: Array[School] = []


static func all() -> Array[School]:
	if _all.is_empty():
		_all = [
			_make(&"berserker", "狂战士", "近战", "E0242A", "6E1218", ICON_BERSERKER),
			_make(&"arms_dealer", "军火大亨", "弹药特性", "F5C400", "8A6800", ICON_ARMS_DEALER),
			_make(&"hawkeye", "鹰眼", "爆头收益", "14C8D4", "0A6670", ICON_HAWKEYE),
		]
	return _all


static func find(id: StringName) -> School:
	for school in all():
		if school.id == id:
			return school
	return null


static func _make(id: StringName, title: String, direction: String, accent: String, shade: String, icon: Texture2D) -> School:
	var school := School.new()
	school.id = id
	school.title = title
	school.direction = direction
	school.accent = Color.html(accent)
	school.shade = Color.html(shade)
	school.icon = icon
	return school
