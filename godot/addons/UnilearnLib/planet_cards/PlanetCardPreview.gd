extends PanelContainer
class_name PlanetCardPreview

signal selected(data: PlanetData)

const PIXEL_PLANET_SCRIPT := preload("res://addons/UnilearnLib/nodes/UnilearnPixelPlanet2D.gd")
const FONT_PATH := "res://assets/fonts/JockeyOne-Regular.ttf"

const COLOR_CARD_BG := Color.BLACK
const COLOR_CARD_BG_HOVER := Color(0.025, 0.025, 0.025, 1.0)
const COLOR_BORDER := Color(1.0, 1.0, 1.0, 0.96)
const COLOR_BORDER_HOVER := Color(1.0, 1.0, 1.0, 1.0)

const COLOR_PLANET_BACK := Color.BLACK
const COLOR_TEXT_AREA := Color.WHITE
const COLOR_TEXT := Color.BLACK

const BORDER_WIDTH := 6.0
const CARD_RADIUS := 36.0

var data: PlanetData

var _root: Control
var _planet_back: Panel
var _planet_clip: Control
var _planet_node: Node2D
var _name_label: Label
var _text_back: Panel
var _border_overlay: Control
var _app_font: Font = null

var _pressing := false
var _press_start_pos := Vector2.ZERO
var _max_drag_distance := 0.0
var _tap_threshold := 20.0
var _hovered := false


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

	custom_minimum_size = Vector2(0, 540)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_PASS
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	clip_contents = true

	add_theme_stylebox_override("panel", _card_style(false))

	if not gui_input.is_connected(Callable(self, "_on_card_gui_input")):
		gui_input.connect(_on_card_gui_input)

	if not mouse_entered.is_connected(Callable(self, "_on_mouse_entered")):
		mouse_entered.connect(_on_mouse_entered)

	if not mouse_exited.is_connected(Callable(self, "_on_mouse_exited")):
		mouse_exited.connect(_on_mouse_exited)

	_root = Control.new()
	_root.name = "CardRoot"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.clip_contents = true
	add_child(_root)

	_planet_back = Panel.new()
	_planet_back.name = "PlanetBackground"
	_planet_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_planet_back.clip_contents = true
	_planet_back.add_theme_stylebox_override("panel", _planet_background_style())
	_root.add_child(_planet_back)

	_planet_clip = Control.new()
	_planet_clip.name = "PlanetClip"
	_planet_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_planet_clip.clip_contents = true
	_root.add_child(_planet_clip)

	_text_back = Panel.new()
	_text_back.name = "TextBackground"
	_text_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text_back.add_theme_stylebox_override("panel", _text_background_style())
	_root.add_child(_text_back)

	_name_label = _make_label(data.name.to_upper(), 58, COLOR_TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	_name_label.name = "PlanetName"
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_name_label)

	_planet_node = PIXEL_PLANET_SCRIPT.new()
	_planet_node.name = "PlanetCardPlanetPreview"
	_planet_node.z_index = 2
	_planet_node.process_mode = Node.PROCESS_MODE_INHERIT
	_planet_clip.add_child(_planet_node)

	_apply_planet_data(_planet_node, data, data.planet_radius_px)

	_border_overlay = Control.new()
	_border_overlay.name = "BorderOverlay"
	_border_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_border_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_border_overlay.z_index = 999
	_border_overlay.draw.connect(_draw_border_overlay)
	add_child(_border_overlay)
	_border_overlay.move_to_front()

	if not resized.is_connected(Callable(self, "_layout_card")):
		resized.connect(_layout_card)

	call_deferred("_layout_card")


func _layout_card() -> void:
	if not is_instance_valid(_root):
		return

	var card_size := size

	if card_size.x <= 0.0 or card_size.y <= 0.0:
		card_size = custom_minimum_size

	var text_height := 116.0
	var planet_height := max(0.0, card_size.y - text_height)

	_root.position = Vector2.ZERO
	_root.size = card_size

	var planet_rect := Rect2(Vector2.ZERO, Vector2(card_size.x, planet_height))
	var text_rect := Rect2(Vector2(0.0, planet_height), Vector2(card_size.x, text_height))

	if is_instance_valid(_planet_back):
		_planet_back.position = planet_rect.position
		_planet_back.size = planet_rect.size

	if is_instance_valid(_planet_clip):
		_planet_clip.position = planet_rect.position
		_planet_clip.size = planet_rect.size

	if is_instance_valid(_text_back):
		_text_back.position = text_rect.position
		_text_back.size = text_rect.size

	if is_instance_valid(_name_label):
		_name_label.position = text_rect.position
		_name_label.size = text_rect.size

	if is_instance_valid(_border_overlay):
		_border_overlay.position = Vector2.ZERO
		_border_overlay.size = card_size
		_border_overlay.queue_redraw()
		_border_overlay.move_to_front()

	_center_preview_planet()


func _center_preview_planet() -> void:
	if not is_instance_valid(_planet_clip) or not is_instance_valid(_planet_node):
		return

	_planet_node.position = (_planet_clip.size * 0.5) + _preview_visual_offset(data.instance_id)


func _draw_border_overlay() -> void:
	if not is_instance_valid(_border_overlay):
		return

	var border_color := COLOR_BORDER_HOVER if _hovered else COLOR_BORDER
	var rect := Rect2(
		Vector2(BORDER_WIDTH * 0.5, BORDER_WIDTH * 0.5),
		_border_overlay.size - Vector2(BORDER_WIDTH, BORDER_WIDTH)
	)

	_border_overlay.draw_arc(
		Vector2(rect.position.x + CARD_RADIUS, rect.position.y + CARD_RADIUS),
		CARD_RADIUS,
		PI,
		PI * 1.5,
		24,
		border_color,
		BORDER_WIDTH,
		true
	)

	_border_overlay.draw_arc(
		Vector2(rect.end.x - CARD_RADIUS, rect.position.y + CARD_RADIUS),
		CARD_RADIUS,
		PI * 1.5,
		TAU,
		24,
		border_color,
		BORDER_WIDTH,
		true
	)

	_border_overlay.draw_arc(
		Vector2(rect.end.x - CARD_RADIUS, rect.end.y - CARD_RADIUS),
		CARD_RADIUS,
		0.0,
		PI * 0.5,
		24,
		border_color,
		BORDER_WIDTH,
		true
	)

	_border_overlay.draw_arc(
		Vector2(rect.position.x + CARD_RADIUS, rect.end.y - CARD_RADIUS),
		CARD_RADIUS,
		PI * 0.5,
		PI,
		24,
		border_color,
		BORDER_WIDTH,
		true
	)

	_border_overlay.draw_line(
		Vector2(rect.position.x + CARD_RADIUS, rect.position.y),
		Vector2(rect.end.x - CARD_RADIUS, rect.position.y),
		border_color,
		BORDER_WIDTH,
		true
	)

	_border_overlay.draw_line(
		Vector2(rect.end.x, rect.position.y + CARD_RADIUS),
		Vector2(rect.end.x, rect.end.y - CARD_RADIUS),
		border_color,
		BORDER_WIDTH,
		true
	)

	_border_overlay.draw_line(
		Vector2(rect.end.x - CARD_RADIUS, rect.end.y),
		Vector2(rect.position.x + CARD_RADIUS, rect.end.y),
		border_color,
		BORDER_WIDTH,
		true
	)

	_border_overlay.draw_line(
		Vector2(rect.position.x, rect.end.y - CARD_RADIUS),
		Vector2(rect.position.x, rect.position.y + CARD_RADIUS),
		border_color,
		BORDER_WIDTH,
		true
	)


func _make_label(value: String, font_size: int, color: Color, alignment: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.text = value
	label.horizontal_alignment = alignment
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.clip_text = true
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	_apply_app_font(label)
	return label


func _on_card_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_pressing = true
			_press_start_pos = event.position
			_max_drag_distance = 0.0
		else:
			if _pressing and _max_drag_distance <= _tap_threshold:
				selected.emit(data)

			_pressing = false

		return

	if event is InputEventScreenTouch:
		if event.pressed:
			_pressing = true
			_press_start_pos = event.position
			_max_drag_distance = 0.0
		else:
			if _pressing and _max_drag_distance <= _tap_threshold:
				selected.emit(data)

			_pressing = false

		return

	if event is InputEventMouseMotion and _pressing:
		_max_drag_distance = max(_max_drag_distance, _press_start_pos.distance_to(event.position))
		return

	if event is InputEventScreenDrag and _pressing:
		_max_drag_distance = max(_max_drag_distance, _press_start_pos.distance_to(event.position))
		return


func _on_mouse_entered() -> void:
	_hovered = true
	add_theme_stylebox_override("panel", _card_style(true))

	if is_instance_valid(_border_overlay):
		_border_overlay.queue_redraw()


func _on_mouse_exited() -> void:
	_hovered = false
	add_theme_stylebox_override("panel", _card_style(false))

	if is_instance_valid(_border_overlay):
		_border_overlay.queue_redraw()


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


func _preview_radius(id: String) -> int:
	match id:
		"jupiter":
			return 150

		"saturn":
			return 148

		"uranus", "neptune":
			return 138

		"mercury", "mars":
			return 130

		_:
			return 138


func _preview_visual_offset(id: String) -> Vector2:
	match id:
		"saturn":
			return Vector2(0, -4)

		_:
			return Vector2.ZERO


func _card_style(hovered: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()

	style.bg_color = COLOR_CARD_BG_HOVER if hovered else COLOR_CARD_BG
	style.border_color = Color.TRANSPARENT
	style.set_border_width_all(0)

	style.corner_radius_top_left = CARD_RADIUS
	style.corner_radius_top_right = CARD_RADIUS
	style.corner_radius_bottom_left = CARD_RADIUS
	style.corner_radius_bottom_right = CARD_RADIUS

	style.content_margin_left = 0
	style.content_margin_right = 0
	style.content_margin_top = 0
	style.content_margin_bottom = 0

	style.shadow_color = Color(0, 0, 0, 0.46)
	style.shadow_size = 16
	style.shadow_offset = Vector2(0, 6)

	return style


func _planet_background_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()

	style.bg_color = COLOR_PLANET_BACK
	style.border_color = Color.TRANSPARENT
	style.set_border_width_all(0)

	style.corner_radius_top_left = CARD_RADIUS
	style.corner_radius_top_right = CARD_RADIUS
	style.corner_radius_bottom_left = 0
	style.corner_radius_bottom_right = 0

	return style


func _text_background_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()

	style.bg_color = COLOR_TEXT_AREA
	style.border_color = Color.TRANSPARENT
	style.set_border_width_all(0)

	style.corner_radius_top_left = 0
	style.corner_radius_top_right = 0
	style.corner_radius_bottom_left = CARD_RADIUS
	style.corner_radius_bottom_right = CARD_RADIUS

	return style


func _apply_app_font(control: Control) -> void:
	if _app_font != null:
		control.add_theme_font_override("font", _app_font)


func _clear_children() -> void:
	for child in get_children():
		child.queue_free()
