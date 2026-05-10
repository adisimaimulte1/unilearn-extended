extends Control
class_name PlanetCardDetails

signal back_requested

const PIXEL_PLANET_SCRIPT := preload("res://addons/UnilearnLib/nodes/UnilearnPixelPlanet2D.gd")
const FONT_PATH := "res://assets/fonts/JockeyOne-Regular.ttf"

const COLOR_PANEL := Color(0.0, 0.0, 0.0, 0.42)
const COLOR_PANEL_SOFT := Color(1.0, 1.0, 1.0, 0.045)
const COLOR_BORDER := Color(1.0, 1.0, 1.0, 0.92)
const COLOR_TEXT := Color.WHITE
const COLOR_MUTED := Color(0.72, 0.76, 0.84, 1.0)
const COLOR_FAINT := Color(1.0, 1.0, 1.0, 0.16)

var data: PlanetData

var _planet_node: Node2D
var _hero_area: Control
var _scroll: ScrollContainer
var _content: VBoxContainer
var _app_font: Font = null


func setup(value: PlanetData) -> void:
	data = value
	if is_inside_tree():
		_rebuild()


func _ready() -> void:
	_app_font = load(FONT_PATH) as Font
	_rebuild()


func _rebuild() -> void:
	if data == null:
		return

	_clear_children()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	_scroll = ScrollContainer.new()
	_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scroll.offset_left = 18
	_scroll.offset_top = 18
	_scroll.offset_right = -18
	_scroll.offset_bottom = -18
	_scroll.follow_focus = true
	add_child(_scroll)

	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 22)
	_scroll.add_child(_content)

	_add_header()
	_add_hero_planet()
	_add_description()
	_add_stats_grid()
	_add_features()
	_add_fact()
	_add_interactive_section()
	_add_footer()

	call_deferred("_center_hero_planet")


func _add_header() -> void:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 16)
	_content.add_child(row)

	var back := Button.new()
	back.text = "‹"
	back.custom_minimum_size = Vector2(66, 66)
	back.focus_mode = Control.FOCUS_NONE
	back.flat = true
	back.add_theme_font_size_override("font_size", 54)
	back.add_theme_color_override("font_color", COLOR_TEXT)
	back.add_theme_color_override("font_hover_color", COLOR_MUTED)
	back.add_theme_color_override("font_pressed_color", COLOR_MUTED)
	_apply_app_font(back)
	back.pressed.connect(func() -> void:
		back_requested.emit()
	)
	row.add_child(back)

	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_box.add_theme_constant_override("separation", 1)
	row.add_child(title_box)

	title_box.add_child(_make_label(data.name.to_upper(), 48, COLOR_TEXT, HORIZONTAL_ALIGNMENT_LEFT, false))
	title_box.add_child(_make_label(data.subtitle, 25, COLOR_MUTED, HORIZONTAL_ALIGNMENT_LEFT, true))


func _add_hero_planet() -> void:
	_hero_area = Control.new()
	_hero_area.custom_minimum_size = Vector2(0, 330)
	_hero_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_child(_hero_area)

	var frame := Panel.new()
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_theme_stylebox_override("panel", _panel_style(30, COLOR_PANEL_SOFT))
	_hero_area.add_child(frame)

	_planet_node = PIXEL_PLANET_SCRIPT.new()
	_planet_node.name = "HeroPlanet"
	_planet_node.z_index = 8
	_hero_area.add_child(_planet_node)

	_apply_planet_data(_planet_node, data, data.planet_radius_px)
	_hero_area.resized.connect(_center_hero_planet)


func _add_description() -> void:
	var panel := _make_panel()
	_content.add_child(panel)

	var margin := _panel_margin(panel, 24, 22, 24, 22)
	var label := _make_label(data.description, 25, COLOR_TEXT, HORIZONTAL_ALIGNMENT_LEFT, true)
	label.custom_minimum_size = Vector2(0, 96)
	margin.add_child(label)


func _add_stats_grid() -> void:
	var panel := _make_panel()
	_content.add_child(panel)

	var margin := _panel_margin(panel, 18, 18, 18, 18)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	margin.add_child(grid)

	_add_stat_item(grid, "Diameter", data.diameter_km)
	_add_stat_item(grid, "Mass", data.mass)
	_add_stat_item(grid, "Year", data.orbital_period)
	_add_stat_item(grid, "Day", data.rotation_period)
	_add_stat_item(grid, "Avg temp", data.average_temperature)
	_add_stat_item(grid, "Gravity", data.gravity)
	_add_stat_item(grid, "Moons", data.moons)
	_add_stat_item(grid, "Distance", data.distance_from_sun)


func _add_features() -> void:
	var panel := _make_panel()
	_content.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	_panel_margin(panel, 24, 22, 24, 24).add_child(box)

	box.add_child(_section_title("KEY FEATURES"))

	for feature in data.key_features:
		_add_feature_item(box, str(feature.get("title", "")), str(feature.get("text", "")))


func _add_fact() -> void:
	var panel := _make_panel()
	_content.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	_panel_margin(panel, 24, 22, 24, 24).add_child(box)

	box.add_child(_section_title(data.fun_fact_title.to_upper()))
	box.add_child(_make_label(data.fun_fact, 24, COLOR_TEXT, HORIZONTAL_ALIGNMENT_LEFT, true))


func _add_interactive_section() -> void:
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", 14)
	_content.add_child(section)

	section.add_child(_section_title("INTERACTIVE LEARNING"))
	_add_action_card(section, data.quiz_title, data.quiz_text, "Start quiz")
	_add_action_card(section, data.compare_title, data.compare_text, "Compare now")
	_add_action_card(section, data.missions_title, data.missions_text, "View missions")


func _add_footer() -> void:
	var footer := _make_label("AI can make mistakes. Verify important scientific information.", 18, COLOR_MUTED, HORIZONTAL_ALIGNMENT_CENTER, true)
	footer.custom_minimum_size = Vector2(0, 52)
	_content.add_child(footer)


func _center_hero_planet() -> void:
	if not is_instance_valid(_hero_area) or not is_instance_valid(_planet_node):
		return

	_planet_node.position = _hero_area.size * 0.5


func _add_stat_item(parent: GridContainer, title: String, value: String) -> void:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 102)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _panel_style(20, Color(1.0, 1.0, 1.0, 0.045), Color(1.0, 1.0, 1.0, 0.24), 2))
	parent.add_child(panel)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 4)
	_panel_margin(panel, 14, 10, 14, 10).add_child(box)

	box.add_child(_make_label(title.to_upper(), 18, COLOR_MUTED, HORIZONTAL_ALIGNMENT_CENTER, false))
	box.add_child(_make_label(value, 22, COLOR_TEXT, HORIZONTAL_ALIGNMENT_CENTER, true))


func _add_feature_item(parent: VBoxContainer, title: String, text: String) -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	parent.add_child(box)

	box.add_child(_make_label(title, 27, COLOR_TEXT, HORIZONTAL_ALIGNMENT_LEFT, true))
	box.add_child(_make_label(text, 22, COLOR_MUTED, HORIZONTAL_ALIGNMENT_LEFT, true))

	var line := ColorRect.new()
	line.custom_minimum_size = Vector2(0, 2)
	line.color = COLOR_FAINT
	parent.add_child(line)


func _add_action_card(parent: VBoxContainer, title: String, text: String, button_text: String) -> void:
	var panel := _make_panel()
	parent.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	_panel_margin(panel, 22, 20, 22, 20).add_child(box)

	box.add_child(_make_label(title, 27, COLOR_TEXT, HORIZONTAL_ALIGNMENT_LEFT, true))
	box.add_child(_make_label(text, 22, COLOR_MUTED, HORIZONTAL_ALIGNMENT_LEFT, true))

	var button := Button.new()
	button.text = button_text
	button.custom_minimum_size = Vector2(0, 54)
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 24)
	button.add_theme_color_override("font_color", COLOR_TEXT)
	button.add_theme_stylebox_override("normal", _button_style(false))
	button.add_theme_stylebox_override("hover", _button_style(true))
	button.add_theme_stylebox_override("pressed", _button_style(true))
	_apply_app_font(button)
	box.add_child(button)


func _section_title(value: String) -> Label:
	return _make_label(value, 30, COLOR_TEXT, HORIZONTAL_ALIGNMENT_LEFT, true)


func _make_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _panel_style(28, COLOR_PANEL))
	return panel


func _panel_margin(parent: Control, left: int, top: int, right: int, bottom: int) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", left)
	margin.add_theme_constant_override("margin_top", top)
	margin.add_theme_constant_override("margin_right", right)
	margin.add_theme_constant_override("margin_bottom", bottom)
	parent.add_child(margin)
	return margin


func _panel_style(radius: int, bg: Color, border: Color = COLOR_BORDER, border_width: int = 3) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.shadow_color = Color(0, 0, 0, 0.38)
	style.shadow_size = 12
	style.shadow_offset = Vector2(0, 4)
	return style


func _button_style(hovered: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1.0, 1.0, 1.0, 0.10 if hovered else 0.045)
	style.border_color = Color.WHITE
	style.set_border_width_all(3)
	style.set_corner_radius_all(18)
	return style


func _make_label(value: String, font_size: int, color: Color, alignment: HorizontalAlignment, wrap: bool) -> Label:
	var label := Label.new()
	label.text = value
	label.horizontal_alignment = alignment
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if wrap else TextServer.AUTOWRAP_OFF
	label.clip_text = false
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	_apply_app_font(label)
	return label


func _apply_planet_data(planet: Node2D, planet_data: PlanetData, radius: int) -> void:
	planet.set("preset", planet_data.planet_preset)
	planet.set("radius_px", radius)
	planet.set("render_pixels", planet_data.planet_pixels)
	planet.set("seed_value", planet_data.planet_seed)
	planet.set("turning_speed", planet_data.planet_turning_speed)
	planet.set("axial_tilt_deg", planet_data.planet_axial_tilt_deg)
	planet.set("debug_border_enabled", false)
	planet.set("draggable", false)
	planet.set("use_custom_colors", planet_data.use_custom_colors)
	planet.set("custom_colors", planet_data.custom_colors)

	if planet.has_method("rebuild"):
		planet.call("rebuild")


func _apply_app_font(control: Control) -> void:
	if _app_font != null:
		control.add_theme_font_override("font", _app_font)


func _clear_children() -> void:
	for child in get_children():
		child.queue_free()
