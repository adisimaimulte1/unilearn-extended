extends "res://app/ui/popups/galaxy_popup/GalaxyPopupMotion.gd"


func _panel_style() -> StyleBoxFlat:
	var key := "panel_planet_cards_shell"
	if _style_cache.has(key):
		return _style_cache[key]

	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_PANEL
	style.border_color = COLOR_BORDER
	style.set_border_width_all(5)
	style.set_corner_radius_all(44)
	style.shadow_color = Color(0, 0, 0, 0.64)
	style.shadow_size = 16
	style.shadow_offset = Vector2(0, 6)
	_style_cache[key] = style
	return style


func _control_style(bg: Color, border: Color, border_width: int = 4, radius: int = 34) -> StyleBoxFlat:
	var key := "control_%s_%s_%d_%d" % [str(bg), str(border), border_width, radius]
	if _style_cache.has(key):
		return _style_cache[key]

	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 28
	style.content_margin_right = 28
	style.content_margin_top = 24
	style.content_margin_bottom = 24
	_style_cache[key] = style
	return style


func _glass_panel_style() -> StyleBoxFlat:
	var key := "glass_panel"
	if _style_cache.has(key):
		return _style_cache[key]

	var style := StyleBoxFlat.new()
	style.bg_color = Color(1.0, 1.0, 1.0, 0.028)
	style.border_color = Color.WHITE
	style.set_border_width_all(4)
	style.set_corner_radius_all(38)
	style.shadow_color = Color(0, 0, 0, 0.42)
	style.shadow_size = 12
	style.shadow_offset = Vector2(0, 4)
	_style_cache[key] = style
	return style


func _section_panel_style() -> StyleBoxFlat:
	var key := "section_panel"
	if _style_cache.has(key):
		return _style_cache[key]

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.24)
	style.border_color = Color(1.0, 1.0, 1.0, 0.82)
	style.set_border_width_all(3)
	style.set_corner_radius_all(34)
	_style_cache[key] = style
	return style


func _hero_score_style() -> StyleBoxFlat:
	var key := "hero_score_%s" % str(_theme_accent_color())
	if _style_cache.has(key):
		return _style_cache[key]

	var style := StyleBoxFlat.new()
	style.bg_color = _theme_accent_color()
	style.border_color = Color.WHITE
	style.set_border_width_all(4)
	style.set_corner_radius_all(38)
	style.shadow_color = _theme_accent_color().darkened(0.65)
	style.shadow_size = 18
	style.shadow_offset = Vector2(0, 6)
	_style_cache[key] = style
	return style


func _metric_card_style(color: Color) -> StyleBoxFlat:
	var key := "metric_card_%s" % str(color)
	if _style_cache.has(key):
		return _style_cache[key]

	var style := StyleBoxFlat.new()
	style.bg_color = Color(1.0, 1.0, 1.0, 0.018)
	style.border_color = color.lerp(Color.WHITE, 0.20)
	style.set_border_width_all(3)
	style.set_corner_radius_all(30)
	_style_cache[key] = style
	return style


func _chip_style(color: Color, filled: bool = false) -> StyleBoxFlat:
	var key := "chip_%s_%s" % [str(color), str(filled)]
	if _style_cache.has(key):
		return _style_cache[key]

	var style := StyleBoxFlat.new()
	style.bg_color = color if filled else Color.TRANSPARENT
	style.border_color = color
	style.set_border_width_all(3)
	style.set_corner_radius_all(24)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	_style_cache[key] = style
	return style


func _slider_card_style() -> StyleBoxFlat:
	var key := "slider_card_large_%s" % str(_theme_accent_color())
	if _style_cache.has(key):
		return _style_cache[key]

	var style := StyleBoxFlat.new()
	style.bg_color = Color(1.0, 1.0, 1.0, 0.018)
	style.border_color = Color(1.0, 1.0, 1.0, 0.72)
	style.set_border_width_all(3)
	style.set_corner_radius_all(32)
	style.shadow_color = Color(0, 0, 0, 0.28)
	style.shadow_size = 8
	style.shadow_offset = Vector2(0, 3)
	_style_cache[key] = style
	return style


func _metric_bar_back_style() -> StyleBoxFlat:
	var key := "metric_bar_back"
	if _style_cache.has(key):
		return _style_cache[key]

	var style := StyleBoxFlat.new()
	style.bg_color = Color(1.0, 1.0, 1.0, 0.08)
	style.border_color = Color.TRANSPARENT
	style.set_border_width_all(0)
	style.set_corner_radius_all(999)
	_style_cache[key] = style
	return style


func _metric_bar_fill_style(color: Color) -> StyleBoxFlat:
	var key := "metric_bar_fill_%s" % str(color)
	if _style_cache.has(key):
		return _style_cache[key]

	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color.TRANSPARENT
	style.set_border_width_all(0)
	style.set_corner_radius_all(999)
	_style_cache[key] = style
	return style


func _theme_accent_color() -> Color:
	if _settings_node != null and _settings_node.has_method("get_accent_color"):
		return _settings_node.call("get_accent_color")
	return Color("#FFC62D")


func _theme_text_color() -> Color:
	return COLOR_TEXT


func _theme_subtitle_color() -> Color:
	return COLOR_SUBTITLE


func _theme_line_color() -> Color:
	return Color(1.0, 1.0, 1.0, 0.86)


func _theme_hover_color() -> Color:
	return Color(1.0, 1.0, 1.0, 0.055)


func _theme_pressed_color() -> Color:
	return Color(1.0, 0.78, 0.18, 0.14)


func _update_action_button_styles(button: Button = null) -> void:
	if not is_instance_valid(button):
		return

	var transparent := StyleBoxFlat.new()
	transparent.bg_color = Color.TRANSPARENT
	transparent.border_color = Color.TRANSPARENT
	transparent.set_border_width_all(0)
	transparent.set_corner_radius_all(0)
	transparent.content_margin_left = 0
	transparent.content_margin_right = 0
	transparent.content_margin_top = 0
	transparent.content_margin_bottom = 0

	button.add_theme_stylebox_override("normal", transparent)
	button.add_theme_stylebox_override("hover", transparent)
	button.add_theme_stylebox_override("pressed", transparent)
	button.add_theme_stylebox_override("focus", transparent)
	button.add_theme_stylebox_override("disabled", transparent)
	button.add_theme_color_override("font_color", _theme_text_color())
	button.add_theme_color_override("font_hover_color", _theme_text_color())
	button.add_theme_color_override("font_pressed_color", _theme_text_color())
	button.add_theme_color_override("font_disabled_color", COLOR_PLACEHOLDER)

func _tabs_shell_style() -> StyleBoxFlat:
	var key := "tabs_shell_%s" % str(_theme_panel_color())
	if _style_cache.has(key):
		return _style_cache[key]

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.26) if _theme_dark_mode() else Color(1.0, 1.0, 1.0, 0.10)
	style.border_color = Color.WHITE
	style.set_border_width_all(3)
	style.set_corner_radius_all(34)
	style.content_margin_left = 0
	style.content_margin_right = 0
	style.content_margin_top = 0
	style.content_margin_bottom = 0
	_style_cache[key] = style
	return style


func _tab_button_style(active: bool, hovered: bool = false) -> StyleBoxFlat:
	var key := "tab_%s_%s_%s" % [str(active), str(hovered), str(_theme_accent_color())]
	if _style_cache.has(key):
		return _style_cache[key]

	var style := StyleBoxFlat.new()

	if active:
		style.bg_color = _theme_accent_color().lightened(0.08 if hovered else 0.0)
		style.border_color = Color(0.0, 0.0, 0.0, 0.0)
		style.set_border_width_all(0)
	else:
		style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
		style.border_color = Color.WHITE
		style.set_border_width_all(3)

	style.set_corner_radius_all(22)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	_style_cache[key] = style
	return style


func _on_tab_button_down(button: Button) -> void:
	_on_button_down(button)


func _on_tab_button_up(button: Button) -> void:
	_on_button_up(button)


func _slider_track_style() -> StyleBoxFlat:
	var key := "xp_like_slider_track"
	if _style_cache.has(key):
		return _style_cache[key]

	var style := StyleBoxFlat.new()
	style.bg_color = Color.BLACK
	style.border_color = Color.WHITE
	style.set_border_width_all(6)
	style.set_corner_radius_all(999)
	style.content_margin_left = 0
	style.content_margin_right = 0
	style.content_margin_top = 24
	style.content_margin_bottom = 24
	_style_cache[key] = style
	return style


func _slider_grabber_area_style() -> StyleBoxFlat:
	var key := "xp_like_slider_fill"
	if _style_cache.has(key):
		return _style_cache[key]

	var style := StyleBoxFlat.new()
	style.bg_color = Color.WHITE
	style.border_color = Color.TRANSPARENT
	style.set_border_width_all(0)
	style.set_corner_radius_all(999)
	style.content_margin_left = 0
	style.content_margin_right = 0
	style.content_margin_top = 24
	style.content_margin_bottom = 24
	_style_cache[key] = style
	return style


func _apply_slider_style(slider: Control) -> void:
	if not is_instance_valid(slider):
		return

	slider.custom_minimum_size = Vector2(0, 96)
	slider.set("track_bg_color", Color.BLACK)
	slider.set("track_border_color", Color.WHITE)
	slider.set("track_border_width", 5.0)
	slider.set("track_height", 46.0)
	slider.set("knob_radius", 40.0)
	slider.set("grabber_hit_radius", 54.0)
	slider.set("knob_color", _theme_accent_color())
	slider.set("fill_color", Color.WHITE)
	slider.queue_redraw()


func _make_slider_grabber_texture(hovered: bool = false) -> Texture2D:
	var size := 104 if hovered else 96
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	var center := Vector2(size * 0.5, size * 0.5)
	var radius := float(size) * 0.44
	var color := _theme_accent_color().lightened(0.08) if hovered else _theme_accent_color()

	for y in range(size):
		for x in range(size):
			var p := Vector2(x + 0.5, y + 0.5)
			if p.distance_to(center) <= radius:
				image.set_pixel(x, y, color)

	return ImageTexture.create_from_image(image)


func _setup_dynamic_theme_refresh() -> void:
	if is_instance_valid(_theme_refresh_timer):
		return

	_theme_refresh_timer = Timer.new()
	_theme_refresh_timer.name = "GalaxyDynamicThemeRefreshTimer"
	_theme_refresh_timer.wait_time = 0.18
	_theme_refresh_timer.one_shot = false
	_theme_refresh_timer.autostart = true
	_theme_refresh_timer.timeout.connect(func() -> void:
		_refresh_dynamic_theme(false)
	)
	add_child(_theme_refresh_timer)
	_theme_refresh_timer.start()

func _refresh_dynamic_theme(force: bool = false) -> void:
	var accent_hex := _theme_accent_color().to_html(false)
	if not force and accent_hex == _last_theme_accent_hex:
		return

	_last_theme_accent_hex = accent_hex

	for item in _highlighted_text_labels:
		if not item is Dictionary:
			continue
		var label: RichTextLabel = item.get("label") as RichTextLabel
		if not is_instance_valid(label):
			continue
		_apply_highlighted_text_label(
			label,
			str(item.get("text", "")),
			int(item.get("alignment", HORIZONTAL_ALIGNMENT_LEFT)),
			item.get("highlights", [])
		)

	for item in _accent_panel_nodes:
		if not item is Dictionary:
			continue
		var panel: PanelContainer = item.get("panel") as PanelContainer
		if not is_instance_valid(panel):
			continue
		var style_id := str(item.get("style", "tile"))
		if style_id == "score_full":
			panel.add_theme_stylebox_override("panel", _system_score_full_row_style())
		else:
			panel.add_theme_stylebox_override("panel", _system_score_tile_style())

	_update_tab_styles()

	for property_name in _value_labels.keys():
		var value_label: Label = _value_labels[property_name] as Label
		if is_instance_valid(value_label):
			value_label.add_theme_color_override("font_color", _theme_accent_color())

	for property_name in _toggles.keys():
		var row = _toggles[property_name]
		if is_instance_valid(row):
			row.refresh_theme(_app_font, _theme_text_color(), _theme_accent_color(), _theme_line_color(), _theme_hover_color(), _theme_pressed_color())

func _register_accent_panel(panel: PanelContainer, style_id: String = "tile") -> void:
	if not is_instance_valid(panel):
		return
	_accent_panel_nodes.append({"panel": panel, "style": style_id})

func _system_score_shell_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.30)
	style.border_color = Color.WHITE
	style.set_border_width_all(3)
	style.set_corner_radius_all(30)
	style.content_margin_left = 0
	style.content_margin_right = 0
	style.content_margin_top = 0
	style.content_margin_bottom = 0
	return style

func _system_score_tile_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = _theme_accent_color()
	style.border_color = _theme_accent_color()
	style.set_border_width_all(0)
	style.set_corner_radius_all(28)
	style.content_margin_left = 0
	style.content_margin_right = 0
	style.content_margin_top = 0
	style.content_margin_bottom = 0
	return style

func _system_score_full_row_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = _theme_accent_color()
	style.border_color = Color.TRANSPARENT
	style.set_border_width_all(0)
	style.set_corner_radius_all(30)
	style.shadow_color = Color(0, 0, 0, 0.30)
	style.shadow_size = 14
	style.shadow_offset = Vector2(0, 5)
	style.content_margin_left = 0
	style.content_margin_right = 0
	style.content_margin_top = 0
	style.content_margin_bottom = 0
	return style

func _system_metric_chip_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.24)
	style.border_color = color
	style.set_border_width_all(2)
	style.set_corner_radius_all(24)
	style.content_margin_left = 0
	style.content_margin_right = 0
	style.content_margin_top = 0
	style.content_margin_bottom = 0
	return style

func _system_attribute_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color.BLACK
	style.border_color = Color.WHITE
	style.set_border_width_all(3)
	style.set_corner_radius_all(34)
	style.content_margin_left = 0
	style.content_margin_right = 0
	style.content_margin_top = 0
	style.content_margin_bottom = 0
	return style

func _system_attribute_bar_back_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.038, 0.048, 1.0)
	style.border_color = Color.TRANSPARENT
	style.set_border_width_all(0)
	style.set_corner_radius_all(999)
	style.shadow_size = 0
	style.shadow_color = Color.TRANSPARENT
	style.shadow_offset = Vector2.ZERO
	style.content_margin_left = 0
	style.content_margin_right = 0
	style.content_margin_top = 0
	style.content_margin_bottom = 0
	return style

func _system_attribute_bar_fill_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color.TRANSPARENT
	style.set_border_width_all(0)
	style.set_corner_radius_all(999)
	style.shadow_size = 0
	style.shadow_color = Color.TRANSPARENT
	style.shadow_offset = Vector2.ZERO
	style.content_margin_left = 0
	style.content_margin_right = 0
	style.content_margin_top = 0
	style.content_margin_bottom = 0
	return style

func _active_bodies_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.20)
	style.border_color = Color.WHITE
	style.set_border_width_all(3)
	style.set_corner_radius_all(30)
	style.shadow_color = Color(0, 0, 0, 0.24)
	style.shadow_size = 10
	style.shadow_offset = Vector2(0, 4)
	return style

func _active_bodies_counter_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color.BLACK
	style.border_color = Color.WHITE
	style.set_border_width_all(3)
	style.set_corner_radius_all(22)
	style.content_margin_left = 0
	style.content_margin_right = 0
	style.content_margin_top = 0
	style.content_margin_bottom = 0
	return style

func _active_body_row_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color.WHITE
	style.border_color = Color.WHITE
	style.set_border_width_all(0)
	style.set_corner_radius_all(24)
	style.content_margin_left = 0
	style.content_margin_right = 0
	style.content_margin_top = 0
	style.content_margin_bottom = 0
	return style

func _active_body_marker_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color.BLACK
	style.set_border_width_all(3)
	style.set_corner_radius_all(12)
	return style

func _body_type_color(body_type: String) -> Color:
	var key := body_type.strip_edges().to_lower()

	if key.contains("star") or key.contains("sun"):
		return Color("#FFE45C")

	if key.contains("moon") or key.contains("satellite"):
		return Color("#BFC2C7")

	if key.contains("lava") or key.contains("fire"):
		return Color("#FF9D42")

	if key.contains("ice") or key.contains("water") or key.contains("ocean"):
		return Color("#63D8FF")

	if key.contains("gas"):
		return Color("#B875FF")

	if key.contains("rock") or key.contains("planet") or key.contains("world"):
		return Color("#7DFF8A")

	return _theme_accent_color()
