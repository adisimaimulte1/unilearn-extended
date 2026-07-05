extends "res://app/ui/popups/multiplayer_popup/MultiplayerPopupBase.gd"

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
	_nearby_list.add_theme_constant_override("separation", 24)
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

	stack.resized.connect(func() -> void:
		_update_nearby_empty_label_height()
	)

	call_deferred("_style_nearby_scroll_bar")
	call_deferred("_update_nearby_empty_label_height")


func _setup_nearby_refresh_timer() -> void:
	_nearby_refresh_timer = Timer.new()
	_nearby_refresh_timer.name = "NearbyPlayersRefreshTimer"
	_nearby_refresh_timer.wait_time = 5.0
	_nearby_refresh_timer.one_shot = false
	_nearby_refresh_timer.autostart = false
	_nearby_refresh_timer.process_mode = Node.PROCESS_MODE_ALWAYS
	_nearby_refresh_timer.timeout.connect(func() -> void:
		if _button_toggled and not _closing:
			_load_nearby_players()
	)
	add_child(_nearby_refresh_timer)


func _start_nearby_refresh() -> void:
	if is_instance_valid(_nearby_refresh_timer) and _nearby_refresh_timer.is_stopped():
		_nearby_refresh_timer.start()


func _stop_nearby_refresh() -> void:
	if is_instance_valid(_nearby_refresh_timer):
		_nearby_refresh_timer.stop()


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
		var display_name := str(player.get("displayName", player.get("username", player.get("name", "")))).strip_edges()
		var uid := str(player.get("uid", player.get("id", ""))).strip_edges()

		if display_name.is_empty():
			display_name = "PLAYER"

		_nearby_players.append({
			"uid": uid,
			"displayName": display_name,
			"distanceMeters": player.get("distanceMeters", player.get("distance", -1)),
		})

	_update_nearby_players_ui()


func _update_nearby_players_ui() -> void:
	if not is_instance_valid(_nearby_list) or not is_instance_valid(_nearby_empty_label):
		return

	for child in _nearby_list.get_children():
		child.queue_free()

	if not _button_toggled:
		if is_instance_valid(_nearby_scroll):
			_nearby_scroll.visible = false
		_nearby_list.visible = false
		_nearby_empty_label.visible = true
		_nearby_empty_label.text = "ENABLE LOCATION"
		_update_nearby_empty_label_height()
		return

	if _nearby_players.is_empty():
		if is_instance_valid(_nearby_scroll):
			_nearby_scroll.visible = false
		_nearby_list.visible = false
		_nearby_empty_label.visible = true
		_nearby_empty_label.text = "NO PLAYER NEARBY"
		_update_nearby_empty_label_height()
		return

	if is_instance_valid(_nearby_scroll):
		_nearby_scroll.visible = true
	_nearby_empty_label.visible = false
	_nearby_list.visible = true

	for player in _nearby_players:
		_nearby_list.add_child(_create_nearby_player_row(player))

	call_deferred("_style_nearby_scroll_bar")


func _create_nearby_player_row(player: Dictionary) -> Control:
	var shell := PanelContainer.new()
	shell.name = "NearbyPlayerRow"
	shell.custom_minimum_size = Vector2(0, 132)
	shell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shell.mouse_filter = Control.MOUSE_FILTER_STOP
	shell.add_theme_stylebox_override("panel", _nearby_player_row_style())

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	shell.add_child(margin)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 22)
	margin.add_child(row)

	row.add_child(_create_nearby_player_icon())

	var text_box := VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	text_box.add_theme_constant_override("separation", 0)
	row.add_child(text_box)

	var name_label := Label.new()
	name_label.text = str(player.get("displayName", "PLAYER")).strip_edges().to_upper()
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.clip_text = true
	name_label.add_theme_font_size_override("font_size", 58)
	name_label.add_theme_color_override("font_color", COLOR_TEXT)
	_apply_app_font(name_label)
	text_box.add_child(name_label)

	var status_label := Label.new()
	status_label.text = _nearby_player_subtitle(player)
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status_label.clip_text = true
	status_label.add_theme_font_size_override("font_size", 34)
	status_label.add_theme_color_override("font_color", COLOR_SUBTITLE)
	_apply_app_font(status_label)
	text_box.add_child(status_label)

	return shell


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

	return "NEARBY PLAYER"


func _load_nearby_players() -> void:
	_nearby_load_generation += 1
	var local_generation := _nearby_load_generation

	if not _button_toggled:
		_set_nearby_players([])
		return

	var database := get_node_or_null("/root/FirebaseDatabase")
	if database == null or not database.has_method("get_nearby_multiplayer_players"):
		_set_nearby_players([])
		return

	var result: Dictionary = await database.call("get_nearby_multiplayer_players")
	if local_generation != _nearby_load_generation or _closing:
		return

	if not bool(result.get("success", false)):
		_set_nearby_players([])
		return

	var raw_players: Variant = result.get("players", [])
	if raw_players is Array:
		_set_nearby_players(raw_players)
	else:
		_set_nearby_players([])


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
	_save_public_display_name(true)
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
	var target := 1.0 if _button_toggled else 0.0

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
	style.bg_color = Color.TRANSPARENT
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


func _get_theme_highlight_color() -> Color:
	if _settings_node != null and _settings_node.has_method("get_accent_color"):
		var value: Variant = _settings_node.call("get_accent_color")
		if value is Color:
			return value
	return COLOR_STATUS


func _play_sfx(id: String) -> void:
	if _sfx_node != null and _sfx_node.has_method("play"):
		_sfx_node.call("play", id)


func _sync_multiplayer_local_state() -> void:
	if _settings_node == null:
		_settings_node = get_node_or_null("/root/UnilearnUserSettings")

	var local_name := ""
	if _settings_node != null:
		if _settings_node.has_method("get_display_name"):
			local_name = str(_settings_node.call("get_display_name")).strip_edges()
		elif "display_name" in _settings_node:
			local_name = str(_settings_node.display_name).strip_edges()

	if is_instance_valid(_username_box):
		_username_box.text = local_name
		_last_saved_display_name = local_name
		_update_username_clear_button()

	_button_toggled = _is_location_enabled_locally()
	_set_button_highlight_blend(1.0 if _button_toggled else 0.0)
	_update_nearby_players_ui()
	if _button_toggled:
		_start_nearby_refresh()
		_load_nearby_players()
	else:
		_stop_nearby_refresh()

	_pull_display_name_from_backend()


func _is_location_enabled_locally() -> bool:
	if _settings_node == null:
		_settings_node = get_node_or_null("/root/UnilearnUserSettings")

	if _settings_node == null:
		return false

	if "location_enabled" in _settings_node:
		var enabled := bool(_settings_node.location_enabled) and _is_location_permission_granted()
		if not enabled and bool(_settings_node.location_enabled) and _settings_node.has_method("set_location_enabled"):
			_settings_node.call("set_location_enabled", false)
		return enabled

	return false


func _set_location_enabled(value: bool) -> void:
	if value and not _is_location_permission_granted():
		_begin_location_permission_request()
		return

	var final_value := value and _is_location_permission_granted()

	if _settings_node == null:
		_settings_node = get_node_or_null("/root/UnilearnUserSettings")

	if _settings_node != null and _settings_node.has_method("set_location_enabled"):
		_settings_node.call("set_location_enabled", final_value)

	_button_toggled = final_value
	if not _button_toggled:
		_stop_nearby_refresh()
		_set_nearby_players([])
	else:
		_start_nearby_refresh()
		_update_nearby_players_ui()
		_load_nearby_players()
	_play_sfx("success" if _button_toggled else "toggle")
	_animate_button_toggle_state()


func _begin_location_permission_request() -> void:
	if _location_permission_flow_running:
		return

	_location_permission_flow_running = true
	_request_location_permission()

	await get_tree().process_frame

	var attempts := 0
	while attempts < 80 and not _is_location_permission_granted():
		attempts += 1
		await get_tree().create_timer(0.25).timeout

	_location_permission_flow_running = false

	if not is_inside_tree() or _closing:
		return

	if _is_location_permission_granted():
		_set_location_enabled(true)
	else:
		_set_location_enabled(false)


func _is_location_permission_granted() -> bool:
	if _settings_node == null:
		_settings_node = get_node_or_null("/root/UnilearnUserSettings")

	if _settings_node != null and _settings_node.has_method("is_location_permission_granted"):
		return bool(_settings_node.call("is_location_permission_granted"))

	if OS.get_name() != "Android":
		return true

	if not OS.has_method("get_granted_permissions"):
		return true

	var granted_permissions: PackedStringArray = OS.get_granted_permissions()
	return granted_permissions.has("android.permission.ACCESS_FINE_LOCATION") or granted_permissions.has("android.permission.ACCESS_COARSE_LOCATION")


func _request_location_permission() -> void:
	if _settings_node == null:
		_settings_node = get_node_or_null("/root/UnilearnUserSettings")

	if _settings_node != null and _settings_node.has_method("request_location_permission"):
		_settings_node.call("request_location_permission")
		return

	if OS.get_name() != "Android":
		return

	if OS.has_method("request_permission"):
		OS.request_permission("android.permission.ACCESS_FINE_LOCATION")
		OS.request_permission("android.permission.ACCESS_COARSE_LOCATION")
		return

	if OS.has_method("request_permissions"):
		OS.request_permissions()


func _save_public_display_name_locally() -> void:
	if not is_instance_valid(_username_box):
		return

	var value := _username_box.text.strip_edges()

	if _settings_node == null:
		_settings_node = get_node_or_null("/root/UnilearnUserSettings")

	if _settings_node != null and _settings_node.has_method("set_display_name"):
		_settings_node.call("set_display_name", value)


func _save_public_display_name(sync_backend: bool = false) -> void:
	if not is_instance_valid(_username_box):
		return

	var value := _username_box.text.strip_edges()
	_save_public_display_name_locally()
	_update_username_clear_button()

	if sync_backend and value != _last_saved_display_name:
		_last_saved_display_name = value
		_save_public_display_name_to_backend(value)


func _save_public_display_name_to_backend(value: String) -> void:
	var database := get_node_or_null("/root/FirebaseDatabase")
	if database == null or not database.has_method("save_user_display_name"):
		return

	var result: Dictionary = await database.call("save_user_display_name", value)
	if not bool(result.get("success", false)):
		push_warning("Failed to save multiplayer displayName: %s" % str(result))


func _pull_display_name_from_backend() -> void:
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
		_username_box.text = backend_name
		_last_saved_display_name = backend_name
		_save_public_display_name_locally()
		_update_username_clear_button()
