extends Node2D
class_name UniversePlayground

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
var _crashing_body_ids: Dictionary = {}
var _last_physics_delta: float = 1.0 / 60.0


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

	if config.collisions_enabled:
		var collision_bodies := _get_collision_active_bodies()
		var removed := COLLISION_SOLVER.solve(collision_bodies, config)

		if not removed.is_empty():
			_refresh_merge_survivor_visuals()
			_mark_orbit_architecture_dirty_after_collision()

		for body in removed:
			if body != null and is_instance_valid(body) and body.data != null:
				_begin_crashed_body_removal(body)

		if not removed.is_empty():
			_rebuild_orbit_architecture_after_collision()


func set_simulation_config(next_config: SimulationPhysicsConfig, rebuild_orbits: bool = false) -> void:
	if next_config == null:
		return

	config = next_config
	_apply_config_side_effects("", null, rebuild_orbits)
	_update_physics_auto_state()


func apply_config_value(property_name: String, value) -> void:
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

	match property_name:
		"trails_enabled":
			_refresh_trail_visibility()
		"max_trail_points", "trail_sample_distance":
			_trim_trails_to_config()
		"simulation_speed", "revolution_speed_multiplier", "orbit_lock_strength", "orbit_distance_padding", "orbit_spacing_multiplier", "moon_orbit_spacing_multiplier", "binary_orbit_spacing_multiplier", "binary_max_distance_multiplier", "stable_orbit_mode", "center_largest_body", "lock_planets_to_largest_body", "hierarchical_orbits_enabled", "binary_orbits_enabled", "same_type_binary_enabled":
			_refresh_orbit_runtime_flags()

	if force_rebuild_orbits:
		reset_orbits()


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
		if parent != null and parent.data != null:
			body.data.orbit_parent_id = parent.data.instance_id
			body.data.orbit_radius = _minimum_visible_orbit_radius(body, parent)

		body.data.orbit_locked = bool(config.lock_planets_to_largest_body or _is_moon_body(body) or _is_binary_body(body))


func _refresh_trail_visibility() -> void:
	var visible := config == null or bool(config.trails_enabled)

	for body in bodies:
		if body == null or not is_instance_valid(body):
			continue

		var trail_line: Variant = body.get("trail_line")
		if trail_line != null and is_instance_valid(trail_line) and trail_line is CanvasItem:
			trail_line.visible = visible


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

		var radius: float = max(body.data.position.distance_to(parent.data.position), _minimum_visible_orbit_radius(body, parent))
		ORBIT_UTILS.make_circular_orbit(body, parent, config, body.data.orbit_clockwise, radius, true)
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
	return ORBIT_UTILS.minimum_orbit_radius(body.data, parent.data, config)

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

	var body = SIMULATION_FACTORY.create_body_from_planet_data(planet_data, space_position)

	if body == null:
		push_error("UniversePlayground: failed to create simulation body for %s." % planet_data.name)
		return null

	body.name = "Sim_%s" % _safe_node_name(planet_data.name)

	if body.data != null:
		body.data.source_card_id = card_id
		body.data.source_planet_data = planet_data
		body.data.position = space_position
		body.data.previous_position = space_position
		body.data.velocity = Vector2.ZERO
		body.data.acceleration = Vector2.ZERO

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

	if bodies.size() >= 2 and config != null and config.auto_orbit_enabled and config.stable_orbit_mode:
		make_body_orbit_nearest(body, true)

	if bodies.size() >= 2 and config != null:
		GRAVITY_SOLVER.prime_orbit_architecture(bodies, config, true)

	_refresh_orbit_runtime_flags()
	_refresh_trail_visibility()
	_update_physics_auto_state()

	_emit_scene_snapshot_changed()
	planet_added.emit(body)

	return body



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


func _mark_orbit_architecture_dirty_after_collision() -> void:
	if config == null:
		return

	GRAVITY_SOLVER.mark_orbit_architecture_dirty(bodies, true)
	return

	for body in bodies:
		if body == null or not is_instance_valid(body) or body.data == null:
			continue

		body.data.metadata["orbit_architecture_dirty"] = true
		body.data.metadata.erase("binary_partner_id")
		body.data.metadata.erase("binary_center_locked")
		body.data.is_static_anchor = false
		body.data.orbit_locked = false


func _rebuild_orbit_architecture_after_collision() -> void:
	if config == null:
		return

	await get_tree().process_frame

	if config == null or bodies.size() < 2:
		return

	GRAVITY_SOLVER.prime_orbit_architecture(_get_collision_active_bodies(), config, true)
	_refresh_orbit_runtime_flags()
	_emit_scene_snapshot_changed()


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
			"object_category": source.object_category if source != null else ""
		})

	return snapshot


func restore_added_planets(saved_bodies: Array, available_cards: Array) -> void:
	clear_all()

	if saved_bodies.is_empty():
		return

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
		var position := _read_vector2_from_dictionary(body_data, "position", Vector2.ZERO)

		var body = add_planet_card(planet_data, position)

		if body == null or not is_instance_valid(body):
			continue

		if body.data == null:
			continue

		body.data.position = position
		body.data.previous_position = position
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


func clear_all() -> void:
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
	_scene_objects_paused = paused

	for body in bodies:
		if body == null or not is_instance_valid(body):
			continue

		if body.has_method("set_scene_animation_paused"):
			body.call("set_scene_animation_paused", paused)


func select_body(body) -> void:
	if body == null or not is_instance_valid(body):
		return

	selected_body = body
	planet_selected.emit(body)


func screen_to_space(screen_position: Vector2) -> Vector2:
	return get_global_transform_with_canvas().affine_inverse() * screen_position


func space_to_screen(space_position: Vector2) -> Vector2:
	return get_global_transform_with_canvas() * space_position


func enable_physics() -> void:
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


func make_body_orbit_nearest(body, clockwise: bool = true) -> bool:
	if body == null or not is_instance_valid(body):
		return false

	var parent = _find_best_orbit_parent(body)

	if parent == null:
		return false

	return ORBIT_UTILS.prepare_soft_circular_orbit(body, parent, config, clockwise, _minimum_visible_orbit_radius(body, parent), true)


func _find_best_orbit_parent(body):
	if body == null or body.data == null:
		return null

	var best = null
	var best_score := INF

	for candidate in bodies:
		if candidate == body:
			continue

		if candidate == null or not is_instance_valid(candidate) or candidate.data == null:
			continue

		if _crashing_body_ids.has(int(candidate.get_instance_id())):
			continue

		if candidate.data.mass <= body.data.mass:
			continue

		var dist: float = body.data.position.distance_to(candidate.data.position)

		if dist <= 0.001:
			continue

		var score: float = dist / max(candidate.data.mass, 0.001)

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

	select_body(body)


func _on_body_drag_finished(body, release_velocity: Vector2) -> void:
	if body == null or not is_instance_valid(body):
		return

	if body.data == null:
		return

	_clear_active_planet_pointer()
	_play_planet_sfx(planet_release_sfx_id)

	if config != null:
		body.data.velocity = Vector2.ZERO if config.ignore_drag_throw_velocity else _capped_drag_throw_velocity(release_velocity)
	else:
		body.data.velocity = release_velocity.limit_length(420.0)

	if config != null and config.auto_orbit_enabled and config.stable_orbit_mode:
		make_body_orbit_nearest(body, true)

	_emit_scene_snapshot_changed()


func _capped_drag_throw_velocity(release_velocity: Vector2) -> Vector2:
	if config == null:
		return release_velocity.limit_length(420.0)

	var throw_velocity: Vector2 = release_velocity * clamp(config.drag_throw_strength, 0.0, 1.0)
	var cap: float = max(float(config.max_drag_throw_speed), 0.0)
	if cap <= 0.0:
		return Vector2.ZERO
	return throw_velocity.limit_length(cap)


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

		"black_hole", "blackhole":
			canvas_item.z_index = LAYER_BLACK_HOLE
			return

	if preset == "star":
		canvas_item.z_index = LAYER_STAR
	elif preset == "black_hole":
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
