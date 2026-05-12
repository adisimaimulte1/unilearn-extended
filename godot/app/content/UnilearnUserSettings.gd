extends Node

signal settings_changed

const SAVE_PATH := "user://unilearn_settings.cfg"
const SECTION := "settings"

const ACCENT_PURPLE := Color("#B56CFF")
const ACCENT_ORANGE := Color("#c89f39ff")

var sfx_enabled: bool = true
var apollo_enabled: bool = true
var reduce_motion_enabled: bool = false

var theme_dark_mode: bool = true
var theme_accent_name: String = "purple"


func _ready() -> void:
	load_settings()


func load_settings() -> void:
	var config := ConfigFile.new()
	var err := config.load(SAVE_PATH)

	if err != OK:
		save_settings()
		return

	sfx_enabled = bool(config.get_value(SECTION, "sfx_enabled", true))
	apollo_enabled = bool(config.get_value(SECTION, "apollo_enabled", true))
	reduce_motion_enabled = bool(config.get_value(SECTION, "reduce_motion_enabled", false))

	theme_dark_mode = bool(config.get_value(SECTION, "theme_dark_mode", true))
	theme_accent_name = str(config.get_value(SECTION, "theme_accent_name", "purple")).strip_edges().to_lower()

	if theme_accent_name != "purple" and theme_accent_name != "orange":
		theme_accent_name = "purple"


func save_settings() -> void:
	var config := ConfigFile.new()

	config.set_value(SECTION, "sfx_enabled", sfx_enabled)
	config.set_value(SECTION, "apollo_enabled", apollo_enabled)
	config.set_value(SECTION, "reduce_motion_enabled", reduce_motion_enabled)

	config.set_value(SECTION, "theme_dark_mode", theme_dark_mode)
	config.set_value(SECTION, "theme_accent_name", theme_accent_name)

	config.save(SAVE_PATH)


func set_sfx_enabled(enabled: bool) -> void:
	if sfx_enabled == enabled:
		return

	sfx_enabled = enabled
	save_settings()
	settings_changed.emit()


func set_apollo_enabled(enabled: bool) -> void:
	if apollo_enabled == enabled:
		return

	apollo_enabled = enabled
	save_settings()
	settings_changed.emit()


func set_reduce_motion_enabled(enabled: bool) -> void:
	if reduce_motion_enabled == enabled:
		return

	reduce_motion_enabled = enabled
	save_settings()
	settings_changed.emit()


func set_theme_dark_mode(enabled: bool) -> void:
	if theme_dark_mode == enabled:
		return

	theme_dark_mode = enabled
	save_settings()
	settings_changed.emit()


func set_theme_accent_name(value: String) -> void:
	var clean_value := value.strip_edges().to_lower()

	if clean_value != "purple" and clean_value != "orange":
		clean_value = "purple"

	if theme_accent_name == clean_value:
		return

	theme_accent_name = clean_value
	save_settings()
	settings_changed.emit()


func toggle_theme_accent() -> void:
	if theme_accent_name == "purple":
		set_theme_accent_name("orange")
	else:
		set_theme_accent_name("purple")


func get_accent_color() -> Color:
	match theme_accent_name:
		"orange":
			return ACCENT_ORANGE
		_:
			return ACCENT_PURPLE


func get_panel_color() -> Color:
	return Color(0.0, 0.0, 0.0, 0.70) if theme_dark_mode else Color(1.0, 1.0, 1.0, 0.92)


func get_text_color() -> Color:
	return Color.WHITE if theme_dark_mode else Color.BLACK


func get_muted_text_color() -> Color:
	return Color(0.72, 0.76, 0.84, 1.0) if theme_dark_mode else Color(0.08, 0.08, 0.10, 0.70)


func get_line_color() -> Color:
	return Color(1.0, 1.0, 1.0, 0.86) if theme_dark_mode else Color(0.0, 0.0, 0.0, 0.28)
