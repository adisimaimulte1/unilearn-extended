extends "res://app/ui/popups/galaxy_popup/GalaxyPopupBase.gd"


class KnobOnlyHSlider:
	extends Control

	signal value_changed(value: float)
	signal knob_drag_started
	signal knob_drag_ended

	var min_value: float = 0.0
	var max_value: float = 100.0
	var step: float = 1.0
	var value: float = 0.0:
		set(next_value):
			_set_value_internal(next_value, true)
		get:
			return _value

	var grabber_hit_radius: float = 64.0
	var track_height: float = 62.0
	var track_border_width: float = 6.0
	var knob_radius: float = 50.0
	var knob_color: Color = Color("#FFC62D")
	var track_bg_color: Color = Color.BLACK
	var track_border_color: Color = Color.WHITE
	var fill_color: Color = Color.WHITE

	var _value: float = 0.0
	var _dragging_grabber: bool = false
	var _drag_offset_x: float = 0.0
	var _knob_scale: float = 1.0
	var _knob_tween: Tween = null

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_PASS
		focus_mode = Control.FOCUS_NONE
		custom_minimum_size = Vector2(0, 96)
		queue_redraw()

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventScreenTouch:
			_handle_touch_event(event)
			return

		if event is InputEventScreenDrag:
			_handle_drag_event(event.position)
			return

		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			_handle_mouse_button_event(event)
			return

		if event is InputEventMouseMotion:
			_handle_mouse_motion_event(event)

	func _draw() -> void:
		var rect := _track_rect()
		var radius := rect.size.y * 0.5
		draw_style_box(_make_track_style(), rect)

		var center := _grabber_center()
		var fill_width: float = max(center.x - rect.position.x, 0.0)
		if fill_width > 0.0:
			var fill_rect := Rect2(rect.position, Vector2(fill_width, rect.size.y))
			draw_style_box(_make_fill_style(), fill_rect)

		draw_circle(center, knob_radius * _knob_scale, knob_color)

	func _set_knob_scale(next_scale: float) -> void:
		_knob_scale = next_scale
		queue_redraw()

	func set_value_no_signal(next_value: float) -> void:
		_set_value_internal(next_value, false)

	func _set_value_internal(next_value: float, emit_signal_enabled: bool) -> void:
		var snapped := _snap_value(next_value)
		var clamped_value: float = clamp(snapped, min_value, max_value)
		if is_equal_approx(_value, clamped_value):
			return
		_value = clamped_value
		queue_redraw()
		if emit_signal_enabled:
			value_changed.emit(_value)

	func _snap_value(next_value: float) -> float:
		if step <= 0.0:
			return next_value
		return round(next_value / step) * step

	func _handle_touch_event(event: InputEventScreenTouch) -> void:
		if event.pressed:
			_begin_grabber_drag(event.position)
			return

		_end_grabber_drag()

	func _handle_drag_event(local_position: Vector2) -> void:
		if not _dragging_grabber:
			return
		_update_value_from_local_x(local_position.x - _drag_offset_x)
		accept_event()

	func _handle_mouse_button_event(event: InputEventMouseButton) -> void:
		if event.pressed:
			_begin_grabber_drag(event.position)
			return

		_end_grabber_drag()

	func _handle_mouse_motion_event(event: InputEventMouseMotion) -> void:
		if not _dragging_grabber:
			return
		_update_value_from_local_x(event.position.x - _drag_offset_x)
		accept_event()

	func _begin_grabber_drag(local_position: Vector2) -> void:
		var center := _grabber_center()
		_dragging_grabber = local_position.distance_to(center) <= grabber_hit_radius
		if not _dragging_grabber:
			return

		_drag_offset_x = local_position.x - center.x
		_play_knob_bounce(0.86, 0.09)
		knob_drag_started.emit()
		accept_event()

	func _end_grabber_drag() -> void:
		if _dragging_grabber:
			knob_drag_ended.emit()
			_play_knob_release_bounce()
			accept_event()
		_dragging_grabber = false
		_drag_offset_x = 0.0

	func _grabber_center() -> Vector2:
		var min_v := float(min_value)
		var max_v := float(max_value)
		var span: float = max(max_v - min_v, 0.0001)
		var ratio: float = clamp((float(value) - min_v) / span, 0.0, 1.0)
		var rect := _track_rect()
		return Vector2(lerp(rect.position.x, rect.position.x + rect.size.x, ratio), rect.position.y + rect.size.y * 0.5)

	func _update_value_from_local_x(local_x: float) -> void:
		var rect := _track_rect()
		var ratio: float = clamp((local_x - rect.position.x) / max(rect.size.x, 0.0001), 0.0, 1.0)
		_set_value_internal(lerp(min_value, max_value, ratio), true)

	func _track_rect() -> Rect2:
		var usable_width: float = max(size.x - knob_radius * 2.0, 1.0)
		var x := knob_radius
		var y: float = max((size.y - track_height) * 0.5, 0.0)
		return Rect2(x, y, usable_width, track_height)

	func _make_track_style() -> StyleBoxFlat:
		var style := StyleBoxFlat.new()
		style.bg_color = track_bg_color
		style.border_color = track_border_color
		style.set_border_width_all(int(track_border_width))
		style.set_corner_radius_all(999)
		return style

	func _make_fill_style() -> StyleBoxFlat:
		var style := StyleBoxFlat.new()
		style.bg_color = fill_color
		style.border_color = Color.TRANSPARENT
		style.set_border_width_all(0)
		style.set_corner_radius_all(999)
		return style

	func _play_knob_bounce(target_scale: float, duration: float) -> void:
		if _knob_tween != null and _knob_tween.is_valid():
			_knob_tween.kill()
		_knob_tween = create_tween()
		_knob_tween.set_trans(Tween.TRANS_BACK)
		_knob_tween.set_ease(Tween.EASE_OUT)
		_knob_tween.tween_method(Callable(self, "_set_knob_scale"), _knob_scale, target_scale, duration)

	func _play_knob_release_bounce() -> void:
		if _knob_tween != null and _knob_tween.is_valid():
			_knob_tween.kill()
		_knob_tween = create_tween()
		_knob_tween.set_trans(Tween.TRANS_BACK)
		_knob_tween.set_ease(Tween.EASE_OUT)
		_knob_tween.tween_method(Callable(self, "_set_knob_scale"), _knob_scale, 1.08, 0.08)
		_knob_tween.tween_method(Callable(self, "_set_knob_scale"), 1.08, 1.0, 0.14)


class GalaxySettingToggleRow:
	extends Control

	signal value_changed(value: bool)

	var label_text: String = ""
	var value: bool = false:
		set(next_value):
			_set_value_internal(next_value, true)
		get:
			return _value

	var text_color: Color = Color.WHITE
	var accent_color: Color = Color("#FFC62D")
	var line_color: Color = Color(1.0, 1.0, 1.0, 0.86)
	var hover_color: Color = Color(1.0, 1.0, 1.0, 0.055)
	var pressed_color: Color = Color(1.0, 0.78, 0.18, 0.14)
	var row_font_size: int = 54
	var row_height: float = 116.0
	var drag_threshold: float = 18.0
	var show_underline: bool = true

	var _label: Label = null
	var _line: ColorRect = null
	var _app_font: Font = null
	var _value: bool = false
	var _pressed_inside: bool = false
	var _cancelled_by_drag: bool = false
	var _press_position: Vector2 = Vector2.ZERO
	var _scale_tween: Tween = null

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_PASS
		focus_mode = Control.FOCUS_NONE
		custom_minimum_size = Vector2(0, row_height)
		pivot_offset = size * 0.5
		mouse_entered.connect(queue_redraw)
		mouse_exited.connect(queue_redraw)
		_build_children()
		_refresh_text()
		queue_redraw()

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED:
			pivot_offset = size * 0.5
			if is_instance_valid(_label):
				_label.pivot_offset = _label.size * 0.5

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventScreenTouch:
			if event.pressed:
				_press_position = event.position
				_pressed_inside = true
				_cancelled_by_drag = false
				_play_press_animation()
				queue_redraw()
				return

			_release_from_position(event.position)
			return

		if event is InputEventScreenDrag:
			if _pressed_inside and event.position.distance_to(_press_position) > drag_threshold:
				_cancel_press_visual()
			return

		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_press_position = event.position
				_pressed_inside = true
				_cancelled_by_drag = false
				_play_press_animation()
				queue_redraw()
				return

			_release_from_position(event.position)
			return

		if event is InputEventMouseMotion:
			if _pressed_inside and event.position.distance_to(_press_position) > drag_threshold:
				_cancel_press_visual()

	func _draw() -> void:
		pass

	func set_value_no_signal(next_value: bool) -> void:
		_set_value_internal(next_value, false)

	func set_underline_visible(visible: bool) -> void:
		show_underline = visible
		if is_instance_valid(_line):
			_line.visible = show_underline

	func refresh_theme(font: Font, next_text_color: Color, next_accent_color: Color, next_line_color: Color, next_hover_color: Color, next_pressed_color: Color) -> void:
		_app_font = font
		text_color = next_text_color
		accent_color = next_accent_color
		line_color = next_line_color
		hover_color = next_hover_color
		pressed_color = next_pressed_color
		if _app_font != null and is_instance_valid(_label):
			_label.add_theme_font_override("font", _app_font)
		if is_instance_valid(_line):
			_line.color = line_color
		_refresh_text()
		queue_redraw()

	func _build_children() -> void:
		if is_instance_valid(_label):
			return

		_label = Label.new()
		_label.set_anchors_preset(Control.PRESET_FULL_RECT)
		_label.offset_left = 22
		_label.offset_right = -22
		_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		_label.clip_text = true
		_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_label.add_theme_font_size_override("font_size", row_font_size)
		if _app_font != null:
			_label.add_theme_font_override("font", _app_font)
		add_child(_label)
		_label.resized.connect(func() -> void:
			if is_instance_valid(_label):
				_label.pivot_offset = _label.size * 0.5
		)

		_line = ColorRect.new()
		_line.anchor_left = 0.0
		_line.anchor_right = 1.0
		_line.anchor_top = 1.0
		_line.anchor_bottom = 1.0
		_line.offset_left = 0.0
		_line.offset_right = 0.0
		_line.offset_top = -5.0
		_line.offset_bottom = 0.0
		_line.color = line_color
		_line.visible = show_underline
		_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_line)

	func _set_value_internal(next_value: bool, emit_signal_enabled: bool) -> void:
		if _value == next_value:
			return
		_value = next_value
		_refresh_text()
		if emit_signal_enabled:
			value_changed.emit(_value)

	func _refresh_text() -> void:
		if not is_instance_valid(_label):
			return
		_label.text = "%s: %s" % [label_text, "ON" if _value else "OFF"]
		_label.add_theme_color_override("font_color", accent_color if _value else text_color)

	func _release_from_position(local_position: Vector2) -> void:
		if not _pressed_inside:
			return

		var should_toggle := not _cancelled_by_drag and Rect2(Vector2.ZERO, size).has_point(local_position)
		_pressed_inside = false
		_cancelled_by_drag = false
		_play_release_animation()
		queue_redraw()

		if should_toggle:
			_set_value_internal(not _value, true)
			accept_event()

	func _cancel_press_visual() -> void:
		_pressed_inside = false
		_cancelled_by_drag = true
		_play_release_animation()
		queue_redraw()

	func _row_style(color: Color) -> StyleBoxFlat:
		var style := StyleBoxFlat.new()
		style.bg_color = color
		style.border_color = Color.TRANSPARENT
		style.set_border_width_all(0)
		style.set_corner_radius_all(0)
		return style

	func _play_press_animation() -> void:
		_tween_scale(Vector2(0.88, 0.88), 0.055)

	func _play_release_animation() -> void:
		var target: Control = _label if is_instance_valid(_label) else self
		if _scale_tween != null and _scale_tween.is_valid():
			_scale_tween.kill()
		_scale_tween = create_tween()
		_scale_tween.set_trans(Tween.TRANS_BACK)
		_scale_tween.set_ease(Tween.EASE_OUT)
		_scale_tween.tween_property(target, "scale", Vector2(1.10, 1.10), 0.11)
		_scale_tween.tween_property(target, "scale", Vector2.ONE, 0.10)

	func _tween_scale(target_scale: Vector2, duration: float) -> void:
		var target: Control = _label if is_instance_valid(_label) else self
		if _scale_tween != null and _scale_tween.is_valid():
			_scale_tween.kill()
		_scale_tween = create_tween()
		_scale_tween.set_trans(Tween.TRANS_BACK)
		_scale_tween.set_ease(Tween.EASE_OUT)
		_scale_tween.tween_property(target, "scale", target_scale, duration)


var _system_bodies_list: VBoxContainer = null
var _system_empty_bodies_label: Label = null
var _system_bodies_count_label: Label = null
var _highlighted_text_labels: Array = []
var _accent_panel_nodes: Array = []
var _last_theme_accent_hex: String = ""
var _theme_refresh_timer: Timer = null

func _build_ui() -> void:
	_root = Control.new()
	_root.name = "GalaxyPopupRoot"
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
			close_popup()
			get_viewport().set_input_as_handled()
		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			close_popup()
			get_viewport().set_input_as_handled()
	)

	_slide_root = Control.new()
	_slide_root.name = "GalaxySlideRoot"
	_slide_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_slide_root.modulate.a = 0.0
	_root.add_child(_slide_root)

	_panel = PanelContainer.new()
	_panel.name = "GalaxyPanel"
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.clip_contents = true
	_panel.add_theme_stylebox_override("panel", _panel_style())
	_slide_root.add_child(_panel)

	_body_root = Control.new()
	_body_root.name = "GalaxyBodyRoot"
	_body_root.mouse_filter = Control.MOUSE_FILTER_PASS
	_body_root.clip_contents = true
	_panel.add_child(_body_root)

	_build_main_view()
	_setup_dynamic_theme_refresh()
	_refresh_dynamic_theme(true)


func _build_main_view() -> void:
	var margin := MarginContainer.new()
	margin.name = "GalaxyMargin"
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", panel_padding_x)
	margin.add_theme_constant_override("margin_right", panel_padding_x)
	margin.add_theme_constant_override("margin_top", panel_padding_y)
	margin.add_theme_constant_override("margin_bottom", panel_padding_y)
	_body_root.add_child(margin)

	var shell := VBoxContainer.new()
	shell.name = "GalaxyContentShell"
	shell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shell.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shell.add_theme_constant_override("separation", 34)
	margin.add_child(shell)

	_add_header(shell)
	_add_tabs(shell)

	_scroll = ScrollContainer.new()
	_scroll.name = "GalaxyScroll"
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.follow_focus = true
	_scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	_scroll.clip_contents = true
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
	_scroll.add_theme_constant_override("scrollbar_margin_left", 20)
	shell.add_child(_scroll)

	_scroll_margin = MarginContainer.new()
	_scroll_margin.name = "GalaxyScrollMargin"
	_scroll_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll_margin.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_scroll_margin.mouse_filter = Control.MOUSE_FILTER_PASS
	_scroll_margin.add_theme_constant_override("margin_left", 20)
	_scroll_margin.add_theme_constant_override("margin_right", 20)
	_scroll.add_child(_scroll_margin)

	_content = VBoxContainer.new()
	_content.name = "GalaxyScrollContent"
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_content.mouse_filter = Control.MOUSE_FILTER_PASS
	_content.add_theme_constant_override("separation", 26)
	_scroll_margin.add_child(_content)

	_data_content = _make_tab_content("GalaxySimulationDataTab", true)
	_behavior_content = _make_tab_content("GalaxyBehaviorTab", false)
	_commands_content = _make_tab_content("GalaxyQuickCommandsTab", false)
	_results_content = _make_tab_content("GalaxyResultsTab", false)

	_add_simulation_tuning_panel(_data_content)
	_add_behavior_panel(_behavior_content)
	_add_action_strip(_commands_content)
	_add_system_feedback_panel(_results_content)
	_set_active_tab("data")



func _make_tab_content(node_name: String, starts_visible: bool) -> VBoxContainer:
	var tab := VBoxContainer.new()
	tab.name = node_name
	tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	tab.mouse_filter = Control.MOUSE_FILTER_PASS
	tab.add_theme_constant_override("separation", 26)
	tab.visible = starts_visible
	_content.add_child(tab)
	return tab


func _make_highlighted_text_label(text: String, font_size: int, alignment: HorizontalAlignment, highlights: Array) -> RichTextLabel:
	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.scroll_following = false
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("normal_font_size", font_size)
	label.add_theme_color_override("default_color", Color.WHITE)
	if _app_font != null:
		label.add_theme_font_override("normal_font", _app_font)

	_highlighted_text_labels.append({
		"label": label,
		"text": text,
		"highlights": highlights,
		"alignment": alignment,
	})

	_apply_highlighted_text_label(label, text, alignment, highlights)
	return label


func _apply_highlighted_text_label(label: RichTextLabel, text: String, alignment: int, highlights: Array) -> void:
	if not is_instance_valid(label):
		return

	label.add_theme_color_override("default_color", Color.WHITE)
	match alignment:
		HORIZONTAL_ALIGNMENT_CENTER:
			label.text = "[center]%s[/center]" % _highlight_subtitle_bbcode(text, highlights)
		HORIZONTAL_ALIGNMENT_RIGHT:
			label.text = "[right]%s[/right]" % _highlight_subtitle_bbcode(text, highlights)
		_:
			label.text = _highlight_subtitle_bbcode(text, highlights)

func _highlight_subtitle_bbcode(text: String, highlights: Array) -> String:
	var result := _bbcode_escape_text(text)
	var accent_hex := _theme_accent_color().to_html(false)

	for raw_word in highlights:
		var word := str(raw_word)
		if word.strip_edges().is_empty():
			continue

		var escaped_word := _bbcode_escape_text(word)
		result = result.replace(escaped_word, "[color=#%s]%s[/color]" % [accent_hex, escaped_word])

	return result


func _bbcode_escape_text(value: String) -> String:
	return value.replace("[", "[lb]").replace("]", "[rb]")


func _subtitle_highlights(title_text: String, subtitle_text: String) -> Array:
	var key := title_text.strip_edges().to_upper()

	match key:
		"SYSTEM RESULTS":
			return ["live simulation", "playable system", "stability", "pressure", "balance", "six traits"]
		"SIMULATION DATA":
			return ["galaxy moves", "time", "orbital grip", "anchoring", "trail memory"]
		"SYSTEM BEHAVIOR":
			return ["live rules", "orbit stability", "anchoring", "drag momentum", "trail rendering"]
		"QUICK COMMANDS":
			return ["simulation actions", "recenter", "rebuild orbit paths", "clear visual history"]
		_:
			return _generic_subtitle_highlights(subtitle_text)


func _generic_subtitle_highlights(subtitle_text: String) -> Array:
	var words := subtitle_text.split(" ", false)
	var result: Array = []

	for raw_word in words:
		var word := str(raw_word).strip_edges()
		for mark in [",", ".", ":", ";", "!", "?", "(", ")"]:
			word = word.replace(mark, "")
		if word.length() >= 8 and result.size() < 4:
			result.append(word)

	return result


func _add_header(parent: VBoxContainer) -> void:
	var title_box := VBoxContainer.new()
	title_box.custom_minimum_size = Vector2(0, 230)
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_box.add_theme_constant_override("separation", 6)
	parent.add_child(title_box)

	var title := Label.new()
	title.text = "GALAXY CONSOLE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 118)
	title.add_theme_color_override("font_color", _theme_text_color())
	title.clip_text = true
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_apply_app_font(title)
	title_box.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Modify data from the universe you created!"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	subtitle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.add_theme_font_size_override("font_size", 52)
	subtitle.add_theme_color_override("font_color", _theme_subtitle_color())
	_apply_app_font(subtitle)
	title_box.add_child(subtitle)

func _add_tabs(parent: VBoxContainer) -> void:
	var tabs_margin := MarginContainer.new()
	tabs_margin.name = "GalaxyTabsMargin"
	tabs_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs_margin.mouse_filter = Control.MOUSE_FILTER_PASS
	tabs_margin.add_theme_constant_override("margin_left", 20)
	tabs_margin.add_theme_constant_override("margin_right", 20)
	tabs_margin.add_theme_constant_override("margin_top", 0)
	tabs_margin.add_theme_constant_override("margin_bottom", 0)
	parent.add_child(tabs_margin)

	_tab_bar = HBoxContainer.new()
	_tab_bar.name = "GalaxyTabs"
	_tab_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tab_bar.mouse_filter = Control.MOUSE_FILTER_PASS
	_tab_bar.add_theme_constant_override("separation", 12)
	tabs_margin.add_child(_tab_bar)

	_data_tab_button = _make_tab_button("DATA", "data")
	_behavior_tab_button = _make_tab_button("BEHAVIOR", "behavior")
	_commands_tab_button = _make_tab_button("COMMANDS", "commands")
	_results_tab_button = _make_tab_button("RESULTS", "results")
	_tab_bar.add_child(_data_tab_button)
	_tab_bar.add_child(_behavior_tab_button)
	_tab_bar.add_child(_commands_tab_button)
	_tab_bar.add_child(_results_tab_button)


func _make_tab_button(text: String, tab_id: String) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_PASS
	button.custom_minimum_size = Vector2(0, 86)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.flat = false
	button.clip_text = true
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.add_theme_font_size_override("font_size", 30)
	button.add_theme_constant_override("outline_size", 0)
	_apply_app_font(button)

	button.button_down.connect(func() -> void:
		_on_tab_button_down(button)
	)
	button.button_up.connect(func() -> void:
		_on_tab_button_up(button)
	)
	button.pressed.connect(func() -> void:
		_play_sfx("click")
		_set_active_tab(tab_id)
	)

	return button


func _set_active_tab(tab_id: String) -> void:
	_active_tab = tab_id

	if is_instance_valid(_data_content):
		_data_content.visible = tab_id == "data"
	if is_instance_valid(_behavior_content):
		_behavior_content.visible = tab_id == "behavior"
	if is_instance_valid(_commands_content):
		_commands_content.visible = tab_id == "commands"
	if is_instance_valid(_results_content):
		_results_content.visible = tab_id == "results"

	_update_tab_styles()
	_refresh_dynamic_theme(false)

	if is_instance_valid(_scroll):
		var bar := _scroll.get_v_scroll_bar()
		if bar != null:
			bar.value = 0

	call_deferred("_refresh_from_config")
	call_deferred("_apply_system_feedback_widgets")


func _update_tab_styles() -> void:
	if is_instance_valid(_data_tab_button):
		_apply_tab_style(_data_tab_button, _active_tab == "data")
	if is_instance_valid(_behavior_tab_button):
		_apply_tab_style(_behavior_tab_button, _active_tab == "behavior")
	if is_instance_valid(_commands_tab_button):
		_apply_tab_style(_commands_tab_button, _active_tab == "commands")
	if is_instance_valid(_results_tab_button):
		_apply_tab_style(_results_tab_button, _active_tab == "results")

func _apply_tab_style(button: Button, active: bool) -> void:
	if not is_instance_valid(button):
		return

	var font_color: Color = Color.BLACK if active else Color.WHITE
	button.modulate = Color.WHITE
	button.self_modulate = Color.WHITE
	button.disabled = false
	button.visible = true
	button.add_theme_font_size_override("font_size", 30)
	button.add_theme_color_override("font_color", font_color)
	button.add_theme_color_override("font_hover_color", font_color)
	button.add_theme_color_override("font_pressed_color", font_color)
	button.add_theme_color_override("font_disabled_color", font_color)
	button.add_theme_stylebox_override("normal", _tab_button_style(active, false))
	button.add_theme_stylebox_override("hover", _tab_button_style(active, true))
	button.add_theme_stylebox_override("pressed", _tab_button_style(active, true))
	button.add_theme_stylebox_override("focus", _tab_button_style(active, false))


func _add_simulation_tuning_panel(parent: VBoxContainer) -> void:
	var panel := _make_section(parent, "SimulationTuningPanel")
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	box.add_theme_constant_override("separation", 24)
	_panel_margin(panel, 24, 26, 24, 28).add_child(box)

	_add_simulation_panel_header(box)
	_add_slider(box, "SIMULATION SPEED", "simulation_speed", 0.05, 25.0, 0.05, 12.525)
	_add_slider(box, "REVOLUTION SPEED", "revolution_speed_multiplier", 0.1, 100.0, 0.1, 50.05)
	_add_slider(box, "CENTER ANCHOR PULL", "center_anchor_strength", 0.0, 40.0, 0.1, 20.0)
	_add_slider(box, "ORBIT LOCK STRENGTH", "orbit_lock_strength", 0.0, 60.0, 0.1, 30.0)
	_add_slider(box, "ORBIT DISTANCE", "orbit_distance_padding", 0.0, 1000.0, 5.0, 500.0)
	_add_slider(box, "TRAIL LENGTH", "max_trail_points", 0.0, 1200.0, 10.0, 600.0)


func _add_behavior_panel(parent: VBoxContainer) -> void:
	var panel := _make_section(parent, "BehaviorPanel")
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	box.add_theme_constant_override("separation", 24)
	_panel_margin(panel, 24, 26, 24, 28).add_child(box)

	_add_panel_header(box, "SYSTEM BEHAVIOR", "Flip the live rules that control orbit stability, anchoring, drag momentum, and trail rendering.")

	var stack := VBoxContainer.new()
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.mouse_filter = Control.MOUSE_FILTER_PASS
	stack.add_theme_constant_override("separation", 0)
	box.add_child(stack)

	_add_toggle(stack, "STABLE ORBIT MODE", "stable_orbit_mode", "Uses the orbit solver instead of letting bodies wander away.")
	_add_toggle(stack, "CENTER BIGGEST OBJECT", "center_largest_body", "Keeps the largest body acting like the system anchor.")
	_add_toggle(stack, "LOCK PLANETS TO ANCHOR", "lock_planets_to_largest_body", "Keeps planets orbiting the largest object instead of drifting.")
	_add_toggle(stack, "IGNORE DRAG THROW", "ignore_drag_throw_velocity", "Dragging repositions bodies without adding unwanted launch velocity.")
	_add_toggle(stack, "TRAILS", "trails_enabled", "Shows orbit paths and movement history.", false)


func _add_action_strip(parent: VBoxContainer) -> void:
	var panel := _make_section(parent, "ActionStrip")
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	box.add_theme_constant_override("separation", 24)
	_panel_margin(panel, 24, 26, 24, 28).add_child(box)

	_add_panel_header(box, "QUICK COMMANDS", "Trigger focused simulation actions instantly: recenter the anchor, rebuild orbit paths, clear visual history, or close the console.")

	var stack := VBoxContainer.new()
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.mouse_filter = Control.MOUSE_FILTER_PASS
	stack.add_theme_constant_override("separation", 0)
	box.add_child(stack)

	_add_action_button(stack, "CENTER ANCHOR", "Pull the largest body back to world center.", func() -> void:
		_play_sfx("success")
		center_anchor_requested.emit()
	)
	_add_action_button(stack, "RESET ORBITS", "Rebuild stable orbit paths using current settings.", func() -> void:
		_play_sfx("success")
		reset_orbits_requested.emit()
	)
	_add_action_button(stack, "CLEAR TRAILS", "Remove old orbit trails without changing bodies.", func() -> void:
		_play_sfx("click")
		clear_trails_requested.emit()
	)
	var close_command: Callable = func() -> void:
		close_popup()
	_add_action_button(stack, "CLOSE", "Return to the galaxy view.", close_command, false)


func _add_system_feedback_panel(parent: VBoxContainer) -> void:
	var panel := PanelContainer.new()
	panel.name = "SystemFeedbackPanel"
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _glass_panel_style())
	parent.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 26)
	margin.add_theme_constant_override("margin_bottom", 28)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	box.add_theme_constant_override("separation", 26)
	margin.add_child(box)

	var header_col := VBoxContainer.new()
	header_col.name = "SystemResultsHeaderColumn"
	header_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_col.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	header_col.mouse_filter = Control.MOUSE_FILTER_PASS
	header_col.add_theme_constant_override("separation", 24)
	box.add_child(header_col)

	_add_panel_header(
		header_col,
		"SYSTEM RESULTS",
		"Read the live simulation as a playable system profile: stability, pressure, balance, object mix, and the six traits that decide how cleanly the galaxy behaves."
	)

	_add_system_score_block(header_col)

	_add_active_bodies_panel(box)

	var metrics_grid := GridContainer.new()
	metrics_grid.name = "SystemMetricsGrid"
	metrics_grid.columns = 2
	metrics_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	metrics_grid.mouse_filter = Control.MOUSE_FILTER_PASS
	metrics_grid.add_theme_constant_override("h_separation", 14)
	metrics_grid.add_theme_constant_override("v_separation", 14)
	box.add_child(metrics_grid)

	_system_count_label = _add_info_chip(metrics_grid, "OBJECTS", "--", _theme_accent_color())
	_system_balance_label = _add_info_chip(metrics_grid, "BALANCE", "--", Color("#63D8FF"))
	_system_pressure_label = _add_info_chip(metrics_grid, "PRESSURE", "--", Color("#FF9D42"))
	_system_mix_label = _add_info_chip(metrics_grid, "MIX", "--", Color.WHITE)

	var attributes_panel := PanelContainer.new()
	attributes_panel.name = "SystemSimulationTraitsPanel"
	attributes_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	attributes_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	attributes_panel.add_theme_stylebox_override("panel", _system_attribute_panel_style())
	box.add_child(attributes_panel)

	var attributes_box := VBoxContainer.new()
	attributes_box.mouse_filter = Control.MOUSE_FILTER_PASS
	attributes_box.add_theme_constant_override("separation", 26)
	_panel_margin(attributes_panel, 34, 32, 34, 36).add_child(attributes_box)

	var title_row := HBoxContainer.new()
	title_row.mouse_filter = Control.MOUSE_FILTER_PASS
	title_row.alignment = BoxContainer.ALIGNMENT_CENTER
	title_row.add_theme_constant_override("separation", 18)
	attributes_box.add_child(title_row)

	var title_stack := VBoxContainer.new()
	title_stack.mouse_filter = Control.MOUSE_FILTER_PASS
	title_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_stack.add_theme_constant_override("separation", 8)
	title_row.add_child(title_stack)

	_add_underlined_title(title_stack, "SIMULATION TRAITS", 68, _theme_text_color())

	var trait_subtitle_text := "The same 0-100 bar language as the planet game profile, rebuilt here for full-system feedback."
	var trait_subtitle := _make_highlighted_text_label(trait_subtitle_text, 38, HORIZONTAL_ALIGNMENT_LEFT, ["0-100", "planet game profile", "full-system feedback"])
	title_stack.add_child(trait_subtitle)

	var scale_tag_panel := PanelContainer.new()
	scale_tag_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scale_tag_panel.add_theme_stylebox_override("panel", _system_score_tile_style())
	_register_accent_panel(scale_tag_panel, "tile")
	title_row.add_child(scale_tag_panel)

	var scale_tag := _make_label("0-100", 32, Color.BLACK, HORIZONTAL_ALIGNMENT_CENTER, false)
	scale_tag.custom_minimum_size = Vector2(150, 70)
	_panel_margin(scale_tag_panel, 14, 8, 14, 8).add_child(scale_tag)

	var stats_stack := VBoxContainer.new()
	stats_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats_stack.mouse_filter = Control.MOUSE_FILTER_PASS
	stats_stack.add_theme_constant_override("separation", 22)
	attributes_box.add_child(stats_stack)

	for stat_key in STAT_KEYS:
		_add_stat_card(stats_stack, stat_key)


func _add_system_score_block(parent: VBoxContainer) -> void:
	var panel := PanelContainer.new()
	panel.name = "SystemScoreBlock"
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size = Vector2(0, 178)
	panel.add_theme_stylebox_override("panel", _system_score_full_row_style())
	_register_accent_panel(panel, "score_full")
	parent.add_child(panel)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 26)
	_panel_margin(panel, 30, 22, 30, 24).add_child(row)

	_system_grade_label = _make_label("--", 58, Color.BLACK, HORIZONTAL_ALIGNMENT_CENTER, false)
	_system_grade_label.custom_minimum_size = Vector2(132, 0)
	row.add_child(_system_grade_label)

	var divider := ColorRect.new()
	divider.custom_minimum_size = Vector2(5, 104)
	divider.color = Color.BLACK
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(divider)

	_system_score_label = _make_label("--", 112, Color.BLACK, HORIZONTAL_ALIGNMENT_CENTER, false)
	_system_score_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_system_score_label.clip_text = true
	_system_score_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(_system_score_label)

	var caption_stack := VBoxContainer.new()
	caption_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption_stack.alignment = BoxContainer.ALIGNMENT_CENTER
	caption_stack.custom_minimum_size = Vector2(250, 0)
	caption_stack.add_theme_constant_override("separation", 2)
	row.add_child(caption_stack)

	caption_stack.add_child(_make_label("SYSTEM", 34, Color.BLACK, HORIZONTAL_ALIGNMENT_CENTER, false))
	caption_stack.add_child(_make_label("HEALTH", 44, Color.BLACK, HORIZONTAL_ALIGNMENT_CENTER, false))


func _add_active_bodies_panel(parent: VBoxContainer) -> void:
	var panel := PanelContainer.new()
	panel.name = "ActiveBodiesPanel"
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _active_bodies_panel_style())
	parent.add_child(panel)

	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	box.add_theme_constant_override("separation", 18)
	_panel_margin(panel, 24, 22, 24, 24).add_child(box)

	var title_row := HBoxContainer.new()
	title_row.mouse_filter = Control.MOUSE_FILTER_PASS
	title_row.alignment = BoxContainer.ALIGNMENT_CENTER
	title_row.add_theme_constant_override("separation", 16)
	box.add_child(title_row)

	var title_stack := VBoxContainer.new()
	title_stack.mouse_filter = Control.MOUSE_FILTER_PASS
	title_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_stack.add_theme_constant_override("separation", 5)
	title_row.add_child(title_stack)

	var title := _make_label("ACTIVE BODIES", 54, _theme_text_color(), HORIZONTAL_ALIGNMENT_LEFT, false)
	title.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	title_stack.add_child(title)

	var underline := ColorRect.new()
	underline.custom_minimum_size = Vector2(_measure_title_width("ACTIVE BODIES", 54), 4)
	underline.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	underline.color = _theme_line_color()
	underline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_stack.add_child(underline)
	_lines.append(underline)

	var tag_panel := PanelContainer.new()
	tag_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag_panel.add_theme_stylebox_override("panel", _active_bodies_counter_style())
	title_row.add_child(tag_panel)

	_system_bodies_count_label = _make_label("--", 31, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, false)
	_system_bodies_count_label.custom_minimum_size = Vector2(138, 62)
	_panel_margin(tag_panel, 14, 6, 14, 6).add_child(_system_bodies_count_label)

	_system_bodies_list = VBoxContainer.new()
	_system_bodies_list.name = "ActiveBodiesList"
	_system_bodies_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_system_bodies_list.mouse_filter = Control.MOUSE_FILTER_PASS
	_system_bodies_list.add_theme_constant_override("separation", 10)
	box.add_child(_system_bodies_list)

	_rebuild_active_bodies_list([])


func _rebuild_active_bodies_list(raw_bodies: Array) -> void:
	if not is_instance_valid(_system_bodies_list):
		return

	for child in _system_bodies_list.get_children():
		child.queue_free()

	var bodies := _normalize_active_bodies(raw_bodies)

	if is_instance_valid(_system_bodies_count_label):
		_system_bodies_count_label.text = "%d BODIES" % bodies.size()

	if bodies.is_empty():
		_add_empty_active_body_row()
		return

	for body in bodies:
		_add_active_body_row(body)

func _normalize_active_bodies(raw_bodies: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []

	for i in range(raw_bodies.size()):
		var item = raw_bodies[i]

		if item is Dictionary:
			var body: Dictionary = item
			var name := str(body.get("name", body.get("title", body.get("id", body.get("instance_id", "Unknown body"))))).strip_edges()
			var body_type := str(body.get("type", body.get("category", body.get("object_category", body.get("archetype", body.get("preset", "planet")))))).strip_edges().to_lower()
			var order_index := int(body.get("order_index", i))

			if name.is_empty():
				name = "Unknown body"

			result.append({
				"name": name,
				"type": body_type,
				"order_index": order_index,
			})
		elif item != null:
			result.append({
				"name": str(item).strip_edges(),
				"type": "planet",
				"order_index": i,
			})

	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("order_index", 0)) < int(b.get("order_index", 0))
	)

	return result

func _add_empty_active_body_row() -> void:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size = Vector2(0, 108)
	panel.add_theme_stylebox_override("panel", _active_body_row_style())
	_system_bodies_list.add_child(panel)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)
	_panel_margin(panel, 18, 14, 18, 14).add_child(row)

	var marker := PanelContainer.new()
	marker.custom_minimum_size = Vector2(58, 58)
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marker.add_theme_stylebox_override("panel", _active_body_marker_style(Color(0.78, 0.78, 0.78, 1.0)))
	row.add_child(marker)

	_system_empty_bodies_label = _make_label("NO ACTIVE BODIES YET", 40, Color.BLACK, HORIZONTAL_ALIGNMENT_LEFT, false)
	_system_empty_bodies_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_system_empty_bodies_label.clip_text = true
	_system_empty_bodies_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(_system_empty_bodies_label)

	var hint := _make_label("ADD ONE", 30, Color.BLACK, HORIZONTAL_ALIGNMENT_RIGHT, false)
	hint.custom_minimum_size = Vector2(130, 0)
	row.add_child(hint)


func _add_active_body_row(body: Dictionary) -> void:
	var body_type := str(body.get("type", "planet")).strip_edges().to_lower()
	var body_name := str(body.get("name", "Unknown body")).strip_edges()

	if body_name.is_empty():
		body_name = "Unknown body"

	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size = Vector2(0, 104)
	panel.add_theme_stylebox_override("panel", _active_body_row_style())
	_system_bodies_list.add_child(panel)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)
	_panel_margin(panel, 18, 14, 18, 14).add_child(row)

	var marker_panel := PanelContainer.new()
	marker_panel.custom_minimum_size = Vector2(58, 58)
	marker_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marker_panel.add_theme_stylebox_override("panel", _active_body_marker_style(_body_type_color(body_type)))
	row.add_child(marker_panel)

	var label := _make_label(body_name.to_upper(), 42, Color.BLACK, HORIZONTAL_ALIGNMENT_LEFT, false)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(label)

	var type_label := _make_label(_body_type_label(body_type), 30, Color.BLACK, HORIZONTAL_ALIGNMENT_RIGHT, false)
	type_label.custom_minimum_size = Vector2(170, 0)
	type_label.clip_text = true
	type_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(type_label)


func _body_type_label(body_type: String) -> String:
	var key := body_type.strip_edges().to_lower()

	if key.contains("star") or key.contains("sun"):
		return "STAR"

	if key.contains("moon") or key.contains("satellite"):
		return "MOON"

	if key.contains("gas"):
		return "GAS"

	if key.contains("ice"):
		return "ICE"

	if key.contains("lava"):
		return "LAVA"

	return "PLANET"


func _active_bodies_from_feedback() -> Array:
	var possible_keys := ["active_bodies", "bodies", "objects", "body_list", "active_objects", "system_bodies"]

	for key in possible_keys:
		var raw: Variant = _system_feedback.get(key, [])

		if raw is Array:
			return raw

	return []

func _make_section(parent: VBoxContainer, node_name: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = node_name
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _section_panel_style())
	parent.add_child(panel)
	return panel


func _add_panel_header(parent: VBoxContainer, title_text: String, subtitle_text: String) -> void:
	_add_underlined_title(parent, title_text, 76, _theme_text_color())

	var subtitle := _make_highlighted_text_label(subtitle_text, 42, HORIZONTAL_ALIGNMENT_LEFT, _subtitle_highlights(title_text, subtitle_text))
	parent.add_child(subtitle)


func _add_simulation_panel_header(parent: VBoxContainer) -> void:
	_add_underlined_title(parent, "SIMULATION DATA", 76, Color.WHITE)

	var subtitle_text := "Shape how your galaxy moves: control time, orbital grip, anchoring, spacing, and trail memory from one clean control deck."
	var subtitle := _make_highlighted_text_label(subtitle_text, 42, HORIZONTAL_ALIGNMENT_LEFT, _subtitle_highlights("SIMULATION DATA", subtitle_text))
	parent.add_child(subtitle)


func _add_underlined_title(parent: VBoxContainer, title_text: String, font_size: int, color: Color) -> void:
	var title_stack := VBoxContainer.new()
	title_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_stack.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	title_stack.add_theme_constant_override("separation", 4)
	parent.add_child(title_stack)

	var title := _make_label(title_text, font_size, color, HORIZONTAL_ALIGNMENT_LEFT, false)
	title.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	title_stack.add_child(title)

	var underline := ColorRect.new()
	underline.custom_minimum_size = Vector2(_measure_title_width(title_text, font_size), 4)
	underline.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	underline.color = _theme_line_color()
	underline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_stack.add_child(underline)
	_lines.append(underline)


func _measure_title_width(text: String, font_size: int) -> float:
	if _app_font != null:
		return ceil(_app_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x)
	return ceil(float(text.length()) * float(font_size) * 0.58)


func _add_info_chip(parent: Control, title: String, value: String, color: Color) -> Label:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size = Vector2(0, 106)
	panel.add_theme_stylebox_override("panel", _system_metric_chip_style(color))
	parent.add_child(panel)

	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 2)
	_panel_margin(panel, 16, 12, 16, 14).add_child(box)

	var title_label := _make_label("%s:" % title, 28, color, HORIZONTAL_ALIGNMENT_CENTER, false)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(title_label)

	var value_label := _make_label(value, 36, _theme_text_color(), HORIZONTAL_ALIGNMENT_CENTER, true)
	value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(value_label)

	return value_label


func _add_stat_card(parent: Control, stat_key: String) -> void:
	var color := _stat_color(stat_key)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)
	parent.add_child(row)

	var title_text := str(STAT_TITLES.get(stat_key, stat_key)).to_upper()
	var title := _make_label(title_text, 40, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, false)
	title.custom_minimum_size = Vector2(340, 54)
	title.clip_text = true
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(title)

	var bar_back := PanelContainer.new()
	bar_back.custom_minimum_size = Vector2(0, 24)
	bar_back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_back.add_theme_stylebox_override("panel", _system_attribute_bar_back_style())
	row.add_child(bar_back)

	var fill := PanelContainer.new()
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fill.add_theme_stylebox_override("panel", _system_attribute_bar_fill_style(color))
	bar_back.add_child(fill)

	var value_label := _make_label("--", 40, color, HORIZONTAL_ALIGNMENT_RIGHT, false)
	value_label.custom_minimum_size = Vector2(82, 54)
	row.add_child(value_label)

	_stat_widgets[stat_key] = {
		"value": value_label,
		"bar": bar_back,
		"fill": fill,
		"color": color,
	}

	bar_back.resized.connect(func() -> void:
		_layout_stat_bar(stat_key)
	)

	call_deferred("_layout_stat_bar", stat_key)


func _add_slider(parent: VBoxContainer, label_text: String, property_name: String, min_value: float, max_value: float, step: float, default_value: float) -> void:
	var panel := PanelContainer.new()
	panel.name = "SliderPanel_%s" % property_name
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _slider_card_style())
	parent.add_child(panel)

	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 19)
	_panel_margin(panel, 22, 19, 22, 22).add_child(box)

	var top_row := HBoxContainer.new()
	top_row.mouse_filter = Control.MOUSE_FILTER_PASS
	top_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.alignment = BoxContainer.ALIGNMENT_CENTER
	top_row.add_theme_constant_override("separation", 14)
	box.add_child(top_row)

	var text_stack := VBoxContainer.new()
	text_stack.mouse_filter = Control.MOUSE_FILTER_PASS
	text_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_stack.add_theme_constant_override("separation", 0)
	top_row.add_child(text_stack)

	var label := _make_label(label_text, 51, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, false)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	text_stack.add_child(label)


	var value_label := _make_label(_format_slider_scale_raw(min_value, max_value, default_value), 50, _theme_accent_color(), HORIZONTAL_ALIGNMENT_RIGHT, false)
	value_label.custom_minimum_size = Vector2(152, 0)
	top_row.add_child(value_label)

	var slider := KnobOnlyHSlider.new()
	slider.name = "Slider_%s" % property_name
	slider.min_value = min_value
	slider.max_value = max_value
	slider.step = step
	slider.set_value_no_signal(clamp(default_value, min_value, max_value))
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size = Vector2(0, 86)
	_apply_slider_style(slider)
	slider.knob_drag_started.connect(func() -> void:
		_play_sfx("click")
	)
	slider.knob_drag_ended.connect(func() -> void:
		_play_sfx("click")
	)
	box.add_child(slider)

	_sliders[property_name] = slider
	_value_labels[property_name] = value_label

	slider.value_changed.connect(func(value: float) -> void:
		var final_value: float = value
		if property_name == "max_trail_points":
			final_value = int(round(value))
		_set_config_value(property_name, final_value)
		value_label.text = _format_slider_scale(slider, final_value)
	)

func _add_toggle(parent: Control, label_text: String, property_name: String, _description_text: String, show_underline: bool = true) -> void:
	var row := GalaxySettingToggleRow.new()
	row.name = "Toggle_%s" % property_name
	row.label_text = label_text
	row.row_height = toggle_row_height
	row.custom_minimum_size = Vector2(0, toggle_row_height)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.refresh_theme(_app_font, _theme_text_color(), _theme_accent_color(), _theme_line_color(), _theme_hover_color(), _theme_pressed_color())
	row.set_underline_visible(show_underline)
	parent.add_child(row)

	_toggles[property_name] = row

	row.value_changed.connect(func(enabled: bool) -> void:
		_play_sfx("toggle")
		_set_config_value(property_name, enabled)
	)


func _add_action_button(parent: VBoxContainer, title_text: String, _description_text: String, callback: Callable, show_underline: bool = true) -> void:
	var button := Button.new()
	button.name = "Command_%s" % title_text.to_lower().replace(" ", "_")
	button.text = ""
	button.custom_minimum_size = Vector2(0, toggle_row_height)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_PASS
	button.flat = true
	_update_action_button_styles(button)
	parent.add_child(button)
	_action_buttons.append(button)

	var label := _make_label(title_text, 54, _theme_text_color(), HORIZONTAL_ALIGNMENT_CENTER, false)
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.offset_left = 22
	label.offset_right = -22
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(label)
	label.resized.connect(func() -> void:
		if is_instance_valid(label):
			label.pivot_offset = label.size * 0.5
	)

	if show_underline:
		var line := ColorRect.new()
		line.anchor_left = 0.0
		line.anchor_right = 1.0
		line.anchor_top = 1.0
		line.anchor_bottom = 1.0
		line.offset_left = 0.0
		line.offset_right = 0.0
		line.offset_top = -5.0
		line.offset_bottom = 0.0
		line.color = _theme_line_color()
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(line)
		_lines.append(line)

	button.button_down.connect(func() -> void:
		_play_command_label_down(label)
	)
	button.button_up.connect(func() -> void:
		_play_command_label_up(label)
	)
	button.pressed.connect(callback)


func _play_command_label_down(label: Label) -> void:
	if _closing or _should_reduce_motion() or not is_instance_valid(label):
		return
	label.pivot_offset = label.size * 0.5
	_tween_command_label_scale(label, Vector2(0.88, 0.88), 0.055)


func _play_command_label_up(label: Label) -> void:
	if _closing or not is_instance_valid(label):
		return
	if _should_reduce_motion():
		label.scale = Vector2.ONE
		return
	label.pivot_offset = label.size * 0.5
	_tween_command_label_scale(label, Vector2(1.10, 1.10), 0.11)
	await get_tree().create_timer(0.11).timeout
	if is_instance_valid(label):
		_tween_command_label_scale(label, Vector2.ONE, 0.10)


func _tween_command_label_scale(label: Label, target_scale: Vector2, duration: float) -> void:
	if not is_instance_valid(label):
		return
	if _button_tween != null and _button_tween.is_valid():
		_button_tween.kill()
	_button_tween = create_tween()
	_button_tween.set_trans(Tween.TRANS_BACK)
	_button_tween.set_ease(Tween.EASE_OUT)
	_button_tween.tween_property(label, "scale", target_scale, duration)


func _make_label(text: String, font_size: int, color: Color, alignment: HorizontalAlignment, wrap: bool) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = alignment
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if wrap else TextServer.AUTOWRAP_OFF
	label.clip_text = false
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_app_font(label)
	return label


func _panel_margin(parent: Control, left: int, top: int, right: int, bottom: int) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", left)
	margin.add_theme_constant_override("margin_top", top)
	margin.add_theme_constant_override("margin_right", right)
	margin.add_theme_constant_override("margin_bottom", bottom)
	parent.add_child(margin)
	return margin


func _add_line_to(parent: VBoxContainer, height: int = 5) -> void:
	var line := ColorRect.new()
	line.custom_minimum_size = Vector2(0, height)
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.color = _theme_line_color()
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(line)
	_lines.append(line)


func _layout_stat_bar(stat_key: String) -> void:
	if not _stat_widgets.has(stat_key):
		return

	var item: Dictionary = _stat_widgets[stat_key]
	var bar_back: PanelContainer = item.get("bar") as PanelContainer
	var fill: Control = item.get("fill") as Control

	if not is_instance_valid(bar_back) or not is_instance_valid(fill):
		return

	var stats: Dictionary = _system_feedback.get("stats", {})
	var value := int(stats.get(stat_key, 0))
	var ratio: float = clamp(float(value) / 100.0, 0.0, 1.0)
	var inset := 3.0
	var available_width: float = max(bar_back.size.x - inset * 2.0, 0.0)
	var available_height: float = max(bar_back.size.y - inset * 2.0, 0.0)

	fill.position = Vector2(inset, inset)
	fill.size = Vector2(available_width * ratio, available_height)
	fill.visible = ratio > 0.0


func _apply_system_feedback_widgets() -> void:
	_refresh_dynamic_theme(false)

	if _system_feedback.is_empty():
		return

	var stats: Dictionary = _system_feedback.get("stats", {})
	var score: int = int(_system_feedback.get("system_score", 0))
	var grade := str(_system_feedback.get("grade", "--"))

	if is_instance_valid(_system_score_label):
		_system_score_label.text = str(score)
	if is_instance_valid(_system_grade_label):
		_system_grade_label.text = grade
	var object_count := int(_system_feedback.get("object_count", 0))
	if is_instance_valid(_system_profile_label):
		if object_count <= 0:
			_system_profile_label.text = "No active bodies yet. Add a star, planet, or moon to start reading the simulation."
		else:
			_system_profile_label.text = str(_system_feedback.get("profile", "Simulation is reading active bodies."))
	if is_instance_valid(_system_count_label):
		_system_count_label.text = "%d bodies" % object_count
	if is_instance_valid(_system_bodies_count_label):
		_system_bodies_count_label.text = "%d BODIES" % object_count
	if is_instance_valid(_system_balance_label):
		_system_balance_label.text = "%d / 100" % int(_system_feedback.get("balance", 0))
	if is_instance_valid(_system_pressure_label):
		_system_pressure_label.text = str(_system_feedback.get("pressure", "--"))
	if is_instance_valid(_system_mix_label):
		_system_mix_label.text = str(_system_feedback.get("mix", "--"))

	_rebuild_active_bodies_list(_active_bodies_from_feedback())

	for stat_key in STAT_KEYS:
		if not _stat_widgets.has(stat_key):
			continue
		var item: Dictionary = _stat_widgets[stat_key]
		var value_label: Label = item.get("value") as Label
		if is_instance_valid(value_label):
			value_label.text = str(int(stats.get(stat_key, 0)))
		_layout_stat_bar(stat_key)


func _add_line() -> void:
	_add_line_to(_content, 5)
