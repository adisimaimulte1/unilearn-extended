extends "res://app/auth/login/LoginScreenAuth.gd"

func _enter_app() -> void:
	_set_loading(false)
	_play_sfx("success")
	get_tree().change_scene_to_file(APP_SCENE)


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

	if not result.get("success", false):
		_set_loading(false)
		_play_sfx("error")
		_set_message(_clean_error(str(result.get("error", "Google login failed."))), false)
		return

	var is_new_google_user := _is_google_new_user(result)

	print("Google is new user: ", is_new_google_user)

	if is_new_google_user:
		if not await _initialize_database_only():
			return

		if not await _preload_planet_cards(true):
			return

		_enter_app()
		return

	if not await _preload_planet_cards(false):
		return

	_enter_app()

func _is_google_new_user(result: Dictionary) -> bool:
	var data: Dictionary = result.get("data", {})

	if not data.has("isNewUser"):
		print("Google result has no isNewUser field: ", data)
		return false

	var value = data.get("isNewUser", false)

	if value is bool:
		return value

	return str(value).strip_edges().to_lower() == "true"

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

func _set_message(message: String, status_message: bool) -> void:
	error_label.text = message
	error_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	error_label.add_theme_font_size_override("font_size", 38)

	if status_message:
		error_label.add_theme_color_override("font_color", WHITE)
	else:
		error_label.add_theme_color_override("font_color", _get_highlight_color())


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
		"MISSING_ID_TOKEN":
			return "Login worked, but the account token is missing."
		"MISSING_TOKEN":
			return "Login token was not sent to the server."
		"INVALID_TOKEN":
			return "Your login token is invalid for this Firebase project."
		"USER_INIT_FAILED":
			return "Could not create your Unilearn database."
		"BACKEND_FAILED":
			return "The backend refused the database setup."
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
