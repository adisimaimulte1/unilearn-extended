extends "res://app/ui/popups/planet_cards_popup/PlanetCardsPopupSearchGrid.gd"


func _prepare_center_position() -> void:
	if get_viewport() == null:
		return

	var viewport_size := get_viewport().get_visible_rect().size
	var panel_width: float = min(viewport_size.x * panel_width_ratio, panel_max_width)
	var panel_height: float = min(viewport_size.y * panel_height_ratio, panel_max_height)

	if is_instance_valid(_grid):
		_grid.columns = 1 if panel_width < 820.0 else columns

	_panel.custom_minimum_size = Vector2(panel_width, panel_height)
	_panel.size = Vector2(panel_width, panel_height)

	_slide_root.size = _panel.size
	_center_position = (viewport_size - _slide_root.size) * 0.5

	_slide_root.position = _center_position
	_panel.position = Vector2.ZERO
	_body_root.size = _panel.size


func _play_intro() -> void:
	_play_sfx("open")

	if _popup_tween:
		_popup_tween.kill()

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
	_popup_tween.tween_property(_slide_root, "position", _center_position, POPUP_SLIDE_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_popup_tween.tween_property(_slide_root, "modulate:a", 1.0, POPUP_FADE_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_popup_tween.tween_property(_dim, "modulate:a", 1.0, DIM_FADE_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	await _popup_tween.finished


func _update_search_focus_from_keyboard() -> void:
	if not is_instance_valid(_search_box):
		return

	if not _search_box.has_focus():
		_keyboard_was_visible = false
		return

	var keyboard_visible := _is_virtual_keyboard_visible()

	if _keyboard_was_visible and not keyboard_visible:
		_release_search_focus()
		return

	if keyboard_visible:
		_keyboard_was_visible = true


func _is_virtual_keyboard_visible() -> bool:
	if not OS.has_feature("mobile"):
		return false

	return DisplayServer.virtual_keyboard_get_height() > 0


func _release_search_focus() -> void:
	if not is_instance_valid(_search_box):
		return

	if _search_box.has_focus():
		_search_box.release_focus()

	if OS.has_feature("mobile"):
		DisplayServer.virtual_keyboard_hide()

	_keyboard_was_visible = false


func _style_scroll_bar() -> void:
	if not is_instance_valid(_scroll):
		return

	var bar := _scroll.get_v_scroll_bar()

	if bar == null:
		return

	bar.visible = true
	bar.modulate.a = 1.0
	bar.custom_minimum_size = Vector2(18, 0)
	bar.add_theme_stylebox_override("scroll", _scroll_track_style())
	bar.add_theme_stylebox_override("grabber", _scroll_grabber_style(COLOR_SCROLL_GRAB))
	bar.add_theme_stylebox_override("grabber_highlight", _scroll_grabber_style(COLOR_SCROLL_GRAB_HOVER))
	bar.add_theme_stylebox_override("grabber_pressed", _scroll_grabber_style(COLOR_SCROLL_GRAB_HOVER))


func _should_reduce_motion() -> bool:
	return reduce_motion_enabled


func _get_left_offscreen_position() -> Vector2:
	return Vector2(-_slide_root.size.x - POPUP_SIDE_PADDING, _center_position.y)


func _get_right_offscreen_position() -> Vector2:
	var viewport_width := _center_position.x + _slide_root.size.x + POPUP_SIDE_PADDING

	if get_viewport() != null:
		viewport_width = get_viewport().get_visible_rect().size.x

	return Vector2(viewport_width + POPUP_SIDE_PADDING, _center_position.y)


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()

	style.bg_color = COLOR_PANEL
	style.border_color = COLOR_BORDER
	style.set_border_width_all(5)
	style.set_corner_radius_all(44)

	style.shadow_color = Color(0, 0, 0, 0.64)
	style.shadow_size = 16
	style.shadow_offset = Vector2(0, 6)

	return style

func _search_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()

	style.bg_color = Color.TRANSPARENT
	style.border_color = COLOR_BORDER
	style.set_border_width_all(6)
	style.set_corner_radius_all(38)

	return style

func _square_button_style(_pressed: bool = false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	var highlight := _get_theme_highlight_color()

	style.bg_color = Color.TRANSPARENT
	style.border_color = COLOR_BORDER.lerp(highlight, _add_button_highlight_blend)
	style.set_border_width_all(6)
	style.set_corner_radius_all(38)

	style.content_margin_left = 0
	style.content_margin_right = 0
	style.content_margin_top = 0
	style.content_margin_bottom = 0

	return style

func _low_bar_style(is_error: bool = false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	var highlight := _get_theme_highlight_color()

	style.bg_color = Color(0.16, 0.035, 0.045, 0.96) if is_error else COLOR_STATUS_PANEL
	style.border_color = COLOR_STATUS_ERROR if is_error else highlight
	style.set_border_width_all(4)
	style.set_corner_radius_all(28)

	style.shadow_color = Color(0, 0, 0, 0.72)
	style.shadow_size = 20
	style.shadow_offset = Vector2(0, 8)

	return style

func _transparent_line_edit_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()

	style.bg_color = Color.TRANSPARENT
	style.border_color = Color.TRANSPARENT
	style.set_border_width_all(0)

	style.content_margin_left = 0
	style.content_margin_right = 0
	style.content_margin_top = 0
	style.content_margin_bottom = 0

	return style

func _scroll_track_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()

	style.bg_color = COLOR_SCROLL_TRACK
	style.border_color = Color.TRANSPARENT
	style.set_border_width_all(0)
	style.set_corner_radius_all(999)

	style.content_margin_left = 5
	style.content_margin_right = 5
	style.content_margin_top = 8
	style.content_margin_bottom = 8

	return style

func _scroll_grabber_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()

	style.bg_color = color
	style.border_color = Color.TRANSPARENT
	style.set_border_width_all(0)
	style.set_corner_radius_all(999)

	style.content_margin_left = 3
	style.content_margin_right = 3
	style.content_margin_top = 3
	style.content_margin_bottom = 3

	return style


func _apply_app_font(control: Control) -> void:
	if _app_font != null:
		control.add_theme_font_override("font", _app_font)


func _play_sfx(id: String) -> void:
	if has_node("/root/UnilearnSFX"):
		get_node("/root/UnilearnSFX").play(id)


func _get_theme_highlight_color() -> Color:
	if has_node("/root/UnilearnUserSettings"):
		var settings := get_node("/root/UnilearnUserSettings")

		if settings != null and settings.has_method("get_accent_color"):
			return settings.get_accent_color()

	return COLOR_STATUS
