class_name Vitals
extends Control
## Bottom-left architectural vitals plaque (Scheme B):
## Carbon-ink numeric block + ivory-paper ruler card with crisp black health bar,
## crimson chip-damage trail, shield hairline and dual horizontal SHIFT dash bars.

const SEGMENTS := 12
const LOW_FRACTION := 0.3
const INK_BLOCK_WIDTH := 96.0
## Health bar rect on the ivory paper half. Shield sits at y - 16 above it.
const BAR_RECT := Rect2(114.0, 26.0, 214.0, 18.0)
## Horizontal dash bars below the health bar; completely clear of the shield strip.
const DASH_CELL := Vector2(68.0, 6.0)
const DASH_GAP := 8.0
const DASH_ORIGIN := Vector2(114.0, 60.0)

var player: Player
var displayed_health := 0.0
var delayed_health := 0.0
var max_health := 100.0
var health_number := 0
var warning := false
var shield_visible := false
var shield_fraction := 0.0
var shield_counter_mode := false
var dash_charges := 0
var dash_max_charges := 0
var dash_recharge_fraction := 0.0

var _trail := HealthTrail.new()
var _pulse := 0.0


func setup(owner: Player) -> void:
	player = owner
	_trail.reset(player.health.health)
	advance(0.0)


func _process(delta: float) -> void:
	advance(delta)


func advance(delta: float) -> void:
	_pulse += delta
	if player == null:
		return
	var health := player.health
	var current := health.health
	max_health = maxf(health.max_health, 1.0)
	_trail.advance(current, delta)
	if health.unbuffered:
		_trail.reset(current)
	displayed_health = _trail.current
	delayed_health = _trail.delayed
	health_number = ceili(current)
	warning = current > 0.0 and current / max_health < LOW_FRACTION

	var shield := player.shield
	shield_visible = shield != null and shield.is_active()
	shield_counter_mode = shield != null and shield.is_counter_mode()
	shield_fraction = 0.0
	if shield_visible:
		if shield_counter_mode:
			shield_fraction = 1.0 - shield.charge_fraction()
		else:
			var duration := maxf(player.stats.get_value(Stats.SHIELD_DURATION), 0.01)
			shield_fraction = clampf(shield.active_remaining / duration, 0.0, 1.0)
	if not shield_visible and player.fragments != null and player.fragments.has_shard(PsycheFragments.SORROW):
		shield_visible = player.fragments.barrier > 0.0
		shield_counter_mode = false
		shield_fraction = player.fragments.barrier / PsycheFragments.TENDERNESS_CAPACITY

	dash_charges = player.dash_charges()
	dash_max_charges = player.dash_max_charges()
	dash_recharge_fraction = player.dash_recharge_fraction()
	queue_redraw()


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	var ink_w := minf(INK_BLOCK_WIDTH, size.x * 0.30)
	var shadow_col := Color(EditorialStyle.WARNING, 0.85) if warning else Color(EditorialStyle.INK, 0.82)

	# Hard architectural offset shadow
	draw_rect(Rect2(Vector2(5.0, 5.0), size), shadow_col)
	# Ivory paper card body
	draw_rect(rect, EditorialStyle.PAPER)
	# Left carbon-ink numeric block (pulses crimson on low health)
	var left_bg := EditorialStyle.INK
	if warning:
		var blink := 0.5 + 0.5 * sin(_pulse * 10.0)
		left_bg = EditorialStyle.INK.lerp(EditorialStyle.WARNING, 0.32 + 0.38 * blink)
	draw_rect(Rect2(Vector2.ZERO, Vector2(ink_w, size.y)), left_bg)

	# Crisp numeric readout inside carbon block
	var mono_heavy := EditorialStyle.font_mono(800)
	var mono_sub := EditorialStyle.font_mono(600, 1)
	var num_str := str(health_number)
	var num_col := EditorialStyle.PAPER
	draw_string(mono_heavy, Vector2(14.0, size.y * 0.56), num_str,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 34, num_col)
	draw_string(mono_sub, Vector2(15.0, size.y - 14.0),
		"HP / %d" % int(roundf(max_health)),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 11, EditorialStyle.ASH)

	# Dynamic bar layout scaled cleanly to control width
	var right_x := ink_w + 18.0
	var right_w := maxf(size.x - right_x - 16.0, 40.0)
	var bar := Rect2(right_x, 26.0, right_w, 16.0)

	# Shield strip above health bar
	if shield_visible:
		var strip := Rect2(bar.position.x, bar.position.y - 11.0, bar.size.x, 5.0)
		var shield_color := PlayerShield.ACCENT if shield_counter_mode else EditorialStyle.SHIELD
		draw_rect(strip, EditorialStyle.PAPER_TRACK)
		draw_rect(Rect2(strip.position, Vector2(strip.size.x * clampf(shield_fraction, 0.0, 1.0), strip.size.y)),
			shield_color)

	# Main health ruler: light stone track + sharp ink fill + crisp crimson damage cut
	draw_rect(bar, EditorialStyle.PAPER_TRACK)
	var health_w := bar.size.x * clampf(displayed_health / max_health, 0.0, 1.0)
	var delayed_w := bar.size.x * clampf(delayed_health / max_health, 0.0, 1.0)
	var fill_color := EditorialStyle.WARNING if warning else EditorialStyle.INK
	if health_w > 0.0:
		draw_rect(Rect2(bar.position, Vector2(health_w, bar.size.y)), fill_color)
	if delayed_w > health_w:
		draw_rect(Rect2(Vector2(bar.position.x + health_w, bar.position.y),
			Vector2(delayed_w - health_w, bar.size.y)), EditorialStyle.WARNING)

	# Subtle quarter ticks on the ruler for precision editorial feel
	for q in range(1, 4):
		var tx := bar.position.x + bar.size.x * (float(q) * 0.25)
		draw_line(Vector2(tx, bar.position.y), Vector2(tx, bar.position.y + 4.0),
			Color(EditorialStyle.PAPER, 0.45), 1.0)

	# Horizontal dash charge bars + SHIFT tag
	_draw_dash_pips(right_x, right_w)

	# Outer sharp architectural ink border (turns crimson on warning)
	var border_col := EditorialStyle.WARNING if warning else EditorialStyle.INK
	draw_rect(rect, border_col, false, 2.0)


func _draw_dash_pips(right_x: float, right_w: float) -> void:
	var count := maxi(dash_max_charges, 0)
	if count <= 0:
		return
	var shift_label_w := 56.0
	var avail_w := maxf(right_w - shift_label_w, 40.0)
	var gap := 7.0
	var cell_w := (avail_w - gap * float(count - 1)) / float(count)
	var y := size.y - 24.0
	var h := 6.0
	for i in count:
		var cell := Rect2(right_x + float(i) * (cell_w + gap), y, cell_w, h)
		draw_rect(cell, EditorialStyle.PAPER_TRACK)
		var fill := 0.0
		if i < dash_charges:
			fill = 1.0
		elif i == dash_charges:
			fill = clampf(dash_recharge_fraction, 0.0, 1.0)
		if fill > 0.0:
			var col := EditorialStyle.INK if fill >= 1.0 else EditorialStyle.GOLD
			draw_rect(Rect2(cell.position, Vector2(cell.size.x * fill, cell.size.y)), col)
	var tag_font := EditorialStyle.font_mono(700, 1)
	var tag := (KeyHint.of("dash") if InputMap.has_action("dash") else "SHIFT").to_upper()
	var tag_w := tag_font.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
	draw_string(tag_font, Vector2(right_x + right_w - tag_w, y + h + 1.0),
		tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, EditorialStyle.SLATE)
