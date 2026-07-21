extends "res://app/ui/popups/multiplayer_popup/MultiplayerPopupBase.gd"

var _local_trade_available_for_nearby_session := 0


func _build_ui() -> void:
	_root = Control.new()
	_root.name = "MultiplayerPopupRoot"
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

	_connect_settings_signal()
	_update_nearby_dynamic_theme_colors(true)

	_dim.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventScreenTouch and event.pressed:
			_release_username_focus()
			close_popup()
			get_viewport().set_input_as_handled()
		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_release_username_focus()
			close_popup()
			get_viewport().set_input_as_handled()
	)

	_slide_root = Control.new()
	_slide_root.name = "MultiplayerSlideRoot"
	_slide_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_slide_root.modulate.a = 0.0
	_root.add_child(_slide_root)

	_panel = PanelContainer.new()
	_panel.name = "MultiplayerPanel"
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.add_theme_stylebox_override("panel", _panel_style())
	_slide_root.add_child(_panel)

	_body_root = Control.new()
	_body_root.name = "MultiplayerBodyRoot"
	_body_root.mouse_filter = Control.MOUSE_FILTER_PASS
	_panel.add_child(_body_root)

	_build_main_view()
	_setup_multiplayer_request_toast()
	_connect_multiplayer_request_response_signals()


func _build_main_view() -> void:
	_main_view = Control.new()
	_main_view.name = "MultiplayerMainView"
	_main_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	_body_root.add_child(_main_view)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", panel_padding_x)
	margin.add_theme_constant_override("margin_right", panel_padding_x)
	margin.add_theme_constant_override("margin_top", panel_padding_y)
	margin.add_theme_constant_override("margin_bottom", panel_padding_y)
	_main_view.add_child(margin)

	var content := VBoxContainer.new()
	content.name = "MultiplayerContent"
	content.add_theme_constant_override("separation", 34)
	margin.add_child(content)

	var title_box := VBoxContainer.new()
	title_box.custom_minimum_size = Vector2(0, 230)
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_box.add_theme_constant_override("separation", 6)
	content.add_child(title_box)

	var title := Label.new()
	title.text = "MULTIPLAYER"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 118)
	title.add_theme_color_override("font_color", COLOR_TEXT)
	title.clip_text = false
	_apply_app_font(title)
	title_box.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Sync universes and trade planet cards!"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	subtitle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.add_theme_font_size_override("font_size", 52)
	subtitle.add_theme_color_override("font_color", COLOR_SUBTITLE)
	_apply_app_font(subtitle)
	title_box.add_child(subtitle)

	var search_row_height := 150.0
	var search_gap := 22.0

	var search_row := Control.new()
	search_row.name = "UsernameRow"
	search_row.custom_minimum_size = Vector2(0, search_row_height)
	search_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search_row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	content.add_child(search_row)

	var username_shell := PanelContainer.new()
	username_shell.name = "UsernameShell"
	username_shell.mouse_filter = Control.MOUSE_FILTER_STOP
	username_shell.add_theme_stylebox_override("panel", _search_style())
	search_row.add_child(username_shell)

	_connect_button = Control.new()
	_connect_button.name = "ConnectMultiplayerButton"
	_connect_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_connect_button.scale = Vector2.ONE
	search_row.add_child(_connect_button)

	_connect_button.draw.connect(func() -> void:
		var rect := Rect2(Vector2.ZERO, _connect_button.size)
		var highlight := _get_theme_highlight_color()
		var icon_color := COLOR_TEXT.lerp(highlight, _button_highlight_blend)

		_connect_button.draw_style_box(_square_button_style(_button_pressed), rect)
		if _sync_mode_active:
			_draw_sync_exit_button_icon(_connect_button, icon_color)
		else:
			_draw_multiplayer_button_icon(_connect_button, icon_color)
	)

	var layout_search_row := func() -> void:
		var row_width := search_row.size.x
		var row_height := search_row.size.y
		if row_height <= 0.0:
			row_height = search_row_height

		var button_size := row_height
		var username_width: float = max(0.0, row_width - button_size - search_gap)

		username_shell.position = Vector2.ZERO
		username_shell.size = Vector2(username_width, row_height)
		username_shell.custom_minimum_size = username_shell.size

		_connect_button.position = Vector2(username_width + search_gap, 0.0)
		_connect_button.size = Vector2(button_size, row_height)
		_connect_button.custom_minimum_size = _connect_button.size
		_connect_button.pivot_offset = _connect_button.size * 0.5
		_connect_button.queue_redraw()

	search_row.resized.connect(func() -> void:
		layout_search_row.call()
	)

	var username_margin := MarginContainer.new()
	username_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	username_margin.add_theme_constant_override("margin_left", 34)
	username_margin.add_theme_constant_override("margin_right", 20)
	username_margin.add_theme_constant_override("margin_top", 0)
	username_margin.add_theme_constant_override("margin_bottom", 0)
	username_shell.add_child(username_margin)

	var username_inner := HBoxContainer.new()
	username_inner.alignment = BoxContainer.ALIGNMENT_CENTER
	username_inner.add_theme_constant_override("separation", 20)
	username_margin.add_child(username_inner)

	username_inner.add_child(_create_user_icon())

	_username_box = LineEdit.new()
	_username_box.placeholder_text = "Your name..."
	_username_box.max_length = USERNAME_MAX_CHARS
	_username_box.custom_minimum_size = Vector2(0, 120)
	_username_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_username_box.clear_button_enabled = false
	_username_box.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_username_box.flat = true
	_username_box.caret_blink = true
	_username_box.caret_blink_interval = 0.42
	_username_box.virtual_keyboard_enabled = true
	_username_box.add_theme_font_size_override("font_size", 66)
	_username_box.add_theme_color_override("font_color", COLOR_TEXT)
	_username_box.add_theme_color_override("font_placeholder_color", COLOR_PLACEHOLDER)
	_username_box.add_theme_color_override("caret_color", COLOR_TEXT)
	_username_box.add_theme_color_override("font_selected_color", Color.BLACK)
	_username_box.add_theme_color_override("selection_color", COLOR_TEXT)
	_username_box.add_theme_stylebox_override("normal", _transparent_line_edit_style())
	_username_box.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_username_box.add_theme_stylebox_override("read_only", _transparent_line_edit_style())
	_apply_app_font(_username_box)
	_username_box.text_changed.connect(func(_text: String) -> void:
		_enforce_username_character_limit()
		_update_username_clear_button()
		_save_public_display_name_locally()
	)
	_username_box.text_submitted.connect(func(_text: String) -> void:
		_save_public_display_name(true)
		_release_username_focus()
	)
	username_inner.add_child(_username_box)

	_username_clear_button = _create_username_clear_button()
	username_inner.add_child(_username_clear_button)
	_update_username_clear_button()

	_connect_button.mouse_entered.connect(func() -> void:
		_button_hovered = true
		_connect_button.queue_redraw()
	)
	_connect_button.mouse_exited.connect(func() -> void:
		_button_hovered = false
		_connect_button.queue_redraw()
	)
	_connect_button.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventScreenTouch and event.pressed:
			_start_button_press()
			get_viewport().set_input_as_handled()
		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_start_button_press()
			get_viewport().set_input_as_handled()
	)

	layout_search_row.call()

	_build_nearby_players_area(content)
	_setup_nearby_refresh_timer()
	_update_nearby_players_ui()
	_update_nearby_dynamic_theme_colors(true)


func _build_nearby_players_area(content: VBoxContainer) -> void:
	var stack := Control.new()
	stack.name = "NearbyPlayersStack"
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.mouse_filter = Control.MOUSE_FILTER_PASS
	content.add_child(stack)

	_nearby_scroll = ScrollContainer.new()
	_nearby_scroll.name = "NearbyPlayersScroll"
	_nearby_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	_nearby_scroll.follow_focus = true
	_nearby_scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	_nearby_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_nearby_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
	_nearby_scroll.add_theme_constant_override("scrollbar_margin_left", 30)
	stack.add_child(_nearby_scroll)

	_nearby_scroll_margin = MarginContainer.new()
	_nearby_scroll_margin.name = "NearbyPlayersScrollMargin"
	_nearby_scroll_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_nearby_scroll_margin.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_nearby_scroll_margin.mouse_filter = Control.MOUSE_FILTER_PASS
	_nearby_scroll_margin.add_theme_constant_override("margin_right", 44)
	_nearby_scroll.add_child(_nearby_scroll_margin)

	_nearby_content = VBoxContainer.new()
	_nearby_content.name = "NearbyPlayersContent"
	_nearby_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_nearby_content.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_nearby_content.mouse_filter = Control.MOUSE_FILTER_PASS
	_nearby_content.add_theme_constant_override("separation", 0)
	_nearby_scroll_margin.add_child(_nearby_content)

	_nearby_list = VBoxContainer.new()
	_nearby_list.name = "NearbyPlayersList"
	_nearby_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_nearby_list.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_nearby_list.mouse_filter = Control.MOUSE_FILTER_PASS
	_nearby_list.add_theme_constant_override("separation", 20)
	_nearby_list.visible = false
	_nearby_content.add_child(_nearby_list)

	_nearby_empty_label = Label.new()
	_nearby_empty_label.name = "NearbyPlayersEmptyLabel"
	_nearby_empty_label.text = "ENABLE LOCATION"
	_nearby_empty_label.visible = true
	_nearby_empty_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_nearby_empty_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_nearby_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_nearby_empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_nearby_empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_nearby_empty_label.add_theme_font_size_override("font_size", 64)
	_nearby_empty_label.add_theme_color_override("font_color", COLOR_SUBTITLE)
	_apply_app_font(_nearby_empty_label)
	stack.add_child(_nearby_empty_label)

	_scroll = _nearby_scroll
	_reset_scroll_motion()

	stack.resized.connect(func() -> void:
		_update_nearby_empty_label_height()
	)

	call_deferred("_style_nearby_scroll_bar")
	call_deferred("_connect_nearby_scroll_runtime_visibility_signal")
	call_deferred("_update_nearby_empty_label_height")


func _setup_nearby_refresh_timer() -> void:
	# Kept under the old method name so the existing popup build flow stays intact.
	# Discovery itself is native BLE and event-driven; there is no HTTP refresh timer.
	if OS.get_name() != "Android":
		return
	if not Engine.has_singleton("UnilearnBLE"):
		push_warning("UnilearnBLE Android plugin is not installed or enabled.")
		return

	_ble_plugin = Engine.get_singleton("UnilearnBLE")
	if _ble_plugin == null:
		return

	if _ble_plugin.has_signal("nearby_players_changed") and not _ble_plugin.is_connected("nearby_players_changed", Callable(self, "_on_ble_nearby_players_changed")):
		_ble_plugin.connect("nearby_players_changed", Callable(self, "_on_ble_nearby_players_changed"))
	if _ble_plugin.has_signal("discovery_error") and not _ble_plugin.is_connected("discovery_error", Callable(self, "_on_ble_discovery_error")):
		_ble_plugin.connect("discovery_error", Callable(self, "_on_ble_discovery_error"))
	if _ble_plugin.has_signal("discovery_state_changed") and not _ble_plugin.is_connected("discovery_state_changed", Callable(self, "_on_ble_discovery_state_changed")):
		_ble_plugin.connect("discovery_state_changed", Callable(self, "_on_ble_discovery_state_changed"))
	if _ble_plugin.has_signal("debug_log") and not _ble_plugin.is_connected("debug_log", Callable(self, "_on_ble_debug_log")):
		_ble_plugin.connect("debug_log", Callable(self, "_on_ble_debug_log"))

	if not is_instance_valid(_ble_sync_heartbeat_timer):
		_ble_sync_heartbeat_timer = Timer.new()
		_ble_sync_heartbeat_timer.name = "NearbySyncHeartbeatTimer"
		_ble_sync_heartbeat_timer.wait_time = NEARBY_SYNC_HEARTBEAT_INTERVAL_SEC
		_ble_sync_heartbeat_timer.one_shot = false
		_ble_sync_heartbeat_timer.process_mode = Node.PROCESS_MODE_ALWAYS
		_ble_sync_heartbeat_timer.timeout.connect(_on_nearby_sync_heartbeat)
		add_child(_ble_sync_heartbeat_timer)


func _start_nearby_refresh() -> void:
	if _ble_discovery_running or _ble_plugin == null or not _button_toggled:
		return

	var auth := get_node_or_null("/root/FirebaseAuth")
	var uid := ""
	if auth != null and "uid" in auth:
		uid = str(auth.uid).strip_edges()
	if uid.is_empty():
		push_warning("BLE discovery needs a signed-in Firebase UID.")
		return

	var display_name := ""
	if is_instance_valid(_username_box):
		display_name = _username_box.text.strip_edges()
	elif _settings_node != null and _settings_node.has_method("get_display_name"):
		display_name = str(_settings_node.call("get_display_name")).strip_edges()

	# Card generation is unavailable while this nearby session is active, so this
	# capability only needs to be calculated once when discovery starts.
	_local_trade_available_for_nearby_session = 1 if _has_any_trade_eligible_planet_card() else 0

	# A peer may return with the exact same JSON payload that was last seen before
	# discovery stopped. Clear the dedupe cache so that first snapshot is never ignored.
	_ble_last_players_json = ""
	_ble_plugin.call("startDiscovery", uid, display_name)
	_ble_discovery_running = true
	if is_instance_valid(_ble_sync_heartbeat_timer):
		_ble_sync_heartbeat_timer.start()
	# Reconcile immediately. This is especially important after location is
	# re-enabled because remembered peers can be restored without waiting for
	# Android to emit another BLE scan callback or for the first timer interval.
	call_deferred("_on_nearby_sync_heartbeat")
	if _ble_plugin.has_method("getDebugSnapshot"):
		call_deferred("_print_ble_debug_snapshot")


func _stop_nearby_refresh() -> void:
	# Notify the backend before clearing local state. The opposite phone will see
	# this explicit leave on its next 350 ms heartbeat instead of waiting for the
	# BLE disappearance grace window.
	_report_all_nearby_sync_leaves()

	if _ble_plugin != null and _ble_discovery_running:
		_ble_plugin.call("stopDiscovery")
	_ble_discovery_running = false
	_ble_last_players_json = ""
	_ble_latest_players_by_uid.clear()
	_ble_stable_players_by_uid.clear()
	_ble_pending_players_by_uid.clear()
	_ble_sync_request_in_flight.clear()
	_ble_sync_reveal_generation.clear()
	_ble_sync_reveal_at_by_uid.clear()
	_ble_peer_explicit_leave_at_by_uid.clear()
	_ble_player_removal_generation.clear()
	if is_instance_valid(_ble_sync_heartbeat_timer):
		_ble_sync_heartbeat_timer.stop()


func _report_all_nearby_sync_leaves() -> void:
	if not _is_online_mode_available():
		return
	var peer_uids: Array[String] = []
	var seen: Dictionary = {}
	for source: Dictionary in [
		_ble_latest_players_by_uid,
		_ble_known_players_by_uid,
		_ble_stable_players_by_uid,
		_ble_pending_players_by_uid,
	]:
		for uid_variant: Variant in source.keys():
			var uid := str(uid_variant).strip_edges()
			if uid.is_empty() or seen.has(uid):
				continue
			seen[uid] = true
			peer_uids.append(uid)

	if peer_uids.is_empty():
		return

	var database := get_node_or_null("/root/FirebaseDatabase")
	if database == null:
		return
	if database.has_method("leave_all_nearby_multiplayer_detections"):
		database.call("leave_all_nearby_multiplayer_detections", peer_uids)
		return

	for uid: String in peer_uids:
		if database.has_method("leave_nearby_multiplayer_detection"):
			database.call("leave_nearby_multiplayer_detection", uid)


func _on_ble_nearby_players_changed(players_json: String) -> void:
	if _closing or not _button_toggled or players_json == _ble_last_players_json:
		return
	_ble_last_players_json = players_json

	var parsed: Variant = JSON.parse_string(players_json)
	if not (parsed is Array):
		return

	var now_seen: Dictionary = {}

	for raw_player: Variant in parsed:
		if not (raw_player is Dictionary):
			continue

		var player: Dictionary = raw_player.duplicate(true)
		var uid := str(player.get("uid", "")).strip_edges()
		var display_name := _limit_multiplayer_display_name(
			str(player.get("displayName", "")).strip_edges()
		)
		if uid.is_empty() or display_name.is_empty():
			continue

		player["displayName"] = display_name
		now_seen[uid] = true
		_ble_latest_players_by_uid[uid] = player
		_ble_known_players_by_uid[uid] = player.duplicate(true)

		if _ble_stable_players_by_uid.has(uid):
			_ble_stable_players_by_uid[uid] = player
		else:
			_ble_pending_players_by_uid[uid] = player

		_ble_player_removal_generation[uid] = int(
			_ble_player_removal_generation.get(uid, 0)
		) + 1

		_request_nearby_sync_report(uid)

	var tracked_uids: Dictionary = {}
	for uid_variant: Variant in _ble_stable_players_by_uid.keys():
		tracked_uids[str(uid_variant)] = true
	for uid_variant: Variant in _ble_pending_players_by_uid.keys():
		tracked_uids[str(uid_variant)] = true

	for tracked_uid_variant: Variant in tracked_uids.keys():
		var tracked_uid := str(tracked_uid_variant)
		if now_seen.has(tracked_uid):
			continue
		var removal_generation := int(
			_ble_player_removal_generation.get(tracked_uid, 0)
		) + 1
		_ble_player_removal_generation[tracked_uid] = removal_generation
		call_deferred(
			"_remove_ble_player_after_grace",
			tracked_uid,
			removal_generation
		)

	_render_stable_ble_players()


func _on_nearby_sync_heartbeat() -> void:
	if _closing or not _button_toggled or not _ble_discovery_running or not _is_online_mode_available():
		return

	# Keep the server-side pair alive for every peer seen during this discovery
	# session, not only peers present in the latest native BLE snapshot. This is
	# what lets the waiting phone notice an immediate rejoin even when Android
	# delays the next nearby_players_changed signal.
	var heartbeat_uids: Dictionary = {}
	for uid_variant: Variant in _ble_known_players_by_uid.keys():
		heartbeat_uids[str(uid_variant)] = true
	for uid_variant: Variant in _ble_latest_players_by_uid.keys():
		heartbeat_uids[str(uid_variant)] = true

	for uid_variant: Variant in heartbeat_uids.keys():
		_request_nearby_sync_report(str(uid_variant))


func _request_nearby_sync_report(uid: String) -> void:
	if not _is_online_mode_available():
		return
	uid = uid.strip_edges()
	if uid.is_empty() or _ble_sync_request_in_flight.has(uid):
		return
	if not _ble_latest_players_by_uid.has(uid) and not _ble_known_players_by_uid.has(uid):
		return

	var database := get_node_or_null("/root/FirebaseDatabase")
	if database == null or not database.has_method("report_nearby_multiplayer_detection"):
		push_warning("FirebaseDatabase nearby sync method is unavailable.")
		return

	_ble_sync_request_in_flight[uid] = true
	var request_started_msec := Time.get_ticks_msec()
	var result: Dictionary = await database.call(
		"report_nearby_multiplayer_detection",
		uid,
		true,
		_local_trade_available_for_nearby_session
	)
	var request_finished_msec := Time.get_ticks_msec()
	_ble_sync_request_in_flight.erase(uid)

	if _closing or not _button_toggled:
		return
	if not bool(result.get("success", false)):
		return

	var peer_trade_available := int(result.get("peerTradeAvailable", 0)) == 1
	_apply_peer_trade_availability(uid, peer_trade_available)

	var peer_left_at := int(result.get("peerExplicitlyLeftAt", 0))
	if peer_left_at > 0:
		var known_leave_at := int(_ble_peer_explicit_leave_at_by_uid.get(uid, 0))
		if peer_left_at > known_leave_at:
			_ble_peer_explicit_leave_at_by_uid[uid] = peer_left_at
			_remove_ble_player_from_explicit_peer_leave(uid)
		return

	if not bool(result.get("ready", false)):
		return

	_ble_peer_explicit_leave_at_by_uid.erase(uid)
	if not _ble_latest_players_by_uid.has(uid) and not _ble_known_players_by_uid.has(uid):
		return

	var reveal_at := int(result.get("revealAt", 0))
	var server_now := int(result.get("serverNow", 0))
	if reveal_at <= 0 or server_now <= 0:
		return
	if _ble_stable_players_by_uid.has(uid):
		return
	if int(_ble_sync_reveal_at_by_uid.get(uid, 0)) == reveal_at:
		return
	_ble_sync_reveal_at_by_uid[uid] = reveal_at

	var round_trip_msec := maxi(0, request_finished_msec - request_started_msec)
	var estimated_server_now_on_receive := server_now + int(round(float(round_trip_msec) * 0.5))
	var delay_msec := maxi(
		NEARBY_SYNC_MIN_REVEAL_DELAY_MSEC,
		reveal_at - estimated_server_now_on_receive
	)

	var generation := int(_ble_sync_reveal_generation.get(uid, 0)) + 1
	_ble_sync_reveal_generation[uid] = generation
	_reveal_synced_ble_player_after_delay(uid, generation, delay_msec)


func _apply_peer_trade_availability(uid: String, trade_available: bool) -> void:
	for players_by_uid: Dictionary in [
		_ble_latest_players_by_uid,
		_ble_known_players_by_uid,
		_ble_stable_players_by_uid,
		_ble_pending_players_by_uid,
	]:
		var player_variant: Variant = players_by_uid.get(uid, null)
		if player_variant is Dictionary:
			var player := (player_variant as Dictionary).duplicate(true)
			player["tradeAvailable"] = trade_available
			players_by_uid[uid] = player

	var card = _nearby_cards_by_uid.get(uid, null)
	if card != null and is_instance_valid(card):
		var player_variant: Variant = card.get_meta("player", {})
		if player_variant is Dictionary:
			var player := (player_variant as Dictionary).duplicate(true)
			player["tradeAvailable"] = trade_available
			card.set_meta("player", player)
		var action_background = card.get_node_or_null("SwipeActionBackground")
		if is_instance_valid(action_background):
			action_background.queue_redraw()


func _reveal_synced_ble_player_after_delay(uid: String, generation: int, delay_msec: int) -> void:
	await get_tree().create_timer(
		float(delay_msec) / 1000.0,
		true,
		false,
		true
	).timeout

	if _closing or not _button_toggled:
		return
	if int(_ble_sync_reveal_generation.get(uid, -1)) != generation:
		return
	if not _ble_latest_players_by_uid.has(uid) and not _ble_known_players_by_uid.has(uid):
		return

	var player_variant: Variant = _ble_pending_players_by_uid.get(
		uid,
		_ble_latest_players_by_uid.get(
			uid,
			_ble_known_players_by_uid.get(uid, {})
		)
	)
	if not (player_variant is Dictionary):
		return

	_ble_pending_players_by_uid.erase(uid)
	_ble_sync_reveal_at_by_uid.erase(uid)
	_ble_stable_players_by_uid[uid] = (player_variant as Dictionary).duplicate(true)
	_nearby_animate_next_build = true
	_render_stable_ble_players()


func _remove_ble_player_from_explicit_peer_leave(uid: String) -> void:
	# Keep the last valid peer payload in _ble_known_players_by_uid. The UI is
	# removed immediately, but the heartbeat keeps checking this pair so the peer
	# can be restored in sync as soon as their device reports active again.
	_ble_last_players_json = ""
	_ble_latest_players_by_uid.erase(uid)
	_ble_stable_players_by_uid.erase(uid)
	_ble_pending_players_by_uid.erase(uid)
	_ble_sync_reveal_at_by_uid.erase(uid)
	_ble_sync_request_in_flight.erase(uid)
	_ble_sync_reveal_generation[uid] = int(_ble_sync_reveal_generation.get(uid, 0)) + 1
	_ble_player_removal_generation[uid] = int(_ble_player_removal_generation.get(uid, 0)) + 1
	_render_stable_ble_players()


func _remove_ble_player_after_grace(uid: String, generation: int) -> void:
	await get_tree().create_timer(
		float(NEARBY_PLAYER_UI_LOST_GRACE_MSEC) / 1000.0,
		true,
		false,
		true
	).timeout

	if _closing or not _button_toggled:
		return
	if int(_ble_player_removal_generation.get(uid, -1)) != generation:
		return
	if _ble_latest_players_by_uid.has(uid):
		return

	_ble_latest_players_by_uid.erase(uid)
	_ble_stable_players_by_uid.erase(uid)
	_ble_pending_players_by_uid.erase(uid)
	_ble_sync_reveal_at_by_uid.erase(uid)
	_ble_sync_reveal_generation[uid] = int(_ble_sync_reveal_generation.get(uid, 0)) + 1
	_ble_player_removal_generation.erase(uid)
	_ble_peer_explicit_leave_at_by_uid.erase(uid)
	_render_stable_ble_players()
	_report_nearby_sync_leave(uid)


func _report_nearby_sync_leave(uid: String) -> void:
	var database := get_node_or_null("/root/FirebaseDatabase")
	if database != null and database.has_method("leave_nearby_multiplayer_detection"):
		database.call_deferred("leave_nearby_multiplayer_detection", uid)


func _render_stable_ble_players() -> void:
	var visible_players: Array[Dictionary] = []
	for uid_variant: Variant in _ble_stable_players_by_uid.keys():
		var player_variant: Variant = _ble_stable_players_by_uid.get(uid_variant, {})
		if not (player_variant is Dictionary):
			continue
		var player: Dictionary = (player_variant as Dictionary).duplicate(true)
		var display_name := _limit_multiplayer_display_name(
			str(player.get("displayName", "")).strip_edges()
		)
		if display_name.is_empty():
			continue
		player["displayName"] = display_name
		visible_players.append(player)

	_set_nearby_players(visible_players)


func _on_ble_discovery_error(code: String) -> void:
	push_warning("[UnilearnBLE/Godot] Discovery error: %s" % code)
	_print_ble_debug_snapshot()
	if code == "PERMISSION_DENIED" or code == "BLUETOOTH_DISABLED" or code == "ADVERTISE_UNSUPPORTED":
		_set_location_enabled(false)


func _on_ble_discovery_state_changed(active: bool) -> void:
	_ble_discovery_running = active
	_print_ble_debug_snapshot()


func _on_ble_debug_log(message: String) -> void:
	pass


func _print_ble_debug_snapshot() -> void:
	pass


func _update_nearby_empty_label_height() -> void:
	if not is_instance_valid(_nearby_empty_label):
		return

	_nearby_empty_label.custom_minimum_size = Vector2.ZERO


func _style_nearby_scroll_bar() -> void:
	if not is_instance_valid(_nearby_scroll):
		return

	var vertical_bar := _nearby_scroll.get_v_scroll_bar()
	if vertical_bar == null:
		return

	vertical_bar.visible = true
	vertical_bar.modulate.a = 1.0
	vertical_bar.custom_minimum_size = Vector2(18, 0)
	vertical_bar.add_theme_stylebox_override("scroll", _scroll_bar_track_style())
	vertical_bar.add_theme_stylebox_override("scroll_focus", _scroll_bar_track_style())
	vertical_bar.add_theme_stylebox_override("grabber", _scroll_bar_grabber_style(COLOR_SCROLL_GRAB))
	vertical_bar.add_theme_stylebox_override("grabber_highlight", _scroll_bar_grabber_style(COLOR_SCROLL_GRAB_HOVER))
	vertical_bar.add_theme_stylebox_override("grabber_pressed", _scroll_bar_grabber_style(COLOR_SCROLL_GRAB_HOVER))


func _set_nearby_players(players: Array) -> void:
	_nearby_players.clear()

	for raw_player in players:
		if not (raw_player is Dictionary):
			continue

		var player: Dictionary = raw_player
		var display_name := _limit_multiplayer_display_name(
			str(player.get("displayName", player.get("username", player.get("name", "")))).strip_edges()
		)
		var uid := str(player.get("uid", player.get("id", ""))).strip_edges()

		if display_name.is_empty():
			display_name = "PLAYER"

		_nearby_players.append({
			"uid": uid,
			"displayName": display_name,
			"distanceMeters": player.get("distanceMeters", player.get("distance", -1)),
		})

	if _multiplayer_request_pending and not _multiplayer_request_pinned_player.is_empty():
		var pinned_uid := str(_multiplayer_request_pinned_player.get("uid", "")).strip_edges()
		var already_present := false
		for existing_player in _nearby_players:
			if str(existing_player.get("uid", "")).strip_edges() == pinned_uid:
				already_present = true
				break
		if not already_present:
			_nearby_players.append(_multiplayer_request_pinned_player.duplicate(true))

	_nearby_players.sort_custom(_sort_nearby_players_by_distance)
	_update_nearby_players_ui()


func _sort_nearby_players_by_distance(a: Dictionary, b: Dictionary) -> bool:
	return _nearby_player_distance_for_sort(a) < _nearby_player_distance_for_sort(b)


func _nearby_player_distance_for_sort(player: Dictionary) -> float:
	var distance_value: Variant = player.get("distanceMeters", player.get("distance", 9999999.0))
	var distance_type := typeof(distance_value)
	if distance_type == TYPE_INT or distance_type == TYPE_FLOAT:
		return float(distance_value)
	if str(distance_value).is_valid_float():
		return float(str(distance_value))
	return 9999999.0


func _show_nearby_loading_state(animate_next_build: bool = true) -> void:
	_nearby_build_generation += 1
	_nearby_animate_next_build = animate_next_build
	_hide_all_nearby_player_cards()
	if is_instance_valid(_nearby_scroll):
		_nearby_scroll.visible = false
	if is_instance_valid(_nearby_list):
		_nearby_list.visible = false
	if is_instance_valid(_nearby_empty_label):
		_nearby_empty_label.visible = true
		_nearby_empty_label.text = "NO INTERNET" if not _is_online_mode_available() else ("ENABLE LOCATION" if not _is_bluetooth_enabled() else "SEARCHING NEARBY...")
		_update_nearby_empty_label_height()


func _update_nearby_players_ui() -> void:
	if not is_instance_valid(_nearby_list) or not is_instance_valid(_nearby_empty_label):
		return

	_nearby_build_generation += 1
	var local_generation := _nearby_build_generation
	var animate_build := _nearby_animate_next_build
	_nearby_animate_next_build = false

	if not _is_online_mode_available():
		_button_toggled = false
		if is_instance_valid(_nearby_scroll):
			_nearby_scroll.visible = false
		_nearby_list.visible = false
		_nearby_empty_label.visible = true
		_nearby_empty_label.text = "NO INTERNET"
		_hide_all_nearby_player_cards()
		_update_nearby_empty_label_height()
		return

	if _sync_mode_active:
		var sync_player := _sync_player.duplicate(true)
		if sync_player.is_empty():
			sync_player = {"displayName": "PLAYER", "uid": "", "syncActive": true}
		sync_player["syncActive"] = true
		if is_instance_valid(_nearby_scroll):
			_nearby_scroll.visible = true
		_nearby_empty_label.visible = false
		_nearby_list.visible = true
		_build_nearby_players_progressively([sync_player], local_generation, animate_build)
		call_deferred("_style_nearby_scroll_bar")
		call_deferred("_connect_nearby_scroll_runtime_visibility_signal")
		return

	if _trade_mode_active:
		var trade_player := _trade_player.duplicate(true)
		if trade_player.is_empty():
			trade_player = {"displayName": "PLAYER", "uid": "", "tradeActive": true}
		trade_player["tradeActive"] = true
		if is_instance_valid(_nearby_scroll):
			_nearby_scroll.visible = true
		_nearby_empty_label.visible = false
		_nearby_list.visible = true
		_build_nearby_players_progressively([trade_player], local_generation, animate_build)
		call_deferred("_style_nearby_scroll_bar")
		call_deferred("_connect_nearby_scroll_runtime_visibility_signal")
		return

	if not _button_toggled:
		if is_instance_valid(_nearby_scroll):
			_nearby_scroll.visible = false
		_nearby_list.visible = false
		_nearby_empty_label.visible = true
		_nearby_empty_label.text = "ENABLE LOCATION"
		_hide_all_nearby_player_cards()
		_update_nearby_empty_label_height()
		return

	if _nearby_players.is_empty():
		if is_instance_valid(_nearby_scroll):
			_nearby_scroll.visible = false
		_nearby_list.visible = false
		_nearby_empty_label.visible = true
		_nearby_empty_label.text = "SEARCHING NEARBY..."
		_hide_all_nearby_player_cards()
		_update_nearby_empty_label_height()
		return

	if is_instance_valid(_nearby_scroll):
		_nearby_scroll.visible = true
	_nearby_empty_label.visible = false
	_nearby_list.visible = true

	_build_nearby_players_progressively(_normal_nearby_players_for_list(_nearby_players), local_generation, animate_build)
	call_deferred("_style_nearby_scroll_bar")
	call_deferred("_connect_nearby_scroll_runtime_visibility_signal")


func _hide_all_nearby_player_cards() -> void:
	for card_key in _nearby_cards_by_uid.keys():
		var card = _nearby_cards_by_uid.get(card_key, null)
		if card != null and is_instance_valid(card):
			card.visible = false


func _nearby_player_card_key(player: Dictionary, index: int) -> String:
	var uid := str(player.get("uid", "")).strip_edges()
	if uid.is_empty():
		uid = str(player.get("id", "")).strip_edges()
	if uid.is_empty():
		uid = "%s_%d" % [str(player.get("displayName", "player")).strip_edges().to_lower(), index]
	return uid


func _normal_nearby_players_for_list(players: Array) -> Array:
	var cleaned: Array = []
	for raw_player in players:
		if raw_player is Dictionary:
			var player := (raw_player as Dictionary).duplicate(true)
			# syncActive is only a temporary UI flag for the one locked sync row.
			# Never let it leak back into the reusable nearby-player cards.
			player.erase("syncActive")
			if not player.has("distanceMeters") and player.has("distance"):
				player["distanceMeters"] = player.get("distance", -1)
			cleaned.append(player)
	return cleaned


func _build_nearby_players_progressively(players: Array, local_generation: int, animate_build: bool = false) -> void:
	if local_generation != _nearby_build_generation or _closing or not is_instance_valid(_nearby_list):
		return

	if not animate_build:
		_reconcile_nearby_players_without_intro(players, local_generation)
		return

	for card_key in _nearby_cards_by_uid.keys():
		var old_card = _nearby_cards_by_uid.get(card_key, null)
		if old_card != null and is_instance_valid(old_card):
			old_card.visible = false

	var built_count := 0
	var index := 0
	while index < players.size():
		if local_generation != _nearby_build_generation or _closing or not is_instance_valid(_nearby_list):
			return

		var batch_count := 0
		var frame_start := Time.get_ticks_msec()
		while index < players.size() and batch_count < NEARBY_PLAYER_CARD_BATCH_SIZE:
			if Time.get_ticks_msec() - frame_start >= NEARBY_BUILD_FRAME_BUDGET_MSEC:
				break

			var player: Dictionary = players[index]
			var card_key := _nearby_player_card_key(player, index)
			var card = _nearby_cards_by_uid.get(card_key, null)
			if card == null or not is_instance_valid(card):
				card = _create_nearby_player_row(player)
				_nearby_cards_by_uid[card_key] = card
				_nearby_list.add_child(card)
			else:
				_refresh_nearby_player_row(card, player)
				if card.get_parent() != _nearby_list:
					_nearby_list.add_child(card)

			card.visible = true
			card.process_mode = Node.PROCESS_MODE_INHERIT
			_nearby_list.move_child(card, index)
			if built_count < NEARBY_CARD_ANIMATION_LIMIT:
				card.modulate.a = 0.0
				card.scale = NEARBY_CARD_ENTER_SCALE
				_animate_nearby_card_in(card, built_count)
			else:
				card.modulate.a = 1.0
				card.scale = Vector2.ONE
			index += 1
			built_count += 1
			batch_count += 1

		_request_nearby_runtime_visibility_update()
		await get_tree().process_frame

	_update_nearby_dynamic_theme_colors(true)
	call_deferred("_style_nearby_scroll_bar")
	_request_nearby_runtime_visibility_update()


func _reconcile_nearby_players_without_intro(players: Array, local_generation: int) -> void:
	if local_generation != _nearby_build_generation or _closing or not is_instance_valid(_nearby_list):
		return

	var expected_keys := {}
	var index := 0
	for raw_player in players:
		if local_generation != _nearby_build_generation or _closing or not is_instance_valid(_nearby_list):
			return
		if not (raw_player is Dictionary):
			continue

		var player: Dictionary = raw_player
		var card_key := _nearby_player_card_key(player, index)
		expected_keys[card_key] = true
		var card = _nearby_cards_by_uid.get(card_key, null)
		if card == null or not is_instance_valid(card):
			card = _create_nearby_player_row(player)
			_nearby_cards_by_uid[card_key] = card
			_nearby_list.add_child(card)
		else:
			_refresh_nearby_player_row(card, player)
			if card.get_parent() != _nearby_list:
				_nearby_list.add_child(card)

		card.visible = true
		card.modulate.a = 1.0
		card.scale = Vector2.ONE
		card.process_mode = Node.PROCESS_MODE_INHERIT
		_nearby_list.move_child(card, index)
		index += 1

	for card_key in _nearby_cards_by_uid.keys():
		if expected_keys.has(card_key):
			continue
		var old_card = _nearby_cards_by_uid.get(card_key, null)
		if old_card != null and is_instance_valid(old_card):
			old_card.visible = false

	_update_nearby_dynamic_theme_colors(true)
	call_deferred("_style_nearby_scroll_bar")
	_request_nearby_runtime_visibility_update()


func _refresh_nearby_player_row(card: Variant, player: Dictionary) -> void:
	if not is_instance_valid(card):
		return
	card.set_meta("player", player.duplicate(true))
	card.set_meta("swipe_offset", 0.0)
	card.set_meta("swipe_dragging", false)
	card.set_meta("swipe_started", false)
	var card_content = card.get_node_or_null("NearbyPlayerCardContent") if card is Node else null
	if is_instance_valid(card_content):
		card_content.offset_left = 0.0
		card_content.offset_right = 0.0
	var action_background = card.get_node_or_null("SwipeActionBackground") if card is Node else null
	if is_instance_valid(action_background):
		action_background.queue_redraw()
	# Find named controls recursively instead of depending on Godot-generated
	# intermediate node names such as MarginContainer/HBoxContainer/VBoxContainer.
	var name_label = card.find_child("NearbyPlayerNameLabel", true, false) if card is Node else null
	if name_label is Label:
		var visible_name := _limit_multiplayer_display_name(
			str(player.get("displayName", "")).strip_edges()
		).to_upper()
		name_label.text = visible_name
		name_label.add_theme_font_size_override(
			"font_size",
			_nearby_player_name_font_size(visible_name)
		)
	var status_label = card.find_child("NearbyPlayerStatusLabel", true, false) if card is Node else null
	if status_label is Label:
		status_label.text = _nearby_player_subtitle(player)
	var hint_label = card.find_child("NearbyPlayerSwipeHintLabel", true, false) if card is Node else null
	if hint_label is Label:
		if _trade_mode_active and bool(player.get("tradeActive", false)):
			hint_label.text = "CARD TRADE"
		elif _sync_mode_active and bool(player.get("syncActive", false)):
			hint_label.text = "SYNC ACTIVE"
		else:
			hint_label.text = "SWIPE LEFT • RIGHT"


func _animate_nearby_card_in(card: Control, index: int) -> void:
	if not is_instance_valid(card):
		return
	card.scale = Vector2.ONE
	if reduce_motion_enabled:
		card.modulate.a = 1.0
		return
	var delay: float = min(float(index % 3) * NEARBY_CARD_ENTER_STAGGER, 0.07)
	var tween := create_tween()
	tween.tween_property(card, "modulate:a", 1.0, NEARBY_CARD_ENTER_TIME) \
		.set_delay(delay) \
		.set_trans(Tween.TRANS_SINE) \
		.set_ease(Tween.EASE_OUT)

func _create_nearby_player_row(player: Dictionary) -> Control:
	var root := Control.new()
	root.name = "NearbyPlayerSwipeCard"
	root.custom_minimum_size = Vector2(0, 186)
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.clip_contents = true
	root.set_meta("player", player.duplicate(true))
	root.set_meta("swipe_offset", 0.0)
	root.set_meta("swipe_dragging", false)
	root.set_meta("swipe_started", false)
	root.set_meta("swipe_start_pos", Vector2.ZERO)
	root.set_meta("swipe_start_offset", 0.0)
	root.set_meta("swipe_tween", null)

	var action_background := Control.new()
	action_background.name = "SwipeActionBackground"
	action_background.set_anchors_preset(Control.PRESET_FULL_RECT)
	action_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	action_background.set_meta("dynamic_highlight_redraw", true)
	root.add_child(action_background)

	var card := PanelContainer.new()
	card.name = "NearbyPlayerCardContent"
	card.set_anchors_preset(Control.PRESET_FULL_RECT)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_theme_stylebox_override("panel", _nearby_player_row_style())	
	root.add_child(card)

	action_background.draw.connect(func() -> void:
		_draw_nearby_swipe_background(action_background, root)
	)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_right", 30)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	card.add_child(margin)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 24)
	margin.add_child(row)

	row.add_child(_create_nearby_player_avatar(player))

	var text_box := VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.size_flags_stretch_ratio = 1.75
	text_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	text_box.add_theme_constant_override("separation", 2)
	row.add_child(text_box)

	var name_label := Label.new()
	name_label.name = "NearbyPlayerNameLabel"
	var visible_name := _limit_multiplayer_display_name(
		str(player.get("displayName", "")).strip_edges()
	).to_upper()
	name_label.text = visible_name
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.clip_text = false
	name_label.add_theme_font_size_override(
		"font_size",
		_nearby_player_name_font_size(visible_name)
	)
	name_label.add_theme_color_override("font_color", COLOR_TEXT)
	_apply_app_font(name_label)
	text_box.add_child(name_label)

	var status_label := Label.new()
	status_label.name = "NearbyPlayerStatusLabel"
	status_label.text = _nearby_player_subtitle(player)
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status_label.clip_text = true
	status_label.add_theme_font_size_override("font_size", 34)
	status_label.add_theme_color_override("font_color", COLOR_SUBTITLE)
	_apply_app_font(status_label)
	text_box.add_child(status_label)

	var hint := Label.new()
	hint.name = "NearbyPlayerSwipeHintLabel"
	if _trade_mode_active and bool(player.get("tradeActive", false)):
		hint.text = "CARD TRADE"
	elif _sync_mode_active and bool(player.get("syncActive", false)):
		hint.text = "SYNC ACTIVE"
	else:
		hint.text = "SWIPE LEFT • RIGHT"
	hint.set_meta("dynamic_highlight_color", true)
	hint.size_flags_horizontal = Control.SIZE_SHRINK_END
	hint.custom_minimum_size = Vector2(250, 0)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hint.clip_text = true
	hint.add_theme_font_size_override("font_size", 30)
	hint.add_theme_color_override("font_color", _get_theme_highlight_color())
	_apply_app_font(hint)
	row.add_child(hint)

	root.gui_input.connect(func(event: InputEvent) -> void:
		var current_player: Dictionary = player
		if root.has_meta("player") and root.get_meta("player") is Dictionary:
			current_player = root.get_meta("player")
		_handle_nearby_card_swipe_input(root, card, action_background, current_player, event)
	)

	return root

func _nearby_player_card_height(root: Variant) -> float:
	if not is_instance_valid(root):
		return 0.0
	return max(0.0, root.size.y)


func _create_nearby_player_avatar(_player: Dictionary) -> Control:
	var avatar := Control.new()
	avatar.custom_minimum_size = Vector2(92, 92)
	avatar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	avatar.draw.connect(func() -> void:
		var center := avatar.size * 0.5
		var radius = min(avatar.size.x, avatar.size.y) * 0.45
		var icon_color := COLOR_TEXT
		avatar.draw_arc(center, radius, 0.0, TAU, 72, icon_color, 5.0, true)
		avatar.draw_arc(center + Vector2(0, -13), 14.0, 0.0, TAU, 48, icon_color, 5.0, true)
		avatar.draw_arc(center + Vector2(0, 29), 25.0, PI, TAU, 48, icon_color, 5.0, true)
	)
	return avatar


func _ensure_nearby_swipe_meta(root: Variant) -> void:
	if not is_instance_valid(root):
		return
	if not root.has_meta("swipe_offset"):
		root.set_meta("swipe_offset", 0.0)
	if not root.has_meta("swipe_dragging"):
		root.set_meta("swipe_dragging", false)
	if not root.has_meta("swipe_started"):
		root.set_meta("swipe_started", false)
	if not root.has_meta("swipe_start_pos"):
		root.set_meta("swipe_start_pos", Vector2.ZERO)
	if not root.has_meta("swipe_start_offset"):
		root.set_meta("swipe_start_offset", 0.0)
	if not root.has_meta("swipe_tween"):
		root.set_meta("swipe_tween", null)


func _nearby_swipe_meta(root: Variant, key: String, fallback: Variant) -> Variant:
	if not is_instance_valid(root):
		return fallback
	if root.has_meta(key):
		return root.get_meta(key)
	return fallback


func _nearby_current_swipe_offset(root: Variant, card: Variant) -> float:
	if is_instance_valid(card):
		return float(card.offset_left)
	return float(_nearby_swipe_meta(root, "swipe_offset", 0.0))


func _handle_nearby_card_swipe_input(root: Variant, card: Variant, action_background: Variant, player: Dictionary, event: InputEvent) -> void:
	if _closing or _sync_mode_active or _trade_mode_active:
		return
	if not is_instance_valid(root) or not is_instance_valid(card) or not is_instance_valid(action_background):
		return
	_ensure_nearby_swipe_meta(root)

	if event is InputEventScreenTouch:
		if event.pressed:
			_begin_nearby_card_swipe(root, event.position)
		else:
			_finish_nearby_card_swipe(root, card, action_background, player)
			get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_begin_nearby_card_swipe(root, event.position)
		else:
			_finish_nearby_card_swipe(root, card, action_background, player)
			get_viewport().set_input_as_handled()
		return

	if event is InputEventScreenDrag:
		_update_nearby_card_swipe(root, card, action_background, event.position)
		return

	if event is InputEventMouseMotion and bool(_nearby_swipe_meta(root, "swipe_dragging", false)):
		_update_nearby_card_swipe(root, card, action_background, event.position)


func _begin_nearby_card_swipe(root: Variant, position: Vector2) -> void:
	if not is_instance_valid(root):
		return
	_ensure_nearby_swipe_meta(root)

	var existing_tween: Variant = _nearby_swipe_meta(root, "swipe_tween", null)
	if existing_tween is Tween and existing_tween.is_valid():
		existing_tween.kill()

	_nearby_card_swipe_lock = false
	root.set_meta("swipe_dragging", true)
	root.set_meta("swipe_started", false)
	root.set_meta("swipe_start_pos", position)
	root.set_meta("swipe_start_offset", _nearby_current_swipe_offset(root, root.get_node_or_null("NearbyPlayerCardContent") if root is Node else null))


func _update_nearby_card_swipe(root: Variant, card: Variant, action_background: Variant, position: Vector2) -> void:
	if not is_instance_valid(root) or not is_instance_valid(card) or not is_instance_valid(action_background):
		return
	_ensure_nearby_swipe_meta(root)
	if not bool(_nearby_swipe_meta(root, "swipe_dragging", false)):
		return


	var start_pos: Vector2 = _nearby_swipe_meta(root, "swipe_start_pos", Vector2.ZERO)
	var delta := position - start_pos
	var started := bool(_nearby_swipe_meta(root, "swipe_started", false))

	if not started:
		if abs(delta.x) < SWIPE_DEADZONE and abs(delta.y) < SWIPE_DEADZONE:
			return
		if abs(delta.y) > abs(delta.x) * 1.15:
			_nearby_card_swipe_lock = false
			root.set_meta("swipe_dragging", false)
			return
		_nearby_card_swipe_lock = true
		root.set_meta("swipe_started", true)
		started = true

	if started:
		var start_offset := float(_nearby_swipe_meta(root, "swipe_start_offset", 0.0))
		var next_offset = clamp(start_offset + delta.x, -SWIPE_MAX_DISTANCE, SWIPE_MAX_DISTANCE)
		_update_nearby_swipe_position(root, card, action_background, next_offset)
		get_viewport().set_input_as_handled()


func _finish_nearby_card_swipe(root: Variant, card: Variant, action_background: Variant, player: Dictionary) -> void:
	if not is_instance_valid(root) or not is_instance_valid(card) or not is_instance_valid(action_background):
		return
	_ensure_nearby_swipe_meta(root)
	if not bool(_nearby_swipe_meta(root, "swipe_dragging", false)):
		return

	_nearby_card_swipe_lock = false
	root.set_meta("swipe_dragging", false)
	var started := bool(_nearby_swipe_meta(root, "swipe_started", false))
	root.set_meta("swipe_started", false)

	var offset := _nearby_current_swipe_offset(root, card)
	var trigger_distance: float = SWIPE_MAX_DISTANCE * SWIPE_COMMIT_RATIO

	if started and offset <= -trigger_distance:
		_commit_nearby_swipe_action(root, card, action_background, player, "trade")
	elif started and offset >= trigger_distance:
		_commit_nearby_swipe_action(root, card, action_background, player, "sync")
	else:
		if started and abs(offset) > SWIPE_DEADZONE:
			_play_sfx("toggle")
		_animate_nearby_swipe_to(root, card, action_background, 0.0, SWIPE_RELEASE_TIME)


func _commit_nearby_swipe_action(root: Variant, card: Variant, action_background: Variant, player: Dictionary, action: String) -> void:
	if not is_instance_valid(root) or not is_instance_valid(card) or not is_instance_valid(action_background):
		return

	var direction := -1.0 if action == "trade" else 1.0
	var target_offset = direction * min(SWIPE_MAX_DISTANCE, max(160.0, root.size.x * 0.34))
	await _animate_nearby_swipe_to(root, card, action_background, target_offset, SWIPE_ACTION_TIME)

	if not is_inside_tree() or _closing:
		return
	if not is_instance_valid(root) or not is_instance_valid(card) or not is_instance_valid(action_background):
		return

	if action == "trade" and (
		not _has_any_trade_eligible_planet_card()
		or not bool(player.get("tradeAvailable", false))
	):
		_play_sfx("error")
		await _animate_nearby_swipe_to(root, card, action_background, 0.0, SWIPE_RELEASE_TIME)
		return

	if _multiplayer_request_locked_for_player(player):
		_play_sfx("error")
		await _animate_nearby_swipe_to(root, card, action_background, 0.0, SWIPE_RELEASE_TIME)
		return

	if action == "trade":
		_request_card_trade(player)
	else:
		_request_universe_sync(player)

	await _animate_nearby_swipe_to(root, card, action_background, 0.0, SWIPE_RELEASE_TIME)


func _animate_nearby_swipe_to(root: Variant, card: Variant, action_background: Variant, target_offset: float, duration: float) -> void:
	if not is_instance_valid(root) or not is_instance_valid(card):
		return
	_ensure_nearby_swipe_meta(root)

	var existing_tween: Variant = _nearby_swipe_meta(root, "swipe_tween", null)
	if existing_tween is Tween and existing_tween.is_valid():
		existing_tween.kill()

	if not is_instance_valid(root) or not is_instance_valid(card):
		return

	var from_offset := _nearby_current_swipe_offset(root, card)
	root.set_meta("swipe_offset", from_offset)

	if duration <= 0.0 or is_equal_approx(from_offset, target_offset):
		_update_nearby_swipe_position(root, card, action_background, target_offset)
		return

	var tween := create_tween()
	root.set_meta("swipe_tween", tween)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)

	# Tween the Control offsets directly so rebuilt rows do not leave captured nodes behind.
	tween.parallel().tween_property(card, "offset_left", target_offset, duration).from(from_offset)
	tween.parallel().tween_property(card, "offset_right", target_offset, duration).from(from_offset)

	await tween.finished

	if not is_instance_valid(root) or not is_instance_valid(card):
		return
	root.set_meta("swipe_offset", target_offset)
	root.set_meta("swipe_tween", null)
	if is_instance_valid(action_background):
		action_background.queue_redraw()


func _update_nearby_swipe_position(root: Variant, card: Variant, action_background: Variant, offset: float) -> void:
	if not is_instance_valid(root) or not is_instance_valid(card):
		return
	_ensure_nearby_swipe_meta(root)

	root.set_meta("swipe_offset", offset)
	card.offset_left = offset
	card.offset_right = offset
	card.offset_top = 0.0
	card.offset_bottom = 0.0

	if is_instance_valid(action_background):
		action_background.offset_left = 0.0
		action_background.offset_right = 0.0
		action_background.offset_top = 0.0
		action_background.offset_bottom = 0.0
		action_background.queue_redraw()


func _draw_nearby_swipe_background(target: Control, root: Control) -> void:
	if not is_instance_valid(root):
		return
	_ensure_nearby_swipe_meta(root)
	var swipe_card: Control = null
	if root is Node:
		swipe_card = root.get_node_or_null("NearbyPlayerCardContent")
	var offset := _nearby_current_swipe_offset(root, swipe_card)
	if abs(offset) < 1.0:
		return

	var player_variant: Variant = root.get_meta("player", {})
	var player: Dictionary = player_variant if player_variant is Dictionary else {}
	var trade_blocked := offset < 0.0 and (
		_local_trade_available_for_nearby_session != 1
		or not bool(player.get("tradeAvailable", false))
	)
	var bg_color := _get_theme_highlight_color() if trade_blocked else _nearby_swipe_back_color()
	bg_color.a = 0.98

	# Fixed half-card action layer: it stays still behind the opaque card,
	# and the moving card simply uncovers it like the email swipe.
	var panel_width := target.size.x * 0.5
	var panel_rect := Rect2(Vector2.ZERO, Vector2(panel_width, target.size.y))
	if offset < 0.0:
		panel_rect.position.x = target.size.x - panel_width
	target.draw_style_box(_nearby_swipe_background_style(bg_color, offset), panel_rect)

	var icon_texture: Texture2D = _planet_cards_icon if offset < 0.0 else _galaxy_console_icon
	var icon_size = min(target.size.y * 0.666, 115.2)
	var icon_margin := 34.0
	var icon_x: float = panel_rect.position.x + icon_margin + icon_size * 0.5
	if offset < 0.0:
		icon_x = panel_rect.position.x + panel_rect.size.x - icon_margin - icon_size * 0.5
	var icon_center := Vector2(icon_x, target.size.y * 0.5)
	var icon_rect := Rect2(icon_center - Vector2(icon_size, icon_size) * 0.5, Vector2(icon_size, icon_size))

	if icon_texture != null:
		target.draw_texture_rect(icon_texture, icon_rect, false, Color.BLACK)
	elif offset < 0.0:
		_draw_fallback_cards_icon(target, icon_rect, Color.BLACK)
	else:
		_draw_fallback_galaxy_icon(target, icon_rect, Color.BLACK)

func _nearby_swipe_background_style(color: Color, offset: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color.TRANSPARENT
	style.set_border_width_all(0)

	# Only the outside corners need rounding. The inside edge is covered by the moving card.
	if offset < 0.0:
		style.corner_radius_top_right = 34
		style.corner_radius_bottom_right = 34
		style.corner_radius_top_left = 0
		style.corner_radius_bottom_left = 0
	else:
		style.corner_radius_top_left = 34
		style.corner_radius_bottom_left = 34
		style.corner_radius_top_right = 0
		style.corner_radius_bottom_right = 0

	return style


func _draw_fallback_cards_icon(target: Control, rect: Rect2, color: Color) -> void:
	var width = max(4.0, rect.size.x * 0.075)
	var first := Rect2(rect.position + Vector2(rect.size.x * 0.16, rect.size.y * 0.05), rect.size * Vector2(0.60, 0.78))
	var second := Rect2(rect.position + Vector2(rect.size.x * 0.27, rect.size.y * 0.16), rect.size * Vector2(0.60, 0.78))
	target.draw_rect(first, color, false, width)
	target.draw_rect(second, color, false, width)
	target.draw_circle(second.position + second.size * 0.5, min(second.size.x, second.size.y) * 0.18, color)


func _draw_fallback_galaxy_icon(target: Control, rect: Rect2, color: Color) -> void:
	var center := rect.position + rect.size * 0.5
	var width = max(4.0, rect.size.x * 0.075)
	target.draw_arc(center, rect.size.x * 0.34, 0.15, TAU * 0.92, 80, color, width, true)
	target.draw_arc(center, rect.size.x * 0.22, PI, TAU * 1.55, 70, color, width, true)
	target.draw_circle(center, rect.size.x * 0.075, color)


func _connect_nearby_scroll_runtime_visibility_signal() -> void:
	if _nearby_scroll_visibility_connected:
		return
	if not is_instance_valid(_nearby_scroll):
		return
	var bar := _nearby_scroll.get_v_scroll_bar()
	if bar == null:
		return
	var cb := Callable(self, "_on_nearby_scroll_changed_for_runtime")
	if not bar.value_changed.is_connected(cb):
		bar.value_changed.connect(cb)
	_nearby_scroll_visibility_connected = true


func _on_nearby_scroll_changed_for_runtime(_value: float) -> void:
	_request_nearby_runtime_visibility_update()


func _request_nearby_runtime_visibility_update() -> void:
	if _nearby_runtime_visibility_update_pending:
		return
	var now := Time.get_ticks_msec()
	if now - _nearby_last_runtime_visibility_msec < NEARBY_RUNTIME_VISIBILITY_MIN_INTERVAL_MSEC:
		_nearby_runtime_visibility_update_pending = true
		var wait_sec := float(NEARBY_RUNTIME_VISIBILITY_MIN_INTERVAL_MSEC - (now - _nearby_last_runtime_visibility_msec)) / 1000.0
		get_tree().create_timer(max(wait_sec, 0.01), false).timeout.connect(func() -> void:
			_update_nearby_runtime_visibility()
		)
		return
	_nearby_runtime_visibility_update_pending = true
	call_deferred("_update_nearby_runtime_visibility")


func _update_nearby_runtime_visibility() -> void:
	_nearby_runtime_visibility_update_pending = false
	_nearby_last_runtime_visibility_msec = Time.get_ticks_msec()
	if not is_instance_valid(_nearby_scroll) or not is_instance_valid(_nearby_list):
		return
	var scroll_rect := _nearby_scroll.get_global_rect()
	var active_rect := Rect2(
		scroll_rect.position - Vector2(0.0, NEARBY_RUNTIME_VIEWPORT_MARGIN),
		scroll_rect.size + Vector2(0.0, NEARBY_RUNTIME_VIEWPORT_MARGIN * 2.0)
	)
	for card_key in _nearby_cards_by_uid.keys():
		var card = _nearby_cards_by_uid.get(card_key, null)
		if card != null and is_instance_valid(card) and card.visible:
			_set_nearby_card_runtime_enabled(card, _rects_intersect(active_rect, card.get_global_rect()))


func _set_nearby_card_runtime_enabled(node: Node, enabled: bool) -> void:
	if node == null:
		return
	var desired_mode := Node.PROCESS_MODE_INHERIT if enabled else Node.PROCESS_MODE_DISABLED
	if node.process_mode != desired_mode:
		node.process_mode = desired_mode


func _rects_intersect(a: Rect2, b: Rect2) -> bool:
	return (
		a.position.x < b.position.x + b.size.x
		and a.position.x + a.size.x > b.position.x
		and a.position.y < b.position.y + b.size.y
		and a.position.y + a.size.y > b.position.y
	)


func _request_card_trade(player: Dictionary) -> void:
	# Default Solar System cards cannot be traded. Do not even open the
	# outgoing request UI when this player has no generated/custom card.
	if not _has_any_trade_eligible_planet_card():
		_play_sfx("error")
		return

	if not _begin_multiplayer_pending_request(player, "trade"):
		return
	var uid := str(player.get("uid", "")).strip_edges()
	var database := get_node_or_null("/root/FirebaseDatabase")
	if database != null and database.has_method("request_planet_card_trade"):
		var result: Variant = await database.call("request_planet_card_trade", uid)
		_handle_multiplayer_request_send_result(result)
		return


func _default_multiplayer_trade_card_ids() -> Dictionary:
	return {
		"sun": true,
		"mercury": true,
		"venus": true,
		"earth": true,
		"moon": true,
		"mars": true,
		"jupiter": true,
		"saturn": true,
		"uranus": true,
		"neptune": true,
	}


func _has_any_trade_eligible_planet_card() -> bool:
	var cache := get_node_or_null("/root/PlanetCardsCache")
	if cache == null or not cache.has_method("get_all_cards"):
		return false

	var default_ids := _default_multiplayer_trade_card_ids()
	var cards: Variant = cache.call("get_all_cards")
	if not (cards is Array):
		return false

	for card_variant in cards:
		if card_variant == null:
			continue

		var card_id := ""
		if card_variant is PlanetData:
			var planet_data := card_variant as PlanetData
			card_id = planet_data.instance_id.strip_edges().to_lower()
			if card_id.is_empty():
				card_id = planet_data.name.strip_edges().to_lower()
		elif card_variant is Dictionary:
			var card_dict := card_variant as Dictionary
			card_id = str(card_dict.get("instance_id", card_dict.get("instanceId", card_dict.get("id", card_dict.get("name", ""))))).strip_edges().to_lower()

		if not card_id.is_empty() and not default_ids.has(card_id):
			return true

	return false


func _request_universe_sync(player: Dictionary) -> void:
	if not _begin_multiplayer_pending_request(player, "sync"):
		return
	var uid := str(player.get("uid", "")).strip_edges()
	var database := get_node_or_null("/root/FirebaseDatabase")
	if database != null and database.has_method("request_universe_sync"):
		var result: Variant = await database.call("request_universe_sync", uid)
		_handle_multiplayer_request_send_result(result)
		return


func _nearby_swipe_back_color() -> Color:
	return _get_theme_highlight_color() if _multiplayer_request_locked() else COLOR_BORDER


func _multiplayer_request_locked() -> bool:
	if _multiplayer_request_pending:
		return true
	return _multiplayer_request_toast_is_active()


func _multiplayer_request_locked_for_player(player: Dictionary) -> bool:
	# Sending a request still globally locks new outgoing requests. Receiving one
	# only locks the player who sent it, so the user may request somebody else.
	if _multiplayer_request_locked():
		return true
	if not _incoming_request_active:
		return false
	var player_uid := str(player.get("uid", "")).strip_edges()
	var incoming_uid := _incoming_request_sender_uid.strip_edges()
	if not player_uid.is_empty() and not incoming_uid.is_empty():
		return player_uid == incoming_uid
	var player_name := str(player.get("displayName", player.get("username", player.get("name", "")))).strip_edges().to_lower()
	var incoming_name := _incoming_request_sender_name.strip_edges().to_lower()
	return not player_name.is_empty() and player_name == incoming_name


func _multiplayer_request_toast_is_active() -> bool:
	if is_instance_valid(_request_toast_panel):
		if _request_toast_panel.visible:
			return true
		if bool(_request_toast_panel.get_meta("multiplayer_request_toast_active", false)):
			return true

	var root := get_tree().root if get_tree() != null else null
	if root == null:
		return false
	var layer := root.get_node_or_null("UniversalMultiplayerRequestToastLayer")
	if layer == null:
		return false
	var panel := layer.get_node_or_null("MultiplayerRequestToast")
	if panel == null or not is_instance_valid(panel):
		return false
	return panel.visible or bool(panel.get_meta("multiplayer_request_toast_active", false))



func _queue_free_multiplayer_toast_layer_if_empty(layer_node: Node) -> void:
	if not is_instance_valid(layer_node):
		_try_queue_free_multiplayer_popup_after_universal_toasts()
		return
	var sent_panel := layer_node.get_node_or_null("MultiplayerRequestToast")
	if sent_panel != null and is_instance_valid(sent_panel):
		if sent_panel.visible or bool(sent_panel.get_meta("multiplayer_request_toast_active", false)):
			return
	var incoming_panel := layer_node.get_node_or_null("MultiplayerIncomingRequestCard")
	if incoming_panel != null and is_instance_valid(incoming_panel):
		if incoming_panel.visible or bool(incoming_panel.get_meta("multiplayer_incoming_request_active", false)):
			return
	layer_node.queue_free()
	_try_queue_free_multiplayer_popup_after_universal_toasts()


func _universal_multiplayer_toasts_are_active() -> bool:
	if _multiplayer_request_pending:
		return true
	if is_instance_valid(_request_toast_panel):
		if _request_toast_panel.visible or bool(_request_toast_panel.get_meta("multiplayer_request_toast_active", false)):
			return true
	if _incoming_request_active:
		return true
	if is_instance_valid(_incoming_request_panel):
		if _incoming_request_panel.visible or bool(_incoming_request_panel.get_meta("multiplayer_incoming_request_active", false)):
			return true
	var root := get_tree().root if get_tree() != null else null
	if root == null:
		return false
	var layer := root.get_node_or_null("UniversalMultiplayerRequestToastLayer")
	if layer == null:
		return false
	var sent_panel := layer.get_node_or_null("MultiplayerRequestToast")
	if sent_panel != null and is_instance_valid(sent_panel):
		if sent_panel.visible or bool(sent_panel.get_meta("multiplayer_request_toast_active", false)):
			return true
	var incoming_panel := layer.get_node_or_null("MultiplayerIncomingRequestCard")
	if incoming_panel != null and is_instance_valid(incoming_panel):
		if incoming_panel.visible or bool(incoming_panel.get_meta("multiplayer_incoming_request_active", false)):
			return true
	return false


func _try_queue_free_multiplayer_popup_after_universal_toasts() -> void:
	if not _kept_alive_for_universal_toasts:
		return
	if _universal_multiplayer_toasts_are_active():
		return
	if is_queued_for_deletion():
		return
	queue_free()

func _maybe_navigate_home_after_multiplayer_request_toast() -> void:
	if not _multiplayer_request_navigate_home_after_toast:
		return

	_multiplayer_request_navigate_home_after_toast = false
	_multiplayer_request_start_at_ms = 0
	var resolved_action: String = _multiplayer_request_resolved_action.strip_edges().to_lower()
	var resolved_request_id: String = _multiplayer_request_resolved_id.strip_edges()
	_multiplayer_request_resolved_action = ""
	_multiplayer_request_resolved_id = ""

	var is_sync_action := resolved_action in ["sync", "universe_sync", "sync_universe"]
	var is_trade_action := resolved_action in ["trade", "card_trade", "planet_card_trade", "trade_card"]
	var peer_name := _multiplayer_request_pending_player_name.strip_edges()
	var peer_uid := _multiplayer_request_pending_player_uid.strip_edges()
	if is_sync_action:
		peer_name = str(_sync_player.get("displayName", peer_name)).strip_edges()
		peer_uid = str(_sync_player.get("uid", peer_uid)).strip_edges()
	if peer_name.is_empty():
		peer_name = "PLAYER"

	var bottom_menu := _find_multiplayer_bottom_menu_node()
	if bottom_menu != null:
		if is_sync_action and bottom_menu.has_method("begin_multiplayer_universe_sync_from_request"):
			var peer_distance := _find_nearby_distance_for_player(peer_uid, peer_name)
			_sync_player = {
				"uid": peer_uid,
				"displayName": peer_name,
				"distanceMeters": peer_distance,
				"syncActive": true,
			}
			bottom_menu.call_deferred("begin_multiplayer_universe_sync_from_request", peer_name, peer_uid, peer_distance, resolved_request_id)
			return
		if is_trade_action and bottom_menu.has_method("begin_multiplayer_card_trade_from_request"):
			bottom_menu.call_deferred("begin_multiplayer_card_trade_from_request", peer_name, peer_uid, resolved_request_id)
			return
		if bottom_menu.has_method("simulate_ai_go_home"):
			bottom_menu.call_deferred("simulate_ai_go_home")
			return

	var controller := get_node_or_null("/root/AppController")
	if controller != null and controller.has_method("go_home"):
		controller.call_deferred("go_home")


func _find_multiplayer_bottom_menu_node() -> Node:
	var current := get_tree().current_scene
	var found := _find_node_with_method_recursive(current, "simulate_ai_go_home")
	if found != null:
		return found
	return _find_node_with_method_recursive(get_tree().root, "simulate_ai_go_home")


func _find_nearby_distance_for_player(peer_uid: String, peer_name: String) -> float:
	var clean_uid := peer_uid.strip_edges()
	var clean_name := peer_name.strip_edges().to_lower()
	for raw_player in _nearby_players:
		if not (raw_player is Dictionary):
			continue
		var player: Dictionary = raw_player
		var uid := str(player.get("uid", player.get("id", ""))).strip_edges()
		var display_name := str(player.get("displayName", player.get("username", player.get("name", "")))).strip_edges().to_lower()
		if (not clean_uid.is_empty() and uid == clean_uid) or (not clean_name.is_empty() and display_name == clean_name):
			return _nearby_player_distance_for_sort(player)
	return -1.0


func _find_node_with_method_recursive(node: Node, method_name: String) -> Node:
	if node == null:
		return null
	if node != self and node.has_method(method_name):
		return node
	for child in node.get_children():
		var found := _find_node_with_method_recursive(child, method_name)
		if found != null:
			return found
	return null

func _begin_multiplayer_pending_request(player: Dictionary, action: String) -> bool:
	if action == "trade" and (
		not _has_any_trade_eligible_planet_card()
		or not bool(player.get("tradeAvailable", false))
	):
		_play_sfx("error")
		return false

	if _multiplayer_request_locked_for_player(player):
		_play_sfx("error")
		return false

	var uid := str(player.get("uid", "")).strip_edges()
	var display_name := str(player.get("displayName", player.get("username", player.get("name", "PLAYER")))).strip_edges()
	if display_name.is_empty():
		display_name = "PLAYER"

	_multiplayer_request_pending = true
	_multiplayer_request_pending_action = action
	_multiplayer_request_pending_player_uid = uid
	_multiplayer_request_pending_player_name = display_name
	_multiplayer_request_pinned_player = player.duplicate(true)
	_multiplayer_request_pinned_player["uid"] = uid
	_multiplayer_request_pinned_player["displayName"] = display_name
	_multiplayer_request_pinned_player["distanceMeters"] = _nearby_player_distance_for_sort(player)
	_multiplayer_request_pending_id = ""
	_play_sfx("success")
	_show_multiplayer_request_toast(
		"REQUEST SENT!",
		("CARD TRADE" if action == "trade" else "UNIVERSE SYNC"),
		"WAITING %s" % display_name.to_upper(),
		true
	)
	_start_multiplayer_pending_request_expire_timer()
	_redraw_nearby_swipe_backgrounds()
	return true


func _handle_multiplayer_request_send_result(result: Variant) -> void:
	if not _multiplayer_request_pending:
		return

	if result == null:
		return

	if result is Dictionary:
		var request_id := str(result.get("requestId", result.get("request_id", result.get("id", "")))).strip_edges()
		if not request_id.is_empty():
			_multiplayer_request_pending_id = request_id

		var success := bool(result.get("success", true))
		if not success:
			_cancel_multiplayer_pending_request_after_send_failure()
			return

		var status := str(result.get("status", result.get("state", ""))).strip_edges().to_lower()
		if status in ["failed", "fail", "error", "send_failed", "request_failed"]:
			_cancel_multiplayer_pending_request_after_send_failure()
		elif status in ["accepted", "accept", "approved", "success_done", "done"]:
			_resolve_multiplayer_pending_request(true)
		elif status in ["denied", "declined", "rejected", "cancelled", "canceled", "expired"]:
			_resolve_multiplayer_pending_request(false)


func _cancel_multiplayer_pending_request_after_send_failure() -> void:
	if not _multiplayer_request_pending:
		return

	_multiplayer_request_pending = false
	_multiplayer_request_pending_id = ""
	_multiplayer_request_pending_action = ""
	_multiplayer_request_pending_player_uid = ""
	_multiplayer_request_pending_player_name = ""
	_multiplayer_request_pinned_player.clear()
	_multiplayer_request_navigate_home_after_toast = false
	_multiplayer_request_start_at_ms = 0
	_multiplayer_request_resolved_action = ""
	_multiplayer_request_expire_generation += 1
	_stop_multiplayer_request_waiting_dots()
	_redraw_nearby_swipe_backgrounds()
	_render_stable_ble_players()
	_dismiss_multiplayer_request_toast_without_text_change()


func _dismiss_multiplayer_request_toast_without_text_change() -> void:
	if not is_instance_valid(_request_toast_panel):
		return

	_stop_multiplayer_request_waiting_dots()
	_stop_multiplayer_request_toast_universal_expire_timer()
	_request_toast_generation += 1
	_request_toast_expire_generation += 1
	var local_generation: int = _request_toast_generation
	_request_toast_panel.set_meta("multiplayer_request_toast_pending", false)
	_request_toast_panel.set_meta("multiplayer_request_toast_active", true)

	if _request_toast_tween != null and _request_toast_tween.is_valid():
		_request_toast_tween.kill()

	var out_position := _multiplayer_request_toast_out_position()
	var panel := _request_toast_panel
	var layer_node := _request_toast_layer

	if reduce_motion_enabled:
		panel.visible = false
		panel.set_meta("multiplayer_request_toast_active", false)
		_redraw_nearby_swipe_backgrounds()
		_maybe_navigate_home_after_multiplayer_request_toast()
		if is_instance_valid(layer_node):
			_queue_free_multiplayer_toast_layer_if_empty(layer_node)
		return

	_request_toast_tween = _request_toast_layer.create_tween() if is_instance_valid(_request_toast_layer) else get_tree().create_tween()
	_request_toast_tween.set_trans(Tween.TRANS_CUBIC)
	_request_toast_tween.set_ease(Tween.EASE_IN)
	_request_toast_tween.tween_property(panel, "position", out_position, MULTIPLAYER_TOAST_OUT_TIME)
	_request_toast_tween.parallel().tween_property(panel, "modulate:a", 0.0, MULTIPLAYER_TOAST_OUT_TIME)
	_request_toast_tween.finished.connect(func() -> void:
		if local_generation != _request_toast_generation:
			return
		if is_instance_valid(panel):
			panel.visible = false
			panel.scale = Vector2.ONE
			panel.set_meta("multiplayer_request_toast_active", false)
		_redraw_nearby_swipe_backgrounds()
		_maybe_navigate_home_after_multiplayer_request_toast()
		if is_instance_valid(layer_node):
			_queue_free_multiplayer_toast_layer_if_empty(layer_node)
	)


func _resolve_multiplayer_pending_request(accepted: bool, reason: String = "", start_at_ms: int = 0) -> void:
	if not _multiplayer_request_pending:
		return

	var resolved_action := _multiplayer_request_pending_action
	var resolved_peer_uid := _multiplayer_request_pending_player_uid
	var resolved_peer_name := _multiplayer_request_pending_player_name
	if accepted and resolved_action != "trade":
		_sync_player = {
			"uid": resolved_peer_uid,
			"displayName": resolved_peer_name if not resolved_peer_name.strip_edges().is_empty() else "PLAYER",
			"distanceMeters": _find_nearby_distance_for_player(resolved_peer_uid, resolved_peer_name),
			"syncActive": true,
		}
	if accepted and resolved_action == "trade":
		_trade_mode_active = true
		_trade_player = {
			"uid": resolved_peer_uid,
			"displayName": resolved_peer_name if not resolved_peer_name.strip_edges().is_empty() else "PLAYER",
			"distanceMeters": _find_nearby_distance_for_player(resolved_peer_uid, resolved_peer_name),
			"tradeActive": true,
		}
		_update_nearby_players_ui()
	_multiplayer_request_navigate_home_after_toast = accepted
	_multiplayer_request_start_at_ms = start_at_ms if accepted else 0
	_multiplayer_request_resolved_action = resolved_action if accepted else ""
	_multiplayer_request_resolved_id = _multiplayer_request_pending_id if accepted else ""

	_multiplayer_request_pending = false
	_multiplayer_request_pending_id = ""
	_multiplayer_request_pending_action = ""
	if not accepted:
		_multiplayer_request_pinned_player.clear()
	_multiplayer_request_pending_player_uid = resolved_peer_uid
	_multiplayer_request_pending_player_name = resolved_peer_name
	_multiplayer_request_expire_generation += 1
	_stop_multiplayer_request_waiting_dots()
	_redraw_nearby_swipe_backgrounds()
	if not accepted:
		_render_stable_ble_players()
		_resume_normal_multiplayer_polling_after_interaction()

	# Keep the request toast visually unchanged on accept/deny/expire.
	# The response should only feel like a result through SFX + the leaving animation.
	_play_sfx("success" if accepted else "error")
	_dismiss_multiplayer_request_toast_without_text_change()



func _resume_normal_multiplayer_polling_after_interaction() -> void:
	var database := get_node_or_null("/root/FirebaseDatabase")
	if database != null:
		if database.has_method("clear_active_multiplayer_trade_session"):
			database.call("clear_active_multiplayer_trade_session")
		if database.has_method("start_multiplayer_request_transport"):
			database.call("start_multiplayer_request_transport")
	if _button_toggled:
		_start_nearby_refresh()
		call_deferred("_load_nearby_players")

func _start_multiplayer_request_toast_universal_expire_timer() -> void:
	if not is_instance_valid(_request_toast_layer) or not is_instance_valid(_request_toast_panel):
		return
	if is_instance_valid(_request_toast_universal_expire_timer):
		_request_toast_universal_expire_timer.stop()
		_request_toast_universal_expire_timer.queue_free()

	_request_toast_expire_generation += 1
	var local_generation: int = _request_toast_expire_generation
	_request_toast_panel.set_meta("multiplayer_request_toast_generation", local_generation)
	_request_toast_universal_expire_timer = Timer.new()
	_request_toast_universal_expire_timer.name = "MultiplayerRequestToastExpireTimer"
	_request_toast_universal_expire_timer.one_shot = true
	_request_toast_universal_expire_timer.wait_time = MULTIPLAYER_TOAST_PENDING_EXPIRE_TIME
	_request_toast_universal_expire_timer.process_mode = Node.PROCESS_MODE_ALWAYS
	_request_toast_layer.add_child(_request_toast_universal_expire_timer)
	var timer_node := _request_toast_universal_expire_timer
	_request_toast_universal_expire_timer.timeout.connect(func() -> void:
		if is_instance_valid(timer_node):
			timer_node.queue_free()
		if local_generation != _request_toast_expire_generation:
			return
		_expire_multiplayer_pending_request_from_timer()
	)
	_request_toast_universal_expire_timer.start()

func _expire_multiplayer_pending_request_from_timer() -> void:
	if _multiplayer_request_pending:
		_resolve_multiplayer_pending_request(false, "REQUEST EXPIRED")
		return
	if not is_instance_valid(_request_toast_panel):
		return
	if not bool(_request_toast_panel.get_meta("multiplayer_request_toast_pending", false)):
		return
	_request_toast_panel.set_meta("multiplayer_request_toast_pending", false)
	_multiplayer_request_navigate_home_after_toast = false
	_multiplayer_request_start_at_ms = 0
	_multiplayer_request_resolved_action = ""
	_stop_multiplayer_request_waiting_dots()
	_play_sfx("error")
	_dismiss_multiplayer_request_toast_without_text_change()


func _stop_multiplayer_request_toast_universal_expire_timer() -> void:
	if is_instance_valid(_request_toast_universal_expire_timer):
		_request_toast_universal_expire_timer.stop()
		_request_toast_universal_expire_timer.queue_free()
	_request_toast_universal_expire_timer = null


func _start_multiplayer_pending_request_expire_timer() -> void:
	_multiplayer_request_expire_generation += 1
	var local_generation: int = _multiplayer_request_expire_generation
	var timer := get_tree().create_timer(MULTIPLAYER_TOAST_PENDING_EXPIRE_TIME, true, false, true)
	await timer.timeout
	if local_generation != _multiplayer_request_expire_generation:
		return
	if not _multiplayer_request_pending:
		return
	_resolve_multiplayer_pending_request(false, "REQUEST EXPIRED")


func _start_multiplayer_request_waiting_dots(base_status: String) -> void:
	_stop_multiplayer_request_waiting_dots()
	_request_toast_waiting_base_status = base_status.strip_edges()
	while _request_toast_waiting_base_status.ends_with("."):
		_request_toast_waiting_base_status = _request_toast_waiting_base_status.substr(0, _request_toast_waiting_base_status.length() - 1).strip_edges()
	if _request_toast_waiting_base_status.is_empty():
		_request_toast_waiting_base_status = "WAITING"

	_request_toast_waiting_dots_generation += 1
	_request_toast_waiting_dots_step = 0
	_advance_multiplayer_request_waiting_dots()

	if not is_instance_valid(_request_toast_layer):
		return
	_request_toast_waiting_dots_timer = Timer.new()
	_request_toast_waiting_dots_timer.name = "MultiplayerRequestWaitingDotsTimer"
	_request_toast_waiting_dots_timer.one_shot = false
	_request_toast_waiting_dots_timer.wait_time = MULTIPLAYER_WAITING_DOTS_INTERVAL
	_request_toast_waiting_dots_timer.process_mode = Node.PROCESS_MODE_ALWAYS
	_request_toast_layer.add_child(_request_toast_waiting_dots_timer)
	var local_generation: int = _request_toast_waiting_dots_generation
	_request_toast_waiting_dots_timer.timeout.connect(func() -> void:
		if local_generation != _request_toast_waiting_dots_generation:
			return
		_advance_multiplayer_request_waiting_dots()
	)
	_request_toast_waiting_dots_timer.start()


func _stop_multiplayer_request_waiting_dots() -> void:
	_request_toast_waiting_dots_generation += 1
	_request_toast_waiting_base_status = ""
	_request_toast_waiting_dots_step = 0
	if is_instance_valid(_request_toast_waiting_dots_timer):
		_request_toast_waiting_dots_timer.stop()
		_request_toast_waiting_dots_timer.queue_free()
	_request_toast_waiting_dots_timer = null


func _advance_multiplayer_request_waiting_dots() -> void:
	if not is_instance_valid(_request_toast_panel) or not is_instance_valid(_request_toast_status_label):
		return
	if not bool(_request_toast_panel.get_meta("multiplayer_request_toast_pending", false)):
		return
	_request_toast_waiting_dots_step += 1
	if _request_toast_waiting_dots_step > 3:
		_request_toast_waiting_dots_step = 1
	var dots := "."
	if _request_toast_waiting_dots_step == 2:
		dots = ".."
	elif _request_toast_waiting_dots_step == 3:
		dots = "..."
	_request_toast_status_label.text = "%s%s" % [_request_toast_waiting_base_status, dots]


func _show_multiplayer_request_blocked_toast() -> void:
	var name := _multiplayer_request_pending_player_name
	if name.strip_edges().is_empty():
		name = "THE OTHER PLAYER"
	_show_multiplayer_request_toast(
		"REQUEST PENDING",
		"ONE REQUEST AT A TIME",
		"WAIT FOR %s" % name.to_upper(),
		true
	)
	_play_sfx("toggle")


func _redraw_nearby_swipe_backgrounds() -> void:
	for card_key in _nearby_cards_by_uid.keys():
		var card = _nearby_cards_by_uid.get(card_key, null)
		if card != null and is_instance_valid(card) and card is Node:
			var bg = card.get_node_or_null("SwipeActionBackground")
			if bg is Control:
				bg.queue_redraw()


func _connect_multiplayer_request_response_signals() -> void:
	var database := get_node_or_null("/root/FirebaseDatabase")
	if database == null:
		return
	var owner_id := int(database.get_instance_id())
	if _multiplayer_request_signal_owner_id == owner_id:
		return
	_multiplayer_request_signal_owner_id = owner_id

	var accepted_cb := Callable(self, "_on_multiplayer_request_accepted")
	var denied_cb := Callable(self, "_on_multiplayer_request_denied")
	var resolved_cb := Callable(self, "_on_multiplayer_request_resolved")
	var incoming_cb := Callable(self, "_on_multiplayer_request_received")

	for signal_name in ["multiplayer_request_accepted", "request_accepted", "planet_card_trade_accepted", "universe_sync_accepted"]:
		if database.has_signal(signal_name) and not database.is_connected(signal_name, accepted_cb):
			database.connect(signal_name, accepted_cb)

	for signal_name in ["multiplayer_request_denied", "request_denied", "multiplayer_request_declined", "request_declined", "planet_card_trade_denied", "universe_sync_denied"]:
		if database.has_signal(signal_name) and not database.is_connected(signal_name, denied_cb):
			database.connect(signal_name, denied_cb)

	for signal_name in ["multiplayer_request_resolved", "request_resolved", "multiplayer_response_received", "planet_card_trade_response", "universe_sync_response"]:
		if database.has_signal(signal_name) and not database.is_connected(signal_name, resolved_cb):
			database.connect(signal_name, resolved_cb)

	for signal_name in ["multiplayer_request_received", "request_received", "incoming_multiplayer_request", "incoming_request_received", "planet_card_trade_requested", "universe_sync_requested"]:
		if database.has_signal(signal_name) and not database.is_connected(signal_name, incoming_cb):
			database.connect(signal_name, incoming_cb)

	if database.has_method("start_multiplayer_request_transport"):
		database.call("start_multiplayer_request_transport")


func _on_multiplayer_request_accepted(payload: Variant = null, _extra_a: Variant = null, _extra_b: Variant = null) -> void:
	if not _multiplayer_response_matches_pending(payload):
		return
	_resolve_multiplayer_pending_request_at_server_time(payload)


func _resolve_multiplayer_pending_request_at_server_time(payload: Variant) -> void:
	# Collapse the sent-request card immediately when acceptance is observed.
	# Only the following navigation/home sequence waits for the shared server time.
	var start_at := 0
	if payload is Dictionary:
		start_at = int(payload.get("startAt", 0))
	if _multiplayer_request_pending:
		_resolve_multiplayer_pending_request(true, "", start_at)


func _on_multiplayer_request_denied(payload: Variant = null, _extra_a: Variant = null, _extra_b: Variant = null) -> void:
	# A denial can resolve either our outgoing request or an incoming card that
	# the requester cancelled by disabling location. Handle both directions.
	if _incoming_response_matches_active(payload):
		_cancel_incoming_multiplayer_request_from_remote()
		return
	if not _multiplayer_response_matches_pending(payload):
		return
	var reason := ""
	if payload is Dictionary:
		reason = str(payload.get("message", payload.get("reason", payload.get("deniedReason", ""))))
	_resolve_multiplayer_pending_request(false, reason)


func _incoming_response_matches_active(payload: Variant) -> bool:
	if not _incoming_request_active or not (payload is Dictionary):
		return false
	var request_id := str(payload.get("requestId", payload.get("request_id", payload.get("id", "")))).strip_edges()
	if not request_id.is_empty() and not _incoming_request_id.is_empty():
		return request_id == _incoming_request_id
	var sender_uid := str(payload.get("senderUid", payload.get("fromUid", ""))).strip_edges()
	return not sender_uid.is_empty() and sender_uid == _incoming_request_sender_uid


func _cancel_incoming_multiplayer_request_from_remote() -> void:
	if not _incoming_request_active:
		return
	_incoming_request_active = false
	_incoming_request_id = ""
	_incoming_request_action = ""
	_incoming_request_sender_uid = ""
	_incoming_request_sender_name = ""
	_incoming_request_payload = {}
	_incoming_request_dragging = false
	_incoming_request_drag_started = false
	_incoming_request_drag_offset = 0.0
	_stop_multiplayer_incoming_request_expire_timer()
	_play_sfx("error")
	_hide_multiplayer_incoming_request_card()
	_redraw_nearby_swipe_backgrounds()


func _on_multiplayer_request_resolved(payload: Variant = null, _extra_a: Variant = null, _extra_b: Variant = null) -> void:
	if not _multiplayer_response_matches_pending(payload):
		return
	if payload is Dictionary:
		var accepted := bool(payload.get("accepted", false))
		var status := str(payload.get("status", payload.get("state", ""))).strip_edges().to_lower()
		if status in ["accepted", "accept", "approved"]:
			accepted = true
		elif status in ["denied", "declined", "rejected", "cancelled", "canceled", "expired"]:
			accepted = false
		_resolve_multiplayer_pending_request(accepted, str(payload.get("message", payload.get("reason", ""))))
	else:
		_resolve_multiplayer_pending_request(bool(payload))


func _multiplayer_response_matches_pending(payload: Variant) -> bool:
	if not _multiplayer_request_pending:
		return false
	if payload == null:
		return true
	if not (payload is Dictionary):
		return true

	var payload_action := str(payload.get("action", payload.get("type", payload.get("requestType", "")))).strip_edges().to_lower()
	if not payload_action.is_empty():
		var expected_action := "trade" if _multiplayer_request_pending_action == "trade" else "sync"
		var action_ok := payload_action == expected_action
		action_ok = action_ok or (expected_action == "trade" and payload_action in ["card_trade", "planet_card_trade", "trade_card"])
		action_ok = action_ok or (expected_action == "sync" and payload_action in ["universe_sync", "sync_universe", "sync"])
		if not action_ok:
			return false

	var request_id := str(payload.get("requestId", payload.get("request_id", payload.get("id", "")))).strip_edges()
	if not request_id.is_empty() and not _multiplayer_request_pending_id.is_empty() and request_id != _multiplayer_request_pending_id:
		return false

	var uid_value: Variant = payload.get("uid", payload.get("fromUid", payload.get("toUid", payload.get("playerUid", payload.get("targetUid", "")))))
	var uid := str(uid_value).strip_edges()
	if not uid.is_empty() and not _multiplayer_request_pending_player_uid.is_empty() and uid != _multiplayer_request_pending_player_uid:
		return false

	return true



func _get_multiplayer_local_display_name_for_test_mirror() -> String:
	var local_name := ""
	if is_instance_valid(_username_box):
		local_name = _username_box.text.strip_edges()
	if local_name.is_empty():
		if _settings_node == null:
			_settings_node = get_node_or_null("/root/UnilearnUserSettings")
		if _settings_node != null:
			if _settings_node.has_method("get_display_name"):
				local_name = str(_settings_node.call("get_display_name")).strip_edges()
			elif "display_name" in _settings_node:
				local_name = str(_settings_node.display_name).strip_edges()
	local_name = _limit_multiplayer_display_name(local_name)
	return local_name if not local_name.is_empty() else "YOU"


func _show_multiplayer_sender_test_incoming_card(player: Dictionary, action: String) -> void:
	if not MULTIPLAYER_TEST_MIRROR_INCOMING_ON_SENT:
		return
	if _incoming_request_active and (not is_instance_valid(_incoming_request_panel) or not bool(_incoming_request_panel.get_meta("sender_test_mirror", false))):
		return

	var target_name := str(player.get("displayName", player.get("username", player.get("name", "PLAYER")))).strip_edges()
	if target_name.is_empty():
		target_name = "PLAYER"
	var sender_name := _get_multiplayer_local_display_name_for_test_mirror()

	_incoming_request_active = true
	_incoming_request_id = "local_sender_test_mirror"
	_incoming_request_action = action
	_incoming_request_sender_uid = str(player.get("uid", "")).strip_edges()
	_incoming_request_sender_name = sender_name
	_incoming_request_payload = {"local_sender_test_mirror": true, "action": action, "target_name": target_name}

	_show_multiplayer_incoming_request_card(
		"NEW REQUEST!",
		("CARD TRADE" if action == "trade" else "UNIVERSE SYNC"),
		"FROM %s" % sender_name.to_upper()
	)
	if is_instance_valid(_incoming_request_panel):
		_incoming_request_panel.set_meta("sender_test_mirror", true)


func _hide_multiplayer_sender_test_incoming_card_if_needed() -> void:
	if not is_instance_valid(_incoming_request_panel):
		return
	if not bool(_incoming_request_panel.get_meta("sender_test_mirror", false)):
		return
	_incoming_request_panel.set_meta("sender_test_mirror", false)
	_incoming_request_active = false
	_incoming_request_id = ""
	_incoming_request_action = ""
	_incoming_request_sender_uid = ""
	_incoming_request_sender_name = ""
	_incoming_request_payload = {}
	_hide_multiplayer_incoming_request_card()


func _on_multiplayer_request_received(payload: Variant = null, _extra_a: Variant = null, _extra_b: Variant = null) -> void:
	var request := _normalize_incoming_multiplayer_request_payload(payload, _extra_a, _extra_b)
	if request.is_empty():
		return

	if is_instance_valid(_incoming_request_panel):
		_incoming_request_panel.set_meta("sender_test_mirror", false)
	_incoming_request_active = true
	_incoming_request_id = str(request.get("id", "")).strip_edges()
	_incoming_request_action = str(request.get("action", "sync")).strip_edges().to_lower()
	_incoming_request_sender_uid = str(request.get("sender_uid", "")).strip_edges()
	_incoming_request_sender_name = str(request.get("sender_name", "PLAYER")).strip_edges()
	if _incoming_request_sender_name.is_empty():
		_incoming_request_sender_name = "PLAYER"
	_incoming_request_payload = request

	_show_multiplayer_incoming_request_card(
		"NEW REQUEST!",
		("CARD TRADE" if _incoming_request_action == "trade" else "UNIVERSE SYNC"),
		"FROM %s" % _incoming_request_sender_name.to_upper()
	)
	_play_sfx("achievement")


func _normalize_incoming_multiplayer_request_payload(payload: Variant, extra_a: Variant = null, extra_b: Variant = null) -> Dictionary:
	var source: Dictionary = {}
	if payload is Dictionary:
		source = payload.duplicate(true)
	else:
		if payload != null:
			source["sender_name"] = str(payload)
		if extra_a != null:
			source["action"] = str(extra_a)
		if extra_b != null:
			source["id"] = str(extra_b)

	if source.is_empty():
		return {}

	var raw_action := str(source.get("action", source.get("type", source.get("requestType", source.get("kind", "sync"))))).strip_edges().to_lower()
	var action := "trade" if raw_action.find("trade") >= 0 or raw_action.find("card") >= 0 else "sync"

	var sender_uid := str(source.get("senderUid", source.get("sender_uid", source.get("fromUid", source.get("from_uid", source.get("uid", "")))))).strip_edges()
	var sender_name := str(source.get("senderName", source.get("sender_name", source.get("fromName", source.get("from_name", source.get("displayName", source.get("name", "PLAYER"))))))).strip_edges()
	if sender_name.is_empty():
		sender_name = "PLAYER"

	return {
		"id": str(source.get("requestId", source.get("request_id", source.get("id", "")))).strip_edges(),
		"action": action,
		"sender_uid": sender_uid,
		"sender_name": sender_name,
		"raw": source,
	}


func _accept_incoming_multiplayer_request() -> void:
	if not _incoming_request_active:
		return
	await _bounce_multiplayer_incoming_request_card_tap()
	_finish_incoming_multiplayer_request(true)


func _deny_incoming_multiplayer_request() -> void:
	_finish_incoming_multiplayer_request(false)


func _finish_incoming_multiplayer_request(accepted: bool) -> void:
	if not _incoming_request_active:
		return

	var is_sender_test := is_instance_valid(_incoming_request_panel) and bool(_incoming_request_panel.get_meta("sender_test_mirror", false))
	var request_id := _incoming_request_id
	var action := _incoming_request_action
	var sender_uid := _incoming_request_sender_uid
	var sender_name := _incoming_request_sender_name
	var payload := _incoming_request_payload.duplicate(true)

	if is_instance_valid(_incoming_request_panel):
		_incoming_request_panel.set_meta("sender_test_mirror", false)

	_incoming_request_active = false
	_incoming_request_id = ""
	_incoming_request_action = ""
	_incoming_request_sender_uid = ""
	_incoming_request_sender_name = ""
	_incoming_request_payload = {}
	_incoming_request_dragging = false
	_incoming_request_drag_started = false
	_incoming_request_drag_offset = 0.0

	# Local test mirror: accepting/denying the receiver-side card should also let the
	# sender-side request toast feel the real response flow during testing.
	if is_sender_test:
		_play_sfx("success" if accepted else "error")
		if _multiplayer_request_pending:
			_resolve_multiplayer_pending_request(accepted)
		_hide_multiplayer_incoming_request_card()
		return

	if not accepted:
		_play_sfx("error")
		_hide_multiplayer_incoming_request_card()
	_complete_incoming_multiplayer_request_response(request_id, action, accepted, payload, sender_name, sender_uid)


func _complete_incoming_multiplayer_request_response(request_id: String, action: String, accepted: bool, payload: Dictionary, sender_name: String, sender_uid: String) -> void:
	var result: Variant = await _send_incoming_multiplayer_request_response(request_id, action, accepted, payload)
	if not accepted:
		return
	if not (result is Dictionary) or not bool((result as Dictionary).get("success", false)):
		_play_sfx("error")
		_hide_multiplayer_incoming_request_card()
		return


	if action == "trade":
		var database := get_node_or_null("/root/FirebaseDatabase")
		if database != null and database.has_method("activate_multiplayer_trade_session"):
			database.call("activate_multiplayer_trade_session", result as Dictionary)

	# Acceptance always collapses immediately toward its own side. The actual
	# go-home/start sequence remains locked to the same backend timestamp on both phones.
	_play_sfx("success")
	_hide_multiplayer_incoming_request_card()
	if action == "trade":
		_start_accepted_incoming_card_trade(sender_name, sender_uid, request_id)
	else:
		_start_accepted_incoming_universe_sync(sender_name, sender_uid, request_id)


func _start_accepted_incoming_card_trade(peer_name: String, peer_uid: String, request_id: String = "") -> void:
	var clean_name := peer_name.strip_edges()
	if clean_name.is_empty():
		clean_name = "PLAYER"
	_trade_mode_active = true
	_trade_player = {
		"uid": peer_uid.strip_edges(),
		"displayName": clean_name,
		"distanceMeters": _find_nearby_distance_for_player(peer_uid, clean_name),
		"tradeActive": true,
	}
	_update_nearby_players_ui()
	var bottom_menu := _find_multiplayer_bottom_menu_node()
	if bottom_menu != null and bottom_menu.has_method("begin_multiplayer_card_trade_from_request"):
		bottom_menu.call_deferred("begin_multiplayer_card_trade_from_request", clean_name, peer_uid.strip_edges(), request_id.strip_edges())
	elif bottom_menu != null and bottom_menu.has_method("simulate_ai_go_home"):
		bottom_menu.call_deferred("simulate_ai_go_home")


func _start_accepted_incoming_universe_sync(peer_name: String, peer_uid: String, request_id: String = "") -> void:
	var clean_name := peer_name.strip_edges()
	if clean_name.is_empty():
		clean_name = "PLAYER"
	var peer_distance := _find_nearby_distance_for_player(peer_uid, clean_name)
	_sync_player = {"uid": peer_uid.strip_edges(), "displayName": clean_name, "distanceMeters": peer_distance, "syncActive": true}
	var bottom_menu := _find_multiplayer_bottom_menu_node()
	if bottom_menu != null and bottom_menu.has_method("begin_multiplayer_universe_sync_from_request"):
		bottom_menu.call_deferred("begin_multiplayer_universe_sync_from_request", clean_name, peer_uid.strip_edges(), peer_distance, request_id.strip_edges())
	elif bottom_menu != null and bottom_menu.has_method("simulate_ai_go_home"):
		bottom_menu.call_deferred("simulate_ai_go_home")


func _send_incoming_multiplayer_request_response(request_id: String, action: String, accepted: bool, payload: Dictionary) -> Variant:
	var database := get_node_or_null("/root/FirebaseDatabase")
	if database == null:
		return {}

	if database.has_method("respond_multiplayer_request"):
		return await database.call("respond_multiplayer_request", request_id, accepted)
	if database.has_method("respond_to_multiplayer_request"):
		return await database.call("respond_to_multiplayer_request", request_id, accepted)

	if accepted:
		if action == "trade" and database.has_method("accept_planet_card_trade"):
			return await database.call("accept_planet_card_trade", request_id)
		if action != "trade" and database.has_method("accept_universe_sync"):
			return await database.call("accept_universe_sync", request_id)
		if database.has_method("accept_multiplayer_request"):
			return await database.call("accept_multiplayer_request", request_id)
	else:
		if action == "trade" and database.has_method("deny_planet_card_trade"):
			return await database.call("deny_planet_card_trade", request_id)
		if action != "trade" and database.has_method("deny_universe_sync"):
			return await database.call("deny_universe_sync", request_id)
		if database.has_method("deny_multiplayer_request"):
			return await database.call("deny_multiplayer_request", request_id)
	return {}


func _start_multiplayer_incoming_request_expire_timer() -> void:
	_stop_multiplayer_incoming_request_expire_timer()
	if not is_instance_valid(_request_toast_layer) or not is_instance_valid(_incoming_request_panel):
		return
	_incoming_request_expire_generation += 1
	var local_generation: int = _incoming_request_expire_generation
	_incoming_request_panel.set_meta("multiplayer_incoming_request_generation", local_generation)
	_incoming_request_universal_expire_timer = Timer.new()
	_incoming_request_universal_expire_timer.name = "MultiplayerIncomingRequestExpireTimer"
	_incoming_request_universal_expire_timer.one_shot = true
	_incoming_request_universal_expire_timer.wait_time = MULTIPLAYER_TOAST_PENDING_EXPIRE_TIME
	_incoming_request_universal_expire_timer.process_mode = Node.PROCESS_MODE_ALWAYS
	_request_toast_layer.add_child(_incoming_request_universal_expire_timer)
	var timer_node := _incoming_request_universal_expire_timer
	_incoming_request_universal_expire_timer.timeout.connect(func() -> void:
		if is_instance_valid(timer_node):
			timer_node.queue_free()
		if local_generation != _incoming_request_expire_generation:
			return
		_expire_multiplayer_incoming_request_from_timer()
	)
	_incoming_request_universal_expire_timer.start()


func _expire_multiplayer_incoming_request_from_timer() -> void:
	if not _incoming_request_active:
		return
	_incoming_request_active = false
	_incoming_request_id = ""
	_incoming_request_action = ""
	_incoming_request_sender_uid = ""
	_incoming_request_sender_name = ""
	_incoming_request_payload = {}
	_incoming_request_dragging = false
	_incoming_request_drag_offset = 0.0
	_play_sfx("error")
	_hide_multiplayer_incoming_request_card()


func _stop_multiplayer_incoming_request_expire_timer() -> void:
	_incoming_request_expire_generation += 1
	if is_instance_valid(_incoming_request_universal_expire_timer):
		_incoming_request_universal_expire_timer.stop()
		_incoming_request_universal_expire_timer.queue_free()
	_incoming_request_universal_expire_timer = null


func _setup_multiplayer_incoming_request_card() -> void:
	if is_instance_valid(_incoming_request_panel):
		return
	_setup_multiplayer_request_toast()
	if not is_instance_valid(_request_toast_layer):
		return

	var existing_panel := _request_toast_layer.get_node_or_null("MultiplayerIncomingRequestCard")
	if existing_panel != null and existing_panel is PanelContainer:
		_incoming_request_panel = existing_panel as PanelContainer
		_incoming_request_title_label = _incoming_request_panel.find_child("IncomingRequestTitleLabel", true, false) as Label
		_incoming_request_name_label = _incoming_request_panel.find_child("IncomingRequestNameLabel", true, false) as Label
		_incoming_request_status_label = _incoming_request_panel.find_child("IncomingRequestStatusLabel", true, false) as Label
		_incoming_request_icon = _incoming_request_panel.find_child("MultiplayerRequestToastIcon", true, false) as Control
		_incoming_request_action_background = _request_toast_layer.get_node_or_null("MultiplayerIncomingRequestSwipeBackground") as Control
		_incoming_request_input_surface = _request_toast_layer.get_node_or_null("MultiplayerIncomingRequestInputSurface") as Control
		_incoming_request_deny_button = _incoming_request_panel.find_child("DenyIncomingRequestButton", true, false) as Control
		_incoming_request_accept_button = _incoming_request_panel.find_child("AcceptIncomingRequestButton", true, false) as Control
		_incoming_request_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_incoming_request_panel.z_index = 1001
		_incoming_request_panel.custom_minimum_size = _multiplayer_pair_card_size(MULTIPLAYER_TOAST_WIDTH, MULTIPLAYER_TOAST_HEIGHT)
		if is_instance_valid(_incoming_request_action_background):
			_incoming_request_action_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_incoming_request_action_background.z_index = 1000
		if is_instance_valid(_incoming_request_deny_button):
			_incoming_request_deny_button.visible = false
			_incoming_request_deny_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if is_instance_valid(_incoming_request_accept_button):
			_incoming_request_accept_button.visible = false
			_incoming_request_accept_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if not _incoming_request_panel.gui_input.is_connected(Callable(self, "_on_multiplayer_incoming_request_card_gui_input")):
			_incoming_request_panel.gui_input.connect(Callable(self, "_on_multiplayer_incoming_request_card_gui_input"))
		_ensure_multiplayer_incoming_request_input_catcher()
		_raise_multiplayer_incoming_request_input_order()
		return

	_incoming_request_action_background = Control.new()
	_incoming_request_action_background.name = "MultiplayerIncomingRequestSwipeBackground"
	_incoming_request_action_background.visible = false
	_incoming_request_action_background.modulate.a = 0.0
	_incoming_request_action_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_incoming_request_action_background.z_index = 1000
	_incoming_request_action_background.draw.connect(func() -> void:
		_draw_multiplayer_incoming_request_swipe_background(_incoming_request_action_background)
	)
	_request_toast_layer.add_child(_incoming_request_action_background)

	_incoming_request_panel = PanelContainer.new()
	_incoming_request_panel.name = "MultiplayerIncomingRequestCard"
	_incoming_request_panel.visible = false
	_incoming_request_panel.modulate.a = 0.0
	_incoming_request_panel.custom_minimum_size = _multiplayer_pair_card_size(MULTIPLAYER_TOAST_WIDTH, MULTIPLAYER_TOAST_HEIGHT)
	_incoming_request_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_incoming_request_panel.z_index = 1001
	_incoming_request_panel.add_theme_stylebox_override("panel", _multiplayer_request_toast_panel_style())
	_incoming_request_panel.gui_input.connect(Callable(self, "_on_multiplayer_incoming_request_card_gui_input"))
	_request_toast_layer.add_child(_incoming_request_panel)

	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	_incoming_request_panel.add_child(margin)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 22)
	margin.add_child(row)

	var text_box := VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text_box.alignment = BoxContainer.ALIGNMENT_CENTER
	text_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_box.add_theme_constant_override("separation", 0)
	row.add_child(text_box)

	_incoming_request_title_label = Label.new()
	_incoming_request_title_label.name = "IncomingRequestTitleLabel"
	_incoming_request_title_label.text = "NEW REQUEST!"
	_incoming_request_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_incoming_request_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_incoming_request_title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_incoming_request_title_label.clip_text = true
	_incoming_request_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_incoming_request_title_label.add_theme_font_size_override("font_size", 31)
	_incoming_request_title_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.80))
	_apply_app_font(_incoming_request_title_label)
	text_box.add_child(_incoming_request_title_label)

	_incoming_request_name_label = Label.new()
	_incoming_request_name_label.name = "IncomingRequestNameLabel"
	_incoming_request_name_label.text = "MULTIPLAYER"
	_incoming_request_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_incoming_request_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_incoming_request_name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_incoming_request_name_label.clip_text = true
	_incoming_request_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_incoming_request_name_label.add_theme_font_size_override("font_size", 52)
	_incoming_request_name_label.add_theme_color_override("font_color", Color.WHITE)
	_apply_app_font(_incoming_request_name_label)
	text_box.add_child(_incoming_request_name_label)

	_incoming_request_status_label = Label.new()
	_incoming_request_status_label.name = "IncomingRequestStatusLabel"
	_incoming_request_status_label.text = "FROM PLAYER"
	_incoming_request_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_incoming_request_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_incoming_request_status_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_incoming_request_status_label.clip_text = true
	_incoming_request_status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_incoming_request_status_label.add_theme_font_size_override("font_size", 27)
	_incoming_request_status_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.62))
	_apply_app_font(_incoming_request_status_label)
	text_box.add_child(_incoming_request_status_label)

	_incoming_request_icon = _create_multiplayer_request_toast_icon()
	_incoming_request_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_incoming_request_icon.set_meta("multiplayer_request_use_highlight", true)
	row.add_child(_incoming_request_icon)
	# Keep the incoming card text left-aligned like the sent toast. The card still
	# enters from the left, but the icon/text order stays readable and balanced.
	row.move_child(_incoming_request_icon, 0)

	_ensure_multiplayer_incoming_request_input_catcher()
	_raise_multiplayer_incoming_request_input_order()
	_layout_multiplayer_incoming_request_card(true)


func _ensure_multiplayer_incoming_request_input_catcher() -> void:
	if not is_instance_valid(_incoming_request_panel) or not is_instance_valid(_request_toast_layer):
		return

	# Older patches used a child catcher inside the PanelContainer. That can still
	# lose input when the PanelContainer resolves a smaller minimum size, so keep it
	# disabled and use a sibling surface with the exact toast rect instead.
	var old_child := _incoming_request_panel.get_node_or_null("IncomingRequestInputCatcher") as Control
	if is_instance_valid(old_child):
		old_child.mouse_filter = Control.MOUSE_FILTER_IGNORE
		old_child.visible = false

	if not is_instance_valid(_incoming_request_input_surface):
		_incoming_request_input_surface = _request_toast_layer.get_node_or_null("MultiplayerIncomingRequestInputSurface") as Control
	if is_instance_valid(_incoming_request_input_surface) and not (_incoming_request_input_surface is Button):
		_incoming_request_input_surface.queue_free()
		_incoming_request_input_surface = null
	if not is_instance_valid(_incoming_request_input_surface):
		# Use a transparent input surface exactly over the card. It is STOP only
		# inside the toast rect, so the card receives tap/drag while the rest of
		# the screen still belongs to the popup/scene behind it.
		var input_button := Button.new()
		input_button.name = "MultiplayerIncomingRequestInputSurface"
		input_button.flat = true
		input_button.text = ""
		input_button.mouse_filter = Control.MOUSE_FILTER_PASS
		input_button.visible = false
		input_button.z_index = 1002
		input_button.focus_mode = Control.FOCUS_NONE
		input_button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
		input_button.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
		input_button.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
		input_button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		_incoming_request_input_surface = input_button
		_request_toast_layer.add_child(_incoming_request_input_surface)

	_incoming_request_input_surface.mouse_filter = Control.MOUSE_FILTER_STOP
	_incoming_request_input_surface.z_index = 1002
	_incoming_request_input_surface.focus_mode = Control.FOCUS_NONE
	if not _incoming_request_input_surface.gui_input.is_connected(Callable(self, "_on_multiplayer_incoming_request_card_gui_input")):
		_incoming_request_input_surface.gui_input.connect(Callable(self, "_on_multiplayer_incoming_request_card_gui_input"))
	_sync_multiplayer_incoming_request_input_surface()


func _sync_multiplayer_incoming_request_input_surface() -> void:
	if not is_instance_valid(_incoming_request_input_surface) or not is_instance_valid(_incoming_request_panel):
		return
	# Exact-card STOP input proxy. It cannot steal touches outside the visible
	# card area, but every tap/drag on the toast is captured above the popup.
	_incoming_request_input_surface.position = _incoming_request_panel.position
	_incoming_request_input_surface.size = _incoming_request_panel.size
	_incoming_request_input_surface.custom_minimum_size = _incoming_request_panel.size
	_incoming_request_input_surface.scale = _incoming_request_panel.scale
	_incoming_request_input_surface.pivot_offset = _incoming_request_panel.pivot_offset
	_incoming_request_input_surface.visible = _incoming_request_panel.visible and bool(_incoming_request_panel.get_meta("multiplayer_incoming_request_active", false))


func _raise_multiplayer_incoming_request_input_order() -> void:
	if not is_instance_valid(_request_toast_layer):
		return
	if is_instance_valid(_incoming_request_action_background) and _incoming_request_action_background.get_parent() == _request_toast_layer:
		_incoming_request_action_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_incoming_request_action_background.z_index = 1000
		_request_toast_layer.move_child(_incoming_request_action_background, 0)
	if is_instance_valid(_incoming_request_panel) and _incoming_request_panel.get_parent() == _request_toast_layer:
		_incoming_request_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_incoming_request_panel.z_index = 1001
		_request_toast_layer.move_child(_incoming_request_panel, _request_toast_layer.get_child_count() - 1)
	if is_instance_valid(_incoming_request_input_surface) and _incoming_request_input_surface.get_parent() == _request_toast_layer:
		_incoming_request_input_surface.mouse_filter = Control.MOUSE_FILTER_STOP
		_incoming_request_input_surface.z_index = 1002
		_request_toast_layer.move_child(_incoming_request_input_surface, _request_toast_layer.get_child_count() - 1)
	_sync_multiplayer_incoming_request_input_surface()


func _create_incoming_request_response_button(text: String, accepted: bool) -> Control:
	var button := Control.new()
	button.name = "%sIncomingRequestButton" % text.capitalize()
	button.custom_minimum_size = Vector2(198, 54)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.set_meta("pressed", false)
	button.draw.connect(func() -> void:
		var rect := Rect2(Vector2.ZERO, button.size)
		var is_pressed := bool(button.get_meta("pressed", false))
		var bg := Color.WHITE if accepted else Color(1.0, 1.0, 1.0, 0.05)
		var fg := Color.BLACK if accepted else Color.WHITE
		if is_pressed:
			bg = bg.darkened(0.18)
		var style := StyleBoxFlat.new()
		style.bg_color = bg
		style.border_color = Color.WHITE
		style.set_border_width_all(4)
		style.set_corner_radius_all(18)
		button.draw_style_box(style, rect)
		var font := _app_font
		if font == null:
			font = ThemeDB.fallback_font
		var font_size := 28
		var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		button.draw_string(font, Vector2((button.size.x - text_size.x) * 0.5, (button.size.y + text_size.y * 0.5) * 0.5 - 2.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, fg)
	)
	button.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventScreenTouch:
			button.set_meta("pressed", event.pressed)
			button.queue_redraw()
			if not event.pressed:
				if accepted:
					_accept_incoming_multiplayer_request()
				else:
					_deny_incoming_multiplayer_request()
				get_viewport().set_input_as_handled()
		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			button.set_meta("pressed", event.pressed)
			button.queue_redraw()
			if not event.pressed:
				if accepted:
					_accept_incoming_multiplayer_request()
				else:
					_deny_incoming_multiplayer_request()
				get_viewport().set_input_as_handled()
	)
	return button


func _handle_multiplayer_incoming_request_global_input(event: InputEvent) -> bool:
	if not _incoming_request_active or not is_instance_valid(_incoming_request_panel) or not _incoming_request_panel.visible:
		return false

	if event is InputEventScreenTouch:
		var touch_pos: Vector2 = event.position
		if event.pressed:
			if not _multiplayer_incoming_request_interaction_rect().has_point(touch_pos):
				return false
			_begin_multiplayer_incoming_request_interaction(touch_pos, event.index)
			return true
		if _incoming_request_dragging and (_incoming_request_drag_pointer_id == event.index or _incoming_request_drag_pointer_id == -999):
			_finish_multiplayer_incoming_drag()
			return true
		return false

	if event is InputEventScreenDrag:
		if _incoming_request_dragging and (_incoming_request_drag_pointer_id == event.index or _incoming_request_drag_pointer_id == -999):
			_update_multiplayer_incoming_drag(event.position)
			return true
		return false

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var mouse_pos: Vector2 = event.position
		if event.pressed:
			if not _multiplayer_incoming_request_interaction_rect().has_point(mouse_pos):
				return false
			_begin_multiplayer_incoming_request_interaction(mouse_pos, -999)
			return true
		if _incoming_request_dragging:
			_finish_multiplayer_incoming_drag()
			return true
		return false

	if event is InputEventMouseMotion and _incoming_request_dragging:
		_update_multiplayer_incoming_drag(event.position)
		return true

	return false


func _multiplayer_incoming_request_interaction_rect() -> Rect2:
	if not is_instance_valid(_incoming_request_panel):
		return Rect2()
	var position := _incoming_request_panel.position
	var size := _incoming_request_panel.size
	if size.x <= 0.0 or size.y <= 0.0:
		size = _multiplayer_pair_card_size(MULTIPLAYER_TOAST_WIDTH, MULTIPLAYER_TOAST_HEIGHT)
	# Accept only the visible card area. When the mirrored card is intentionally
	# cut off on the left, the off-screen part is not allowed to steal touches.
	var viewport_size := _multiplayer_request_toast_viewport_size()
	var rect := Rect2(position, size)
	var visible_rect := Rect2(Vector2.ZERO, viewport_size)
	var clipped := rect.intersection(visible_rect)
	if clipped.size.x > 0.0 and clipped.size.y > 0.0:
		return clipped.grow(6.0)
	return rect.grow(6.0)


func _multiplayer_incoming_gui_event_viewport_position(event: InputEvent) -> Vector2:
	var local_pos := Vector2.ZERO
	if event is InputEventScreenTouch:
		local_pos = event.position
	elif event is InputEventScreenDrag:
		local_pos = event.position
	elif event is InputEventMouseButton:
		local_pos = event.position
	elif event is InputEventMouseMotion:
		local_pos = event.position
	else:
		return Vector2.ZERO

	if is_instance_valid(_incoming_request_input_surface) and _incoming_request_input_surface.visible:
		return _incoming_request_input_surface.position + local_pos
	if is_instance_valid(_incoming_request_panel):
		return _incoming_request_panel.position + local_pos
	return local_pos


func _on_multiplayer_incoming_request_card_gui_input(event: InputEvent) -> void:
	if not _incoming_request_active or not is_instance_valid(_incoming_request_panel):
		return
	var viewport_pos := _multiplayer_incoming_gui_event_viewport_position(event)
	if event is InputEventScreenTouch:
		if event.pressed:
			_begin_multiplayer_incoming_request_interaction(viewport_pos, event.index)
		else:
			if _incoming_request_dragging and (_incoming_request_drag_pointer_id == event.index or _incoming_request_drag_pointer_id == -999):
				_finish_multiplayer_incoming_drag()
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		if _incoming_request_dragging and (_incoming_request_drag_pointer_id == event.index or _incoming_request_drag_pointer_id == -999):
			_update_multiplayer_incoming_drag(viewport_pos)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_begin_multiplayer_incoming_request_interaction(viewport_pos, -999)
		elif _incoming_request_dragging:
			_finish_multiplayer_incoming_drag()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _incoming_request_dragging:
		_update_multiplayer_incoming_drag(viewport_pos)
		get_viewport().set_input_as_handled()


func _begin_multiplayer_incoming_request_interaction(position: Vector2, pointer_id: int) -> void:
	if not is_instance_valid(_incoming_request_panel):
		return
	if _incoming_request_tween != null and _incoming_request_tween.is_valid():
		_incoming_request_tween.kill()
	if _incoming_request_press_tween != null and _incoming_request_press_tween.is_valid():
		_incoming_request_press_tween.kill()
	_incoming_request_dragging = true
	_incoming_request_drag_started = false
	_incoming_request_pressing = true
	_incoming_request_drag_start = position
	_incoming_request_drag_offset = 0.0
	_incoming_request_drag_pointer_id = pointer_id
	_incoming_request_panel.set_meta("incoming_drag_base_position", _multiplayer_incoming_request_card_in_position())
	_incoming_request_panel.pivot_offset = _incoming_request_panel.size * 0.5
	if not reduce_motion_enabled:
		_incoming_request_press_tween = _request_toast_layer.create_tween() if is_instance_valid(_request_toast_layer) else get_tree().create_tween()
		_incoming_request_press_tween.set_trans(Tween.TRANS_BACK)
		_incoming_request_press_tween.set_ease(Tween.EASE_OUT)
		_incoming_request_press_tween.tween_property(_incoming_request_panel, "scale", Vector2(0.965, 0.965), BUTTON_DOWN_TIME)
	get_viewport().set_input_as_handled()


func _update_multiplayer_incoming_drag(pointer_position: Vector2) -> void:
	if not is_instance_valid(_incoming_request_panel):
		return
	var delta := pointer_position - _incoming_request_drag_start
	if not _incoming_request_drag_started:
		if abs(delta.x) < SWIPE_DEADZONE and abs(delta.y) < SWIPE_DEADZONE:
			return
		if abs(delta.y) > abs(delta.x) * 1.15:
			_incoming_request_dragging = false
			_incoming_request_drag_started = false
			_incoming_request_drag_pointer_id = -999
			_animate_multiplayer_incoming_request_back_to_place()
			return
		_incoming_request_drag_started = true
		_incoming_request_pressing = false
		if _incoming_request_press_tween != null and _incoming_request_press_tween.is_valid():
			_incoming_request_press_tween.kill()
		_incoming_request_panel.scale = Vector2.ONE

	var next_offset: float = clamp(delta.x, -SWIPE_MAX_DISTANCE, 0.0)
	_update_multiplayer_incoming_swipe_position(next_offset)


func _update_multiplayer_incoming_swipe_position(offset: float) -> void:
	if not is_instance_valid(_incoming_request_panel):
		return
	_incoming_request_drag_offset = offset
	var base_position: Vector2 = _incoming_request_panel.get_meta("incoming_drag_base_position", _multiplayer_incoming_request_card_in_position())
	_incoming_request_panel.position = base_position + Vector2(offset, 0.0)
	_incoming_request_panel.modulate.a = 1.0
	_sync_multiplayer_incoming_request_input_surface()
	_update_multiplayer_incoming_swipe_background_layout(true)


func _finish_multiplayer_incoming_drag() -> void:
	if not is_instance_valid(_incoming_request_panel):
		return
	var dragged: float = abs(_incoming_request_drag_offset)
	var tap_limit := 16.0
	var deny_threshold: float = SWIPE_MAX_DISTANCE * SWIPE_COMMIT_RATIO
	var was_real_drag := _incoming_request_drag_started
	_incoming_request_dragging = false
	_incoming_request_drag_started = false
	_incoming_request_drag_pointer_id = -999
	if was_real_drag and dragged >= deny_threshold:
		_animate_multiplayer_incoming_request_commit_left()
		return
	if dragged <= tap_limit and not was_real_drag:
		_accept_incoming_multiplayer_request()
		return
	_play_sfx("toggle")
	_animate_multiplayer_incoming_request_back_to_place()


func _bounce_multiplayer_incoming_request_card_tap() -> void:
	if not is_instance_valid(_incoming_request_panel):
		return
	if reduce_motion_enabled:
		return
	if _incoming_request_press_tween != null and _incoming_request_press_tween.is_valid():
		_incoming_request_press_tween.kill()
	_incoming_request_panel.pivot_offset = _incoming_request_panel.size * 0.5
	_incoming_request_press_tween = _request_toast_layer.create_tween() if is_instance_valid(_request_toast_layer) else get_tree().create_tween()
	_incoming_request_press_tween.set_trans(Tween.TRANS_BACK)
	_incoming_request_press_tween.set_ease(Tween.EASE_OUT)
	_incoming_request_press_tween.tween_property(_incoming_request_panel, "scale", Vector2(1.025, 1.025), BUTTON_UP_TIME)
	_incoming_request_press_tween.tween_property(_incoming_request_panel, "scale", Vector2.ONE, BUTTON_SETTLE_TIME)
	await _incoming_request_press_tween.finished


func _animate_multiplayer_incoming_request_commit_left() -> void:
	if not is_instance_valid(_incoming_request_panel):
		return
	if _incoming_request_tween != null and _incoming_request_tween.is_valid():
		_incoming_request_tween.kill()
	if is_instance_valid(_incoming_request_action_background):
		_incoming_request_action_background.visible = true
		_incoming_request_action_background.modulate.a = 1.0
		_incoming_request_action_background.queue_redraw()
	# Do not snap/bounce to a secondary commit position before resolving.
	# The exit animation now starts exactly from the finger-left swipe position.
	_deny_incoming_multiplayer_request()


func _animate_multiplayer_incoming_request_back_to_place() -> void:
	if not is_instance_valid(_incoming_request_panel):
		return
	if _incoming_request_tween != null and _incoming_request_tween.is_valid():
		_incoming_request_tween.kill()
	if _incoming_request_press_tween != null and _incoming_request_press_tween.is_valid():
		_incoming_request_press_tween.kill()
	_incoming_request_pressing = false
	var from_offset := _incoming_request_drag_offset
	_incoming_request_tween = _request_toast_layer.create_tween() if is_instance_valid(_request_toast_layer) else get_tree().create_tween()
	_incoming_request_tween.set_trans(Tween.TRANS_CUBIC)
	_incoming_request_tween.set_ease(Tween.EASE_OUT)
	_incoming_request_tween.tween_method(func(value: float) -> void:
		_update_multiplayer_incoming_swipe_position(value)
	, from_offset, 0.0, SWIPE_RELEASE_TIME)
	_incoming_request_tween.parallel().tween_property(_incoming_request_panel, "scale", Vector2.ONE, SWIPE_RELEASE_TIME)
	if is_instance_valid(_incoming_request_action_background):
		_incoming_request_tween.parallel().tween_property(_incoming_request_action_background, "modulate:a", 0.0, SWIPE_RELEASE_TIME)



func _update_multiplayer_incoming_swipe_background_layout(revealed: bool) -> void:
	if not is_instance_valid(_incoming_request_action_background) or not is_instance_valid(_incoming_request_panel):
		return
	_incoming_request_action_background.size = _incoming_request_panel.size
	_incoming_request_action_background.custom_minimum_size = _incoming_request_panel.size
	_incoming_request_action_background.position = _multiplayer_incoming_request_card_in_position()
	_incoming_request_action_background.visible = _incoming_request_panel.visible and revealed
	# The deny reveal should feel like a real card action background, not like a
	# loading overlay: once the swipe starts, the white border/text are fully there.
	# They only fade out after cancel/deny.
	_incoming_request_action_background.modulate.a = 1.0 if revealed else 0.0
	_incoming_request_action_background.queue_redraw()


func _draw_multiplayer_incoming_request_swipe_background(target: Control) -> void:
	if not is_instance_valid(target):
		return
	var rect := Rect2(Vector2.ZERO, target.size)
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1.0, 1.0, 1.0, 0.0)
	style.border_color = Color.WHITE
	style.set_border_width_all(5)
	style.set_corner_radius_all(28)
	target.draw_style_box(style, rect)
	var font := _app_font
	if font == null:
		font = ThemeDB.fallback_font
	var label := "DENY"
	var font_size := 74
	var text_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var color := Color.WHITE
	target.draw_string(font, Vector2(rect.size.x - text_size.x - 42.0, (rect.size.y + text_size.y * 0.5) * 0.5 - 2.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _multiplayer_request_action_from_title(request_title: String) -> String:
	var clean_title := request_title.strip_edges().to_lower()
	if clean_title.find("trade") >= 0 or clean_title.find("card") >= 0:
		return "trade"
	return "sync"

func _show_multiplayer_incoming_request_card(title: String, request_name: String, status: String) -> void:
	if not is_instance_valid(_incoming_request_panel):
		_setup_multiplayer_incoming_request_card()
	if not is_instance_valid(_incoming_request_panel):
		return

	_incoming_request_generation += 1
	if is_instance_valid(_incoming_request_title_label):
		_incoming_request_title_label.text = title
	if is_instance_valid(_incoming_request_name_label):
		_incoming_request_name_label.text = request_name
		_incoming_request_name_label.add_theme_color_override("font_color", Color.WHITE)
	if is_instance_valid(_incoming_request_status_label):
		_incoming_request_status_label.text = status
	if is_instance_valid(_incoming_request_icon):
		_incoming_request_icon.custom_minimum_size = Vector2(MULTIPLAYER_TOAST_ICON_SIZE, MULTIPLAYER_TOAST_ICON_SIZE)
		_incoming_request_icon.size = _incoming_request_icon.custom_minimum_size
		_incoming_request_icon.visible = true
		_incoming_request_icon.modulate = Color.WHITE
		_incoming_request_icon.set_meta("multiplayer_request_action", _multiplayer_request_action_from_title(request_name))
		_incoming_request_icon.set_meta("multiplayer_request_use_highlight", true)
		_incoming_request_icon.queue_redraw()

	_update_multiplayer_request_toast_theme_colors()

	_incoming_request_panel.set_meta("multiplayer_incoming_request_active", true)
	_incoming_request_dragging = false
	_incoming_request_drag_offset = 0.0
	_incoming_request_drag_pointer_id = -999
	_start_multiplayer_incoming_request_expire_timer()
	_layout_multiplayer_incoming_request_card(true)
	_raise_multiplayer_incoming_request_input_order()
	_update_multiplayer_incoming_swipe_background_layout(false)
	_incoming_request_panel.visible = true
	_sync_multiplayer_incoming_request_input_surface()
	_incoming_request_panel.modulate.a = 0.0
	_incoming_request_panel.scale = Vector2(0.982, 0.982)
	if is_instance_valid(_incoming_request_action_background):
		_incoming_request_action_background.visible = true
		_incoming_request_action_background.modulate.a = 0.0

	if _incoming_request_tween != null and _incoming_request_tween.is_valid():
		_incoming_request_tween.kill()

	var in_position := _multiplayer_incoming_request_card_in_position()
	var out_position := _multiplayer_incoming_request_card_out_position()
	_incoming_request_panel.position = out_position
	_sync_multiplayer_incoming_request_input_surface()

	if reduce_motion_enabled:
		_incoming_request_panel.position = in_position
		_incoming_request_panel.modulate.a = 1.0
		_sync_multiplayer_incoming_request_input_surface()
		if is_instance_valid(_incoming_request_action_background):
			_incoming_request_action_background.modulate.a = 0.0
		return

	_incoming_request_tween = _request_toast_layer.create_tween() if is_instance_valid(_request_toast_layer) else get_tree().create_tween()
	_incoming_request_tween.set_trans(Tween.TRANS_CUBIC)
	_incoming_request_tween.set_ease(Tween.EASE_OUT)
	_incoming_request_tween.tween_property(_incoming_request_panel, "position", in_position, MULTIPLAYER_TOAST_IN_TIME)
	if is_instance_valid(_incoming_request_input_surface):
		_incoming_request_tween.parallel().tween_property(_incoming_request_input_surface, "position", in_position, MULTIPLAYER_TOAST_IN_TIME)
	_incoming_request_tween.parallel().tween_property(_incoming_request_panel, "scale", Vector2.ONE, MULTIPLAYER_TOAST_IN_TIME)
	_incoming_request_tween.parallel().tween_property(_incoming_request_panel, "modulate:a", 1.0, 0.30)


func _hide_multiplayer_incoming_request_card() -> void:
	if not is_instance_valid(_incoming_request_panel):
		return
	_incoming_request_panel.set_meta("multiplayer_incoming_request_active", false)
	_stop_multiplayer_incoming_request_expire_timer()
	_incoming_request_generation += 1
	_incoming_request_pressing = false
	_incoming_request_drag_started = false
	if _incoming_request_press_tween != null and _incoming_request_press_tween.is_valid():
		_incoming_request_press_tween.kill()
	if _incoming_request_tween != null and _incoming_request_tween.is_valid():
		_incoming_request_tween.kill()

	var out_position := _multiplayer_incoming_request_card_out_position()
	# Preserve whatever x-position the swipe left at. This avoids the deny exit
	# bouncing back toward the resting position before leaving the screen.
	var current_panel_position: Vector2 = _incoming_request_panel.position
	if is_instance_valid(_incoming_request_input_surface):
		_incoming_request_input_surface.position = current_panel_position
	if reduce_motion_enabled:
		if is_instance_valid(_incoming_request_input_surface):
			_incoming_request_input_surface.visible = false
		_incoming_request_panel.visible = false
		_incoming_request_panel.modulate.a = 0.0
		_incoming_request_panel.position = out_position
		if is_instance_valid(_incoming_request_action_background):
			_incoming_request_action_background.visible = false
			_incoming_request_action_background.modulate.a = 0.0
		return

	_incoming_request_tween = _request_toast_layer.create_tween() if is_instance_valid(_request_toast_layer) else get_tree().create_tween()
	_incoming_request_tween.set_trans(Tween.TRANS_CUBIC)
	_incoming_request_tween.set_ease(Tween.EASE_IN)
	_incoming_request_tween.tween_property(_incoming_request_panel, "position", out_position, MULTIPLAYER_TOAST_OUT_TIME)
	if is_instance_valid(_incoming_request_input_surface):
		_incoming_request_tween.parallel().tween_property(_incoming_request_input_surface, "position", out_position, MULTIPLAYER_TOAST_OUT_TIME)
	_incoming_request_tween.parallel().tween_property(_incoming_request_panel, "modulate:a", 0.0, MULTIPLAYER_TOAST_OUT_TIME)
	if is_instance_valid(_incoming_request_action_background):
		_incoming_request_tween.parallel().tween_property(_incoming_request_action_background, "modulate:a", 0.0, MULTIPLAYER_TOAST_OUT_TIME)
	await _incoming_request_tween.finished
	if is_instance_valid(_incoming_request_input_surface):
		_incoming_request_input_surface.visible = false
	if is_instance_valid(_incoming_request_panel):
		_incoming_request_panel.visible = false
		_incoming_request_panel.scale = Vector2.ONE
		_incoming_request_panel.modulate.a = 0.0
	if is_instance_valid(_incoming_request_action_background):
		_incoming_request_action_background.visible = false
		_incoming_request_action_background.modulate.a = 0.0
	_incoming_request_dragging = false
	_incoming_request_drag_offset = 0.0
	if is_instance_valid(_request_toast_layer):
		_queue_free_multiplayer_toast_layer_if_empty(_request_toast_layer)


func _layout_multiplayer_incoming_request_card(offscreen: bool = false) -> void:
	if not is_instance_valid(_incoming_request_panel):
		return
	# Match the outgoing request toast exactly. Using the outgoing panel size avoids
	# the incoming PanelContainer resolving to its children and becoming shorter.
	var size := _multiplayer_request_pair_exact_size()
	_incoming_request_panel.custom_minimum_size = size
	_incoming_request_panel.size = size
	_incoming_request_panel.set_deferred("size", size)
	_incoming_request_panel.pivot_offset = size * 0.5
	_apply_multiplayer_request_card_responsive_fonts(size.x)
	var target_position := _multiplayer_incoming_request_card_out_position() if offscreen else _multiplayer_incoming_request_card_in_position()
	_incoming_request_panel.position = target_position
	_ensure_multiplayer_incoming_request_input_catcher()
	_raise_multiplayer_incoming_request_input_order()
	_sync_multiplayer_incoming_request_input_surface()


func _multiplayer_incoming_request_card_in_position() -> Vector2:
	# Mirror the outgoing toast correctly: the left toast's RIGHT edge stays before
	# the outgoing toast's LEFT edge. If there is not enough width, only the LEFT
	# edge gets cut off-screen. Never push it right and never overlap the sent toast.
	var width: float = _multiplayer_request_pair_exact_size().x
	if width <= 0.0:
		width = _multiplayer_pair_card_width(MULTIPLAYER_TOAST_WIDTH)
	var sent_left: float = _multiplayer_request_toast_in_position().x
	var max_right: float = sent_left - MULTIPLAYER_TOAST_PAIR_GAP
	var x: float = MULTIPLAYER_TOAST_LEFT_MARGIN
	if x + width > max_right:
		x = max_right - width
	return Vector2(x, MULTIPLAYER_TOAST_TOP_MARGIN)


func _multiplayer_incoming_request_card_out_position() -> Vector2:
	return Vector2(-_multiplayer_pair_card_width(MULTIPLAYER_TOAST_WIDTH) - 26.0, MULTIPLAYER_TOAST_TOP_MARGIN)


func _multiplayer_request_pair_exact_size() -> Vector2:
	if is_instance_valid(_request_toast_panel):
		var toast_size: Vector2 = _request_toast_panel.size
		if toast_size.x > 0.0 and toast_size.y > 0.0:
			return toast_size
	return _multiplayer_pair_card_size(MULTIPLAYER_TOAST_WIDTH, MULTIPLAYER_TOAST_HEIGHT)


func _multiplayer_pair_card_width(base_width: float) -> float:
	var viewport_size: Vector2 = _multiplayer_request_toast_viewport_size()
	var paired_max: float = floor((viewport_size.x - MULTIPLAYER_TOAST_LEFT_MARGIN - MULTIPLAYER_TOAST_RIGHT_MARGIN - MULTIPLAYER_TOAST_PAIR_GAP) * 0.5)
	var single_max: float = max(viewport_size.x - MULTIPLAYER_TOAST_LEFT_MARGIN - MULTIPLAYER_TOAST_RIGHT_MARGIN, 280.0)
	var max_width: float = paired_max if paired_max >= 320.0 else single_max
	return clamp(base_width, 280.0, max_width)


func _multiplayer_pair_card_size(base_width: float, base_height: float) -> Vector2:
	return Vector2(_multiplayer_pair_card_width(base_width), base_height)


func _apply_multiplayer_request_card_responsive_fonts(width: float) -> void:
	# The outgoing toast must visually match the incoming card. Its short WAIT NAME
	# status now fits safely, so never shrink the entire outgoing text hierarchy.
	# Previously a ~335 px paired toast entered the "tiny" branch and became
	# 24/34/22 while a persistent incoming card could remain 31/52/27.
	if is_instance_valid(_request_toast_title_label):
		_request_toast_title_label.add_theme_font_size_override("font_size", 31)
	if is_instance_valid(_request_toast_name_label):
		_request_toast_name_label.add_theme_font_size_override("font_size", 52)
	if is_instance_valid(_request_toast_status_label):
		_request_toast_status_label.add_theme_font_size_override("font_size", 27)

	if is_instance_valid(_incoming_request_title_label):
		# Existing incoming cards already use the intended full-size typography.
		# Keep those exact values too so both sides are deterministic.
		_incoming_request_title_label.add_theme_font_size_override("font_size", 31)
	if is_instance_valid(_incoming_request_name_label):
		_incoming_request_name_label.add_theme_font_size_override("font_size", 52)
	if is_instance_valid(_incoming_request_status_label):
		_incoming_request_status_label.add_theme_font_size_override("font_size", 27)



func _update_multiplayer_request_toast_theme_colors() -> void:
	# Live color refresh only. Keep active tweens, modulate, positions, scales,
	# timers, waiting dots and request state exactly as they are.
	var highlight := _get_theme_highlight_color()

	if is_instance_valid(_request_toast_panel):
		_request_toast_panel.add_theme_stylebox_override("panel", _multiplayer_request_toast_panel_style())
	if is_instance_valid(_incoming_request_panel):
		_incoming_request_panel.add_theme_stylebox_override("panel", _multiplayer_request_toast_panel_style())

	if is_instance_valid(_request_toast_title_label):
		_request_toast_title_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.80))
	if is_instance_valid(_request_toast_name_label):
		var request_uses_highlight := is_instance_valid(_request_toast_icon) and bool(_request_toast_icon.get_meta("multiplayer_request_use_highlight", false))
		_request_toast_name_label.add_theme_color_override("font_color", highlight if request_uses_highlight and not bool(_request_toast_panel.get_meta("multiplayer_request_toast_pending", true)) else Color.WHITE)
	if is_instance_valid(_request_toast_status_label):
		_request_toast_status_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.62))
	if is_instance_valid(_request_toast_icon):
		if str(_request_toast_icon.get_meta("multiplayer_request_action", "")).strip_edges().is_empty() and is_instance_valid(_request_toast_name_label):
			_request_toast_icon.set_meta("multiplayer_request_action", _multiplayer_request_action_from_title(_request_toast_name_label.text))
		_request_toast_icon.set_meta("multiplayer_request_use_highlight", bool(_request_toast_icon.get_meta("multiplayer_request_use_highlight", _multiplayer_request_pending)))
		_refresh_multiplayer_request_toast_icon_visual(_request_toast_icon)

	if is_instance_valid(_incoming_request_title_label):
		_incoming_request_title_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.80))
	if is_instance_valid(_incoming_request_name_label):
		_incoming_request_name_label.add_theme_color_override("font_color", Color.WHITE)
	if is_instance_valid(_incoming_request_status_label):
		_incoming_request_status_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.62))
	if is_instance_valid(_incoming_request_icon):
		if str(_incoming_request_icon.get_meta("multiplayer_request_action", "")).strip_edges().is_empty() and is_instance_valid(_incoming_request_name_label):
			_incoming_request_icon.set_meta("multiplayer_request_action", _multiplayer_request_action_from_title(_incoming_request_name_label.text))
		_incoming_request_icon.set_meta("multiplayer_request_use_highlight", bool(_incoming_request_icon.get_meta("multiplayer_request_use_highlight", true)))
		_refresh_multiplayer_request_toast_icon_visual(_incoming_request_icon)
	if is_instance_valid(_incoming_request_action_background):
		_incoming_request_action_background.queue_redraw()

func _setup_multiplayer_request_toast() -> void:
	if is_instance_valid(_request_toast_panel):
		return

	var tree := get_tree()
	var root_node := tree.root if tree != null else null
	if root_node == null:
		return

	var existing_layer := root_node.get_node_or_null("UniversalMultiplayerRequestToastLayer")
	if existing_layer != null and existing_layer is CanvasLayer:
		_request_toast_layer = existing_layer as CanvasLayer
		_request_toast_layer.layer = MULTIPLAYER_TOAST_LAYER
		var existing_panel := _request_toast_layer.get_node_or_null("MultiplayerRequestToast")
		if existing_panel != null and existing_panel is PanelContainer:
			_request_toast_panel = existing_panel as PanelContainer
			_request_toast_title_label = _request_toast_panel.find_child("RequestToastTitleLabel", true, false) as Label
			_request_toast_name_label = _request_toast_panel.find_child("RequestToastNameLabel", true, false) as Label
			_request_toast_status_label = _request_toast_panel.find_child("RequestToastStatusLabel", true, false) as Label
			_request_toast_icon = _request_toast_panel.find_child("MultiplayerRequestToastIcon", true, false) as Control

			if is_instance_valid(_request_toast_title_label) and is_instance_valid(_request_toast_name_label) and is_instance_valid(_request_toast_status_label) and is_instance_valid(_request_toast_icon):
				_ensure_request_toast_icon_node()
				_normalize_multiplayer_request_toast_text_layout()
				_update_multiplayer_request_toast_theme_colors()
				return

			_request_toast_panel.name = "BrokenMultiplayerRequestToast"
			_request_toast_panel.queue_free()
			_request_toast_panel = null
			_request_toast_title_label = null
			_request_toast_name_label = null
			_request_toast_status_label = null
			_request_toast_icon = null
	else:
		_request_toast_layer = CanvasLayer.new()
		_request_toast_layer.name = "UniversalMultiplayerRequestToastLayer"
		_request_toast_layer.layer = MULTIPLAYER_TOAST_LAYER
		_request_toast_layer.process_mode = Node.PROCESS_MODE_ALWAYS
		root_node.add_child(_request_toast_layer)

	_request_toast_panel = PanelContainer.new()
	_request_toast_panel.name = "MultiplayerRequestToast"
	_request_toast_panel.visible = false
	_request_toast_panel.modulate.a = 0.0
	_request_toast_panel.custom_minimum_size = Vector2(MULTIPLAYER_TOAST_WIDTH, MULTIPLAYER_TOAST_HEIGHT)
	_request_toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_request_toast_panel.z_index = 900
	_request_toast_panel.add_theme_stylebox_override("panel", _multiplayer_request_toast_panel_style())
	_request_toast_layer.add_child(_request_toast_panel)

	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	_request_toast_panel.add_child(margin)

	var row := HBoxContainer.new()
	row.name = "MultiplayerRequestToastRow"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 22)
	margin.add_child(row)

	_request_toast_icon = _create_multiplayer_request_toast_icon()
	row.add_child(_request_toast_icon)

	var text_box := VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text_box.alignment = BoxContainer.ALIGNMENT_CENTER
	text_box.add_theme_constant_override("separation", 0)
	row.add_child(text_box)

	_request_toast_title_label = Label.new()
	_request_toast_title_label.name = "RequestToastTitleLabel"
	_request_toast_title_label.text = "REQUEST SENT!"
	_request_toast_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_request_toast_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_request_toast_title_label.add_theme_font_size_override("font_size", 31)
	_request_toast_title_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.80))
	_apply_app_font(_request_toast_title_label)
	text_box.add_child(_request_toast_title_label)

	_request_toast_name_label = Label.new()
	_request_toast_name_label.name = "RequestToastNameLabel"
	_request_toast_name_label.text = "MULTIPLAYER"
	_request_toast_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_request_toast_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_request_toast_name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_request_toast_name_label.clip_text = true
	_request_toast_name_label.add_theme_font_size_override("font_size", 52)
	_request_toast_name_label.add_theme_color_override("font_color", Color.WHITE)
	_apply_app_font(_request_toast_name_label)
	text_box.add_child(_request_toast_name_label)

	_request_toast_status_label = Label.new()
	_request_toast_status_label.name = "RequestToastStatusLabel"
	_request_toast_status_label.text = "WAITING"
	_request_toast_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_request_toast_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_request_toast_status_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_request_toast_status_label.clip_text = true
	_request_toast_status_label.add_theme_font_size_override("font_size", 27)
	_request_toast_status_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.62))
	_apply_app_font(_request_toast_status_label)
	text_box.add_child(_request_toast_status_label)

	_normalize_multiplayer_request_toast_text_layout()
	_layout_multiplayer_request_toast(true)


func _normalize_multiplayer_request_toast_text_layout() -> void:
	if not is_instance_valid(_request_toast_panel):
		return

	# Reset transforms left behind by an older universal-toast instance. Only the
	# panel itself is allowed to scale during its entry animation.
	var row := _request_toast_panel.find_child("MultiplayerRequestToastRow", true, false) as Control
	if is_instance_valid(row):
		row.scale = Vector2.ONE
		row.modulate = Color.WHITE

	for label in [_request_toast_title_label, _request_toast_name_label, _request_toast_status_label]:
		if not is_instance_valid(label):
			continue
		label.scale = Vector2.ONE
		label.modulate = Color.WHITE
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		label.clip_text = true
		_apply_app_font(label)
		var parent_control := label.get_parent() as Control
		if is_instance_valid(parent_control):
			parent_control.scale = Vector2.ONE
			parent_control.modulate = Color.WHITE

	# Reapply the exact same responsive sizes used by the incoming request card.
	var width := _request_toast_panel.size.x
	if width <= 0.0:
		width = _multiplayer_pair_card_width(MULTIPLAYER_TOAST_WIDTH)
	_apply_multiplayer_request_card_responsive_fonts(width)


func _force_request_toast_icon_ready() -> void:
	_ensure_request_toast_icon_node()
	if not is_instance_valid(_request_toast_icon):
		return
	_request_toast_icon.custom_minimum_size = Vector2(MULTIPLAYER_TOAST_ICON_SIZE, MULTIPLAYER_TOAST_ICON_SIZE)
	_request_toast_icon.size = _request_toast_icon.custom_minimum_size
	_request_toast_icon.visible = true
	_request_toast_icon.modulate = Color.WHITE
	_request_toast_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_refresh_multiplayer_request_toast_icon_visual(_request_toast_icon)


func _show_multiplayer_request_toast(title: String, request_name: String, status: String, pending: bool) -> void:
	if not is_instance_valid(_request_toast_panel):
		_setup_multiplayer_request_toast()
	if is_instance_valid(_request_toast_panel) and not is_instance_valid(_request_toast_icon):
		_request_toast_panel.queue_free()
		_request_toast_panel = null
		_request_toast_title_label = null
		_request_toast_name_label = null
		_request_toast_status_label = null
		_request_toast_icon = null
		_setup_multiplayer_request_toast()
	if not is_instance_valid(_request_toast_panel):
		return

	_request_toast_generation += 1
	_request_toast_expire_generation += 1
	var local_generation: int = _request_toast_generation

	_request_toast_panel.set_meta("multiplayer_request_toast_active", true)
	_request_toast_panel.set_meta("multiplayer_request_toast_pending", pending)
	_request_toast_panel.set_meta("multiplayer_request_toast_generation", _request_toast_expire_generation)

	if is_instance_valid(_request_toast_title_label):
		_request_toast_title_label.text = title
	if is_instance_valid(_request_toast_name_label):
		_request_toast_name_label.text = request_name
		_request_toast_name_label.add_theme_color_override("font_color", Color.WHITE if pending else _get_theme_highlight_color())
	if is_instance_valid(_request_toast_status_label):
		_request_toast_status_label.text = status
	if is_instance_valid(_request_toast_icon):
		_request_toast_icon.set_meta("multiplayer_request_action", _multiplayer_request_action_from_title(request_name))
		_request_toast_icon.set_meta("multiplayer_request_use_highlight", pending)
		_force_request_toast_icon_ready()

	# The universal sender toast can survive popup rebuilds. Older instances could
	# keep a scaled text container even though the panel itself returned to 1.0,
	# making REQUEST SENT look noticeably smaller than NEW REQUEST. Normalize the
	# complete text branch every time before displaying it.
	_normalize_multiplayer_request_toast_text_layout()
	_update_multiplayer_request_toast_theme_colors()

	if pending:
		_start_multiplayer_request_waiting_dots(status)
	else:
		_stop_multiplayer_request_waiting_dots()

	if pending:
		_layout_multiplayer_request_toast(true)
		_start_multiplayer_request_toast_universal_expire_timer()
	else:
		_stop_multiplayer_request_toast_universal_expire_timer()
		_layout_multiplayer_request_toast(false)

	if _request_toast_tween != null and _request_toast_tween.is_valid():
		_request_toast_tween.kill()

	var in_position := _multiplayer_request_toast_in_position()
	var out_position := _multiplayer_request_toast_out_position()
	_request_toast_panel.visible = true

	if pending:
		_request_toast_panel.position = out_position
		_request_toast_panel.modulate.a = 0.0
		_request_toast_panel.scale = Vector2(0.982, 0.982)
	else:
		_request_toast_panel.position = in_position
		_request_toast_panel.modulate.a = 1.0
		_request_toast_panel.scale = Vector2.ONE

	if reduce_motion_enabled:
		_request_toast_panel.position = in_position
		_request_toast_panel.modulate.a = 1.0
		if not pending:
			var panel := _request_toast_panel
			var layer_node := _request_toast_layer
			var generation_at_hide: int = local_generation
			var timer := get_tree().create_timer(MULTIPLAYER_TOAST_RESOLVED_HOLD_TIME, true, false, true)
			timer.timeout.connect(func() -> void:
				if generation_at_hide != _request_toast_generation:
					return
				if is_instance_valid(panel):
					panel.visible = false
					panel.set_meta("multiplayer_request_toast_active", false)
				if is_instance_valid(layer_node):
					_queue_free_multiplayer_toast_layer_if_empty(layer_node)
			)
		return

	_request_toast_tween = _request_toast_layer.create_tween() if is_instance_valid(_request_toast_layer) else get_tree().create_tween()
	_request_toast_tween.set_trans(Tween.TRANS_CUBIC)
	_request_toast_tween.set_ease(Tween.EASE_OUT)
	if pending:
		_request_toast_tween.tween_property(_request_toast_panel, "position", in_position, MULTIPLAYER_TOAST_IN_TIME)
		_request_toast_tween.parallel().tween_property(_request_toast_panel, "scale", Vector2.ONE, MULTIPLAYER_TOAST_IN_TIME)
		_request_toast_tween.parallel().tween_property(_request_toast_panel, "modulate:a", 1.0, 0.30)
	else:
		_request_toast_tween.tween_interval(MULTIPLAYER_TOAST_RESOLVED_HOLD_TIME)
		_request_toast_tween.set_trans(Tween.TRANS_CUBIC)
		_request_toast_tween.set_ease(Tween.EASE_IN)
		_request_toast_tween.tween_property(_request_toast_panel, "position", out_position, MULTIPLAYER_TOAST_OUT_TIME)
		_request_toast_tween.parallel().tween_property(_request_toast_panel, "modulate:a", 0.0, MULTIPLAYER_TOAST_OUT_TIME)
		var panel := _request_toast_panel
		var layer_node := _request_toast_layer
		_request_toast_tween.finished.connect(func() -> void:
			if local_generation != _request_toast_generation:
				return
			if is_instance_valid(panel):
				panel.visible = false
				panel.scale = Vector2.ONE
				panel.set_meta("multiplayer_request_toast_active", false)
			_redraw_nearby_swipe_backgrounds()
			if is_instance_valid(layer_node):
				_queue_free_multiplayer_toast_layer_if_empty(layer_node)
		)

func _layout_multiplayer_request_toast(offscreen: bool = false) -> void:
	if not is_instance_valid(_request_toast_panel):
		return
	var size := _multiplayer_pair_card_size(MULTIPLAYER_TOAST_WIDTH, MULTIPLAYER_TOAST_HEIGHT)
	var width := size.x
	var height := size.y
	_request_toast_panel.size = size
	_request_toast_panel.custom_minimum_size = _request_toast_panel.size
	_request_toast_panel.pivot_offset = Vector2(width * 0.5, height * 0.5)
	_apply_multiplayer_request_card_responsive_fonts(width)
	_request_toast_panel.position = _multiplayer_request_toast_out_position() if offscreen else _multiplayer_request_toast_in_position()


func _multiplayer_request_toast_in_position() -> Vector2:
	var viewport_size: Vector2 = _multiplayer_request_toast_viewport_size()
	var width: float = _multiplayer_pair_card_width(MULTIPLAYER_TOAST_WIDTH)
	var x: float = max(19.0, viewport_size.x - width - MULTIPLAYER_TOAST_RIGHT_MARGIN)
	var y: float = MULTIPLAYER_TOAST_TOP_MARGIN
	return Vector2(x, y)


func _multiplayer_request_toast_out_position() -> Vector2:
	var viewport_size: Vector2 = _multiplayer_request_toast_viewport_size()
	return Vector2(viewport_size.x + 26.0, _multiplayer_request_toast_in_position().y)


func _multiplayer_request_toast_viewport_size() -> Vector2:
	if is_instance_valid(_root):
		var root_control := _root as Control
		if root_control != null:
			var root_rect: Rect2 = root_control.get_viewport_rect()
			if root_rect.size.x > 0.0 and root_rect.size.y > 0.0:
				return root_rect.size
	var viewport := get_viewport()
	if viewport != null:
		return viewport.get_visible_rect().size
	return Vector2(1080.0, 1920.0)


func _multiplayer_request_toast_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 1.0)
	style.border_color = Color(1.0, 1.0, 1.0, 0.92)
	style.set_border_width_all(5)
	style.set_corner_radius_all(28)
	return style


func _multiplayer_request_toast_safe_icon_color(use_highlight: bool) -> Color:
	var color := _get_theme_highlight_color() if use_highlight else Color.WHITE
	# During live theme rebuilds the highlight color can briefly be transparent or
	# too dark for a black toast. Do not let that make the icon disappear.
	if color.a < 0.72:
		color.a = 1.0
	var luminance := color.r * 0.299 + color.g * 0.587 + color.b * 0.114
	if luminance < 0.12:
		color = Color.WHITE
	return color


func _ensure_multiplayer_toast_icon_textures_loaded() -> void:
	if _planet_cards_icon == null:
		_planet_cards_icon = load(PLANET_CARDS_ICON_PATH) as Texture2D
	if _galaxy_console_icon == null:
		_galaxy_console_icon = load(GALAXY_CONSOLE_ICON_PATH) as Texture2D


func _multiplayer_request_toast_icon_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color.TRANSPARENT
	style.border_color = color
	style.set_border_width_all(5)
	style.set_corner_radius_all(int(MULTIPLAYER_TOAST_ICON_SIZE * 0.5))
	return style


func _create_multiplayer_request_toast_icon() -> Control:
	_ensure_multiplayer_toast_icon_textures_loaded()
	var icon := PanelContainer.new()
	icon.name = "MultiplayerRequestToastIcon"
	icon.custom_minimum_size = Vector2(MULTIPLAYER_TOAST_ICON_SIZE, MULTIPLAYER_TOAST_ICON_SIZE)
	icon.size = icon.custom_minimum_size
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.set_meta("multiplayer_request_action", "")
	icon.set_meta("multiplayer_request_use_highlight", true)
	icon.add_theme_stylebox_override("panel", _multiplayer_request_toast_icon_style(Color.WHITE))

	var margin := MarginContainer.new()
	margin.name = "MultiplayerRequestToastIconMargin"
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 27)
	margin.add_theme_constant_override("margin_right", 27)
	margin.add_theme_constant_override("margin_top", 27)
	margin.add_theme_constant_override("margin_bottom", 27)
	icon.add_child(margin)

	var texture_rect := TextureRect.new()
	texture_rect.name = "MultiplayerRequestToastIconTexture"
	texture_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_rect.texture = _galaxy_console_icon
	texture_rect.modulate = Color.WHITE
	margin.add_child(texture_rect)

	_refresh_multiplayer_request_toast_icon_visual(icon)
	return icon


func _ensure_request_toast_icon_node() -> void:
	if not is_instance_valid(_request_toast_panel):
		return
	var needs_rebuild := false
	if not is_instance_valid(_request_toast_icon):
		needs_rebuild = true
	elif _request_toast_icon.find_child("MultiplayerRequestToastIconTexture", true, false) == null:
		needs_rebuild = true

	if not needs_rebuild:
		return

	var old_icon := _request_toast_icon
	var parent_node: Node = null
	var insert_index := 0
	if is_instance_valid(old_icon):
		parent_node = old_icon.get_parent()
		insert_index = old_icon.get_index()
	else:
		parent_node = _request_toast_panel.find_child("MultiplayerRequestToastRow", true, false)

	if parent_node == null:
		return

	var new_icon := _create_multiplayer_request_toast_icon()
	parent_node.add_child(new_icon)
	parent_node.move_child(new_icon, insert_index)
	if is_instance_valid(old_icon):
		old_icon.queue_free()
	_request_toast_icon = new_icon


func _refresh_multiplayer_request_toast_icon_visual(icon_node: Control) -> void:
	if not is_instance_valid(icon_node):
		return
	_ensure_multiplayer_toast_icon_textures_loaded()
	var action := str(icon_node.get_meta("multiplayer_request_action", "")).strip_edges().to_lower()
	var use_highlight := bool(icon_node.get_meta("multiplayer_request_use_highlight", true))
	var color := _multiplayer_request_toast_safe_icon_color(use_highlight)
	icon_node.custom_minimum_size = Vector2(MULTIPLAYER_TOAST_ICON_SIZE, MULTIPLAYER_TOAST_ICON_SIZE)
	icon_node.size = icon_node.custom_minimum_size
	icon_node.visible = true
	icon_node.modulate = Color.WHITE
	var icon_panel := icon_node as PanelContainer
	if icon_panel != null:
		icon_panel.add_theme_stylebox_override("panel", _multiplayer_request_toast_icon_style(color))

	var texture_rect := icon_node.find_child("MultiplayerRequestToastIconTexture", true, false) as TextureRect
	if texture_rect == null:
		return
	texture_rect.texture = _planet_cards_icon if action == "trade" else _galaxy_console_icon
	texture_rect.modulate = color
	texture_rect.visible = texture_rect.texture != null


func _draw_multiplayer_request_toast_action_icon(_target: Control, _icon_color: Color) -> void:
	# Kept only for old signal compatibility if an already-open toast from a previous build exists.
	# New toasts use TextureRect children with cached textures, not fallback drawing.
	return

func _create_nearby_player_icon() -> Control:
	var icon := Control.new()
	icon.custom_minimum_size = Vector2(74, 74)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.draw.connect(func() -> void:
		var color := COLOR_TEXT
		var width := 6.0
		var center := icon.size * 0.5
		icon.draw_arc(center + Vector2(0, -11), 13.0, 0.0, TAU, 48, color, width, true)
		icon.draw_arc(center + Vector2(0, 25), 23.0, PI, TAU, 48, color, width, true)
	)
	return icon


func _nearby_player_subtitle(player: Dictionary) -> String:
	var distance_value: Variant = player.get("distanceMeters", -1)
	var distance := -1.0

	var distance_type := typeof(distance_value)
	if distance_type == TYPE_INT or distance_type == TYPE_FLOAT:
		distance = float(distance_value)
	elif str(distance_value).is_valid_float():
		distance = float(str(distance_value))

	if distance >= 0.0:
		if distance >= 1000.0:
			return "NEARBY • %.1f KM" % (distance / 1000.0)
		return "NEARBY • %d M" % int(round(distance))

	return "NEARBY • 0 M"


func _load_nearby_players() -> void:
	# BLE pushes changes through nearby_players_changed. This method now only ensures
	# discovery is active and never performs a repeating backend/Firebase request.
	if _sync_mode_active:
		_update_nearby_players_ui()
		return
	if not _button_toggled:
		_set_nearby_players([])
		return
	_start_nearby_refresh()


func _dummy_nearby_players() -> Array:
	return [
		{
			"uid": "dummy_orion",
			"displayName": "Orion Runner",
			"distanceMeters": 18,
		},
		{
			"uid": "dummy_nova",
			"displayName": "Nova Crafter",
			"distanceMeters": 41,
		},
		{
			"uid": "dummy_aster",
			"displayName": "Aster Pilot",
			"distanceMeters": 76,
		},
		{
			"uid": "dummy_luna",
			"displayName": "Luna Builder",
			"distanceMeters": 132,
		},
	]


func _limit_multiplayer_display_name(value: String) -> String:
	if USERNAME_MAX_CHARS <= 0 or value.length() <= USERNAME_MAX_CHARS:
		return value
	return value.substr(0, USERNAME_MAX_CHARS)


func _nearby_player_name_font_size(value: String) -> int:
	var length := value.strip_edges().length()
	if length <= 10:
		return 60
	if length <= 13:
		return 53
	return 46


func _enforce_username_character_limit() -> void:
	if not is_instance_valid(_username_box):
		return
	if USERNAME_MAX_CHARS <= 0:
		return
	if _username_box.text.length() <= USERNAME_MAX_CHARS:
		return
	var caret := _username_box.caret_column
	_username_box.text = _username_box.text.substr(0, USERNAME_MAX_CHARS)
	_username_box.caret_column = min(caret, USERNAME_MAX_CHARS)


func _update_username_clear_button() -> void:
	if not is_instance_valid(_username_clear_button) or not is_instance_valid(_username_box):
		return
	_username_clear_button.visible = not _username_box.text.strip_edges().is_empty()


func _clear_username() -> void:
	if not is_instance_valid(_username_box):
		return
	_username_box.text = ""
	_username_box.grab_focus()
	_update_username_clear_button()
	_save_public_display_name(true)


func _release_username_focus() -> void:
	if not is_instance_valid(_username_box):
		return

	if _username_box.has_focus():
		_username_box.release_focus()

	if OS.has_feature("mobile"):
		DisplayServer.virtual_keyboard_hide()


func _create_user_icon() -> Control:
	var center_wrap := CenterContainer.new()
	center_wrap.custom_minimum_size = Vector2(92, 120)
	center_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var icon := Control.new()
	icon.custom_minimum_size = Vector2(76, 76)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.draw.connect(func() -> void:
		var color := Color.WHITE
		var width := 7.0
		icon.draw_arc(Vector2(38, 28), 15.0, 0.0, TAU, 64, color, width, true)
		icon.draw_arc(Vector2(38, 69), 24.0, PI, TAU, 64, color, width, true)
	)

	center_wrap.add_child(icon)
	return center_wrap


func _create_username_clear_button() -> Control:
	var button := Control.new()
	button.name = "UsernameClearButton"
	button.custom_minimum_size = Vector2(92, 120)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.visible = false
	button.draw.connect(func() -> void:
		var center := button.size * 0.5
		var half_size := 21.0
		var width := 7.0
		button.draw_line(center + Vector2(-half_size, -half_size), center + Vector2(half_size, half_size), COLOR_TEXT, width, true)
		button.draw_line(center + Vector2(half_size, -half_size), center + Vector2(-half_size, half_size), COLOR_TEXT, width, true)
	)
	button.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventScreenTouch and event.pressed:
			_clear_username()
			get_viewport().set_input_as_handled()
		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_clear_username()
			get_viewport().set_input_as_handled()
	)
	return button


func _draw_multiplayer_button_icon(target: Control, icon_color: Color) -> void:
	var center := target.size * 0.5
	var icon_size := target.size.y * 0.48

	if _multiplayer_icon != null:
		var texture_size := _multiplayer_icon.get_size()
		if texture_size.x > 0.0 and texture_size.y > 0.0:
			var scale_factor: float = min(icon_size / texture_size.x, icon_size / texture_size.y)
			var draw_size := texture_size * scale_factor
			var draw_rect := Rect2(center - draw_size * 0.5, draw_size)
			target.draw_texture_rect(_multiplayer_icon, draw_rect, false, icon_color)
			return

	var width := target.size.y * 0.055
	var r := target.size.y * 0.09
	var offset := target.size.y * 0.18
	target.draw_arc(center + Vector2(-offset, -offset * 0.25), r, 0.0, TAU, 48, icon_color, width, true)
	target.draw_arc(center + Vector2(offset, -offset * 0.25), r, 0.0, TAU, 48, icon_color, width, true)
	target.draw_arc(center + Vector2(0, offset * 0.65), r, 0.0, TAU, 48, icon_color, width, true)
	target.draw_line(center + Vector2(-offset + r, -offset * 0.18), center + Vector2(-r * 0.45, offset * 0.5), icon_color, width, true)
	target.draw_line(center + Vector2(offset - r, -offset * 0.18), center + Vector2(r * 0.45, offset * 0.5), icon_color, width, true)
	target.draw_line(center + Vector2(-offset + r, -offset * 0.25), center + Vector2(offset - r, -offset * 0.25), icon_color, width, true)


func _draw_sync_exit_button_icon(target: Control, icon_color: Color) -> void:
	var center := target.size * 0.5
	var half_size := target.size.y * 0.19
	var width := target.size.y * 0.06
	target.draw_line(center + Vector2(-half_size, -half_size), center + Vector2(half_size, half_size), icon_color, width, true)
	target.draw_line(center + Vector2(half_size, -half_size), center + Vector2(-half_size, half_size), icon_color, width, true)


func _apply_app_font(control: Control) -> void:
	if _app_font != null:
		control.add_theme_font_override("font", _app_font)


func _start_button_press() -> void:
	if not is_instance_valid(_connect_button):
		return

	_button_pressed = true
	_connect_button.queue_redraw()
	if not reduce_motion_enabled:
		_bounce_button_down()


func _finish_button_press(screen_position: Vector2) -> void:
	if not is_instance_valid(_connect_button):
		return

	var released_inside := _connect_button.get_global_rect().has_point(screen_position)
	_button_pressed = false
	_connect_button.queue_redraw()

	if released_inside:
		if not reduce_motion_enabled:
			_bounce_button_release()
		_press_multiplayer_button()
	else:
		if not reduce_motion_enabled:
			_bounce_button_cancel()


func _press_multiplayer_button(_force_on: bool = false) -> void:
	if not _is_online_mode_available() or not _is_bluetooth_enabled():
		_play_sfx("error")
		_button_toggled = false
		_update_nearby_players_ui()
		_animate_button_toggle_state()
		return
	_save_public_display_name(true)
	if _sync_mode_active:
		_exit_multiplayer_sync_ui()
		return
	_set_location_enabled(not _button_toggled)


func _bounce_button_down() -> void:
	if not is_instance_valid(_connect_button):
		return

	if _button_bounce_tween != null and _button_bounce_tween.is_valid():
		_button_bounce_tween.kill()

	_connect_button.pivot_offset = _connect_button.size * 0.5
	_button_bounce_tween = create_tween()
	_button_bounce_tween.set_trans(Tween.TRANS_BACK)
	_button_bounce_tween.set_ease(Tween.EASE_OUT)
	_button_bounce_tween.tween_property(_connect_button, "scale", BUTTON_PRESS_SCALE, BUTTON_DOWN_TIME)


func _bounce_button_release() -> void:
	if not is_instance_valid(_connect_button):
		return

	if _button_bounce_tween != null and _button_bounce_tween.is_valid():
		_button_bounce_tween.kill()

	_connect_button.pivot_offset = _connect_button.size * 0.5
	_button_bounce_tween = create_tween()
	_button_bounce_tween.set_trans(Tween.TRANS_BACK)
	_button_bounce_tween.set_ease(Tween.EASE_OUT)
	_button_bounce_tween.tween_property(_connect_button, "scale", BUTTON_RELEASE_SCALE, BUTTON_UP_TIME)
	_button_bounce_tween.tween_property(_connect_button, "scale", Vector2.ONE, BUTTON_SETTLE_TIME)


func _bounce_button_cancel() -> void:
	if not is_instance_valid(_connect_button):
		return

	if _button_bounce_tween != null and _button_bounce_tween.is_valid():
		_button_bounce_tween.kill()

	_connect_button.pivot_offset = _connect_button.size * 0.5
	_button_bounce_tween = create_tween()
	_button_bounce_tween.set_trans(Tween.TRANS_BACK)
	_button_bounce_tween.set_ease(Tween.EASE_OUT)
	_button_bounce_tween.tween_property(_connect_button, "scale", Vector2.ONE, BUTTON_SETTLE_TIME)


func _animate_button_toggle_state() -> void:
	var target := 0.0 if _button_toggled else 1.0

	if is_equal_approx(_button_highlight_blend, target):
		_update_button_visual()
		return

	if _button_color_tween != null and _button_color_tween.is_valid():
		_button_color_tween.kill()

	if reduce_motion_enabled:
		_button_highlight_blend = target
		_update_button_visual()
		return

	_button_color_tween = create_tween()
	_button_color_tween.set_trans(Tween.TRANS_SINE)
	_button_color_tween.set_ease(Tween.EASE_OUT)
	_button_color_tween.tween_method(
		func(value: float) -> void:
			_button_highlight_blend = value
			_update_button_visual(),
		_button_highlight_blend,
		target,
		BUTTON_COLOR_TWEEN_TIME
	)


func _update_button_visual() -> void:
	if is_instance_valid(_connect_button):
		_connect_button.queue_redraw()


func _set_button_highlight_blend(value: float) -> void:
	_button_highlight_blend = clamp(value, 0.0, 1.0)
	_update_button_visual()



func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_PANEL
	style.border_color = COLOR_BORDER
	style.set_border_width_all(5)
	style.set_corner_radius_all(44)
	style.shadow_color = Color(0, 0, 0, 0.64)
	style.shadow_size = 16
	style.shadow_offset = Vector2(0, 6)
	return style


func _search_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color.TRANSPARENT
	style.border_color = COLOR_BORDER
	style.set_border_width_all(6)
	style.set_corner_radius_all(38)
	return style


func _square_button_style(_pressed: bool = false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	var highlight := _get_theme_highlight_color()
	style.bg_color = Color.TRANSPARENT
	style.border_color = COLOR_BORDER.lerp(highlight, _button_highlight_blend)
	style.set_border_width_all(6)
	style.set_corner_radius_all(38)
	style.content_margin_left = 0
	style.content_margin_right = 0
	style.content_margin_top = 0
	style.content_margin_bottom = 0
	return style


func _nearby_player_row_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color.BLACK
	style.border_color = COLOR_BORDER
	style.set_border_width_all(5)
	style.set_corner_radius_all(34)
	return style


func _scroll_bar_track_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()

	style.bg_color = COLOR_SCROLL_TRACK
	style.border_color = Color.TRANSPARENT
	style.set_border_width_all(0)
	style.set_corner_radius_all(999)

	style.content_margin_left = 5
	style.content_margin_right = 5
	style.content_margin_top = 8
	style.content_margin_bottom = 8

	return style


func _scroll_bar_grabber_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()

	style.bg_color = color
	style.border_color = Color.TRANSPARENT
	style.set_border_width_all(0)
	style.set_corner_radius_all(999)

	style.content_margin_left = 3
	style.content_margin_right = 3
	style.content_margin_top = 3
	style.content_margin_bottom = 3

	return style


func _transparent_line_edit_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color.TRANSPARENT
	style.border_color = Color.TRANSPARENT
	style.set_border_width_all(0)
	style.content_margin_left = 0
	style.content_margin_right = 0
	style.content_margin_top = 0
	style.content_margin_bottom = 0
	return style


func _connect_settings_signal() -> void:
	if _settings_node == null:
		_settings_node = get_node_or_null("/root/UnilearnUserSettings")

	if _settings_node == null:
		return

	if not _settings_node.has_signal("settings_changed"):
		return

	var callable := Callable(self, "_on_settings_changed")
	if not _settings_node.settings_changed.is_connected(callable):
		_settings_node.settings_changed.connect(callable)


func _on_settings_changed() -> void:
	if not is_inside_tree() or _closing:
		return

	_sync_reduce_motion_from_settings()
	var online_now := _is_online_mode_available()
	if online_now != _last_online_mode_available:
		_last_online_mode_available = online_now
		_apply_live_connectivity_state()
	_update_nearby_dynamic_theme_colors(true)
	_update_multiplayer_request_toast_theme_colors()

	# This popup uses custom-drawn controls, so force a redraw immediately when
	# Apollo/settings changes the theme at response start. Do not rebuild cards.
	if is_instance_valid(_panel):
		_panel.add_theme_stylebox_override("panel", _panel_style())
		_panel.queue_redraw()
	if is_instance_valid(_connect_button):
		_connect_button.queue_redraw()
	if is_instance_valid(_nearby_scroll):
		_style_nearby_scroll_bar()
	if is_instance_valid(_nearby_list):
		_nearby_list.queue_redraw()

	call_deferred("_update_nearby_dynamic_theme_colors", true)


func _apply_live_connectivity_state() -> void:
	if _is_online_mode_available():
		_save_public_display_name(true)
		_update_nearby_players_ui()
		return
	if _button_toggled:
		_button_toggled = false
		_deny_multiplayer_requests_for_location_disable()
		_stop_nearby_refresh()
		_set_nearby_players([])
	if is_instance_valid(_nearby_empty_label):
		_nearby_empty_label.text = "NO INTERNET"
	_update_nearby_players_ui()
	_animate_button_toggle_state()


func _sync_reduce_motion_from_settings() -> void:
	if _settings_node == null:
		_settings_node = get_node_or_null("/root/UnilearnUserSettings")

	if _settings_node == null:
		return

	if "reduce_motion_enabled" in _settings_node:
		reduce_motion_enabled = bool(_settings_node.reduce_motion_enabled)


func _get_theme_highlight_color() -> Color:
	if _settings_node == null:
		_settings_node = get_node_or_null("/root/UnilearnUserSettings")

	if _settings_node != null:
		if _settings_node.has_method("get_accent_color"):
			var accent_value: Variant = _settings_node.call("get_accent_color")
			if accent_value is Color:
				return accent_value

		if _settings_node.has_method("get_text_highlighted_color"):
			var text_value: Variant = _settings_node.call("get_text_highlighted_color")
			if text_value is Color:
				return text_value

		for property_name in ["text_highlighted_color", "textHighlightedColor", "highlighted_text_color", "highlightedTextColor", "text_highlight_color", "textHighlightColor", "highlight_color", "highlightColor", "accent_color", "accentColor"]:
			var value: Variant = _settings_node.get(property_name)
			if value is Color:
				return value

	return COLOR_STATUS


func _process(_delta: float) -> void:
	_update_nearby_dynamic_theme_colors(false)


func _update_nearby_dynamic_theme_colors(force: bool = false) -> void:
	var highlight := _get_theme_highlight_color()
	if not force and highlight.is_equal_approx(_nearby_theme_color_last):
		return
	_nearby_theme_color_last = highlight
	_apply_nearby_dynamic_theme_to_tree(self, highlight)
	_update_button_visual()


func _apply_nearby_dynamic_theme_to_tree(node: Node, highlight: Color) -> void:
	if node == null:
		return
	if node is Label and node.has_meta("dynamic_highlight_color"):
		(node as Label).add_theme_color_override("font_color", highlight)
	if node is Control and node.has_meta("dynamic_highlight_redraw"):
		(node as Control).queue_redraw()
	for child in node.get_children():
		_apply_nearby_dynamic_theme_to_tree(child, highlight)


func _play_sfx(id: String) -> void:
	if _sfx_node != null and _sfx_node.has_method("play"):
		_sfx_node.call("play", id)


func _sync_multiplayer_local_state() -> void:
	_sync_multiplayer_mode_from_owner()
	if _settings_node == null:
		_settings_node = get_node_or_null("/root/UnilearnUserSettings")
	_last_online_mode_available = _is_online_mode_available()

	var local_name := ""
	if _settings_node != null:
		if _settings_node.has_method("get_display_name"):
			local_name = str(_settings_node.call("get_display_name")).strip_edges()
		elif "display_name" in _settings_node:
			local_name = str(_settings_node.display_name).strip_edges()

	if is_instance_valid(_username_box):
		_username_box.text = _limit_multiplayer_display_name(local_name)
		if _is_online_mode_available():
			_last_saved_display_name = _username_box.text
		_update_username_clear_button()

	_button_toggled = _is_location_enabled_locally()
	_set_button_highlight_blend(0.0 if _button_toggled else 1.0)
	if _button_toggled:
		_show_nearby_loading_state()
		_start_nearby_refresh()
		_load_nearby_players()
	else:
		_update_nearby_players_ui()
		_stop_nearby_refresh()

	if _is_online_mode_available():
		_pull_display_name_from_backend()


func _sync_multiplayer_mode_from_owner() -> void:
	var owner := _find_multiplayer_sync_owner()
	if owner != null and owner.has_method("is_multiplayer_sync_active") and bool(owner.call("is_multiplayer_sync_active")):
		_sync_mode_active = true
		if owner.has_method("get_multiplayer_sync_peer"):
			var peer: Variant = owner.call("get_multiplayer_sync_peer")
			_sync_player = peer if peer is Dictionary else {}
		if _sync_player.is_empty():
			_sync_player = {"displayName": "PLAYER", "uid": "", "syncActive": true}
		_sync_player["syncActive"] = true
	else:
		_sync_mode_active = false
		_sync_player = {}


func _find_multiplayer_sync_owner() -> Node:
	var node := get_parent()
	while node != null:
		if node.has_method("is_multiplayer_sync_active") or node.has_method("set_multiplayer_sync_active"):
			return node
		node = node.get_parent()
	var bottom_menu := _find_multiplayer_bottom_menu_node()
	if bottom_menu != null:
		return bottom_menu
	return null


func remote_multiplayer_sync_closed() -> void:
	if not _sync_mode_active:
		_sync_multiplayer_mode_from_owner()
	_sync_mode_active = false
	_sync_player = {}
	_reset_cached_nearby_swipe_cards_after_sync()
	_play_sfx("toggle")
	_animate_button_toggle_state()
	_sync_multiplayer_local_state()
	call_deferred("_restart_nearby_discovery_after_sync")


func _exit_multiplayer_sync_ui() -> void:
	var owner := _find_multiplayer_sync_owner()
	if owner != null and owner.has_method("stop_multiplayer_sync_ui"):
		owner.call("stop_multiplayer_sync_ui")
	elif owner != null and owner.has_method("set_multiplayer_sync_active"):
		owner.call("set_multiplayer_sync_active", false)
	_sync_mode_active = false
	_sync_player = {}
	_reset_cached_nearby_swipe_cards_after_sync()
	# Rebuild immediately from the normal nearby cache so recycled sync rows cannot stay
	# on screen while the real nearby refresh is loading.
	if _button_toggled and not _nearby_players.is_empty():
		_update_nearby_players_ui()
	_play_sfx("toggle")
	_animate_button_toggle_state()
	_sync_multiplayer_local_state()
	call_deferred("_restart_nearby_discovery_after_sync")


func _restart_nearby_discovery_after_sync() -> void:
	if _closing or not _button_toggled or _ble_plugin == null:
		return

	# A completed universe sync may leave Android BLE advertising/scanning alive with
	# the exact same cached snapshot. Restart both sides so each phone advertises and
	# discovers again instead of waiting forever for a changed native payload.
	if _ble_discovery_running:
		_ble_plugin.call("stopDiscovery")
	_ble_discovery_running = false
	_ble_last_players_json = ""
	_ble_latest_players_by_uid.clear()
	_ble_known_players_by_uid.clear()
	_ble_stable_players_by_uid.clear()
	_ble_pending_players_by_uid.clear()
	_ble_sync_request_in_flight.clear()
	_ble_sync_reveal_generation.clear()
	_ble_sync_reveal_at_by_uid.clear()
	_ble_peer_explicit_leave_at_by_uid.clear()
	_ble_player_removal_generation.clear()
	_set_nearby_players([])
	_show_nearby_loading_state(false)

	# Give Android one rendered frame to unregister the previous advertiser before
	# registering the new one. Both phones execute this same path after sync closes.
	await get_tree().process_frame
	if _closing or not _button_toggled:
		return
	_start_nearby_refresh()
	await get_tree().process_frame
	_on_nearby_sync_heartbeat()


func _reset_cached_nearby_swipe_cards_after_sync() -> void:
	# Do not recycle the locked sync row back into the normal nearby list.
	# Reusing it is exactly what kept SYNC ACTIVE / NEARBY • -- M stuck on real players.
	for card_key in _nearby_cards_by_uid.keys():
		var cached_card = _nearby_cards_by_uid.get(card_key, null)
		if is_instance_valid(cached_card):
			cached_card.queue_free()
	_nearby_cards_by_uid.clear()
	_nearby_card_swipe_lock = false

func _is_location_enabled_locally() -> bool:
	if _settings_node == null:
		_settings_node = get_node_or_null("/root/UnilearnUserSettings")
	if _settings_node == null or not ("location_enabled" in _settings_node):
		return false

	var enabled := bool(_settings_node.location_enabled) and _is_location_permission_granted() and _is_bluetooth_enabled() and _is_online_mode_available()
	if not enabled and bool(_settings_node.location_enabled) and _settings_node.has_method("set_location_enabled"):
		_settings_node.call("set_location_enabled", false)
	return enabled


func _set_location_enabled(value: bool) -> void:
	if _sync_mode_active:
		return
	if value and (not _is_online_mode_available() or not _is_bluetooth_enabled()):
		_button_toggled = false
		_play_sfx("error")
		_update_nearby_players_ui()
		_animate_button_toggle_state()
		return
	if value and not _is_location_permission_granted():
		_begin_location_permission_request()
		return

	var final_value := value and _is_location_permission_granted() and _is_bluetooth_enabled() and _is_online_mode_available()
	if _settings_node == null:
		_settings_node = get_node_or_null("/root/UnilearnUserSettings")
	if _settings_node != null and _settings_node.has_method("set_location_enabled"):
		_settings_node.call("set_location_enabled", final_value)

	_button_toggled = final_value
	if not _button_toggled:
		_deny_multiplayer_requests_for_location_disable()
		_stop_nearby_refresh()
		_set_nearby_players([])
	else:
		_show_nearby_loading_state()
		_start_nearby_refresh()
	_play_sfx("success" if _button_toggled else "toggle")
	_animate_button_toggle_state()


func _deny_multiplayer_requests_for_location_disable() -> void:
	# End the local UI immediately, then notify the server so the other phone
	# receives the same denial on its next 120 ms request poll.
	if _multiplayer_request_pending:
		_resolve_multiplayer_pending_request(false, "LOCATION DISABLED")
	if _incoming_request_active:
		_finish_incoming_multiplayer_request(false)

	var database := get_node_or_null("/root/FirebaseDatabase")
	if database != null and database.has_method("cancel_active_multiplayer_requests"):
		database.call_deferred("cancel_active_multiplayer_requests", "location_disabled")


func _begin_location_permission_request() -> void:
	if _ble_permission_flow_running:
		return
	_ble_permission_flow_running = true
	_request_location_permission()

	await get_tree().process_frame
	var attempts := 0
	while attempts < 80 and not _is_location_permission_granted():
		attempts += 1
		await get_tree().create_timer(0.25).timeout
	_ble_permission_flow_running = false

	if not is_inside_tree() or _closing:
		return
	_set_location_enabled(_is_location_permission_granted())


func _is_location_permission_granted() -> bool:
	# The button keeps its existing UI name, but on Android 12+ this checks the
	# Nearby devices Bluetooth permission group, not phone location.
	if OS.get_name() != "Android":
		return true
	if _ble_plugin != null:
		return bool(_ble_plugin.call("hasPermissions"))
	if Engine.has_singleton("UnilearnBLE"):
		_ble_plugin = Engine.get_singleton("UnilearnBLE")
		return bool(_ble_plugin.call("hasPermissions"))
	return false


func _is_online_mode_available() -> bool:
	if _settings_node == null:
		_settings_node = get_node_or_null("/root/UnilearnUserSettings")
	return _settings_node != null and _settings_node.has_method("is_online_mode_available") and bool(_settings_node.call("is_online_mode_available"))


func _is_bluetooth_enabled() -> bool:
	if OS.get_name() != "Android":
		return true
	if _ble_plugin == null and Engine.has_singleton("UnilearnBLE"):
		_ble_plugin = Engine.get_singleton("UnilearnBLE")
	return _ble_plugin != null and bool(_ble_plugin.call("isBluetoothEnabled"))


func _request_location_permission() -> void:
	if OS.get_name() != "Android":
		return
	if _ble_plugin == null and Engine.has_singleton("UnilearnBLE"):
		_ble_plugin = Engine.get_singleton("UnilearnBLE")
	if _ble_plugin == null:
		push_warning("UnilearnBLE plugin is unavailable.")
		return

	if not bool(_ble_plugin.call("isBluetoothEnabled")):
		_ble_plugin.call("requestEnableBluetooth")
	_ble_plugin.call("requestPermissions")


func _save_public_display_name_locally() -> void:
	if not is_instance_valid(_username_box):
		return

	var value := _limit_multiplayer_display_name(_username_box.text)

	if _username_box.text != value:
		_username_box.text = value

	if _settings_node == null:
		_settings_node = get_node_or_null("/root/UnilearnUserSettings")

	if _settings_node != null and _settings_node.has_method("set_display_name"):
		_settings_node.call("set_display_name", value)

	if _ble_plugin != null and _ble_discovery_running:
		_ble_plugin.call("updateIdentity", value)


func _save_public_display_name(sync_backend: bool = false) -> void:
	if not is_instance_valid(_username_box):
		return

	var value := _limit_multiplayer_display_name(_username_box.text)
	if _username_box.text != value:
		_username_box.text = value
	_save_public_display_name_locally()
	_update_username_clear_button()

	if sync_backend and _is_online_mode_available() and value != _last_saved_display_name:
		_last_saved_display_name = value
		_save_public_display_name_to_backend(value)


func _save_public_display_name_to_backend(value: String) -> void:
	if not _is_online_mode_available():
		return
	var database := get_node_or_null("/root/FirebaseDatabase")
	if database == null or not database.has_method("save_user_display_name"):
		return

	var result: Dictionary = await database.call("save_user_display_name", value)
	if not bool(result.get("success", false)):
		push_warning("Failed to save multiplayer displayName: %s" % str(result))


func _pull_display_name_from_backend() -> void:
	if not _is_online_mode_available():
		return
	var database := get_node_or_null("/root/FirebaseDatabase")
	if database == null or not database.has_method("get_user_profile"):
		return

	var result: Dictionary = await database.call("get_user_profile")
	if not bool(result.get("success", false)):
		return

	var raw_user: Variant = result.get("user", {})
	var user: Dictionary = raw_user if raw_user is Dictionary else {}
	var backend_name := str(user.get("displayName", "")).strip_edges()

	if not is_instance_valid(_username_box):
		return

	if _username_box.text.strip_edges() == "" and backend_name != "":
		_username_box.text = _limit_multiplayer_display_name(backend_name)
		_last_saved_display_name = _username_box.text
		_save_public_display_name_locally()
		_update_username_clear_button()
