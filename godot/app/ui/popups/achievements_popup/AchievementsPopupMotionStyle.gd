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
	card.scale = Vector2.ONE
	if _should_reduce_motion():
		card.modulate.a = 1.0
		return
	var delay: float = min(float(index % 3) * CARD_ENTER_STAGGER, 0.07)
	var tween := create_tween()
	tween.tween_property(card, "modulate:a", 1.0, CARD_ENTER_TIME) \
		.set_delay(delay) \
		.set_trans(Tween.TRANS_SINE) \
		.set_ease(Tween.EASE_OUT)


func _style_scroll_bar() -> void:
	if not is_instance_valid(_scroll):
		return

	var bar := _scroll.get_v_scroll_bar()

	if bar == null:
		return

	_cached_max_scroll_bar = bar
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
	style.bg_color = _theme_panel_color()
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
	style.bg_color = _theme_soft_panel_color()
	style.border_color = COLOR_BORDER
	style.set_border_width_all(6)
	style.set_corner_radius_all(38)
	style.shadow_color = Color(0, 0, 0, 0.70)
	style.shadow_size = 16
	style.shadow_offset = Vector2(0, 6)
	return style


func _tier_summary_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = _theme_soft_panel_color()
	style.border_color = COLOR_BORDER
	style.set_border_width_all(6)
	style.set_corner_radius_all(38)
	style.shadow_color = Color(0, 0, 0, 0.70)
	style.shadow_size = 16
	style.shadow_offset = Vector2(0, 6)
	return style


func _achievement_card_style(tier_color: Color, tier: int, rare_unlocked: bool = false) -> StyleBoxFlat:
	var key := "achievement_%s_%d_%s_%s" % [
		str(tier_color),
		tier,
		str(rare_unlocked),
		_theme_signature()
	]

	if _style_cache.has(key):
		return _style_cache[key]

	var style := StyleBoxFlat.new()
	style.bg_color = _theme_card_bg_color()
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
	return _theme_accent_color()


func _process(delta: float) -> void:
	_apply_scroll_inertia(delta)


func _input(event: InputEvent) -> void:
	if _handle_back_button_global_input(event):
		return

	_handle_slippery_scroll_input(event)


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


func _handle_slippery_scroll_input(event: InputEvent) -> void:
	if not is_instance_valid(_scroll):
		return

	if event is InputEventMouseButton:
		if not _is_inside_scroll(event.position):
			return

		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_scroll_velocity += _scroll_wheel_impulse
			_scroll_velocity = clamp(_scroll_velocity, -_scroll_max_velocity, _scroll_max_velocity)
			_ensure_scroll_process()
			get_viewport().set_input_as_handled()
			return

		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_scroll_velocity -= _scroll_wheel_impulse
			_scroll_velocity = clamp(_scroll_velocity, -_scroll_max_velocity, _scroll_max_velocity)
			_ensure_scroll_process()
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
					_scroll_last_time = Time.get_ticks_msec() / 1000.0
					_scroll_velocity = 0.0
			else:
				if _scroll_pointer_id == -2:
					if _scroll_dragging:
						get_viewport().set_input_as_handled()

					_scroll_pointer_id = -999
					_scroll_dragging = false

	elif event is InputEventMouseMotion:
		if _scroll_pointer_id == -2:
			_apply_manual_scroll(event.position.y)

			if _scroll_dragging:
				get_viewport().set_input_as_handled()

	elif event is InputEventScreenTouch:
		if event.pressed:
			if _is_inside_scroll(event.position):
				_scroll_pointer_id = event.index
				_scroll_dragging = false
				_scroll_start_y = event.position.y
				_scroll_last_y = event.position.y
				_scroll_start_value = _scroll.scroll_vertical
				_scroll_last_time = Time.get_ticks_msec() / 1000.0
				_scroll_velocity = 0.0
		else:
			if event.index == _scroll_pointer_id:
				if _scroll_dragging:
					get_viewport().set_input_as_handled()

				_scroll_pointer_id = -999
				_scroll_dragging = false

	elif event is InputEventScreenDrag:
		if event.index == _scroll_pointer_id:
			_apply_manual_scroll(event.position.y)

			if _scroll_dragging:
				get_viewport().set_input_as_handled()


func _apply_manual_scroll(current_y: float) -> void:
	if not is_instance_valid(_scroll):
		return

	var total_delta := _scroll_start_y - current_y

	if abs(total_delta) >= _scroll_drag_deadzone:
		_scroll_dragging = true

	if not _scroll_dragging:
		return

	var now := Time.get_ticks_msec() / 1000.0
	var dt: float = max(0.001, now - _scroll_last_time)
	var frame_delta := _scroll_last_y - current_y

	_scroll_velocity = clamp(frame_delta / dt, -_scroll_max_velocity, _scroll_max_velocity)
	_ensure_scroll_process()
	_scroll.scroll_vertical = int(clamp(float(_scroll.scroll_vertical) + frame_delta, 0.0, _get_max_scroll()))

	_scroll_last_y = current_y
	_scroll_last_time = now


func _ensure_scroll_process() -> void:
	if process_mode == Node.PROCESS_MODE_DISABLED:
		return
	if not is_processing():
		set_process(true)


func _apply_scroll_inertia(delta: float) -> void:
	if not is_instance_valid(_scroll):
		return

	if _scroll_pointer_id != -999:
		return

	if abs(_scroll_velocity) < 8.0:
		_scroll_velocity = 0.0
		set_process(false)
		return

	var max_scroll := _get_max_scroll()

	if max_scroll <= 0.0:
		_scroll_velocity = 0.0
		_scroll.scroll_vertical = 0
		return

	var next_scroll := float(_scroll.scroll_vertical) + (_scroll_velocity * delta)

	if next_scroll <= 0.0:
		next_scroll = 0.0
		_scroll_velocity = 0.0

	elif next_scroll >= max_scroll:
		next_scroll = max_scroll
		_scroll_velocity = 0.0

	else:
		_scroll_velocity = lerp(_scroll_velocity, 0.0, 1.0 - exp(-_scroll_friction * delta))

	_scroll.scroll_vertical = int(next_scroll)


func _get_max_scroll() -> float:
	if not is_instance_valid(_scroll):
		return 0.0

	var bar := _scroll.get_v_scroll_bar()
	_cached_max_scroll_bar = bar
	if bar == null:
		return 0.0

	# Do not reuse the previous view's scrollbar limits here. Category/detail
	# views are swapped and their content grows progressively, so a stale cached
	# max value can stop the user before the real bottom of the ScrollContainer.
	return max(0.0, bar.max_value - bar.page)


func _reset_scroll_dragging() -> void:
	_scroll_dragging = false


func _reset_scroll_motion() -> void:
	_scroll_pointer_id = -999
	_scroll_dragging = false
	_scroll_velocity = 0.0
	_cached_max_scroll_bar = null


func _is_inside_scroll(screen_position: Vector2) -> bool:
	if not is_instance_valid(_scroll):
		return false

	return _scroll.get_global_rect().has_point(screen_position)
