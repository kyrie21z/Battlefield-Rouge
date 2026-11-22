class_name WeaponPanel
extends Control
## One pistol: current/capacity, name and crystal reassembly progress (Scheme B).

const AMMO_POS := Vector2(18.0, 44.0)
const AMMO_FONT := 36
const AMMO_WIDTH := 178.0
const RELOAD_BAR := Rect2(18.0, 80.0, 178.0, 6.0)
const LOW_AMMO_SHARE := 0.25

var weapon: Weapon
var ammo_text := ""
var ammo_low := false
var ammo_color := HudStyle.TEXT
var gun_name := ""
var reload_visible := false
var reload_fraction := 0.0

var _name_label: Label


func _ready() -> void:
	_name_label = Label.new()
	_name_label.position = Vector2(18.0, 52.0)
	_name_label.size = Vector2(AMMO_WIDTH, 24.0)
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_name_label.clip_text = true
	EditorialStyle.style_label(_name_label, 14, EditorialStyle.ASH, 600)
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


func _sync() -> void:
	if weapon == null or weapon.data == null:
		return
	ammo_text = "%d / %d" % [weapon.ammo, weapon.magazine_capacity()]
	ammo_low = weapon.ammo <= int(weapon.magazine_capacity() * LOW_AMMO_SHARE)
	ammo_color = HudStyle.WARNING if ammo_low else HudStyle.TEXT
	gun_name = weapon.data.display_name
	reload_visible = weapon.is_reloading()
	reload_fraction = weapon.reload_progress()
	_name_label.text = gun_name


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(Rect2(Vector2(-4.0, 4.0), size), Color(EditorialStyle.PAPER, 0.85))
	draw_rect(rect, EditorialStyle.INK)
	draw_rect(rect, EditorialStyle.INK, false, 2.0)
	var font := EditorialStyle.font_mono(800)
	draw_string(font, AMMO_POS, ammo_text, HORIZONTAL_ALIGNMENT_LEFT, -1, AMMO_FONT, ammo_color)

	if reload_visible:
		draw_rect(RELOAD_BAR, EditorialStyle.INK_TRACK)
		draw_rect(Rect2(RELOAD_BAR.position,
			Vector2(RELOAD_BAR.size.x * clampf(reload_fraction, 0.0, 1.0), RELOAD_BAR.size.y)),
			EditorialStyle.GOLD_BRIGHT)
