class_name EditorialWeaponPanel
extends Control
## Bottom-right architectural ammo & weapon plaque (Scheme B):
## Carbon-ink card with ivory offset shadow, vertical round ticks, bold monospace
## counter, crystal reassembly bar and OBSIDIAN / BLADE [V] footer.

const LOW_AMMO_SHARE := 0.25

var weapon: Weapon
var ammo := 0
var capacity := 8
var ammo_low := false
var reloading := false
var reload_fraction := 0.0
var gun_name := "黑晶手枪"


func setup(gun: Weapon) -> void:
	weapon = gun
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sync()
	queue_redraw()


func _process(_delta: float) -> void:
	_sync()
	queue_redraw()


func _sync() -> void:
	if not is_instance_valid(weapon):
		return
	ammo = weapon.ammo
	capacity = maxi(weapon.magazine_capacity(), 1)
	ammo_low = ammo <= int(capacity * LOW_AMMO_SHARE)
	reloading = weapon.is_reloading()
	reload_fraction = clampf(weapon.reload_progress(), 0.0, 1.0)
	if weapon.data != null and not weapon.data.display_name.is_empty():
		gun_name = weapon.data.display_name


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)

	# Hard ivory offset shadow (mirroring bottom-left plaque) + carbon ink card
	draw_rect(Rect2(Vector2(-5.0, 5.0), size), Color(EditorialStyle.PAPER, 0.88))
	draw_rect(rect, EditorialStyle.INK)
	draw_rect(rect, EditorialStyle.INK, false, 2.0)

	# Right-aligned monospace ammo readout: "06" + "/08"
	var mono_heavy := EditorialStyle.font_mono(800)
	var mono_sub := EditorialStyle.font_mono(600, 1)
	var num_str := "%02d" % ammo
	var cap_str := "/%02d" % capacity
	var num_col := EditorialStyle.GOLD_BRIGHT if reloading else (EditorialStyle.WARNING if ammo_low else EditorialStyle.PAPER)
	var cap_w := mono_sub.get_string_size(cap_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
	var num_w := mono_heavy.get_string_size(num_str, HORIZONTAL_ALIGNMENT_LEFT, -1, 34).x
	var right_pad := 16.0
	var baseline := 42.0
	draw_string(mono_sub, Vector2(size.x - right_pad - cap_w, baseline), cap_str,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 15, EditorialStyle.ASH)
	draw_string(mono_heavy, Vector2(size.x - right_pad - cap_w - num_w - 3.0, baseline), num_str,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 34, num_col)

	# Left vertical round ticks (adaptive count so high magazine buffs stay crisp)
	var ticks_left := 16.0
	var ticks_max_w := maxf(size.x - right_pad - cap_w - num_w - 32.0, 48.0)
	var display_count := clampi(capacity, 1, 16)
	var gap := 4.0 if display_count <= 10 else 2.5
	var tick_w := clampf((ticks_max_w - gap * float(display_count - 1)) / float(display_count), 3.0, 7.0)
	var full_h := 24.0
	var spent_h := 10.0
	var ticks_bottom := 42.0
	var filled_ratio := float(ammo) / float(capacity)
	for i in display_count:
		var threshold := float(i + 1) / float(display_count)
		var lit := filled_ratio >= threshold - 0.0001
		var is_reassembling := reloading and reload_fraction >= threshold - 0.0001
		var h := full_h if (lit or is_reassembling) else spent_h
		var col := EditorialStyle.GOLD_BRIGHT if is_reassembling else (
			(EditorialStyle.WARNING if ammo_low else EditorialStyle.PAPER) if lit else EditorialStyle.INK_MUTED)
		var x := ticks_left + float(i) * (tick_w + gap)
		draw_rect(Rect2(x, ticks_bottom - h, tick_w, h), col)

	# Structural divider line (turns into gold progress bar while reassembling)
	var sep_y := size.y - 30.0
	draw_rect(Rect2(14.0, sep_y, size.x - 28.0, 2.0), EditorialStyle.INK_TRACK)
	if reloading:
		draw_rect(Rect2(14.0, sep_y, (size.x - 28.0) * reload_fraction, 2.0), EditorialStyle.GOLD_BRIGHT)

	# Footer metadata: weapon identity + melee key hint
	var foot_font := EditorialStyle.font_mono(700, 1)
	var cn_font := EditorialStyle.font_sans(600)
	var foot_y := size.y - 11.0
	var left_text := "晶体重组中…" if reloading else gun_name
	var left_col := EditorialStyle.GOLD_BRIGHT if reloading else EditorialStyle.ASH
	draw_string(cn_font, Vector2(16.0, foot_y), left_text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 12, left_col)

	var blade_key := KeyHint.of("melee") if InputMap.has_action("melee") else "V"
	var right_text := "BLADE [%s]" % blade_key
	var right_font := EditorialStyle.font_sans(700)
	var right_w := right_font.get_string_size(right_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	draw_string(right_font, Vector2(size.x - 16.0 - right_w, foot_y), right_text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 13, EditorialStyle.GOLD_BRIGHT)
