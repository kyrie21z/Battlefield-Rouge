class_name SchoolBadge
extends PanelContainer
## Silhouette plus the direction words for one school.
## Vertical slices call setup(). This does not offer a buff and shows no numbers.

const PLATE := Color("1e2430")
const TEXT := Color("e7eaef")

var school: School


func setup(shown: School, icon_size: int = 48) -> void:
	school = shown
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = PLATE
	style.border_color = school.accent
	style.set_border_width_all(3)
	style.set_corner_radius_all(8)
	style.content_margin_left = 10
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	add_theme_stylebox_override("panel", style)

	var row := HBoxContainer.new()
	row.name = "Row"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	add_child(row)

	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.texture = school.icon
	icon.custom_minimum_size = Vector2(icon_size, icon_size)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(icon)

	var text := VBoxContainer.new()
	text.name = "Text"
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_theme_constant_override("separation", 0)
	row.add_child(text)

	var title := Label.new()
	title.name = "Title"
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.text = school.title
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", school.accent)
	text.add_child(title)

	var direction := Label.new()
	direction.name = "Direction"
	direction.mouse_filter = Control.MOUSE_FILTER_IGNORE
	direction.text = school.direction
	direction.add_theme_font_size_override("font_size", 16)
	direction.add_theme_color_override("font_color", TEXT)
	text.add_child(direction)
