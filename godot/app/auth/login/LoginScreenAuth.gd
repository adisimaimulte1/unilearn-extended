extends "res://app/auth/login/LoginScreenUi.gd"

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

		if not result.get("success", false):
			_set_loading(false)
			_play_sfx("error")
			_set_message(_clean_error(str(result.get("error", "Register failed."))), false)
			return

		if not await _initialize_database_only():
			return

		_mark_tutorial_pending_for_new_account()

		await _sync_public_profile_after_login()

		if not await _preload_planet_cards(true):
			return

		await _sync_achievements_after_login()
		_enter_app()
		return

	result = await FirebaseAuth.login(email, password)

	if not result.get("success", false):
		_set_loading(false)
		_play_sfx("error")
		_set_message(_clean_error(str(result.get("error", "Login failed."))), false)
		return

	await _sync_public_profile_after_login()

	if not await _preload_planet_cards(false):
		return

	await _sync_achievements_after_login()
	_enter_app()


func _mark_tutorial_pending_for_new_account() -> void:
	var settings := get_node_or_null("/root/UnilearnUserSettings")
	if settings != null and settings.has_method("mark_tutorial_pending_for_current_account"):
		settings.call("mark_tutorial_pending_for_current_account")


func _sync_public_profile_after_login() -> void:
	var settings := get_node_or_null("/root/UnilearnUserSettings")
	var database := get_node_or_null("/root/FirebaseDatabase")

	if settings == null or database == null:
		return

	if not database.has_method("get_user_profile"):
		return

	var result: Dictionary = await database.call("get_user_profile")

	if not bool(result.get("success", false)):
		return

	var raw_user: Variant = result.get("user", {})
	_save_public_display_name_locally_from_user(raw_user)


func _save_public_display_name_locally_from_user(raw_user: Variant) -> void:
	var settings := get_node_or_null("/root/UnilearnUserSettings")
	if settings == null or not settings.has_method("set_display_name"):
		return

	var user: Dictionary = raw_user if raw_user is Dictionary else {}
	var display_name := str(user.get("displayName", "")).strip_edges()
	settings.call("set_display_name", display_name)


func _sync_achievements_after_login() -> void:
	_set_message("Syncing achievements...", true)

	var tracker := get_node_or_null("/root/UnilearnAchievements")
	if tracker == null:
		tracker = get_node_or_null("/root/UnilearnAchievementTracker")
	if tracker == null:
		tracker = get_node_or_null("/root/AchievementTracker")

	if tracker == null:
		return

	if tracker.has_method("force_reload_from_backend_after_login"):
		await tracker.call("force_reload_from_backend_after_login")
	elif tracker.has_method("load_from_backend"):
		await tracker.call("load_from_backend")


func _initialize_database_only() -> bool:
	_set_message("Setting up your universe...", true)

	if not has_node("/root/FirebaseDatabase"):
		_set_loading(false)
		_play_sfx("error")
		_set_message("Database service is not added as an autoload.", false)
		return false

	var init_result: Dictionary = await FirebaseDatabase.initialize_user_account()


	if not init_result.get("success", false):
		_set_loading(false)
		_play_sfx("error")
		_set_message(_clean_error(str(init_result.get("error", "Database setup failed."))), false)
		return false

	_save_public_display_name_locally_from_user(init_result.get("user", {}))

	return true


func _preload_planet_cards(force_refresh: bool = false) -> bool:
	_set_message("Loading your universe...", true)

	if not has_node("/root/PlanetCardsCache"):
		_set_loading(false)
		_play_sfx("error")
		_set_message("Planet cards cache is not added as an autoload.", false)
		return false

	if force_refresh:
		PlanetCardsCache.clear_cache()

	var cards: Array[PlanetData] = await PlanetCardsCache.ensure_loaded(force_refresh)


	if cards.is_empty():
		_set_loading(false)
		_play_sfx("error")
		_set_message("No planet cards were found. Try again in a moment.", false)
		return false

	return true
