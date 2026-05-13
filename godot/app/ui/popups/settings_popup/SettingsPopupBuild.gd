extends "res://app/ui/popups/settings_popup/SettingsPopupBase.gd"

func _build_ui() -> void:
	_root = Control.new()
	_root.name = "SettingsPopupRoot"
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
			close_popup()
			get_viewport().set_input_as_handled()
		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			close_popup()
			get_viewport().set_input_as_handled()
	)

	_slide_root = Control.new()
	_slide_root.name = "SettingsSlideRoot"
	_slide_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_slide_root.modulate.a = 0.0
	_root.add_child(_slide_root)

	_panel = PanelContainer.new()
	_panel.name = "SettingsPanel"
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.add_theme_stylebox_override("panel", _panel_style())
	_slide_root.add_child(_panel)

	var outer_margin := MarginContainer.new()
	outer_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	outer_margin.add_theme_constant_override("margin_left", panel_padding_x)
	outer_margin.add_theme_constant_override("margin_right", panel_padding_x)
	outer_margin.add_theme_constant_override("margin_top", panel_padding_y)
	outer_margin.add_theme_constant_override("margin_bottom", panel_padding_y)
	_panel.add_child(outer_margin)

	var center := CenterContainer.new()
	center.name = "SettingsCenter"
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer_margin.add_child(center)

	_content = VBoxContainer.new()
	_content.name = "SettingsContent"
	_content.custom_minimum_size = Vector2(content_max_width, 0)
	_content.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_content.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_content.alignment = BoxContainer.ALIGNMENT_CENTER
	_content.add_theme_constant_override("separation", 0)
	center.add_child(_content)

	_sfx_button = _create_button("")
	_sfx_button.button_down.connect(func() -> void:
		_on_button_down(_sfx_button)
	)
	_sfx_button.button_up.connect(func() -> void:
		_on_button_up(_sfx_button)

		var next_enabled := not sfx_enabled

		if _sfx_node != null and _sfx_node.has_method("set_enabled"):
			_sfx_node.call("set_enabled", true)

		if _sfx_node != null and _sfx_node.has_method("play"):
			_sfx_node.call("play", "toggle")

		sfx_enabled = next_enabled

		if _sfx_node != null and _sfx_node.has_method("set_enabled"):
			_sfx_node.call("set_enabled", sfx_enabled)

		_update_button_texts()
		sfx_changed.emit(sfx_enabled)
	)
	_content.add_child(_sfx_button)

	_add_line()

	_apollo_button = _create_button("")
	_apollo_button.button_down.connect(func() -> void:
		_on_button_down(_apollo_button)
	)
	_apollo_button.button_up.connect(func() -> void:
		_on_button_up(_apollo_button)
		_play_sfx("toggle")

		apollo_enabled = not apollo_enabled
		_update_button_texts()
		apollo_changed.emit(apollo_enabled)
	)
	_content.add_child(_apollo_button)

	_add_line()

	_motion_button = _create_button("")
	_motion_button.button_down.connect(func() -> void:
		_on_button_down(_motion_button)
	)
	_motion_button.button_up.connect(func() -> void:
		_on_button_up(_motion_button)
		_play_sfx("toggle")

		reduce_motion_enabled = not reduce_motion_enabled
		_update_button_texts()
		reduce_motion_changed.emit(reduce_motion_enabled)
	)
	_content.add_child(_motion_button)

	_add_line()

	_theme_button = _create_button("")
	_theme_button.button_down.connect(func() -> void:
		_on_button_down(_theme_button)
	)
	_theme_button.button_up.connect(func() -> void:
		_on_button_up(_theme_button)
		_play_sfx("toggle")

		_toggle_theme_accent()
		_refresh_theme()
	)
	_content.add_child(_theme_button)

	_add_line()

	_reset_button = _create_button("RESET CAMERA")
	_reset_button.button_down.connect(func() -> void:
		_on_button_down(_reset_button)
	)
	_reset_button.button_up.connect(func() -> void:
		_on_button_up(_reset_button)
		_play_sfx("success")

		close_popup("reset_camera")
	)
	_content.add_child(_reset_button)

	_add_line()

	_logout_button = _create_button("LOGOUT", true)
	_logout_button.button_down.connect(func() -> void:
		_on_button_down(_logout_button)
	)
	_logout_button.button_up.connect(func() -> void:
		_on_button_up(_logout_button)
		_play_sfx("click")

		close_popup("logout")
	)
	_content.add_child(_logout_button)

	_update_button_texts()
