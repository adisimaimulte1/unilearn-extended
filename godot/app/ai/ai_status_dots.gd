extends Control
class_name AIStatusDots

const IDLE_COLOR := Color("#B8B8B8")
const LISTENING_COLOR := Color("#FFB347")
const THINKING_COLOR := Color("#35D6C8")
const SPEAKING_COLOR := Color("#9B6DFF")

const DOT_COUNT := 3

const IDLE_ANIMATION_FPS := 14.0
const LISTENING_ANIMATION_FPS := 24.0
const THINKING_ANIMATION_FPS := 30.0
const SPEAKING_ANIMATION_FPS := 30.0
const TRANSITION_ANIMATION_FPS := 30.0

const DOT_PHASE_0 := 0.0
const DOT_PHASE_1 := PI / 1.5
const DOT_PHASE_2 := PI

const Y_AMP_0 := 0.55
const Y_AMP_1 := 0.35
const Y_AMP_2 := 0.65

const X_AMP_0 := 0.08
const X_AMP_1 := 0.05
const X_AMP_2 := 0.10

const THINKING_SPEED := TAU * 0.42
const SPEAKING_SPEED := PI * 1.45
const FLICKER_DURATION := 2.5
const FLICKER_STEP := 0.33

const DOT_TEXTURE_SIZE := 96
const GLOW_EXTRA_SIZE := 20.0
const GLOW_ALPHA_MULTIPLIER := 0.25

var dot_size: float = 44.0
var dot_gap: float = 20.0
var corner_radius: int = 44

var transition_duration: float = 0.85

var anim_time: float = 0.0
var transition_progress: float = 1.0

var current_state: AIState.State = AIState.State.IDLE
var from_state: AIState.State = AIState.State.IDLE

var from_style := _DotStyle.new(IDLE_COLOR, 0.3, dot_size)
var to_style := _DotStyle.new(IDLE_COLOR, 0.3, dot_size)

var _background_style := StyleBoxFlat.new()
var _dot_texture: Texture2D = null

var _base_centers: Array[Vector2] = []
var _dot_bodies: Array[TextureRect] = []
var _dot_glows: Array[TextureRect] = []

var _redraw_accumulator: float = 0.0
var _redraw_requested := true
var _current_frame_time := 1.0 / IDLE_ANIMATION_FPS

var _last_border_color := Color.TRANSPARENT
var _last_border_opacity := -1.0


func _ready() -> void:
	custom_minimum_size = Vector2(270, 125)
	size = Vector2(270, 125)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = false

	_dot_texture = _make_dot_texture()

	_setup_background_style()
	_update_base_centers()
	_build_dot_nodes()
	_update_frame_time()

	if not resized.is_connected(_on_resized):
		resized.connect(_on_resized)

	if not visibility_changed.is_connected(_on_visibility_changed):
		visibility_changed.connect(_on_visibility_changed)

	if not AIState.state_changed.is_connected(_on_state_changed):
		AIState.state_changed.connect(_on_state_changed)

	set_process(is_visible_in_tree())
	_apply_visual_state(true)


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		set_process(false)
		return

	anim_time += delta

	if transition_progress < 1.0:
		transition_progress = min(transition_progress + delta / transition_duration, 1.0)
		_redraw_requested = true

		if transition_progress >= 1.0:
			_update_frame_time()

	_redraw_accumulator += delta

	if _redraw_requested or _redraw_accumulator >= _current_frame_time:
		_redraw_requested = false
		_redraw_accumulator = 0.0
		_apply_visual_state(false)


func _draw() -> void:
	draw_style_box(_background_style, Rect2(Vector2.ZERO, size))


func _on_resized() -> void:
	_update_base_centers()
	_apply_visual_state(true)


func _on_visibility_changed() -> void:
	var visible_now := is_visible_in_tree()
	set_process(visible_now)

	if visible_now:
		_redraw_accumulator = _current_frame_time
		_apply_visual_state(true)


func _on_state_changed(new_state: AIState.State) -> void:
	if current_state == new_state:
		return

	from_state = current_state
	from_style = _current_blended_style()

	current_state = new_state
	to_style = _style_for_state(new_state)

	transition_progress = 0.0
	_update_frame_time()

	set_process(is_visible_in_tree())
	_apply_visual_state(true)


func _update_frame_time() -> void:
	var fps := IDLE_ANIMATION_FPS

	if transition_progress < 1.0:
		fps = TRANSITION_ANIMATION_FPS
	else:
		match current_state:
			AIState.State.LISTENING:
				fps = LISTENING_ANIMATION_FPS

			AIState.State.THINKING:
				fps = THINKING_ANIMATION_FPS

			AIState.State.SPEAKING:
				fps = SPEAKING_ANIMATION_FPS

			_:
				fps = IDLE_ANIMATION_FPS

	_current_frame_time = 1.0 / max(fps, 1.0)


func _apply_visual_state(force_redraw: bool) -> void:
	if _base_centers.size() < DOT_COUNT:
		return

	var blend := _smoothest(transition_progress)

	var color := from_style.color.lerp(to_style.color, blend)
	var opacity := lerpf(from_style.opacity, to_style.opacity, blend)
	var size_blend := lerpf(from_style.size, to_style.size, blend)

	_update_background_style_if_needed(color, opacity, force_redraw)

	_apply_dot_fast(0, _base_centers[0], blend, color, size_blend)
	_apply_dot_fast(1, _base_centers[1], blend, color, size_blend)
	_apply_dot_fast(2, _base_centers[2], blend, color, size_blend)


func _apply_dot_fast(index: int, base_center: Vector2, blend: float, base_color: Color, size_blend: float) -> void:
	var body := _dot_bodies[index]
	var glow := _dot_glows[index]

	var flicker := _dot_flicker(index)

	var from_opacity := flicker * from_style.opacity
	var to_opacity := flicker * to_style.opacity

	var body_color := base_color
	body_color.a = lerpf(from_opacity, to_opacity, blend)

	var glow_color := body_color
	glow_color.a *= GLOW_ALPHA_MULTIPLIER

	var base_scale := 0.86 + flicker * 0.14

	var phase := _phase_for_index(index)

	var thinking_wave := sin(anim_time * THINKING_SPEED + phase) * 12.0
	var from_wave := thinking_wave if from_state == AIState.State.THINKING else 0.0
	var to_wave := thinking_wave if current_state == AIState.State.THINKING else 0.0
	var offset_y := lerpf(from_wave, to_wave, blend)

	var speaking_blend := 0.0

	if from_state == AIState.State.SPEAKING or current_state == AIState.State.SPEAKING:
		speaking_blend = blend if current_state == AIState.State.SPEAKING else 1.0 - blend

	var speaking_wave := sin(anim_time * SPEAKING_SPEED + phase)

	var scale_y := 1.0 + _y_amp_for_index(index) * speaking_wave * speaking_blend
	var scale_x := 0.95 + _x_amp_for_index(index) * -speaking_wave * speaking_blend

	var center := base_center + Vector2(0.0, -offset_y)
	var half_size := size_blend * 0.5 * base_scale

	var body_size := Vector2(
		max(1.0, half_size * 2.0 * scale_x),
		max(1.0, half_size * 2.0 * scale_y)
	)

	var glow_size := body_size + Vector2(GLOW_EXTRA_SIZE, GLOW_EXTRA_SIZE)

	_apply_texture_rect(body, center, body_size, body_color)
	_apply_texture_rect(glow, center, glow_size, glow_color)


func _apply_texture_rect(rect: TextureRect, center: Vector2, rect_size: Vector2, color: Color) -> void:
	rect.position = center - rect_size * 0.5
	rect.size = rect_size
	rect.modulate = color


func _build_dot_nodes() -> void:
	for child in get_children():
		child.queue_free()

	_dot_bodies.clear()
	_dot_glows.clear()

	for i in range(DOT_COUNT):
		var glow := _make_dot_rect("DotGlow_%d" % i)
		_dot_glows.append(glow)
		add_child(glow)

	for i in range(DOT_COUNT):
		var body := _make_dot_rect("DotBody_%d" % i)
		_dot_bodies.append(body)
		add_child(body)


func _make_dot_rect(node_name: String) -> TextureRect:
	var rect := TextureRect.new()
	rect.name = node_name
	rect.texture = _dot_texture
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	return rect


func _make_dot_texture() -> Texture2D:
	var image := Image.create(DOT_TEXTURE_SIZE, DOT_TEXTURE_SIZE, false, Image.FORMAT_RGBA8)
	var center := Vector2(DOT_TEXTURE_SIZE, DOT_TEXTURE_SIZE) * 0.5
	var radius := float(DOT_TEXTURE_SIZE) * 0.5 - 2.0

	for y in range(DOT_TEXTURE_SIZE):
		for x in range(DOT_TEXTURE_SIZE):
			var p := Vector2(float(x) + 0.5, float(y) + 0.5)
			var dist := p.distance_to(center)

			var alpha := 1.0 - smoothstep(radius - 1.5, radius + 1.5, dist)
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))

	return ImageTexture.create_from_image(image)


func _phase_for_index(index: int) -> float:
	match index:
		1:
			return DOT_PHASE_1

		2:
			return DOT_PHASE_2

		_:
			return DOT_PHASE_0


func _y_amp_for_index(index: int) -> float:
	match index:
		1:
			return Y_AMP_1

		2:
			return Y_AMP_2

		_:
			return Y_AMP_0


func _x_amp_for_index(index: int) -> float:
	match index:
		1:
			return X_AMP_1

		2:
			return X_AMP_2

		_:
			return X_AMP_0


func _dot_flicker(index: int) -> float:
	var phase := anim_time / FLICKER_DURATION + float(index) * FLICKER_STEP
	phase -= floor(phase)

	if phase < 0.33:
		return lerpf(0.3, 1.0, _smoothest(phase / 0.33))

	return lerpf(1.0, 0.3, _smoothest((phase - 0.33) / 0.67))


func _update_base_centers() -> void:
	_base_centers.clear()

	var center_y := size.y * 0.5
	var total_width := dot_size * 3.0 + dot_gap * 2.0
	var start_x := size.x * 0.5 - total_width * 0.5 + dot_size * 0.5

	_base_centers.append(Vector2(start_x, center_y))
	_base_centers.append(Vector2(start_x + dot_size + dot_gap, center_y))
	_base_centers.append(Vector2(start_x + (dot_size + dot_gap) * 2.0, center_y))


func _setup_background_style() -> void:
	_background_style.bg_color = Color(0, 0, 0, 0)

	_background_style.border_width_left = 5
	_background_style.border_width_right = 5
	_background_style.border_width_top = 5
	_background_style.border_width_bottom = 5

	_background_style.corner_radius_top_left = corner_radius
	_background_style.corner_radius_top_right = corner_radius
	_background_style.corner_radius_bottom_left = corner_radius
	_background_style.corner_radius_bottom_right = corner_radius


func _update_background_style_if_needed(border_color: Color, border_opacity: float, force_redraw: bool) -> void:
	var border := border_color
	border.a = max(0.3, border_opacity)

	var changed := force_redraw
	changed = changed or border != _last_border_color
	changed = changed or not is_equal_approx(border.a, _last_border_opacity)

	if not changed:
		return

	_background_style.border_color = border
	_last_border_color = border
	_last_border_opacity = border.a
	queue_redraw()


func _style_for_state(state: AIState.State) -> _DotStyle:
	match state:
		AIState.State.LISTENING:
			return _DotStyle.new(LISTENING_COLOR, 0.75, dot_size)

		AIState.State.THINKING:
			return _DotStyle.new(THINKING_COLOR, 1.0, dot_size)

		AIState.State.SPEAKING:
			return _DotStyle.new(SPEAKING_COLOR, 1.0, dot_size)

		_:
			return _DotStyle.new(IDLE_COLOR, 0.35, dot_size)


func _current_blended_style() -> _DotStyle:
	var blend := _smoothest(transition_progress)

	return _DotStyle.new(
		from_style.color.lerp(to_style.color, blend),
		lerpf(from_style.opacity, to_style.opacity, blend),
		lerpf(from_style.size, to_style.size, blend)
	)


func _smoothest(t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	return t * t * t * (t * (t * 6.0 - 15.0) + 10.0)


class _DotStyle:
	var color: Color
	var opacity: float
	var size: float

	func _init(_color: Color, _opacity: float, _size: float) -> void:
		color = _color
		opacity = _opacity
		size = _size
