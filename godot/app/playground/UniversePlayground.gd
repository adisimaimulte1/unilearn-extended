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


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_INHERIT
	set_process(true)
	set_physics_process(true)

	_cache_space_background()
	_sync_to_space_background_camera()


func _process(_delta: float) -> void:
	if follow_space_background_camera:
		_sync_to_space_background_camera()


func _physics_process(delta: float) -> void:
	if _scene_objects_paused:
		return

	if not simulation_enabled:
		return

	if config == null:
		return

	if config.gravity_enabled:
		GRAVITY_SOLVER.step(bodies, delta, config)

	if config.collisions_enabled:
		var removed := COLLISION_SOLVER.solve(bodies, config)

		for body in removed:
			if body != null and is_instance_valid(body) and body.data != null:
				remove_planet_card_id(body.data.source_card_id)


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

	_emit_scene_snapshot_changed()
	planet_added.emit(body)

	return body


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

		# Higher z_index wins.
		# If same z_index, newer-added body wins as fallback.
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

		snapshot.append({
			"card_id": body.data.source_card_id,
			"instance_id": body.data.instance_id,
			"name": body.data.get_display_name(),
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
			"object_category": source.object_category if source != null else ""
		})

	return snapshot


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
	simulation_enabled = true


func disable_physics() -> void:
	simulation_enabled = false


func toggle_physics() -> void:
	simulation_enabled = not simulation_enabled


func make_body_orbit_nearest(body, clockwise: bool = true) -> bool:
	if body == null or not is_instance_valid(body):
		return false

	var parent = _find_best_orbit_parent(body)

	if parent == null:
		return false

	return ORBIT_UTILS.make_circular_orbit(body, parent, config, clockwise)


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
		body.data.velocity = release_velocity * config.drag_throw_strength
	else:
		body.data.velocity = release_velocity

	if config != null and config.auto_orbit_enabled:
		make_body_orbit_nearest(body, true)

	_emit_scene_snapshot_changed()


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
