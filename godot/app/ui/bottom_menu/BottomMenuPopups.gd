extends "res://app/ui/bottom_menu/BottomMenuBuild.gd"


func _open_multiplayer_popup() -> void:
	if is_instance_valid(_multiplayer_popup):
		return

	item_pressed.emit("popup_multiplayer_opened")
	item_pressed.emit("multiplayer")

	close_menu()
	_play_sfx("whoosh")
	await get_tree().process_frame
	await get_tree().process_frame

	_multiplayer_popup = MULTIPLAYER_POPUP_SCRIPT.new()
	_multiplayer_popup.name = "UnilearnMultiplayerPopup"

	if _multiplayer_popup.has_method("setup"):
		_multiplayer_popup.call("setup", reduce_motion_enabled)

	add_child(_multiplayer_popup)

	if _multiplayer_popup.has_signal("closed"):
		_multiplayer_popup.connect("closed", func() -> void:
			_multiplayer_popup = null
			item_pressed.emit("popup_multiplayer_closed")
			item_pressed.emit("multiplayer_closed")
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

func _open_trade_card_selection_popup(peer_name: String = "", peer_uid: String = "", request_id: String = "") -> void:
	if is_instance_valid(_planet_cards_popup):
		return

	item_pressed.emit("popup_trade_cards_opened")
	item_pressed.emit("trade_cards")

	close_menu()
	_play_sfx("whoosh")
	await get_tree().process_frame
	await get_tree().process_frame

	var cards_popup := CanvasLayer.new()
	cards_popup.set_script(PLANET_CARDS_POPUP_SCRIPT)
	cards_popup.name = "UnilearnTradeCardSelectionPopup"
	_planet_cards_popup = cards_popup as UnilearnPlanetCardsPopup

	if _planet_cards_popup.has_method("setup_trade_selection"):
		_planet_cards_popup.call("setup_trade_selection", peer_name, peer_uid, request_id, reduce_motion_enabled)
	else:
		_planet_cards_popup.setup(reduce_motion_enabled)

	add_child(_planet_cards_popup)

	_connect_multiplayer_trade_visual_signals()

	if _planet_cards_popup.has_signal("trade_card_chosen"):
		_planet_cards_popup.connect("trade_card_chosen", func(card_data, target_uid: String, target_name: String) -> void:
			item_pressed.emit("trade_card_selected")
			var database := get_node_or_null("/root/FirebaseDatabase")
			if database != null and database.has_method("submit_multiplayer_trade_card"):
				var result: Variant = await database.call("submit_multiplayer_trade_card", target_uid, card_data, request_id)
				if not (result is Dictionary) or not bool((result as Dictionary).get("success", false)):
					_play_sfx("error")
		)

	var database := get_node_or_null("/root/FirebaseDatabase")
	if database != null and database.has_method("get_multiplayer_trade_state"):
		var cached: Variant = database.call("get_multiplayer_trade_state", peer_uid)
		if cached is Dictionary and not (cached as Dictionary).is_empty():
			var cached_payload := cached as Dictionary
			# A payload with a start time belongs to a trade whose final animation
			# already began. Never hydrate a newly opened trade popup from it.
			# This is what previously showed the last traded planet before the
			# other player had selected anything in the new trade.
			if int(cached_payload.get("tradeStartAt", 0)) > 0:
				if database.has_method("clear_multiplayer_trade_state"):
					database.call("clear_multiplayer_trade_state", peer_uid)
			else:
				_apply_multiplayer_trade_visual_payload(cached_payload)

	_planet_cards_popup.closed.connect(func() -> void:
		_planet_cards_popup = null
		item_pressed.emit("popup_trade_cards_closed")
		item_pressed.emit("trade_cards_closed")
	)



func _open_achievements_popup() -> void:
	if is_instance_valid(_achievements_popup):
		return

	item_pressed.emit("popup_achievements_opened")
	item_pressed.emit("achievements")

	close_menu()
	_play_sfx("whoosh")
	# Same cadence as the lighter popups: let the bottom menu render its close
	# animation before even the lightweight achievements shell is added.
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


func _connect_multiplayer_trade_visual_signals() -> void:
	var database := get_node_or_null("/root/FirebaseDatabase")
	if database == null:
		return
	var selected_cb := Callable(self, "_on_multiplayer_trade_peer_card_selected")
	if database.has_signal("multiplayer_trade_peer_card_selected") and not database.is_connected("multiplayer_trade_peer_card_selected", selected_cb):
		database.connect("multiplayer_trade_peer_card_selected", selected_cb)
	var start_cb := Callable(self, "_on_multiplayer_trade_start")
	if database.has_signal("multiplayer_trade_start") and not database.is_connected("multiplayer_trade_start", start_cb):
		database.connect("multiplayer_trade_start", start_cb)


func _on_multiplayer_trade_peer_card_selected(payload: Dictionary) -> void:
	if not _trade_payload_matches_open_popup(payload):
		return
	_apply_multiplayer_trade_visual_payload(payload)


func _on_multiplayer_trade_start(payload: Dictionary) -> void:
	if not _trade_payload_matches_open_popup(payload):
		return
	_apply_committed_multiplayer_trade_to_local_cache(payload)
	_apply_multiplayer_trade_visual_payload(payload)
	if not is_instance_valid(_planet_cards_popup):
		return
	if not _planet_cards_popup.has_method("start_multiplayer_trade_visual"):
		return
	var peer_uid := str(payload.get("peerUid", "")).strip_edges()
	if peer_uid.is_empty():
		return
	_planet_cards_popup.call(
		"start_multiplayer_trade_visual",
		int(payload.get("tradeStartAt", 0)),
		int(payload.get("serverNow", 0))
	)


func _trade_payload_matches_open_popup(payload: Dictionary) -> bool:
	if not is_instance_valid(_planet_cards_popup):
		return false
	var payload_request_id := str(payload.get("requestId", "")).strip_edges()
	if payload_request_id.is_empty():
		return false
	if _planet_cards_popup.has_method("get_trade_request_id"):
		return str(_planet_cards_popup.call("get_trade_request_id")).strip_edges() == payload_request_id
	return true


func _apply_committed_multiplayer_trade_to_local_cache(payload: Dictionary) -> void:
	if not bool(payload.get("tradeCommitted", false)):
		return
	if not is_instance_valid(_planet_cards_popup):
		return
	if not _planet_cards_popup.has_method("get_trade_selected_card_id"):
		return
	var sent_card_id := str(_planet_cards_popup.call("get_trade_selected_card_id")).strip_edges()
	if sent_card_id.is_empty():
		return
	var peer_card_value: Variant = payload.get("peerCard", {})
	if not (peer_card_value is Dictionary) or (peer_card_value as Dictionary).is_empty():
		return
	var received_card := PlanetData.from_firebase_dict(peer_card_value as Dictionary)
	if received_card == null:
		return
	var cache := get_node_or_null("/root/PlanetCardsCache")
	if cache != null and cache.has_method("apply_committed_trade_swap"):
		cache.call("apply_committed_trade_swap", sent_card_id, received_card)


func _apply_multiplayer_trade_visual_payload(payload: Dictionary) -> void:
	if not is_instance_valid(_planet_cards_popup):
		return
	var peer_card: Variant = payload.get("peerCard", {})
	if not (peer_card is Dictionary) or (peer_card as Dictionary).is_empty():
		return
	var card := PlanetData.from_firebase_dict(peer_card as Dictionary)
	if card == null:
		return
	if _planet_cards_popup.has_method("set_trade_peer_selected_card_preview"):
		_planet_cards_popup.call("set_trade_peer_selected_card_preview", card)
