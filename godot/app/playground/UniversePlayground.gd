extends Node2D
class_name UniversePlayground

const MAX_SIMULATION_BODIES := 20

signal planet_card_open_requested(planet_data)
signal scene_planets_changed(snapshot)
signal planet_added(body)
signal planet_removed(card_id)
signal planet_selected(body)

const SIMULATION_FACTORY := preload("res://addons/UnilearnLib/physics/SimulationPlanetFactory.gd")
const SIMULATION_CONFIG_SCRIPT := preload("res://addons/UnilearnLib/physics/SimulationPhysicsConfig.gd")
const GRAVITY_SOLVER := preload("res://addons/UnilearnLib/physics/SimulationGravitySolver.gd")
const COLLISION_SOLVER := preload("res://addons/UnilearnLib/physics/SimulationCollisionSolver.gd")
const ORBIT_UTILS := preload("res://addons/UnilearnLib/physics/SimulationOrbitUtils.gd")

const POINTER_NONE := -999
const POINTER_MOUSE := -2

const CRASH_POP_TIME := 0.10
const CRASH_SHRINK_TIME := 0.28
const CRASH_DRIFT_MAX_DISTANCE := 620.0
const BODY_ENTRY_OFFSET_Y := 34.0
const BODY_ENTRY_SCALE := Vector2(0.72, 0.72)
const BODY_ENTRY_FADE_TIME := 0.22
const BODY_ENTRY_SETTLE_TIME := 0.42
const BODY_LOGOUT_FADE_TIME := 0.72
const BODY_LOGOUT_STAGGER_TIME := 0.025
const BODY_ENTRY_MAX_STAGGER := 0.42
const DRAG_THROW_SPEED_CAP := 520.0
const UNIVERSE_END_FONT_PATH := "res://assets/fonts/JockeyOne-Regular.ttf"
const UNIVERSE_END_EXPLOSION_SFX_PATH := "res://assets/audio/sfx/explosion.mp3"
const UNIVERSE_END_AFTER_EXPLOSION_SFX_PATH := "res://assets/audio/sfx/after_explosion.mp3"
const UNIVERSE_END_KEYPRESS_SFX_DIR := "res://assets/audio/sfx/keys"
const UNIVERSE_END_FINAL_TEXT := "THE END?"
const UNIVERSE_END_WHITE_SCREEN_SECONDS := 8.0
const UNIVERSE_END_DANCE_SECONDS := 8.0
const UNIVERSE_END_AUDIO_VOLUME_DB := -8.0
const UNIVERSE_END_AFTER_AUDIO_TARGET_DB := -20.0
const UNIVERSE_END_AFTER_AUDIO_START_DB := -38.0
const UNIVERSE_END_FAKE_CENTER_CURSOR_OFFSET_FACTOR := 0.42
const DEFAULT_TIME_MULTIPLIER := 12.5
const DEFAULT_ORBIT_SPEED_MULTIPLIER := 12.5

const LAYER_BLACK_HOLE := 10
const LAYER_STAR := 20
const LAYER_PLANET := 30
const LAYER_MOON := 40

@export var config: SimulationPhysicsConfig = SIMULATION_CONFIG_SCRIPT.new()
@export var simulation_enabled: bool = false
@export var auto_select_added_body: bool = true
@export var follow_space_background_camera: bool = true
@export var space_background_path: NodePath = NodePath("/root/SpaceBackground")

@export var planet_click_sfx_id: String = "click"
@export var planet_release_sfx_id: String = "click"
@export var planet_open_sfx_id: String = "open"
@export var planet_crash_sfx_id: String = "error"

var _last_camera_position := Vector2(INF, INF)
var _last_camera_zoom := INF
var _last_camera_rotation := INF
var _last_viewport_center := Vector2(INF, INF)

var bodies: Array = []
var bodies_by_card_id: Dictionary = {}
var selected_body = null

var _space_background_ref: Node = null
var _last_snapshot: Array[Dictionary] = []

var _active_planet_pointer_id: int = POINTER_NONE
var _active_planet_pointer_body = null
var _last_planet_tap_sfx_usec: int = 0

var _active_screen_touches: Dictionary = {}
var _scene_objects_paused: bool = false
var _paused_body_velocity_cache: Dictionary = {}
var _physics_requested_while_paused: bool = false
var _crashing_body_ids: Dictionary = {}
var _last_physics_delta: float = 1.0 / 60.0
var _body_entry_tweens: Dictionary = {}
var _bulk_restoring_bodies: bool = false
var _achievement_tracker_cache: Node = null
var _achievement_runtime_accum: float = 0.0
var _universe_end_running: bool = false
var _universe_end_camera_tween: Tween = null
const ACHIEVEMENT_RUNTIME_INTERVAL := 0.85
const UNIVERSE_END_CAMERA_FOCUS_SECONDS := 2.65



func _ready() -> void:
	process_mode = Node.PROCESS_MODE_INHERIT
	_load_galaxy_config_from_state()
	_connect_galaxy_state_signal()
	set_process(follow_space_background_camera)
	set_physics_process(simulation_enabled)

	_cache_space_background()
	_sync_to_space_background_camera()


func _process(_delta: float) -> void:
	if _scene_objects_paused:
		return

	if follow_space_background_camera:
		_sync_to_space_background_camera()


func _physics_process(delta: float) -> void:
	if _scene_objects_paused:
		return

	if not simulation_enabled:
		return

	if config == null:
		return

	_last_physics_delta = max(delta, 0.0001)

	if config.gravity_enabled:
		GRAVITY_SOLVER.step(bodies, delta, config)

	_force_black_white_death_dance(delta)

	if config.collisions_enabled:
		var collision_bodies := _get_collision_active_bodies()
		var removed := COLLISION_SOLVER.solve(collision_bodies, config)

		if not removed.is_empty():
			_refresh_merge_survivor_visuals()
			_notify_black_magic_if_needed()
			_mark_orbit_architecture_dirty_after_collision()

		var universe_end_collision := false
		for body in removed:
			if body != null and is_instance_valid(body) and body.data != null:
				universe_end_collision = universe_end_collision or bool(body.data.metadata.get("universe_end_collision", false))
				_begin_crashed_body_removal(body)
		if universe_end_collision:
			call_deferred("_trigger_universe_end")

		if not removed.is_empty():
			_rebuild_orbit_architecture_after_collision()
			_notify_achievement_collision_batch(removed)

	_notify_achievement_runtime_snapshot(delta)


func _achievement_tracker() -> Node:
	if _achievement_tracker_cache != null and is_instance_valid(_achievement_tracker_cache):
		return _achievement_tracker_cache
	for path in ["/root/UnilearnAchievements", "/root/UnilearnAchievementTracker", "/root/AchievementTracker"]:
		var tracker := get_node_or_null(path)
		if tracker != null:
			_achievement_tracker_cache = tracker
			return tracker
	return null


func _notify_achievement_body_added(body) -> void:
	var tracker := _achievement_tracker()
	if tracker == null:
		return
	if tracker.has_method("register_body_added"):
		tracker.call("register_body_added", body)
	elif tracker.has_method("record_body_added"):
		tracker.call("record_body_added", body)


func _notify_achievement_collision_batch(removed: Array) -> void:
	var tracker := _achievement_tracker()
	if tracker == null:
		return
	for body in removed:
		var collision_a: Variant = null
		var collision_b: Variant = null
		var collision_survivor: Variant = null
		if body != null and is_instance_valid(body) and body.data != null:
			collision_a = body.data.metadata.get("achievement_collision_a", null)
			collision_b = body.data.metadata.get("achievement_collision_b", null)
			collision_survivor = body.data.metadata.get("achievement_collision_survivor", null)
		if collision_a != null and collision_b != null and tracker.has_method("register_collision"):
			tracker.call("register_collision", collision_a, collision_b, collision_survivor)
		elif tracker.has_method("record_planet_collision"):
			tracker.call("record_planet_collision", body, null)
		elif tracker.has_method("register_collision"):
			tracker.call("register_collision", body, null, null)


func _notify_achievement_runtime_snapshot(delta: float) -> void:
	_achievement_runtime_accum += max(delta, 0.0)
	if _achievement_runtime_accum < ACHIEVEMENT_RUNTIME_INTERVAL:
		return
	var elapsed := _achievement_runtime_accum
	_achievement_runtime_accum = 0.0
	var tracker := _achievement_tracker()
	if tracker == null:
		return
	var active_bodies := _get_collision_active_bodies()
	if active_bodies.size() < 2:
		return
	if tracker.has_method("register_stability_snapshot"):
		tracker.call("register_stability_snapshot", active_bodies, config, elapsed)
	if tracker.has_method("register_unstable_snapshot"):
		tracker.call("register_unstable_snapshot", active_bodies, config)


func set_simulation_config(next_config: SimulationPhysicsConfig, rebuild_orbits: bool = false) -> void:
	if next_config == null:
		return

	config = next_config
	_apply_config_side_effects("", null, rebuild_orbits)
	_update_physics_auto_state()


func apply_config_value(property_name: String, value) -> void:
	if property_name == "selected_body_instance_id":
		select_body_by_instance_id(str(value))
		return
	if property_name == "selected_body_card_id":
		select_body_by_card_id(str(value))
		return
	if property_name == "selected_body_mass_multiplier":
		_apply_selected_body_mass_multiplier(float(value))
		return
	if property_name == "selected_body_gravity_multiplier":
		_apply_selected_body_gravity_multiplier(float(value))
		return
	if property_name == "selected_body_size_multiplier":
		_apply_selected_body_size_multiplier(float(value))
		return

	if config == null:
		config = SIMULATION_CONFIG_SCRIPT.new()

	var applied := false
	if config.has_method("apply_safe_value"):
		applied = bool(config.call("apply_safe_value", property_name, value))
	elif _config_has_property(property_name):
		config.set(property_name, value)
		applied = true

	if not applied:
		return

	_apply_config_side_effects(property_name, config.get(property_name), false)
	_update_physics_auto_state()


func _load_galaxy_config_from_state() -> void:
	var state := get_node_or_null("/root/GalaxyState")
	if state == null:
		if config == null:
			config = SIMULATION_CONFIG_SCRIPT.new()
		_apply_default_simulation_multipliers_if_needed()
		return

	if config == null:
		config = SIMULATION_CONFIG_SCRIPT.new()

	if state.has_method("load_into"):
		var loaded: Variant = state.call("load_into", config)
		if loaded is SimulationPhysicsConfig:
			config = loaded
		return

	if state.has_method("get_config"):
		var loaded_config: Variant = state.call("get_config")
		if loaded_config is SimulationPhysicsConfig:
			config = loaded_config



func _apply_default_simulation_multipliers_if_needed() -> void:
	if config == null:
		return
	for item in [{"name":"simulation_speed", "value":DEFAULT_TIME_MULTIPLIER}, {"name":"orbit_speed_multiplier", "value":DEFAULT_ORBIT_SPEED_MULTIPLIER}, {"name":"revolution_speed_multiplier", "value":DEFAULT_ORBIT_SPEED_MULTIPLIER}]:
		var property_name := str(item.get("name", ""))
		var target_value := float(item.get("value", 1.0))
		if not _config_has_property(property_name):
			continue
		var current_value := float(config.get(property_name))
		if abs(current_value - 1.0) > 0.001:
			continue
		if config.has_method("apply_safe_value"):
			config.call("apply_safe_value", property_name, target_value)
		else:
			config.set(property_name, target_value)

func _connect_galaxy_state_signal() -> void:
	var state := get_node_or_null("/root/GalaxyState")
	if state == null:
		return

	if state.has_signal("galaxy_config_changed"):
		var callable := Callable(self, "_on_galaxy_state_config_changed")
		if not state.is_connected("galaxy_config_changed", callable):
			state.connect("galaxy_config_changed", callable)

	if state.has_signal("galaxy_config_loaded"):
		var loaded_callable := Callable(self, "_on_galaxy_state_config_loaded")
		if not state.is_connected("galaxy_config_loaded", loaded_callable):
			state.connect("galaxy_config_loaded", loaded_callable)


func _on_galaxy_state_config_changed(property_name: String, value, next_config: SimulationPhysicsConfig) -> void:
	if next_config != null and next_config != config:
		config = next_config
	else:
		apply_config_value(property_name, value)
		return

	_apply_config_side_effects(property_name, value, false)
	_update_physics_auto_state()


func _on_galaxy_state_config_loaded(next_config: SimulationPhysicsConfig) -> void:
	if next_config == null:
		return
	set_simulation_config(next_config, false)


func _config_has_property(property_name: String) -> bool:
	if config == null:
		return false
	if config.has_method("has_config_property"):
		return bool(config.call("has_config_property", property_name))
	return config.get(property_name) != null


func _apply_config_side_effects(property_name: String, _value, force_rebuild_orbits: bool = false) -> void:
	if property_name.is_empty():
		_refresh_trail_visibility()
		_trim_trails_to_config()
		_refresh_orbit_runtime_flags()
		if force_rebuild_orbits:
			reset_orbits()
		return

	var should_rebuild_orbits := force_rebuild_orbits
	match property_name:
		"trails_enabled":
			_refresh_trail_visibility()
		"max_trail_points", "trail_memory_percent", "trail_sample_distance":
			_trim_trails_to_config()
		"orbit_speed_multiplier", "revolution_speed_multiplier", "orbit_lock_strength", "orbit_distance_padding", "orbit_spacing_multiplier", "stable_orbit_radius_multiplier", "moon_orbit_spacing_multiplier", "binary_orbit_spacing_multiplier", "binary_max_distance_multiplier", "stable_orbit_mode", "center_largest_body", "lock_planets_to_largest_body", "hierarchical_orbits_enabled", "binary_orbits_enabled", "same_type_binary_enabled":
			should_rebuild_orbits = true
		"simulation_speed", "gravitational_constant", "center_anchor_strength", "hand_throw_enabled", "ignore_drag_throw_velocity":
			_refresh_orbit_runtime_flags()

	if should_rebuild_orbits:
		reset_orbits()
	else:
		_refresh_orbit_runtime_flags()


func _refresh_orbit_runtime_flags() -> void:
	if config == null:
		return

	var active_bodies := _get_collision_active_bodies()

	if active_bodies.size() >= 2:
		GRAVITY_SOLVER.prime_orbit_architecture(active_bodies, config, false)

	var anchor = _find_largest_body_from(active_bodies) if config.center_largest_body else null

	for body in active_bodies:
		if body == null or not is_instance_valid(body) or body.data == null:
			continue

		if _is_binary_body(body):
			body.data.is_static_anchor = false
			body.data.orbit_locked = bool(config.stable_orbit_mode)
			continue

		body.data.is_static_anchor = body == anchor

		if body == anchor:
			body.data.orbit_locked = false
			continue

		if not config.stable_orbit_mode:
			body.data.orbit_locked = false
			continue

		var parent = _find_best_orbit_parent(body)
		if parent != null and parent.data != null and not _is_white_hole_body(parent):
			body.data.orbit_parent_id = parent.data.instance_id
			# Recompute from the CURRENT sliders every refresh. Keeping an old radius here
			# made the 0.1 radius setting appear farther away than the 1.0 setting.
			body.data.orbit_radius = _preferred_orbit_radius_for_slot(body, parent, _orbit_slot_for_parent(parent, body))
			body.data.metadata["stable_orbit_radius_multiplier_used"] = _stable_radius_multiplier_local()
			
		if _orbit_parent_is_black_hole(body):
			body.data.orbit_locked = false
			body.data.metadata["black_hole_unstable_orbit"] = true
		else:
			body.data.orbit_locked = bool(config.lock_planets_to_largest_body or _is_moon_body(body) or _is_binary_body(body)) and not _orbit_parent_is_white_hole(body)


func _refresh_trail_visibility() -> void:
	var trails_visible := config == null or bool(config.trails_enabled)

	for body in bodies:
		if body == null or not is_instance_valid(body):
			continue

		var trail_line: Variant = body.get("trail_line")
		if trail_line != null and is_instance_valid(trail_line) and trail_line is CanvasItem:
			trail_line.visible = trails_visible


func _trim_trails_to_config() -> void:
	if config == null:
		return

	var max_points := int(config.max_trail_points)
	for body in bodies:
		if body == null or not is_instance_valid(body) or body.data == null:
			continue
		while max_points > 0 and body.data.trail_points.size() > max_points:
			body.data.trail_points.remove_at(0)
		if body.has_method("_update_trail_line"):
			body.call("_update_trail_line")
		if body.has_method("sync_from_data"):
			body.call("sync_from_data")


func _find_largest_body():
	var best = null
	var best_mass := -INF

	for body in bodies:
		if body == null or not is_instance_valid(body) or body.data == null:
			continue

		var score: float = body.data.mass
		if body.data.body_kind == SimulationPlanetData.BodyKind.STAR or body.data.body_kind == SimulationPlanetData.BodyKind.BLACK_HOLE:
			score *= 8.0
		elif body.data.body_kind == SimulationPlanetData.BodyKind.PLANET or body.data.body_kind == SimulationPlanetData.BodyKind.RINGED_PLANET:
			score *= 2.0

		if score > best_mass:
			best_mass = score
			best = body

	return best


func _find_largest_body_from(source_bodies: Array):
	var best = null
	var best_mass := -INF

	for body in source_bodies:
		if body == null or not is_instance_valid(body) or body.data == null:
			continue

		var score: float = body.data.mass
		if body.data.body_kind == SimulationPlanetData.BodyKind.STAR or body.data.body_kind == SimulationPlanetData.BodyKind.BLACK_HOLE:
			score *= 8.0
		elif body.data.body_kind == SimulationPlanetData.BodyKind.PLANET or body.data.body_kind == SimulationPlanetData.BodyKind.RINGED_PLANET:
			score *= 2.0

		if score > best_mass:
			best_mass = score
			best = body

	return best


func center_anchor_body() -> void:
	var anchor = _find_largest_body()
	if anchor == null or not is_instance_valid(anchor) or anchor.data == null:
		return

	anchor.data.position = Vector2.ZERO
	anchor.data.previous_position = Vector2.ZERO
	anchor.data.velocity = Vector2.ZERO
	anchor.data.acceleration = Vector2.ZERO
	anchor.data.is_static_anchor = true

	if anchor.data.has_method("reset_trail"):
		anchor.data.reset_trail()

	if anchor.has_method("sync_from_data"):
		anchor.call("sync_from_data")

	_refresh_orbit_runtime_flags()
	_emit_scene_snapshot_changed()


func reset_orbits() -> void:
	if config == null or bodies.size() < 2:
		return

	_refresh_orbit_runtime_flags()

	var anchor = _find_largest_body()
	for body in bodies:
		if body == null or not is_instance_valid(body) or body.data == null:
			continue
		if body == anchor:
			body.data.velocity = Vector2.ZERO
			body.data.acceleration = Vector2.ZERO
			body.data.is_static_anchor = bool(config.center_largest_body)
			body.data.orbit_parent_id = ""
			body.data.orbit_radius = 0.0
			body.data.orbit_locked = false
			body.data.reset_trail()
			body.sync_from_data()
			continue

		var parent = _find_best_orbit_parent(body)
		if parent == null and anchor != null:
			parent = anchor
		if parent == null or parent == body:
			continue

		var radius: float = _preferred_orbit_radius_for_slot(body, parent, _orbit_slot_for_parent(parent, body))
		if (_is_black_hole_body(body) and _is_white_hole_body(parent)) or (_is_white_hole_body(body) and _is_black_hole_body(parent)):
			body.data.orbit_parent_id = parent.data.instance_id
			body.data.orbit_radius = max(body.data.position.distance_to(parent.data.position), 1.0)
			body.data.orbit_locked = false
			body.data.metadata["black_hole_unstable_orbit"] = true
			body.data.metadata["death_dance_pair"] = parent.data.instance_id
			continue
		_prepare_soft_circular_orbit_local(body, parent, body.data.orbit_clockwise, radius, true)
		body.data.metadata["stable_orbit_radius_multiplier_used"] = _stable_radius_multiplier_local()
		if _is_black_hole_body(parent):
			body.data.orbit_locked = false
			body.data.metadata["black_hole_unstable_orbit"] = true
		else:
			body.data.orbit_locked = bool(config.stable_orbit_mode and config.lock_planets_to_largest_body)

	_emit_scene_snapshot_changed()


func clear_trails() -> void:
	for body in bodies:
		if body == null or not is_instance_valid(body) or body.data == null:
			continue
		body.data.reset_trail()
		if body.has_method("_update_trail_line"):
			body.call("_update_trail_line")
		if body.has_method("sync_from_data"):
			body.call("sync_from_data")


func _minimum_visible_orbit_radius(body, parent) -> float:
	if body == null or parent == null or body.data == null or parent.data == null:
		return 90.0
	if config == null:
		return 90.0
	return _minimum_orbit_radius_local(body.data, parent.data)


func _initial_spawn_velocity_for(body, spawn_position: Vector2) -> Vector2:
	if body == null or body.data == null or bodies.is_empty():
		return Vector2.ZERO
	var parent = null
	var best_distance := INF
	for other in bodies:
		if other == null or not is_instance_valid(other) or other.data == null:
			continue
		if other == body:
			continue
		var d: float = other.data.position.distance_to(spawn_position)
		if d < best_distance:
			best_distance = d
			parent = other
	if parent == null or parent.data == null:
		return Vector2.ZERO

	var offset: Vector2 = spawn_position - parent.data.position
	if offset.length() < 8.0:
		offset = Vector2.RIGHT.rotated(randf() * TAU) * 120.0

	var radial_dir := offset.normalized()
	if radial_dir.length_squared() < 0.001:
		radial_dir = Vector2.RIGHT.rotated(randf() * TAU)

	var tangent := Vector2(-radial_dir.y, radial_dir.x).normalized()
	if body.data != null and not bool(body.data.orbit_clockwise):
		tangent *= -1.0

	var speed := 95.0
	if config != null:
		var orbit_multiplier: float = config.get_orbit_speed_multiplier() if config.has_method("get_orbit_speed_multiplier") else clamp(config.revolution_speed_multiplier, 0.05, 32.0)
		var parent_mass: float = max(float(parent.data.mass) * abs(float(parent.data.gravitational_influence)), 0.001)
		speed = _safe_circular_orbit_speed(parent_mass, max(offset.length(), 16.0)) * orbit_multiplier
		if body.data.has_method("get_collision_radius"):
			speed = min(speed, 520.0)
		else:
			speed = min(speed, 420.0)

	return parent.data.velocity + tangent * clamp(speed, 45.0, 620.0)


func _safe_circular_orbit_speed(parent_mass: float, radius: float) -> float:
	if config == null:
		return 95.0
	var g: float = max(float(config.gravitational_constant), 0.001)
	var safe_mass: float = max(parent_mass, 0.001)
	var safe_radius: float = max(radius, 1.0)
	return sqrt(max(g * safe_mass / safe_radius, 0.0))

func get_simulation_body_count() -> int:
	return bodies.size()


func is_simulation_body_limit_reached() -> bool:
	return bodies.size() >= MAX_SIMULATION_BODIES


func add_planet_card(planet_data: PlanetData, space_position: Vector2) -> Node:
	if planet_data == null:
		return null

	var card_id := _card_key(planet_data)

	if card_id.is_empty():
		return null

	if bodies_by_card_id.has(card_id):
		var existing = bodies_by_card_id[card_id]

		if is_instance_valid(existing):
			select_body(existing)
			return existing

		bodies_by_card_id.erase(card_id)

	if not _bulk_restoring_bodies and is_simulation_body_limit_reached():
		push_warning("UniversePlayground: Scene body cap reached (%d)." % MAX_SIMULATION_BODIES)
		return null

	var actual_spawn_position := space_position
	if not _bulk_restoring_bodies:
		actual_spawn_position = screen_to_space(get_viewport_rect().size * 0.5)

	var body = SIMULATION_FACTORY.create_body_from_planet_data(planet_data, actual_spawn_position)

	if body == null:
		push_error("UniversePlayground: failed to create simulation body for %s." % planet_data.name)
		return null

	body.name = "Sim_%s" % _safe_node_name(planet_data.name)

	if body.data != null:
		body.data.source_card_id = card_id
		body.data.source_planet_data = planet_data
		body.data.position = actual_spawn_position
		body.data.previous_position = actual_spawn_position
		body.data.velocity = _initial_spawn_velocity_for(body, actual_spawn_position)
		body.data.acceleration = Vector2.ZERO
		if not _bulk_restoring_bodies:
			body.data.metadata["spawned_from_screen_center"] = true
			body.data.metadata["stable_orbit_soft_recover"] = true
			body.data.metadata["collision_protected_until_ms"] = Time.get_ticks_msec() + 4200

		if body.data.has_method("reset_trail"):
			body.data.reset_trail()

	add_child(body)

	if body.has_method("force_apply_planet_data"):
		body.call("force_apply_planet_data", planet_data)

	_apply_body_layer(body)

	bodies.append(body)
	bodies_by_card_id[card_id] = body

	_connect_body(body)
	
	if _scene_objects_paused and body.has_method("set_scene_animation_paused"):
		body.call("set_scene_animation_paused", true)

	if auto_select_added_body:
		select_body(body)

	if not _bulk_restoring_bodies and bodies.size() >= 2 and config != null:
		# Build the global architecture before assigning the just-added body a
		# fallback one-body orbit. Otherwise the new body briefly becomes a
		# normal satellite of the old anchor before binary promotion.
		GRAVITY_SOLVER.prime_orbit_architecture(bodies, config, true)
		if config.auto_orbit_enabled and config.stable_orbit_mode and not _is_binary_body(body):
			make_body_orbit_nearest(body, true, false, false)

	if not _bulk_restoring_bodies:
		_refresh_orbit_runtime_flags()
	_refresh_trail_visibility()
	_update_physics_auto_state()

	_emit_scene_snapshot_changed()
	planet_added.emit(body)
	_notify_achievement_body_added(body)

	return body



func play_scene_entry_animation(initial_delay: float = 0.0) -> void:
	if bodies.is_empty():
		return

	var max_index: int = max(bodies.size() - 1, 1)
	for i in range(bodies.size()):
		var body = bodies[i]
		if body == null or not is_instance_valid(body):
			continue
		var stagger: float = min(float(i) * 0.045, BODY_ENTRY_MAX_STAGGER)
		_play_body_entry_animation(body, max(initial_delay, 0.0) + stagger)


func _play_body_entry_animation(body, delay: float = 0.0) -> void:
	if body == null or not is_instance_valid(body):
		return
	if not body is Node2D:
		return

	var node_2d := body as Node2D
	var body_id := int(node_2d.get_instance_id())

	if _body_entry_tweens.has(body_id):
		var old_tween: Tween = _body_entry_tweens[body_id]
		if old_tween != null and old_tween.is_valid():
			old_tween.kill()

	var final_position := node_2d.position
	var final_scale := node_2d.scale
	if final_scale.length_squared() <= 0.0001:
		final_scale = Vector2.ONE

	node_2d.position = final_position + Vector2(0.0, BODY_ENTRY_OFFSET_Y)
	node_2d.scale = BODY_ENTRY_SCALE

	if node_2d is CanvasItem:
		var canvas_item := node_2d as CanvasItem
		canvas_item.modulate.a = 0.0

	var tween := create_tween()
	tween.set_parallel(true)

	if delay > 0.0:
		tween.tween_interval(delay)

	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(node_2d, "position", final_position, BODY_ENTRY_SETTLE_TIME).set_delay(delay)

	if node_2d is CanvasItem:
		tween.tween_property(node_2d, "modulate:a", 1.0, BODY_ENTRY_FADE_TIME).set_delay(delay)

	tween.set_trans(Tween.TRANS_BACK)
	tween.tween_property(node_2d, "scale", final_scale, BODY_ENTRY_SETTLE_TIME).set_delay(delay)
	tween.finished.connect(func() -> void:
		_body_entry_tweens.erase(body_id)
	)

	_body_entry_tweens[body_id] = tween


func _refresh_merge_survivor_visuals() -> void:
	for body in bodies:
		if body == null or not is_instance_valid(body) or body.data == null:
			continue

		if _crashing_body_ids.has(int(body.get_instance_id())):
			continue

		if bool(body.data.metadata.get("merge_visual_dirty", false)):
			if body.has_method("animate_merge_growth_from_metadata"):
				body.call("animate_merge_growth_from_metadata")
			else:
				body.data.metadata.erase("merge_visual_dirty")


func _notify_black_magic_if_needed() -> void:
	var tracker := _achievement_tracker()
	if tracker == null:
		return
	for body in bodies:
		if body == null or not is_instance_valid(body) or body.data == null:
			continue
		if bool(body.data.metadata.get("unlock_black_magic", false)):
			body.data.metadata.erase("unlock_black_magic")
			if tracker.has_method("unlock"):
				tracker.call("unlock", "black_magic", {"body": body.data.get_display_name()}, "supernova_collapse")
			elif tracker.has_method("register_black_hole_unlocked"):
				tracker.call("register_black_hole_unlocked", body)


func _mark_orbit_architecture_dirty_after_collision() -> void:
	if config == null:
		return

	GRAVITY_SOLVER.mark_orbit_architecture_dirty(bodies, true)


func _rebuild_orbit_architecture_after_collision() -> void:
	if config == null:
		return

	await get_tree().process_frame

	if config == null or bodies.size() < 2:
		return

	GRAVITY_SOLVER.prime_orbit_architecture(_get_collision_active_bodies(), config, true)
	_refresh_orbit_runtime_flags()
	_emit_scene_snapshot_changed()


func _force_black_white_death_dance(delta: float) -> void:
	if bodies.size() < 2 or delta <= 0.0:
		return

	var black_holes: Array = []
	var white_holes: Array = []
	for body in _get_collision_active_bodies():
		if body == null or not is_instance_valid(body) or body.data == null:
			continue
		if _is_black_hole_body(body):
			black_holes.append(body)
		elif _is_white_hole_body(body):
			white_holes.append(body)

	if black_holes.is_empty() or white_holes.is_empty():
		return

	for black in black_holes:
		for white in white_holes:
			if black == null or white == null or not is_instance_valid(black) or not is_instance_valid(white):
				continue
			if black.data == null or white.data == null:
				continue

			black.data.is_static_anchor = false
			white.data.is_static_anchor = false
			black.data.orbit_locked = false
			white.data.orbit_locked = false
			black.data.orbit_parent_id = white.data.instance_id
			white.data.orbit_parent_id = black.data.instance_id
			black.data.metadata["binary_partner_id"] = white.data.instance_id
			white.data.metadata["binary_partner_id"] = black.data.instance_id
			black.data.metadata["binary_center_locked"] = false
			white.data.metadata["binary_center_locked"] = false
			black.data.metadata["gravity_polarity"] = "attractive"
			white.data.metadata["gravity_polarity"] = "attractive"
			black.data.metadata["death_dance_pair"] = white.data.instance_id
			white.data.metadata["death_dance_pair"] = black.data.instance_id
			black.data.metadata["death_dance_ignore_binary_reseed"] = true
			white.data.metadata["death_dance_ignore_binary_reseed"] = true
			black.data.metadata["black_hole_unstable_orbit"] = true
			white.data.metadata["black_hole_unstable_orbit"] = true

			var offset: Vector2 = white.data.position - black.data.position
			var distance: float = offset.length()
			if distance < 1.0:
				offset = Vector2.RIGHT.rotated(float(abs(hash(black.data.instance_id + white.data.instance_id)) % 6283) / 1000.0)
				distance = 1.0
			var direction: Vector2 = offset / distance
			var combined_radius: float = max(black.data.get_collision_radius(config) + white.data.get_collision_radius(config), 1.0)
			var dance_duration: float = UNIVERSE_END_DANCE_SECONDS
			var dance_elapsed: float = float(black.data.metadata.get("death_dance_elapsed", 0.0)) + delta
			black.data.metadata["death_dance_elapsed"] = dance_elapsed
			white.data.metadata["death_dance_elapsed"] = dance_elapsed

			if not bool(black.data.metadata.get("death_dance_initialized", false)):
				black.data.metadata["death_dance_initialized"] = true
				white.data.metadata["death_dance_initialized"] = true
				black.data.metadata["death_dance_start_distance"] = distance
				white.data.metadata["death_dance_start_distance"] = distance
				black.data.metadata["death_dance_start_barycenter"] = (black.data.position * black.data.mass + white.data.position * white.data.mass) / max(black.data.mass + white.data.mass, 0.001)
				black.data.metadata["death_dance_collision_ready"] = false
				white.data.metadata["death_dance_collision_ready"] = false

			var dance_start_distance: float = max(float(black.data.metadata.get("death_dance_start_distance", distance)), combined_radius * 1.05, 1.0)
			var time_progress: float = clamp(dance_elapsed / dance_duration, 0.0, 1.0)
			var time_curve: float = time_progress * time_progress * (3.0 - 2.0 * time_progress)
			var total_mass: float = max(black.data.mass + white.data.mass, 0.001)
			var black_share: float = white.data.mass / total_mass
			var white_share: float = black.data.mass / total_mass
			var old_black_position: Vector2 = black.data.position
			var old_white_position: Vector2 = white.data.position
			var barycenter: Vector2 = (black.data.position * black.data.mass + white.data.position * white.data.mass) / total_mass
			var stored_barycenter: Variant = black.data.metadata.get("death_dance_start_barycenter", barycenter)
			var start_barycenter: Vector2 = stored_barycenter if stored_barycenter is Vector2 else barycenter
			var center_curve: float = clamp(time_curve * 0.72, 0.0, 1.0)
			var target_barycenter: Vector2 = start_barycenter.lerp(Vector2.ZERO, center_curve)
			var swirl_sign := -1.0 if black.data.instance_id < white.data.instance_id else 1.0
			var angular_speed: float = lerp(1.1, 7.6, time_curve)
			var next_direction := direction.rotated(swirl_sign * angular_speed * delta).normalized()
			var target_distance: float = lerp(dance_start_distance, 0.0, time_curve)
			target_distance = max(target_distance, 0.0)
			var black_target_position: Vector2 = target_barycenter - next_direction * target_distance * black_share
			var white_target_position: Vector2 = target_barycenter + next_direction * target_distance * white_share

			var position_blend: float = clamp(delta * lerp(1.8, 14.0, time_curve), 0.0, lerp(0.34, 0.96, time_curve))
			if dance_elapsed >= dance_duration:
				position_blend = 1.0
			var black_next_position: Vector2 = old_black_position.lerp(black_target_position, position_blend)
			var white_next_position: Vector2 = old_white_position.lerp(white_target_position, position_blend)
			var black_desired_velocity: Vector2 = (black_next_position - old_black_position) / max(delta, 0.0001)
			var white_desired_velocity: Vector2 = (white_next_position - old_white_position) / max(delta, 0.0001)
			var velocity_blend: float = clamp(delta * 3.25, 0.0, 0.35)

			black.data.previous_position = old_black_position
			white.data.previous_position = old_white_position
			black.data.position = black_next_position
			white.data.position = white_next_position
			black.data.velocity = black.data.velocity.lerp(black_desired_velocity, velocity_blend).limit_length(22000.0)
			white.data.velocity = white.data.velocity.lerp(white_desired_velocity, velocity_blend).limit_length(22000.0)
			var current_pair_distance: float = black_next_position.distance_to(white_next_position)
			var collision_window_started: bool = dance_elapsed >= dance_duration * 0.72
			var visual_collision_distance: float = combined_radius * 1.18
			var collision_ready: bool = collision_window_started and current_pair_distance <= visual_collision_distance
			black.data.metadata["death_dance_collision_ready"] = collision_ready
			white.data.metadata["death_dance_collision_ready"] = collision_ready
			if black.has_method("sync_from_data"):
				black.call("sync_from_data")
			if white.has_method("sync_from_data"):
				white.call("sync_from_data")

			if collision_ready:
				black.data.metadata["universe_end_collision"] = true
				white.data.metadata["universe_end_collision"] = true
				call_deferred("_trigger_universe_end")
				return


func focus_universe_end_pair_camera(duration: float = UNIVERSE_END_CAMERA_FOCUS_SECONDS) -> void:
	if _space_background_ref == null or not is_instance_valid(_space_background_ref):
		_cache_space_background()

	if _space_background_ref == null or not is_instance_valid(_space_background_ref):
		return

	var pair := _get_black_white_universe_end_pair()
	if pair.is_empty():
		return

	var start_position := _get_space_background_vector("space_position", Vector2.ZERO)
	var start_zoom := _get_space_background_float("space_zoom", 1.0)
	var target_zoom := 0.16
	duration = max(duration, 0.05)

	if _space_background_ref.has_method("set_navigation_enabled"):
		_space_background_ref.call("set_navigation_enabled", false)

	if _universe_end_camera_tween != null and _universe_end_camera_tween.is_valid():
		_universe_end_camera_tween.kill()

	_universe_end_camera_tween = create_tween()
	_universe_end_camera_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_universe_end_camera_tween.set_trans(Tween.TRANS_SINE)
	_universe_end_camera_tween.set_ease(Tween.EASE_IN_OUT)
	_universe_end_camera_tween.tween_method(
		Callable(self, "_update_universe_end_camera_focus").bind(pair, start_position, start_zoom, target_zoom),
		0.0,
		1.0,
		duration
	)


func _update_universe_end_camera_focus(progress: float, fallback_pair: Array, start_position: Vector2, start_zoom: float, target_zoom: float) -> void:
	var live_pair := _get_black_white_universe_end_pair()
	var target_position := _get_pair_barycenter(live_pair) if not live_pair.is_empty() else _get_pair_barycenter(fallback_pair)
	var curve := progress * progress * (3.0 - 2.0 * progress)
	_apply_universe_end_camera_values(start_position.lerp(target_position, curve), lerp(start_zoom, target_zoom, curve))


func _apply_universe_end_camera_values(camera_position: Vector2, camera_zoom: float) -> void:
	if _space_background_ref == null or not is_instance_valid(_space_background_ref):
		return

	if _space_background_ref.has_method("set_space_position"):
		_space_background_ref.call("set_space_position", camera_position, true)
	else:
		_space_background_ref.set("space_position", camera_position)
		_space_background_ref.set("target_space_position", camera_position)

	if _space_background_ref.has_method("set_space_zoom"):
		_space_background_ref.call("set_space_zoom", camera_zoom, Vector2.ZERO, true)
	else:
		_space_background_ref.set("space_zoom", camera_zoom)
		_space_background_ref.set("target_space_zoom", camera_zoom)

	_sync_to_space_background_camera()


func _get_black_white_universe_end_pair() -> Array:
	var black = null
	var white = null
	var best_score := -INF

	for candidate_black in bodies:
		if candidate_black == null or not is_instance_valid(candidate_black) or candidate_black.data == null:
			continue
		if not _is_black_hole_body(candidate_black):
			continue
		for candidate_white in bodies:
			if candidate_white == null or not is_instance_valid(candidate_white) or candidate_white.data == null:
				continue
			if not _is_white_hole_body(candidate_white):
				continue
			var paired := str(candidate_black.data.metadata.get("death_dance_pair", "")) == str(candidate_white.data.instance_id)
			paired = paired or str(candidate_white.data.metadata.get("death_dance_pair", "")) == str(candidate_black.data.instance_id)
			var distance: float = max(candidate_black.data.position.distance_to(candidate_white.data.position), 1.0)
			var mass_score: float = max(candidate_black.data.mass, 0.001) + max(candidate_white.data.mass, 0.001)
			var score: float = mass_score / distance
			if paired:
				score *= 1000.0
			if score > best_score:
				best_score = score
				black = candidate_black
				white = candidate_white

	if black == null or white == null:
		return []

	return [black, white]


func _get_pair_barycenter(pair: Array) -> Vector2:
	if pair.size() < 2:
		return Vector2.ZERO

	var black = pair[0]
	var white = pair[1]
	if black == null or white == null or not is_instance_valid(black) or not is_instance_valid(white):
		return Vector2.ZERO
	if black.data == null or white.data == null:
		return Vector2.ZERO

	var black_mass: float = max(float(black.data.mass), 0.001)
	var white_mass: float = max(float(white.data.mass), 0.001)
	var total_mass: float = max(black_mass + white_mass, 0.001)
	return (black.data.position * black_mass + white.data.position * white_mass) / total_mass


func _get_crash_visual_velocity(body) -> Vector2:
	if body == null or not is_instance_valid(body) or body.data == null:
		return Vector2.ZERO

	var d: SimulationPlanetData = body.data
	var path_delta: Vector2 = d.position - d.previous_position
	var path_velocity := Vector2.ZERO

	if path_delta.length_squared() > 0.0001:
		path_velocity = path_delta / max(_last_physics_delta * max(config.simulation_speed if config != null else 1.0, 0.001), 0.0001)

	if path_velocity.length_squared() > 1.0:
		var speed: float = max(d.velocity.length(), path_velocity.length())
		return path_velocity.normalized() * speed

	return d.velocity


func _begin_crashed_body_removal(body) -> void:
	if body == null or not is_instance_valid(body):
		return

	if body.data == null:
		return

	var body_id := int(body.get_instance_id())
	if _crashing_body_ids.has(body_id):
		return

	_crashing_body_ids[body_id] = true

	var card_id := str(body.data.source_card_id).strip_edges()
	var crash_velocity: Vector2 = _get_crash_visual_velocity(body)

	body.data.is_dragging = true
	body.data.acceleration = Vector2.ZERO
	body.data.collision_mode = SimulationPlanetData.CollisionMode.OFF
	body.data.gravitational_influence = 0.0
	body.data.velocity = crash_velocity
	body.data.metadata["crashing_out"] = true
	body.data.metadata["crash_card_id"] = card_id

	if selected_body == body:
		selected_body = null

	if _active_planet_pointer_body == body:
		_clear_active_planet_pointer()

	if body.has_method("set_scene_animation_paused"):
		body.call("set_scene_animation_paused", false)

	_play_planet_crash_sfx()
	_animate_crashed_body(body, body_id, card_id, crash_velocity)


func _animate_crashed_body(body, body_id: int, card_id: String = "", crash_velocity: Vector2 = Vector2.ZERO) -> void:
	if body == null or not is_instance_valid(body):
		_finalize_crashed_body_removal(body, body_id, card_id, false)
		return

	if body is CanvasItem:
		var canvas_item := body as CanvasItem
		canvas_item.z_as_relative = false
		canvas_item.z_index = max(canvas_item.z_index, 250)

	if body is Node2D:
		var node_2d := body as Node2D
		var start_scale := node_2d.scale
		if start_scale.length_squared() <= 0.0001:
			start_scale = Vector2.ONE

		var total_time := CRASH_POP_TIME + CRASH_SHRINK_TIME
		var max_speed: float = CRASH_DRIFT_MAX_DISTANCE / max(total_time, 0.001)
		var visual_velocity := crash_velocity.limit_length(max_speed)
		var start_position: Vector2 = body.data.position if body.data != null else node_2d.position

		var motion_tween := node_2d.create_tween()
		motion_tween.set_trans(Tween.TRANS_LINEAR)
		motion_tween.set_ease(Tween.EASE_IN_OUT)
		motion_tween.tween_method(Callable(self, "_update_crash_body_motion").bind(body, start_position, visual_velocity), 0.0, total_time, total_time)

		var tween := node_2d.create_tween()
		tween.set_trans(Tween.TRANS_BACK)
		tween.set_ease(Tween.EASE_OUT)
		tween.tween_property(node_2d, "scale", start_scale * 1.12, CRASH_POP_TIME)
		tween.set_trans(Tween.TRANS_QUAD)
		tween.set_ease(Tween.EASE_IN)
		tween.tween_property(node_2d, "scale", start_scale * 0.06, CRASH_SHRINK_TIME)

		if node_2d is CanvasItem:
			tween.parallel().tween_property(node_2d, "modulate:a", 0.25, CRASH_SHRINK_TIME)

		tween.finished.connect(func() -> void:
			_finalize_crashed_body_removal(body, body_id, card_id, false)
		)
		return

	_finalize_crashed_body_removal(body, body_id, card_id, false)


func _update_crash_body_motion(elapsed: float, body, start_position: Vector2, visual_velocity: Vector2) -> void:
	if body == null or not is_instance_valid(body):
		return

	if body.data == null:
		return

	var next_position := start_position + visual_velocity * elapsed
	body.data.position = next_position
	body.data.previous_position = next_position
	body.data.velocity = visual_velocity
	body.call("sync_from_data")


func _get_collision_active_bodies() -> Array:
	var result: Array = []

	for body in bodies:
		if body == null or not is_instance_valid(body):
			continue

		var body_id := int(body.get_instance_id())
		if _crashing_body_ids.has(body_id):
			continue

		result.append(body)

	return result


func _finalize_crashed_body_removal(body, body_id: int, card_id: String = "", play_sfx: bool = true) -> void:
	_crashing_body_ids.erase(body_id)

	if body != null:
		bodies.erase(body)

	if not card_id.is_empty() and bodies_by_card_id.has(card_id) and bodies_by_card_id[card_id] == body:
		bodies_by_card_id.erase(card_id)

	if selected_body == body:
		selected_body = null

	if _active_planet_pointer_body == body:
		_clear_active_planet_pointer()

	_mark_orbit_architecture_dirty_after_collision()
	_rebuild_orbit_architecture_after_collision()
	_update_physics_auto_state()
	_emit_scene_snapshot_changed()

	if not card_id.is_empty():
		planet_removed.emit(card_id)

	if play_sfx:
		_play_planet_crash_sfx()

	if body != null and is_instance_valid(body):
		if body.data != null:
			body.data.is_dragging = false
		body.queue_free()


func _play_planet_crash_sfx() -> void:
	var clean_id := planet_crash_sfx_id.strip_edges()

	if clean_id.is_empty():
		clean_id = "error"

	if has_node("/root/UnilearnUserSettings"):
		var settings := get_node("/root/UnilearnUserSettings")
		if settings != null and settings.get("sfx_enabled") == false:
			return

	var sfx := get_node_or_null("/root/UnilearnSFX")

	if sfx == null:
		return

	if sfx.has_method("play"):
		sfx.call("play", clean_id, 0.92, 1.03)


func remove_planet_card(planet_data: PlanetData) -> void:
	if planet_data == null:
		return

	remove_planet_card_id(_card_key(planet_data))


func remove_planet_card_id(card_id: String) -> void:
	card_id = card_id.strip_edges()

	if card_id.is_empty():
		return

	if not bodies_by_card_id.has(card_id):
		return

	var body = bodies_by_card_id[card_id]
	bodies_by_card_id.erase(card_id)
	bodies.erase(body)

	if selected_body == body:
		selected_body = null

	if _active_planet_pointer_body == body:
		_clear_active_planet_pointer()

	if is_instance_valid(body):
		body.queue_free()

	_update_physics_auto_state()

	_emit_scene_snapshot_changed()
	planet_removed.emit(card_id)


func is_planet_card_added(planet_data: PlanetData) -> bool:
	if planet_data == null:
		return false

	return is_planet_card_id_added(_card_key(planet_data))


func is_planet_card_id_added(card_id: String) -> bool:
	card_id = card_id.strip_edges()

	if card_id.is_empty():
		return false

	if not bodies_by_card_id.has(card_id):
		return false

	var body = bodies_by_card_id[card_id]

	if is_instance_valid(body):
		return true

	bodies_by_card_id.erase(card_id)
	return false


func get_body_for_card(planet_data: PlanetData):
	if planet_data == null:
		return null

	var card_id := _card_key(planet_data)

	if not bodies_by_card_id.has(card_id):
		return null

	var body = bodies_by_card_id[card_id]

	if is_instance_valid(body):
		return body

	bodies_by_card_id.erase(card_id)
	return null


func is_dragging_any_body() -> bool:
	for body in bodies:
		if body == null or not is_instance_valid(body):
			continue

		if body.has_method("is_dragging_body") and bool(body.call("is_dragging_body")):
			return true

	return false


func is_screen_position_over_body(screen_position: Vector2) -> bool:
	return get_body_at_screen_position(screen_position) != null


func get_body_at_screen_position(screen_position: Vector2):
	var best_body = null
	var best_z := -INF
	var best_order := -1

	for i in range(bodies.size()):
		var body = bodies[i]

		if body == null or not is_instance_valid(body):
			continue

		if not body.has_method("contains_screen_position"):
			continue

		if not bool(body.call("contains_screen_position", screen_position)):
			continue

		var z := 0

		if body is CanvasItem:
			z = (body as CanvasItem).z_index

		if best_body == null or float(z) > best_z or (float(z) == best_z and i > best_order):
			best_body = body
			best_z = float(z)
			best_order = i

	return best_body


func consume_space_input(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		return _consume_mouse_button(event)

	if event is InputEventMouseMotion:
		return _consume_mouse_motion(event)

	if event is InputEventScreenTouch:
		return _consume_screen_touch(event)

	if event is InputEventScreenDrag:
		return _consume_screen_drag(event)

	return false

func _consume_mouse_button(event: InputEventMouseButton) -> bool:
	if event.button_index != MOUSE_BUTTON_LEFT:
		return false

	if event.pressed:
		var body = get_body_at_screen_position(event.position)

		if body == null:
			_clear_active_planet_pointer()
			return false

		_active_planet_pointer_id = POINTER_MOUSE
		_active_planet_pointer_body = body

		select_body(body)
		_play_planet_sfx(planet_click_sfx_id)
		_forward_event_to_active_planet(event)

		return true

	if _active_planet_pointer_id == POINTER_MOUSE:
		_forward_event_to_active_planet(event)
		_clear_active_planet_pointer()
		return true

	return false

func _consume_mouse_motion(event: InputEventMouseMotion) -> bool:
	if _active_planet_pointer_id != POINTER_MOUSE:
		return false

	_forward_event_to_active_planet(event)
	return true

func _consume_screen_touch(event: InputEventScreenTouch) -> bool:
	if event.pressed:
		_active_screen_touches[event.index] = event.position

		var body = get_body_at_screen_position(event.position)

		if _active_planet_pointer_id == POINTER_NONE and body != null:
			_active_planet_pointer_id = event.index
			_active_planet_pointer_body = body

			select_body(body)
			_play_planet_sfx(planet_click_sfx_id)
			_forward_event_to_active_planet(event)

			return true

		return false

	_active_screen_touches.erase(event.index)

	if event.index == _active_planet_pointer_id:
		_forward_event_to_active_planet(event)
		_clear_active_planet_pointer()
		return true

	return false


func _consume_screen_drag(event: InputEventScreenDrag) -> bool:
	_active_screen_touches[event.index] = event.position

	if event.index != _active_planet_pointer_id:
		return false

	_forward_event_to_active_planet(event)
	return true


func _forward_event_to_active_planet(event: InputEvent) -> void:
	if _active_planet_pointer_body == null:
		return

	if not is_instance_valid(_active_planet_pointer_body):
		return

	if _active_planet_pointer_body.has_method("handle_planet_input"):
		_active_planet_pointer_body.call("handle_planet_input", event)


func _clear_active_planet_pointer() -> void:
	_active_planet_pointer_id = POINTER_NONE
	_active_planet_pointer_body = null


func _runtime_object_category_for_body(body) -> String:
	if body == null or not is_instance_valid(body) or body.data == null:
		return "planet"
	if _is_black_hole_body(body) or _is_white_hole_body(body):
		return "singularity"
	var source: PlanetData = body.data.source_planet_data
	if source != null:
		var category := source.object_category.strip_edges().to_lower().replace(" ", "_").replace("-", "_")
		if category != "":
			return category
	match int(body.data.body_kind):
		SimulationPlanetData.BodyKind.STAR:
			return "star"
		SimulationPlanetData.BodyKind.MOON, SimulationPlanetData.BodyKind.SATELLITE:
			return "moon"
		SimulationPlanetData.BodyKind.RINGED_PLANET:
			return "planet"
		_:
			return "planet"

func get_added_planets_snapshot() -> Array[Dictionary]:
	var snapshot: Array[Dictionary] = []

	for body in bodies:
		if body == null or not is_instance_valid(body):
			continue

		if body.data == null:
			continue

		var source: PlanetData = body.data.source_planet_data

		var source_name := ""
		var source_subtitle := ""
		if source != null:
			source_name = source.name
			source_subtitle = source.subtitle

		var display_name := source_name.strip_edges()
		if display_name.is_empty():
			display_name = str(body.data.get_display_name()).strip_edges()
		if display_name.is_empty() or display_name.to_lower() == "unknown body" or display_name.to_lower() == "object":
			display_name = body.data.source_card_id

		var hero_main_color: Color = body.data.get_hero_main_color()

		snapshot.append({
			"order_index": snapshot.size(),
			"card_id": body.data.source_card_id,
			"instance_id": body.data.instance_id,
			"name": display_name,
			"title": display_name,
			"source_name": source_name,
			"subtitle": source_subtitle,
			"position": body.data.position,
			"velocity": body.data.velocity,
			"mass": body.data.mass,
			"radius_world": body.data.radius_world,
			"orbit_parent_id": body.data.orbit_parent_id,
			"orbit_radius": body.data.orbit_radius,
			"orbit_clockwise": body.data.orbit_clockwise,
			"body_kind": int(body.data.body_kind),
			"planet_preset": source.planet_preset if source != null else body.data.get_planet_preset(),
			"planet_seed": source.planet_seed if source != null else body.data.get_planet_seed(),
			"planet_radius_px": source.planet_radius_px if source != null else body.data.visual_radius_px,
			"simulation_radius_px": body.data.visual_radius_px,
			"planet_pixels": source.planet_pixels if source != null else 0,
			"planet_turning_speed": source.planet_turning_speed if source != null else 0.0,
			"planet_axial_tilt_deg": source.planet_axial_tilt_deg if source != null else 0.0,
			"use_custom_colors": source.use_custom_colors if source != null else false,
			"custom_colors": source.custom_colors if source != null else PackedColorArray(),
			"hero_main_color": hero_main_color,
			"hero_main_color_hex": hero_main_color.to_html(true),
			"object_category": _runtime_object_category_for_body(body),
			"source_object_category": source.object_category if source != null else ""
		})

	return snapshot


func restore_added_planets(saved_bodies: Array, available_cards: Array) -> void:
	clear_all()

	if saved_bodies.is_empty():
		return

	_bulk_restoring_bodies = true

	var card_map := _build_planet_card_map(available_cards)

	var sorted_bodies := saved_bodies.duplicate(true)
	sorted_bodies.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("order_index", 0)) < int(b.get("order_index", 0))
	)

	for item in sorted_bodies:
		if not item is Dictionary:
			continue

		var body_data: Dictionary = item
		var card_id := str(body_data.get("card_id", "")).strip_edges()

		if card_id.is_empty():
			continue

		if not card_map.has(card_id):
			continue

		var planet_data: PlanetData = card_map[card_id]
		var saved_position := _read_vector2_from_dictionary(body_data, "position", Vector2.ZERO)

		var body = add_planet_card(planet_data, saved_position)

		if body == null or not is_instance_valid(body):
			continue

		if body.data == null:
			continue

		body.data.position = saved_position
		body.data.previous_position = saved_position
		body.data.velocity = _read_vector2_from_dictionary(body_data, "velocity", Vector2.ZERO)
		body.data.orbit_parent_id = str(body_data.get("orbit_parent_id", ""))
		body.data.orbit_radius = float(body_data.get("orbit_radius", 0.0))
		body.data.orbit_clockwise = bool(body_data.get("orbit_clockwise", true))

		if body_data.has("instance_id"):
			body.data.instance_id = str(body_data.get("instance_id", body.data.instance_id))

		if body.has_method("sync_from_data"):
			body.call("sync_from_data")

		if body.data.has_method("reset_trail"):
			body.data.reset_trail()

	_bulk_restoring_bodies = false
	_update_physics_auto_state()
	_emit_scene_snapshot_changed()


func _build_planet_card_map(available_cards: Array) -> Dictionary:
	var result := {}

	for card in available_cards:
		if card == null:
			continue

		if not card is PlanetData:
			continue

		var planet_data: PlanetData = card
		var key := _card_key(planet_data)

		if not key.is_empty():
			result[key] = planet_data

	return result


func _read_vector2_from_dictionary(data: Dictionary, key: String, fallback: Vector2) -> Vector2:
	if not data.has(key):
		return fallback

	var value = data[key]

	if value is Vector2:
		return value

	if value is Dictionary:
		return Vector2(float(value.get("x", fallback.x)), float(value.get("y", fallback.y)))

	if value is Array and value.size() >= 2:
		return Vector2(float(value[0]), float(value[1]))

	return fallback


func get_galaxy_database_document() -> Dictionary:
	return {
		"updated_at_unix": Time.get_unix_time_from_system(),
		"planet_count": bodies.size(),
		"planets": get_added_planets_snapshot()
	}


func _trigger_universe_end() -> void:
	if _universe_end_running:
		return
	_universe_end_running = true
	_scene_objects_paused = true
	set_physics_process(false)

	var layer := CanvasLayer.new()
	layer.layer = 50000
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	var flash := ColorRect.new()
	flash.color = Color(1.0, 1.0, 1.0, 0.0)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(flash)

	var label_holder := Control.new()
	label_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label_holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(label_holder)

	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = false
	label.scroll_active = false
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.custom_minimum_size = Vector2.ZERO
	label.add_theme_color_override("default_color", Color.BLACK)
	var end_font := load(UNIVERSE_END_FONT_PATH) as Font
	if end_font != null:
		label.add_theme_font_override("normal_font", end_font)
	label.add_theme_font_size_override("normal_font_size", 220)
	label.add_theme_constant_override("line_separation", 0)
	label_holder.add_child(label)

	var cursor_bar := ColorRect.new()
	cursor_bar.name = "UniverseEndCursor"
	cursor_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cursor_bar.color = Color.BLACK
	label.add_child(cursor_bar)
	label.set_meta("universe_end_cursor", cursor_bar)

	_layout_universe_end_label(label)
	_set_universe_end_text(label, "", true)
	get_tree().root.add_child(layer)

	var universe_end_started_msec := Time.get_ticks_msec()
	_stop_music_for_universe_end()
	_play_universe_end_audio(layer)

	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(flash, "color", Color(1.0, 1.0, 1.0, 1.0), 1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await _wait_with_universe_cursor(label, "", 1.0, false)

	var after_player := _play_universe_end_after_audio(layer)
	var typed_text: String = await _type_universe_end_label(label, "THE END", 0.46, layer)
	await _wait_with_universe_cursor(label, typed_text, 1.0)
	_play_universe_end_key_sfx(layer)
	typed_text += "?"
	_set_universe_end_text(label, typed_text, true)
	await _wait_with_universe_cursor(label, typed_text, 0.5)
	_set_universe_end_text(label, typed_text, false)

	var alive_elapsed := float(Time.get_ticks_msec() - universe_end_started_msec) / 1000.0
	var remaining_alive: float = max(0.0, UNIVERSE_END_WHITE_SCREEN_SECONDS - alive_elapsed)
	if remaining_alive > 3.0:
		await get_tree().create_timer(remaining_alive - 3.0, true, false, true).timeout
		_fade_universe_end_after_audio(after_player, 3.0)
		await get_tree().create_timer(3.0, true, false, true).timeout
	elif remaining_alive > 0.0:
		_fade_universe_end_after_audio(after_player, remaining_alive)
		await get_tree().create_timer(remaining_alive, true, false, true).timeout

	_set_universe_end_text(label, typed_text, false)
	clear_all()

	var fade := create_tween()
	fade.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	fade.tween_property(flash, "color", Color(1.0, 1.0, 1.0, 0.0), 0.72).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	fade.parallel().tween_property(label, "modulate:a", 0.0, 0.72)
	await fade.finished

	if is_instance_valid(layer):
		layer.queue_free()
	_resume_music_after_universe_end()
	_unlock_universe_end_achievement()
	_scene_objects_paused = false
	_universe_end_running = false
	_update_physics_auto_state()



func _stop_music_for_universe_end() -> void:
	var music := get_node_or_null("/root/UnilearnMusic")
	if music != null and music.has_method("stop_for_universe_end"):
		music.call("stop_for_universe_end")


func _resume_music_after_universe_end() -> void:
	var music := get_node_or_null("/root/UnilearnMusic")
	if music != null and music.has_method("resume_after_universe_end"):
		music.call("resume_after_universe_end")


func _layout_universe_end_label(label: RichTextLabel) -> void:
	if label == null or not is_instance_valid(label):
		return
	var viewport_size: Vector2 = get_viewport_rect().size
	var label_height: float = min(360.0, max(260.0, viewport_size.y * 0.32))
	var label_width: float = min(viewport_size.x * 0.94, max(360.0, _universe_end_final_line_width(label)))
	var label_offset_x: float = _universe_end_fake_center_offset(label)
	label.position = Vector2((viewport_size.x - label_width) * 0.5 + label_offset_x, (viewport_size.y - label_height) * 0.5)
	label.size = Vector2(label_width, label_height)

func _universe_end_final_line_width(label: RichTextLabel) -> float:
	if label == null or not is_instance_valid(label):
		return 520.0
	var font := label.get_theme_font("normal_font")
	var font_size: int = label.get_theme_font_size("normal_font_size")
	if font_size <= 0:
		font_size = 220
	if font == null:
		return float(font_size) * 4.1
	var text_width: float = font.get_string_size(UNIVERSE_END_FINAL_TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
	var cursor_width: float = font.get_string_size("|", HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
	return text_width + cursor_width

func _universe_end_fake_center_offset(label: RichTextLabel) -> float:
	if label == null or not is_instance_valid(label):
		return 0.0
	var font := label.get_theme_font("normal_font")
	var font_size: int = label.get_theme_font_size("normal_font_size")
	if font_size <= 0:
		font_size = 220
	if font == null:
		return max(8.0, float(font_size) * 0.05) * UNIVERSE_END_FAKE_CENTER_CURSOR_OFFSET_FACTOR
	var cursor_width: float = font.get_string_size("|", HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
	return max(0.0, cursor_width * UNIVERSE_END_FAKE_CENTER_CURSOR_OFFSET_FACTOR)

func _play_universe_end_audio(parent: Node) -> void:
	if not _sfx_enabled_for_universe_end():
		return
	_play_universe_end_stream(parent, UNIVERSE_END_EXPLOSION_SFX_PATH, UNIVERSE_END_AUDIO_VOLUME_DB, false, UNIVERSE_END_AUDIO_VOLUME_DB)


func _play_universe_end_after_audio(parent: Node) -> AudioStreamPlayer:
	if not _sfx_enabled_for_universe_end():
		return null
	return _play_universe_end_stream(parent, UNIVERSE_END_AFTER_EXPLOSION_SFX_PATH, UNIVERSE_END_AFTER_AUDIO_START_DB, true, UNIVERSE_END_AFTER_AUDIO_TARGET_DB)


func _play_universe_end_stream(parent: Node, path: String, start_volume_db: float, fade_in: bool, target_volume_db: float = 0.0) -> AudioStreamPlayer:
	if parent == null or not is_instance_valid(parent):
		return null
	if not ResourceLoader.exists(path):
		return null
	var stream := load(path) as AudioStream
	if stream == null:
		return null
	var player := AudioStreamPlayer.new()
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	player.bus = "Master"
	player.stream = stream
	player.volume_db = start_volume_db
	parent.add_child(player)
	player.play()
	if fade_in:
		var audio_tween := create_tween()
		audio_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		audio_tween.tween_property(player, "volume_db", target_volume_db, 2.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	return player


func _sfx_enabled_for_universe_end() -> bool:
	if has_node("/root/UnilearnUserSettings"):
		var settings := get_node("/root/UnilearnUserSettings")
		if settings != null and settings.get("sfx_enabled") == false:
			return false
	var sfx := get_node_or_null("/root/UnilearnSFX")
	if sfx != null and sfx.get("enabled") == false:
		return false
	return true


func _type_universe_end_label(label, text: String, delay: float, sfx_parent: Node) -> String:
	var visible_text := ""
	_set_universe_end_text(label, visible_text, _universe_end_cursor_visible_now())
	for i in range(text.length()):
		visible_text += text.substr(i, 1)
		_play_universe_end_key_sfx(sfx_parent)
		_set_universe_end_text(label, visible_text, _universe_end_cursor_visible_now())
		await _wait_with_universe_cursor(label, visible_text, delay, false)
	return visible_text


func _wait_with_universe_cursor(label, visible_text: String, duration: float, force_visible_at_end: bool = true) -> void:
	var elapsed := 0.0
	var tick_step := 0.08
	while elapsed < duration:
		_set_universe_end_text(label, visible_text, _universe_end_cursor_visible_now())
		var step: float = min(tick_step, duration - elapsed)
		await get_tree().create_timer(step, true, false, true).timeout
		elapsed += step
	_set_universe_end_text(label, visible_text, true if force_visible_at_end else _universe_end_cursor_visible_now())


func _universe_end_cursor_visible_now() -> bool:
	var blink_seconds: float = 0.48
	var phase: float = fmod(float(Time.get_ticks_msec()) / 1000.0, blink_seconds * 2.0)
	return phase < blink_seconds


func _set_universe_end_text(label, visible_text: String, cursor_visible: bool) -> void:
	if label == null or not is_instance_valid(label):
		return
	var safe_text := _escape_universe_end_bbcode(visible_text)
	var cursor_color := "#000000" if cursor_visible else "#00000000"
	if label is RichTextLabel:
		label.text = "%s[color=%s]|[/color]" % [safe_text, cursor_color]
	elif label is Label:
		(label as Label).text = "%s|" % visible_text


func _layout_universe_end_cursor(label: RichTextLabel, visible_text: String, cursor_visible: bool) -> void:
	if label == null or not is_instance_valid(label):
		return
	if not label.has_meta("universe_end_cursor"):
		return
	var cursor_variant = label.get_meta("universe_end_cursor")
	if cursor_variant == null or not is_instance_valid(cursor_variant):
		return
	var cursor_bar := cursor_variant as Control
	if cursor_bar == null:
		return
	var font := label.get_theme_font("normal_font")
	var font_size: int = label.get_theme_font_size("normal_font_size")
	if font_size <= 0:
		font_size = 220
	var text_width: float = 0.0
	if font != null and not visible_text.is_empty():
		text_width = font.get_string_size(visible_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x

	var cursor_width: float = max(10.0, float(font_size) * 0.055)
	var cursor_height: float = max(80.0, float(font_size) * 0.82)
	var cursor_x: float = (label.size.x + text_width) * 0.5 + max(10.0, float(font_size) * 0.04)
	var cursor_y: float = max(0.0, float(font_size) * 0.085)

	cursor_bar.size = Vector2(cursor_width, cursor_height)
	cursor_bar.position = Vector2(cursor_x, cursor_y)
	cursor_bar.modulate.a = 1.0 if cursor_visible else 0.0

func _escape_universe_end_bbcode(value: String) -> String:
	return value.replace("[", "[lb]").replace("]", "[rb]")


func _fade_universe_end_after_audio(player: AudioStreamPlayer, duration: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	var fade_duration: float = max(duration, 0.05)
	var audio_tween := create_tween()
	audio_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	audio_tween.tween_property(player, "volume_db", -60.0, fade_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


func _play_universe_end_key_sfx(parent: Node) -> void:
	if not _sfx_enabled_for_universe_end():
		return
	if parent == null or not is_instance_valid(parent):
		return
	var key_index := int(randi() % 32) + 1
	var path := "%s/keypress-%03d.mp3" % [UNIVERSE_END_KEYPRESS_SFX_DIR, key_index]
	if not ResourceLoader.exists(path):
		path = "%s/keypress-%03d.wav" % [UNIVERSE_END_KEYPRESS_SFX_DIR, key_index]
	if not ResourceLoader.exists(path):
		return
	_play_universe_end_stream(parent, path, 8.0, false, 8.0)


func _unlock_universe_end_achievement() -> void:
	var tracker := _achievement_tracker()
	if tracker == null:
		return
	if tracker.has_method("unlock"):
		tracker.call("unlock", "the_end_of_the_universe", {}, "black_white_hole_collision")




func play_logout_exit_animation(duration: float = BODY_LOGOUT_FADE_TIME) -> void:
	var active_bodies := bodies.duplicate()
	if active_bodies.is_empty():
		return

	duration = max(duration, 0.08)
	var max_wait := duration
	for i in range(active_bodies.size()):
		var body = active_bodies[i]
		if body == null or not is_instance_valid(body):
			continue
		if not (body is Node2D):
			continue
		var node_2d := body as Node2D
		var delay: float = min(float(i) * BODY_LOGOUT_STAGGER_TIME, duration * 0.28)
		max_wait = max(max_wait, delay + duration)
		var fade_tween := create_tween()
		fade_tween.set_parallel(true)
		fade_tween.set_trans(Tween.TRANS_SINE)
		fade_tween.set_ease(Tween.EASE_IN_OUT)
		if node_2d is CanvasItem:
			fade_tween.tween_property(node_2d, "modulate:a", 0.0, duration).set_delay(delay)
		_fade_body_trail_for_logout(body, duration, delay)

	await get_tree().create_timer(max_wait, false).timeout


func _fade_body_trail_for_logout(body, duration: float, delay: float) -> void:
	if body == null or not is_instance_valid(body):
		return
	var trail_line: Variant = body.get("trail_line")
	if trail_line == null or not is_instance_valid(trail_line):
		return
	if not (trail_line is CanvasItem):
		return
	var trail_item := trail_line as CanvasItem
	var trail_tween := create_tween()
	trail_tween.set_trans(Tween.TRANS_SINE)
	trail_tween.set_ease(Tween.EASE_IN_OUT)
	trail_tween.tween_property(trail_item, "modulate:a", 0.0, duration).set_delay(delay)

func clear_all() -> void:
	if _universe_end_camera_tween != null and _universe_end_camera_tween.is_valid():
		_universe_end_camera_tween.kill()
	_universe_end_camera_tween = null
	for body in bodies.duplicate():
		if is_instance_valid(body):
			body.queue_free()

	bodies.clear()
	bodies_by_card_id.clear()
	selected_body = null
	_active_screen_touches.clear()
	_clear_active_planet_pointer()

	_emit_scene_snapshot_changed()


func set_scene_objects_paused(paused: bool) -> void:
	if _scene_objects_paused == paused:
		if paused:
			set_physics_process(false)
		return

	if paused:
		_physics_requested_while_paused = simulation_enabled
		_capture_body_velocity_cache()
		set_physics_process(false)
	else:
		_restore_body_velocity_cache()

	_scene_objects_paused = paused

	for body in bodies:
		if body == null or not is_instance_valid(body):
			continue

		if body.has_method("set_scene_animation_paused"):
			body.call("set_scene_animation_paused", paused)

	if not paused:
		if _physics_requested_while_paused or simulation_enabled:
			_physics_requested_while_paused = false
			_update_physics_auto_state()
		else:
			set_physics_process(false)


func _capture_body_velocity_cache() -> void:
	_paused_body_velocity_cache.clear()
	for body in bodies:
		if body == null or not is_instance_valid(body) or body.data == null:
			continue
		_paused_body_velocity_cache[str(body.data.instance_id)] = {
			"velocity": body.data.velocity,
			"acceleration": body.data.acceleration,
			"previous_acceleration": body.data.previous_acceleration,
		}


func _restore_body_velocity_cache() -> void:
	for body in bodies:
		if body == null or not is_instance_valid(body) or body.data == null:
			continue
		var key := str(body.data.instance_id)
		if not _paused_body_velocity_cache.has(key):
			continue
		var cached: Dictionary = _paused_body_velocity_cache[key]
		var cached_velocity: Variant = cached.get("velocity", null)
		if cached_velocity is Vector2:
			var velocity_value: Vector2 = cached_velocity
			if body.data.velocity.length_squared() <= 0.0001 and velocity_value.length_squared() > 0.0001:
				body.data.velocity = velocity_value
		var cached_acceleration: Variant = cached.get("acceleration", null)
		if cached_acceleration is Vector2:
			body.data.acceleration = cached_acceleration
		var cached_previous_acceleration: Variant = cached.get("previous_acceleration", null)
		if cached_previous_acceleration is Vector2:
			body.data.previous_acceleration = cached_previous_acceleration
	_paused_body_velocity_cache.clear()


func select_body_by_instance_id(instance_id: String) -> void:
	var clean := instance_id.strip_edges()
	if clean.is_empty():
		return
	for body in bodies:
		if body == null or not is_instance_valid(body) or body.data == null:
			continue
		if str(body.data.instance_id) == clean:
			select_body(body)
			return

func select_body_by_card_id(card_id: String) -> void:
	var clean := card_id.strip_edges()
	if clean.is_empty():
		return
	if bodies_by_card_id.has(clean) and is_instance_valid(bodies_by_card_id[clean]):
		select_body(bodies_by_card_id[clean])
		return
	for body in bodies:
		if body == null or not is_instance_valid(body) or body.data == null:
			continue
		if str(body.data.source_card_id) == clean:
			select_body(body)
			return

func select_body(body) -> void:
	if body == null or not is_instance_valid(body):
		return

	selected_body = body
	planet_selected.emit(body)


func screen_to_space(screen_position: Vector2) -> Vector2:
	if follow_space_background_camera:
		_sync_to_space_background_camera()
	return get_global_transform_with_canvas().affine_inverse() * screen_position


func space_to_screen(space_position: Vector2) -> Vector2:
	if follow_space_background_camera:
		_sync_to_space_background_camera()
	return get_global_transform_with_canvas() * space_position


func enable_physics() -> void:
	if _scene_objects_paused:
		simulation_enabled = true
		_physics_requested_while_paused = true
		set_physics_process(false)
		return

	var active_count := 0

	for body in bodies:
		if body == null or not is_instance_valid(body):
			continue

		if body.data == null:
			continue

		if _crashing_body_ids.has(int(body.get_instance_id())):
			continue

		active_count += 1

	if active_count < 1:
		simulation_enabled = false
		set_physics_process(false)
		return

	simulation_enabled = true
	set_physics_process(true)


func disable_physics() -> void:
	_physics_requested_while_paused = false
	simulation_enabled = false
	set_physics_process(false)


func toggle_physics() -> void:
	if simulation_enabled:
		disable_physics()
	else:
		enable_physics()


func _update_physics_auto_state() -> void:
	var active_count := 0

	for body in bodies:
		if body == null or not is_instance_valid(body):
			continue

		if body.data == null:
			continue

		if _crashing_body_ids.has(int(body.get_instance_id())):
			continue

		active_count += 1

	if active_count >= 1:
		enable_physics()
	else:
		disable_physics()


func make_body_orbit_nearest(body, clockwise: bool = true, preserve_existing_orbit: bool = true, instant_velocity: bool = false) -> bool:
	if body == null or not is_instance_valid(body):
		return false

	if body.data == null or config == null:
		return false

	var parent = null
	var radius_override := -1.0

	if preserve_existing_orbit and not str(body.data.orbit_parent_id).strip_edges().is_empty() and body.data.orbit_radius > 0.0:
		parent = _find_body_by_instance_id(str(body.data.orbit_parent_id))
		if parent != null and is_instance_valid(parent) and parent.data != null:
			var current_target_radius := _preferred_orbit_radius_for_slot(body, parent, _orbit_slot_for_parent(parent, body))
			var stored_slider := float(body.data.metadata.get("stable_orbit_radius_multiplier_used", -1.0))
			var current_slider := _stable_radius_multiplier_local()
			if stored_slider >= 0.0 and not is_equal_approx(stored_slider, current_slider):
				radius_override = current_target_radius
			else:
				radius_override = max(body.data.orbit_radius, _minimum_visible_orbit_radius(body, parent))

	if parent == null:
		parent = _find_best_orbit_parent(body)

	if parent == null:
		return false

	if radius_override <= 0.0:
		radius_override = _preferred_orbit_radius_for_slot(body, parent, _orbit_slot_for_parent(parent, body))

	var result := _prepare_soft_circular_orbit_local(body, parent, clockwise, radius_override, not instant_velocity)
	if result and body.data != null:
		body.data.metadata["stable_orbit_soft_recover"] = true
		body.data.metadata["stable_orbit_radius_multiplier_used"] = _stable_radius_multiplier_local()
		body.data.metadata.erase("orbit_architecture_dirty")
		if _is_black_hole_body(parent):
			body.data.orbit_locked = false
			body.data.metadata["black_hole_unstable_orbit"] = true
		else:
			body.data.orbit_locked = bool(config.stable_orbit_mode)
		if body.has_method("sync_from_data"):
			body.call("sync_from_data")
	return result



func _config_float_value(property_name: String, fallback: float) -> float:
	if config == null:
		return fallback
	if config.has_method("has_config_property") and not bool(config.call("has_config_property", property_name)):
		return fallback
	var value: Variant = config.get(property_name)
	if value == null:
		return fallback
	return float(value)


func _config_bool_value(property_name: String, fallback: bool) -> bool:
	if config == null:
		return fallback
	if config.has_method("has_config_property") and not bool(config.call("has_config_property", property_name)):
		return fallback
	var value: Variant = config.get(property_name)
	if value == null:
		return fallback
	return bool(value)


func _stable_radius_multiplier_local() -> float:
	return clamp(_config_float_value("stable_orbit_radius_multiplier", 1.0), 0.1, 1.0)


func _orbit_spacing_multiplier_local() -> float:
	return clamp(_config_float_value("orbit_spacing_multiplier", 1.0), 0.1, 1.0)


func _minimum_orbit_radius_local(body_data: SimulationPlanetData, parent_data: SimulationPlanetData) -> float:
	if body_data == null or parent_data == null or config == null:
		return 120.0
	var body_clearance: float = max(body_data.radius_world, body_data.get_collision_radius(config))
	var parent_clearance: float = max(parent_data.radius_world, parent_data.get_collision_radius(config))
	if parent_data.metadata.has("binary_partner_id") and parent_data.orbit_radius > 0.0 and not _is_moon_data(body_data) and not _is_star_data(parent_data):
		parent_clearance = max(parent_clearance, parent_data.orbit_radius + parent_data.get_collision_radius(config))
	var padding: float = max(22.0, _config_float_value("orbit_distance_padding", 86.0) * 0.18)
	if _is_moon_data(body_data):
		padding = max(18.0, _config_float_value("orbit_distance_padding", 86.0) * 0.13 * _orbit_spacing_multiplier_local())
	elif _is_star_data(body_data) and _is_star_data(parent_data):
		padding = max(32.0, _config_float_value("orbit_distance_padding", 86.0) * 0.22)
	return max(12.0, parent_clearance + body_clearance + padding)


func _normal_orbit_radius_local(body_data: SimulationPlanetData, parent_data: SimulationPlanetData) -> float:
	if body_data == null or parent_data == null or config == null:
		return 120.0
	var padding := _config_float_value("orbit_distance_padding", 86.0)
	var clearance: float = parent_data.radius_world + body_data.radius_world + padding * 1.32
	if _is_moon_data(body_data):
		clearance = parent_data.radius_world + body_data.radius_world + padding * 0.86 * _orbit_spacing_multiplier_local()
	elif _is_star_data(body_data) and _is_star_data(parent_data):
		clearance = parent_data.radius_world + body_data.radius_world + padding * 1.64
	return max(_config_float_value("min_visible_orbit_radius", 120.0), clearance)


func _preferred_orbit_radius_local(body_data: SimulationPlanetData, parent_data: SimulationPlanetData, slot: int = 0) -> float:
	if body_data == null or parent_data == null or config == null:
		return 120.0
	var min_radius := _minimum_orbit_radius_local(body_data, parent_data)
	var max_radius = max(min_radius, _normal_orbit_radius_local(body_data, parent_data))
	var radius_bonus := sqrt(max(body_data.radius_world, 8.0)) * 16.0
	var mass_bonus := pow(max(body_data.mass, 0.01), 0.30) * 30.0
	var parent_bonus := pow(max(parent_data.mass * abs(parent_data.gravitational_influence), 0.01), 0.16) * 18.0
	var kind_multiplier := 1.0
	if _is_moon_data(body_data):
		kind_multiplier = 0.48 * max(_orbit_spacing_multiplier_local(), 0.1)
	elif _is_star_data(body_data) and _is_star_data(parent_data):
		kind_multiplier = 1.62
	elif _is_planet_data(body_data):
		kind_multiplier = 1.06
	max_radius += (radius_bonus + mass_bonus + parent_bonus) * kind_multiplier
	if slot > 0:
		var compact_gap := _compact_orbit_lane_gap_for_data(body_data, parent_data)
		var normal_gap := _normal_orbit_lane_gap_for_data(body_data, parent_data)
		min_radius += float(slot) * compact_gap
		max_radius += float(slot) * normal_gap
	var slider := _stable_radius_multiplier_local()
	var t = clamp((slider - 0.1) / 0.9, 0.0, 1.0)
	return lerp(max(min_radius, 1.0), max(max_radius, min_radius), t)

func _compact_orbit_lane_gap_for_data(body_data: SimulationPlanetData, existing_data: SimulationPlanetData) -> float:
	if body_data == null or existing_data == null or config == null:
		return 120.0
	var body_clearance = max(body_data.radius_world, body_data.get_collision_radius(config))
	var existing_clearance = max(existing_data.radius_world, existing_data.get_collision_radius(config))
	var padding := _config_float_value("orbit_distance_padding", 86.0)
	var spacing = max(_orbit_spacing_multiplier_local(), 0.1)
	var gap = body_clearance + existing_clearance + max(56.0, padding * 0.82)
	if _is_planet_data(body_data) and _is_planet_data(existing_data):
		gap = max(gap, body_clearance + existing_clearance + max(140.0, padding * 1.95))
	elif _is_moon_data(body_data) or _is_moon_data(existing_data):
		gap = max(gap, body_clearance + existing_clearance + max(72.0, padding * 0.92) * spacing)
	elif _is_star_data(body_data) or _is_star_data(existing_data):
		gap = max(gap, body_clearance + existing_clearance + max(180.0, padding * 2.25))
	return max(96.0, gap)

func _normal_orbit_lane_gap_for_data(body_data: SimulationPlanetData, existing_data: SimulationPlanetData) -> float:
	if body_data == null or existing_data == null or config == null:
		return 160.0
	var compact := _compact_orbit_lane_gap_for_data(body_data, existing_data)
	var min_visible := _config_float_value("min_visible_orbit_radius", 120.0)
	var padding := _config_float_value("orbit_distance_padding", 86.0)
	var spacing = max(_orbit_spacing_multiplier_local(), 0.1)
	var wide = compact + max(max(min_visible * 1.08, padding * 1.32), 118.0)
	if _is_planet_data(body_data) and _is_planet_data(existing_data):
		wide = compact + max(max(min_visible * 1.42, padding * 2.10), 190.0)
	elif _is_moon_data(body_data) or _is_moon_data(existing_data):
		wide = compact + max(max(min_visible * 0.82, padding * 0.95), 86.0) * spacing
	elif _is_star_data(body_data) or _is_star_data(existing_data):
		wide = compact + max(max(min_visible * 1.65, padding * 2.60), 240.0)
	return max(compact, wide)


func _prepare_soft_circular_orbit_local(body, parent, clockwise: bool = true, radius_override: float = -1.0, blend_velocity: bool = true) -> bool:
	if body == null or parent == null or not is_instance_valid(body) or not is_instance_valid(parent):
		return false
	if body.data == null or parent.data == null or config == null:
		return false
	var d: SimulationPlanetData = body.data
	var h: SimulationPlanetData = parent.data
	var offset: Vector2 = d.position - h.position
	var radius: float = radius_override if radius_override > 0.0 else offset.length()
	radius = max(radius, _minimum_orbit_radius_local(d, h))
	if offset.length_squared() < 0.001:
		offset = Vector2.RIGHT.rotated(float(abs(hash(d.instance_id)) % 6283) / 1000.0) * radius
	var radial_dir := offset.normalized()
	if radial_dir.length_squared() < 0.001:
		radial_dir = Vector2.RIGHT
	# Do not move the body here. This function only reserves the target orbit and
	# seeds the direction/velocity. The gravity solver moves it out from the spawn
	# point smoothly, so moons and stacked planets never teleport into place.
	d.metadata["soft_orbit_radial_dir"] = radial_dir
	var tangent := Vector2(-radial_dir.y, radial_dir.x)
	if clockwise:
		tangent *= -1.0
	var orbit_multiplier: float = config.get_orbit_speed_multiplier() if config.has_method("get_orbit_speed_multiplier") else clamp(_config_float_value("revolution_speed_multiplier", 1.0), 0.05, 32.0)
	var speed := sqrt(max(_config_float_value("gravitational_constant", 1.0) * max(h.mass * abs(h.gravitational_influence), 0.001) / max(radius, 1.0), 0.0)) * orbit_multiplier
	var target_velocity: Vector2 = h.velocity + tangent * min(speed, max(d.max_orbit_speed * 4.0, 80.0))
	d.orbit_parent_id = h.instance_id
	d.orbit_radius = radius
	d.orbit_clockwise = clockwise
	d.orbit_eccentricity = 0.0
	d.orbit_locked = bool(_config_bool_value("stable_orbit_mode", true))
	d.metadata["stable_orbit_soft_recover"] = true
	d.metadata["collision_protected_until_ms"] = Time.get_ticks_msec() + 4200
	d.metadata.erase("orbit_architecture_dirty")
	d.velocity = d.velocity.lerp(target_velocity, 0.18) if blend_velocity else target_velocity
	if body.has_method("sync_from_data"):
		body.call("sync_from_data")
	return true


func _is_star_data(d: SimulationPlanetData) -> bool:
	return d != null and int(d.body_kind) in [SimulationPlanetData.BodyKind.STAR, SimulationPlanetData.BodyKind.BLACK_HOLE, SimulationPlanetData.BodyKind.WHITE_HOLE, SimulationPlanetData.BodyKind.GALAXY]


func _is_planet_data(d: SimulationPlanetData) -> bool:
	return d != null and int(d.body_kind) in [SimulationPlanetData.BodyKind.PLANET, SimulationPlanetData.BodyKind.RINGED_PLANET]


func _is_moon_data(d: SimulationPlanetData) -> bool:
	return d != null and int(d.body_kind) in [SimulationPlanetData.BodyKind.MOON, SimulationPlanetData.BodyKind.SATELLITE]


func _preferred_orbit_radius_for_slot(body, parent, slot: int = 0) -> float:
	if body == null or parent == null or not is_instance_valid(body) or not is_instance_valid(parent):
		return 120.0
	if body.data == null or parent.data == null or config == null:
		return 120.0
	return _preferred_orbit_radius_local(body.data, parent.data, slot)


func _orbit_slot_for_parent(parent, ignored_body = null) -> int:
	if parent == null or not is_instance_valid(parent) or parent.data == null:
		return 0
	var parent_id := str(parent.data.instance_id)
	var slot := 0
	for candidate in bodies:
		if candidate == ignored_body or candidate == null or not is_instance_valid(candidate) or candidate.data == null:
			continue
		if str(candidate.data.orbit_parent_id) == parent_id:
			slot += 1
	return slot


func _find_body_by_instance_id(instance_id: String):
	var clean := instance_id.strip_edges()
	if clean.is_empty():
		return null
	for candidate in bodies:
		if candidate == null or not is_instance_valid(candidate) or candidate.data == null:
			continue
		if str(candidate.data.instance_id) == clean:
			return candidate
	return null


func _find_best_orbit_parent(body):
	if body == null or body.data == null:
		return null

	var body_kind: int = int(body.data.body_kind)
	var best = null
	var best_score := INF

	for candidate in bodies:
		if candidate == body:
			continue

		if candidate == null or not is_instance_valid(candidate) or candidate.data == null:
			continue

		if _crashing_body_ids.has(int(candidate.get_instance_id())):
			continue

		var candidate_kind: int = int(candidate.data.body_kind)
		var allowed := false
		var score_bias := 1.0

		if body_kind == SimulationPlanetData.BodyKind.MOON or body_kind == SimulationPlanetData.BodyKind.SATELLITE:
			if candidate_kind == SimulationPlanetData.BodyKind.PLANET or candidate_kind == SimulationPlanetData.BodyKind.RINGED_PLANET:
				allowed = true
				score_bias = 1.0
			elif candidate_kind == SimulationPlanetData.BodyKind.MOON or candidate_kind == SimulationPlanetData.BodyKind.SATELLITE:
				allowed = true
				score_bias = 1.8
		elif body_kind == SimulationPlanetData.BodyKind.PLANET or body_kind == SimulationPlanetData.BodyKind.RINGED_PLANET:
			if candidate_kind == SimulationPlanetData.BodyKind.STAR or candidate_kind == SimulationPlanetData.BodyKind.BLACK_HOLE or candidate_kind == SimulationPlanetData.BodyKind.GALAXY:
				allowed = true
				score_bias = 1.0
		elif body_kind == SimulationPlanetData.BodyKind.STAR or body_kind == SimulationPlanetData.BodyKind.BLACK_HOLE or body_kind == SimulationPlanetData.BodyKind.GALAXY:
			if candidate.data.mass > body.data.mass:
				allowed = true
				score_bias = 1.0

		if not allowed:
			if candidate.data.mass <= body.data.mass:
				continue
			allowed = true
			score_bias = 2.8

		var dist: float = body.data.position.distance_to(candidate.data.position)
		if dist <= 0.001:
			continue

		var score: float = dist * score_bias
		if not _is_moon_body(body):
			score = score / max(candidate.data.mass, 0.001)

		if score < best_score:
			best_score = score
			best = candidate

	return best


func _is_moon_body(body) -> bool:
	return body != null and body.data != null and (body.data.body_kind == SimulationPlanetData.BodyKind.MOON or body.data.body_kind == SimulationPlanetData.BodyKind.SATELLITE)


func _is_binary_body(body) -> bool:
	if body == null or body.data == null:
		return false
	return str(body.data.metadata.get("binary_partner_id", "")).strip_edges() != ""


func _connect_body(body) -> void:
	if body == null:
		return

	if body.has_signal("tapped"):
		var tapped_callable := Callable(self, "_on_body_tapped")

		if not body.is_connected("tapped", tapped_callable):
			body.connect("tapped", tapped_callable)

	if body.has_signal("pressed"):
		var pressed_callable := Callable(self, "_on_body_pressed")

		if not body.is_connected("pressed", pressed_callable):
			body.connect("pressed", pressed_callable)

	if body.has_signal("drag_started"):
		var drag_started_callable := Callable(self, "_on_body_drag_started")

		if not body.is_connected("drag_started", drag_started_callable):
			body.connect("drag_started", drag_started_callable)

	if body.has_signal("drag_finished"):
		var drag_finished_callable := Callable(self, "_on_body_drag_finished")

		if not body.is_connected("drag_finished", drag_finished_callable):
			body.connect("drag_finished", drag_finished_callable)


func _on_body_pressed(body) -> void:
	if body == null or not is_instance_valid(body):
		return

	select_body(body)
	_play_planet_sfx(planet_click_sfx_id)


func _on_body_tapped(body) -> void:
	if body == null or not is_instance_valid(body):
		return

	select_body(body)
	_play_planet_sfx(planet_open_sfx_id)

	if body.data != null and body.data.source_planet_data != null:
		planet_card_open_requested.emit(body.data.source_planet_data)


func _on_body_drag_started(body) -> void:
	if body == null or not is_instance_valid(body):
		return

	if body.data != null:
		body.data.metadata["velocity_before_manual_drag"] = body.data.velocity
	select_body(body)


func _on_body_drag_finished(body, release_velocity: Vector2) -> void:
	if body == null or not is_instance_valid(body):
		return

	if body.data == null:
		return

	_clear_active_planet_pointer()
	_play_planet_sfx(planet_release_sfx_id)

	body.data.is_dragging = false
	body.data.metadata.erase("crashing_out")

	var previous_velocity: Variant = body.data.metadata.get("velocity_before_manual_drag", null)
	body.data.metadata.erase("velocity_before_manual_drag")
	var preserved_velocity: Vector2 = body.data.velocity
	if previous_velocity is Vector2:
		preserved_velocity = previous_velocity
	if config != null:
		if config.hand_throw_enabled:
			var thrown_velocity := _capped_drag_throw_velocity(release_velocity)
			# A body that is moved and then held still before release should stay still.
			# Previously a stale drag sample could produce a throw, or a zero throw
			# could restore the old orbital velocity, which felt like a fake fling.
			body.data.velocity = thrown_velocity if thrown_velocity.length_squared() > 0.0001 else Vector2.ZERO
		else:
			body.data.velocity = preserved_velocity
	else:
		body.data.velocity = release_velocity.limit_length(420.0)

	if bool(body.data.metadata.get("pending_rebuild_visual_after_drag_release", false)) and body.has_method("rebuild_visual"):
		body.data.metadata.erase("pending_rebuild_visual_after_drag_release")
		body.call_deferred("rebuild_visual")

	if config != null and config.auto_orbit_enabled and config.stable_orbit_mode:
		make_body_orbit_nearest(body, true, true)

	_emit_scene_snapshot_changed()


func _capped_drag_throw_velocity(release_velocity: Vector2) -> Vector2:
	var zoom_compensation := _current_throw_zoom_compensation()

	# Dead-zone tiny/stale releases. SimulationPlanetBody already sends ZERO
	# after the finger is held still, but this keeps the playground safe too.
	if release_velocity.length() < 65.0:
		return Vector2.ZERO

	if config == null:
		return release_velocity.limit_length(420.0 * zoom_compensation)

	var throw_strength: float = clamp(config.drag_throw_strength, 0.0, 1.0)
	if throw_strength <= 0.001:
		return Vector2.ZERO

	# release_velocity is already measured in universe/world space by SimulationPlanetBody,
	# but the safety cap used to be fixed. That made throws feel weak when zoomed out
	# and too aggressive when zoomed in. Scale the cap by camera zoom so the same
	# hand gesture keeps the same visual feel across zoom levels.
	var throw_velocity: Vector2 = release_velocity * throw_strength
	var cap: float = float(config.max_drag_throw_speed) if config != null else DRAG_THROW_SPEED_CAP
	if cap <= 0.0:
		return Vector2.ZERO
	return throw_velocity.limit_length(cap * zoom_compensation)


func _current_throw_zoom_compensation() -> float:
	if _space_background_ref == null or not is_instance_valid(_space_background_ref):
		_cache_space_background()
	var camera_zoom := _get_space_background_float("space_zoom", scale.x if abs(scale.x) > 0.001 else 1.0)
	return 1.0 / max(abs(camera_zoom), 0.001)


func _apply_selected_body_mass_multiplier(multiplier: float) -> void:
	if selected_body == null or not is_instance_valid(selected_body) or selected_body.data == null:
		return
	var d: SimulationPlanetData = selected_body.data
	if not d.metadata.has("base_mass_for_tuning"):
		d.metadata["base_mass_for_tuning"] = max(d.mass, 0.001)
	var base_mass := float(d.metadata.get("base_mass_for_tuning", d.mass))
	d.mass = max(base_mass * clamp(multiplier, 0.1, 8.0), 0.001)
	_update_selected_body_evolution()
	if selected_body.has_method("sync_from_data"):
		selected_body.call("sync_from_data")
	_refresh_orbit_runtime_flags()
	_emit_scene_snapshot_changed()


func _apply_selected_body_gravity_multiplier(multiplier: float) -> void:
	if selected_body == null or not is_instance_valid(selected_body) or selected_body.data == null:
		return
	var d: SimulationPlanetData = selected_body.data
	if not d.metadata.has("base_gravity_for_tuning"):
		d.metadata["base_gravity_for_tuning"] = max(abs(d.gravitational_influence), 0.001)
	var base_gravity := float(d.metadata.get("base_gravity_for_tuning", d.gravitational_influence))
	d.gravitational_influence = max(base_gravity * clamp(multiplier, 0.0, 8.0), 0.0)
	_update_selected_body_evolution()
	if selected_body.has_method("sync_from_data"):
		selected_body.call("sync_from_data")
	_refresh_orbit_runtime_flags()
	_emit_scene_snapshot_changed()


func _apply_selected_body_size_multiplier(multiplier: float) -> void:
	if selected_body == null or not is_instance_valid(selected_body) or selected_body.data == null:
		return
	var d: SimulationPlanetData = selected_body.data
	if not d.metadata.has("base_radius_for_tuning"):
		d.metadata["base_radius_for_tuning"] = max(float(d.radius_world), 8.0)
	var base_radius := float(d.metadata.get("base_radius_for_tuning", d.radius_world))
	d.radius_world = max(base_radius * clamp(multiplier, 0.25, 4.0), 8.0)
	d.visual_radius_px = int(max(d.visual_radius_px, d.radius_world))
	_update_selected_body_evolution()
	if selected_body.has_method("_apply_visual_radius"):
		selected_body.call("_apply_visual_radius", d.radius_world, -1.0, false)
	elif selected_body.has_method("rebuild_visual"):
		selected_body.call("rebuild_visual")
	_refresh_orbit_runtime_flags()
	_emit_scene_snapshot_changed()


func _update_selected_body_evolution() -> void:
	if selected_body == null or not is_instance_valid(selected_body) or selected_body.data == null:
		return

	var d: SimulationPlanetData = selected_body.data
	if d.source_planet_data == null:
		return

	var before_kind := int(d.body_kind)
	var before_preset := str(d.source_planet_data.planet_preset)
	var before_category := str(d.source_planet_data.object_category)
	var before_archetype := str(d.source_planet_data.archetype_id)

	# Reuse the exact same evolution chain used by collisions, so mass-only tuning
	# can promote the selected body through moon/rocky/gas/ringed/brown-dwarf/star/black-hole stages.
	COLLISION_SOLVER._apply_collision_evolution(d, null)

	var after_preset := str(d.source_planet_data.planet_preset)
	var after_category := str(d.source_planet_data.object_category)
	var after_archetype := str(d.source_planet_data.archetype_id)
	var changed := (
		before_kind != int(d.body_kind)
		or before_preset != after_preset
		or before_category != after_category
		or before_archetype != after_archetype
	)

	if changed and selected_body.has_method("rebuild_visual"):
		selected_body.call("rebuild_visual")
	_apply_body_layer(selected_body)

func _play_planet_tap_sfx() -> void:
	_play_planet_sfx(planet_click_sfx_id)


func _play_planet_sfx(id: String) -> void:
	var clean_id := id.strip_edges()

	if clean_id.is_empty():
		return

	var now := Time.get_ticks_usec()

	if now - _last_planet_tap_sfx_usec < 70000:
		return

	_last_planet_tap_sfx_usec = now

	if has_node("/root/UnilearnUserSettings"):
		var settings := get_node("/root/UnilearnUserSettings")
		if settings != null and settings.get("sfx_enabled") == false:
			return

	var sfx := get_node_or_null("/root/UnilearnSFX")

	if sfx == null:
		return

	if sfx.has_method("play"):
		sfx.call("play", clean_id, 0.94, 1.08)


func _emit_scene_snapshot_changed() -> void:
	_last_snapshot = get_added_planets_snapshot()
	scene_planets_changed.emit(_last_snapshot)


func _cache_space_background() -> void:
	_space_background_ref = get_node_or_null(space_background_path)


func _sync_to_space_background_camera() -> void:
	if _space_background_ref == null or not is_instance_valid(_space_background_ref):
		_cache_space_background()

	if _space_background_ref == null:
		var fallback_center := get_viewport_rect().size * 0.5

		if position == fallback_center \
		and is_equal_approx(rotation, 0.0) \
		and scale == Vector2.ONE:
			return

		position = fallback_center
		rotation = 0.0
		scale = Vector2.ONE
		return

	var viewport_center := get_viewport_rect().size * 0.5

	var camera_position := _get_space_background_vector("space_position", Vector2.ZERO)
	var camera_zoom := _get_space_background_float("space_zoom", 1.0)
	var camera_rotation := _get_space_background_float("space_rotation", 0.0)

	camera_zoom = max(camera_zoom, 0.001)

	if camera_position == _last_camera_position \
	and is_equal_approx(camera_zoom, _last_camera_zoom) \
	and is_equal_approx(camera_rotation, _last_camera_rotation) \
	and viewport_center == _last_viewport_center:
		return

	_last_camera_position = camera_position
	_last_camera_zoom = camera_zoom
	_last_camera_rotation = camera_rotation
	_last_viewport_center = viewport_center

	rotation = camera_rotation
	scale = Vector2.ONE * camera_zoom
	position = viewport_center - camera_position.rotated(camera_rotation) * camera_zoom


func _apply_body_layer(body) -> void:
	if body == null or not is_instance_valid(body):
		return

	if not (body is CanvasItem):
		return

	var canvas_item := body as CanvasItem
	canvas_item.z_as_relative = false

	if _is_black_hole_body(body) or _is_white_hole_body(body):
		canvas_item.z_index = LAYER_BLACK_HOLE
		return
	if body.data != null and int(body.data.body_kind) == SimulationPlanetData.BodyKind.STAR:
		canvas_item.z_index = LAYER_STAR
		return
	if body.data != null and (int(body.data.body_kind) == SimulationPlanetData.BodyKind.MOON or int(body.data.body_kind) == SimulationPlanetData.BodyKind.SATELLITE):
		canvas_item.z_index = LAYER_MOON
		return

	var category := ""
	var preset := ""

	if body.data != null and body.data.source_planet_data != null:
		category = body.data.source_planet_data.object_category.strip_edges().to_lower().replace(" ", "_")
		preset = body.data.source_planet_data.planet_preset.strip_edges().to_lower().replace(" ", "_")

	match category:
		"moon", "satellite":
			canvas_item.z_index = LAYER_MOON
			return

		"planet", "dwarf_planet", "gas_giant", "terrestrial_planet", "rocky_planet":
			canvas_item.z_index = LAYER_PLANET
			return

		"star", "sun":
			canvas_item.z_index = LAYER_STAR
			return

		"black_hole", "blackhole", "white_hole", "whitehole":
			canvas_item.z_index = LAYER_BLACK_HOLE
			return

	if preset == "star":
		canvas_item.z_index = LAYER_STAR
	elif preset == "black_hole" or preset == "white_hole":
		canvas_item.z_index = LAYER_BLACK_HOLE
	elif preset == "moon":
		canvas_item.z_index = LAYER_MOON
	else:
		canvas_item.z_index = LAYER_PLANET


func _get_space_background_vector(property_name: String, fallback: Vector2) -> Vector2:
	if _space_background_ref == null:
		return fallback

	var value = _space_background_ref.get(property_name)

	if value is Vector2:
		return value

	return fallback


func _get_space_background_float(property_name: String, fallback: float) -> float:
	if _space_background_ref == null:
		return fallback

	var value = _space_background_ref.get(property_name)

	if value == null:
		return fallback

	return float(value)


func _card_key(planet_data: PlanetData) -> String:
	if planet_data == null:
		return ""

	var id := ""

	if "instance_id" in planet_data:
		id = str(planet_data.instance_id).strip_edges()

	if id.is_empty() and "archetype_id" in planet_data:
		id = str(planet_data.archetype_id).strip_edges()

	if id.is_empty():
		id = str(planet_data.name).strip_edges().to_lower().replace(" ", "_")

	return id


func _safe_node_name(value: String) -> String:
	var clean := value.strip_edges()

	if clean.is_empty():
		clean = "Planet"

	clean = clean.replace(" ", "_")
	clean = clean.replace("/", "_")
	clean = clean.replace("\\", "_")
	clean = clean.replace(":", "_")
	clean = clean.replace("*", "_")
	clean = clean.replace("?", "_")
	clean = clean.replace("\"", "_")
	clean = clean.replace("<", "_")
	clean = clean.replace(">", "_")
	clean = clean.replace("|", "_")

	return clean


func _orbit_parent_is_white_hole(body) -> bool:
	if body == null or not is_instance_valid(body) or body.data == null:
		return false
	var parent_id := str(body.data.orbit_parent_id)
	if parent_id.is_empty():
		return false
	for candidate in bodies:
		if candidate != null and is_instance_valid(candidate) and candidate.data != null and candidate.data.instance_id == parent_id:
			return _is_white_hole_body(candidate)
	return false

func _orbit_parent_is_black_hole(body) -> bool:
	if body == null or not is_instance_valid(body) or body.data == null:
		return false
	var parent_id := str(body.data.orbit_parent_id)
	if parent_id.is_empty():
		return false
	for candidate in bodies:
		if candidate != null and is_instance_valid(candidate) and candidate.data != null and candidate.data.instance_id == parent_id:
			return _is_black_hole_body(candidate)
	return false

func _is_black_hole_body(body) -> bool:
	if body == null or not is_instance_valid(body) or body.data == null:
		return false
	if int(body.data.body_kind) == 4:
		return true
	var planet_data = body.data.source_planet_data
	if planet_data == null:
		return false
	var category := str(planet_data.object_category).strip_edges().to_lower()
	var archetype := str(planet_data.archetype_id).strip_edges().to_lower()
	var preset := str(planet_data.planet_preset).strip_edges().to_lower()
	return category == "black_hole" or archetype == "black_hole" or preset == "black_hole" or (category == "singularity" and preset == "black_hole")

func _is_white_hole_body(body) -> bool:
	if body == null or not is_instance_valid(body) or body.data == null:
		return false
	if int(body.data.body_kind) == 8:
		return true
	var planet_data = body.data.source_planet_data
	if planet_data == null:
		return false
	var category := str(planet_data.object_category).strip_edges().to_lower()
	var archetype := str(planet_data.archetype_id).strip_edges().to_lower()
	var preset := str(planet_data.planet_preset).strip_edges().to_lower()
	return category == "white_hole" or archetype == "white_hole" or preset == "white_hole"
