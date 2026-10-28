class_name WorldMarker
extends Control

enum Kind { CAPTURE, PEDESTAL, BOSS }

const SAFE_INSET := Vector2(88.0, 100.0)
const EXTENTS := Vector2(62.0, 78.0)

var kind := Kind.CAPTURE
var director: ZoneDirector
var player: Player
var target: Node3D
var marker_color := CapturePoint.COLOR_LOCKED
var screen_position := Vector2.ZERO
var direction := Vector2.DOWN
var distance_meters := 0
var distance_text := ""
var offscreen := false
var behind := false
var highlighted := false
var progress_visible := false
var progress_fraction := 0.0
var opacity := 1.0
var _projected_position := Vector2.ZERO


func setup(marker_kind: Kind, zone: ZoneDirector, owner: Player) -> void:
	kind = marker_kind
	director = zone
	player = owner
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	refresh()


func refresh() -> void:
	visible = false
	highlighted = false
	progress_visible = false
	opacity = 1.0
	var height := 3.5
	match kind:
		Kind.CAPTURE:
			target = director.capture_point
			var point := director.capture_point
			marker_color = CapturePoint.COLOR_CAPTURED if point.is_captured() else (
				CapturePoint.COLOR_LOCKED if point.locked else CapturePoint.COLOR_OPEN)
			if point.is_captured():
				return
			opacity = 0.5 if director.phase == ZoneDirector.Phase.CLEAR_GUARDS else 1.0
			progress_visible = director.phase == ZoneDirector.Phase.HAMMER_POINT
			progress_fraction = point.progress
		Kind.PEDESTAL:
			target = director.buff_pedestal
			if not is_instance_valid(target):
				return
			height = 1.6
			highlighted = director.buff_pedestal.in_range(player)
			marker_color = CapturePoint.COLOR_CAPTURED
		Kind.BOSS:
			target = director.boss
			if not is_instance_valid(target) or director.boss.health.is_dead():
				return
			height = director.boss.eye_height + 0.8
			marker_color = HudStyle.WARNING
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var world_position := target.global_position + Vector3.UP * height
	distance_meters = roundi(camera.global_position.distance_to(target.global_position))
	distance_text = "%d米" % distance_meters
	var view := get_viewport_rect()
	var center := view.get_center()
	var safe := view.grow_individual(-SAFE_INSET.x, -SAFE_INSET.y, -SAFE_INSET.x, -SAFE_INSET.y)
	behind = camera.is_position_behind(world_position)
	var local := camera.to_local(world_position)
	var projected := center
	if absf(local.z) > 0.001:
		projected = camera.unproject_position(world_position)
	var offset := projected - center
	if behind or absf(local.z) <= 0.001:
		offset = Vector2(local.x, -local.y)
	if offset.is_zero_approx():
		offset = Vector2.DOWN
	direction = offset.normalized()
	offscreen = behind or absf(local.z) <= 0.001 or not safe.has_point(projected)
	screen_position = projected
	if offscreen:
		var half_size := safe.size * 0.5
		var factor := maxf(absf(direction.x) / half_size.x, absf(direction.y) / half_size.y)
		screen_position = center + direction / factor
	_projected_position = screen_position
	visible = true
	queue_redraw()


func avoid(other: WorldMarker) -> void:
	if not visible or not other.visible or not marker_rect().intersects(other.marker_rect()):
		return
	var safe := get_viewport_rect().grow_individual(-SAFE_INSET.x, -SAFE_INSET.y,
		-SAFE_INSET.x, -SAFE_INSET.y)
	for offset in [Vector2(EXTENTS.x * 2.0 + 16.0, 0.0), Vector2(-EXTENTS.x * 2.0 - 16.0, 0.0),
			Vector2(0.0, EXTENTS.y * 2.0 + 16.0), Vector2(0.0, -EXTENTS.y * 2.0 - 16.0)]:
		var candidate: Vector2 = other.screen_position + offset
		if safe.has_point(candidate):
			screen_position = candidate
			queue_redraw()
			return


func marker_rect() -> Rect2:
	return Rect2(screen_position - EXTENTS, EXTENTS * 2.0)


func _draw() -> void:
	var color := Color(marker_color, opacity)
	var center := screen_position
	if not offscreen and not center.is_equal_approx(_projected_position):
		draw_line(_projected_position, center, Color(marker_color, 0.35), 1.0, true)
	if highlighted:
		draw_circle(center, 35.0, Color(marker_color, 0.24))
	var diamond := PackedVector2Array([center + Vector2(0.0, -22.0),
		center + Vector2(22.0, 0.0), center + Vector2(0.0, 22.0), center + Vector2(-22.0, 0.0)])
	draw_colored_polygon(diamond, Color(0.015, 0.025, 0.04, 0.85 * opacity))
	diamond.append(diamond[0])
	draw_polyline(diamond, color, 3.0 if highlighted else 2.0, true)
	if progress_visible:
		draw_arc(center, 30.0, 0.0, TAU, 64, Color(0.0, 0.0, 0.0, 0.75), 5.0, true)
		if progress_fraction > 0.0:
			draw_arc(center, 30.0, -PI * 0.5, -PI * 0.5 + TAU * progress_fraction,
				64, color, 5.0, true)
	if offscreen:
		var tip := center + direction * 45.0
		var base := center + direction * 34.0
		var side := direction.orthogonal() * 7.0
		draw_colored_polygon(PackedVector2Array([tip, base + side, base - side]), color)
	var font := ThemeDB.fallback_font
	if kind == Kind.PEDESTAL:
		HudStyle.draw_text_centered(self, font, center.x, center.y + 8.0, "F", 24, color)
	var text_size := font.get_string_size(distance_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22)
	var text_y := 47.0 if offscreen or kind == Kind.PEDESTAL else -70.0
	draw_rect(Rect2(center + Vector2(-text_size.x * 0.5 - 6.0, text_y),
		Vector2(text_size.x + 12.0, 28.0)), Color(0.0, 0.0, 0.0, 0.85))
	HudStyle.draw_text_centered(self, font, center.x, center.y + text_y + 22.0, distance_text, 22,
		Color(HudStyle.TEXT, maxf(opacity, 0.75)))
