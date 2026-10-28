class_name WeaponPanel
extends Control
## Bottom-right gun block: big current / reserve numbers, the gun name and one
## slot per gun in `data_set`, all in one row. Reloading swaps a progress bar in.
## Reads the weapon only.

const AMMO_POS := Vector2(18.0, 44.0)
const AMMO_FONT := 36
const AMMO_WIDTH := 178.0
const RELOAD_BAR := Rect2(18.0, 80.0, 178.0, 8.0)
const SLOT_SIZE := Vector2(84.0, 80.0)
const SLOT_START := 212.0
const SLOT_STEP := 94.0
const SLOT_TOP := 10.0
const LOW_AMMO_SHARE := 0.25

var weapon: Weapon
var ammo_text := ""
var ammo_low := false
var ammo_color := HudStyle.TEXT
var gun_name := ""
var selected_index := 0
var reload_visible := false
var reload_fraction := 0.0

var _name_label: Label


func _ready() -> void:
	_name_label = Label.new()
	_name_label.position = Vector2(18.0, 50.0)
	_name_label.size = Vector2(AMMO_WIDTH, 24.0)
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_name_label.clip_text = true
	_name_label.add_theme_font_size_override("font_size", 16)
	_name_label.add_theme_color_override("font_color", HudStyle.MUTED)
	_name_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_name_label.add_theme_constant_override("outline_size", 4)
	add_child(_name_label)


func setup(gun: Weapon) -> void:
	weapon = gun
	advance(0.0)


func _process(_delta: float) -> void:
	_sync()
	queue_redraw()


func advance(_delta: float) -> void:
	_sync()
	queue_redraw()


func slot_rect(index: int) -> Rect2:
	return Rect2(Vector2(SLOT_START + float(index) * SLOT_STEP, SLOT_TOP), SLOT_SIZE)


func _sync() -> void:
	if weapon == null or weapon.data == null:
		return
	ammo_text = "%d / %d" % [weapon.ammo, weapon.reserve]
	ammo_low = weapon.ammo <= int(weapon.magazine_capacity() * LOW_AMMO_SHARE)
	ammo_color = HudStyle.WARNING if ammo_low else HudStyle.TEXT
	gun_name = weapon.data.display_name
	selected_index = weapon.index
	reload_visible = weapon.is_reloading()
	reload_fraction = weapon.reload_progress()
	_name_label.text = gun_name


func _draw() -> void:
	HudStyle.draw_panel(self, Rect2(Vector2.ZERO, size), HudStyle.PANEL_LINE)
	var font := ThemeDB.fallback_font
	draw_string(font, AMMO_POS, ammo_text, HORIZONTAL_ALIGNMENT_LEFT, -1, AMMO_FONT, ammo_color)

	if reload_visible:
		draw_rect(RELOAD_BAR, Color(0.0, 0.0, 0.0, 0.6))
		draw_rect(Rect2(RELOAD_BAR.position,
			Vector2(RELOAD_BAR.size.x * clampf(reload_fraction, 0.0, 1.0), RELOAD_BAR.size.y)),
			HudStyle.ACCENT)
		draw_rect(RELOAD_BAR, Color(HudStyle.ACCENT, 0.45), false, 1.0)

	if weapon == null or weapon.data_set.is_empty():
		return
	for i in weapon.data_set.size():
		var slot := slot_rect(i)
		var current := i == selected_index
		draw_rect(slot, Color(0.0, 0.0, 0.0, 0.45))
		if current:
			draw_rect(slot, Color(HudStyle.ACCENT, 0.16))
			draw_rect(slot, HudStyle.ACCENT, false, 2.0)
		else:
			draw_rect(slot, Color(HudStyle.MUTED, 0.35), false, 1.0)
		var tint := HudStyle.TEXT if current else Color(0.68, 0.78, 0.82, 0.55)
		HudStyle.draw_icon(self, weapon.data_set[i].icon, slot.grow(-8.0), tint)
