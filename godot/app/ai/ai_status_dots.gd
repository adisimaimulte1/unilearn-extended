extends Control
class_name AIStatusDots

const IDLE_COLOR := Color("#B8B8B8")
const LISTENING_COLOR := Color("#FFB347")
const THINKING_COLOR := Color("#35D6C8")
const SPEAKING_COLOR := Color("#9B6DFF")

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


func _ready() -> void:
	custom_minimum_size = Vector2(270, 125)
	size = Vector2(270, 125)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	AIState.state_changed.connect(_on_state_changed)


func _process(delta: float) -> void:
	anim_time += delta
	transition_progress = min(transition_progress + delta / transition_duration, 1.0)
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

	draw_style_box(
		_get_background_style(border_color, border_opacity),
		Rect2(Vector2.ZERO, size)
	)

	var center_y: float = size.y * 0.5
	var total_width: float = dot_size * 3.0 + dot_gap * 2.0
	var start_x: float = size.x * 0.5 - total_width * 0.5 + dot_size * 0.5

	for i in range(3):
		_draw_dot(i, Vector2(start_x + float(i) * (dot_size + dot_gap), center_y))


func _draw_dot(index: int, base_center: Vector2) -> void:
	var blend: float = _smoothest(transition_progress)
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

	var phase_offsets: Array[float] = [0.0, PI / 1.5, PI]
	var y_amplitudes: Array[float] = [0.55, 0.35, 0.65]
	var x_amplitudes: Array[float] = [0.08, 0.05, 0.1]

	var speaking_wave: float = sin(anim_time * PI * 1.45 + phase_offsets[index])

	var scale_y: float = 1.0 + y_amplitudes[index] * speaking_wave * speaking_blend
	var scale_x: float = 0.95 + x_amplitudes[index] * -speaking_wave * speaking_blend

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
	var glow: Color = color
	glow.a *= 0.25
	_draw_custom_ellipse(center, radius_x + 10.0, radius_y + 10.0, glow)


func _draw_custom_ellipse(center: Vector2, radius_x: float, radius_y: float, color: Color) -> void:
	var points := PackedVector2Array()

	for i in range(42):
		var angle: float = TAU * float(i) / 42.0
		points.append(center + Vector2(cos(angle) * radius_x, sin(angle) * radius_y))

	draw_colored_polygon(points, color)


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


func _get_background_style(border_color: Color, border_opacity: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()

	style.bg_color = Color(0, 0, 0, 0)

	var border: Color = border_color
	border.a = max(0.3, border_opacity)

	style.border_width_left = 5
	style.border_width_right = 5
	style.border_width_top = 5
	style.border_width_bottom = 5
	style.border_color = border

	style.corner_radius_top_left = corner_radius
	style.corner_radius_top_right = corner_radius
	style.corner_radius_bottom_left = corner_radius
	style.corner_radius_bottom_right = corner_radius

	return style


class _DotStyle:
	var color: Color
	var opacity: float
	var size: float

	func _init(_color: Color, _opacity: float, _size: float) -> void:
		color = _color
		opacity = _opacity
		size = _size
