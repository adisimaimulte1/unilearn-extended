extends "res://app/ui/popups/settings_popup/SettingsPopupBase.gd"

var _delete_confirmation_visible := false
var _delete_confirmation_transitioning := false
var _delete_confirmation_content: VBoxContainer = null
var _delete_confirmation_buttons: HBoxContainer = null
var _delete_confirmation_yes_button: Button = null
var _settings_mode_panel_size := Vector2.ZERO
var _settings_mode_center_position := Vector2.ZERO

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
			if _delete_confirmation_visible and not _delete_confirmation_transitioning:
				_play_sfx("click")
				_hide_delete_confirmation(false)
			elif _delete_confirmation_visible:
				pass
			else:
				close_popup()
			get_viewport().set_input_as_handled()
		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if _delete_confirmation_visible and not _delete_confirmation_transitioning:
				_play_sfx("click")
				_hide_delete_confirmation(false)
			elif _delete_confirmation_visible:
				pass
			else:
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
		_show_delete_confirmation()
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


func _build_delete_confirmation_content() -> void:
	if is_instance_valid(_delete_confirmation_content):
		return
	_delete_confirmation_content = VBoxContainer.new()
	_delete_confirmation_content.name = "DeleteAccountConfirmation"
	_delete_confirmation_content.alignment = BoxContainer.ALIGNMENT_CENTER
	_delete_confirmation_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_delete_confirmation_content.clip_contents = true
	_delete_confirmation_content.add_theme_constant_override("separation", 24)
	_delete_confirmation_content.visible = false
	_content.add_child(_delete_confirmation_content)

	var title := Label.new()
	title.text = "DELETE ACCOUNT"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 76)
	title.add_theme_color_override("font_color", Color.WHITE)
	if _app_font != null:
		title.add_theme_font_override("font", _app_font)
	_delete_confirmation_content.add_child(title)

	_delete_confirmation_buttons = HBoxContainer.new()
	_delete_confirmation_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	_delete_confirmation_buttons.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_delete_confirmation_buttons.add_theme_constant_override("separation", 22)
	_delete_confirmation_content.add_child(_delete_confirmation_buttons)

	var no_button := _create_delete_confirmation_button("NO", false)
	_delete_confirmation_yes_button = _create_delete_confirmation_button("YES", true)
	no_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_delete_confirmation_yes_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_delete_confirmation_buttons.add_child(no_button)
	_delete_confirmation_buttons.add_child(_delete_confirmation_yes_button)
	_connect_dry_settings_button(no_button, func() -> void:
		_play_sfx("click")
		_hide_delete_confirmation(false)
	)
	_connect_dry_settings_button(_delete_confirmation_yes_button, func() -> void:
		if not _is_online_mode_available():
			_play_sfx("error")
			return
		_play_sfx("click")
		close_popup("delete_account")
	)
	_refresh_delete_confirmation_offline_state(false)


func _create_delete_confirmation_button(label: String, highlighted: bool) -> Button:
	var button := Button.new()
	button.text = label
	button.custom_minimum_size = Vector2(0, 98)
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.add_theme_font_size_override("font_size", 38)
	if _app_font != null:
		button.add_theme_font_override("font", _app_font)
	var background := Color.WHITE if highlighted else Color.BLACK
	var foreground := Color.BLACK if highlighted else Color.WHITE
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = Color.WHITE
	style.set_border_width_all(4)
	style.set_corner_radius_all(28)
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("hover", style)
	button.add_theme_stylebox_override("pressed", style)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.add_theme_color_override("font_color", foreground)
	button.add_theme_color_override("font_hover_color", foreground)
	button.add_theme_color_override("font_pressed_color", foreground)
	return button


func _show_delete_confirmation() -> void:
	if _delete_confirmation_visible or _delete_confirmation_transitioning:
		return
	_build_delete_confirmation_content()
	await _set_delete_confirmation_mode(true)


func _hide_delete_confirmation(play_sound: bool = true) -> void:
	if not _delete_confirmation_visible or _delete_confirmation_transitioning:
		return
	if play_sound:
		_play_sfx("close")
	await _set_delete_confirmation_mode(false)


func _set_delete_confirmation_mode(show_confirmation: bool) -> void:
	if not is_instance_valid(_content):
		return
	_delete_confirmation_transitioning = true
	var fade_out := create_tween()
	fade_out.tween_property(_content, "modulate:a", 0.0, _motion_duration(0.11)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await fade_out.finished
	if show_confirmation:
		_settings_mode_panel_size = _panel.size
		_settings_mode_center_position = _slide_root.position
		_delete_confirmation_visible = true
		_set_settings_content_visibility(false)
		_delete_confirmation_content.visible = true
		var old_size := _settings_mode_panel_size
		var old_position := _settings_mode_center_position
		# SettingsContent already owns the fixed inner width. A second width
		# minimum here could enlarge the whole PanelContainer at some UI scales.
		_delete_confirmation_content.custom_minimum_size = Vector2.ZERO
		if is_instance_valid(_delete_confirmation_buttons):
			_delete_confirmation_buttons.custom_minimum_size = Vector2.ZERO
		_panel.custom_minimum_size = Vector2(old_size.x, 0.0)
		await get_tree().process_frame
		var target_height := _panel.get_combined_minimum_size().y
		var target_size := Vector2(old_size.x, target_height)
		var viewport_size := get_viewport().get_visible_rect().size
		var target_position := (viewport_size - target_size) * 0.5
		_panel.size = old_size
		_slide_root.size = old_size
		_slide_root.position = old_position
		await _animate_delete_confirmation_resize(target_size, target_position)
	else:
		var restore_size := _settings_mode_panel_size
		var restore_position := _settings_mode_center_position
		if restore_size == Vector2.ZERO:
			restore_size = _panel.size
			restore_position = _slide_root.position
		await _animate_delete_confirmation_resize(restore_size, restore_position)
		_delete_confirmation_visible = false
		_delete_confirmation_content.visible = false
		_set_settings_content_visibility(true)
		_panel.custom_minimum_size = restore_size
		_panel.size = restore_size
		_slide_root.custom_minimum_size = restore_size
		_slide_root.size = restore_size
		_slide_root.position = restore_position
	if not is_instance_valid(_content):
		return
	var fade_in := create_tween()
	fade_in.tween_property(_content, "modulate:a", 1.0, _motion_duration(0.16)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await fade_in.finished
	_delete_confirmation_transitioning = false


func _refresh_delete_confirmation_offline_state(_blocked: bool) -> void:
	if not is_instance_valid(_delete_confirmation_yes_button):
		return
	# Keep the confirmation action visually consistent. Connectivity is checked
	# on press so an offline tap can provide error feedback without deleting.
	_delete_confirmation_yes_button.disabled = false
	_apply_delete_confirmation_account_color(Color.WHITE)


func _apply_delete_confirmation_account_color(_color: Color) -> void:
	if not is_instance_valid(_delete_confirmation_yes_button):
		return
	var background := Color.WHITE
	var foreground := Color.BLACK
	var border := Color.WHITE
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(4)
	style.set_corner_radius_all(28)
	for state in ["normal", "hover", "pressed", "disabled"]:
		_delete_confirmation_yes_button.add_theme_stylebox_override(state, style)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_disabled_color"]:
		_delete_confirmation_yes_button.add_theme_color_override(state, foreground)


func _set_settings_content_visibility(visible_value: bool) -> void:
	for child in _content.get_children():
		if child == _delete_confirmation_content:
			continue
		if child is CanvasItem:
			(child as CanvasItem).visible = visible_value


func _animate_delete_confirmation_resize(target_size: Vector2, target_position: Vector2) -> void:
	if not is_instance_valid(_panel) or not is_instance_valid(_slide_root):
		return
	if _should_reduce_motion():
		_panel.custom_minimum_size = target_size
		_panel.size = target_size
		_slide_root.custom_minimum_size = target_size
		_slide_root.size = target_size
		_slide_root.position = target_position
		_center_position = target_position
		return
	var resize_tween := create_tween()
	resize_tween.set_parallel(true)
	resize_tween.tween_property(_panel, "size", target_size, 0.30).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN_OUT)
	resize_tween.tween_property(_panel, "pivot_offset", target_size * 0.5, 0.30).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN_OUT)
	resize_tween.tween_property(_slide_root, "size", target_size, 0.30).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN_OUT)
	resize_tween.tween_property(_slide_root, "position", target_position, 0.30).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN_OUT)
	await resize_tween.finished
	_panel.custom_minimum_size = target_size
	_panel.size = target_size
	_panel.pivot_offset = target_size * 0.5
	_slide_root.custom_minimum_size = target_size
	_slide_root.size = target_size
	_slide_root.position = target_position
	_center_position = target_position


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
