extends "res://app/auth/login/LoginScreenBase.gd"

func _setup_logic() -> void:
	_make_button_bouncy(login_button)
	_make_button_bouncy(google_button)

	login_button.pressed.connect(_submit_auth)
	google_button.pressed.connect(_google_login)

	forgot_button.pressed.connect(func() -> void:
		_play_sfx("click")
		_forgot_password()
	)

	create_button.pressed.connect(func() -> void:
		_play_sfx("toggle")
		_toggle_auth_mode()
	)

func _setup_settings_listener() -> void:
	if not has_node("/root/UnilearnUserSettings"):
		return

	var settings = get_node("/root/UnilearnUserSettings")

	if settings.has_signal("settings_changed") and not settings.settings_changed.is_connected(_on_settings_changed):
		settings.settings_changed.connect(_on_settings_changed)

func _setup_google_sign_in() -> void:
	if not Engine.has_singleton("GodotGoogleSignIn"):
		return

	google_sign_in = Engine.get_singleton("GodotGoogleSignIn")

	if google_sign_in.has_java_method("initialize"):
		google_sign_in.call("initialize", GOOGLE_WEB_CLIENT_ID)

	if google_sign_in.has_signal("sign_in_success"):
		if not google_sign_in.sign_in_success.is_connected(_on_google_sign_in_success):
			google_sign_in.sign_in_success.connect(_on_google_sign_in_success)

	if google_sign_in.has_signal("sign_in_failed"):
		if not google_sign_in.sign_in_failed.is_connected(_on_google_sign_in_failed):
			google_sign_in.sign_in_failed.connect(_on_google_sign_in_failed)


func _on_settings_changed() -> void:
	if error_label.text.strip_edges() == "":
		return

	var current_color := error_label.get_theme_color("font_color")
	var is_status := current_color.is_equal_approx(WHITE)

	_set_message(error_label.text, is_status)


func _get_highlight_color() -> Color:
	if has_node("/root/UnilearnUserSettings"):
		var settings = get_node("/root/UnilearnUserSettings")

		if settings.has_method("get_accent_color"):
			return settings.get_accent_color()

	return Color.WHITE


func _toggle_auth_mode() -> void:
	is_register_mode = !is_register_mode
	_set_message("", false)

	google_button.text = "Sign in with Google"

	if is_register_mode:
		login_button.text = "Register"
		create_button.text = "Already have an account? Login"
		forgot_button.disabled = true
		forgot_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
		forgot_button.modulate.a = 0.0
	else:
		login_button.text = "Login"
		create_button.text = "Don’t have an account? Register"
		forgot_button.visible = true
		forgot_button.disabled = false
		forgot_button.mouse_filter = Control.MOUSE_FILTER_STOP
		forgot_button.modulate.a = 1.0


func _make_button_bouncy(button: Button) -> void:
	button.button_down.connect(func():
		_play_sfx("click")
		_fix_button_pivots()
		_scale_button(button, Vector2(0.94, 0.94), 0.08)
	)

	button.button_up.connect(func():
		_fix_button_pivots()
		_scale_button(button, Vector2(1.04, 1.04), 0.11, true)
	)

func _scale_button(button: Button, target_scale: Vector2, duration: float, return_to_normal := false) -> void:
	if button_tweens.has(button) and button_tweens[button]:
		button_tweens[button].kill()

	var t := create_tween()
	button_tweens[button] = t

	t.set_trans(Tween.TRANS_BACK)
	t.set_ease(Tween.EASE_OUT)
	t.tween_property(button, "scale", target_scale, duration)

	if return_to_normal:
		t.tween_property(button, "scale", Vector2.ONE, 0.1)


func _animate_in() -> void:
	_play_sfx("open")

	panel.modulate.a = 0.0
	panel.position.y += 90.0
	panel.scale = Vector2(0.96, 0.96)
	panel.pivot_offset = panel.size * 0.5

	title_underline.scale.x = 0.0

	for child in box.get_children():
		if child is Control and child != title_gap_spacer:
			child.modulate.a = 0.0
			child.position.y += 28.0

	var t := create_tween()
	t.set_trans(Tween.TRANS_SINE)
	t.set_ease(Tween.EASE_OUT)

	t.tween_property(panel, "modulate:a", 1.0, 0.45)
	t.parallel().tween_property(panel, "position:y", panel.position.y - 90.0, 0.55)
	t.parallel().tween_property(panel, "scale", Vector2.ONE, 0.55)

	for i in box.get_child_count():
		var child := box.get_child(i)

		if child is Control and child != title_gap_spacer:
			t.parallel().tween_interval(0.08 + i * 0.055).finished.connect(func():
				var local := create_tween()
				local.set_trans(Tween.TRANS_SINE)
				local.set_ease(Tween.EASE_OUT)
				local.tween_property(child, "modulate:a", 1.0, 0.32)
				local.parallel().tween_property(child, "position:y", child.position.y - 28.0, 0.32)

				if child == title_underline:
					_fix_underline_size()
					title_underline.scale.x = 0.0
					local.parallel().tween_property(title_underline, "scale:x", 1.0, 0.42)
			)


func _fix_underline_size() -> void:
	var font := title_label.get_theme_font("font")
	var font_size := title_label.get_theme_font_size("font_size")
	var text_size := font.get_string_size(title_label.text, HORIZONTAL_ALIGNMENT_CENTER, -1.0, font_size)
	var width := text_size.x * UNDERLINE_WIDTH_MULTIPLIER

	title_underline.custom_minimum_size = Vector2(width, 6)
	title_underline.size = Vector2(width, 6)
	title_underline.pivot_offset = title_underline.size * 0.5

func _fix_button_pivots() -> void:
	login_button.pivot_offset = login_button.size * 0.5
	google_button.pivot_offset = google_button.size * 0.5


func _style_input(input: LineEdit) -> void:
	input.add_theme_font_size_override("font_size", 46)
	input.add_theme_color_override("font_color", WHITE)
	input.add_theme_color_override("font_placeholder_color", Color(1, 1, 1, 0.62))
	input.add_theme_color_override("caret_color", WHITE)
	input.add_theme_color_override("selection_color", TRANSPARENT)

	input.add_theme_stylebox_override("normal", _style_box(TRANSPARENT, 4, 34, WHITE))
	input.add_theme_stylebox_override("focus", _style_box(TRANSPARENT, 5, 34, WHITE))
	input.add_theme_stylebox_override("read_only", _style_box(TRANSPARENT, 4, 34, WHITE))

	input.caret_blink = true

func _style_primary_button(button: Button) -> void:
	button.add_theme_font_size_override("font_size", 40)

	button.add_theme_color_override("font_color", BLACK)
	button.add_theme_color_override("font_hover_color", BLACK)
	button.add_theme_color_override("font_pressed_color", BLACK)
	button.add_theme_color_override("font_disabled_color", BLACK)

	button.add_theme_stylebox_override("normal", _style_box(WHITE, 0, 34))
	button.add_theme_stylebox_override("hover", _style_box(WHITE, 0, 34))
	button.add_theme_stylebox_override("pressed", _style_box(WHITE, 0, 34))
	button.add_theme_stylebox_override("disabled", _style_box(Color(1, 1, 1, 0.35), 0, 34))

func _style_text_button(button: Button) -> void:
	button.flat = true
	button.add_theme_font_size_override("font_size", 30)
	button.add_theme_color_override("font_color", WHITE)
	button.add_theme_color_override("font_hover_color", WHITE)
	button.add_theme_color_override("font_pressed_color", WHITE)

func _style_box(bg: Color, border_width: int, radius: int, border_color: Color = Color.TRANSPARENT) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.border_width_left = border_width
	style.border_width_right = border_width
	style.border_width_top = border_width
	style.border_width_bottom = border_width
	style.border_color = border_color
	style.content_margin_left = 38
	style.content_margin_right = 38
	style.content_margin_top = 24
	style.content_margin_bottom = 24
	return style
