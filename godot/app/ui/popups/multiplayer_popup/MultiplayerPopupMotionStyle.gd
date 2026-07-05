extends "res://app/ui/popups/multiplayer_popup/MultiplayerPopupBuild.gd"

func _ready() -> void:
	layer = 1200
	process_mode = Node.PROCESS_MODE_ALWAYS
	_app_font = load(FONT_PATH) as Font
	_multiplayer_icon = load(MULTIPLAYER_ICON_PATH) as Texture2D
	_sfx_node = get_node_or_null("/root/UnilearnSFX")
	_settings_node = get_node_or_null("/root/UnilearnUserSettings")
	_build_ui()
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_inside_tree() or _closing:
		return
	_prepare_center_position()
	await _play_intro()


func _notification(what: int) -> void:
	if what == Control.NOTIFICATION_RESIZED:
		_prepare_center_position()


func _input(event: InputEvent) -> void:
	if not is_instance_valid(_connect_button):
		return

	if not _button_pressed:
		return

	if event is InputEventMouseMotion:
		_button_pressed = _connect_button.get_global_rect().has_point(event.position)
		_connect_button.queue_redraw()
	elif event is InputEventScreenDrag:
		_button_pressed = _connect_button.get_global_rect().has_point(event.position)
		_connect_button.queue_redraw()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_finish_button_press(event.position)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch and not event.pressed:
		_finish_button_press(event.position)
		get_viewport().set_input_as_handled()



func close_popup() -> void:
	if _closing:
		return

	_closing = true
	_release_username_focus()
	_play_sfx("close")

	if _popup_tween != null and _popup_tween.is_valid():
		_popup_tween.kill()

	if not is_inside_tree() or get_viewport() == null:
		closed.emit()
		queue_free()
		return

	if reduce_motion_enabled:
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
