extends "res://app/ui/bottom_menu/BottomMenuBuild.gd"


func _open_help_popup() -> void:
	if is_instance_valid(_help_popup):
		return

	item_pressed.emit("popup_help_opened")
	item_pressed.emit("help")

	close_menu()
	_play_sfx("whoosh")
	await get_tree().process_frame
	await get_tree().process_frame

	_help_popup = HELP_POPUP_SCRIPT.new()
	_help_popup.name = "UnilearnHelpPopup"

	if _help_popup.has_method("setup"):
		_help_popup.call("setup", reduce_motion_enabled)

	add_child(_help_popup)

	if _help_popup.has_signal("closed"):
		_help_popup.connect("closed", func() -> void:
			_help_popup = null
			item_pressed.emit("popup_help_closed")
			item_pressed.emit("help_closed")
		)

func _open_settings_popup() -> void:
	if is_instance_valid(_settings_popup):
		return

	item_pressed.emit("popup_settings_opened")
	item_pressed.emit("settings")

	close_menu()
	_play_sfx("whoosh")
	await get_tree().process_frame
	await get_tree().process_frame

	var settings_popup := CanvasLayer.new()
	settings_popup.set_script(SETTINGS_POPUP_SCRIPT)
	settings_popup.name = "UnilearnSettingsPopup"
	_settings_popup = settings_popup as UnilearnSettingsPopup
	add_child(_settings_popup)

	_settings_popup.setup(sfx_enabled, apollo_enabled, reduce_motion_enabled, music_enabled)

	if _settings_popup.has_signal("music_changed"):
		_settings_popup.music_changed.connect(func(enabled: bool) -> void:
			music_enabled = enabled

			if _settings_node != null and _settings_node.has_method("set_music_enabled"):
				_settings_node.call("set_music_enabled", enabled)

			if _music_node == null:
				_music_node = get_node_or_null("/root/UnilearnMusic")

			if _music_node != null and _music_node.has_method("set_enabled"):
				_music_node.call("set_enabled", enabled)

			item_pressed.emit("settings_music_" + ("on" if enabled else "off"))
		)

	_settings_popup.sfx_changed.connect(func(enabled: bool) -> void:
		sfx_enabled = enabled

		if _settings_node != null and _settings_node.has_method("set_sfx_enabled"):
			_settings_node.call("set_sfx_enabled", enabled)

		if _sfx_node != null and _sfx_node.has_method("set_enabled"):
			_sfx_node.call("set_enabled", enabled)

		item_pressed.emit("settings_sfx_" + ("on" if enabled else "off"))
	)

	_settings_popup.apollo_changed.connect(func(enabled: bool) -> void:
		apollo_enabled = enabled

		if _settings_node != null and _settings_node.has_method("set_apollo_enabled"):
			_settings_node.call("set_apollo_enabled", enabled)

		item_pressed.emit("settings_apollo_" + ("on" if enabled else "off"))
	)

	_settings_popup.reduce_motion_changed.connect(func(enabled: bool) -> void:
		set_reduce_motion_enabled(enabled)

		if _settings_node != null and _settings_node.has_method("set_reduce_motion_enabled"):
			_settings_node.call("set_reduce_motion_enabled", enabled)

		item_pressed.emit("settings_reduce_motion_" + ("on" if enabled else "off"))
	)

	_settings_popup.reset_camera_requested.connect(func() -> void:
		item_pressed.emit("settings_reset_camera")
	)

	_settings_popup.logout_requested.connect(func() -> void:
		item_pressed.emit("settings_logout")
	)

	if _settings_popup.has_signal("delete_account_requested"):
		_settings_popup.delete_account_requested.connect(func() -> void:
			item_pressed.emit("settings_delete_account")
		)

	_settings_popup.closed.connect(func() -> void:
		_settings_popup = null
		item_pressed.emit("popup_settings_closed")
		item_pressed.emit("settings_closed")
	)

func _open_planet_cards_popup() -> void:
	if is_instance_valid(_planet_cards_popup):
		return

	item_pressed.emit("popup_cards_opened")
	item_pressed.emit("cards")

	close_menu()
	_play_sfx("whoosh")
	await get_tree().process_frame
	await get_tree().process_frame

	var cards_popup := CanvasLayer.new()
	cards_popup.set_script(PLANET_CARDS_POPUP_SCRIPT)
	cards_popup.name = "UnilearnPlanetCardsPopup"
	_planet_cards_popup = cards_popup as UnilearnPlanetCardsPopup
	add_child(_planet_cards_popup)

	_planet_cards_popup.setup(reduce_motion_enabled)

	_planet_cards_popup.closed.connect(func() -> void:
		_planet_cards_popup = null
		item_pressed.emit("popup_cards_closed")
		item_pressed.emit("cards_closed")
	)


func _open_achievements_popup() -> void:
	if is_instance_valid(_achievements_popup):
		return

	item_pressed.emit("popup_achievements_opened")
	item_pressed.emit("achievements")

	close_menu()
	_play_sfx("whoosh")
	await get_tree().process_frame
	await get_tree().process_frame

	var popup := CanvasLayer.new()
	popup.set_script(ACHIEVEMENTS_POPUP_SCRIPT)
	popup.name = "UnilearnAchievementsPopup"
	_achievements_popup = popup

	if _achievements_popup.has_method("setup"):
		_achievements_popup.call("setup", reduce_motion_enabled)

	add_child(_achievements_popup)

	if _achievements_popup.has_signal("closed"):
		_achievements_popup.connect("closed", func() -> void:
			_achievements_popup = null
			item_pressed.emit("popup_achievements_closed")
			item_pressed.emit("achievements_closed")
		)


func _open_galaxy_popup() -> void:
	if is_instance_valid(_galaxy_popup):
		return

	item_pressed.emit("popup_galaxy_opened")
	item_pressed.emit("playgrounds")

	close_menu()
	_play_sfx("whoosh")
	await get_tree().process_frame
	await get_tree().process_frame

	var galaxy_state := get_node_or_null("/root/GalaxyState")
	if galaxy_state != null:
		if galaxy_state.has_method("get_config"):
			_galaxy_config = galaxy_state.call("get_config")
		elif galaxy_state.has_method("load_settings"):
			_galaxy_config = galaxy_state.call("load_settings")

	if _galaxy_config == null:
		_galaxy_config = SimulationPhysicsConfig.new()

	if galaxy_state != null and galaxy_state.has_method("load_into"):
		_galaxy_config = galaxy_state.call("load_into", _galaxy_config)

	var galaxy_popup := CanvasLayer.new()
	galaxy_popup.set_script(GALAXY_POPUP_SCRIPT)
	galaxy_popup.name = "UnilearnGalaxyPopup"
	_galaxy_popup = galaxy_popup

	if _galaxy_popup.has_method("setup"):
		var saved_bodies: Array = []
		if galaxy_state != null and galaxy_state.has_method("get_bodies"):
			saved_bodies = galaxy_state.call("get_bodies")

		_galaxy_popup.call("setup", _galaxy_config, reduce_motion_enabled, saved_bodies)

	add_child(_galaxy_popup)
	galaxy_popup_opened.emit(_galaxy_popup)

	if _galaxy_popup.has_signal("config_value_changed"):
		_galaxy_popup.connect("config_value_changed", func(property_name: String, value) -> void:
			if galaxy_state != null and galaxy_state.has_method("set_config_value"):
				galaxy_state.call("set_config_value", property_name, value, true)
			item_pressed.emit("galaxy_config_" + property_name)
		)

	if _galaxy_popup.has_signal("center_anchor_requested"):
		_galaxy_popup.connect("center_anchor_requested", func() -> void:
			item_pressed.emit("galaxy_center_anchor")
		)

	if _galaxy_popup.has_signal("reset_orbits_requested"):
		_galaxy_popup.connect("reset_orbits_requested", func() -> void:
			item_pressed.emit("galaxy_reset_orbits")
		)

	if _galaxy_popup.has_signal("clear_trails_requested"):
		_galaxy_popup.connect("clear_trails_requested", func() -> void:
			item_pressed.emit("galaxy_clear_trails")
		)

	if _galaxy_popup.has_signal("reset_camera_requested"):
		_galaxy_popup.connect("reset_camera_requested", func() -> void:
			_emit_reset_camera_after_galaxy_popup_closed()
		)

	if _galaxy_popup.has_signal("closed"):
		_galaxy_popup.connect("closed", func() -> void:
			if galaxy_state != null and galaxy_state.has_method("replace_config") and _galaxy_config != null:
				galaxy_state.call("replace_config", _galaxy_config, true)

			_galaxy_popup = null
			item_pressed.emit("popup_galaxy_closed")
			item_pressed.emit("playgrounds_closed")
		)


func _emit_reset_camera_after_galaxy_popup_closed() -> void:
	var popup := _galaxy_popup
	if popup != null and is_instance_valid(popup) and popup.has_signal("closed"):
		await popup.closed

	if not is_inside_tree():
		return

	item_pressed.emit("settings_reset_camera")
