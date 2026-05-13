extends "res://app/ui/bottom_menu/BottomMenuPopups.gd"


func _layout() -> void:
	if not is_instance_valid(_root):
		return

	var viewport_size := get_viewport().get_visible_rect().size

	if viewport_size == _last_layout_size:
		return

	_last_layout_size = viewport_size

	var count := _icon_buttons.size()
	var icons_total_width := (icon_size * float(count)) + (icon_spacing * float(max(count - 1, 0)))
	var panel_width := icons_total_width + (group_horizontal_padding * 2.0)
	var panel_height := icon_size + (group_vertical_padding * 2.0)

	_panel.size = Vector2(panel_width, panel_height)
	_panel.pivot_offset = _panel.size * 0.5

	_handle.size = Vector2(handle_size, handle_size)
	_handle.pivot_offset = _handle.size * 0.5

	_position_icons_symmetrically()
	_update_icon_contents()
	_handle.move_to_front()

	_last_applied_progress = -999.0
	_apply_progress(_progress)


func _position_icons_symmetrically() -> void:
	if _icon_buttons.is_empty() or not is_instance_valid(_panel):
		return

	_icons_origin_y.clear()

	var count := _icon_buttons.size()
	var center_x := _panel.size.x * 0.5
	var center_y := _panel.size.y * 0.5
	var step := icon_size + icon_spacing
	var middle_index := float(count - 1) * 0.5

	for i in range(count):
		var button := _icon_buttons[i]

		if not is_instance_valid(button):
			continue

		var button_size := Vector2(icon_size, icon_size)

		if button.size != button_size:
			button.size = button_size
			button.pivot_offset = button_size * 0.5

		var offset_from_middle := float(i) - middle_index
		var icon_center_x := center_x + (offset_from_middle * step)
		var icon_center_y := center_y

		button.position = Vector2(
			icon_center_x - (icon_size * 0.5),
			icon_center_y - (icon_size * 0.5)
		)

		_icons_origin_y.append(button.position.y)


func _update_icon_contents() -> void:
	var icon_target_size := Vector2(menu_icon_max_width, menu_icon_max_width)

	for button in _icon_buttons:
		if not is_instance_valid(button):
			continue

		var icon_rect := button.get_node_or_null("CenteredAssetIcon") as TextureRect

		if icon_rect != null:
			if icon_rect.size != icon_target_size:
				icon_rect.size = icon_target_size
				icon_rect.pivot_offset = icon_target_size * 0.5

			icon_rect.position = (button.size - icon_target_size) * 0.5

		var label := button.get_node_or_null("CenteredFallbackText") as Label

		if label != null:
			label.position = Vector2.ZERO
			label.size = button.size


func _apply_progress(value: float) -> void:
	var next_progress: float = clamp(value, 0.0, 1.0)

	if not is_instance_valid(_panel) or not is_instance_valid(_handle):
		return

	var viewport_size := get_viewport().get_visible_rect().size

	if is_equal_approx(next_progress, _last_applied_progress) and viewport_size == _last_applied_viewport_size:
		return

	_progress = next_progress
	_last_applied_progress = next_progress
	_last_applied_viewport_size = viewport_size

	var closed_handle_y := viewport_size.y - bottom_padding - handle_size
	var open_handle_y := closed_handle_y - open_lift

	var closed_panel_y := viewport_size.y + 8.0
	var open_panel_y := open_handle_y + handle_size + arrow_menu_gap

	_handle.position = Vector2(
		(viewport_size.x - handle_size) * 0.5,
		lerp(closed_handle_y, open_handle_y, _progress)
	)

	_handle.rotation = lerp(0.0, PI, _progress)
	_handle.scale = Vector2.ONE * lerp(1.0, 0.92, _progress)

	_panel.position = Vector2(
		(viewport_size.x - _panel.size.x) * 0.5,
		lerp(closed_panel_y, open_panel_y, _progress)
	)

	var panel_should_be_visible := _progress > 0.01

	if _panel.visible != panel_should_be_visible:
		_panel.visible = panel_should_be_visible

	_panel.modulate.a = smoothstep(0.05, 0.6, _progress)

	_apply_icon_slide(_progress)


func _apply_icon_slide(p: float) -> void:
	var local_p := smoothstep(0.16, 0.8, p)

	for button in _icon_buttons:
		if not is_instance_valid(button):
			continue

		button.modulate.a = local_p

		if not _button_tweens.has(button) and button.scale != Vector2.ONE:
			button.scale = Vector2.ONE


func _snap_to(target: float) -> void:
	target = clamp(target, 0.0, 1.0)

	if is_equal_approx(target, _progress) and not _dragging:
		is_open = target >= 0.5
		return

	if _snap_tween != null and _snap_tween.is_valid():
		_snap_tween.kill()

	is_open = target >= 0.5
	_play_sfx("open" if is_open else "close")

	if reduce_motion_enabled:
		_last_applied_progress = -999.0
		_apply_progress(target)

		if target <= 0.0 and is_instance_valid(_panel):
			_panel.visible = false

		return

	_snap_tween = create_tween()
	_snap_tween.set_trans(Tween.TRANS_SINE)
	_snap_tween.set_ease(Tween.EASE_OUT)

	_snap_tween.tween_method(
		func(v: float) -> void:
			_apply_progress(v),
		_progress,
		target,
		snap_duration
	)

	if target <= 0.0:
		_snap_tween.finished.connect(func() -> void:
			if is_instance_valid(_panel):
				_panel.visible = false
		)


func _on_handle_gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_start_drag(event.index, event.position.y)
			get_viewport().set_input_as_handled()
		else:
			if _dragging and event.index == _active_touch_index:
				_finish_drag()
				get_viewport().set_input_as_handled()

	elif event is InputEventScreenDrag:
		if _dragging and event.index == _active_touch_index:
			_update_drag(event.position.y)
			get_viewport().set_input_as_handled()

	elif event is InputEventMouseButton:
		if event.button_index != MOUSE_BUTTON_LEFT:
			return

		if event.pressed:
			_start_drag(-2, event.position.y)
			get_viewport().set_input_as_handled()
		else:
			if _dragging and _active_touch_index == -2:
				_finish_drag()
				get_viewport().set_input_as_handled()

	elif event is InputEventMouseMotion:
		if _dragging and _active_touch_index == -2:
			_update_drag(event.position.y)
			get_viewport().set_input_as_handled()


func _start_drag(touch_index: int, y_position: float) -> void:
	if _snap_tween != null and _snap_tween.is_valid():
		_snap_tween.kill()

	_dragging = true
	_drag_started = false
	_drag_started_from_open = is_open
	_active_touch_index = touch_index
	_drag_start_y = y_position
	_drag_start_progress = _progress


func _update_drag(current_y: float) -> void:
	var dragged_up := _drag_start_y - current_y

	if abs(dragged_up) > drag_deadzone:
		_drag_started = true

	if _drag_started_from_open:
		_apply_progress(1.0)
		return

	var next_progress := _drag_start_progress + (dragged_up / drag_distance_to_open)
	_apply_progress(next_progress)


func _finish_drag() -> void:
	_dragging = false
	_active_touch_index = -1

	if not _drag_started:
		toggle_menu()
		_drag_started_from_open = false
		return

	if _drag_started_from_open:
		_snap_to(1.0)
		_drag_started_from_open = false
		return

	if _progress >= snap_threshold:
		_snap_to(1.0)
	else:
		_snap_to(0.0)

	_drag_started_from_open = false
