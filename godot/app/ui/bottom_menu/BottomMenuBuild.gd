extends "res://app/ui/bottom_menu/BottomMenuBase.gd"

func _build_ui() -> void:
	_root = Control.new()
	_root.name = "BottomMenuRoot"
	_root.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_root)
	_full_rect(_root)

	_panel = Panel.new()
	_panel.name = "FloatingMenuPanel"
	_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	_panel.visible = false
	_panel.add_theme_stylebox_override(
		"panel",
		_group_panel_style(group_background_color, group_border_color, group_border_width)
	)
	_root.add_child(_panel)

	_add_icon("help", help_texture_path, "?")
	_add_icon("cards", cards_texture_path, "C")
	_add_icon("achievements", achievements_texture_path, "A")
	_add_icon("playgrounds", playgrounds_texture_path, "U")
	_add_icon("settings", settings_texture_path, "S")

	_handle = Button.new()
	_handle.name = "MenuHandle"
	_handle.mouse_filter = Control.MOUSE_FILTER_STOP
	_handle.focus_mode = Control.FOCUS_NONE
	_handle.flat = true
	_handle.custom_minimum_size = Vector2(handle_size, handle_size)
	_handle.icon = _load_texture(arrow_texture_path)
	_handle.expand_icon = true
	_handle.add_theme_constant_override("icon_max_width", handle_icon_max_width)
	_handle.text = "" if _handle.icon != null else "⌃"

	_handle.add_theme_font_size_override("font_size", 52)
	_handle.add_theme_color_override("font_color", Color.WHITE)
	_handle.add_theme_color_override("font_hover_color", Color.WHITE)
	_handle.add_theme_color_override("font_pressed_color", Color("#FFC62D"))

	_handle.add_theme_stylebox_override("normal", _circle_style(Color.TRANSPARENT, Color.TRANSPARENT, 0))
	_handle.add_theme_stylebox_override("hover", _circle_style(Color(1.0, 1.0, 1.0, 0.08), Color(1.0, 1.0, 1.0, 0.25), 1))
	_handle.add_theme_stylebox_override("pressed", _circle_style(Color(1.0, 1.0, 1.0, 0.12), Color(1.0, 1.0, 1.0, 0.45), 1))

	_handle.gui_input.connect(_on_handle_gui_input)
	_root.add_child(_handle)
	_handle.move_to_front()


func _add_icon(item_id: String, texture_path: String, fallback_text: String) -> void:
	var button := Button.new()
	button.name = item_id.capitalize() + "Button"
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.focus_mode = Control.FOCUS_NONE
	button.flat = true
	button.clip_contents = false
	button.custom_minimum_size = Vector2(icon_size, icon_size)
	button.text = ""

	button.add_theme_stylebox_override("normal", _circle_style(Color.TRANSPARENT, Color.TRANSPARENT, 0))
	button.add_theme_stylebox_override("hover", _circle_style(icon_hover_color, Color.TRANSPARENT, 0))
	button.add_theme_stylebox_override("pressed", _circle_style(icon_pressed_color, Color.TRANSPARENT, 0))

	var texture := _load_texture(texture_path)
	if texture != null:
		var icon_rect := TextureRect.new()
		icon_rect.name = "CenteredAssetIcon"
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_rect.texture = texture
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		button.add_child(icon_rect)
	else:
		var label := Label.new()
		label.name = "CenteredFallbackText"
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.text = fallback_text
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 36)
		label.add_theme_color_override("font_color", Color.WHITE)
		button.add_child(label)

	button.scale = Vector2.ONE
	button.modulate.a = 0.0

	button.button_down.connect(func() -> void:
		_on_icon_button_down(button)
	)

	button.button_up.connect(func() -> void:
		_on_icon_button_up(button)
	)

	button.pressed.connect(func() -> void:
		if _drag_started:
			_bounce_button_cancel(button)
			return

		_activate_icon(item_id)
	)

	_panel.add_child(button)
	_icon_buttons.append(button)

func _on_icon_button_down(button: Button) -> void:
	if _drag_started:
		return

	_play_sfx("click")

	if reduce_motion_enabled:
		return

	_tween_button_scale(button, BUTTON_PRESS_SCALE, BUTTON_DOWN_TIME)

func _on_icon_button_up(button: Button) -> void:
	if reduce_motion_enabled:
		button.scale = Vector2.ONE
		return

	_tween_button_release(button)

func _activate_icon(item_id: String) -> void:
	if item_id == "settings":
		_open_settings_popup()
		return

	if item_id == "cards":
		_open_planet_cards_popup()
		return

	item_pressed.emit(item_id)


func _tween_button_scale(button: Button, target_scale: Vector2, duration: float) -> void:
	if not is_instance_valid(button):
		return

	button.pivot_offset = button.size * 0.5

	if _button_tweens.has(button):
		var old_tween: Tween = _button_tweens[button]
		if old_tween != null and old_tween.is_valid():
			old_tween.kill()

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "scale", target_scale, duration)

	_button_tweens[button] = tween

func _tween_button_release(button: Button) -> void:
	if not is_instance_valid(button):
		return

	button.pivot_offset = button.size * 0.5

	if _button_tweens.has(button):
		var old_tween: Tween = _button_tweens[button]
		if old_tween != null and old_tween.is_valid():
			old_tween.kill()

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "scale", BUTTON_RELEASE_SCALE, BUTTON_UP_TIME)
	tween.tween_property(button, "scale", Vector2.ONE, BUTTON_SETTLE_TIME)

	_button_tweens[button] = tween

func _bounce_button_cancel(button: Button) -> void:
	if not is_instance_valid(button):
		return

	if reduce_motion_enabled:
		button.scale = Vector2.ONE
		return

	_tween_button_scale(button, Vector2.ONE, BUTTON_SETTLE_TIME)
