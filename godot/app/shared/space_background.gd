extends Control

const STAR_SHADER_PATH := "res://shaders/space_stars_gpu.gdshader"

const STAR_DENSITY_MULTIPLIER := 1.0
const MIN_SAFE_CHUNK_RADIUS := 4
const MIN_STARS_PER_CHUNK := 0

@export var star_count: int = 100
@export var star_base_size_multiplier: float = 1.25

@export var navigation_enabled: bool = false

@export var min_zoom: float = 0.16
@export var max_zoom: float = 1.85

@export var pan_sensitivity: float = 1.12
@export var pinch_zoom_sensitivity: float = 0.62
@export var pinch_deadzone: float = 0.002
@export var rotation_sensitivity: float = 0.72
@export var rotation_deadzone_deg: float = 0.18

@export var camera_smooth_speed: float = 16.0
@export var zoom_smooth_speed: float = 15.0
@export var rotation_smooth_speed: float = 14.0
@export var pinch_center_smoothness: float = 0.38

@export var visual_zoom_strength: float = 0.34
@export var star_size_zoom_strength: float = 0.12

@export var star_animation_enabled: bool = false
@export var star_update_hz: float = 24.0

@export var chunk_size: float = 1500.0
@export var chunk_radius: int = 4
@export var chunk_seed: int = 918273

@export var far_parallax: float = 0.16
@export var near_parallax: float = 0.58

@export var travel_speed_multiplier: float = 0.0
@export var travel_direction: Vector2 = Vector2(0.0, -1.0)

@export var nebula_alpha: float = 0.14
@export var nebula_drift_strength: float = 3.0
@export var nebula_drift_speed: float = 0.06

@onready var space_gradient: ColorRect = $SpaceGradient
@onready var wave_nebula: ColorRect = $WaveNebula
@onready var star_layer: Control = $StarLayer

var star_reveal: float = 0.0
var nebula_base_position := Vector2.ZERO

var space_position: Vector2 = Vector2.ZERO
var space_zoom: float = 1.0
var space_rotation: float = 0.0

var target_space_position: Vector2 = Vector2.ZERO
var target_space_zoom: float = 1.0
var target_space_rotation: float = 0.0

var background_paused: bool = false

var _touches: Dictionary = {}

var _last_pinch_distance: float = 0.0
var _last_pinch_center := Vector2.ZERO
var _last_pinch_angle: float = 0.0

var _screen_center := Vector2.ZERO
var _white_tex: Texture2D
var _quad_mesh: QuadMesh
var _mm_instance: MultiMeshInstance2D
var _mm: MultiMesh

var _visible_chunks: Array[Vector2i] = []
var _last_center_chunk := Vector2i(999999, 999999)
var _last_chunk_radius: int = -1
var _last_chunk_size: float = -1.0
var _last_stars_per_chunk: int = -1

var _stars_per_chunk: int = 1
var _instance_count: int = 0

var _stars_dirty: bool = true
var _star_update_accum: float = 0.0

var _last_shader_space_position := Vector2(INF, INF)
var _last_shader_visual_zoom: float = INF
var _last_shader_camera_rotation: float = INF
var _last_shader_star_size_zoom: float = INF
var _last_shader_star_reveal: float = INF
var _last_shader_screen_center := Vector2(INF, INF)
var _last_shader_zoom_out_brightness: float = INF
var _last_shader_animation_enabled := false
var _last_shader_time_bucket := -999999

var reduce_motion_enabled: bool = false

var _space_gradient_material: ShaderMaterial = null
var _wave_nebula_material: ShaderMaterial = null
var _star_material: ShaderMaterial = null

var _nebula_locked_to_base := false
var _touch_points_cache: Array = []

var _white_hidden := Color(1.0, 1.0, 1.0, 0.0)


func set_background_paused(paused: bool) -> void:
	if background_paused == paused:
		return

	background_paused = paused

	if background_paused:
		_reset_touch_state()
		navigation_enabled = false
		set_process(false)
		return

	set_process(true)
	_mark_stars_dirty()
	_apply_camera_view(0.0, true)


func set_reduce_motion_enabled(enabled: bool) -> void:
	if reduce_motion_enabled == enabled:
		return

	reduce_motion_enabled = enabled

	if reduce_motion_enabled:
		space_position = target_space_position
		space_zoom = _clamp_raw_zoom(target_space_zoom)
		target_space_zoom = space_zoom
		space_rotation = target_space_rotation
		_mark_stars_dirty()
		_apply_camera_view(0.0, true)
	else:
		_nebula_locked_to_base = false
		_mark_stars_dirty()


func _ready() -> void:
	_sanitize_zoom_limits()

	_full_rect(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_full_rect(space_gradient)
	space_gradient.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_full_rect(wave_nebula)
	wave_nebula.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_full_rect(star_layer)
	star_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE

	nebula_base_position = Vector2.ZERO

	space_zoom = _clamp_raw_zoom(space_zoom)
	target_space_position = space_position
	target_space_zoom = space_zoom
	target_space_rotation = space_rotation

	_cache_materials()
	_setup_materials()
	_update_screen_cache()
	_build_star_multimesh()
	_force_chunk_rebuild()
	_apply_camera_view(0.0, true)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_update_screen_cache()
		_apply_camera_view(0.0, true)


func _process(delta: float) -> void:
	if background_paused:
		return

	var time := Time.get_ticks_msec() * 0.001

	target_space_zoom = _clamp_raw_zoom(target_space_zoom)

	if travel_speed_multiplier != 0.0:
		var dir := travel_direction.normalized().rotated(-target_space_rotation)
		target_space_position += dir * travel_speed_multiplier * delta
		_mark_stars_dirty()

	_smooth_camera(delta)
	_update_nebula_drift(time)
	_update_visible_chunks_if_needed()

	if _should_update_shader(delta, time):
		_apply_camera_view(time, false)


func _full_rect(node: Control) -> void:
	node.anchor_left = 0.0
	node.anchor_top = 0.0
	node.anchor_right = 1.0
	node.anchor_bottom = 1.0
	node.offset_left = 0.0
	node.offset_top = 0.0
	node.offset_right = 0.0
	node.offset_bottom = 0.0


func _cache_materials() -> void:
	_space_gradient_material = space_gradient.material as ShaderMaterial
	_wave_nebula_material = wave_nebula.material as ShaderMaterial


func _sanitize_zoom_limits() -> void:
	min_zoom = max(min_zoom, 0.01)
	max_zoom = max(max_zoom, min_zoom + 0.01)


func _clamp_raw_zoom(value: float) -> float:
	_sanitize_zoom_limits()
	return clamp(value, min_zoom, max_zoom)


func _get_effective_chunk_radius() -> int:
	return max(chunk_radius, MIN_SAFE_CHUNK_RADIUS)


func _get_visible_chunk_count() -> int:
	var r := _get_effective_chunk_radius()
	var d := r * 2 + 1
	return d * d


func _get_effective_star_count() -> int:
	if star_count <= 0:
		return 0

	return max(0, int(round(float(star_count) * STAR_DENSITY_MULTIPLIER)))


func _get_stars_per_chunk() -> int:
	var effective_count := _get_effective_star_count()

	if effective_count <= 0:
		return 0

	var chunk_count: int = max(_get_visible_chunk_count(), 1)
	var density_target := int(ceil(float(effective_count) / float(chunk_count)))

	return max(MIN_STARS_PER_CHUNK, density_target)


func _update_screen_cache() -> void:
	_screen_center = get_viewport_rect().size * 0.5
	_mark_stars_dirty()


func _setup_materials() -> void:
	if _space_gradient_material != null:
		_space_gradient_material.set_shader_parameter("reveal", 0.0)
		_space_gradient_material.set_shader_parameter("wave_strength", 0.02)
		_space_gradient_material.set_shader_parameter("color_a", Color(0.0, 0.0, 0.0, 1.0))
		_space_gradient_material.set_shader_parameter("color_b", Color(0.008, 0.018, 0.055, 1.0))
		_space_gradient_material.set_shader_parameter("color_c", Color(0.025, 0.045, 0.11, 1.0))

	if _wave_nebula_material != null:
		_wave_nebula_material.set_shader_parameter("reveal", 0.0)
		_wave_nebula_material.set_shader_parameter("wave_strength", 0.04)
		_wave_nebula_material.set_shader_parameter("color_a", Color(0.0, 0.0, 0.0, 0.0))
		_wave_nebula_material.set_shader_parameter("color_b", Color(0.018, 0.035, 0.095, 0.75))
		_wave_nebula_material.set_shader_parameter("color_c", Color(0.055, 0.065, 0.16, 0.65))

	wave_nebula.modulate.a = nebula_alpha
	wave_nebula.scale = Vector2.ONE
	wave_nebula.rotation = 0.0

	_star_material = ShaderMaterial.new()

	if ResourceLoader.exists(STAR_SHADER_PATH):
		_star_material.shader = load(STAR_SHADER_PATH) as Shader
	else:
		push_error("Missing star shader: " + STAR_SHADER_PATH)


func _build_star_multimesh() -> void:
	for child in star_layer.get_children():
		if child is MultiMeshInstance2D:
			child.queue_free()

	var img := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	_white_tex = ImageTexture.create_from_image(img)

	_quad_mesh = QuadMesh.new()
	_quad_mesh.size = Vector2.ONE

	_stars_per_chunk = _get_stars_per_chunk()
	_last_stars_per_chunk = _stars_per_chunk
	_instance_count = _stars_per_chunk * _get_visible_chunk_count()
	
	if _instance_count <= 0:
		_mm_instance = MultiMeshInstance2D.new()
		_mm_instance.name = "StarMultiMesh"
		_mm_instance.visible = false
		star_layer.add_child(_mm_instance)
		_mm = null
		return

	_mm_instance = MultiMeshInstance2D.new()
	_mm_instance.name = "StarMultiMesh"
	_mm_instance.texture = _white_tex
	_mm_instance.top_level = true
	_mm_instance.material = _star_material
	star_layer.add_child(_mm_instance)

	_mm = MultiMesh.new()
	_mm.transform_format = MultiMesh.TRANSFORM_2D
	_mm.use_colors = true
	_mm.use_custom_data = true
	_mm.mesh = _quad_mesh
	_mm.instance_count = _instance_count
	_mm_instance.multimesh = _mm

	for i in range(_instance_count):
		_mm.set_instance_transform_2d(i, Transform2D())
		_mm.set_instance_color(i, _white_hidden)
		_mm.set_instance_custom_data(i, Color(0.0, 0.0, far_parallax, 1.0))

	_mark_stars_dirty()


func _force_chunk_rebuild() -> void:
	_last_center_chunk = Vector2i(999999, 999999)
	_last_chunk_radius = -1
	_last_chunk_size = -1.0
	_update_visible_chunks_if_needed()


func _update_visible_chunks_if_needed() -> void:
	var center_chunk := _world_to_chunk(space_position)
	var effective_radius := _get_effective_chunk_radius()
	var stars_per_chunk_now := _get_stars_per_chunk()

	if stars_per_chunk_now != _last_stars_per_chunk:
		_build_star_multimesh()
		_last_center_chunk = Vector2i(999999, 999999)

	if center_chunk == _last_center_chunk and effective_radius == _last_chunk_radius and is_equal_approx(chunk_size, _last_chunk_size):
		return

	_last_center_chunk = center_chunk
	_last_chunk_radius = effective_radius
	_last_chunk_size = chunk_size

	_visible_chunks.clear()

	for y in range(center_chunk.y - effective_radius, center_chunk.y + effective_radius + 1):
		for x in range(center_chunk.x - effective_radius, center_chunk.x + effective_radius + 1):
			_visible_chunks.append(Vector2i(x, y))

	_fill_stars_from_chunks()
	_mark_stars_dirty()


func _world_to_chunk(world_pos: Vector2) -> Vector2i:
	var safe_chunk_size: float = max(chunk_size, 1.0)

	return Vector2i(
		floori(world_pos.x / safe_chunk_size),
		floori(world_pos.y / safe_chunk_size)
	)


func _fill_stars_from_chunks() -> void:
	if _mm == null or _visible_chunks.is_empty():
		return

	var index := 0

	for chunk in _visible_chunks:
		var chunk_origin_x := float(chunk.x) * chunk_size
		var chunk_origin_y := float(chunk.y) * chunk_size

		for slot in range(_stars_per_chunk):
			if index >= _instance_count:
				return

			var h0 := _hash01(chunk.x, chunk.y, slot, 11)
			var h1 := _hash01(chunk.x, chunk.y, slot, 23)
			var h2 := _hash01(chunk.x, chunk.y, slot, 37)
			var h3 := _hash01(chunk.x, chunk.y, slot, 41)
			var h4 := _hash01(chunk.x, chunk.y, slot, 53)
			var h5 := _hash01(chunk.x, chunk.y, slot, 67)
			var h6 := _hash01(chunk.x, chunk.y, slot, 79)
			var h7 := _hash01(chunk.x, chunk.y, slot, 83)

			var depth := h2
			var parallax: float = lerp(far_parallax, near_parallax, depth)

			var world_x := chunk_origin_x + h0 * chunk_size
			var world_y := chunk_origin_y + h1 * chunk_size
			var star_size: float = lerp(2.35, 5.95, h3) * star_base_size_multiplier * lerp(0.76, 1.22, depth)

			var alpha: float = lerp(0.72, 1.0, h6)
			var drift_normalized := h4
			var pulse_normalized := h5
			var phase_normalized := h7

			_mm.set_instance_transform_2d(index, Transform2D())
			_mm.set_instance_custom_data(index, Color(world_x, world_y, parallax, star_size))
			_mm.set_instance_color(index, Color(alpha, drift_normalized, pulse_normalized, phase_normalized))

			index += 1

	while index < _instance_count:
		_mm.set_instance_color(index, _white_hidden)
		index += 1


func _hash01(x: int, y: int, star: int, salt: int) -> float:
	var n := int(chunk_seed)
	n ^= x * 374761393
	n ^= y * 668265263
	n ^= star * 3266489917
	n ^= salt * 1274126177

	n = (n ^ (n >> 13)) * 1274126177
	n = n ^ (n >> 16)

	return float(n & 0x7fffffff) / 2147483647.0


func intro_reveal(tween: Tween) -> void:
	set_navigation_enabled(false)
	tween.tween_method(set_space_reveal, 0.0, 1.0, 0.7)
	tween.parallel().tween_method(set_nebula_reveal, 0.0, 0.65, 1.0)
	tween.parallel().tween_property(self, "star_reveal", 1.0, 0.9)


func set_navigation_enabled(enabled: bool) -> void:
	if background_paused:
		navigation_enabled = false
		return

	navigation_enabled = enabled

	if not enabled:
		_reset_touch_state()


func set_space_reveal(v: float) -> void:
	if _space_gradient_material != null:
		_space_gradient_material.set_shader_parameter("reveal", v)


func set_nebula_reveal(v: float) -> void:
	if _wave_nebula_material != null:
		_wave_nebula_material.set_shader_parameter("reveal", v)


func set_space_position(v: Vector2, immediate: bool = false) -> void:
	target_space_position = v
	_mark_stars_dirty()

	if immediate:
		space_position = v
		_force_chunk_rebuild()

	_apply_camera_view(0.0, true)


func set_space_zoom(v: float, _zoom_center_screen := Vector2.ZERO, immediate: bool = false) -> void:
	target_space_zoom = _clamp_raw_zoom(v)
	_mark_stars_dirty()

	if immediate:
		space_zoom = target_space_zoom

	_apply_camera_view(0.0, true)


func set_space_rotation(v: float, _rotation_center_screen := Vector2.ZERO, immediate: bool = false) -> void:
	target_space_rotation = wrapf(v, -PI, PI)
	_mark_stars_dirty()

	if immediate:
		space_rotation = target_space_rotation

	_apply_camera_view(0.0, true)


func handle_navigation_input(event: InputEvent) -> void:
	if background_paused:
		return

	if not navigation_enabled:
		return

	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		_handle_touch_input(event)


func _handle_touch_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_touches[event.index] = event.position
		else:
			_touches.erase(event.index)
			_last_pinch_distance = 0.0
			_last_pinch_center = Vector2.ZERO
			_last_pinch_angle = 0.0

		if _touches.size() == 1:
			_last_pinch_center = _get_touch_center()

	elif event is InputEventScreenDrag:
		_touches[event.index] = event.position

		if _touches.size() == 1:
			target_space_position -= _screen_delta_to_world(event.relative) * pan_sensitivity
			_mark_stars_dirty()
		elif _touches.size() >= 2:
			_update_two_finger_navigation()


func _update_two_finger_navigation() -> void:
	_touch_points_cache = _touches.values()

	if _touch_points_cache.size() < 2:
		return

	var a: Vector2 = _touch_points_cache[0]
	var b: Vector2 = _touch_points_cache[1]

	var distance: float = max(a.distance_to(b), 1.0)
	var raw_center := (a + b) * 0.5
	var angle := (b - a).angle()

	if _last_pinch_distance <= 0.0:
		_last_pinch_distance = distance
		_last_pinch_center = raw_center
		_last_pinch_angle = angle
		return

	var center := _last_pinch_center.lerp(raw_center, pinch_center_smoothness)

	var zoom_delta := log(distance / _last_pinch_distance)

	if abs(zoom_delta) > pinch_deadzone:
		var ratio := exp(zoom_delta * pinch_zoom_sensitivity)
		target_space_zoom = _clamp_raw_zoom(target_space_zoom * ratio)
		_mark_stars_dirty()

	var angle_delta := wrapf(angle - _last_pinch_angle, -PI, PI)

	if abs(angle_delta) > deg_to_rad(rotation_deadzone_deg):
		target_space_rotation = wrapf(target_space_rotation + angle_delta * rotation_sensitivity, -PI, PI)
		_mark_stars_dirty()

	var center_delta := center - _last_pinch_center

	if not center_delta.is_zero_approx():
		target_space_position -= _screen_delta_to_world(center_delta) * pan_sensitivity
		_mark_stars_dirty()

	_last_pinch_distance = distance
	_last_pinch_center = center
	_last_pinch_angle = angle


func _get_touch_center() -> Vector2:
	var result := Vector2.ZERO

	for p in _touches.values():
		result += p

	return result / max(_touches.size(), 1)


func _reset_touch_state() -> void:
	_touches.clear()
	_last_pinch_distance = 0.0
	_last_pinch_center = Vector2.ZERO
	_last_pinch_angle = 0.0


func set_external_navigation_touch(index: int, screen_position: Vector2, apply_gesture: bool = false) -> void:
	_touches[index] = screen_position

	if _touches.size() == 1:
		_last_pinch_center = _get_touch_center()
		return

	if apply_gesture and _touches.size() >= 2:
		_update_two_finger_navigation()


func remove_external_navigation_touch(index: int) -> void:
	if _touches.has(index):
		_touches.erase(index)

	_last_pinch_distance = 0.0
	_last_pinch_center = Vector2.ZERO
	_last_pinch_angle = 0.0

	if _touches.size() == 1:
		_last_pinch_center = _get_touch_center()


func _screen_delta_to_world(delta: Vector2) -> Vector2:
	var z := _get_visual_zoom(target_space_zoom)
	return delta.rotated(-target_space_rotation) / max(z, 0.001)


func _get_visual_zoom(raw_zoom: float) -> float:
	return lerp(1.0, _clamp_raw_zoom(raw_zoom), visual_zoom_strength)


func _get_star_size_zoom(visual_zoom: float) -> float:
	var size_zoom: float = max(1.0, lerp(1.0, visual_zoom, star_size_zoom_strength))
	return clamp(size_zoom, 1.0, 1.28)


func _smooth_camera(delta: float) -> void:
	target_space_zoom = _clamp_raw_zoom(target_space_zoom)

	if reduce_motion_enabled:
		var changed := space_position != target_space_position
		changed = changed or not is_equal_approx(space_zoom, target_space_zoom)
		changed = changed or not is_equal_approx(space_rotation, target_space_rotation)

		if changed:
			space_position = target_space_position
			space_zoom = target_space_zoom
			space_rotation = target_space_rotation
			_mark_stars_dirty()

		return

	var rot_difference := wrapf(target_space_rotation - space_rotation, -PI, PI)

	var at_rest := space_position == target_space_position
	at_rest = at_rest and is_equal_approx(space_zoom, target_space_zoom)
	at_rest = at_rest and is_equal_approx(rot_difference, 0.0)

	if at_rest:
		return

	var pos_t := 1.0 - exp(-camera_smooth_speed * delta)
	var zoom_t := 1.0 - exp(-zoom_smooth_speed * delta)
	var rot_t := 1.0 - exp(-rotation_smooth_speed * delta)

	space_position = space_position.lerp(target_space_position, pos_t)
	space_zoom = _clamp_raw_zoom(lerp(space_zoom, target_space_zoom, zoom_t))
	space_rotation = wrapf(space_rotation + rot_difference * rot_t, -PI, PI)

	if space_position.distance_squared_to(target_space_position) < 0.000001:
		space_position = target_space_position

	if abs(space_zoom - target_space_zoom) < 0.0001:
		space_zoom = target_space_zoom

	if abs(wrapf(target_space_rotation - space_rotation, -PI, PI)) < 0.0001:
		space_rotation = target_space_rotation

	_mark_stars_dirty()


func _update_nebula_drift(time: float) -> void:
	if reduce_motion_enabled:
		if not _nebula_locked_to_base:
			wave_nebula.position = nebula_base_position
			wave_nebula.scale = Vector2.ONE
			wave_nebula.rotation = 0.0
			_nebula_locked_to_base = true

		return

	_nebula_locked_to_base = false

	wave_nebula.position = nebula_base_position + Vector2(
		sin(time * nebula_drift_speed) * nebula_drift_strength,
		cos(time * nebula_drift_speed * 0.7) * nebula_drift_strength
	)


func _mark_stars_dirty() -> void:
	_stars_dirty = true


func _should_update_shader(delta: float, time: float) -> bool:
	if _star_material == null:
		return false

	if _stars_dirty:
		return true

	var visual_zoom := _get_visual_zoom(space_zoom)
	var star_size_zoom := _get_star_size_zoom(visual_zoom)
	var zoom_out_brightness: float = clamp(1.0 / max(visual_zoom, 0.65), 1.0, 1.25)

	if space_position != _last_shader_space_position:
		return true

	if not is_equal_approx(visual_zoom, _last_shader_visual_zoom):
		return true

	if not is_equal_approx(space_rotation, _last_shader_camera_rotation):
		return true

	if not is_equal_approx(star_size_zoom, _last_shader_star_size_zoom):
		return true

	if not is_equal_approx(star_reveal, _last_shader_star_reveal):
		return true

	if _screen_center != _last_shader_screen_center:
		return true

	if not is_equal_approx(zoom_out_brightness, _last_shader_zoom_out_brightness):
		return true

	var animation_now := star_animation_enabled and not reduce_motion_enabled

	if animation_now != _last_shader_animation_enabled:
		return true

	if not animation_now:
		return false

	_star_update_accum += delta
	var interval: float = 1.0 / max(star_update_hz, 1.0)

	if _star_update_accum < interval:
		return false

	_star_update_accum = 0.0

	var bucket := int(time / interval)
	if bucket == _last_shader_time_bucket:
		return false

	_last_shader_time_bucket = bucket
	return true


func _apply_camera_view(time: float = 0.0, force: bool = false) -> void:
	if _star_material == null:
		return

	space_zoom = _clamp_raw_zoom(space_zoom)
	target_space_zoom = _clamp_raw_zoom(target_space_zoom)

	var visual_zoom := _get_visual_zoom(space_zoom)
	var star_size_zoom := _get_star_size_zoom(visual_zoom)
	var zoom_out_brightness: float = clamp(1.0 / max(visual_zoom, 0.65), 1.0, 1.25)
	var animation_now := star_animation_enabled and not reduce_motion_enabled

	if force or _last_shader_space_position != space_position:
		_star_material.set_shader_parameter("camera_position", space_position)
		_last_shader_space_position = space_position

	if force or not is_equal_approx(_last_shader_visual_zoom, visual_zoom):
		_star_material.set_shader_parameter("visual_zoom", visual_zoom)
		_last_shader_visual_zoom = visual_zoom

	if force or not is_equal_approx(_last_shader_camera_rotation, space_rotation):
		_star_material.set_shader_parameter("camera_rotation", space_rotation)
		_last_shader_camera_rotation = space_rotation

	if force or not is_equal_approx(_last_shader_star_size_zoom, star_size_zoom):
		_star_material.set_shader_parameter("star_size_zoom", star_size_zoom)
		_last_shader_star_size_zoom = star_size_zoom

	if force or _last_shader_screen_center != _screen_center:
		_star_material.set_shader_parameter("screen_center", _screen_center)
		_last_shader_screen_center = _screen_center

	if force or not is_equal_approx(_last_shader_star_reveal, star_reveal):
		_star_material.set_shader_parameter("star_reveal", star_reveal)
		_last_shader_star_reveal = star_reveal

	if force or not is_equal_approx(_last_shader_zoom_out_brightness, zoom_out_brightness):
		_star_material.set_shader_parameter("zoom_out_brightness", zoom_out_brightness)
		_last_shader_zoom_out_brightness = zoom_out_brightness

	if force or animation_now != _last_shader_animation_enabled:
		_star_material.set_shader_parameter("animation_enabled", animation_now)
		_last_shader_animation_enabled = animation_now

	if animation_now:
		_star_material.set_shader_parameter("time_seconds", time)

	_stars_dirty = false


func space_to_screen(world_pos: Vector2) -> Vector2:
	var visual_zoom := _get_visual_zoom(space_zoom)

	var local := world_pos - space_position

	var cosr := cos(space_rotation)
	var sinr := sin(space_rotation)

	var rx := local.x * cosr - local.y * sinr
	var ry := local.x * sinr + local.y * cosr

	return _screen_center + Vector2(rx, ry) * visual_zoom


func reset_navigation_view() -> void:
	space_position = Vector2.ZERO
	target_space_position = Vector2.ZERO

	space_zoom = 1.0
	target_space_zoom = 1.0

	space_rotation = 0.0
	target_space_rotation = 0.0

	_mark_stars_dirty()
	_force_chunk_rebuild()
	_apply_camera_view(0.0, true)
