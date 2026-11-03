class_name GameSettings
extends RefCounted
## Player-facing options: mouse look sensitivity, crosshair look, music
## volume and key bindings. Pure data; the HUD applies it and the pause menu
## edits and saves it. Every default reproduces the game before this menu
## existed (music at 70%), so a missing or untrusted file never changes the feel.

signal changed

const DEFAULT_PATH := "user://settings.cfg"
## Tests and the proof point this at a temp file, so a real user config on this
## machine is never read or written behind their back.
static var settings_path := DEFAULT_PATH

const SENS_MIN := 0.1
const SENS_MAX := 5.0
const ADS_MIN := 0.2
const ADS_MAX := 2.0
const SIZE_MIN := 0.5
const SIZE_MAX := 2.0
const THICKNESS_MIN := 1.0
const THICKNESS_MAX := 4.0
const ALPHA_MIN := 0.2
const ALPHA_MAX := 1.0
const MUSIC_DEFAULT := 0.7
## RGB only; the alpha slider is separate.
const COLOR_PRESETS: Array[Color] = [
	Color(1.0, 1.0, 1.0), Color(0.35, 0.95, 0.45), Color(0.3, 0.9, 0.95),
	Color(1.0, 0.85, 0.25), Color(0.95, 0.35, 0.95), Color(0.95, 0.25, 0.2)]
const COLOR_NAMES: Array[String] = ["白", "绿", "青", "黄", "品红", "红"]
const STYLE_NAMES: Array[String] = ["十字", "十字+点", "仅点", "圆环"]

var mouse_sensitivity := 1.0
var ads_sensitivity := 1.0
var crosshair_style := Crosshair.Style.CROSS_DOT
var crosshair_color := Color(1.0, 1.0, 1.0)
var crosshair_size := 1.0
## Today's crosshair line thickness.
var crosshair_thickness := 1.5
## Today's crosshair colour alpha.
var crosshair_alpha := 0.9
var dynamic_gap := true
## Linear 0..1 level of the Music bus; 0 mutes it.
var music_volume := MUSIC_DEFAULT
## action → KeyBindings code, only for actions moved off their default.
var bindings := {}


func clamp_values() -> void:
	mouse_sensitivity = clampf(mouse_sensitivity, SENS_MIN, SENS_MAX)
	ads_sensitivity = clampf(ads_sensitivity, ADS_MIN, ADS_MAX)
	crosshair_style = clampi(crosshair_style, 0, Crosshair.Style.RING)
	crosshair_color = Color(crosshair_color.r, crosshair_color.g, crosshair_color.b)
	crosshair_size = clampf(crosshair_size, SIZE_MIN, SIZE_MAX)
	crosshair_thickness = clampf(crosshair_thickness, THICKNESS_MIN, THICKNESS_MAX)
	crosshair_alpha = clampf(crosshair_alpha, ALPHA_MIN, ALPHA_MAX)
	music_volume = clampf(music_volume, 0.0, 1.0)
	bindings = KeyBindings.sanitize(bindings)


func reset_defaults() -> void:
	mouse_sensitivity = 1.0
	ads_sensitivity = 1.0
	crosshair_style = Crosshair.Style.CROSS_DOT
	crosshair_color = Color(1.0, 1.0, 1.0)
	crosshair_size = 1.0
	crosshair_thickness = 1.5
	crosshair_alpha = 0.9
	dynamic_gap = true
	music_volume = MUSIC_DEFAULT
	bindings = {}
	changed.emit()


## Reads `path`. A missing or broken file leaves the current values alone.
func load_from(path: String) -> bool:
	var config := ConfigFile.new()
	if config.load(path) != OK:
		return false
	mouse_sensitivity = float(config.get_value("input", "mouse_sensitivity", mouse_sensitivity))
	ads_sensitivity = float(config.get_value("input", "ads_sensitivity", ads_sensitivity))
	crosshair_style = int(config.get_value("crosshair", "style", crosshair_style))
	var stored_color: Variant = config.get_value("crosshair", "color", crosshair_color)
	if stored_color is Color:
		crosshair_color = stored_color
	crosshair_size = float(config.get_value("crosshair", "size", crosshair_size))
	crosshair_thickness = float(config.get_value("crosshair", "thickness", crosshair_thickness))
	crosshair_alpha = float(config.get_value("crosshair", "alpha", crosshair_alpha))
	dynamic_gap = bool(config.get_value("crosshair", "dynamic_gap", dynamic_gap))
	music_volume = float(config.get_value("audio", "music_volume", music_volume))
	bindings = {}
	if config.has_section("bindings"):
		for action in config.get_section_keys("bindings"):
			bindings[action] = str(config.get_value("bindings", action, ""))
	clamp_values()
	changed.emit()
	return true


func save_to(path: String) -> Error:
	clamp_values()
	var config := ConfigFile.new()
	config.set_value("input", "mouse_sensitivity", mouse_sensitivity)
	config.set_value("input", "ads_sensitivity", ads_sensitivity)
	config.set_value("crosshair", "style", crosshair_style)
	config.set_value("crosshair", "color", crosshair_color)
	config.set_value("crosshair", "size", crosshair_size)
	config.set_value("crosshair", "thickness", crosshair_thickness)
	config.set_value("crosshair", "alpha", crosshair_alpha)
	config.set_value("crosshair", "dynamic_gap", dynamic_gap)
	config.set_value("audio", "music_volume", music_volume)
	for action in bindings:
		config.set_value("bindings", action, bindings[action])
	return config.save(path)
