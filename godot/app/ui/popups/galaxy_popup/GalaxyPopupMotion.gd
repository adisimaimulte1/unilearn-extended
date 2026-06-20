extends "res://app/ui/popups/galaxy_popup/GalaxyPopupBuild.gd"


func _prepare_center_position() -> void:
	if get_viewport() == null or not is_instance_valid(_panel) or not is_instance_valid(_slide_root):
		return

	var viewport_size := get_viewport().get_visible_rect().size
	var panel_width: float = min(viewport_size.x * panel_width_ratio, panel_max_width)
	var panel_height: float = min(viewport_size.y * panel_height_ratio, panel_max_height)

	_panel.custom_minimum_size = Vector2(panel_width, panel_height)
	_panel.size = Vector2(panel_width, panel_height)

	_slide_root.size = _panel.size
	_center_position = (viewport_size - _slide_root.size) * 0.5

	_slide_root.position = _center_position
	_panel.position = Vector2.ZERO

	if is_instance_valid(_body_root):
		_body_root.position = Vector2.ZERO
		_body_root.size = _panel.size
		_body_root.custom_minimum_size = _panel.size

	for button in _action_buttons:
		if is_instance_valid(button):
			button.pivot_offset = button.size * 0.5

	var tab_buttons := [_data_tab_button, _behavior_tab_button, _commands_tab_button, _results_tab_button]
	for tab_button in tab_buttons:
		if is_instance_valid(tab_button):
			tab_button.pivot_offset = tab_button.size * 0.5


func _play_intro() -> void:
	_play_sfx("open")

	if _popup_tween != null and _popup_tween.is_valid():
		_popup_tween.kill()

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


func _refresh_theme_live() -> void:
	_style_cache.clear()

	if is_instance_valid(_panel):
		_panel.add_theme_stylebox_override("panel", _panel_style())

	for line in _lines:
		if is_instance_valid(line):
			line.color = _theme_line_color()

	for button in _action_buttons:
		if is_instance_valid(button):
			_update_action_button_styles(button)

	_update_tab_styles()

	for property_name in _sliders.keys():
		var slider = _sliders[property_name]
		if is_instance_valid(slider):
			_apply_slider_style(slider)

	for property_name in _value_labels.keys():
		var label: Label = _value_labels[property_name]
		if is_instance_valid(label):
			label.add_theme_color_override("font_color", _theme_accent_color())

	for property_name in _toggles.keys():
		var toggle = _toggles[property_name]
		if is_instance_valid(toggle):
			if toggle.has_method("refresh_theme"):
				toggle.refresh_theme(_app_font, _theme_text_color(), _theme_accent_color(), _theme_line_color(), _theme_hover_color(), _theme_pressed_color())
			else:
				toggle.add_theme_color_override("font_color", _theme_text_color())
				toggle.add_theme_color_override("font_hover_color", toggle.get_theme_color("font_color"))
				toggle.add_theme_color_override("font_pressed_color", toggle.get_theme_color("font_color"))

	_refresh_from_config()
	_apply_system_feedback_widgets()
	call_deferred("_style_scroll_bar")
