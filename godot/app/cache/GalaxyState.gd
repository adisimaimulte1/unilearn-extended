extends Node

signal galaxy_config_loaded(config: SimulationPhysicsConfig)
signal galaxy_config_changed(property_name: String, value: Variant, config: SimulationPhysicsConfig)
signal galaxy_config_saved(config: SimulationPhysicsConfig)
signal galaxy_bodies_loaded(bodies: Array)
signal galaxy_bodies_changed(bodies: Array)
signal galaxy_bodies_saved(bodies: Array)

const SAVE_PATH := "user://unilearn_galaxy_settings.cfg"
const SECTION := "galaxy_physics"
const BODIES_SECTION := "galaxy_bodies"
const BODIES_KEY := "items"

var config: SimulationPhysicsConfig = SimulationPhysicsConfig.new()
var bodies: Array[Dictionary] = []
var _loaded := false


func _ready() -> void:
	load_settings()


func get_config() -> SimulationPhysicsConfig:
	if not _loaded:
		load_settings()
	return config


func get_bodies() -> Array[Dictionary]:
	if not _loaded:
		load_settings()
	return bodies.duplicate(true)


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

		if file.has_section_key(BODIES_SECTION, BODIES_KEY):
			var loaded_bodies = file.get_value(BODIES_SECTION, BODIES_KEY, [])
			bodies = _sanitize_bodies_array(loaded_bodies)
		else:
			bodies.clear()

	_loaded = true
	galaxy_config_loaded.emit(config)
	galaxy_bodies_loaded.emit(bodies.duplicate(true))
	return config


func save_settings() -> void:
	if config == null:
		config = SimulationPhysicsConfig.new()

	var file := ConfigFile.new()

	for key in SimulationPhysicsConfig.SAVE_KEYS:
		file.set_value(SECTION, key, config.get(key))

	file.set_value(BODIES_SECTION, BODIES_KEY, bodies.duplicate(true))

	var err := file.save(SAVE_PATH)
	if err != OK:
		push_warning("Could not save galaxy settings. Error: %s" % str(err))
		return

	galaxy_config_saved.emit(config)
	galaxy_bodies_saved.emit(bodies.duplicate(true))


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


func set_bodies(next_bodies: Array, save_immediately: bool = true) -> void:
	bodies = _sanitize_bodies_array(next_bodies)
	_loaded = true

	if save_immediately:
		save_settings()

	galaxy_bodies_changed.emit(bodies.duplicate(true))


func clear_bodies(save_immediately: bool = true) -> void:
	bodies.clear()
	_loaded = true

	if save_immediately:
		save_settings()

	galaxy_bodies_changed.emit([])


func capture_runtime(system_objects: Array, next_config: SimulationPhysicsConfig = null, save_immediately: bool = true) -> void:
	if next_config != null:
		config = next_config

	set_bodies(system_objects, save_immediately)


func _sanitize_bodies_array(raw_value) -> Array[Dictionary]:
	var result: Array[Dictionary] = []

	if not raw_value is Array:
		return result

	for item in raw_value:
		if not item is Dictionary:
			continue

		var body := (item as Dictionary).duplicate(true)

		var card_id := str(body.get("card_id", "")).strip_edges()
		if card_id.is_empty():
			continue

		body["card_id"] = card_id
		body["order_index"] = int(body.get("order_index", result.size()))

		if body.has("position") and not body["position"] is Vector2:
			body["position"] = _variant_to_vector2(body["position"], Vector2.ZERO)

		if body.has("velocity") and not body["velocity"] is Vector2:
			body["velocity"] = _variant_to_vector2(body["velocity"], Vector2.ZERO)

		result.append(body)

	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("order_index", 0)) < int(b.get("order_index", 0))
	)

	return result


func _variant_to_vector2(value, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value

	if value is Dictionary:
		return Vector2(float(value.get("x", fallback.x)), float(value.get("y", fallback.y)))

	if value is Array and value.size() >= 2:
		return Vector2(float(value[0]), float(value[1]))

	return fallback
