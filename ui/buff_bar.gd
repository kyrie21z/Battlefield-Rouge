class_name BuffBar
extends Control
## One icon per owned buff: the buff's own icon, a border in its school accent
## and a ×N stack badge. Empty runs hide the whole bar. Reads RunState only.

const ICON_SIZE := 56.0
const GAP := 10.0

var entries: Array[Dictionary] = []


func _ready() -> void:
	refresh()


func refresh() -> void:
	entries.clear()
	var index: Dictionary = {}
	for buff: Buff in RunState.buffs:
		var key := _buff_key(buff)
		if index.has(key):
			var seen: Dictionary = entries[index[key]]
			seen["count"] = int(seen["count"]) + 1
		else:
			index[key] = entries.size()
			entries.append({"buff": buff, "count": 1, "accent": _accent(buff)})
	var count := entries.size()
	visible = count > 0
	offset_right = offset_left + (float(count) * (ICON_SIZE + GAP) - GAP if count > 0 else 0.0)
	offset_bottom = offset_top + ICON_SIZE
	queue_redraw()


func stack_count(id: StringName) -> int:
	for entry: Dictionary in entries:
		var buff: Buff = entry["buff"]
		if buff.id == id:
			return int(entry["count"])
	return 0


func accent_for(id: StringName) -> Color:
	for entry: Dictionary in entries:
		if entry["buff"].id == id:
			return entry["accent"]
	return Color.TRANSPARENT


func count_label(index: int) -> String:
	return "×%d" % int(entries[index]["count"])


func icon_at(index: int) -> Texture2D:
	return entries[index]["buff"].icon


func icon_rect(index: int) -> Rect2:
	return Rect2(Vector2(float(index) * (ICON_SIZE + GAP), 0.0), Vector2(ICON_SIZE, ICON_SIZE))


func _accent(buff: Buff) -> Color:
	var school := SchoolCatalog.find(buff.school_id)
	return school.accent if school != null else HudStyle.MUTED


func _buff_key(buff: Buff) -> String:
	return String(buff.id) if buff.id != &"" else buff.resource_path + buff.title


func _draw() -> void:
	var font := ThemeDB.fallback_font
	for i in entries.size():
		var entry: Dictionary = entries[i]
		var box := icon_rect(i)
		var accent: Color = entry["accent"]
		var points := HudStyle.bevel_points(box, 8.0)
		draw_colored_polygon(points, Color(0.015, 0.035, 0.05, 0.9))
		var outline := points.duplicate()
		outline.append(points[0])
		draw_polyline(outline, accent, 2.0, true)
		HudStyle.draw_icon(self, entry["buff"].icon, box.grow(-8.0), Color.WHITE)

		var text := count_label(i)
		var text_width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		var badge := Rect2(box.end.x - text_width - 10.0, box.end.y - 22.0, text_width + 8.0, 18.0)
		draw_rect(badge, Color(0.0, 0.005, 0.01, 0.92))
		draw_rect(badge, Color(accent, 0.8), false, 1.0)
		draw_string(font, Vector2(badge.position.x + 4.0, badge.position.y + 14.0), text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 16, HudStyle.TEXT)
