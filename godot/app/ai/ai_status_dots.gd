extends Control
class_name AIStatusDots

const IDLE_COLOR := Color("#B8B8B8")
const LISTENING_COLOR := Color("#FFB347")
const THINKING_COLOR := Color("#35D6C8")
const SPEAKING_COLOR := Color("#9B6DFF")

const DOT_COUNT := 3
const ELLIPSE_SEGMENTS := 42

const PHASE_OFFSETS: Array[float] = [0.0, PI / 1.5, PI]
const Y_AMPLITUDES: Array[float] = [0.55, 0.35, 0.65]
const X_AMPLITUDES: Array[float] = [0.08, 0.05, 0.1]

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
var _ellipse_points := PackedVector2Array()
var _unit_circle_points := PackedVector2Array()

var _base_centers: Array[Vector2] = []
var _cached_size := Vector2.ZERO


func _ready() -> void:
	custom_minimum_size = Vector2(270, 125)
	size = Vector2(270, 125)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_build_unit_circle()
	_setup_background_style()
	_update_base_centers()

	if not resized.is_connected(_on_resized):
		resized.connect(_on_resized)

	if not AIState.state_changed.is_connected(_on_state_changed):
		AIState.state_changed.connect(_on_state_changed)


func _process(delta: float) -> void:
	anim_time += delta

	if transition_progress < 1.0:
		transition_progress = min(transition_progress + delta / transition_duration, 1.0)

	queue_redraw()


func _on_resized() -> void:
	_update_base_centers()
	queue_redraw()


func _on_state_changed(new_state: AIState.State) -> void:
	if current_state == new_state:
		return

	from_state = current_state
	from_style = _current_blended_style()

	current_state = new_state
	to_style = _style_for_state(new_state)

	transition_progress = 0.0


func _draw() -> void:
	var blend: float = _smoothest(transition_progress)

	var border_color: Color = from_style.color.lerp(to_style.color, blend)
	var border_opacity: float = lerpf(from_style.opacity, to_style.opacity, blend)

	_update_background_style(border_color, border_opacity)
	draw_style_box(_background_style, Rect2(Vector2.ZERO, size))

	for i in range(DOT_COUNT):
		_draw_dot(i, _base_centers[i], blend)


func _draw_dot(index: int, base_center: Vector2, blend: float) -> void:
	var flicker: float = _dot_flicker(index)

	var opacity: float = lerpf(
		flicker * from_style.opacity,
		flicker * to_style.opacity,
		blend
	)

	var color: Color = from_style.color.lerp(to_style.color, blend)
	color.a = opacity

	var size_blend: float = lerpf(from_style.size, to_style.size, blend)
	var base_scale: float = 0.86 + flicker * 0.14

	var thinking_wave: float = sin(anim_time * TAU * 0.42 + float(index) * PI / 1.5) * 12.0
	var from_wave: float = thinking_wave if from_state == AIState.State.THINKING else 0.0
	var to_wave: float = thinking_wave if current_state == AIState.State.THINKING else 0.0
	var offset_y: float = lerpf(from_wave, to_wave, blend)

	var speaking_blend: float = 0.0
	if from_state == AIState.State.SPEAKING or current_state == AIState.State.SPEAKING:
		speaking_blend = blend if current_state == AIState.State.SPEAKING else 1.0 - blend

	var speaking_wave: float = sin(anim_time * PI * 1.45 + PHASE_OFFSETS[index])

	var scale_y: float = 1.0 + Y_AMPLITUDES[index] * speaking_wave * speaking_blend
	var scale_x: float = 0.95 + X_AMPLITUDES[index] * -speaking_wave * speaking_blend

	var center: Vector2 = base_center + Vector2(0.0, -offset_y)
	var radius_x: float = size_blend * 0.5 * base_scale * scale_x
	var radius_y: float = size_blend * 0.5 * base_scale * scale_y

	_draw_glow(center, radius_x, radius_y, color)
	_draw_custom_ellipse(center, radius_x, radius_y, color)


func _dot_flicker(index: int) -> float:
	var phase: float = fmod(anim_time / 2.5 + float(index) * 0.33, 1.0)

	if phase < 0.33:
		return lerpf(0.3, 1.0, _smoothest(phase / 0.33))

	return lerpf(1.0, 0.3, _smoothest((phase - 0.33) / 0.67))


func _draw_glow(center: Vector2, radius_x: float, radius_y: float, color: Color) -> void:
	var glow := color
	glow.a *= 0.25
	_draw_custom_ellipse(center, radius_x + 10.0, radius_y + 10.0, glow)


func _draw_custom_ellipse(center: Vector2, radius_x: float, radius_y: float, color: Color) -> void:
	for i in range(ELLIPSE_SEGMENTS):
		var unit := _unit_circle_points[i]
		_ellipse_points[i] = center + Vector2(unit.x * radius_x, unit.y * radius_y)

	draw_colored_polygon(_ellipse_points, color)


func _build_unit_circle() -> void:
	_unit_circle_points.resize(ELLIPSE_SEGMENTS)
	_ellipse_points.resize(ELLIPSE_SEGMENTS)

	for i in range(ELLIPSE_SEGMENTS):
		var angle: float = TAU * float(i) / float(ELLIPSE_SEGMENTS)
		_unit_circle_points[i] = Vector2(cos(angle), sin(angle))
		_ellipse_points[i] = Vector2.ZERO


func _update_base_centers() -> void:
	_base_centers.clear()

	var center_y: float = size.y * 0.5
	var total_width: float = dot_size * 3.0 + dot_gap * 2.0
	var start_x: float = size.x * 0.5 - total_width * 0.5 + dot_size * 0.5

	for i in range(DOT_COUNT):
		_base_centers.append(Vector2(start_x + float(i) * (dot_size + dot_gap), center_y))


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


func _update_background_style(border_color: Color, border_opacity: float) -> void:
	var border := border_color
	border.a = max(0.3, border_opacity)
	_background_style.border_color = border


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
	var blend: float = _smoothest(transition_progress)

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
