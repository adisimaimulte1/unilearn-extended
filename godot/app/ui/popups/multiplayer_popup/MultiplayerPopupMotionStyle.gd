extends "res://app/ui/popups/multiplayer_popup/MultiplayerPopupBuild.gd"

func _ready() -> void:
	layer = 1200
	process_mode = Node.PROCESS_MODE_ALWAYS
	_app_font = load(FONT_PATH) as Font
	_multiplayer_icon = load(MULTIPLAYER_ICON_PATH) as Texture2D
	_planet_cards_icon = load(PLANET_CARDS_ICON_PATH) as Texture2D
	_galaxy_console_icon = load(GALAXY_CONSOLE_ICON_PATH) as Texture2D
	_sfx_node = get_node_or_null("/root/UnilearnSFX")
	_settings_node = get_node_or_null("/root/UnilearnUserSettings")
	_build_ui()
	_sync_multiplayer_local_state()
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_inside_tree() or _closing:
		return
	_prepare_center_position()
	await _play_intro()


func _notification(what: int) -> void:
	if what == Control.NOTIFICATION_RESIZED:
		_prepare_center_position()
		_style_nearby_scroll_bar()


func _process(delta: float) -> void:
	if _kept_alive_for_universal_toasts or _closing:
		return
	_apply_scroll_inertia(delta)


func _input(event: InputEvent) -> void:
	# Universal multiplayer request cards live above the popup. Handle them first
	# so their visible rect consumes tap/drag instead of the popup/scene behind it.
	if _handle_multiplayer_incoming_request_global_input(event):
		get_viewport().set_input_as_handled()
		return

	# When the tab has been closed but universal toasts are still alive, this node
	# stays around only as their tiny input/timer manager. Do not let the hidden
	# multiplayer popup keep reacting to scroll/connect/background touches.
	if _kept_alive_for_universal_toasts or _closing:
		return

	if _handle_connect_button_global_input(event):
		return

	_handle_slippery_scroll_input(event)


func _handle_connect_button_global_input(event: InputEvent) -> bool:
	if not is_instance_valid(_connect_button):
		return false

	if not _button_pressed:
		return false

	if event is InputEventMouseMotion:
		_button_pressed = _connect_button.get_global_rect().has_point(event.position)
		_connect_button.queue_redraw()
		get_viewport().set_input_as_handled()
		return true
	elif event is InputEventScreenDrag:
		_button_pressed = _connect_button.get_global_rect().has_point(event.position)
		_connect_button.queue_redraw()
		get_viewport().set_input_as_handled()
		return true
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_finish_button_press(event.position)
		get_viewport().set_input_as_handled()
		return true
	elif event is InputEventScreenTouch and not event.pressed:
		_finish_button_press(event.position)
		get_viewport().set_input_as_handled()
		return true

	return false


func _handle_slippery_scroll_input(event: InputEvent) -> void:
	if _nearby_card_swipe_lock:
		return

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

	return max(0.0, bar.max_value - bar.page)


func _reset_scroll_motion() -> void:
	_scroll_pointer_id = -999
	_scroll_dragging = false
	_scroll_velocity = 0.0
	_cached_max_scroll_bar = null


func _is_inside_scroll(screen_position: Vector2) -> bool:
	if not is_instance_valid(_scroll):
		return false

	return _scroll.get_global_rect().has_point(screen_position)


func _emit_multiplayer_popup_closed_once() -> void:
	if _closed_signal_sent:
		return
	_closed_signal_sent = true
	closed.emit()


func _finish_multiplayer_popup_close_or_keep_toasts() -> void:
	_emit_multiplayer_popup_closed_once()
	if _universal_multiplayer_toasts_are_active():
		_kept_alive_for_universal_toasts = true
		process_mode = Node.PROCESS_MODE_ALWAYS
		set_process_input(true)
		if is_instance_valid(_root):
			_root.visible = false
		if is_instance_valid(_dim):
			_dim.visible = false
		if is_instance_valid(_slide_root):
			_slide_root.visible = false
		return
	queue_free()


func close_popup() -> void:
	if _closing:
		return

	_closing = true
	_stop_nearby_refresh()
	_release_username_focus()
	_play_sfx("close")

	if _popup_tween != null and _popup_tween.is_valid():
		_popup_tween.kill()

	if not is_inside_tree() or get_viewport() == null:
		_finish_multiplayer_popup_close_or_keep_toasts()
		return

	if reduce_motion_enabled:
		_slide_root.position = _center_position
		_slide_root.modulate.a = 0.0
		_dim.modulate.a = 0.0
		_finish_multiplayer_popup_close_or_keep_toasts()
		return

	_slide_root.position = _center_position
	_slide_root.modulate.a = 1.0

	_popup_tween = create_tween()
	_popup_tween.set_parallel(true)
	_popup_tween.tween_property(_slide_root, "position", _get_right_offscreen_position(), POPUP_SLIDE_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_popup_tween.tween_property(_slide_root, "modulate:a", 0.0, POPUP_FADE_DURATION).set_delay(max(0.0, POPUP_SLIDE_DURATION - POPUP_FADE_DURATION)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_popup_tween.tween_property(_dim, "modulate:a", 0.0, DIM_FADE_DURATION).set_delay(max(0.0, POPUP_SLIDE_DURATION - DIM_FADE_DURATION)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

	await _popup_tween.finished
	_finish_multiplayer_popup_close_or_keep_toasts()


func _prepare_center_position() -> void:
	if get_viewport() == null or not is_instance_valid(_panel):
		return

	var viewport_size := get_viewport().get_visible_rect().size
	var panel_width: float = min(viewport_size.x * panel_width_ratio, panel_max_width)
	var panel_height: float = min(viewport_size.y * panel_height_ratio, panel_max_height)
	panel_width = max(360.0, panel_width)
	panel_height = max(520.0, panel_height)

	_panel.custom_minimum_size = Vector2(panel_width, panel_height)
	_panel.size = Vector2(panel_width, panel_height)
	_slide_root.size = _panel.size
	_center_position = (viewport_size - _slide_root.size) * 0.5
	_slide_root.position = _center_position
	_panel.position = Vector2.ZERO
	_body_root.size = _panel.size


func _play_intro() -> void:
	_play_sfx("open")

	if _popup_tween != null and _popup_tween.is_valid():
		_popup_tween.kill()

	_dim.color = Color(0, 0, 0, 0.88)

	if reduce_motion_enabled:
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


func _get_left_offscreen_position() -> Vector2:
	return Vector2(-_slide_root.size.x - POPUP_SIDE_PADDING, _center_position.y)


func _get_right_offscreen_position() -> Vector2:
	var viewport_width := _center_position.x + _slide_root.size.x + POPUP_SIDE_PADDING
	if get_viewport() != null:
		viewport_width = get_viewport().get_visible_rect().size.x
	return Vector2(viewport_width + POPUP_SIDE_PADDING, _center_position.y)
