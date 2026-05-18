extends Node

signal galaxy_config_loaded(config: SimulationPhysicsConfig)
signal galaxy_config_changed(property_name: String, value: Variant, config: SimulationPhysicsConfig)
signal galaxy_config_saved(config: SimulationPhysicsConfig)

const SAVE_PATH := "user://unilearn_galaxy_settings.cfg"
const SECTION := "galaxy_physics"

var config: SimulationPhysicsConfig = SimulationPhysicsConfig.new()
var _loaded := false


func _ready() -> void:
	load_settings()


func get_config() -> SimulationPhysicsConfig:
	if not _loaded:
		load_settings()
	return config


func load_settings() -> SimulationPhysicsConfig:
	if config == null:
		config = SimulationPhysicsConfig.new()

	var file := ConfigFile.new()
	var err := file.load(SAVE_PATH)
	if err == OK:
		var values := {}
		for key in SimulationPhysicsConfig.SAVE_KEYS:
			if file.has_section_key(SECTION, key):
				values[key] = file.get_value(SECTION, key)
		config.apply_save_dict(values)

	_loaded = true
	galaxy_config_loaded.emit(config)
	return config


func save_settings() -> void:
	if config == null:
		config = SimulationPhysicsConfig.new()

	var file := ConfigFile.new()
	for key in SimulationPhysicsConfig.SAVE_KEYS:
		file.set_value(SECTION, key, config.get(key))

	var err := file.save(SAVE_PATH)
	if err != OK:
		push_warning("Could not save galaxy settings. Error: %s" % str(err))
		return

	galaxy_config_saved.emit(config)


func load_into(target_config: SimulationPhysicsConfig) -> SimulationPhysicsConfig:
	var saved := get_config()
	if target_config == null:
		return saved

	target_config.apply_save_dict(saved.to_save_dict())
	config = target_config
	return config


func set_config_value(property_name: String, value: Variant, save_immediately: bool = true) -> bool:
	if config == null:
		config = SimulationPhysicsConfig.new()

	if not config.apply_safe_value(property_name, value):
		return false

	if save_immediately:
		save_settings()

	galaxy_config_changed.emit(property_name, config.get(property_name), config)
	return true


func replace_config(next_config: SimulationPhysicsConfig, save_immediately: bool = true) -> SimulationPhysicsConfig:
	if next_config == null:
		return get_config()

	config = next_config
	_loaded = true

	if save_immediately:
		save_settings()

	galaxy_config_loaded.emit(config)
	return config
