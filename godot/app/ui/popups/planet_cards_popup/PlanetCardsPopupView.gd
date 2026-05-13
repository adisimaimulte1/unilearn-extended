extends "res://app/ui/popups/planet_cards_popup/PlanetCardsPopupBase.gd"


func _build_ui() -> void:
	_root = Control.new()
	_root.name = "PlanetCardsPopupRoot"
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
			_release_search_focus()
			close_popup()
			get_viewport().set_input_as_handled()
		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_release_search_focus()
			close_popup()
			get_viewport().set_input_as_handled()
	)

	_slide_root = Control.new()
	_slide_root.name = "PlanetCardsSlideRoot"
	_slide_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_slide_root.modulate.a = 0.0
	_root.add_child(_slide_root)

	_panel = PanelContainer.new()
	_panel.name = "PlanetCardsPanel"
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.add_theme_stylebox_override("panel", _panel_style())
	_slide_root.add_child(_panel)

	_body_root = Control.new()
	_body_root.name = "PlanetCardsBodyRoot"
	_body_root.mouse_filter = Control.MOUSE_FILTER_PASS
	_panel.add_child(_body_root)

	_build_main_view()
	_build_low_bar()

	_generate_http = HTTPRequest.new()
	_generate_http.name = "GeneratePlanetHTTPRequest"
	_generate_http.timeout = 90.0
	_generate_http.request_completed.connect(_on_generate_planet_request_completed)
	add_child(_generate_http)


func _build_main_view() -> void:
	if is_instance_valid(_main_view):
		_main_view.queue_free()

	_main_view = Control.new()
	_main_view.name = "PlanetCardsMainView"
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
	content.name = "PlanetCardsContent"
	content.add_theme_constant_override("separation", 34)
	margin.add_child(content)

	var title_box := VBoxContainer.new()
	title_box.custom_minimum_size = Vector2(0, 230)
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_box.add_theme_constant_override("separation", 6)
	content.add_child(title_box)

	var title := Label.new()
	title.text = "PLANET CARDS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 118)
	title.add_theme_color_override("font_color", COLOR_TEXT)
	title.clip_text = false
	_apply_app_font(title)
	title_box.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Learn about the planets you discovered!"
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
	search_row.name = "SearchRow"
	search_row.custom_minimum_size = Vector2(0, search_row_height)
	search_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search_row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	content.add_child(search_row)

	var search_shell := PanelContainer.new()
	search_shell.name = "SearchShell"
	search_shell.mouse_filter = Control.MOUSE_FILTER_STOP
	search_shell.add_theme_stylebox_override("panel", _search_style())
	search_row.add_child(search_shell)

	_add_button = Control.new()
	_add_button.name = "CreatePlanetButton"
	_add_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_add_button.scale = Vector2.ONE
	search_row.add_child(_add_button)

	_add_button.draw.connect(func() -> void:
		var rect := Rect2(Vector2.ZERO, _add_button.size)
		var highlight := _get_theme_highlight_color()
		var icon_color := COLOR_TEXT.lerp(highlight, _add_button_highlight_blend)

		_add_button.draw_style_box(_square_button_style(false), rect)

		var center := _add_button.size * 0.5
		var plus_length := _add_button.size.y * 0.38
		var plus_thickness := _add_button.size.y * 0.075

		_add_button.draw_line(center + Vector2(-plus_length * 0.5, 0), center + Vector2(plus_length * 0.5, 0), icon_color, plus_thickness, true)
		_add_button.draw_line(center + Vector2(0, -plus_length * 0.5), center + Vector2(0, plus_length * 0.5), icon_color, plus_thickness, true)
	)

	var layout_search_row := func() -> void:
		var row_width := search_row.size.x
		var row_height := search_row.size.y

		if row_height <= 0.0:
			row_height = search_row_height

		var button_size := row_height
		var search_width: float = max(0.0, row_width - button_size - search_gap)

		search_shell.position = Vector2.ZERO
		search_shell.size = Vector2(search_width, row_height)
		search_shell.custom_minimum_size = search_shell.size

		_add_button.position = Vector2(search_width + search_gap, 0.0)
		_add_button.size = Vector2(button_size, row_height)
		_add_button.custom_minimum_size = _add_button.size
		_add_button.pivot_offset = _add_button.size * 0.5
		_add_button.queue_redraw()

	search_row.resized.connect(func() -> void:
		layout_search_row.call()
	)

	var search_margin := MarginContainer.new()
	search_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	search_margin.add_theme_constant_override("margin_left", 34)
	search_margin.add_theme_constant_override("margin_right", 20)
	search_margin.add_theme_constant_override("margin_top", 0)
	search_margin.add_theme_constant_override("margin_bottom", 0)
	search_shell.add_child(search_margin)

	var search_inner := HBoxContainer.new()
	search_inner.alignment = BoxContainer.ALIGNMENT_CENTER
	search_inner.add_theme_constant_override("separation", 20)
	search_margin.add_child(search_inner)

	var search_icon := _create_search_icon()
	search_inner.add_child(search_icon)

	_search_box = LineEdit.new()
	_search_box.placeholder_text = SEARCH_PLACEHOLDER
	_search_box.custom_minimum_size = Vector2(0, 120)
	_search_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search_box.clear_button_enabled = false
	_search_box.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_search_box.flat = true
	_search_box.caret_blink = true
	_search_box.caret_blink_interval = 0.42
	_search_box.virtual_keyboard_enabled = true
	_search_box.add_theme_font_size_override("font_size", 66)
	_search_box.add_theme_color_override("font_color", COLOR_TEXT)
	_search_box.add_theme_color_override("font_placeholder_color", COLOR_PLACEHOLDER)
	_search_box.add_theme_color_override("caret_color", COLOR_TEXT)
	_search_box.add_theme_color_override("font_selected_color", Color.BLACK)
	_search_box.add_theme_color_override("selection_color", COLOR_TEXT)
	_search_box.add_theme_stylebox_override("normal", _transparent_line_edit_style())
	_search_box.add_theme_stylebox_override("focus", _transparent_line_edit_style())
	_search_box.add_theme_stylebox_override("read_only", _transparent_line_edit_style())
	_apply_app_font(_search_box)

	_search_box.focus_entered.connect(func() -> void:
		_search_box.placeholder_text = ""
		_keyboard_was_visible = _is_virtual_keyboard_visible()
	)

	_search_box.focus_exited.connect(func() -> void:
		if _search_box.text.strip_edges().is_empty():
			_search_box.placeholder_text = SEARCH_PLACEHOLDER
		_keyboard_was_visible = false
	)

	_search_box.text_submitted.connect(func(_text: String) -> void:
		if _is_add_button_locked():
			_release_search_focus()
			return

		if _get_search_match_count(_search_box.text) == 0 and not _search_box.text.strip_edges().is_empty():
			_press_create_planet_button(_add_button)
		else:
			_release_search_focus()
	)

	_search_box.text_changed.connect(_on_search_text_changed)
	search_inner.add_child(_search_box)

	_search_clear_button = _create_search_clear_button()
	search_inner.add_child(_search_clear_button)
	_update_search_clear_button()

	_add_button.mouse_entered.connect(func() -> void:
		_add_button_hovered = true
		_add_button.queue_redraw()
	)

	_add_button.mouse_exited.connect(func() -> void:
		_add_button_hovered = false
		_add_button.queue_redraw()
	)

	_add_button.gui_input.connect(func(event: InputEvent) -> void:
		if _is_add_button_locked():
			get_viewport().set_input_as_handled()
			return

		if event is InputEventScreenTouch and event.pressed:
			_start_add_button_press(event.index)
			get_viewport().set_input_as_handled()

		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_start_add_button_press(-2)
			get_viewport().set_input_as_handled()
	)

	layout_search_row.call()
	_sync_generate_button_ui(true)

	_scroll = ScrollContainer.new()
	_scroll.name = "PlanetCardsScroll"
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.follow_focus = true
	_scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
	_scroll.add_theme_constant_override("scrollbar_margin_left", 30)
	content.add_child(_scroll)

	_scroll_margin = MarginContainer.new()
	_scroll_margin.name = "ScrollContentMargin"
	_scroll_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll_margin.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_scroll_margin.mouse_filter = Control.MOUSE_FILTER_PASS
	_scroll_margin.add_theme_constant_override("margin_right", 44)
	_scroll.add_child(_scroll_margin)

	_scroll_content = VBoxContainer.new()
	_scroll_content.name = "ScrollContent"
	_scroll_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll_content.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_scroll_content.mouse_filter = Control.MOUSE_FILTER_PASS
	_scroll_content.add_theme_constant_override("separation", 0)
	_scroll_margin.add_child(_scroll_content)

	_grid = GridContainer.new()
	_grid.name = "PlanetCardsGrid"
	_grid.columns = columns
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_grid.mouse_filter = Control.MOUSE_FILTER_PASS
	_grid.visible = false
	_grid.modulate.a = 1.0
	_grid.position = Vector2.ZERO
	_grid.add_theme_constant_override("h_separation", 24)
	_grid.add_theme_constant_override("v_separation", 26)
	_scroll_content.add_child(_grid)

	_no_results_label = Label.new()
	_no_results_label.name = "NoResultsLabel"
	_no_results_label.text = ""
	_no_results_label.visible = true
	_no_results_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_no_results_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_no_results_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_no_results_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_no_results_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_no_results_label.add_theme_font_size_override("font_size", 64)
	_no_results_label.add_theme_color_override("font_color", COLOR_SUBTITLE)
	_apply_app_font(_no_results_label)
	_scroll_content.add_child(_no_results_label)

	_scroll.resized.connect(func() -> void:
		_update_no_results_height()
	)

	call_deferred("_style_scroll_bar")
	call_deferred("_update_no_results_height")


func _build_low_bar() -> void:
	_low_bar = PanelContainer.new()
	_low_bar.name = "PlanetCardsLowBar"
	_low_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_low_bar.visible = false
	_low_bar.modulate.a = 0.0
	_low_bar.add_theme_stylebox_override("panel", _low_bar_style(false))
	_body_root.add_child(_low_bar)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 34)
	margin.add_theme_constant_override("margin_right", 34)
	margin.add_theme_constant_override("margin_top", 0)
	margin.add_theme_constant_override("margin_bottom", 0)
	_low_bar.add_child(margin)

	_low_bar_label = Label.new()
	_low_bar_label.text = ""
	_low_bar_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_low_bar_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_low_bar_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_low_bar_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_low_bar_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_low_bar_label.add_theme_font_size_override("font_size", 34)
	_low_bar_label.add_theme_color_override("font_color", COLOR_TEXT)
	_apply_app_font(_low_bar_label)
	margin.add_child(_low_bar_label)

	_layout_low_bar()


func _layout_low_bar() -> void:
	if not is_instance_valid(_low_bar) or not is_instance_valid(_body_root):
		return

	var parent_size := _body_root.size

	if parent_size.x <= 0.0 or parent_size.y <= 0.0:
		parent_size = _panel.size if is_instance_valid(_panel) else Vector2(1080, 1600)

	var width: float = min(parent_size.x * LOW_BAR_WIDTH_RATIO, LOW_BAR_MAX_WIDTH)
	var height := LOW_BAR_HEIGHT

	_low_bar.size = Vector2(width, height)
	_low_bar.custom_minimum_size = _low_bar.size
	_low_bar.position = Vector2(
		(parent_size.x - width) * 0.5,
		parent_size.y - height - LOW_BAR_BOTTOM_PADDING
	)
