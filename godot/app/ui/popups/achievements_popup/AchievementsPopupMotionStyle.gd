extends "res://app/ui/popups/achievements_popup/AchievementsPopupBuild.gd"


func _prepare_center_position() -> void:
	if get_viewport() == null:
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
	_body_root.size = _panel.size


func _play_intro() -> void:
	_play_sfx("open")

	if _popup_tween:
		_popup_tween.kill()

	_prepare_center_position()
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


func close_popup() -> void:
	if _closing:
		return

	_closing = true
	_play_sfx("close")

	if _popup_tween:
		_popup_tween.kill()

	if not is_inside_tree() or get_viewport() == null:
		closed.emit()
		queue_free()
		return

	if _should_reduce_motion():
		_slide_root.position = _center_position
		_slide_root.modulate.a = 0.0
		_dim.modulate.a = 0.0
		closed.emit()
		queue_free()
		return

	_slide_root.position = _center_position
	_slide_root.modulate.a = 1.0

	_popup_tween = create_tween()
	_popup_tween.set_parallel(true)
	_popup_tween.tween_property(_slide_root, "position", _get_right_offscreen_position(), POPUP_SLIDE_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_popup_tween.tween_property(_slide_root, "modulate:a", 0.0, POPUP_FADE_DURATION).set_delay(max(0.0, POPUP_SLIDE_DURATION - POPUP_FADE_DURATION)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_popup_tween.tween_property(_dim, "modulate:a", 0.0, DIM_FADE_DURATION).set_delay(max(0.0, POPUP_SLIDE_DURATION - DIM_FADE_DURATION)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

	await _popup_tween.finished

	closed.emit()
	queue_free()

func _notification(what: int) -> void:
	if what == Control.NOTIFICATION_RESIZED:
		_prepare_center_position()
		_style_scroll_bar()


func _animate_card_in(card: Control, index: int) -> void:
	if not is_instance_valid(card):
		return

	if _should_reduce_motion():
		card.modulate.a = 1.0
		card.scale = Vector2.ONE
		return

	card.pivot_offset = card.size * 0.5

	var delay: float = min(float(index % 2) * CARD_ENTER_STAGGER, 0.035)
	var tween := create_tween()
	tween.set_parallel(true)

	tween.tween_property(card, "modulate:a", 1.0, CARD_ENTER_TIME) \
		.set_delay(delay) \
		.set_trans(Tween.TRANS_SINE) \
		.set_ease(Tween.EASE_OUT)

	tween.tween_property(card, "scale", Vector2.ONE, CARD_ENTER_TIME) \
		.set_delay(delay) \
		.set_trans(Tween.TRANS_BACK) \
		.set_ease(Tween.EASE_OUT)


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


func _square_button_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color.TRANSPARENT
	style.border_color = _get_back_button_icon_color()
	style.set_border_width_all(6)
	style.set_corner_radius_all(38)
	style.content_margin_left = 0
	style.content_margin_right = 0
	style.content_margin_top = 0
	style.content_margin_bottom = 0
	return style


func _unlocked_box_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color.TRANSPARENT
	style.border_color = COLOR_BORDER
	style.set_border_width_all(6)
	style.set_corner_radius_all(38)
	style.shadow_color = Color(0, 0, 0, 0.70)
	style.shadow_size = 16
	style.shadow_offset = Vector2(0, 6)
	return style


func _tier_summary_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color.TRANSPARENT
	style.border_color = COLOR_BORDER
	style.set_border_width_all(6)
	style.set_corner_radius_all(38)
	style.shadow_color = Color(0, 0, 0, 0.70)
	style.shadow_size = 16
	style.shadow_offset = Vector2(0, 6)
	return style


func _achievement_card_style(tier_color: Color, tier: int) -> StyleBoxFlat:
	var key := "achievement_%s_%d" % [str(tier_color), tier]
	if _style_cache.has(key):
		return _style_cache[key]

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.36)
	style.border_color = Color(1.0, 1.0, 1.0, 0.72) if tier <= 0 else COLOR_BORDER.lerp(tier_color, 0.32)
	style.set_border_width_all(5)
	style.set_corner_radius_all(38)
	style.shadow_color = Color(0, 0, 0, 0.54)
	style.shadow_size = 12
	style.shadow_offset = Vector2(0, 5)
	_style_cache[key] = style
	return style


func _progress_back_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1.0, 1.0, 1.0, 0.08)
	style.border_color = Color.TRANSPARENT
	style.set_border_width_all(0)
	style.set_corner_radius_all(999)
	return style


func _progress_fill_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color.TRANSPARENT
	style.set_border_width_all(0)
	style.set_corner_radius_all(999)
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


func _input(event: InputEvent) -> void:
	if _handle_back_button_global_input(event):
		return

	_handle_scroll_from_any_card(event)


func _handle_back_button_global_input(event: InputEvent) -> bool:
	if not is_instance_valid(_back_button):
		return false

	if event is InputEventScreenTouch:
		if event.pressed:
			if _back_button.get_global_rect().has_point(event.position):
				if not _selected_category.strip_edges().is_empty():
					_start_back_button_press(event.index)
				get_viewport().set_input_as_handled()
				return true
		elif _back_button_pointer_id == event.index:
			_finish_back_button_press(event.position)
			get_viewport().set_input_as_handled()
			return true

	elif event is InputEventScreenDrag:
		if _back_button_pointer_id == event.index:
			_update_back_button_pressed_visual(event.position)
			get_viewport().set_input_as_handled()
			return true

	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if _back_button.get_global_rect().has_point(event.position):
				if not _selected_category.strip_edges().is_empty():
					_start_back_button_press(-2)
				get_viewport().set_input_as_handled()
				return true
		elif _back_button_pointer_id == -2:
			_finish_back_button_press(event.position)
			get_viewport().set_input_as_handled()
			return true

	elif event is InputEventMouseMotion:
		if _back_button_pointer_id == -2:
			_update_back_button_pressed_visual(event.position)
			get_viewport().set_input_as_handled()
			return true

	return false


func _handle_scroll_from_any_card(event: InputEvent) -> void:
	if not is_instance_valid(_scroll):
		return

	if event is InputEventScreenTouch:
		if event.pressed:
			if _is_inside_scroll(event.position):
				_scroll_pointer_id = event.index
				_scroll_dragging = false
				_scroll_start_y = event.position.y
				_scroll_last_y = event.position.y
				_scroll_start_value = _scroll.scroll_vertical
		else:
			if event.index == _scroll_pointer_id:
				if _scroll_dragging:
					get_viewport().set_input_as_handled()
				_scroll_pointer_id = -999
				call_deferred("_reset_scroll_dragging")

	elif event is InputEventScreenDrag:
		if event.index == _scroll_pointer_id:
			var delta_y: float = event.position.y - _scroll_start_y
			if abs(delta_y) > _scroll_drag_deadzone:
				_scroll_dragging = true
			if _scroll_dragging:
				_scroll.scroll_vertical = max(0, _scroll_start_value - int(round(delta_y)))
				_scroll_last_y = event.position.y
				get_viewport().set_input_as_handled()

	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed and _is_inside_scroll(event.position):
			_scroll.scroll_vertical += 190
			get_viewport().set_input_as_handled()
			return
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed and _is_inside_scroll(event.position):
			_scroll.scroll_vertical = max(0, _scroll.scroll_vertical - 190)
			get_viewport().set_input_as_handled()
			return
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if _is_inside_scroll(event.position):
					_scroll_pointer_id = -2
					_scroll_dragging = false
					_scroll_start_y = event.position.y
					_scroll_last_y = event.position.y
					_scroll_start_value = _scroll.scroll_vertical
			else:
				if _scroll_pointer_id == -2:
					if _scroll_dragging:
						get_viewport().set_input_as_handled()
					_scroll_pointer_id = -999
					call_deferred("_reset_scroll_dragging")

	elif event is InputEventMouseMotion:
		if _scroll_pointer_id == -2:
			var delta_y: float = event.position.y - _scroll_start_y
			if abs(delta_y) > _scroll_drag_deadzone:
				_scroll_dragging = true
			if _scroll_dragging:
				_scroll.scroll_vertical = max(0, _scroll_start_value - int(round(delta_y)))
				_scroll_last_y = event.position.y
				get_viewport().set_input_as_handled()


func _reset_scroll_dragging() -> void:
	_scroll_dragging = false


func _is_inside_scroll(screen_position: Vector2) -> bool:
	if not is_instance_valid(_scroll):
		return false
	return _scroll.get_global_rect().has_point(screen_position)
