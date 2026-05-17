extends Node2D
class_name SimulationPlanetBody

signal pressed(body)
signal tapped(body)
signal drag_started(body)
signal dragged(body, space_position)
signal drag_finished(body, release_velocity)

const PIXEL_PLANET_SCRIPT := preload("res://addons/UnilearnLib/nodes/UnilearnPixelPlanet2D.gd")
const SCALE_UTILS := preload("res://addons/UnilearnLib/physics/SimulationScaleUtils.gd")

const LAYER_MOON := 10
const LAYER_PLANET := 20
const LAYER_STAR := 30
const LAYER_BLACK_HOLE := 40

const TAP_MAX_DISTANCE := 18.0
const TAP_MAX_TIME_SEC := 0.28

var data: SimulationPlanetData = null
var planet_visual: Node2D = null
var trail_line: Line2D = null

var drag_enabled: bool = true

var _dragging := false
var _drag_start_space := Vector2.ZERO
var _drag_last_space := Vector2.ZERO
var _drag_last_time_usec := 0
var _drag_start_time_usec := 0
var _release_velocity := Vector2.ZERO


func _ready() -> void:
	set_process(true)
	set_physics_process(false)


func setup(sim_data: SimulationPlanetData) -> void:
	data = sim_data

	if data == null:
		name = "SimulationPlanetBody"
		return

	name = _safe_node_name(_get_display_name())

	_apply_body_layer()
	_apply_scaled_radius_from_data()
	_build_visual()
	_build_trail()

	sync_from_data()


func _process(_delta: float) -> void:
	_update_trail_line()


func set_scene_animation_paused(paused: bool) -> void:
	set_process(not paused)

	if is_instance_valid(planet_visual):
		if planet_visual.has_method("set_scene_animation_paused"):
			planet_visual.call("set_scene_animation_paused", paused)


func force_apply_planet_data(planet_data: PlanetData) -> void:
	if data == null or planet_data == null:
		return

	data.source_planet_data = planet_data
	_apply_scaled_radius_from_data()

	if is_instance_valid(planet_visual):
		_apply_planet_data_exactly_like_preview(planet_visual, planet_data)


func sync_from_data() -> void:
	if data == null:
		return

	position = data.position


func sync_to_data() -> void:
	if data == null:
		return

	data.position = position


func is_dragging_body() -> bool:
	return _dragging


func get_active_pointer_id() -> int:
	if planet_visual != null and planet_visual.has_method("get_active_pointer_id"):
		return int(planet_visual.call("get_active_pointer_id"))

	return -999


func owns_pointer(pointer_id: int) -> bool:
	if planet_visual != null and planet_visual.has_method("owns_pointer"):
		return bool(planet_visual.call("owns_pointer", pointer_id))

	return false


func contains_screen_position(screen_position: Vector2) -> bool:
	if planet_visual != null and planet_visual.has_method("contains_screen_point"):
		return bool(planet_visual.call("contains_screen_point", screen_position))

	if data == null:
		return false

	var space_position := _screen_to_parent_space(screen_position)
	return space_position.distance_to(position) <= _get_hit_radius()


func rebuild_visual() -> void:
	if is_instance_valid(planet_visual):
		planet_visual.queue_free()

	planet_visual = null
	_build_visual()


func _apply_scaled_radius_from_data() -> void:
	if data == null:
		return

	var source := data.source_planet_data

	if source == null:
		data.radius_world = max(float(data.visual_radius_px), 48.0)
		return

	var radius := SCALE_UTILS.calculate_scene_radius(source)
	data.radius_world = radius
	data.visual_radius_px = radius


func _build_visual() -> void:
	if data == null:
		return

	planet_visual = PIXEL_PLANET_SCRIPT.new()
	planet_visual.name = "PixelPlanetVisual"
	planet_visual.position = Vector2.ZERO
	planet_visual.z_index = 2
	planet_visual.z_as_relative = true
	planet_visual.process_mode = Node.PROCESS_MODE_INHERIT
	add_child(planet_visual)

	_apply_planet_data_exactly_like_preview(planet_visual, data.source_planet_data)
	_connect_visual_interaction()


func _apply_planet_data_exactly_like_preview(planet: Node2D, planet_data: PlanetData) -> void:
	if planet == null:
		return

	if planet_data == null:
		push_error("SimulationPlanetBody: source_planet_data is NULL, so the spawned planet would become generic.")
		return

	var scaled_radius := SCALE_UTILS.calculate_scene_radius(planet_data)

	planet.set("preset", planet_data.planet_preset)
	planet.set("radius_px", scaled_radius)
	planet.set("render_pixels", planet_data.planet_pixels)
	planet.set("seed_value", planet_data.planet_seed)
	planet.set("turning_speed", planet_data.planet_turning_speed)
	planet.set("axial_tilt_deg", planet_data.planet_axial_tilt_deg)
	planet.set("debug_border_enabled", false)

	planet.set("draggable", drag_enabled)

	planet.set("use_custom_colors", planet_data.use_custom_colors)
	planet.set("custom_colors", planet_data.custom_colors)
	
	var preset_key := planet_data.planet_preset.strip_edges().to_lower().replace(" ", "_").replace("-", "_")
	planet.set("backing_disk_enabled", true)
	planet.set("backing_disk_color", Color.BLACK)
	planet.set("backing_disk_padding_px", 0.0)

	if planet.has_method("rebuild"):
		planet.call("rebuild")

	data.radius_world = scaled_radius
	data.visual_radius_px = scaled_radius


func _connect_visual_interaction() -> void:
	if planet_visual == null:
		return

	_connect_visual_signal("picked", Callable(self, "_on_visual_picked"))
	_connect_visual_signal("released", Callable(self, "_on_visual_released"))
	_connect_visual_signal("dragged", Callable(self, "_on_visual_dragged"))


func _connect_visual_signal(signal_name: String, callable: Callable) -> void:
	if planet_visual == null:
		return

	if not planet_visual.has_signal(signal_name):
		return

	if planet_visual.is_connected(signal_name, callable):
		return

	planet_visual.connect(signal_name, callable)


func _on_visual_picked() -> void:
	_dragging = true
	_release_velocity = Vector2.ZERO

	var current_space := position

	_drag_start_space = current_space
	_drag_last_space = current_space
	_drag_start_time_usec = Time.get_ticks_usec()
	_drag_last_time_usec = _drag_start_time_usec

	if data != null:
		data.is_dragging = true
		data.velocity = Vector2.ZERO
		data.reset_trail()

	pressed.emit(self)
	drag_started.emit(self)


func _on_visual_dragged(visual_global_position: Vector2) -> void:
	if planet_visual == null or data == null:
		return

	if not _dragging:
		_on_visual_picked()

	var new_space_position := _visual_global_to_parent_space(visual_global_position)

	var now := Time.get_ticks_usec()
	var dt := max(float(now - _drag_last_time_usec) / 1000000.0, 0.0001)

	_release_velocity = (new_space_position - _drag_last_space) / dt
	_drag_last_space = new_space_position
	_drag_last_time_usec = now

	position = new_space_position

	data.position = new_space_position
	data.previous_position = new_space_position
	data.velocity = Vector2.ZERO
	data.reset_trail()

	planet_visual.position = Vector2.ZERO

	dragged.emit(self, new_space_position)


func _on_visual_released() -> void:
	if planet_visual == null or data == null:
		return

	var final_space_position := _visual_global_to_parent_space(planet_visual.global_position)

	if final_space_position.distance_to(position) > 0.001:
		_on_visual_dragged(planet_visual.global_position)

	var now := Time.get_ticks_usec()
	var held_time := float(now - _drag_start_time_usec) / 1000000.0
	var drag_distance := _drag_start_space.distance_to(data.position)

	var should_tap := drag_distance <= TAP_MAX_DISTANCE and held_time <= TAP_MAX_TIME_SEC

	_dragging = false
	data.is_dragging = false
	planet_visual.position = Vector2.ZERO

	drag_finished.emit(self, _release_velocity)

	if should_tap:
		tapped.emit(self)


func _build_trail() -> void:
	trail_line = Line2D.new()
	trail_line.name = "TrailLine"
	trail_line.width = 2.0
	trail_line.default_color = Color(1.0, 1.0, 1.0, 0.22)
	trail_line.z_index = -10
	trail_line.z_as_relative = true
	add_child(trail_line)


func _update_trail_line() -> void:
	if trail_line == null or data == null:
		return

	trail_line.clear_points()

	for p in data.trail_points:
		trail_line.add_point(to_local(p))


func _visual_global_to_parent_space(visual_global_position: Vector2) -> Vector2:
	var parent_node := get_parent()

	if parent_node is Node2D:
		return (parent_node as Node2D).to_local(visual_global_position)

	if parent_node is CanvasItem:
		var parent_canvas := parent_node as CanvasItem
		return parent_canvas.get_global_transform_with_canvas().affine_inverse() * visual_global_position

	return visual_global_position


func _screen_to_parent_space(screen_position: Vector2) -> Vector2:
	var parent_node := get_parent()

	if parent_node is CanvasItem:
		var parent_canvas := parent_node as CanvasItem
		return parent_canvas.get_global_transform_with_canvas().affine_inverse() * screen_position

	return screen_position


func _get_hit_radius() -> float:
	if data == null:
		return 48.0

	if data.source_planet_data != null:
		return SCALE_UTILS.calculate_hit_radius(data.source_planet_data, float(data.radius_world))

	return max(float(data.radius_world) + 24.0, 44.0)


func _apply_body_layer() -> void:
	z_as_relative = false
	z_index = _get_layer_for_data()


func _get_layer_for_data() -> int:
	var category := _normalized_category()
	var preset := _normalized_preset()

	if category == "black_hole" or preset == "black_hole":
		return LAYER_BLACK_HOLE

	if category == "star" or preset == "star":
		return LAYER_STAR

	if category == "moon" or category == "satellite" or preset == "moon" or preset == "no_atmosphere":
		return LAYER_MOON

	return LAYER_PLANET


func _normalized_category() -> String:
	if data == null or data.source_planet_data == null:
		return ""

	return data.source_planet_data.object_category.strip_edges().to_lower().replace(" ", "_")


func _normalized_preset() -> String:
	if data == null or data.source_planet_data == null:
		return ""

	return data.source_planet_data.planet_preset.strip_edges().to_lower().replace(" ", "_")


func _get_display_name() -> String:
	if data != null and data.source_planet_data != null:
		return data.source_planet_data.name

	if data != null and data.has_method("get_display_name"):
		return data.get_display_name()

	return "Planet"


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


func handle_planet_input(event: InputEvent) -> void:
	if not is_instance_valid(planet_visual):
		return

	if planet_visual.has_method("handle_external_input"):
		planet_visual.call("handle_external_input", event)
