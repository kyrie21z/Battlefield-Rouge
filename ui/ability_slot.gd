class_name AbilitySlot
extends Control
## One square skill slot. G is the shield (locked / ready / active / cooling),
## V is melee: it shows the current blade, flashes its border during the parry
## window and draws the stored-round dots when the parry perk is unlocked.
## The dangerous-magazine perk is a small corner badge, not a sentence.

enum Mode { SHIELD, MELEE }

const KEY_AREA := 28.0
const LOCK_COLOR := Color(0.75, 0.82, 0.85, 0.9)
const DOT_RADIUS := 2.5

@export var mode := Mode.SHIELD
@export var key_text := "G"
## Shield silhouette; the melee slot takes its icon from the selected MeleeData.
@export var icon: Texture2D
## Dangerous-magazine badge drawn in the top-right corner of the shield slot.
@export var corner_icon: Texture2D

var player: Player
var locked := false
var slot_ready := true
var active := false
var cooling := false
var cooldown_fraction := 0.0
var cooldown_seconds := 0.0
var parry_flash := false
var stored_rounds := 0
var stored_capacity := 0
var stored_visible := false
var danger_badge := false
var current_icon: Texture2D

var _pulse := 0.0


func setup(owner: Player) -> void:
	player = owner
	advance(0.0)


func _process(delta: float) -> void:
	advance(delta)


func advance(delta: float) -> void:
	_pulse += delta
	if player == null:
		return
	if mode == Mode.SHIELD:
		_sync_shield()
	else:
		_sync_melee()
	queue_redraw()


func _sync_shield() -> void:
	var shield := player.shield
	locked = not shield.is_unlocked()
	active = not locked and shield.is_active()
	cooling = not locked and not active and shield.cooldown_remaining > 0.0
	slot_ready = not locked and not active and not cooling
	cooldown_seconds = shield.cooldown_remaining
	cooldown_fraction = 0.0
	if cooling:
		cooldown_fraction = clampf(shield.cooldown_remaining / shield.cooldown_duration(), 0.0, 1.0)
	current_icon = icon
	danger_badge = player.stats.get_value(Stats.RELOAD_BLAST_DAMAGE) > 0.0
	parry_flash = false
	stored_visible = false
	stored_capacity = 0
	stored_rounds = 0


func _sync_melee() -> void:
	var melee := player.melee.current()
	current_icon = melee.icon if melee != null else null
	locked = false
	slot_ready = true
	active = false
	cooling = false
	cooldown_fraction = 0.0
	cooldown_seconds = 0.0
	parry_flash = player.combat_traits.parry_remaining > 0.0
	stored_capacity = player.combat_traits.capacity()
	stored_rounds = player.combat_traits.stored_rounds
	stored_visible = stored_capacity > 0
	danger_badge = false


func _draw() -> void:
	var box := Rect2(0.0, 0.0, size.x, size.y - KEY_AREA)
	var cut := 9.0
	var border := Color(HudStyle.MUTED, 0.5)
	var fill := HudStyle.PANEL_FILL
	if locked:
		border = Color(0.38, 0.44, 0.48, 0.55)
		fill = Color(0.01, 0.025, 0.03, 0.78)
	elif active:
		border = Color(HudStyle.ACCENT, 0.95)
		fill = Color(HudStyle.ACCENT, 0.18)
		HudStyle.draw_glow(self, box, HudStyle.ACCENT, cut)
	elif parry_flash:
		var flash := 0.55 + 0.45 * sin(_pulse * 18.0)
		border = Color(0.95, 1.0, 1.0, flash)
		HudStyle.draw_glow(self, box, Color(0.9, 1.0, 1.0, flash), cut)
	elif slot_ready:
		border = Color(HudStyle.ACCENT, 0.75)
	HudStyle.draw_panel(self, box, border, cut, fill)

	var tint := Color(0.9, 1.0, 1.0, 1.0)
	if locked:
		tint = Color(0.5, 0.56, 0.6, 0.55)
	elif not slot_ready and not active:
		tint = Color(0.68, 0.8, 0.85, 0.75)
	HudStyle.draw_icon(self, current_icon, box.grow(-12.0), tint)

	if cooling:
		_draw_cooldown(box.get_center(), minf(box.size.x, box.size.y) * 0.36)
	if locked:
		_draw_lock(box.get_center())
	if stored_visible:
		_draw_rounds(box)
	if danger_badge and corner_icon != null:
		_draw_corner_badge(box)

	var key_rect := Rect2(size.x * 0.5 - 15.0, size.y - 26.0, 30.0, 26.0)
	draw_rect(key_rect, Color(0.0, 0.005, 0.01, 0.96))
	draw_rect(key_rect, Color(border, 0.85), false, 1.0)
	var key_color := HudStyle.TEXT if slot_ready or active else Color(0.75, 0.82, 0.86)
	HudStyle.draw_text_centered(self, ThemeDB.fallback_font, size.x * 0.5, size.y - 5.0,
		key_text, 22, key_color)


func _draw_cooldown(center: Vector2, radius: float) -> void:
	var points := PackedVector2Array([center])
	var steps := 40
	for i in steps + 1:
		var angle := -PI * 0.5 + TAU * cooldown_fraction * float(i) / float(steps)
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	draw_colored_polygon(points, Color(0.0, 0.0, 0.0, 0.62))
	HudStyle.draw_text_centered(self, ThemeDB.fallback_font, center.x, center.y + 7.0,
		"%d" % ceili(cooldown_seconds), 18, HudStyle.TEXT)


func _draw_lock(center: Vector2) -> void:
	draw_rect(Rect2(center.x - 7.0, center.y - 1.0, 14.0, 11.0), LOCK_COLOR)
	draw_arc(Vector2(center.x, center.y - 1.0), 5.0, PI, TAU, 12, LOCK_COLOR, 2.0, true)


func _draw_rounds(box: Rect2) -> void:
	var spacing := 7.0
	var total := float(stored_capacity) * spacing
	var start := box.get_center().x - total * 0.5 + spacing * 0.5
	var y := box.end.y - 7.0
	for i in stored_capacity:
		var point := Vector2(start + float(i) * spacing, y)
		if i < stored_rounds:
			draw_circle(point, DOT_RADIUS, HudStyle.ACCENT)
		else:
			draw_arc(point, DOT_RADIUS, 0.0, TAU, 10, Color(HudStyle.ACCENT, 0.5), 1.2, true)


func _draw_corner_badge(box: Rect2) -> void:
	var center := Vector2(box.end.x - 10.0, box.position.y + 10.0)
	draw_circle(center, 11.0, Color(0.16, 0.02, 0.02, 0.92))
	draw_arc(center, 11.0, 0.0, TAU, 20, Color(HudStyle.WARNING, 0.85), 1.5, true)
	HudStyle.draw_icon(self, corner_icon, Rect2(center - Vector2(7.0, 7.0), Vector2(14.0, 14.0)),
		Color(1.0, 0.72, 0.52, 1.0))
