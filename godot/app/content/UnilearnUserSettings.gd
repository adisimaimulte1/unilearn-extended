extends Node

signal settings_changed

const SAVE_PATH := "user://unilearn_settings.cfg"
const SECTION := "settings"

var sfx_enabled: bool = true
var apollo_enabled: bool = true
var reduce_motion_enabled: bool = false


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


func save_settings() -> void:
	var config := ConfigFile.new()

	config.set_value(SECTION, "sfx_enabled", sfx_enabled)
	config.set_value(SECTION, "apollo_enabled", apollo_enabled)
	config.set_value(SECTION, "reduce_motion_enabled", reduce_motion_enabled)

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
