extends Node
## Headless check that the three school identities stay distinct (AC-06).
##   godot --headless --path . res://tests/school_icons_test.tscn
## Also checks the three directions used by the nine playable AC-08 buffs.

var _failures := 0
var _finished := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run()
	var ok := _failures == 0 and _finished
	print("%s (%d failed%s)" % ["ALL PASSED" if ok else "FAIL", _failures, "" if _finished else ", run did not finish"])
	get_tree().quit(0 if ok else 1)


func _run() -> void:
	print("== schools (AC-06)")
	var schools := SchoolCatalog.all()
	_check("three schools", schools.size() == 3)
	var ids: Array[StringName] = []
	var hashes: PackedStringArray = []
	for school in schools:
		ids.append(school.id)
		_check("%s has a title" % school.id, not school.title.is_empty())
		_check("%s direction has no digits" % school.id, _no_digits(school.direction))
		_check("%s icon loads" % school.id, school.icon != null)
		var image := school.icon.get_image() if school.icon != null else null
		_check("%s icon has pixels" % school.id, image != null and image.get_width() >= 32 and image.get_height() >= 32)
		if image != null:
			hashes.append(_hash(image))
			_check("%s icon uses its accent" % school.id, _count_near(image, school.accent) > 8)
			_check("%s icon uses its shade" % school.id, _count_near(image, school.shade) > 8)
			_check("%s icon uses the ink line" % school.id, _count_near(image, Color.html("1A1C22")) > 8)
	_check("ids are firearm, blade, skill", ids == [&"firearm", &"blade", &"skill"])
	if schools.size() == 3:
		_check("titles", schools[0].title == "枪械加持" and schools[1].title == "刀具加持" and schools[2].title == "技能获得")
		_check("directions", schools[0].direction == "枪伤·射速·弹匣" and schools[1].direction == "刀伤·刀速·刀距" and schools[2].direction == "主动护盾")
		_check("accents", _same(schools[0].accent, "F5C400") and _same(schools[1].accent, "E0242A") and _same(schools[2].accent, "B36CFF"))
		_check("shades", _same(schools[0].shade, "8A6800") and _same(schools[1].shade, "6E1218") and _same(schools[2].shade, "5D2A8C"))
	_check("icons differ", hashes.size() == 3 and hashes[0] != hashes[1] and hashes[0] != hashes[2] and hashes[1] != hashes[2])
	_check("find misses unknown ids", SchoolCatalog.find(&"") == null and SchoolCatalog.find(&"nope") == null)
	_check("find hits firearm", schools.size() == 3 and SchoolCatalog.find(&"firearm") == schools[0])

	print("== buff select shows the three directions")
	var select := (load("res://ui/buff_select.tscn") as PackedScene).instantiate()
	add_child(select)
	BuffPool.reset(606)
	select.setup(BuffPool.pick(3), "测试：枪械、刀具、技能")
	var badges: Array[SchoolBadge] = []
	_collect(select, badges)
	_check("three badges on the select screen", badges.size() == 3)
	if badges.size() == 3:
		_check("badge order", badges[0].school.id == &"firearm" and badges[1].school.id == &"blade" and badges[2].school.id == &"skill")
		var icon := badges[0].get_node_or_null("Row/Icon") as TextureRect
		_check("badge paints a TextureRect", icon != null and icon.texture == badges[0].school.icon)
		_check("badge ignores clicks", badges[0].mouse_filter == Control.MOUSE_FILTER_IGNORE)
	_finished = true


func _collect(node: Node, into: Array[SchoolBadge]) -> void:
	if node is SchoolBadge:
		into.append(node as SchoolBadge)
	for child in node.get_children():
		_collect(child, into)


func _no_digits(text: String) -> bool:
	for i in 10:
		if text.contains(str(i)):
			return false
	return true


func _same(got: Color, hex: String) -> bool:
	return got.is_equal_approx(Color.html(hex))


func _count_near(image: Image, want: Color) -> int:
	var hits := 0
	var step := 3
	for y in range(0, image.get_height(), step):
		for x in range(0, image.get_width(), step):
			var pixel := image.get_pixel(x, y)
			if absf(pixel.r - want.r) < 0.08 and absf(pixel.g - want.g) < 0.08 and absf(pixel.b - want.b) < 0.08 and pixel.a > 0.5:
				hits += 1
	return hits


func _hash(image: Image) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(image.get_data())
	return ctx.finish().hex_encode()


func _check(label: String, ok: bool) -> void:
	if not ok:
		_failures += 1
	print("  %s  %s" % ["ok" if ok else "FAIL", label])
