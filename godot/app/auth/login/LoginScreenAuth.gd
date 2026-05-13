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

		if not await _preload_planet_cards(true):
			return

		_enter_app()
		return

	result = await FirebaseAuth.login(email, password)

	if not result.get("success", false):
		_set_loading(false)
		_play_sfx("error")
		_set_message(_clean_error(str(result.get("error", "Login failed."))), false)
		return

	if not await _preload_planet_cards(false):
		return

	_enter_app()


func _initialize_database_only() -> bool:
	_set_message("Setting up your universe...", true)

	if not has_node("/root/FirebaseDatabase"):
		_set_loading(false)
		_play_sfx("error")
		_set_message("Database service is not added as an autoload.", false)
		return false

	var init_result: Dictionary = await FirebaseDatabase.initialize_user_account()

	print("Unilearn database init result: ", init_result)

	if not init_result.get("success", false):
		_set_loading(false)
		_play_sfx("error")
		_set_message(_clean_error(str(init_result.get("error", "Database setup failed."))), false)
		return false

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

	print("Planet cards loaded: ", cards.size())

	if cards.is_empty():
		_set_loading(false)
		_play_sfx("error")
		_set_message("No planet cards were found. Try again in a moment.", false)
		return false

	return true
