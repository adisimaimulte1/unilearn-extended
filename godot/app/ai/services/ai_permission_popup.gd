extends CanvasLayer
class_name AIPermissionPopup

signal closed(should_quit: bool)

const FONT_PATH := "res://assets/fonts/JockeyOne-Regular.ttf"

const POPUP_SLIDE_DURATION := 0.72
const POPUP_FADE_DURATION := 0.38
const DIM_FADE_DURATION := 0.58
const POPUP_SIDE_PADDING := 80.0

const BUTTON_PRESS_SCALE := Vector2(0.94, 0.94)
const BUTTON_RELEASE_SCALE := Vector2(1.07, 1.07)

const COLOR_ON := Color.WHITE
const COLOR_OFF := Color("#FF4D5E")

var title_text: String = ""
var body_text: String = ""
var button_text: String = "Close App"
var quit_on_confirm: bool = true

var _root: Control
var _dim: ColorRect
var _slide_root: Control
var _panel: PanelContainer
var _button: Button
var _dots: PermissionThinkingDots

var _accent_color := COLOR_ON
var _closing := false
var _center_position := Vector2.ZERO
var _button_tween: Tween
var _popup_tween: Tween


func setup(
	_title_text: String,
	_body_text: String,
	_button_text: String,
	_quit_on_confirm: bool,
	_is_permission_rejected: bool = false
) -> void:
	title_text = _title_text
	body_text = _body_text
	button_text = _button_text
	quit_on_confirm = _quit_on_confirm

	_accent_color = COLOR_OFF if _is_permission_rejected else COLOR_ON



func _ready() -> void:
	layer = 9999

	_build_ui()

	await get_tree().process_frame
	await get_tree().process_frame

	_prepare_center_position()
	_play_intro()


func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	_dim = ColorRect.new()
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.color = Color(0, 0, 0, 0)
	_root.add_child(_dim)

	_slide_root = Control.new()
	_slide_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_slide_root)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(900, 0)
	_panel.add_theme_stylebox_override("panel", _panel_style())
	_slide_root.add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 64)
	margin.add_theme_constant_override("margin_right", 64)
	margin.add_theme_constant_override("margin_top", 58)
	margin.add_theme_constant_override("margin_bottom", 52)
	_panel.add_child(margin)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 34)
	margin.add_child(box)

	_dots = PermissionThinkingDots.new()
	_dots.custom_minimum_size = Vector2(280, 92)
	_dots.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_dots.dot_color = _accent_color
	box.add_child(_dots)

	var title := Label.new()
	title.text = title_text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_size_override("font_size", 76)
	title.add_theme_color_override("font_color", _accent_color)
	_apply_app_font(title)
	box.add_child(title)

	var underline := ColorRect.new()
	underline.custom_minimum_size = Vector2(280, 8)
	underline.color = _accent_color
	underline.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(underline)

	var body := Label.new()
	body.text = body_text
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size", 52)
	var body_color := _accent_color.lightened(0.18)
	body_color.a = 0.88
	body.add_theme_color_override("font_color", body_color)
	body.custom_minimum_size = Vector2(760, 0)
	box.add_child(body)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 12)
	box.add_child(spacer)

	_button = Button.new()
	_button.text = button_text
	_button.custom_minimum_size = Vector2(460, 116)
	_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_button.add_theme_font_size_override("font_size", 56)
	_button.add_theme_color_override("font_color", _accent_color)
	_button.add_theme_color_override("font_hover_color", _accent_color)
	_button.add_theme_color_override("font_pressed_color", _accent_color)
	_button.add_theme_color_override("font_disabled_color", _accent_color)

	var button_normal := _button_style(Color(_accent_color.r, _accent_color.g, _accent_color.b, 0.0))
	var button_hover := _button_style(Color(_accent_color.r, _accent_color.g, _accent_color.b, 0.08))

	_button.add_theme_stylebox_override("normal", button_normal)
	_button.add_theme_stylebox_override("hover", button_hover)
	_button.add_theme_stylebox_override("pressed", button_normal)
	_button.add_theme_stylebox_override("focus", button_normal)
	_button.add_theme_stylebox_override("disabled", button_normal)

	_apply_app_font(_button)

	_button.button_down.connect(_on_button_down)
	_button.button_up.connect(_on_button_up)

	box.add_child(_button)

	_panel.position = Vector2.ZERO
	_slide_root.modulate.a = 0.0


func _prepare_center_position() -> void:
	var viewport_size := get_viewport().get_visible_rect().size

	_panel.size = _panel.get_combined_minimum_size()
	_slide_root.size = _panel.size

	_center_position = (viewport_size - _slide_root.size) * 0.5

	_slide_root.position = _center_position
	_panel.position = Vector2.ZERO

	_button.pivot_offset = _button.size * 0.5


func _play_intro() -> void:
	_dots.intro_boost()

	if _popup_tween:
		_popup_tween.kill()

	_slide_root.position = _get_left_offscreen_position()
	_slide_root.modulate.a = 0.0
	_dim.color = Color(0, 0, 0, 0)

	_popup_tween = create_tween()
	_popup_tween.set_parallel(true)

	# Slide in: fast at first, then gently decelerates into center.
	_popup_tween.tween_property(_slide_root, "position", _center_position, POPUP_SLIDE_DURATION)\
		.set_trans(Tween.TRANS_CUBIC)\
		.set_ease(Tween.EASE_OUT)

	_popup_tween.tween_property(_slide_root, "modulate:a", 1.0, POPUP_FADE_DURATION)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_OUT)

	_popup_tween.tween_property(_dim, "color", Color(0, 0, 0, 0.84), DIM_FADE_DURATION)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_OUT)


func _on_button_down() -> void:
	if _closing:
		return

	_button.pivot_offset = _button.size * 0.5
	_tween_button_scale(BUTTON_PRESS_SCALE, 0.08)


func _on_button_up() -> void:
	if _closing:
		return

	_closing = true
	_button.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Do not boost the dots on close.
	# Keeping their energy untouched makes the exit feel continuous and smooth.

	_button.pivot_offset = _button.size * 0.5

	_tween_button_scale(BUTTON_RELEASE_SCALE, 0.10)
	await get_tree().create_timer(0.10).timeout

	_tween_button_scale(Vector2.ONE, 0.12)
	await get_tree().create_timer(0.08).timeout

	if _popup_tween:
		_popup_tween.kill()

	_slide_root.position = _center_position
	_slide_root.modulate.a = 1.0

	_popup_tween = create_tween()
	_popup_tween.set_parallel(true)

	# Slide out: gentle start, then accelerates out.
	_popup_tween.tween_property(_slide_root, "position", _get_right_offscreen_position(), POPUP_SLIDE_DURATION)\
		.set_trans(Tween.TRANS_CUBIC)\
		.set_ease(Tween.EASE_IN)

	# Fade near the end so the actual slide remains visible.
	_popup_tween.tween_property(_slide_root, "modulate:a", 0.0, POPUP_FADE_DURATION)\
		.set_delay(POPUP_SLIDE_DURATION - POPUP_FADE_DURATION)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN)

	_popup_tween.tween_property(_dim, "color", Color(0, 0, 0, 0.0), DIM_FADE_DURATION)\
		.set_delay(POPUP_SLIDE_DURATION - DIM_FADE_DURATION)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN)

	await _popup_tween.finished

	closed.emit(quit_on_confirm)
	queue_free()


func _get_left_offscreen_position() -> Vector2:
	return Vector2(
		-_slide_root.size.x - POPUP_SIDE_PADDING,
		_center_position.y
	)


func _get_right_offscreen_position() -> Vector2:
	return Vector2(
		get_viewport().get_visible_rect().size.x + POPUP_SIDE_PADDING,
		_center_position.y
	)


func _tween_button_scale(target_scale: Vector2, duration: float) -> void:
	if _button_tween:
		_button_tween.kill()

	_button_tween = create_tween()
	_button_tween.set_trans(Tween.TRANS_BACK)
	_button_tween.set_ease(Tween.EASE_OUT)
	_button_tween.tween_property(_button, "scale", target_scale, duration)


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()

	style.bg_color = Color(0.0, 0.0, 0.0, 0.70)
	style.border_color = _accent_color

	style.border_width_left = 5
	style.border_width_right = 5
	style.border_width_top = 5
	style.border_width_bottom = 5

	style.corner_radius_top_left = 48
	style.corner_radius_top_right = 48
	style.corner_radius_bottom_left = 48
	style.corner_radius_bottom_right = 48

	style.shadow_color = Color(0, 0, 0, 0.76)
	style.shadow_size = 38
	style.shadow_offset = Vector2(0, 16)

	return style


func _button_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()

	style.bg_color = color
	style.border_color = _accent_color

	style.border_width_left = 5
	style.border_width_right = 5
	style.border_width_top = 5
	style.border_width_bottom = 5

	style.corner_radius_top_left = 38
	style.corner_radius_top_right = 38
	style.corner_radius_bottom_left = 38
	style.corner_radius_bottom_right = 38

	style.content_margin_left = 44
	style.content_margin_right = 44
	style.content_margin_top = 28
	style.content_margin_bottom = 28

	return style


func _apply_app_font(control: Control) -> void:
	var font := load(FONT_PATH) as Font
	if font != null:
		control.add_theme_font_override("font", font)


class PermissionThinkingDots:
	extends Control

	var dot_size: float = 38.0
	var dot_gap: float = 26.0
	var anim_time: float = 0.0
	var energy: float = 1.0
	var dot_color: Color = Color.WHITE

	func intro_boost() -> void:
		energy = 1.45

	func _process(delta: float) -> void:
		anim_time += delta
		energy = lerpf(energy, 1.0, delta * 2.4)
		queue_redraw()

	func _draw() -> void:
		var total_width := dot_size * 3.0 + dot_gap * 2.0
		var start_x := size.x * 0.5 - total_width * 0.5 + dot_size * 0.5
		var base_y := size.y * 0.5

		for i in range(3):
			var phase := anim_time * TAU * 0.32 + float(i) * PI / 1.5
			var wave := sin(phase)
			var pulse_wave := sin(phase + PI * 0.5)

			var y_offset := wave * 12.0 * energy
			var pulse := 0.86 + pulse_wave * 0.14
			var radius := dot_size * 0.5 * pulse

			var center := Vector2(
				start_x + float(i) * (dot_size + dot_gap),
				base_y + y_offset
			)

			draw_circle(center, radius + 12.0 * energy, Color(dot_color.r, dot_color.g, dot_color.b, 0.18))
			draw_circle(center, radius, Color(dot_color.r, dot_color.g, dot_color.b, 0.94))
