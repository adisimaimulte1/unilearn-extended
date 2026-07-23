extends Node2D
class_name SimulationPlanetBody

signal pressed(body)
signal tapped(body)
signal drag_started(body)
signal dragged(body, space_position)
signal drag_finished(body, release_velocity)

const PIXEL_PLANET_SCRIPT := preload("res://addons/UnilearnLib/nodes/UnilearnPixelPlanet2D.gd")
const SCALE_UTILS := preload("res://addons/UnilearnLib/physics/SimulationScaleUtils.gd")

const LAYER_BLACK_HOLE := 10
const LAYER_STAR := 20
const LAYER_PLANET := 30
const LAYER_MOON := 40
const LAYER_TRAIL := 9

const TAP_MAX_DISTANCE := 18.0
const TAP_MAX_TIME_SEC := 0.28

var data: SimulationPlanetData = null
var planet_visual: Node2D = null
var trail_line: Line2D = null

var drag_enabled: bool = true

var _dragging := false
var _actual_drag_started := false
var _drag_start_space := Vector2.ZERO
var _drag_last_space := Vector2.ZERO
var _drag_last_time_usec := 0
var _drag_start_time_usec := 0
var _release_velocity := Vector2.ZERO
var _velocity_before_pointer_interaction := Vector2.ZERO
var _drag_velocity_samples: Array[Vector2] = []
var _drag_position_samples: Array[Vector2] = []
const DRAG_INERTIA_SAMPLE_LIMIT := 8
const RELEASE_THROW_STALE_TIME_SEC := 0.14
const RELEASE_THROW_MIN_SPEED := 65.0

const TRAIL_VISUAL_MAX_POINTS_NORMAL := 240
const TRAIL_VISUAL_MAX_POINTS_BUSY := 160
const TRAIL_VISUAL_MAX_POINTS_HEAVY := 100
const TRAIL_VISUAL_BUSY_BODY_COUNT := 7
const TRAIL_VISUAL_HEAVY_BODY_COUNT := 12
const TRAIL_FULL_RESYNC_MAX_NEW_POINTS := 4
const TRAIL_MIN_SCREEN_WIDTH_PX := 1.45
const TRAIL_MAX_LOCAL_WIDTH := 64.0
const TRAIL_WIDTH_UPDATE_EPSILON := 0.04

var _trail_last_source_count := 0
var _trail_last_body_position := Vector2.INF
var _trail_last_canvas_scale := -1.0
var _trail_last_first_point := Vector2.INF
var _trail_last_tail_point := Vector2.INF
var _trail_last_budget := -1
var _trail_packed_points := PackedVector2Array()
var _trail_parent_node: Node = null
var _trail_width_check_accum := 99.0


func _ready() -> void:
	set_process(true)
	set_physics_process(false)


func _exit_tree() -> void:
	# Trail is reparented to the playground for performance, so it no longer
	# automatically dies as a child of this body. Clean it explicitly.
	if is_instance_valid(trail_line):
		trail_line.queue_free()


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


func _process(delta: float) -> void:
	_update_trail_line(delta)


func set_scene_animation_paused(paused: bool) -> void:
	# Keep this node processing so hit-tests and tap forwarding stay reliable while the scene is frozen.
	set_process(true)

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

	if is_instance_valid(trail_line):
		trail_line.width = _get_trail_width()
		trail_line.default_color = _get_trail_color()
		trail_line.gradient = null
		_update_trail_width_for_current_zoom()


func animate_merge_growth_from_metadata() -> void:
	if data == null:
		return

	if not bool(data.metadata.get("merge_visual_dirty", false)):
		_consume_pending_visual_rebuild()
		return

	var old_radius: float = float(data.metadata.get("merge_visual_old_radius", data.radius_world))
	var target_radius: float = float(data.metadata.get("merge_visual_target_radius", data.radius_world))
	var needs_visual_rebuild := bool(data.metadata.get("force_rebuild_visual", false))
	data.metadata.erase("merge_visual_dirty")
	data.metadata.erase("merge_visual_old_radius")
	data.metadata.erase("merge_visual_old_visual_radius")
	data.metadata.erase("merge_visual_target_radius")

	# If the collision changed the actual body type (star -> black hole, planet -> star,
	# black hole disk state, etc.), swap/reconfigure the scene visual BEFORE the growth
	# tween. Otherwise the old star/planet scene can remain visible while the details
	# panel already reads the evolved black-hole data.
	if needs_visual_rebuild:
		data.metadata.erase("force_rebuild_visual")
		rebuild_visual()

	if _dragging or data.is_dragging:
		# A held body must change size on the same frame as its collision-driven
		# type/preset change. Starting a shrink tween from the old star radius while
		# the pointer owns the visual can leave the new black-hole UI at star size.
		_apply_visual_radius(target_radius, target_radius, false)
	else:
		_apply_visual_radius(target_radius, old_radius, true)


func _apply_visual_radius(target_radius: float, start_radius: float = -1.0, animated: bool = false) -> void:
	if data == null:
		return

	target_radius = max(target_radius, 8.0)
	data.radius_world = target_radius
	# Keep the stored visual radius identical to the rendered target. Using max()
	# prevented legitimate collapse transitions (red supergiant -> black hole)
	# from shrinking their runtime size even after the preset had changed.
	data.visual_radius_px = int(target_radius)

	if is_instance_valid(trail_line):
		trail_line.width = _get_trail_width()
		trail_line.default_color = _get_trail_color()
		trail_line.gradient = null
		_update_trail_width_for_current_zoom()

	if not is_instance_valid(planet_visual):
		return

	var current_radius: float = target_radius
	var radius_value: Variant = planet_visual.get("radius_px")
	if radius_value != null:
		current_radius = float(radius_value)

	if start_radius > 0.0:
		current_radius = start_radius
		planet_visual.set("radius_px", current_radius)

	if not animated:
		planet_visual.set("radius_px", target_radius)
		return

	var pop_radius: float = max(target_radius * 1.08, current_radius + 2.0)
	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(planet_visual, "radius_px", pop_radius, 0.16)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(planet_visual, "radius_px", target_radius, 0.20)


func sync_from_data() -> void:
	if data == null:
		return

	position = data.position
	_apply_body_layer()
	if not bool(data.metadata.get("merge_visual_dirty", false)):
		_consume_pending_visual_rebuild()


func _consume_pending_visual_rebuild() -> void:
	if data == null:
		return
	if not bool(data.metadata.get("force_rebuild_visual", false)):
		return
	data.metadata.erase("force_rebuild_visual")
	rebuild_visual()


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


func cancel_active_drag() -> void:
	if not _dragging:
		return
	if is_instance_valid(planet_visual) and planet_visual.has_method("_stop_drag"):
		planet_visual.call("_stop_drag")
		return
	# Fallback for a visual that disappeared during the collision rebuild.
	_dragging = false
	if data != null:
		data.is_dragging = false


func rebuild_visual() -> void:
	if data != null and _dragging and is_instance_valid(planet_visual):
		# Do not destroy the visual node while a finger/mouse pointer owns it.
		# Queue-freeing it cancels the visual's drag stream, which made collision
		# evolution freeze the held planet in place until release. Reconfigure the
		# existing visual instead; release/drag signals stay connected.
		_apply_planet_data_exactly_like_preview(planet_visual, data.source_planet_data)
		planet_visual.position = Vector2.ZERO
		_connect_visual_interaction()
		return

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
	# The simulator can zoom a procedural planet across most of the display.
	# Cache its native shader result in a fixed-resolution SubViewport so zooming
	# scales a texture instead of rerunning every noise shader per screen pixel.
	planet_visual.set("use_subviewport_cache", true)
	planet_visual.set("shared_render_budget_enabled", true)
	# Configure the pixel planet before it enters the scene tree.
	# Otherwise _ready() builds the default terran planet first, then the real
	# card data triggers another expensive shader/tree rebuild on the same frame.
	_apply_planet_data_exactly_like_preview(planet_visual, data.source_planet_data, true)
	add_child(planet_visual)
	_connect_visual_interaction()


func _apply_planet_data_exactly_like_preview(planet: Node2D, planet_data: PlanetData, defer_tree_rebuild: bool = false) -> void:
	if planet == null:
		return

	if planet_data == null:
		push_error("SimulationPlanetBody: source_planet_data is NULL, so the spawned planet would become generic.")
		return

	var can_bulk_update := planet.has_method("begin_bulk_update") and planet.has_method("end_bulk_update") and planet.is_inside_tree()
	if can_bulk_update:
		planet.call("begin_bulk_update")

	var scaled_radius := SCALE_UTILS.calculate_scene_radius(planet_data)
	var target_radius := scaled_radius
	if data != null and bool(data.metadata.get("preserve_runtime_visual_radius", false)):
		target_radius = max(float(data.radius_world), 8.0)
	elif data != null and bool(data.metadata.get("collision_evolved", false)):
		target_radius = max(float(data.radius_world), 8.0)
	elif data != null and bool(data.metadata.get("runtime_visual_clone", false)):
		target_radius = max(float(data.radius_world), 8.0)

	planet.set("preset", planet_data.planet_preset)
	planet.set("radius_px", target_radius)
	planet.set("render_pixels", planet_data.planet_pixels)
	planet.set("seed_value", planet_data.planet_seed)
	planet.set("turning_speed", planet_data.planet_turning_speed)
	planet.set("axial_tilt_deg", planet_data.planet_axial_tilt_deg)
	var preset_key := planet_data.planet_preset.strip_edges().to_lower().replace(" ", "_").replace("-", "_")
	var category_key := planet_data.object_category.strip_edges().to_lower().replace(" ", "_").replace("-", "_")
	planet.set("debug_border_enabled", false)
	planet.set("debug_border_width", 2.0)
	planet.set("debug_border_color", Color(0.2, 1.0, 1.0, 0.9))

	planet.set("draggable", drag_enabled)

	planet.set("use_custom_colors", planet_data.use_custom_colors)
	planet.set("custom_colors", planet_data.custom_colors)
	
	planet.set("backing_disk_enabled", true)
	planet.set("backing_disk_color", Color.WHITE if planet_data.planet_preset.strip_edges().to_lower().replace(" ", "_").replace("-", "_") == "white_hole" else Color.BLACK)
	planet.set("backing_disk_padding_px", 0.0)
	planet.set("accretion_disk_enabled", _singularity_has_disk(planet_data))

	if can_bulk_update:
		planet.call("end_bulk_update")
	elif not defer_tree_rebuild and planet.has_method("rebuild"):
		planet.call("rebuild")

	data.radius_world = target_radius
	data.visual_radius_px = int(max(float(data.visual_radius_px), target_radius))



func _singularity_has_disk(planet_data: PlanetData) -> bool:
	if planet_data == null:
		return true
	var preset := planet_data.planet_preset.strip_edges().to_lower().replace(" ", "_").replace("-", "_")
	var category := planet_data.object_category.strip_edges().to_lower().replace(" ", "_").replace("-", "_")
	var archetype := planet_data.archetype_id.strip_edges().to_lower().replace(" ", "_").replace("-", "_")
	if not (preset == "black_hole" or preset == "white_hole" or category == "singularity" or archetype == "black_hole" or archetype == "white_hole"):
		return true
	if preset == "white_hole" or archetype == "white_hole" or category == "white_hole":
		return true
	if planet_data.singularity_has_disk == false:
		return false
	var text := planet_data.ring_system.strip_edges().to_lower()
	for card in planet_data.data_cards:
		if card is Dictionary and str(card.get("title", "")).strip_edges().to_lower() == "disk":
			text = str(card.get("value", "")).strip_edges().to_lower()
			break
	if text.is_empty():
		return planet_data.singularity_has_disk
	return not (text == "none" or text.contains("no disk") or text.contains("no confirmed") or text.contains("absent") or text.contains("without disk") or text.contains("not confirmed"))


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
	_actual_drag_started = false
	_release_velocity = Vector2.ZERO
	_velocity_before_pointer_interaction = data.velocity if data != null else Vector2.ZERO
	_drag_velocity_samples.clear()
	_drag_position_samples.clear()

	var current_space := position

	_drag_start_space = current_space
	_drag_last_space = current_space
	_drag_start_time_usec = Time.get_ticks_usec()
	_drag_last_time_usec = _drag_start_time_usec

	if data != null:
		data.is_dragging = true

	pressed.emit(self)


func _on_visual_dragged(visual_global_position: Vector2) -> void:
	if planet_visual == null or data == null:
		return

	if not _dragging:
		_on_visual_picked()

	var new_space_position := _visual_global_to_parent_space(visual_global_position)
	var distance_from_start := _drag_start_space.distance_to(new_space_position)

	if not _actual_drag_started:
		if distance_from_start <= TAP_MAX_DISTANCE:
			planet_visual.position = Vector2.ZERO
			return

		_actual_drag_started = true
		data.velocity = Vector2.ZERO
		data.reset_trail()
		drag_started.emit(self)

	var now := Time.get_ticks_usec()
	var dt := max(float(now - _drag_last_time_usec) / 1000000.0, 0.0001)

	_release_velocity = (new_space_position - _drag_last_space) / dt
	_drag_velocity_samples.append(_release_velocity)
	_drag_position_samples.append(new_space_position)
	while _drag_velocity_samples.size() > DRAG_INERTIA_SAMPLE_LIMIT:
		_drag_velocity_samples.pop_front()
	while _drag_position_samples.size() > DRAG_INERTIA_SAMPLE_LIMIT:
		_drag_position_samples.pop_front()
	_drag_last_space = new_space_position
	_drag_last_time_usec = now

	position = new_space_position

	data.position = new_space_position
	data.previous_position = new_space_position
	data.velocity = Vector2.ZERO
	data.reset_trail()

	planet_visual.position = Vector2.ZERO

	dragged.emit(self, new_space_position)



func _combined_release_velocity(release_time_usec: int = -1) -> Vector2:
	var now_usec := release_time_usec if release_time_usec > 0 else Time.get_ticks_usec()
	var age_sec := float(now_usec - _drag_last_time_usec) / 1000000.0

	# Use ONLY the real finger velocity from the last drag event.
	# No averaged inertia, no curved/momentum correction, no old orbital velocity.
	# If the finger stops before release, this returns ZERO and the body is simply placed.
	if age_sec > RELEASE_THROW_STALE_TIME_SEC:
		return Vector2.ZERO
	if _release_velocity.length() < RELEASE_THROW_MIN_SPEED:
		return Vector2.ZERO
	return _release_velocity

func _on_visual_released() -> void:
	if planet_visual == null or data == null:
		return

	var final_space_position := _visual_global_to_parent_space(planet_visual.global_position)

	if _actual_drag_started and final_space_position.distance_to(position) > 0.001:
		_on_visual_dragged(planet_visual.global_position)

	var now := Time.get_ticks_usec()
	var held_time := float(now - _drag_start_time_usec) / 1000000.0
	var drag_distance := _drag_start_space.distance_to(data.position)

	var should_tap := not _actual_drag_started and drag_distance <= TAP_MAX_DISTANCE and held_time <= TAP_MAX_TIME_SEC

	_dragging = false
	data.is_dragging = false
	planet_visual.position = Vector2.ZERO

	if _actual_drag_started:
		drag_finished.emit(self, _combined_release_velocity(now))
	else:
		# Pure taps/selects must never kill orbital motion. Some touch drivers emit a
		# pick/release sequence when opening the planet card; restore the pre-tap
		# velocity so the body keeps orbiting while the UI opens.
		data.velocity = _velocity_before_pointer_interaction
		_release_velocity = Vector2.ZERO

	_actual_drag_started = false

	if bool(data.metadata.get("pending_rebuild_visual_after_drag_release", false)):
		data.metadata.erase("pending_rebuild_visual_after_drag_release")
		call_deferred("rebuild_visual")

	if should_tap:
		tapped.emit(self)


func _build_trail() -> void:
	if is_instance_valid(trail_line):
		trail_line.queue_free()

	trail_line = Line2D.new()
	trail_line.name = "TrailLine"
	trail_line.position = Vector2.ZERO
	trail_line.width = _get_trail_width()
	trail_line.z_index = LAYER_TRAIL
	trail_line.z_as_relative = false
	trail_line.closed = false
	# Keep rounded caps/joins because sharp/mitered corners look like broken wires on tight orbits.
	# Antialiasing stays off because it was one of the expensive mobile-GPU paths.
	trail_line.joint_mode = Line2D.LINE_JOINT_ROUND
	trail_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	trail_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	trail_line.antialiased = false
	trail_line.default_color = _get_trail_color()
	trail_line.gradient = null
	trail_line.width_curve = null
	trail_line.clear_points()
	add_child(trail_line)
	call_deferred("_ensure_trail_parent_space")
	_reset_trail_render_cache()


func _ensure_trail_parent_space() -> bool:
	if not is_instance_valid(trail_line):
		return false

	var parent_node := get_parent()
	if parent_node == null:
		return false

	if trail_line.get_parent() == parent_node:
		_trail_parent_node = parent_node
		trail_line.position = Vector2.ZERO
		return true

	# Make trails siblings of bodies, not children of moving bodies. This preserves
	# the same universe/camera scaling, rotation and translation, but removes the
	# old per-frame translation of every cached trail point.
	var old_points := trail_line.points
	if trail_line.get_parent() != null:
		trail_line.get_parent().remove_child(trail_line)
	parent_node.add_child(trail_line)
	trail_line.points = old_points
	trail_line.position = Vector2.ZERO
	_trail_parent_node = parent_node
	return true


func _reset_trail_render_cache() -> void:
	_trail_last_source_count = 0
	_trail_last_body_position = Vector2.INF
	_trail_last_first_point = Vector2.INF
	_trail_last_tail_point = Vector2.INF
	_trail_last_budget = -1
	_trail_packed_points = PackedVector2Array()


func _update_trail_line(_delta: float = 0.0) -> void:
	if not is_instance_valid(trail_line) or data == null:
		return

	if not _ensure_trail_parent_space():
		return

	_trail_width_check_accum += _delta
	if _trail_width_check_accum >= 0.12:
		_trail_width_check_accum = 0.0
		_update_trail_width_for_current_zoom()

	var source_count := data.trail_points.size()
	if source_count < 2:
		if _trail_last_source_count != source_count or _trail_packed_points.size() > 0:
			trail_line.clear_points()
			_reset_trail_render_cache()
			_trail_last_source_count = source_count
		return

	var first_point: Vector2 = Vector2(data.trail_points[0])
	var tail_point: Vector2 = Vector2(data.trail_points[source_count - 1])
	var budget := _runtime_trail_visual_point_budget(_get_parent_body_count())

	var source_changed := source_count != _trail_last_source_count or first_point != _trail_last_first_point or tail_point != _trail_last_tail_point or budget != _trail_last_budget
	if not source_changed:
		return

	var can_incremental := budget == _trail_last_budget and _trail_packed_points.size() > 0 and tail_point != _trail_last_tail_point
	var source_delta := source_count - _trail_last_source_count
	if can_incremental and source_delta >= 0 and source_delta <= TRAIL_FULL_RESYNC_MAX_NEW_POINTS and first_point == _trail_last_first_point:
		# Pure append path: only add the newest points.
		for i in range(_trail_last_source_count, source_count):
			_trail_packed_points.append(Vector2(data.trail_points[i]))
		_trim_cached_trail_to_budget(budget)
	elif can_incremental and source_delta == 0 and first_point != _trail_last_first_point:
		# Ring-buffer style path: physics removed old points and appended the new tail.
		# Avoid rebuilding the whole line; remove the same amount from the front and
		# append the new tail. In practice this is usually one point per physics tick.
		var removed := _estimate_removed_source_points(source_count, first_point)
		removed = clampi(removed, 1, max(1, _trail_packed_points.size() - 2))
		for _i in range(removed):
			if _trail_packed_points.size() > 0:
				_trail_packed_points.remove_at(0)
		_trail_packed_points.append(tail_point)
		_trim_cached_trail_to_budget(budget)
	else:
		# Reset/large mutation/budget change: rebuild once. This should be rare and is
		# much cheaper than doing it every frame.
		_resync_cached_trail_from_source(budget)

	trail_line.points = _trail_packed_points
	_trail_last_source_count = source_count
	_trail_last_first_point = first_point
	_trail_last_tail_point = tail_point
	_trail_last_budget = budget


func _translate_cached_trail_points(_offset: Vector2) -> void:
	# Kept for compatibility with older calls. Trails now live in parent/world
	# coordinates, so cached vertices do not need per-frame translation.
	return


func _trim_cached_trail_to_budget(budget: int) -> void:
	budget = max(8, budget)
	while _trail_packed_points.size() > budget:
		_trail_packed_points.remove_at(0)


func _estimate_removed_source_points(source_count: int, first_point: Vector2) -> int:
	# Source points usually remove exactly one old point. This helper keeps the path
	# robust if a slower frame drops multiple points at once.
	var search_limit: int = mini(source_count, TRAIL_FULL_RESYNC_MAX_NEW_POINTS + 1)
	for i in range(search_limit):
		if Vector2(data.trail_points[i]) == first_point:
			return i
	return 1


func _resync_cached_trail_from_source(budget: int) -> void:
	var source_count := data.trail_points.size()
	budget = max(8, budget)
	var start_index: int = max(0, source_count - budget)
	var out_count: int = source_count - start_index
	_trail_packed_points.resize(out_count)
	for write_index in range(out_count):
		_trail_packed_points[write_index] = Vector2(data.trail_points[start_index + write_index])
	trail_line.points = _trail_packed_points


func _get_parent_body_count() -> int:
	var parent_body_count := 1
	var parent_node := get_parent()
	if parent_node != null:
		var parent_bodies: Variant = parent_node.get("bodies")
		if parent_bodies is Array:
			parent_body_count = (parent_bodies as Array).size()
	return parent_body_count


func _runtime_trail_visual_point_budget(parent_body_count: int) -> int:
	if parent_body_count >= TRAIL_VISUAL_HEAVY_BODY_COUNT:
		return TRAIL_VISUAL_MAX_POINTS_HEAVY
	if parent_body_count >= TRAIL_VISUAL_BUSY_BODY_COUNT:
		return TRAIL_VISUAL_MAX_POINTS_BUSY
	return TRAIL_VISUAL_MAX_POINTS_NORMAL


func _make_trail_gradient(base_color: Color) -> Gradient:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 1.0])
	gradient.colors = PackedColorArray([
		Color(base_color.r, base_color.g, base_color.b, 0.82),
		Color(base_color.r, base_color.g, base_color.b, 0.82)
	])
	return gradient


func _make_trail_width_curve() -> Curve:
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 1.0))
	curve.add_point(Vector2(1.0, 1.0))
	return curve


func _update_trail_width_for_current_zoom() -> void:
	if not is_instance_valid(trail_line):
		return

	# When the universe is zoomed far out, normal small trails can become thinner
	# than a physical screen pixel. Godot then aliases them into a dotted/broken line,
	# especially on diagonals and tight curves. Keep the trail in local space so it
	# still scales with the system, but add a tiny screen-space floor only when needed.
	var canvas_scale := _get_trail_canvas_scale_factor()
	var min_local_width := TRAIL_MIN_SCREEN_WIDTH_PX / canvas_scale
	var target_width: float = clamp(max(_get_trail_width(), min_local_width), 0.5, TRAIL_MAX_LOCAL_WIDTH)

	if absf(float(trail_line.width) - target_width) > TRAIL_WIDTH_UPDATE_EPSILON:
		trail_line.width = target_width


func _get_trail_canvas_scale_factor() -> float:
	var transform := trail_line.get_global_transform_with_canvas() if is_instance_valid(trail_line) else get_global_transform_with_canvas()
	var x_scale := transform.x.length()
	var y_scale := transform.y.length()
	var canvas_scale := max(0.001, (x_scale + y_scale) * 0.5)
	return canvas_scale


func _get_trail_width() -> float:
	if data == null:
		return 4.0
	return clamp(float(data.radius_world) * 0.055, 3.0, 16.0)


func _get_trail_color() -> Color:
	if data != null and data.source_planet_data != null:
		var source := data.source_planet_data
		if source.has_method("get_hero_main_color"):
			var hero_color: Variant = source.call("get_hero_main_color")
			if hero_color is Color:
				var c: Color = hero_color
				c.a = 1.0
				return c
		if source.use_custom_colors and source.custom_colors.size() > 0:
			var c2: Color = source.custom_colors[0]
			c2.a = 1.0
			return c2

	var category := _normalized_category()
	var preset := _normalized_preset()

	if category == "star" or preset == "star":
		return Color(1.0, 0.78, 0.35, 1.0)
	if category == "moon" or category == "satellite" or preset == "moon" or preset == "no_atmosphere":
		return Color(0.72, 0.82, 1.0, 1.0)
	if category == "white_hole" or preset == "white_hole":
		return Color(1.0, 1.0, 1.0, 1.0)
	if category == "black_hole" or preset == "black_hole":
		return Color(1.0, 0.62, 0.20, 1.0)
	if preset.contains("gas"):
		return Color(0.95, 0.72, 1.0, 1.0)
	if preset.contains("ice"):
		return Color(0.55, 0.95, 1.0, 1.0)
	if preset.contains("lava"):
		return Color(1.0, 0.42, 0.22, 1.0)
	return Color(1.0, 1.0, 1.0, 1.0)


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

	var base_radius := max(float(data.radius_world) + 24.0, 44.0)
	if data.source_planet_data != null:
		base_radius = SCALE_UTILS.calculate_hit_radius(data.source_planet_data, float(data.radius_world))

	if _is_runtime_singularity():
		return max(base_radius, float(data.radius_world) * 1.45 + 42.0)

	return base_radius


func _is_runtime_singularity() -> bool:
	if data == null:
		return false
	if int(data.body_kind) == SimulationPlanetData.BodyKind.BLACK_HOLE or int(data.body_kind) == SimulationPlanetData.BodyKind.WHITE_HOLE:
		return true
	if data.source_planet_data == null:
		return false
	var category := data.source_planet_data.object_category.strip_edges().to_lower().replace(" ", "_").replace("-", "_")
	var preset := data.source_planet_data.planet_preset.strip_edges().to_lower().replace(" ", "_").replace("-", "_")
	var archetype := data.source_planet_data.archetype_id.strip_edges().to_lower().replace(" ", "_").replace("-", "_")
	return category == "singularity" or category == "black_hole" or category == "white_hole" or preset == "black_hole" or preset == "white_hole" or archetype == "black_hole" or archetype == "white_hole"


func _apply_body_layer() -> void:
	z_as_relative = false
	z_index = _get_layer_for_data()


func _get_layer_for_data() -> int:
	var category := _normalized_category()
	var preset := _normalized_preset()

	if category == "black_hole" or category == "white_hole" or preset == "black_hole" or preset == "white_hole":
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
