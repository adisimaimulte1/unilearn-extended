extends "res://app/ui/popups/settings_popup/SettingsPopupBuild.gd"

func _prepare_center_position() -> void:
	if get_viewport() == null or not is_instance_valid(_panel) or not is_instance_valid(_slide_root):
		return

	var viewport_size := get_viewport().get_visible_rect().size
	var panel_width: float = min(viewport_size.x * panel_width_ratio, panel_max_width)

	_panel.custom_minimum_size = Vector2(panel_width, 0)
	_panel.size = Vector2(panel_width, 0)

	await get_tree().process_frame

	if not is_inside_tree() or _closing:
		return

	var natural_height := _panel.get_combined_minimum_size().y

	_panel.custom_minimum_size = Vector2(panel_width, natural_height)
	_panel.size = Vector2(panel_width, natural_height)

	_slide_root.custom_minimum_size = _panel.size
	_slide_root.size = _panel.size

	_center_position = Vector2(
		(viewport_size.x - _slide_root.size.x) * 0.5,
		(viewport_size.y - _slide_root.size.y) * 0.5
	)

	_slide_root.position = _center_position
	_panel.position = Vector2.ZERO

	for button in [_sfx_button, _apollo_button, _motion_button, _theme_button, _reset_button, _logout_button]:
		if is_instance_valid(button):
			button.pivot_offset = button.size * 0.5


func _play_intro() -> void:
	_play_sfx("open")

	if _popup_tween:
		_popup_tween.kill()

	await _prepare_center_position()

	if not is_inside_tree() or _closing:
		return

	_dim.color = Color(0, 0, 0, 0.88)

	if _should_reduce_motion():
		_slide_root.position = _center_position
		_slide_root.modulate.a = 1.0
		_dim.modulate.a = 1.0
		await get_tree().process_frame
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

	await _popup_tween.finished


func _refresh_theme() -> void:
	_style_cache.clear()

	if is_instance_valid(_panel):
		_panel.add_theme_stylebox_override("panel", _panel_style())

	for line in _lines:
		if is_instance_valid(line):
			line.color = _theme_line_color()

	for button in [_sfx_button, _apollo_button, _motion_button, _theme_button, _reset_button, _logout_button]:
		if is_instance_valid(button):
			_update_button_styles(button)

	_update_button_texts()


func _update_button_texts() -> void:
	if is_instance_valid(_sfx_button):
		_sfx_button.text = "SFX:  " + ("ON" if sfx_enabled else "OFF")
		_set_button_color(_sfx_button, _theme_text_color() if sfx_enabled else _theme_accent_color())

	if is_instance_valid(_apollo_button):
		_apollo_button.text = "APOLLO AI:  " + ("ON" if apollo_enabled else "OFF")
		_set_button_color(_apollo_button, _theme_text_color() if apollo_enabled else _theme_accent_color())

	if is_instance_valid(_motion_button):
		_motion_button.text = "REDUCE MOTION:  " + ("ON" if reduce_motion_enabled else "OFF")
		_set_button_color(_motion_button, _theme_text_color() if reduce_motion_enabled else _theme_accent_color())

	if is_instance_valid(_theme_button):
		_theme_button.text = "THEME:  " + ("DARK" if _theme_accent_label() == "PURPLE" else "LIGHT")
		_set_button_color(_theme_button, _theme_accent_color())

	if is_instance_valid(_reset_button):
		_set_button_color(_reset_button, _theme_text_color())

	if is_instance_valid(_logout_button):
		_set_button_color(_logout_button, _theme_accent_color())


func _create_button(label: String, danger: bool = false) -> Button:
	var button := Button.new()
	button.text = label
	button.custom_minimum_size = Vector2(0, button_height)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.flat = true

	var color := _theme_accent_color() if danger else _theme_text_color()

	button.add_theme_font_size_override("font_size", button_font_size)
	button.add_theme_color_override("font_color", color)
	button.add_theme_color_override("font_hover_color", color)
	button.add_theme_color_override("font_pressed_color", color)
	button.add_theme_color_override("font_disabled_color", color)

	_update_button_styles(button)
	_apply_app_font(button)

	return button


func _update_button_styles(button: Button) -> void:
	if not is_instance_valid(button):
		return

	var transparent_style := _button_style(Color.TRANSPARENT)

	button.add_theme_stylebox_override("normal", transparent_style)
	button.add_theme_stylebox_override("hover", _button_style(_theme_hover_color()))
	button.add_theme_stylebox_override("pressed", _button_style(_theme_pressed_color()))
	button.add_theme_stylebox_override("focus", transparent_style)
	button.add_theme_stylebox_override("disabled", transparent_style)


func _set_button_color(button: Button, color: Color) -> void:
	if not is_instance_valid(button):
		return

	button.add_theme_color_override("font_color", color)
	button.add_theme_color_override("font_hover_color", color)
	button.add_theme_color_override("font_pressed_color", color)
	button.add_theme_color_override("font_disabled_color", color)


func _add_line() -> void:
	var line := ColorRect.new()
	line.custom_minimum_size = Vector2(0, 5)
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.color = _theme_line_color()
	_content.add_child(line)
	_lines.append(line)


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
	if not is_instance_valid(button):
		return

	if _button_tween:
		_button_tween.kill()

	_button_tween = create_tween()
	_button_tween.set_trans(Tween.TRANS_BACK)
	_button_tween.set_ease(Tween.EASE_OUT)
	_button_tween.tween_property(button, "scale", target_scale, duration)
