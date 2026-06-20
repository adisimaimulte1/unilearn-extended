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

	_music_button = _create_button("")
	_connect_dry_settings_button(_music_button, func() -> void:
		_play_sfx("toggle")
		_set_music_setting(not music_enabled)
	)
	_content.add_child(_music_button)

	_add_line()

	_sfx_button = _create_button("")
	_connect_dry_settings_button(_sfx_button, func() -> void:
		var next_enabled := not sfx_enabled

		if _sfx_node != null and _sfx_node.has_method("set_enabled"):
			_sfx_node.call("set_enabled", true)

		if _sfx_node != null and _sfx_node.has_method("play"):
			_sfx_node.call("play", "toggle")

		_set_sfx_setting(next_enabled)
	)
	_content.add_child(_sfx_button)

	_add_line()

	_apollo_button = _create_button("")
	_connect_dry_settings_button(_apollo_button, func() -> void:
		_play_sfx("toggle")
		_set_apollo_setting(not apollo_enabled)
	)
	_content.add_child(_apollo_button)

	_add_line()

	_motion_button = _create_button("")
	_connect_dry_settings_button(_motion_button, func() -> void:
		_play_sfx("toggle")
		_set_reduce_motion_setting(not reduce_motion_enabled)
	)
	_content.add_child(_motion_button)

	_add_line()

	_theme_button = _create_button("")
	_connect_dry_settings_button(_theme_button, func() -> void:
		_play_sfx("toggle")
		_toggle_theme_accent_setting()
	)
	_content.add_child(_theme_button)

	_add_line()

	_delete_account_button = _create_button("DELETE ACCOUNT", true)
	_connect_dry_settings_button(_delete_account_button, func() -> void:
		_play_sfx("click")
		close_popup("delete_account")
	)
	_content.add_child(_delete_account_button)

	_add_line()

	_logout_button = _create_button("LOGOUT", true)
	_connect_dry_settings_button(_logout_button, func() -> void:
		_play_sfx("click")
		close_popup("logout")
	)
	_content.add_child(_logout_button)

	_sync_from_settings()
	_refresh_theme_live()


func _connect_dry_settings_button(button: Button, action: Callable) -> void:
	button.button_down.connect(func() -> void:
		_on_button_down(button)
	)
	button.button_up.connect(func() -> void:
		_on_button_cancel(button)
	)
	button.pressed.connect(func() -> void:
		_on_button_up(button)
		action.call()
	)


func _make_buttons_dry(root: Node) -> void:
	if root == null:
		return
	if root is Button:
		var b := root as Button
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_stylebox_override("hover", b.get_theme_stylebox("normal"))
		b.add_theme_stylebox_override("pressed", b.get_theme_stylebox("normal"))
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		b.add_theme_color_override("font_hover_color", b.get_theme_color("font_color"))
		b.add_theme_color_override("font_pressed_color", b.get_theme_color("font_color"))
	for child in root.get_children():
		_make_buttons_dry(child)
