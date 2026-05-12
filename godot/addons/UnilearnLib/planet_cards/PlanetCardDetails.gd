extends Control
class_name PlanetCardDetails

signal back_requested
signal add_planet_requested(data: PlanetData)
signal remove_planet_requested(data: PlanetData)

const PIXEL_PLANET_SCRIPT := preload("res://addons/UnilearnLib/nodes/UnilearnPixelPlanet2D.gd")
const FONT_PATH := "res://assets/fonts/JockeyOne-Regular.ttf"
const BACK_ARROW_TEXTURE_PATH := "res://assets/app/buttons/button_arrow.png"

const FALLBACK_ACCENT_DARK := Color("#B56CFF")
const FALLBACK_ACCENT_LIGHT := Color("#c89f39ff")

const COLOR_SCROLL_TRACK := Color(1.0, 1.0, 1.0, 0.06)
const COLOR_SCROLL_GRAB := Color(1.0, 1.0, 1.0, 0.34)
const COLOR_SCROLL_GRAB_HOVER := Color(1.0, 1.0, 1.0, 0.52)

const HERO_BODY_MAX_FILL := 0.88
const HERO_STAR_COUNT := 95
const HERO_STAR_SEED := 91283

const HERO_DRAG_DEADZONE := 10.0
const HERO_DRAG_TIME_SENSITIVITY := 0.012
const HERO_DRAG_MIN_DELTA := 0.05

const BACK_BUTTON_SIZE := Vector2(132, 132)
const BACK_ARROW_ICON_SIZE := Vector2(92, 92)
const ADD_BUTTON_SIZE := Vector2(250, 132)

const NAME_FONT_SIZE_MAX := 116
const NAME_FONT_SIZE_MIN := 52
const NAME_SIDE_PADDING := 20.0

const BUTTON_PRESS_SCALE := Vector2(0.88, 0.88)
const BUTTON_RELEASE_SCALE := Vector2(1.10, 1.10)
const BUTTON_DOWN_TIME := 0.055
const BUTTON_UP_TIME := 0.11
const BUTTON_SETTLE_TIME := 0.10

const TAB_OVERVIEW := "overview"
const TAB_DATA := "data"
const TAB_DISCOVERIES := "discoveries"
const TAB_TRAINING := "training"

var data: PlanetData

var _planet_node: Node2D
var _hero_area: Control
var _hero_stars: Control
var _hero_clip: Control
var _hero_scroll_locked := false

var _add_planet_button: Button
var _back_button: Control
var _back_icon: TextureRect
var _back_button_pressed := false
var _name_label: Label

var _scroll: ScrollContainer
var _scroll_margin: MarginContainer
var _content: VBoxContainer
var _app_font: Font = null

var _details_stack: VBoxContainer
var _details_tab_buttons: Dictionary = {}
var _selected_tab := TAB_OVERVIEW

var _scroll_pointer_id := -999
var _scroll_dragging := false
var _scroll_start_y := 0.0
var _scroll_last_y := 0.0
var _scroll_last_time := 0.0
var _scroll_velocity := 0.0
var _scroll_drag_deadzone := 8.0
var _scroll_wheel_impulse := 1450.0
var _scroll_friction := 7.5
var _scroll_max_velocity := 3900.0

var _hero_pointer_id := -999
var _hero_dragging := false
var _hero_drag_start := Vector2.ZERO
var _hero_last_drag_pos := Vector2.ZERO
var _hero_manual_animation_time := 0.0
var _hero_base_turning_speed := 0.0

var _planet_added := false
var _button_tweens: Dictionary = {}


func setup(value: PlanetData) -> void:
	data = value

	if is_inside_tree():
		call_deferred("_rebuild")


func _ready() -> void:
	_app_font = load(FONT_PATH) as Font
	_connect_settings_signal()
	call_deferred("_rebuild")


func _process(delta: float) -> void:
	_apply_scroll_inertia(delta)


func _input(event: InputEvent) -> void:
	if _handle_hero_input(event):
		return

	_handle_slippery_scroll_input(event)


func _connect_settings_signal() -> void:
	var settings := _settings_node()

	if settings == null:
		return

	if settings.has_signal("settings_changed"):
		var callable := Callable(self, "_on_settings_changed")

		if not settings.settings_changed.is_connected(callable):
			settings.settings_changed.connect(callable)


func _on_settings_changed() -> void:
	if is_inside_tree():
		_rebuild()


func _rebuild() -> void:
	if data == null:
		return

	_clear_children()

	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process(true)

	_hero_base_turning_speed = data.planet_turning_speed
	_selected_tab = TAB_OVERVIEW

	_scroll = ScrollContainer.new()
	_scroll.name = "PlanetDetailsScroll"
	_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scroll.offset_left = 18
	_scroll.offset_top = 18
	_scroll.offset_right = -18
	_scroll.offset_bottom = -18
	_scroll.follow_focus = true
	_scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
	_scroll.add_theme_constant_override("scrollbar_margin_left", 30)
	add_child(_scroll)

	_scroll_margin = MarginContainer.new()
	_scroll_margin.name = "DetailsScrollMargin"
	_scroll_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll_margin.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_scroll_margin.mouse_filter = Control.MOUSE_FILTER_PASS
	_scroll_margin.add_theme_constant_override("margin_right", 46)
	_scroll_margin.add_theme_constant_override("margin_bottom", 28)
	_scroll.add_child(_scroll_margin)

	_content = VBoxContainer.new()
	_content.name = "DetailsContent"
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_content.mouse_filter = Control.MOUSE_FILTER_PASS
	_content.add_theme_constant_override("separation", 36)
	_scroll_margin.add_child(_content)

	_add_header()
	_add_hero_planet()
	_add_learning_deck()
	_add_footer()

	call_deferred("_style_scroll_bar")
	call_deferred("_center_hero_planet")
	call_deferred("_fit_name_label_font_size")


func _add_header() -> void:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_theme_constant_override("separation", 26)
	_content.add_child(row)

	var back_center := CenterContainer.new()
	back_center.custom_minimum_size = BACK_BUTTON_SIZE
	back_center.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back_center.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	back_center.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_child(back_center)

	_back_button = Control.new()
	_back_button.name = "BackButton"
	_back_button.custom_minimum_size = BACK_BUTTON_SIZE
	_back_button.size = BACK_BUTTON_SIZE
	_back_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_back_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_back_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_back_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_back_button.draw.connect(_draw_back_button)
	_back_button.gui_input.connect(_on_back_button_gui_input)
	back_center.add_child(_back_button)

	_back_icon = TextureRect.new()
	_back_icon.name = "BackArrowIcon"
	_back_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_back_icon.texture = _load_texture(BACK_ARROW_TEXTURE_PATH)
	_back_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_back_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_back_icon.size = BACK_ARROW_ICON_SIZE
	_back_icon.position = (BACK_BUTTON_SIZE - BACK_ARROW_ICON_SIZE) * 0.5
	_back_icon.pivot_offset = BACK_ARROW_ICON_SIZE * 0.5
	_back_icon.rotation = -PI * 0.5
	_back_icon.modulate = Color.BLACK
	_back_button.add_child(_back_icon)

	_name_label = _make_label(data.name.to_upper(), NAME_FONT_SIZE_MAX, _text_color(), HORIZONTAL_ALIGNMENT_LEFT, false)
	_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_name_label)

	if not _name_label.resized.is_connected(Callable(self, "_fit_name_label_font_size")):
		_name_label.resized.connect(_fit_name_label_font_size)

	var add_center := CenterContainer.new()
	add_center.custom_minimum_size = ADD_BUTTON_SIZE
	add_center.size_flags_horizontal = Control.SIZE_SHRINK_END
	add_center.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	add_center.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_child(add_center)

	_add_planet_button = Button.new()
	_add_planet_button.name = "AddPlanetButton"
	_add_planet_button.text = "ADD"
	_add_planet_button.focus_mode = Control.FOCUS_NONE
	_add_planet_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_add_planet_button.custom_minimum_size = ADD_BUTTON_SIZE
	_add_planet_button.size = ADD_BUTTON_SIZE
	_add_planet_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_add_planet_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_add_planet_button.add_theme_font_size_override("font_size", 66)
	_apply_app_font(_add_planet_button)

	_add_planet_button.button_down.connect(func() -> void:
		_on_header_button_down(_add_planet_button)
	)

	_add_planet_button.button_up.connect(func() -> void:
		_on_header_button_up(_add_planet_button)
	)

	_add_planet_button.pressed.connect(_toggle_add_planet)

	add_center.add_child(_add_planet_button)
	_update_add_planet_button_style()


func _fit_name_label_font_size() -> void:
	if not is_instance_valid(_name_label):
		return

	var available_width: float = max(_name_label.size.x - (NAME_SIDE_PADDING * 2.0), 1.0)
	var font_size := NAME_FONT_SIZE_MAX

	while font_size > NAME_FONT_SIZE_MIN:
		if _get_text_width(_name_label.text, font_size) <= available_width:
			break

		font_size -= 1

	_name_label.add_theme_font_size_override("font_size", font_size)


func _get_text_width(text: String, font_size: int) -> float:
	if _app_font != null:
		return _app_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x

	return float(text.length() * font_size) * 0.58


func _draw_back_button() -> void:
	if not is_instance_valid(_back_button):
		return

	var rect := Rect2(Vector2.ZERO, _back_button.size)
	_back_button.draw_style_box(_white_button_style(_back_button_pressed), rect)


func _on_back_button_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_back_button_pressed = true
			_back_button.queue_redraw()
			_on_header_button_down(_back_button)
			get_viewport().set_input_as_handled()
		else:
			var inside := _back_button.get_global_rect().has_point(event.global_position)
			_back_button_pressed = false
			_back_button.queue_redraw()

			if inside:
				_on_header_button_up(_back_button)
				back_requested.emit()
			else:
				_tween_header_button_cancel(_back_button)

			get_viewport().set_input_as_handled()

		return

	if event is InputEventScreenTouch:
		if event.pressed:
			_back_button_pressed = true
			_back_button.queue_redraw()
			_on_header_button_down(_back_button)
			get_viewport().set_input_as_handled()
		else:
			var inside := _back_button.get_global_rect().has_point(event.position)
			_back_button_pressed = false
			_back_button.queue_redraw()

			if inside:
				_on_header_button_up(_back_button)
				back_requested.emit()
			else:
				_tween_header_button_cancel(_back_button)

			get_viewport().set_input_as_handled()

		return


func _add_hero_planet() -> void:
	_hero_area = Control.new()
	_hero_area.name = "HeroArea"
	_hero_area.custom_minimum_size = Vector2(0, 540)
	_hero_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hero_area.mouse_filter = Control.MOUSE_FILTER_PASS
	_hero_area.clip_contents = true
	_content.add_child(_hero_area)

	var background := Panel.new()
	background.name = "HeroBackground"
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.clip_contents = true
	background.add_theme_stylebox_override("panel", _panel_style(44, Color.BLACK, _transparent(), 0))
	_hero_area.add_child(background)

	_hero_clip = Control.new()
	_hero_clip.name = "HeroInnerClip"
	_hero_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hero_clip.clip_contents = true
	_hero_area.add_child(_hero_clip)

	_hero_stars = Control.new()
	_hero_stars.name = "HeroStaticStars"
	_hero_stars.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hero_stars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hero_stars.clip_contents = true
	_hero_stars.draw.connect(_draw_hero_stars)
	_hero_clip.add_child(_hero_stars)

	_planet_node = PIXEL_PLANET_SCRIPT.new()
	_planet_node.name = "HeroPlanet"
	_planet_node.z_index = 8
	_hero_clip.add_child(_planet_node)

	_apply_planet_data(_planet_node, data, data.planet_radius_px)

	var border := Panel.new()
	border.name = "HeroBorder"
	border.set_anchors_preset(Control.PRESET_FULL_RECT)
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	border.clip_contents = false
	border.z_index = 999
	border.add_theme_stylebox_override("panel", _hero_border_style())
	_hero_area.add_child(border)
	border.move_to_front()

	if not _hero_area.resized.is_connected(Callable(self, "_layout_hero_clip")):
		_hero_area.resized.connect(_layout_hero_clip)

	call_deferred("_layout_hero_clip")


func _hero_border_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()

	style.bg_color = _transparent()
	style.border_color = _line_color()
	style.set_border_width_all(5)
	style.set_corner_radius_all(44)

	style.shadow_color = _transparent()
	style.shadow_size = 0
	style.shadow_offset = Vector2.ZERO

	style.content_margin_left = 0
	style.content_margin_right = 0
	style.content_margin_top = 0
	style.content_margin_bottom = 0

	return style


func _layout_hero_clip() -> void:
	if not is_instance_valid(_hero_area):
		return

	var border_width := 5.0
	var safe_gap := 4.0
	var inset := border_width + safe_gap

	if is_instance_valid(_hero_clip):
		_hero_clip.position = Vector2(inset, inset)
		_hero_clip.size = Vector2(
			max(0.0, _hero_area.size.x - inset * 2.0),
			max(0.0, _hero_area.size.y - inset * 2.0)
		)

	if is_instance_valid(_hero_stars):
		_hero_stars.queue_redraw()

	_center_hero_planet()


func _add_learning_deck() -> void:
	var deck := PanelContainer.new()
	deck.name = "LearningDeck"
	deck.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	deck.mouse_filter = Control.MOUSE_FILTER_PASS
	deck.add_theme_stylebox_override("panel", _panel_style(42, _panel_color(), _line_color(), 3))
	_content.add_child(deck)

	var margin := _panel_margin(deck, 24, 24, 24, 30)

	var box := VBoxContainer.new()
	box.name = "LearningDeckContent"
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	box.add_theme_constant_override("separation", 32)
	margin.add_child(box)

	_add_deck_intro(box)
	_add_tab_selector(box)

	_details_stack = VBoxContainer.new()
	_details_stack.name = "DetailsTabStack"
	_details_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_details_stack.mouse_filter = Control.MOUSE_FILTER_PASS
	_details_stack.add_theme_constant_override("separation", 30)
	box.add_child(_details_stack)

	_set_details_tab(TAB_OVERVIEW)


func _add_deck_intro(parent: VBoxContainer) -> void:
	var top := VBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_PASS
	top.add_theme_constant_override("separation", 14)
	parent.add_child(top)

	top.add_child(_make_label(_guide_label(), 38, _accent_color(), HORIZONTAL_ALIGNMENT_LEFT, false))

	var subtitle := _make_label(data.subtitle, 58, _text_color(), HORIZONTAL_ALIGNMENT_LEFT, true)
	subtitle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(subtitle)

	var underline_width := min(
		_get_text_width(data.subtitle, 58),
		max(size.x - 120.0, 260.0)
	)

	var underline := ColorRect.new()
	underline.custom_minimum_size = Vector2(underline_width, 6)
	underline.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	underline.color = Color.WHITE
	underline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(underline)

	top.add_child(_make_label(_make_intro_hint(), 42, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, true))


func _guide_label() -> String:
	match _object_category():
		"star":
			return "STELLAR FIELD GUIDE"
		"moon":
			return "SATELLITE FIELD GUIDE"
		"dwarf_planet":
			return "DWARF WORLD FIELD GUIDE"
		_:
			return "PLANET FIELD GUIDE"


func _make_intro_hint() -> String:
	match _object_category():
		"star":
			return "Study %s as a stellar engine: how it produces energy, shapes nearby orbits, and controls the environment around it." % data.name
		"moon":
			return "Study %s as a natural satellite: its parent body, surface story, orbital behavior, and what it reveals about its local system." % data.name
		"dwarf_planet":
			return "Study %s as a small planetary world: its orbit, surface chemistry, formation clues, and why it matters beyond the major planets." % data.name
		_:
			if data.archetype_id.contains("gas") or data.archetype_id.contains("ice"):
				return "Study %s as a giant world: its atmosphere, deep interior, rings or moons, and the forces that shape its system." % data.name

			return "Study %s as a planetary world: its surface, atmosphere, rotation, environment, and the clues it gives about planet formation." % data.name


func _add_tab_selector(parent: VBoxContainer) -> void:
	_details_tab_buttons.clear()

	var rail := HBoxContainer.new()
	rail.name = "DetailsTabSelector"
	rail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rail.mouse_filter = Control.MOUSE_FILTER_PASS
	rail.add_theme_constant_override("separation", 14)
	parent.add_child(rail)

	_add_tab_button(rail, TAB_OVERVIEW, "PREVIEW")
	_add_tab_button(rail, TAB_DATA, "DATA")
	_add_tab_button(rail, TAB_DISCOVERIES, "DISCOVER")
	_add_tab_button(rail, TAB_TRAINING, "TRAIN")


func _add_tab_button(parent: HBoxContainer, tab_id: String, text: String) -> void:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.custom_minimum_size = Vector2(0, 96)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 38)
	_apply_app_font(button)

	button.button_down.connect(func() -> void:
		_on_header_button_down(button)
	)

	button.button_up.connect(func() -> void:
		_on_header_button_up(button)
	)

	button.pressed.connect(func() -> void:
		_set_details_tab(tab_id)
	)

	parent.add_child(button)
	_details_tab_buttons[tab_id] = button


func _set_details_tab(tab_id: String) -> void:
	_selected_tab = tab_id
	_update_tab_button_styles()

	if not is_instance_valid(_details_stack):
		return

	for child in _details_stack.get_children():
		child.queue_free()

	if tab_id == TAB_DATA:
		_build_data_tab(_details_stack)
	elif tab_id == TAB_DISCOVERIES:
		_build_discoveries_tab(_details_stack)
	elif tab_id == TAB_TRAINING:
		_build_training_tab(_details_stack)
	else:
		_build_overview_tab(_details_stack)

	if is_instance_valid(_scroll):
		_scroll_velocity = 0.0


func _update_tab_button_styles() -> void:
	for tab_id in _details_tab_buttons.keys():
		var button: Button = _details_tab_buttons[tab_id]

		if not is_instance_valid(button):
			continue

		var selected: int = tab_id == _selected_tab
		var font_color := Color.BLACK if selected else Color.WHITE

		button.add_theme_color_override("font_color", font_color)
		button.add_theme_color_override("font_hover_color", font_color)
		button.add_theme_color_override("font_pressed_color", font_color)
		button.add_theme_stylebox_override("normal", _tab_button_style(selected, false))
		button.add_theme_stylebox_override("hover", _tab_button_style(selected, true))
		button.add_theme_stylebox_override("pressed", _tab_button_style(selected, true))


func _build_overview_tab(parent: VBoxContainer) -> void:
	_add_highlight_description(parent)
	_add_overview_points(parent)
	_add_fact()


func _build_data_tab(parent: VBoxContainer) -> void:
	_add_stats_grid()
	_add_environment_block(parent)


func _build_discoveries_tab(parent: VBoxContainer) -> void:
	_add_features()
	_add_missions_block(parent)


func _build_training_tab(parent: VBoxContainer) -> void:
	_add_interactive_section()
	_add_learning_prompts(parent)


func _add_highlight_description(parent: VBoxContainer) -> void:
	var panel := _make_panel(_soft_panel_color(), _accent_color(), 0)
	parent.add_child(panel)

	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	box.add_theme_constant_override("separation", 24)
	_panel_margin(panel, 36, 34, 36, 38).add_child(box)

	box.add_child(_section_title("FIRST LOOK"))

	var rich := RichTextLabel.new()
	rich.name = "HighlightedDescription"
	rich.bbcode_enabled = true
	rich.fit_content = true
	rich.scroll_active = false
	rich.selection_enabled = false
	rich.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rich.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rich.add_theme_font_size_override("normal_font_size", 54)
	rich.add_theme_color_override("default_color", _text_color())
	_apply_app_font(rich)
	rich.text = _build_highlighted_description_bbcode()
	box.add_child(rich)

	var beam := ColorRect.new()
	beam.custom_minimum_size = Vector2(0, 6)
	beam.color = Color.WHITE
	beam.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(beam)


func _add_overview_points(parent: VBoxContainer) -> void:
	var points := data.overview_points

	if points.is_empty():
		points = _fallback_overview_points()

	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.mouse_filter = Control.MOUSE_FILTER_PASS
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 18)
	parent.add_child(grid)

	for point in points:
		_add_overview_card(grid, str(point.get("title", "")), str(point.get("text", "")))


func _add_overview_card(parent: GridContainer, title: String, text: String) -> void:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 190)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.add_theme_stylebox_override(
		"panel",
		_panel_style(
			30,
			Color(0.0, 0.0, 0.0, 0.18) if _dark_mode() else Color(1.0, 1.0, 1.0, 0.10),
			Color.WHITE,
			3
		)
	)
	parent.add_child(panel)

	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	box.add_theme_constant_override("separation", 10)
	_panel_margin(panel, 24, 22, 24, 22).add_child(box)

	box.add_child(_make_label(title.to_upper(), 34, _accent_color(), HORIZONTAL_ALIGNMENT_LEFT, true))
	box.add_child(_make_label(text, 44, _text_color(), HORIZONTAL_ALIGNMENT_LEFT, true))


func _add_stats_grid() -> void:
	var parent := _details_stack if is_instance_valid(_details_stack) else _content

	var panel := _make_panel(Color.BLACK, Color.WHITE, 3)
	parent.add_child(panel)

	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	box.add_theme_constant_override("separation", 30)
	_panel_margin(panel, 30, 30, 30, 34).add_child(box)

	var title_row := HBoxContainer.new()
	title_row.mouse_filter = Control.MOUSE_FILTER_PASS
	title_row.alignment = BoxContainer.ALIGNMENT_CENTER
	title_row.add_theme_constant_override("separation", 18)
	box.add_child(title_row)

	var title := _section_title(_data_section_title())
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title)

	var tag := _make_label(_object_category().replace("_", " ").to_upper(), 34, Color.BLACK, HORIZONTAL_ALIGNMENT_CENTER, false)
	tag.custom_minimum_size = Vector2(230, 72)

	var tag_panel := PanelContainer.new()
	tag_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	tag_panel.add_theme_stylebox_override("panel", _panel_style(22, Color.WHITE, Color.WHITE, 0))
	title_row.add_child(tag_panel)
	_panel_margin(tag_panel, 18, 8, 18, 8).add_child(tag)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.mouse_filter = Control.MOUSE_FILTER_PASS
	grid.add_theme_constant_override("h_separation", 22)
	grid.add_theme_constant_override("v_separation", 22)
	box.add_child(grid)

	var items := _data_items()

	for i in range(items.size()):
		var item: Dictionary = items[i]
		_add_stat_item(grid, str(item.get("title", "")), str(item.get("value", "")), i)
	

func _data_section_title() -> String:
	match _object_category():
		"star":
			return "STELLAR DATA"
		"moon":
			return "SATELLITE DATA"
		"dwarf_planet":
			return "DWARF WORLD DATA"
		_:
			return "PLANET DATA"


func _data_items() -> Array[Dictionary]:
	if not data.data_cards.is_empty():
		return data.data_cards

	match _object_category():
		"star":
			return [
				{"title": "Diameter", "value": data.diameter_km},
				{"title": "Mass", "value": data.mass},
				{"title": "Rotation", "value": data.rotation_period},
				{"title": "Temperature", "value": data.average_temperature},
				{"title": "Planets", "value": data.moons},
				{"title": "Galactic orbit", "value": data.orbital_period},
			]
		"moon":
			return [
				{"title": "Parent", "value": _value_or_unknown(data.parent_object)},
				{"title": "Diameter", "value": data.diameter_km},
				{"title": "Mass", "value": data.mass},
				{"title": "Gravity", "value": data.gravity},
				{"title": "Orbit", "value": data.orbital_period},
				{"title": "Surface", "value": _value_or_unknown(data.surface_geology)},
			]
		_:
			return [
				{"title": "Diameter", "value": data.diameter_km},
				{"title": "Mass", "value": data.mass},
				{"title": "Gravity", "value": data.gravity},
				{"title": "Rotation", "value": data.rotation_period},
				{"title": "Orbit", "value": data.orbital_period},
				{"title": _satellite_field_title(), "value": data.moons},
			]


func _add_environment_block(parent: VBoxContainer) -> void:
	var panel := _make_panel(Color.BLACK, Color.WHITE, 3)
	parent.add_child(panel)

	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	box.add_theme_constant_override("separation", 28)
	_panel_margin(panel, 34, 34, 34, 36).add_child(box)

	box.add_child(_section_title("ENVIRONMENT PROFILE"))

	var intro := _make_label(
		"Physical context, structure, and conditions that explain what this object is like beyond the raw numbers.",
		42,
		Color.WHITE,
		HORIZONTAL_ALIGNMENT_LEFT,
		true
	)
	box.add_child(intro)

	var line := ColorRect.new()
	line.custom_minimum_size = Vector2(0, 5)
	line.color = Color.WHITE
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(line)

	var items := _environment_items()

	for item in items:
		_add_environment_item(box, str(item.get("title", "")), str(item.get("text", "")))


func _add_environment_item(parent: VBoxContainer, title: String, text: String) -> void:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.add_theme_stylebox_override("panel", _panel_style(26, Color(0.0, 0.0, 0.0, 0.24), Color.WHITE, 2))
	parent.add_child(panel)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_theme_constant_override("separation", 22)
	_panel_margin(panel, 24, 22, 24, 24).add_child(row)

	var number_block := PanelContainer.new()
	number_block.custom_minimum_size = Vector2(96, 96)
	number_block.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	number_block.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	number_block.mouse_filter = Control.MOUSE_FILTER_IGNORE
	number_block.add_theme_stylebox_override("panel", _panel_style(24, Color.WHITE, Color.WHITE, 0))
	row.add_child(number_block)

	var short := title.substr(0, 1).to_upper()
	var letter := _make_label(short, 52, Color.BLACK, HORIZONTAL_ALIGNMENT_CENTER, false)
	_panel_margin(number_block, 0, 0, 0, 0).add_child(letter)

	var text_box := VBoxContainer.new()
	text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_box.mouse_filter = Control.MOUSE_FILTER_PASS
	text_box.add_theme_constant_override("separation", 8)
	row.add_child(text_box)

	text_box.add_child(_make_label(title.to_upper(), 36, _accent_color(), HORIZONTAL_ALIGNMENT_LEFT, true))
	text_box.add_child(_make_label(text, 46, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, true))


func _environment_items() -> Array[Dictionary]:
	var result: Array[Dictionary] = []

	if not data.composition.is_empty():
		result.append({"title": "Composition", "text": data.composition})

	if not data.atmosphere.is_empty():
		result.append({"title": "Atmosphere", "text": data.atmosphere})

	if not data.surface_geology.is_empty():
		result.append({"title": "Surface / Structure", "text": data.surface_geology})

	if not data.magnetic_field.is_empty():
		result.append({"title": "Magnetic Field", "text": data.magnetic_field})

	if not data.ring_system.is_empty():
		result.append({"title": "Ring System", "text": data.ring_system})

	if not data.habitability_note.is_empty():
		result.append({"title": "Habitability", "text": data.habitability_note})

	if result.is_empty():
		result.append({"title": "Profile", "text": "No extended environment profile is available yet."})

	return result


func _add_features() -> void:
	var parent := _details_stack if is_instance_valid(_details_stack) else _content

	var panel := _make_panel(Color.BLACK, Color.WHITE, 3)
	parent.add_child(panel)

	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	box.add_theme_constant_override("separation", 30)
	_panel_margin(panel, 34, 34, 34, 38).add_child(box)

	var title_row := HBoxContainer.new()
	title_row.mouse_filter = Control.MOUSE_FILTER_PASS
	title_row.alignment = BoxContainer.ALIGNMENT_CENTER
	title_row.add_theme_constant_override("separation", 18)
	box.add_child(title_row)

	var title := _section_title("DISCOVERY MAP")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title)

	var tag_panel := PanelContainer.new()
	tag_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	tag_panel.add_theme_stylebox_override("panel", _panel_style(22, Color.WHITE, Color.WHITE, 0))
	title_row.add_child(tag_panel)

	var tag := _make_label("SCIENCE", 34, Color.BLACK, HORIZONTAL_ALIGNMENT_CENTER, false)
	tag.custom_minimum_size = Vector2(210, 72)
	_panel_margin(tag_panel, 18, 8, 18, 8).add_child(tag)

	var intro := _make_label(
		"Not just facts — these are the clues scientists use to understand how this object formed, changed, and interacts with its system.",
		44,
		Color.WHITE,
		HORIZONTAL_ALIGNMENT_LEFT,
		true
	)
	box.add_child(intro)

	var line := ColorRect.new()
	line.custom_minimum_size = Vector2(0, 5)
	line.color = Color.WHITE
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(line)

	var features := data.key_features

	for i in range(features.size()):
		var feature: Dictionary = features[i]
		_add_discovery_item(
			box,
			i + 1,
			str(feature.get("title", "")),
			str(feature.get("text", ""))
		)


func _add_discovery_item(parent: VBoxContainer, number: int, title: String, text: String) -> void:
	var row_panel := PanelContainer.new()
	row_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	row_panel.add_theme_stylebox_override(
		"panel",
		_panel_style(30, Color(0.0, 0.0, 0.0, 0.22), Color.WHITE, 3)
	)
	parent.add_child(row_panel)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_theme_constant_override("separation", 24)
	_panel_margin(row_panel, 24, 24, 24, 26).add_child(row)

	var number_column := VBoxContainer.new()
	number_column.custom_minimum_size = Vector2(120, 0)
	number_column.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	number_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	number_column.alignment = BoxContainer.ALIGNMENT_CENTER
	number_column.mouse_filter = Control.MOUSE_FILTER_PASS
	number_column.add_theme_constant_override("separation", 12)
	row.add_child(number_column)

	var number_panel := PanelContainer.new()
	number_panel.custom_minimum_size = Vector2(100, 100)
	number_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	number_panel.add_theme_stylebox_override("panel", _panel_style(999, Color.WHITE, Color.WHITE, 0))
	number_column.add_child(number_panel)

	var number_label := _make_label(str(number).pad_zeros(2), 42, Color.BLACK, HORIZONTAL_ALIGNMENT_CENTER, false)
	_panel_margin(number_panel, 0, 0, 0, 0).add_child(number_label)

	var vertical_line := ColorRect.new()
	vertical_line.custom_minimum_size = Vector2(5, 72)
	vertical_line.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vertical_line.color = Color.WHITE
	vertical_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	number_column.add_child(vertical_line)

	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.mouse_filter = Control.MOUSE_FILTER_PASS
	content.add_theme_constant_override("separation", 12)
	row.add_child(content)

	content.add_child(_make_label(title.to_upper(), 46, _accent_color(), HORIZONTAL_ALIGNMENT_LEFT, true))

	var text_label := _make_label(text, 46, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, true)
	text_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(text_label)

	var bottom_row := HBoxContainer.new()
	bottom_row.mouse_filter = Control.MOUSE_FILTER_PASS
	bottom_row.add_theme_constant_override("separation", 12)
	content.add_child(bottom_row)

	var chip_1 := _discovery_chip("OBSERVE")
	var chip_2 := _discovery_chip("ANALYZE")
	var chip_3 := _discovery_chip("CONNECT")

	bottom_row.add_child(chip_1)
	bottom_row.add_child(chip_2)
	bottom_row.add_child(chip_3)


func _discovery_chip(text: String) -> PanelContainer:
	var chip := PanelContainer.new()
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_theme_stylebox_override("panel", _panel_style(18, Color.TRANSPARENT, Color.WHITE, 2))

	var label := _make_label(text, 26, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, false)
	label.custom_minimum_size = Vector2(130, 48)
	_panel_margin(chip, 10, 4, 10, 4).add_child(label)

	return chip


func _add_missions_block(parent: VBoxContainer) -> void:
	var panel := _make_panel(Color.BLACK, Color.WHITE, 3)
	parent.add_child(panel)

	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	box.add_theme_constant_override("separation", 28)
	_panel_margin(panel, 34, 34, 34, 38).add_child(box)

	var title_row := HBoxContainer.new()
	title_row.mouse_filter = Control.MOUSE_FILTER_PASS
	title_row.alignment = BoxContainer.ALIGNMENT_CENTER
	title_row.add_theme_constant_override("separation", 18)
	box.add_child(title_row)

	var title := _section_title(data.missions_title.to_upper())
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title)

	var orbit_tag_panel := PanelContainer.new()
	orbit_tag_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	orbit_tag_panel.add_theme_stylebox_override("panel", _panel_style(22, _accent_color(), _accent_color(), 0))
	title_row.add_child(orbit_tag_panel)

	var orbit_tag := _make_label("MISSIONS", 34, Color.BLACK, HORIZONTAL_ALIGNMENT_CENTER, false)
	orbit_tag.custom_minimum_size = Vector2(230, 72)
	_panel_margin(orbit_tag_panel, 18, 8, 18, 8).add_child(orbit_tag)

	var timeline := HBoxContainer.new()
	timeline.mouse_filter = Control.MOUSE_FILTER_PASS
	timeline.add_theme_constant_override("separation", 18)
	box.add_child(timeline)

	_add_mission_step(timeline, "01", "Observe", "Capture light, motion, weather, or surface details.")
	_add_mission_step(timeline, "02", "Measure", "Convert observations into useful scientific data.")
	_add_mission_step(timeline, "03", "Explain", "Use the data to model origin, structure, and change.")

	var mission_text_panel := PanelContainer.new()
	mission_text_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mission_text_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	mission_text_panel.add_theme_stylebox_override("panel", _panel_style(28, Color(0.0, 0.0, 0.0, 0.26), Color.WHITE, 3))
	box.add_child(mission_text_panel)

	var mission_box := VBoxContainer.new()
	mission_box.mouse_filter = Control.MOUSE_FILTER_PASS
	mission_box.add_theme_constant_override("separation", 14)
	_panel_margin(mission_text_panel, 26, 24, 26, 26).add_child(mission_box)

	mission_box.add_child(_make_label("MISSION RECORD", 38, _accent_color(), HORIZONTAL_ALIGNMENT_LEFT, true))
	mission_box.add_child(_make_label(data.missions_text, 46, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, true))

	if not data.discovery_note.is_empty():
		var context_line := ColorRect.new()
		context_line.custom_minimum_size = Vector2(0, 5)
		context_line.color = Color.WHITE
		context_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mission_box.add_child(context_line)

		mission_box.add_child(_make_label("DISCOVERY CONTEXT", 38, _accent_color(), HORIZONTAL_ALIGNMENT_LEFT, true))
		mission_box.add_child(_make_label(data.discovery_note, 44, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, true))


func _add_mission_step(parent: HBoxContainer, number: String, title: String, text: String) -> void:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 210)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.add_theme_stylebox_override("panel", _panel_style(28, Color.TRANSPARENT, Color.WHITE, 3))
	parent.add_child(panel)

	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 10)
	_panel_margin(panel, 20, 18, 20, 20).add_child(box)

	box.add_child(_make_label(number, 48, _accent_color(), HORIZONTAL_ALIGNMENT_CENTER, false))

	var divider := ColorRect.new()
	divider.custom_minimum_size = Vector2(0, 4)
	divider.color = Color.WHITE
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(divider)

	box.add_child(_make_label(title.to_upper(), 34, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, true))
	box.add_child(_make_label(text, 31, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, true))


func _add_fact() -> void:
	var parent := _details_stack if is_instance_valid(_details_stack) else _content

	var panel := _make_panel(_accent_color(), _transparent(), 0)
	parent.add_child(panel)

	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	box.add_theme_constant_override("separation", 24)
	_panel_margin(panel, 36, 34, 36, 38).add_child(box)

	box.add_child(_make_label(data.fun_fact_title.to_upper(), 58, Color.BLACK, HORIZONTAL_ALIGNMENT_LEFT, true))
	box.add_child(_make_label(data.fun_fact, 48, Color.BLACK, HORIZONTAL_ALIGNMENT_LEFT, true))


func _add_interactive_section() -> void:
	var parent := _details_stack if is_instance_valid(_details_stack) else _content

	var panel := _make_panel(Color.BLACK, Color.WHITE, 3)
	parent.add_child(panel)

	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	box.add_theme_constant_override("separation", 30)
	_panel_margin(panel, 34, 34, 34, 38).add_child(box)

	var title_row := HBoxContainer.new()
	title_row.mouse_filter = Control.MOUSE_FILTER_PASS
	title_row.alignment = BoxContainer.ALIGNMENT_CENTER
	title_row.add_theme_constant_override("separation", 18)
	box.add_child(title_row)

	var title := _section_title("TRAINING DECK")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title)

	var tag_panel := PanelContainer.new()
	tag_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	tag_panel.add_theme_stylebox_override("panel", _panel_style(22, _accent_color(), _accent_color(), 0))
	title_row.add_child(tag_panel)

	var tag := _make_label("ACTIVE", 34, Color.BLACK, HORIZONTAL_ALIGNMENT_CENTER, false)
	tag.custom_minimum_size = Vector2(190, 72)
	_panel_margin(tag_panel, 18, 8, 18, 8).add_child(tag)

	var intro := _make_label(
		"Turn this object into something you can actually remember: test, compare, then connect it to exploration.",
		44,
		Color.WHITE,
		HORIZONTAL_ALIGNMENT_LEFT,
		true
	)
	box.add_child(intro)

	var line := ColorRect.new()
	line.custom_minimum_size = Vector2(0, 5)
	line.color = Color.WHITE
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(line)

	var actions := HBoxContainer.new()
	actions.mouse_filter = Control.MOUSE_FILTER_PASS
	actions.add_theme_constant_override("separation", 18)
	box.add_child(actions)

	_add_training_action_card(actions, "01", data.quiz_title, data.quiz_text, "Start quiz")
	_add_training_action_card(actions, "02", data.compare_title, data.compare_text, "Compare now")
	_add_training_action_card(actions, "03", data.missions_title, data.missions_text, "View missions")


func _add_training_action_card(parent: HBoxContainer, number: String, title: String, text: String, button_text: String) -> void:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 310)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.add_theme_stylebox_override("panel", _panel_style(30, Color.TRANSPARENT, Color.WHITE, 3))
	parent.add_child(panel)

	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 14)
	_panel_margin(panel, 22, 22, 22, 24).add_child(box)

	var number_panel := PanelContainer.new()
	number_panel.custom_minimum_size = Vector2(96, 96)
	number_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	number_panel.add_theme_stylebox_override("panel", _panel_style(999, Color.WHITE, Color.WHITE, 0))
	box.add_child(number_panel)

	var number_label := _make_label(number, 42, Color.BLACK, HORIZONTAL_ALIGNMENT_CENTER, false)
	_panel_margin(number_panel, 0, 0, 0, 0).add_child(number_label)

	box.add_child(_make_label(title.to_upper(), 38, _accent_color(), HORIZONTAL_ALIGNMENT_CENTER, true))

	var divider := ColorRect.new()
	divider.custom_minimum_size = Vector2(0, 4)
	divider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	divider.color = Color.WHITE
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(divider)

	var text_label := _make_label(text, 34, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, true)
	text_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(text_label)

	var button := Button.new()
	button.text = button_text
	button.custom_minimum_size = Vector2(0, 82)
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.add_theme_font_size_override("font_size", 34)
	button.add_theme_color_override("font_color", Color.BLACK)
	button.add_theme_color_override("font_hover_color", Color.BLACK)
	button.add_theme_color_override("font_pressed_color", Color.BLACK)
	button.add_theme_stylebox_override("normal", _training_button_style(false))
	button.add_theme_stylebox_override("hover", _training_button_style(true))
	button.add_theme_stylebox_override("pressed", _training_button_style(true))
	_apply_app_font(button)

	button.button_down.connect(func() -> void:
		_on_header_button_down(button)
	)

	button.button_up.connect(func() -> void:
		_on_header_button_up(button)
	)

	box.add_child(button)


func _training_button_style(_hovered: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()

	style.bg_color = Color.WHITE
	style.border_color = Color.WHITE
	style.set_border_width_all(3)
	style.set_corner_radius_all(22)

	style.content_margin_left = 22
	style.content_margin_right = 22
	style.content_margin_top = 12
	style.content_margin_bottom = 12

	return style


func _add_learning_prompts(parent: VBoxContainer) -> void:
	var prompts := data.learning_prompts

	if prompts.is_empty():
		prompts = _fallback_learning_prompts()

	var panel := _make_panel(Color.BLACK, Color.WHITE, 3)
	parent.add_child(panel)

	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	box.add_theme_constant_override("separation", 28)
	_panel_margin(panel, 34, 34, 34, 38).add_child(box)

	var title_row := HBoxContainer.new()
	title_row.mouse_filter = Control.MOUSE_FILTER_PASS
	title_row.alignment = BoxContainer.ALIGNMENT_CENTER
	title_row.add_theme_constant_override("separation", 18)
	box.add_child(title_row)

	var title := _section_title("THINK LIKE A SCIENTIST")
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title)

	var tag_panel := PanelContainer.new()
	tag_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	tag_panel.add_theme_stylebox_override("panel", _panel_style(22, Color.WHITE, Color.WHITE, 0))
	title_row.add_child(tag_panel)

	var tag := _make_label("PROMPTS", 34, Color.BLACK, HORIZONTAL_ALIGNMENT_CENTER, false)
	tag.custom_minimum_size = Vector2(210, 72)
	_panel_margin(tag_panel, 18, 8, 18, 8).add_child(tag)

	var ladder := VBoxContainer.new()
	ladder.mouse_filter = Control.MOUSE_FILTER_PASS
	ladder.add_theme_constant_override("separation", 18)
	box.add_child(ladder)

	for i in range(prompts.size()):
		var prompt: Dictionary = prompts[i]
		_add_training_prompt_item(
			ladder,
			i + 1,
			str(prompt.get("title", "")),
			str(prompt.get("text", ""))
		)


func _add_training_prompt_item(parent: VBoxContainer, number: int, title: String, text: String) -> void:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.add_theme_stylebox_override("panel", _panel_style(28, Color(0.0, 0.0, 0.0, 0.24), Color.WHITE, 3))
	parent.add_child(panel)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_theme_constant_override("separation", 22)
	_panel_margin(panel, 24, 22, 24, 24).add_child(row)

	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(110, 0)
	left.alignment = BoxContainer.ALIGNMENT_CENTER
	left.mouse_filter = Control.MOUSE_FILTER_PASS
	left.add_theme_constant_override("separation", 8)
	row.add_child(left)

	var number_text := str(number).pad_zeros(2)
	var number_label := _make_label(number_text, 46, _accent_color(), HORIZONTAL_ALIGNMENT_CENTER, false)
	left.add_child(number_label)

	var pillar := ColorRect.new()
	pillar.custom_minimum_size = Vector2(5, 72)
	pillar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	pillar.color = Color.WHITE
	pillar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.add_child(pillar)

	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.mouse_filter = Control.MOUSE_FILTER_PASS
	content.add_theme_constant_override("separation", 10)
	row.add_child(content)

	content.add_child(_make_label(title.to_upper(), 44, _accent_color(), HORIZONTAL_ALIGNMENT_LEFT, true))
	content.add_child(_make_label(text, 46, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, true))

	var challenge_strip := HBoxContainer.new()
	challenge_strip.mouse_filter = Control.MOUSE_FILTER_PASS
	challenge_strip.add_theme_constant_override("separation", 12)
	content.add_child(challenge_strip)

	challenge_strip.add_child(_training_chip("RECALL"))
	challenge_strip.add_child(_training_chip("REASON"))
	challenge_strip.add_child(_training_chip("APPLY"))


func _training_chip(text: String) -> PanelContainer:
	var chip := PanelContainer.new()
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_theme_stylebox_override("panel", _panel_style(18, Color.TRANSPARENT, Color.WHITE, 2))

	var label := _make_label(text, 26, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, false)
	label.custom_minimum_size = Vector2(120, 48)
	_panel_margin(chip, 10, 4, 10, 4).add_child(label)

	return chip


func _fallback_overview_points() -> Array[Dictionary]:
	return [
		{"title": "Role", "text": _value_or_unknown(data.system_role)},
		{"title": "Visual cue", "text": _value_or_unknown(data.visual_signature)},
		{"title": "Origin clue", "text": _value_or_unknown(data.formation_note)},
		{"title": "Extreme", "text": _value_or_unknown(data.notable_extreme)},
	]


func _fallback_learning_prompts() -> Array[Dictionary]:
	return [
		{"title": "Observe", "text": "Name one visible feature that helps identify " + data.name + "."},
		{"title": "Explain", "text": "Describe one force or process that shapes this object."},
		{"title": "Connect", "text": "Compare it with another object from the same category."},
	]


func _add_memory_item(parent: VBoxContainer, title: String, text: String) -> void:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.add_theme_stylebox_override("panel", _panel_style(24, _card_color(), _transparent(), 0))
	parent.add_child(panel)

	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	box.add_theme_constant_override("separation", 10)
	_panel_margin(panel, 26, 22, 26, 22).add_child(box)

	box.add_child(_make_label(title.to_upper(), 34, _accent_color(), HORIZONTAL_ALIGNMENT_LEFT, false))
	box.add_child(_make_label(text, 46, _text_color(), HORIZONTAL_ALIGNMENT_LEFT, true))


func _add_feature_item(parent: VBoxContainer, title: String, text: String) -> void:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_theme_constant_override("separation", 20)
	parent.add_child(row)

	var marker := PanelContainer.new()
	marker.custom_minimum_size = Vector2(18, 0)
	marker.size_flags_vertical = Control.SIZE_EXPAND_FILL
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marker.add_theme_stylebox_override("panel", _panel_style(999, _accent_color(), _accent_color(), 0))
	row.add_child(marker)

	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	box.add_theme_constant_override("separation", 10)
	row.add_child(box)

	box.add_child(_make_label(title, 50, _text_color(), HORIZONTAL_ALIGNMENT_LEFT, true))
	box.add_child(_make_label(text, 46, _muted_color(), HORIZONTAL_ALIGNMENT_LEFT, true))


func _add_stat_item(parent: GridContainer, title: String, value: String, index: int = 0) -> void:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 214)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.mouse_filter = Control.MOUSE_FILTER_PASS

	var bg := Color(0.0, 0.0, 0.0, 0.34) if index % 2 == 0 else Color(0.0, 0.0, 0.0, 0.18)

	panel.add_theme_stylebox_override(
		"panel",
		_panel_style(30, bg, Color.WHITE, 3)
	)
	parent.add_child(panel)

	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 12)
	_panel_margin(panel, 22, 20, 22, 22).add_child(box)

	var title_label := _make_label(title.to_upper(), 34, _accent_color(), HORIZONTAL_ALIGNMENT_CENTER, true)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(title_label)

	var divider := ColorRect.new()
	divider.custom_minimum_size = Vector2(0, 4)
	divider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	divider.color = Color.WHITE
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(divider)

	var value_label := _make_label(_value_or_unknown(value), 56, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, true)
	value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(value_label)


func _add_action_card(parent: VBoxContainer, title: String, text: String, button_text: String) -> void:
	var panel := _make_panel(_card_color(), _transparent(), 0)
	parent.add_child(panel)

	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	box.add_theme_constant_override("separation", 24)
	_panel_margin(panel, 34, 32, 34, 34).add_child(box)

	box.add_child(_make_label(title, 50, _text_color(), HORIZONTAL_ALIGNMENT_LEFT, true))
	box.add_child(_make_label(text, 46, _muted_color(), HORIZONTAL_ALIGNMENT_LEFT, true))

	var button := Button.new()
	button.text = button_text
	button.custom_minimum_size = Vector2(0, 96)
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.add_theme_font_size_override("font_size", 40)
	button.add_theme_color_override("font_color", Color.BLACK)
	button.add_theme_color_override("font_hover_color", Color.BLACK)
	button.add_theme_color_override("font_pressed_color", Color.BLACK)
	button.add_theme_stylebox_override("normal", _learning_button_style(false))
	button.add_theme_stylebox_override("hover", _learning_button_style(true))
	button.add_theme_stylebox_override("pressed", _learning_button_style(true))
	_apply_app_font(button)
	button.pressed.connect(func() -> void:
		_play_sfx("click")
	)
	box.add_child(button)


func _section_title(value: String) -> Label:
	return _make_label(value, 58, _text_color(), HORIZONTAL_ALIGNMENT_LEFT, true)


func _add_footer() -> void:
	var footer := _make_label(
		"AI can make mistakes. Verify important scientific information.",
		34,
		Color.WHITE,
		HORIZONTAL_ALIGNMENT_CENTER,
		true
	)
	footer.custom_minimum_size = Vector2(0, 90)
	_content.add_child(footer)


func _build_highlighted_description_bbcode() -> String:
	var words := data.description.split(" ", false)
	var highlight_map := {}

	for index in data.description_highlight_indices:
		highlight_map[int(index)] = true

	var result := ""

	for i in range(words.size()):
		var word := _bbcode_escape(str(words[i]))

		if highlight_map.has(i):
			result += "[color=#%s]%s[/color]" % [_accent_color().to_html(false), word]
		else:
			result += word

		if i < words.size() - 1:
			result += " "

	return result


func _bbcode_escape(value: String) -> String:
	return value.replace("[", "\\[").replace("]", "\\]")


func _object_category() -> String:
	var clean := data.object_category.strip_edges().to_lower()

	if clean.is_empty():
		if data.archetype_id.to_lower().contains("star") or data.planet_preset.to_lower().contains("star"):
			return "star"

		return "planet"

	return clean


func _satellite_field_title() -> String:
	if _object_category() == "star":
		return "Planets"

	if _object_category() == "moon":
		return "Parent"

	return "Moons"


func _value_or_unknown(value: String) -> String:
	if value.strip_edges().is_empty():
		return "unknown"

	return value


func _toggle_add_planet() -> void:
	_planet_added = not _planet_added
	_update_add_planet_button_style()

	if _planet_added:
		add_planet_requested.emit(data)
	else:
		remove_planet_requested.emit(data)


func _update_add_planet_button_style() -> void:
	if not is_instance_valid(_add_planet_button):
		return

	if _planet_added:
		_add_planet_button.text = "REMOVE"
		_add_planet_button.add_theme_color_override("font_color", _accent_color())
		_add_planet_button.add_theme_color_override("font_hover_color", _accent_color())
		_add_planet_button.add_theme_color_override("font_pressed_color", _accent_color())
		_add_planet_button.add_theme_stylebox_override("normal", _add_button_style(false, true))
		_add_planet_button.add_theme_stylebox_override("hover", _add_button_style(true, true))
		_add_planet_button.add_theme_stylebox_override("pressed", _add_button_style(true, true))
	else:
		_add_planet_button.text = "ADD"
		_add_planet_button.add_theme_color_override("font_color", Color.BLACK)
		_add_planet_button.add_theme_color_override("font_hover_color", Color.BLACK)
		_add_planet_button.add_theme_color_override("font_pressed_color", Color.BLACK)
		_add_planet_button.add_theme_stylebox_override("normal", _add_button_style(false, false))
		_add_planet_button.add_theme_stylebox_override("hover", _add_button_style(true, false))
		_add_planet_button.add_theme_stylebox_override("pressed", _add_button_style(true, false))


func _on_header_button_down(button: Control) -> void:
	if not is_instance_valid(button):
		return

	_play_sfx("click")
	_tween_header_button_down(button)


func _on_header_button_up(button: Control) -> void:
	if not is_instance_valid(button):
		return

	_tween_header_button_release(button)


func _tween_header_button_down(button: Control) -> void:
	if not is_instance_valid(button):
		return

	button.pivot_offset = button.size * 0.5

	if _button_tweens.has(button):
		var old_tween: Tween = _button_tweens[button]
		if old_tween != null and old_tween.is_valid():
			old_tween.kill()

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "scale", BUTTON_PRESS_SCALE, BUTTON_DOWN_TIME)

	_button_tweens[button] = tween


func _tween_header_button_release(button: Control) -> void:
	if not is_instance_valid(button):
		return

	button.pivot_offset = button.size * 0.5

	if _button_tweens.has(button):
		var old_tween: Tween = _button_tweens[button]
		if old_tween != null and old_tween.is_valid():
			old_tween.kill()

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "scale", BUTTON_RELEASE_SCALE, BUTTON_UP_TIME)
	tween.tween_property(button, "scale", Vector2.ONE, BUTTON_SETTLE_TIME)

	_button_tweens[button] = tween


func _tween_header_button_cancel(button: Control) -> void:
	if not is_instance_valid(button):
		return

	button.pivot_offset = button.size * 0.5

	if _button_tweens.has(button):
		var old_tween: Tween = _button_tweens[button]
		if old_tween != null and old_tween.is_valid():
			old_tween.kill()

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "scale", Vector2.ONE, BUTTON_SETTLE_TIME)

	_button_tweens[button] = tween


func _draw_hero_stars() -> void:
	if not is_instance_valid(_hero_stars):
		return

	var area_size := _hero_stars.size

	if area_size.x <= 0.0 or area_size.y <= 0.0:
		return

	for i in range(HERO_STAR_COUNT):
		var x := _hash01(i, 11, HERO_STAR_SEED) * area_size.x
		var y := _hash01(i, 23, HERO_STAR_SEED) * area_size.y
		var r := lerp(1.2, 3.8, _hash01(i, 37, HERO_STAR_SEED))
		var a := lerp(0.35, 0.95, _hash01(i, 41, HERO_STAR_SEED))

		_hero_stars.draw_circle(
			Vector2(x, y),
			r,
			Color(1.0, 1.0, 1.0, a)
		)


func _hash01(a: int, b: int, seed: int) -> float:
	var n := seed
	n ^= a * 374761393
	n ^= b * 668265263
	n = (n ^ (n >> 13)) * 1274126177
	n = n ^ (n >> 16)
	return float(n & 0x7fffffff) / 2147483647.0


func _handle_hero_input(event: InputEvent) -> bool:
	if not is_instance_valid(_hero_area):
		return false

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if _is_inside_interactive_header(event.position):
				return false

			if _is_inside_hero_area(event.position):
				_start_hero_drag(-2, event.position)
				return true
		else:
			if _hero_pointer_id == -2:
				_finish_hero_drag()
				return true

		return false

	if event is InputEventMouseMotion:
		if _hero_pointer_id == -2:
			_update_hero_drag(event.position)

			if _hero_dragging:
				get_viewport().set_input_as_handled()

			return true

		return false

	if event is InputEventScreenTouch:
		if event.pressed:
			if _is_inside_interactive_header(event.position):
				return false

			if _is_inside_hero_area(event.position):
				_start_hero_drag(event.index, event.position)
				return true
		else:
			if event.index == _hero_pointer_id:
				_finish_hero_drag()
				return true

		return false

	if event is InputEventScreenDrag:
		if event.index == _hero_pointer_id:
			_update_hero_drag(event.position)

			if _hero_dragging:
				get_viewport().set_input_as_handled()

			return _hero_pointer_id != -999

		return false

	return false


func _start_hero_drag(pointer_id: int, pos: Vector2) -> void:
	_hero_pointer_id = pointer_id
	_hero_dragging = false
	_hero_scroll_locked = false
	_hero_drag_start = pos
	_hero_manual_animation_time = _get_planet_animation_time()
	_hero_base_turning_speed = data.planet_turning_speed

	_scroll_pointer_id = -999
	_scroll_dragging = false
	_scroll_velocity = 0.0


func _update_hero_drag(pos: Vector2) -> void:
	if _hero_pointer_id == -999:
		return

	var total := pos - _hero_drag_start

	if not _hero_dragging:
		if max(abs(total.x), abs(total.y)) < HERO_DRAG_DEADZONE:
			return

		if abs(total.y) > abs(total.x):
			_hero_pointer_id = -999
			_hero_dragging = false
			_hero_scroll_locked = false
			_hero_drag_start = Vector2.ZERO
			_hero_manual_animation_time = 0.0
			_set_scroll_locked(false)
			_start_scroll_drag_from_position(pos)
			return

		_hero_dragging = true
		_hero_scroll_locked = true
		_set_scroll_locked(true)

		_scroll_pointer_id = -999
		_scroll_dragging = false
		_scroll_velocity = 0.0

	var delta_x := pos.x - _hero_drag_start.x

	if abs(delta_x) <= HERO_DRAG_MIN_DELTA:
		return

	_hero_manual_animation_time += delta_x * HERO_DRAG_TIME_SENSITIVITY
	_hero_drag_start = pos

	_set_planet_animation_time(_hero_manual_animation_time)


func _finish_hero_drag() -> void:
	if is_instance_valid(_planet_node):
		_set_planet_animation_time(_hero_manual_animation_time)
		_planet_node.set("turning_speed", _hero_base_turning_speed)

	data.planet_turning_speed = _hero_base_turning_speed

	_hero_pointer_id = -999
	_hero_dragging = false
	_hero_scroll_locked = false
	_hero_drag_start = Vector2.ZERO
	_hero_manual_animation_time = 0.0

	_set_scroll_locked(false)


func _set_scroll_locked(locked: bool) -> void:
	if not is_instance_valid(_scroll):
		return

	if locked:
		_scroll_velocity = 0.0
		_scroll_pointer_id = -999
		_scroll_dragging = false


func _get_planet_animation_time() -> float:
	if not is_instance_valid(_planet_node):
		return 0.0

	var current_time = _planet_node.get("_animation_time")

	if current_time == null:
		return 0.0

	return float(current_time)


func _set_planet_animation_time(value: float) -> void:
	if not is_instance_valid(_planet_node):
		return

	_planet_node.set("_animation_time", value)

	var inner_planet = _planet_node.get("_planet")

	if inner_planet != null and inner_planet.has_method("update_time"):
		inner_planet.call("update_time", value)


func _start_scroll_drag_from_position(screen_position: Vector2) -> void:
	_scroll_pointer_id = -2
	_scroll_dragging = false
	_scroll_start_y = screen_position.y
	_scroll_last_y = screen_position.y
	_scroll_last_time = Time.get_ticks_msec() / 1000.0
	_scroll_velocity = 0.0


func _center_hero_planet() -> void:
	if not is_instance_valid(_hero_clip) or not is_instance_valid(_planet_node):
		return

	var available_diameter: float = min(_hero_clip.size.x, _hero_clip.size.y) * HERO_BODY_MAX_FILL
	var planet_body_diameter: float = max(float(data.planet_radius_px) * 2.0, 1.0)
	var preview_scale: float = min(1.0, available_diameter / planet_body_diameter)

	_planet_node.scale = Vector2.ONE * preview_scale
	_planet_node.position = _hero_clip.size * 0.5


func _apply_planet_data(planet: Node2D, planet_data: PlanetData, radius: int) -> void:
	planet.set("preset", planet_data.planet_preset)
	planet.set("radius_px", radius)
	planet.set("render_pixels", planet_data.planet_pixels)
	planet.set("seed_value", planet_data.planet_seed)
	planet.set("turning_speed", planet_data.planet_turning_speed)
	planet.set("axial_tilt_deg", planet_data.planet_axial_tilt_deg)
	planet.set("ring_angle_deg", planet_data.planet_ring_angle_deg)
	planet.set("debug_border_enabled", false)
	planet.set("draggable", false)
	planet.set("use_custom_colors", planet_data.use_custom_colors)
	planet.set("custom_colors", planet_data.custom_colors)

	if planet.has_method("rebuild"):
		planet.call("rebuild")


func _handle_slippery_scroll_input(event: InputEvent) -> void:
	if not is_instance_valid(_scroll):
		return
	
	if _hero_scroll_locked:
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			if _scroll_pointer_id == -2:
				if _scroll_dragging:
					get_viewport().set_input_as_handled()

				_scroll_pointer_id = -999
				_scroll_dragging = false

			return

		if not _is_inside_scroll(event.position):
			return

		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_scroll_velocity += _scroll_wheel_impulse
			_scroll_velocity = clamp(_scroll_velocity, -_scroll_max_velocity, _scroll_max_velocity)
			get_viewport().set_input_as_handled()
			return

		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_scroll_velocity -= _scroll_wheel_impulse
			_scroll_velocity = clamp(_scroll_velocity, -_scroll_max_velocity, _scroll_max_velocity)
			get_viewport().set_input_as_handled()
			return

		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if _is_inside_interactive_header(event.position):
				return

			if _is_inside_scroll(event.position):
				_scroll_pointer_id = -2
				_scroll_dragging = false
				_scroll_start_y = event.position.y
				_scroll_last_y = event.position.y
				_scroll_last_time = Time.get_ticks_msec() / 1000.0
				_scroll_velocity = 0.0

	elif event is InputEventMouseMotion:
		if _scroll_pointer_id == -2:
			_apply_manual_scroll(event.position.y)

			if _scroll_dragging:
				get_viewport().set_input_as_handled()

	elif event is InputEventScreenTouch:
		if event.pressed:
			if _is_inside_interactive_header(event.position):
				return

			if _is_inside_scroll(event.position):
				_scroll_pointer_id = event.index
				_scroll_dragging = false
				_scroll_start_y = event.position.y
				_scroll_last_y = event.position.y
				_scroll_last_time = Time.get_ticks_msec() / 1000.0
				_scroll_velocity = 0.0
		else:
			if event.index == _scroll_pointer_id:
				if _scroll_dragging:
					get_viewport().set_input_as_handled()

				_scroll_pointer_id = -999
				_scroll_dragging = false

	elif event is InputEventScreenDrag:
		if event.index == _scroll_pointer_id:
			_apply_manual_scroll(event.position.y)

			if _scroll_dragging:
				get_viewport().set_input_as_handled()


func _apply_manual_scroll(current_y: float) -> void:
	if not is_instance_valid(_scroll):
		return

	var total_delta := _scroll_start_y - current_y

	if abs(total_delta) >= _scroll_drag_deadzone:
		_scroll_dragging = true

	if not _scroll_dragging:
		return

	var now := Time.get_ticks_msec() / 1000.0
	var dt: float = max(0.001, now - _scroll_last_time)
	var frame_delta := _scroll_last_y - current_y

	_scroll_velocity = clamp(frame_delta / dt, -_scroll_max_velocity, _scroll_max_velocity)
	_scroll.scroll_vertical = int(clamp(float(_scroll.scroll_vertical) + frame_delta, 0.0, _get_max_scroll()))

	_scroll_last_y = current_y
	_scroll_last_time = now


func _apply_scroll_inertia(delta: float) -> void:
	if not is_instance_valid(_scroll):
		return

	if _scroll_pointer_id != -999:
		return

	if abs(_scroll_velocity) < 8.0:
		_scroll_velocity = 0.0
		return

	var max_scroll := _get_max_scroll()

	if max_scroll <= 0.0:
		_scroll_velocity = 0.0
		_scroll.scroll_vertical = 0
		return

	var next_scroll := float(_scroll.scroll_vertical) + (_scroll_velocity * delta)

	if next_scroll <= 0.0:
		next_scroll = 0.0
		_scroll_velocity = 0.0
	elif next_scroll >= max_scroll:
		next_scroll = max_scroll
		_scroll_velocity = 0.0
	else:
		_scroll_velocity = lerp(_scroll_velocity, 0.0, 1.0 - exp(-_scroll_friction * delta))

	_scroll.scroll_vertical = int(next_scroll)


func _get_max_scroll() -> float:
	if not is_instance_valid(_scroll):
		return 0.0

	var bar := _scroll.get_v_scroll_bar()

	if bar == null:
		return 0.0

	return max(0.0, bar.max_value - bar.page)


func _is_inside_scroll(screen_position: Vector2) -> bool:
	if not is_instance_valid(_scroll):
		return false

	return _scroll.get_global_rect().has_point(screen_position)


func _is_inside_hero_area(screen_position: Vector2) -> bool:
	if not is_instance_valid(_hero_area):
		return false

	return _hero_area.get_global_rect().has_point(screen_position)


func _is_inside_interactive_header(screen_position: Vector2) -> bool:
	if is_instance_valid(_back_button) and _back_button.get_global_rect().has_point(screen_position):
		return true

	if is_instance_valid(_add_planet_button) and _add_planet_button.get_global_rect().has_point(screen_position):
		return true

	return false


func _style_scroll_bar() -> void:
	if not is_instance_valid(_scroll):
		return

	var bar := _scroll.get_v_scroll_bar()

	if bar == null:
		return

	bar.visible = true
	bar.modulate.a = 1.0
	bar.custom_minimum_size = Vector2(18, 0)
	bar.add_theme_stylebox_override("scroll", _scroll_track_style())
	bar.add_theme_stylebox_override("grabber", _scroll_grabber_style(COLOR_SCROLL_GRAB))
	bar.add_theme_stylebox_override("grabber_highlight", _scroll_grabber_style(COLOR_SCROLL_GRAB_HOVER))
	bar.add_theme_stylebox_override("grabber_pressed", _scroll_grabber_style(COLOR_SCROLL_GRAB_HOVER))


func _scroll_track_style() -> StyleBoxFlat:
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


func _scroll_grabber_style(color: Color) -> StyleBoxFlat:
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


func _make_panel(bg: Color = Color.BLACK, border: Color = Color.WHITE, border_width: int = 3) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.add_theme_stylebox_override("panel", _panel_style(36, bg, border, border_width))
	return panel


func _panel_margin(parent: Control, left: int, top: int, right: int, bottom: int) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_PASS
	margin.add_theme_constant_override("margin_left", left)
	margin.add_theme_constant_override("margin_top", top)
	margin.add_theme_constant_override("margin_right", right)
	margin.add_theme_constant_override("margin_bottom", bottom)
	parent.add_child(margin)
	return margin


func _panel_style(radius: int, bg: Color, border: Color = Color.WHITE, border_width: int = 3) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.shadow_color = Color(0, 0, 0, 0.42)
	style.shadow_size = 16
	style.shadow_offset = Vector2(0, 6)
	return style


func _learning_button_style(hovered: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = _accent_color().lightened(0.08 if hovered else 0.0)
	style.border_color = _transparent()
	style.set_border_width_all(0)
	style.set_corner_radius_all(24)
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	return style


func _tab_button_style(selected: bool, hovered: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()

	if selected:
		style.bg_color = _accent_color().lightened(0.08 if hovered else 0.0)
		style.border_color = _transparent()
		style.set_border_width_all(0)
	else:
		style.bg_color = Color(0, 0, 0, 0.0)
		style.border_color = Color.WHITE
		style.set_border_width_all(3)

	style.set_corner_radius_all(22)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	return style


func _add_button_style(hovered: bool, remove_mode: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()

	if remove_mode:
		style.bg_color = Color(0.0, 0.0, 0.0, 0.92 if not hovered else 1.0)
		style.border_color = _accent_color()
		style.set_border_width_all(5)
	else:
		style.bg_color = Color(1.0, 1.0, 1.0, 0.92 if not hovered else 1.0)
		style.border_color = Color.WHITE
		style.set_border_width_all(5)

	style.set_corner_radius_all(24)
	style.content_margin_left = 26
	style.content_margin_right = 26
	style.content_margin_top = 14
	style.content_margin_bottom = 14

	return style


func _white_button_style(hovered: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1.0, 1.0, 1.0, 0.92 if not hovered else 1.0)
	style.border_color = Color.WHITE
	style.set_border_width_all(5)
	style.set_corner_radius_all(24)
	return style


func _make_label(value: String, font_size: int, color: Color, alignment: HorizontalAlignment, wrap: bool) -> Label:
	var label := Label.new()
	label.text = value
	label.horizontal_alignment = alignment
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if wrap else TextServer.AUTOWRAP_OFF
	label.clip_text = false
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	_apply_app_font(label)
	return label


func _load_texture(path: String) -> Texture2D:
	if path.is_empty():
		return null

	if not ResourceLoader.exists(path):
		push_warning("Texture missing: " + path)
		return null

	return load(path) as Texture2D


func _apply_app_font(control: Control) -> void:
	if _app_font != null:
		control.add_theme_font_override("font", _app_font)


func _play_sfx(id: String) -> void:
	if has_node("/root/UnilearnSFX"):
		get_node("/root/UnilearnSFX").play(id)


func _settings_node() -> Node:
	return get_node_or_null("/root/UnilearnUserSettings")


func _dark_mode() -> bool:
	var settings := _settings_node()

	if settings != null:
		return bool(settings.get("theme_dark_mode"))

	return true


func _accent_color() -> Color:
	var settings := _settings_node()

	if settings != null and settings.has_method("get_accent_color"):
		return settings.call("get_accent_color")

	return FALLBACK_ACCENT_DARK if _dark_mode() else FALLBACK_ACCENT_LIGHT


func _panel_color() -> Color:
	var settings := _settings_node()

	if settings != null and settings.has_method("get_panel_color"):
		return settings.call("get_panel_color")

	return Color(0.0, 0.0, 0.0, 0.70) if _dark_mode() else Color(1.0, 1.0, 1.0, 0.92)


func _text_color() -> Color:
	var settings := _settings_node()

	if settings != null and settings.has_method("get_text_color"):
		return settings.call("get_text_color")

	return Color.WHITE if _dark_mode() else Color.BLACK


func _muted_color() -> Color:
	var settings := _settings_node()

	if settings != null and settings.has_method("get_muted_text_color"):
		return settings.call("get_muted_text_color")

	return Color(0.72, 0.76, 0.84, 1.0) if _dark_mode() else Color(0.08, 0.08, 0.10, 0.70)


func _line_color() -> Color:
	var settings := _settings_node()

	if settings != null and settings.has_method("get_line_color"):
		return settings.call("get_line_color")

	return Color(1.0, 1.0, 1.0, 0.86) if _dark_mode() else Color(0.0, 0.0, 0.0, 0.28)


func _card_color() -> Color:
	return Color(1.0, 1.0, 1.0, 0.075) if _dark_mode() else Color(0.0, 0.0, 0.055)


func _soft_panel_color() -> Color:
	return Color(0.0, 0.0, 0.0, 0.34) if _dark_mode() else Color(1.0, 1.0, 1.0, 0.58)


func _accent_soft_color() -> Color:
	var accent := _accent_color()
	return Color(accent.r, accent.g, accent.b, 0.22 if _dark_mode() else 0.28)


func _transparent() -> Color:
	return Color(0, 0, 0, 0)


func _clear_children() -> void:
	_scroll_pointer_id = -999
	_scroll_dragging = false
	_scroll_velocity = 0.0

	_hero_pointer_id = -999
	_hero_dragging = false
	_hero_drag_start = Vector2.ZERO
	_hero_manual_animation_time = 0.0
	_back_button_pressed = false
	_name_label = null
	_details_stack = null
	_details_tab_buttons.clear()

	for button in _button_tweens.keys():
		if is_instance_valid(button):
			button.scale = Vector2.ONE

	_button_tweens.clear()

	for child in get_children():
		child.queue_free()
	
	_hero_clip = null
	_hero_scroll_locked = false
