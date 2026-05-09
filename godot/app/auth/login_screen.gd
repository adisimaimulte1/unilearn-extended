extends Control

const GOOGLE_WEB_CLIENT_ID := "302625054209-3lbcj4hra1c9vqepg0cn5vpj704389dg.apps.googleusercontent.com"

const APP_SCENE := "res://app/content/AppContentScreen.tscn"
const GLOBAL_UP_SHIFT := 80.0
const UNDERLINE_WIDTH_MULTIPLIER := 1.25

const WHITE := Color("#FFFFFF")
const BLACK := Color("#000000")
const TRANSPARENT := Color(1, 1, 1, 0)
const ERROR := Color("#FF6B6B")
const SUCCESS := Color("#8DFFB3")

@onready var panel: PanelContainer = $AuthPanel
@onready var margin: MarginContainer = $AuthPanel/MarginContainer
@onready var box: VBoxContainer = $AuthPanel/MarginContainer/VBoxContainer

@onready var title_label: Label = $AuthPanel/MarginContainer/VBoxContainer/Title
@onready var title_underline: ColorRect = $AuthPanel/MarginContainer/VBoxContainer/TitleUnderline

@onready var email_input: LineEdit = $AuthPanel/MarginContainer/VBoxContainer/Email
@onready var password_input: LineEdit = $AuthPanel/MarginContainer/VBoxContainer/Password
@onready var error_label: Label = $AuthPanel/MarginContainer/VBoxContainer/ErrorLabel
@onready var login_button: Button = $AuthPanel/MarginContainer/VBoxContainer/LoginButton
@onready var google_button: Button = $AuthPanel/MarginContainer/VBoxContainer/GoogleButton
@onready var forgot_button: Button = $AuthPanel/MarginContainer/VBoxContainer/ForgotPasswordButton
@onready var create_button: Button = $AuthPanel/MarginContainer/VBoxContainer/CreateAccountButton

var title_gap_spacer: Control
var button_tweens: Dictionary = {}
var is_register_mode := false
var google_sign_in = null


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	set_offsets_preset(Control.PRESET_FULL_RECT)

	RenderingServer.set_default_clear_color(Color("#050712"))

	_create_title_gap_spacer()
	_setup_layout()
	_setup_style()
	_setup_logic()
	_setup_google_sign_in()

	call_deferred("_fix_button_pivots")
	call_deferred("_fix_underline_size")

	await get_tree().process_frame
	_animate_in()


func _create_title_gap_spacer() -> void:
	title_gap_spacer = Control.new()
	title_gap_spacer.name = "TitleGapSpacer"
	title_gap_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(title_gap_spacer)
	box.move_child(title_gap_spacer, title_underline.get_index() + 1)


func _setup_layout() -> void:
	var screen_size := get_viewport_rect().size
	var side_padding := 54.0

	panel.set_anchors_preset(Control.PRESET_CENTER, false)
	panel.size = Vector2(screen_size.x - side_padding * 2.0, min(screen_size.y * 0.82, 960.0))
	panel.position = (screen_size - panel.size) * 0.5 - Vector2(0.0, GLOBAL_UP_SHIFT)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	margin.add_theme_constant_override("margin_left", 0)
	margin.add_theme_constant_override("margin_right", 0)
	margin.add_theme_constant_override("margin_top", 0)
	margin.add_theme_constant_override("margin_bottom", 0)

	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 30)

	title_label.custom_minimum_size = Vector2(0, 140)
	title_underline.custom_minimum_size = Vector2(360, 6)
	title_gap_spacer.custom_minimum_size = Vector2(0, 40)

	email_input.custom_minimum_size = Vector2(0, 124)
	password_input.custom_minimum_size = Vector2(0, 124)
	login_button.custom_minimum_size = Vector2(0, 124)
	google_button.custom_minimum_size = Vector2(0, 124)

	forgot_button.custom_minimum_size = Vector2(0, 64)
	create_button.custom_minimum_size = Vector2(0, 64)
	error_label.custom_minimum_size = Vector2(0, 44)


func _setup_style() -> void:
	panel.add_theme_stylebox_override("panel", _style_box(TRANSPARENT, 0, 0))

	title_label.text = "Unilearn"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	title_label.add_theme_font_size_override("font_size", 170)
	title_label.add_theme_color_override("font_color", WHITE)

	title_underline.color = WHITE
	title_underline.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	email_input.placeholder_text = "Email"
	password_input.placeholder_text = "Password"
	password_input.secret = true

	_style_input(email_input)
	_style_input(password_input)

	login_button.text = "Login"
	google_button.text = "Sign in with Google"
	forgot_button.text = "Forgot password?"
	create_button.text = "Don’t have an account? Register"

	_style_primary_button(login_button)
	_style_primary_button(google_button)
	_style_text_button(forgot_button)
	_style_text_button(create_button)

	_set_message("", false)


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


func _toggle_auth_mode() -> void:
	is_register_mode = !is_register_mode
	_set_message("", false)

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


func _submit_auth() -> void:
	await _run_auth(is_register_mode)


func _forgot_password() -> void:
	var email := email_input.text.strip_edges()

	if email == "":
		_play_sfx("error")
		_set_message("Enter your email first.", false)
		return

	_set_loading(true)

	var result: Dictionary = await FirebaseAuth.send_password_reset(email)

	_set_loading(false)

	if result.get("success", false):
		_play_sfx("success")
		_set_message("Password reset email sent.", true)
	else:
		_play_sfx("error")
		_set_message(_clean_error(str(result.get("error", "Reset failed."))), false)


func _run_auth(create_new: bool) -> void:
	_set_message("", false)

	var email := email_input.text.strip_edges()
	var password := password_input.text

	if email == "" or password == "":
		_play_sfx("error")
		_set_message("Email and password are required.", false)
		return

	if password.length() < 6:
		_play_sfx("error")
		_set_message("Password must be at least 6 characters.", false)
		return

	_set_loading(true)

	var result: Dictionary

	if create_new:
		result = await FirebaseAuth.create_account(email, password)
	else:
		result = await FirebaseAuth.login(email, password)

	_set_loading(false)

	if result.get("success", false):
		_play_sfx("success")
		get_tree().change_scene_to_file(APP_SCENE)
	else:
		_play_sfx("error")
		_set_message(_clean_error(str(result.get("error", "Login failed."))), false)


func _google_login() -> void:
	_set_message("", false)

	if google_sign_in == null:
		_setup_google_sign_in()

	if google_sign_in == null:
		_play_sfx("error")
		_set_message("Google Sign-In is only available in an exported Android build.", false)
		return

	_set_loading(true)

	if google_sign_in.has_java_method("signInWithGoogleButton"):
		google_sign_in.call("signInWithGoogleButton")
	elif google_sign_in.has_java_method("signInWithAccountChooser"):
		google_sign_in.call("signInWithAccountChooser")
	elif google_sign_in.has_java_method("signIn"):
		google_sign_in.call("signIn")
	else:
		_set_loading(false)
		_play_sfx("error")
		_set_message("Google Sign-In method not found.", false)


func _on_google_sign_in_success(arg1 = "", arg2 = "", arg3 = "") -> void:
	var google_id_token := _extract_google_id_token([arg1, arg2, arg3])

	if google_id_token == "":
		_set_loading(false)
		_play_sfx("error")
		_set_message("Google login worked, but no ID token was found.", false)
		return

	var result: Dictionary = await FirebaseAuth.login_with_google_id_token(google_id_token)

	_set_loading(false)

	if result.get("success", false):
		_play_sfx("success")
		get_tree().change_scene_to_file(APP_SCENE)
	else:
		_play_sfx("error")
		_set_message(_clean_error(str(result.get("error", "Google login failed."))), false)


func _extract_google_id_token(args: Array) -> String:
	for arg in args:
		var value := str(arg)
		if value.count(".") == 2:
			return value

	return ""


func _on_google_sign_in_failed(error: String) -> void:
	_set_loading(false)
	_play_sfx("error")
	_set_message(_clean_error(error), false)


func _set_loading(value: bool) -> void:
	login_button.disabled = value
	create_button.disabled = value
	google_button.disabled = value
	forgot_button.disabled = value or is_register_mode

	_apply_dim_style(value)

	if value:
		_set_message("Connecting...", true)
	else:
		_set_message("", false)


func _set_message(message: String, success: bool) -> void:
	error_label.text = message
	error_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	error_label.add_theme_font_size_override("font_size", 38)

	if success:
		error_label.add_theme_color_override("font_color", SUCCESS)
	else:
		error_label.add_theme_color_override("font_color", ERROR)


func _clean_error(error: String) -> String:
	match error:
		"EMAIL_EXISTS":
			return "An account already exists with this email."
		"EMAIL_NOT_FOUND":
			return "No account found with this email."
		"INVALID_PASSWORD":
			return "Wrong password."
		"INVALID_LOGIN_CREDENTIALS":
			return "Wrong email or password."
		"INVALID_EMAIL":
			return "Invalid email address."
		"WEAK_PASSWORD : Password should be at least 6 characters":
			return "Password should be at least 6 characters."
		"USER_DISABLED":
			return "This account has been disabled."
		"MISSING_EMAIL":
			return "Enter your email first."
		"TOO_MANY_ATTEMPTS_TRY_LATER":
			return "Too many attempts. Try again later."
		"OPERATION_NOT_ALLOWED":
			return "This login method is not enabled in Firebase."
		"REQUEST_FAILED":
			return "Could not connect to Firebase."
		"INVALID_RESPONSE":
			return "Firebase returned an invalid response."
		_:
			return error.replace("_", " ").capitalize()


func _apply_dim_style(dim: bool) -> void:
	var color := Color(1, 1, 1, 0.35) if dim else WHITE
	var placeholder := Color(1, 1, 1, 0.35) if dim else Color(1, 1, 1, 0.62)

	title_label.add_theme_color_override("font_color", color)
	title_underline.color = color

	email_input.add_theme_color_override("font_color", color)
	password_input.add_theme_color_override("font_color", color)

	email_input.add_theme_color_override("font_placeholder_color", placeholder)
	password_input.add_theme_color_override("font_placeholder_color", placeholder)

	email_input.add_theme_stylebox_override("normal", _style_box(TRANSPARENT, 4, 34, color))
	password_input.add_theme_stylebox_override("normal", _style_box(TRANSPARENT, 4, 34, color))


func _play_sfx(id: String) -> void:
	if has_node("/root/UnilearnSFX"):
		get_node("/root/UnilearnSFX").play(id)
