extends Control

signal back_requested
signal add_planet_requested(data: PlanetData)
signal remove_planet_requested(data: PlanetData)

const PIXEL_PLANET_SCRIPT := preload("res://addons/UnilearnLib/nodes/UnilearnPixelPlanet2D.gd")
const FONT_PATH := "res://assets/fonts/JockeyOne-Regular.ttf"
const BACK_ARROW_TEXTURE_PATH := "res://assets/app/buttons/button_arrow.png"

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
const TAB_TRAINING := "game"

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

var _pending_restore_scroll_vertical := -1
var _pending_restore_selected_tab := ""

var _last_accent_color := Color.WHITE


func setup(value: PlanetData) -> void:
	data = value

	if is_inside_tree():
		call_deferred("_rebuild")


func _ready() -> void:
	_app_font = load(FONT_PATH) as Font
	_last_accent_color = _accent_color()
	_connect_settings_signal()
	_connect_quiz_completed_signal()
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


func _connect_quiz_completed_signal() -> void:
	var quiz := get_node_or_null("/root/UnilearnQuizController")

	if quiz == null:
		return

	if not quiz.has_signal("quiz_completed"):
		return

	var callable := Callable(self, "_on_quiz_completed")

	if not quiz.quiz_completed.is_connected(callable):
		quiz.quiz_completed.connect(callable)


func _on_quiz_completed(updated_data: PlanetData, _score: int, _total: int, _xp_won: int) -> void:
	if data == null or updated_data == null:
		return

	if data.instance_id.strip_edges() != updated_data.instance_id.strip_edges():
		return

	data = updated_data

	_pending_restore_selected_tab = _selected_tab

	if is_instance_valid(_scroll):
		_pending_restore_scroll_vertical = _scroll.scroll_vertical
	else:
		_pending_restore_scroll_vertical = -1

	call_deferred("_rebuild")


func _on_settings_changed() -> void:
	if not is_inside_tree() or data == null:
		return

	_apply_live_accent_refresh()


func _apply_live_accent_refresh() -> void:
	var old_accent := _last_accent_color
	var new_accent := _accent_color()

	if _colors_close(old_accent, new_accent):
		return

	_last_accent_color = new_accent

	_refresh_node_accent_recursive(self, old_accent, new_accent)

	if is_instance_valid(_details_stack):
		_update_tab_button_styles()

	if is_instance_valid(_add_planet_button):
		_update_add_planet_button_style()

	_refresh_highlighted_description()

	if is_instance_valid(_hero_area):
		_hero_area.queue_redraw()

	if is_instance_valid(_hero_stars):
		_hero_stars.queue_redraw()


func _refresh_node_accent_recursive(node: Node, old_accent: Color, new_accent: Color) -> void:
	if node == null:
		return

	if node is Label:
		_refresh_label_accent(node as Label, old_accent, new_accent)

	if node is RichTextLabel:
		_refresh_rich_text_accent(node as RichTextLabel)

	if node is Control:
		_refresh_control_style_accent(node as Control, old_accent, new_accent)

	for child in node.get_children():
		_refresh_node_accent_recursive(child, old_accent, new_accent)


func _refresh_label_accent(label: Label, old_accent: Color, new_accent: Color) -> void:
	if not is_instance_valid(label):
		return

	var color_names := [
		"font_color",
		"font_hover_color",
		"font_pressed_color",
		"font_focus_color",
		"font_hover_pressed_color"
	]

	for color_name in color_names:
		var color := label.get_theme_color(color_name)

		if _colors_close(color, old_accent):
			label.add_theme_color_override(color_name, new_accent)


func _refresh_rich_text_accent(rich: RichTextLabel) -> void:
	if not is_instance_valid(rich):
		return

	if rich.name == "HighlightedDescription":
		rich.text = _build_highlighted_description_bbcode()


func _refresh_control_style_accent(control: Control, old_accent: Color, new_accent: Color) -> void:
	if not is_instance_valid(control):
		return

	var style_names := [
		"panel",
		"normal",
		"hover",
		"pressed",
		"focus",
		"disabled"
	]

	for style_name in style_names:
		if not control.has_theme_stylebox(style_name):
			continue

		var style := control.get_theme_stylebox(style_name)

		if not (style is StyleBoxFlat):
			continue

		var flat := style as StyleBoxFlat
		var needs_update := false
		var next_style := flat.duplicate() as StyleBoxFlat

		if _colors_close(next_style.bg_color, old_accent):
			next_style.bg_color = new_accent
			needs_update = true

		if _colors_close(next_style.border_color, old_accent):
			next_style.border_color = new_accent
			needs_update = true

		if _colors_close(next_style.shadow_color, old_accent):
			next_style.shadow_color = new_accent
			needs_update = true

		if needs_update:
			control.add_theme_stylebox_override(style_name, next_style)


func _refresh_highlighted_description() -> void:
	var rich := find_child("HighlightedDescription", true, false)

	if rich is RichTextLabel:
		var text := rich as RichTextLabel
		text.text = _build_highlighted_description_bbcode()


func _colors_close(a: Color, b: Color, tolerance: float = 0.01) -> bool:
	return (
		abs(a.r - b.r) <= tolerance
		and abs(a.g - b.g) <= tolerance
		and abs(a.b - b.b) <= tolerance
		and abs(a.a - b.a) <= tolerance
	)


func _rebuild() -> void:
	if data == null:
		return

	_last_accent_color = _accent_color()

	var tab_to_restore := _pending_restore_selected_tab
	var scroll_to_restore := _pending_restore_scroll_vertical

	if tab_to_restore.strip_edges().is_empty():
		tab_to_restore = TAB_OVERVIEW

	_clear_children()

	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process(true)

	_hero_base_turning_speed = data.planet_turning_speed
	_selected_tab = tab_to_restore

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
	_add_game_progress_strip()
	_add_learning_deck()
	_add_footer()

	call_deferred("_style_scroll_bar")
	call_deferred("_center_hero_planet")
	call_deferred("_fit_name_label_font_size")

	if scroll_to_restore >= 0:
		call_deferred("_restore_scroll_after_rebuild", scroll_to_restore)

	_pending_restore_selected_tab = ""
	_pending_restore_scroll_vertical = -1


func _restore_scroll_after_rebuild(scroll_value: int) -> void:
	await get_tree().process_frame
	await get_tree().process_frame

	if not is_inside_tree():
		return

	if not is_instance_valid(_scroll):
		return

	_scroll.scroll_vertical = int(clamp(float(scroll_value), 0.0, _get_max_scroll()))
	_scroll_velocity = 0.0


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


# -----------------------------------------------------------------------------
# Split-script virtual method declarations.
# -----------------------------------------------------------------------------
func _add_learning_deck() -> void:
	pass

func _add_footer() -> void:
	pass

func _add_game_progress_strip() -> void:
	pass

func _handle_hero_input(_event: InputEvent) -> bool:
	return false

func _handle_slippery_scroll_input(_event: InputEvent) -> void:
	pass

func _apply_scroll_inertia(_delta: float) -> void:
	pass

func _style_scroll_bar() -> void:
	pass

func _center_hero_planet() -> void:
	pass

func _apply_planet_data(_planet: Node2D, _planet_data: PlanetData, _radius: int) -> void:
	pass

func _update_add_planet_button_style() -> void:
	pass

func _on_header_button_down(_button: Control) -> void:
	pass

func _on_header_button_up(_button: Control) -> void:
	pass

func _tween_header_button_cancel(_button: Control) -> void:
	pass

func _draw_hero_stars() -> void:
	pass


func _make_panel(bg: Color = Color.BLACK, border: Color = Color.WHITE, border_width: int = 3) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style(36, bg, border, border_width))
	return panel

func _panel_margin(parent: Control, left: int, top: int, right: int, bottom: int) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", left)
	margin.add_theme_constant_override("margin_top", top)
	margin.add_theme_constant_override("margin_right", right)
	margin.add_theme_constant_override("margin_bottom", bottom)
	if parent != null:
		parent.add_child(margin)
	return margin

func _panel_style(radius: int, bg: Color, border: Color = Color.WHITE, border_width: int = 3) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	return style

func _learning_button_style(_hovered: bool) -> StyleBoxFlat:
	return _panel_style(24, Color.WHITE, Color.TRANSPARENT, 0)

func _tab_button_style(_selected: bool, _hovered: bool) -> StyleBoxFlat:
	return _panel_style(24, Color.TRANSPARENT, Color.WHITE, 2)

func _add_button_style(_hovered: bool, _remove_mode: bool) -> StyleBoxFlat:
	return _panel_style(36, Color.WHITE, Color.TRANSPARENT, 0)

func _white_button_style(_hovered: bool) -> StyleBoxFlat:
	return _panel_style(36, Color.WHITE, Color.TRANSPARENT, 0)

func _make_label(value: String, font_size: int, color: Color, alignment: HorizontalAlignment, wrap: bool) -> Label:
	var label := Label.new()
	label.text = value
	label.horizontal_alignment = alignment
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if wrap else TextServer.AUTOWRAP_OFF
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

func _load_texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null


func _apply_app_font(_control: Control) -> void:
	pass

func _play_sfx(_id: String) -> void:
	pass


func _settings_node() -> Node:
	return get_node_or_null("/root/UnilearnUserSettings")


func _dark_mode() -> bool:
	return true

func _accent_color() -> Color:
	var settings := _settings_node()
	if settings != null and settings.has_method("get_accent_color"):
		return settings.call("get_accent_color")
	return Color.WHITE

func _panel_color() -> Color:
	return Color(0, 0, 0, 0.70)

func _text_color() -> Color:
	return Color.WHITE

func _muted_color() -> Color:
	return Color(0.72, 0.76, 0.84, 1.0)

func _line_color() -> Color:
	return Color.WHITE

func _card_color() -> Color:
	return Color(1.0, 1.0, 1.0, 0.06)

func _soft_panel_color() -> Color:
	return Color(1.0, 1.0, 1.0, 0.045)

func _accent_soft_color() -> Color:
	var accent := _accent_color()
	return Color(accent.r, accent.g, accent.b, 0.22)


func _transparent() -> Color:
	return Color(0, 0, 0, 0)

func _clear_children() -> void:
	for child in get_children():
		child.queue_free()

func _build_highlighted_description_bbcode() -> String:
	return data.description if data != null else ""

func _bbcode_escape(value: String) -> String:
	return value.replace("[", "[lb]").replace("]", "[rb]")

func _object_category() -> String:
	if data == null:
		return "planet"

	var clean := data.object_category.strip_edges().to_lower()
	var archetype := data.archetype_id.strip_edges().to_lower()
	var preset := data.planet_preset.strip_edges().to_lower()

	if clean == "moon" or clean == "satellite" or clean == "natural_satellite":
		return "satellite"

	if archetype == "moon" or archetype.contains("moon") or preset == "moon":
		return "satellite"

	if clean.is_empty():
		if archetype.contains("star") or preset.contains("star"):
			return "star"

		if archetype.contains("dwarf"):
			return "dwarf_planet"

		return "planet"

	return clean

func _satellite_field_title() -> String:
	match _object_category():
		"star":
			return "Planets"

		"satellite", "moon":
			return "Parent"

		_:
			return "Moons"

func _value_or_unknown(value: String) -> String:
	return value if not value.strip_edges().is_empty() else "Unknown"

func _toggle_add_planet() -> void:
	pass

func _get_planet_animation_time() -> float:
	return 0.0

func _set_planet_animation_time(_value: float) -> void:
	pass

func _get_max_scroll() -> float:
	return 0.0


func _is_inside_scroll(_screen_position: Vector2) -> bool:
	return false

func _is_inside_hero_area(_screen_position: Vector2) -> bool:
	return false

func _is_inside_interactive_header(_screen_position: Vector2) -> bool:
	return false


func _scroll_track_style() -> StyleBoxFlat:
	return _panel_style(999, Color.TRANSPARENT, Color.TRANSPARENT, 0)

func _scroll_grabber_style(color: Color) -> StyleBoxFlat:
	return _panel_style(999, color, Color.TRANSPARENT, 0)


func _add_features() -> void:
	pass

func _add_fact() -> void:
	pass

func _add_interactive_section() -> void:
	pass

func _add_game_stats_section(_parent: VBoxContainer) -> void:
	pass

func _add_missions_block(_parent: VBoxContainer) -> void:
	pass

func _add_learning_prompts(_parent: VBoxContainer) -> void:
	pass

func _fallback_overview_points() -> Array[Dictionary]:
	return []

func _fallback_learning_prompts() -> Array[Dictionary]:
	return []

func _add_stat_item(parent: GridContainer, title: String, value: String, index: int = 0) -> void:
	if parent == null:
		return

	var clean_title := title.strip_edges()
	var clean_value := value.strip_edges()

	if clean_title.is_empty():
		clean_title = "Data"

	if clean_value.is_empty():
		clean_value = "Unknown"

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 150)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.add_theme_stylebox_override(
		"panel",
		_panel_style(28, Color(0.0, 0.0, 0.0, 0.24), Color.WHITE, 3)
	)
	parent.add_child(panel)

	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 6)
	_panel_margin(panel, 22, 18, 22, 20).add_child(box)

	var title_label := _make_label(
		"%s:" % clean_title.to_upper(),
		32,
		_accent_color(),
		HORIZONTAL_ALIGNMENT_CENTER,
		true
	)
	title_label.custom_minimum_size = Vector2(0, 38)
	box.add_child(title_label)

	var value_label := _make_label(
		clean_value,
		42,
		Color.WHITE,
		HORIZONTAL_ALIGNMENT_CENTER,
		true
	)
	value_label.custom_minimum_size = Vector2(0, 76)
	value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(value_label)

func _update_tab_button_styles() -> void:
	pass

func _set_details_tab(_tab_id: String) -> void:
	pass


func _section_title(value: String) -> Label:
	return _make_label(value, 54, _text_color(), HORIZONTAL_ALIGNMENT_LEFT, true)
