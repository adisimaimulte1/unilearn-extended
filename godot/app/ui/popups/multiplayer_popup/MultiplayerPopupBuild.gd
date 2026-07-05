extends "res://app/ui/popups/multiplayer_popup/MultiplayerPopupBase.gd"

func _build_ui() -> void:
	_root = Control.new()
	_root.name = "MultiplayerPopupRoot"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	_dim = ColorRect.new()
	_dim.name = "TapOutsideDim"
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.color = Color(0, 0, 0, 0.88)
	_dim.modulate.a = 0.0
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(_dim)
	_dim.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventScreenTouch and event.pressed:
			_release_username_focus()
			close_popup()
			get_viewport().set_input_as_handled()
		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_release_username_focus()
			close_popup()
			get_viewport().set_input_as_handled()
	)

	_slide_root = Control.new()
	_slide_root.name = "MultiplayerSlideRoot"
	_slide_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_slide_root.modulate.a = 0.0
	_root.add_child(_slide_root)

	_panel = PanelContainer.new()
	_panel.name = "MultiplayerPanel"
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.add_theme_stylebox_override("panel", _panel_style())
	_slide_root.add_child(_panel)

	_body_root = Control.new()
	_body_root.name = "MultiplayerBodyRoot"
	_body_root.mouse_filter = Control.MOUSE_FILTER_PASS
	_panel.add_child(_body_root)

	_build_main_view()


func _build_main_view() -> void:
	_main_view = Control.new()
	_main_view.name = "MultiplayerMainView"
	_main_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	_body_root.add_child(_main_view)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", panel_padding_x)
	margin.add_theme_constant_override("margin_right", panel_padding_x)
	margin.add_theme_constant_override("margin_top", panel_padding_y)
	margin.add_theme_constant_override("margin_bottom", panel_padding_y)
	_main_view.add_child(margin)

	var content := VBoxContainer.new()
	content.name = "MultiplayerContent"
	content.add_theme_constant_override("separation", 34)
	margin.add_child(content)

	var title_box := VBoxContainer.new()
	title_box.custom_minimum_size = Vector2(0, 230)
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_box.add_theme_constant_override("separation", 6)
	content.add_child(title_box)

	var title := Label.new()
	title.text = "MULTIPLAYER"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 118)
	title.add_theme_color_override("font_color", COLOR_TEXT)
	title.clip_text = false
	_apply_app_font(title)
	title_box.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Sync universes and trade planet cards!"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	subtitle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.add_theme_font_size_override("font_size", 52)
	subtitle.add_theme_color_override("font_color", COLOR_SUBTITLE)
	_apply_app_font(subtitle)
	title_box.add_child(subtitle)

	var search_row_height := 150.0
	var search_gap := 22.0

	var search_row := Control.new()
	search_row.name = "UsernameRow"
	search_row.custom_minimum_size = Vector2(0, search_row_height)
	search_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search_row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	content.add_child(search_row)

	var username_shell := PanelContainer.new()
	username_shell.name = "UsernameShell"
	username_shell.mouse_filter = Control.MOUSE_FILTER_STOP
	username_shell.add_theme_stylebox_override("panel", _search_style())
	search_row.add_child(username_shell)

	_connect_button = Control.new()
	_connect_button.name = "ConnectMultiplayerButton"
	_connect_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_connect_button.scale = Vector2.ONE
	search_row.add_child(_connect_button)

	_connect_button.draw.connect(func() -> void:
		var rect := Rect2(Vector2.ZERO, _connect_button.size)
		var highlight := _get_theme_highlight_color()
		var icon_color := COLOR_TEXT.lerp(highlight, _button_highlight_blend)

		_connect_button.draw_style_box(_square_button_style(_button_pressed), rect)
		_draw_multiplayer_button_icon(_connect_button, icon_color)
	)

	var layout_search_row := func() -> void:
		var row_width := search_row.size.x
		var row_height := search_row.size.y
		if row_height <= 0.0:
			row_height = search_row_height

		var button_size := row_height
		var username_width: float = max(0.0, row_width - button_size - search_gap)

		username_shell.position = Vector2.ZERO
		username_shell.size = Vector2(username_width, row_height)
		username_shell.custom_minimum_size = username_shell.size

		_connect_button.position = Vector2(username_width + search_gap, 0.0)
		_connect_button.size = Vector2(button_size, row_height)
		_connect_button.custom_minimum_size = _connect_button.size
		_connect_button.pivot_offset = _connect_button.size * 0.5
		_connect_button.queue_redraw()

	search_row.resized.connect(func() -> void:
		layout_search_row.call()
	)

	var username_margin := MarginContainer.new()
	username_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	username_margin.add_theme_constant_override("margin_left", 34)
	username_margin.add_theme_constant_override("margin_right", 20)
	username_margin.add_theme_constant_override("margin_top", 0)
	username_margin.add_theme_constant_override("margin_bottom", 0)
	username_shell.add_child(username_margin)

	var username_inner := HBoxContainer.new()
	username_inner.alignment = BoxContainer.ALIGNMENT_CENTER
	username_inner.add_theme_constant_override("separation", 20)
	username_margin.add_child(username_inner)

	username_inner.add_child(_create_user_icon())

	_username_box = LineEdit.new()
	_username_box.placeholder_text = "Your name..."
	_username_box.custom_minimum_size = Vector2(0, 120)
	_username_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_username_box.clear_button_enabled = false
	_username_box.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_username_box.flat = true
	_username_box.caret_blink = true
	_username_box.caret_blink_interval = 0.42
	_username_box.virtual_keyboard_enabled = true
	_username_box.add_theme_font_size_override("font_size", 66)
	_username_box.add_theme_color_override("font_color", COLOR_TEXT)
	_username_box.add_theme_color_override("font_placeholder_color", COLOR_PLACEHOLDER)
	_username_box.add_theme_color_override("caret_color", COLOR_TEXT)
	_username_box.add_theme_color_override("font_selected_color", Color.BLACK)
	_username_box.add_theme_color_override("selection_color", COLOR_TEXT)
	_username_box.add_theme_stylebox_override("normal", _transparent_line_edit_style())
	_username_box.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_username_box.add_theme_stylebox_override("read_only", _transparent_line_edit_style())
	_apply_app_font(_username_box)
	_username_box.text_changed.connect(func(_text: String) -> void:
		_update_username_clear_button()
	)
	_username_box.text_submitted.connect(func(_text: String) -> void:
		_press_multiplayer_button(true)
	)
	username_inner.add_child(_username_box)

	_username_clear_button = _create_username_clear_button()
	username_inner.add_child(_username_clear_button)
	_update_username_clear_button()

	_connect_button.mouse_entered.connect(func() -> void:
		_button_hovered = true
		_connect_button.queue_redraw()
	)
	_connect_button.mouse_exited.connect(func() -> void:
		_button_hovered = false
		_connect_button.queue_redraw()
	)
	_connect_button.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventScreenTouch and event.pressed:
			_start_button_press()
			get_viewport().set_input_as_handled()
		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_start_button_press()
			get_viewport().set_input_as_handled()
	)

	layout_search_row.call()

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(spacer)


func _update_username_clear_button() -> void:
	if not is_instance_valid(_username_clear_button) or not is_instance_valid(_username_box):
		return
	_username_clear_button.visible = not _username_box.text.strip_edges().is_empty()


func _clear_username() -> void:
	if not is_instance_valid(_username_box):
		return
	_username_box.text = ""
	_username_box.grab_focus()
	_update_username_clear_button()


func _release_username_focus() -> void:
	if not is_instance_valid(_username_box):
		return

	if _username_box.has_focus():
		_username_box.release_focus()

	if OS.has_feature("mobile"):
		DisplayServer.virtual_keyboard_hide()


func _create_user_icon() -> Control:
	var center_wrap := CenterContainer.new()
	center_wrap.custom_minimum_size = Vector2(92, 120)
	center_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var icon := Control.new()
	icon.custom_minimum_size = Vector2(76, 76)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.draw.connect(func() -> void:
		var color := Color.WHITE
		var width := 7.0
		icon.draw_arc(Vector2(38, 28), 15.0, 0.0, TAU, 64, color, width, true)
		icon.draw_arc(Vector2(38, 69), 24.0, PI, TAU, 64, color, width, true)
	)

	center_wrap.add_child(icon)
	return center_wrap


func _create_username_clear_button() -> Control:
	var button := Control.new()
	button.name = "UsernameClearButton"
	button.custom_minimum_size = Vector2(92, 120)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.visible = false
	button.draw.connect(func() -> void:
		var center := button.size * 0.5
		var half_size := 21.0
		var width := 7.0
		button.draw_line(center + Vector2(-half_size, -half_size), center + Vector2(half_size, half_size), COLOR_TEXT, width, true)
		button.draw_line(center + Vector2(half_size, -half_size), center + Vector2(-half_size, half_size), COLOR_TEXT, width, true)
	)
	button.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventScreenTouch and event.pressed:
			_clear_username()
			get_viewport().set_input_as_handled()
		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_clear_username()
			get_viewport().set_input_as_handled()
	)
	return button


func _draw_multiplayer_button_icon(target: Control, icon_color: Color) -> void:
	var center := target.size * 0.5
	var icon_size := target.size.y * 0.48

	if _multiplayer_icon != null:
		var texture_size := _multiplayer_icon.get_size()
		if texture_size.x > 0.0 and texture_size.y > 0.0:
			var scale_factor: float = min(icon_size / texture_size.x, icon_size / texture_size.y)
			var draw_size := texture_size * scale_factor
			var draw_rect := Rect2(center - draw_size * 0.5, draw_size)
			target.draw_texture_rect(_multiplayer_icon, draw_rect, false, icon_color)
			return

	var width := target.size.y * 0.055
	var r := target.size.y * 0.09
	var offset := target.size.y * 0.18
	target.draw_arc(center + Vector2(-offset, -offset * 0.25), r, 0.0, TAU, 48, icon_color, width, true)
	target.draw_arc(center + Vector2(offset, -offset * 0.25), r, 0.0, TAU, 48, icon_color, width, true)
	target.draw_arc(center + Vector2(0, offset * 0.65), r, 0.0, TAU, 48, icon_color, width, true)
	target.draw_line(center + Vector2(-offset + r, -offset * 0.18), center + Vector2(-r * 0.45, offset * 0.5), icon_color, width, true)
	target.draw_line(center + Vector2(offset - r, -offset * 0.18), center + Vector2(r * 0.45, offset * 0.5), icon_color, width, true)
	target.draw_line(center + Vector2(-offset + r, -offset * 0.25), center + Vector2(offset - r, -offset * 0.25), icon_color, width, true)


func _apply_app_font(control: Control) -> void:
	if _app_font != null:
		control.add_theme_font_override("font", _app_font)


func _start_button_press() -> void:
	if not is_instance_valid(_connect_button):
		return

	_button_pressed = true
	_connect_button.queue_redraw()
	if not reduce_motion_enabled:
		_bounce_button_down()


func _finish_button_press(screen_position: Vector2) -> void:
	if not is_instance_valid(_connect_button):
		return

	var released_inside := _connect_button.get_global_rect().has_point(screen_position)
	_button_pressed = false
	_connect_button.queue_redraw()

	if released_inside:
		if not reduce_motion_enabled:
			_bounce_button_release()
		_press_multiplayer_button()
	else:
		if not reduce_motion_enabled:
			_bounce_button_cancel()


func _press_multiplayer_button(force_on: bool = false) -> void:
	if force_on:
		_button_toggled = true
	else:
		_button_toggled = not _button_toggled

	_release_username_focus()
	_play_sfx("success" if _button_toggled else "toggle")
	_animate_button_toggle_state()


func _bounce_button_down() -> void:
	if not is_instance_valid(_connect_button):
		return

	if _button_bounce_tween != null and _button_bounce_tween.is_valid():
		_button_bounce_tween.kill()

	_connect_button.pivot_offset = _connect_button.size * 0.5
	_button_bounce_tween = create_tween()
	_button_bounce_tween.set_trans(Tween.TRANS_BACK)
	_button_bounce_tween.set_ease(Tween.EASE_OUT)
	_button_bounce_tween.tween_property(_connect_button, "scale", BUTTON_PRESS_SCALE, BUTTON_DOWN_TIME)


func _bounce_button_release() -> void:
	if not is_instance_valid(_connect_button):
		return

	if _button_bounce_tween != null and _button_bounce_tween.is_valid():
		_button_bounce_tween.kill()

	_connect_button.pivot_offset = _connect_button.size * 0.5
	_button_bounce_tween = create_tween()
	_button_bounce_tween.set_trans(Tween.TRANS_BACK)
	_button_bounce_tween.set_ease(Tween.EASE_OUT)
	_button_bounce_tween.tween_property(_connect_button, "scale", BUTTON_RELEASE_SCALE, BUTTON_UP_TIME)
	_button_bounce_tween.tween_property(_connect_button, "scale", Vector2.ONE, BUTTON_SETTLE_TIME)


func _bounce_button_cancel() -> void:
	if not is_instance_valid(_connect_button):
		return

	if _button_bounce_tween != null and _button_bounce_tween.is_valid():
		_button_bounce_tween.kill()

	_connect_button.pivot_offset = _connect_button.size * 0.5
	_button_bounce_tween = create_tween()
	_button_bounce_tween.set_trans(Tween.TRANS_BACK)
	_button_bounce_tween.set_ease(Tween.EASE_OUT)
	_button_bounce_tween.tween_property(_connect_button, "scale", Vector2.ONE, BUTTON_SETTLE_TIME)


func _animate_button_toggle_state() -> void:
	var target := 1.0 if _button_toggled else 0.0

	if is_equal_approx(_button_highlight_blend, target):
		_update_button_visual()
		return

	if _button_color_tween != null and _button_color_tween.is_valid():
		_button_color_tween.kill()

	if reduce_motion_enabled:
		_button_highlight_blend = target
		_update_button_visual()
		return

	_button_color_tween = create_tween()
	_button_color_tween.set_trans(Tween.TRANS_SINE)
	_button_color_tween.set_ease(Tween.EASE_OUT)
	_button_color_tween.tween_method(
		func(value: float) -> void:
			_button_highlight_blend = value
			_update_button_visual(),
		_button_highlight_blend,
		target,
		BUTTON_COLOR_TWEEN_TIME
	)


func _update_button_visual() -> void:
	if is_instance_valid(_connect_button):
		_connect_button.queue_redraw()


func _set_button_highlight_blend(value: float) -> void:
	_button_highlight_blend = clamp(value, 0.0, 1.0)
	_update_button_visual()



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
	style.border_color = COLOR_BORDER.lerp(highlight, _button_highlight_blend)
	style.set_border_width_all(6)
	style.set_corner_radius_all(38)
	style.content_margin_left = 0
	style.content_margin_right = 0
	style.content_margin_top = 0
	style.content_margin_bottom = 0
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


func _get_theme_highlight_color() -> Color:
	if _settings_node != null and _settings_node.has_method("get_accent_color"):
		var value: Variant = _settings_node.call("get_accent_color")
		if value is Color:
			return value
	return COLOR_STATUS


func _play_sfx(id: String) -> void:
	if _sfx_node != null and _sfx_node.has_method("play"):
		_sfx_node.call("play", id)
