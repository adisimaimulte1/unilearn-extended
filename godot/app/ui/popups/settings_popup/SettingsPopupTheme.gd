extends "res://app/ui/popups/settings_popup/SettingsPopupMotion.gd"

func _toggle_theme_accent() -> void:
	if _settings_node == null:
		return

	if _settings_node.has_method("toggle_theme_accent"):
		_settings_node.call("toggle_theme_accent")
		return

	var current := "purple"

	if _settings_node.get("theme_accent_name") != null:
		current = str(_settings_node.get("theme_accent_name")).strip_edges().to_lower()

	var next := "orange" if current == "purple" else "purple"

	if _settings_node.has_method("set_theme_accent_name"):
		_settings_node.call("set_theme_accent_name", next)
	elif _settings_node.get("theme_accent_name") != null:
		_settings_node.set("theme_accent_name", next)

		if _settings_node.has_method("save_settings"):
			_settings_node.call("save_settings")


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
	var key := "panel_%s" % str(_theme_panel_color())

	if _style_cache.has(key):
		return _style_cache[key]

	var style := StyleBoxFlat.new()

	style.bg_color = _theme_panel_color()
	style.border_color = Color.WHITE
	style.set_border_width_all(5)
	style.set_corner_radius_all(44)

	style.shadow_color = Color(0, 0, 0, 0.64)
	style.shadow_size = 16
	style.shadow_offset = Vector2(0, 6)

	_style_cache[key] = style
	return style


func _button_style(color: Color) -> StyleBoxFlat:
	var key := "button_%s" % str(color)

	if _style_cache.has(key):
		return _style_cache[key]

	var style := StyleBoxFlat.new()

	style.bg_color = color
	style.border_color = Color.TRANSPARENT
	style.set_border_width_all(0)

	style.corner_radius_top_left = 0
	style.corner_radius_top_right = 0
	style.corner_radius_bottom_left = 0
	style.corner_radius_bottom_right = 0

	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 18
	style.content_margin_bottom = 18

	_style_cache[key] = style
	return style


func _theme_accent_color() -> Color:
	if _settings_node != null and _settings_node.has_method("get_accent_color"):
		return _settings_node.call("get_accent_color")

	if _settings_node != null and _settings_node.get("theme_accent_name") != null:
		match str(_settings_node.get("theme_accent_name")).strip_edges().to_lower():
			"orange":
				return UnilearnUserSettings.ACCENT_ORANGE
			_:
				return UnilearnUserSettings.ACCENT_PURPLE

	return UnilearnUserSettings.ACCENT_PURPLE


func _theme_accent_label() -> String:
	if _settings_node != null and _settings_node.get("theme_accent_name") != null:
		return str(_settings_node.get("theme_accent_name")).strip_edges().to_upper()

	return "PURPLE"


func _theme_dark_mode() -> bool:
	if _settings_node != null and _settings_node.get("theme_dark_mode") != null:
		return bool(_settings_node.get("theme_dark_mode"))

	return true


func _theme_panel_color() -> Color:
	if _settings_node != null and _settings_node.has_method("get_panel_color"):
		return _settings_node.call("get_panel_color")

	return Color(0.0, 0.0, 0.0, 0.82)


func _theme_text_color() -> Color:
	if _settings_node != null and _settings_node.has_method("get_text_color"):
		return _settings_node.call("get_text_color")

	return FALLBACK_COLOR_ON


func _theme_line_color() -> Color:
	if _settings_node != null and _settings_node.has_method("get_line_color"):
		return _settings_node.call("get_line_color")

	return Color(1.0, 1.0, 1.0, 0.86)


func _theme_hover_color() -> Color:
	return Color(1.0, 1.0, 1.0, 0.04) if _theme_dark_mode() else Color(0.0, 0.0, 0.0, 0.045)


func _theme_pressed_color() -> Color:
	return Color(1.0, 1.0, 1.0, 0.035) if _theme_dark_mode() else Color(0.0, 0.0, 0.065)


func _apply_app_font(control: Control) -> void:
	if _app_font != null:
		control.add_theme_font_override("font", _app_font)


func _play_sfx(id: String) -> void:
	if _sfx_node != null and _sfx_node.has_method("play"):
		_sfx_node.call("play", id)
