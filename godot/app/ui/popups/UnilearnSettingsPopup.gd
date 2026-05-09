extends CanvasLayer
class_name UnilearnSettingsPopup

signal sfx_changed(enabled: bool)
signal apollo_changed(enabled: bool)
signal reduce_motion_changed(enabled: bool)
signal reset_camera_requested
signal logout_requested
signal closed

const FONT_PATH := "res://assets/fonts/JockeyOne-Regular.ttf"

const POPUP_SLIDE_DURATION := 0.42
const POPUP_FADE_DURATION := 0.22
const DIM_FADE_DURATION := 0.26
const POPUP_SIDE_PADDING := 80.0

const BUTTON_PRESS_SCALE := Vector2(0.88, 0.88)
const BUTTON_RELEASE_SCALE := Vector2(1.10, 1.10)

const COLOR_ON := Color.WHITE
const COLOR_OFF := Color("#FF4D5E")

@export var panel_width_ratio: float = 0.84
@export var panel_max_width: float = 820.0
@export var button_height: float = 116.0
@export var button_font_size: int = 54
@export var panel_padding_x: int = 52
@export var panel_padding_y: int = 48

var sfx_enabled: bool = true
var apollo_enabled: bool = true
var reduce_motion_enabled: bool = false

var _root: Control
var _dim: ColorRect
var _slide_root: Control
var _panel: PanelContainer
var _content: VBoxContainer

var _sfx_button: Button
var _apollo_button: Button
var _motion_button: Button
var _reset_button: Button
var _logout_button: Button

var _center_position := Vector2.ZERO
var _closing := false
var _popup_tween: Tween
var _button_tween: Tween
var _app_font: Font = null


func _motion_duration(duration: float) -> float:
	return 0.0 if reduce_motion_enabled else duration


func _should_reduce_motion() -> bool:
	return reduce_motion_enabled


func setup(
	_sfx_enabled: bool = true,
	_apollo_enabled: bool = true,
	_reduce_motion_enabled: bool = false
) -> void:
	sfx_enabled = _sfx_enabled
	apollo_enabled = _apollo_enabled
	reduce_motion_enabled = _reduce_motion_enabled

	if is_inside_tree():
		_update_button_texts()


func _ready() -> void:
	layer = 1200
	process_mode = Node.PROCESS_MODE_ALWAYS

	_app_font = load(FONT_PATH) as Font

	_build_ui()

	await get_tree().process_frame
	await get_tree().process_frame

	_prepare_center_position()
	_play_intro()


func _notification(what: int) -> void:
	if what == Control.NOTIFICATION_RESIZED:
		await get_tree().process_frame
		_prepare_center_position()


func close_popup(action_after_close: String = "") -> void:
	if _closing:
		return

	_closing = true
	_play_sfx("close")

	if action_after_close == "reset_camera":
		reset_camera_requested.emit()
		action_after_close = ""

	if _popup_tween:
		_popup_tween.kill()

	if not is_inside_tree() or get_viewport() == null:
		if action_after_close == "logout":
			logout_requested.emit()

		closed.emit()
		queue_free()
		return

	if _should_reduce_motion():
		_slide_root.position = _center_position
		_slide_root.modulate.a = 0.0
		_dim.modulate.a = 0.0

		if action_after_close == "logout":
			logout_requested.emit()

		closed.emit()
		queue_free()
		return

	_slide_root.position = _center_position
	_slide_root.modulate.a = 1.0

	_popup_tween = create_tween()
	_popup_tween.set_parallel(true)

	_popup_tween.tween_property(_slide_root, "position", _get_right_offscreen_position(), POPUP_SLIDE_DURATION)\
		.set_trans(Tween.TRANS_CUBIC)\
		.set_ease(Tween.EASE_IN)

	_popup_tween.tween_property(_slide_root, "modulate:a", 0.0, POPUP_FADE_DURATION)\
		.set_delay(max(0.0, POPUP_SLIDE_DURATION - POPUP_FADE_DURATION))\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN)

	_popup_tween.tween_property(_dim, "modulate:a", 0.0, DIM_FADE_DURATION)\
		.set_delay(max(0.0, POPUP_SLIDE_DURATION - DIM_FADE_DURATION))\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN)

	await _popup_tween.finished

	if action_after_close == "logout":
		logout_requested.emit()

	closed.emit()
	queue_free()


func _build_ui() -> void:
	_root = Control.new()
	_root.name = "SettingsPopupRoot"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	_dim = ColorRect.new()
	_dim.name = "TapOutsideDim"
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.color = Color(0, 0, 0, 0.84)
	_dim.modulate.a = 0.0
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(_dim)

	_dim.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventScreenTouch and event.pressed:
			close_popup()
			get_viewport().set_input_as_handled()
		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			close_popup()
			get_viewport().set_input_as_handled()
	)

	_slide_root = Control.new()
	_slide_root.name = "SettingsSlideRoot"
	_slide_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_slide_root.modulate.a = 0.0
	_root.add_child(_slide_root)

	_panel = PanelContainer.new()
	_panel.name = "SettingsPanel"
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.add_theme_stylebox_override("panel", _panel_style())
	_slide_root.add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", panel_padding_x)
	margin.add_theme_constant_override("margin_right", panel_padding_x)
	margin.add_theme_constant_override("margin_top", panel_padding_y)
	margin.add_theme_constant_override("margin_bottom", panel_padding_y)
	_panel.add_child(margin)

	_content = VBoxContainer.new()
	_content.name = "SettingsContent"
	_content.alignment = BoxContainer.ALIGNMENT_CENTER
	_content.add_theme_constant_override("separation", 0)
	margin.add_child(_content)

	_sfx_button = _create_button("")
	_sfx_button.button_down.connect(func() -> void:
		_on_button_down(_sfx_button)
	)
	_sfx_button.button_up.connect(func() -> void:
		_on_button_up(_sfx_button)

		var next_enabled := not sfx_enabled

		if has_node("/root/UnilearnSFX"):
			get_node("/root/UnilearnSFX").set_enabled(true)
			get_node("/root/UnilearnSFX").play("toggle")

		sfx_enabled = next_enabled

		if has_node("/root/UnilearnSFX"):
			get_node("/root/UnilearnSFX").set_enabled(sfx_enabled)

		_update_button_texts()
		sfx_changed.emit(sfx_enabled)
	)
	_content.add_child(_sfx_button)

	_add_line()

	_apollo_button = _create_button("")
	_apollo_button.button_down.connect(func() -> void:
		_on_button_down(_apollo_button)
	)
	_apollo_button.button_up.connect(func() -> void:
		_on_button_up(_apollo_button)
		_play_sfx("toggle")
		
		apollo_enabled = not apollo_enabled
		_update_button_texts()
		apollo_changed.emit(apollo_enabled)
	)
	_content.add_child(_apollo_button)

	_add_line()

	_motion_button = _create_button("")
	_motion_button.button_down.connect(func() -> void:
		_on_button_down(_motion_button)
	)
	_motion_button.button_up.connect(func() -> void:
		_on_button_up(_motion_button)
		_play_sfx("toggle")
		
		reduce_motion_enabled = not reduce_motion_enabled
		_update_button_texts()
		reduce_motion_changed.emit(reduce_motion_enabled)
	)
	_content.add_child(_motion_button)

	_add_line()

	_reset_button = _create_button("RESET CAMERA")
	_reset_button.button_down.connect(func() -> void:
		_on_button_down(_reset_button)
	)
	_reset_button.button_up.connect(func() -> void:
		_on_button_up(_reset_button)
		_play_sfx("success")
		
		close_popup("reset_camera")
	)
	_content.add_child(_reset_button)

	_add_line()

	_logout_button = _create_button("LOGOUT", true)
	_logout_button.button_down.connect(func() -> void:
		_on_button_down(_logout_button)
	)
	_logout_button.button_up.connect(func() -> void:
		_on_button_up(_logout_button)
		_play_sfx("click")
		
		close_popup("logout")
	)
	_content.add_child(_logout_button)

	_update_button_texts()


func _prepare_center_position() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var panel_width: float = min(viewport_size.x * panel_width_ratio, panel_max_width)

	_panel.custom_minimum_size = Vector2(panel_width, 0)
	_panel.size = _panel.get_combined_minimum_size()

	_slide_root.size = _panel.size
	_center_position = (viewport_size - _slide_root.size) * 0.5

	_slide_root.position = _center_position
	_panel.position = Vector2.ZERO

	for button in [_sfx_button, _apollo_button, _motion_button, _reset_button, _logout_button]:
		if is_instance_valid(button):
			button.pivot_offset = button.size * 0.5


func _play_intro() -> void:
	_play_sfx("open")
	
	if _popup_tween:
		_popup_tween.kill()

	_dim.color = Color(0, 0, 0, 0.84)

	if _should_reduce_motion():
		_slide_root.position = _center_position
		_slide_root.modulate.a = 1.0
		_dim.modulate.a = 1.0
		return

	_slide_root.position = _get_left_offscreen_position()
	_slide_root.modulate.a = 0.0
	_dim.modulate.a = 0.0

	_popup_tween = create_tween()
	_popup_tween.set_parallel(true)

	_popup_tween.tween_property(_slide_root, "position", _center_position, POPUP_SLIDE_DURATION)\
		.set_trans(Tween.TRANS_CUBIC)\
		.set_ease(Tween.EASE_OUT)

	_popup_tween.tween_property(_slide_root, "modulate:a", 1.0, POPUP_FADE_DURATION)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_OUT)

	_popup_tween.tween_property(_dim, "modulate:a", 1.0, DIM_FADE_DURATION)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_OUT)


func _update_button_texts() -> void:
	if is_instance_valid(_sfx_button):
		_sfx_button.text = "SFX  " + ("ON" if sfx_enabled else "OFF")
		_set_button_color(_sfx_button, COLOR_ON if sfx_enabled else COLOR_OFF)

	if is_instance_valid(_apollo_button):
		_apollo_button.text = "APOLLO AI  " + ("ON" if apollo_enabled else "OFF")
		_set_button_color(_apollo_button, COLOR_ON if apollo_enabled else COLOR_OFF)

	if is_instance_valid(_motion_button):
		_motion_button.text = "REDUCE MOTION  " + ("ON" if reduce_motion_enabled else "OFF")
		_set_button_color(_motion_button, COLOR_ON if reduce_motion_enabled else COLOR_OFF)


func _create_button(label: String, danger: bool = false) -> Button:
	var button := Button.new()
	button.text = label
	button.custom_minimum_size = Vector2(0, button_height)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.flat = true

	var color := COLOR_OFF if danger else COLOR_ON

	button.add_theme_font_size_override("font_size", button_font_size)
	button.add_theme_color_override("font_color", color)
	button.add_theme_color_override("font_hover_color", color)
	button.add_theme_color_override("font_pressed_color", color)
	button.add_theme_color_override("font_disabled_color", color)

	var transparent_style := _button_style(Color.TRANSPARENT)

	button.add_theme_stylebox_override("normal", transparent_style)
	button.add_theme_stylebox_override("hover", _button_style(Color(1.0, 1.0, 1.0, 0.04)))
	button.add_theme_stylebox_override("pressed", _button_style(Color(1.0, 1.0, 1.0, 0.035)))
	button.add_theme_stylebox_override("focus", transparent_style)
	button.add_theme_stylebox_override("disabled", transparent_style)

	_apply_app_font(button)

	return button


func _set_button_color(button: Button, color: Color) -> void:
	button.add_theme_color_override("font_color", color)
	button.add_theme_color_override("font_hover_color", color)
	button.add_theme_color_override("font_pressed_color", color)
	button.add_theme_color_override("font_disabled_color", color)


func _add_line() -> void:
	var line := ColorRect.new()
	line.custom_minimum_size = Vector2(0, 5)
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.color = Color(1.0, 1.0, 1.0, 0.86)
	_content.add_child(line)


func _on_button_down(button: Button) -> void:
	if _closing:
		return

	if _should_reduce_motion():
		return

	button.pivot_offset = button.size * 0.5
	_tween_button_scale(button, BUTTON_PRESS_SCALE, 0.055)


func _on_button_up(button: Button) -> void:
	if _closing:
		return

	if _should_reduce_motion():
		button.scale = Vector2.ONE
		return

	button.pivot_offset = button.size * 0.5
	_tween_button_scale(button, BUTTON_RELEASE_SCALE, 0.11)

	await get_tree().create_timer(0.11).timeout

	if is_instance_valid(button):
		_tween_button_scale(button, Vector2.ONE, 0.10)


func _tween_button_scale(button: Button, target_scale: Vector2, duration: float) -> void:
	if _button_tween:
		_button_tween.kill()

	_button_tween = create_tween()
	_button_tween.set_trans(Tween.TRANS_BACK)
	_button_tween.set_ease(Tween.EASE_OUT)
	_button_tween.tween_property(button, "scale", target_scale, duration)
	

func _get_left_offscreen_position() -> Vector2:
	return Vector2(
		-_slide_root.size.x - POPUP_SIDE_PADDING,
		_center_position.y
	)


func _get_right_offscreen_position() -> Vector2:
	var viewport_width := 0.0

	if get_viewport() != null:
		viewport_width = get_viewport().get_visible_rect().size.x
	else:
		viewport_width = _center_position.x + _slide_root.size.x + POPUP_SIDE_PADDING

	return Vector2(
		viewport_width + POPUP_SIDE_PADDING,
		_center_position.y
	)


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()

	style.bg_color = Color(0.0, 0.0, 0.0, 0.70)
	style.border_color = COLOR_ON

	style.border_width_left = 5
	style.border_width_right = 5
	style.border_width_top = 5
	style.border_width_bottom = 5

	style.corner_radius_top_left = 48
	style.corner_radius_top_right = 48
	style.corner_radius_bottom_left = 48
	style.corner_radius_bottom_right = 48

	style.shadow_color = Color(0, 0, 0, 0.58)
	style.shadow_size = 14
	style.shadow_offset = Vector2(0, 6)

	return style


func _button_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()

	style.bg_color = color
	style.border_color = Color.TRANSPARENT

	style.border_width_left = 0
	style.border_width_right = 0
	style.border_width_top = 0
	style.border_width_bottom = 0

	style.corner_radius_top_left = 0
	style.corner_radius_top_right = 0
	style.corner_radius_bottom_left = 0
	style.corner_radius_bottom_right = 0

	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 18
	style.content_margin_bottom = 18

	return style


func _apply_app_font(control: Control) -> void:
	if _app_font != null:
		control.add_theme_font_override("font", _app_font)


func _play_sfx(id: String) -> void:
	if has_node("/root/UnilearnSFX"):
		get_node("/root/UnilearnSFX").play(id)
