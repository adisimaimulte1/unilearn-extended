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

const NAME_FONT_SIZE_MAX := 58
const NAME_FONT_SIZE_MIN := 28
const NAME_TEXT_SIDE_PADDING := 28.0
const PLANET_BODY_MAX_FILL := 0.95

const CARD_STAR_COUNT := 82
const CARD_STAR_MIN_RADIUS := 1.1
const CARD_STAR_MAX_RADIUS := 3.4
const CARD_STAR_MIN_ALPHA := 0.32
const CARD_STAR_MAX_ALPHA := 0.92

const TAP_SCALE_DOWN := 0.96
const TAP_SCALE_UP := 1.025
const TAP_DOWN_TIME := 0.055
const TAP_UP_TIME := 0.11
const TAP_SETTLE_TIME := 0.10

var data: PlanetData

var _root: Control
var _planet_back: Panel
var _stars_layer: Control
var _planet_clip: Control
var _planet_node: Node2D
var _name_label: Label
var _text_back: Panel
var _tap_catcher: Control
var _border_overlay: Control
var _app_font: Font = null

var _card_star_seed := 0

var _pressing := false
var _press_start_pos := Vector2.ZERO
var _max_drag_distance := 0.0
var _tap_threshold := 20.0
var _hovered := false
var _bounce_tween: Tween = null


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

	_card_star_seed = _make_star_seed()

	custom_minimum_size = Vector2(0, 540)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	clip_contents = true
	pivot_offset = size * 0.5
	scale = Vector2.ONE

	add_theme_stylebox_override("panel", _card_style(false))

	if not mouse_entered.is_connected(Callable(self, "_on_mouse_entered")):
		mouse_entered.connect(_on_mouse_entered)

	if not mouse_exited.is_connected(Callable(self, "_on_mouse_exited")):
		mouse_exited.connect(_on_mouse_exited)

	_root = Control.new()
	_root.name = "CardRoot"
	_make_manual_control(_root)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.clip_contents = true
	add_child(_root)

	_planet_back = Panel.new()
	_planet_back.name = "PlanetBackground"
	_make_manual_control(_planet_back)
	_planet_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_planet_back.clip_contents = true
	_planet_back.add_theme_stylebox_override("panel", _planet_background_style())
	_root.add_child(_planet_back)

	_stars_layer = Control.new()
	_stars_layer.name = "StaticStars"
	_make_manual_control(_stars_layer)
	_stars_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stars_layer.clip_contents = true
	_stars_layer.draw.connect(_draw_static_stars)
	_root.add_child(_stars_layer)

	_planet_clip = Control.new()
	_planet_clip.name = "PlanetClip"
	_make_manual_control(_planet_clip)
	_planet_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_planet_clip.clip_contents = true
	_root.add_child(_planet_clip)

	_text_back = Panel.new()
	_text_back.name = "TextBackground"
	_make_manual_control(_text_back)
	_text_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text_back.add_theme_stylebox_override("panel", _text_background_style())
	_root.add_child(_text_back)

	_name_label = _make_label(data.name.to_upper(), NAME_FONT_SIZE_MAX, COLOR_TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	_name_label.name = "PlanetName"
	_make_manual_control(_name_label)
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_name_label)

	_planet_node = PIXEL_PLANET_SCRIPT.new()
	_planet_node.name = "PlanetCardPlanetPreview"
	_planet_node.z_index = 2
	_planet_node.process_mode = Node.PROCESS_MODE_INHERIT
	_planet_clip.add_child(_planet_node)

	_apply_planet_data(_planet_node, data, data.planet_radius_px)

	_tap_catcher = Control.new()
	_tap_catcher.name = "TapCatcher"
	_make_manual_control(_tap_catcher)
	_tap_catcher.mouse_filter = Control.MOUSE_FILTER_PASS
	_tap_catcher.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_tap_catcher.gui_input.connect(_on_card_gui_input)
	add_child(_tap_catcher)

	_border_overlay = Control.new()
	_border_overlay.name = "BorderOverlay"
	_make_manual_control(_border_overlay)
	_border_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_border_overlay.z_index = 999
	_border_overlay.draw.connect(_draw_border_overlay)
	add_child(_border_overlay)

	_tap_catcher.move_to_front()
	_border_overlay.move_to_front()

	if not resized.is_connected(Callable(self, "_layout_card")):
		resized.connect(_layout_card)

	call_deferred("_layout_card")


func _make_manual_control(control: Control) -> void:
	control.anchor_left = 0.0
	control.anchor_top = 0.0
	control.anchor_right = 0.0
	control.anchor_bottom = 0.0
	control.offset_left = 0.0
	control.offset_top = 0.0
	control.offset_right = 0.0
	control.offset_bottom = 0.0


func _layout_card() -> void:
	if not is_instance_valid(_root):
		return

	var card_size := size

	if card_size.x <= 0.0 or card_size.y <= 0.0:
		card_size = custom_minimum_size

	pivot_offset = card_size * 0.5

	var text_height := 116.0
	var planet_height := max(0.0, card_size.y - text_height)

	_root.position = Vector2.ZERO
	_root.size = card_size

	var planet_rect := Rect2(Vector2.ZERO, Vector2(card_size.x, planet_height))
	var text_rect := Rect2(Vector2(0.0, planet_height), Vector2(card_size.x, text_height))

	if is_instance_valid(_planet_back):
		_planet_back.position = planet_rect.position
		_planet_back.size = planet_rect.size

	if is_instance_valid(_stars_layer):
		_stars_layer.position = planet_rect.position
		_stars_layer.size = planet_rect.size
		_stars_layer.queue_redraw()

	if is_instance_valid(_planet_clip):
		_planet_clip.position = planet_rect.position
		_planet_clip.size = planet_rect.size

	if is_instance_valid(_text_back):
		_text_back.position = text_rect.position
		_text_back.size = text_rect.size

	if is_instance_valid(_name_label):
		_name_label.position = text_rect.position
		_name_label.size = text_rect.size
		_fit_name_label_font_size()

	if is_instance_valid(_tap_catcher):
		_tap_catcher.position = Vector2.ZERO
		_tap_catcher.size = card_size
		_tap_catcher.move_to_front()

	if is_instance_valid(_border_overlay):
		_border_overlay.position = Vector2.ZERO
		_border_overlay.size = card_size
		_border_overlay.queue_redraw()
		_border_overlay.move_to_front()

	_center_preview_planet()


func _center_preview_planet() -> void:
	if not is_instance_valid(_planet_clip) or not is_instance_valid(_planet_node):
		return

	var available_diameter: float = min(_planet_clip.size.x, _planet_clip.size.y) * PLANET_BODY_MAX_FILL
	var planet_body_diameter: float = max(float(data.planet_radius_px) * 2.0, 1.0)
	var preview_scale: float = min(1.0, available_diameter / planet_body_diameter)

	_planet_node.scale = Vector2.ONE * preview_scale
	_planet_node.position = (_planet_clip.size * 0.5) + _preview_visual_offset(data.instance_id)


func _fit_name_label_font_size() -> void:
	if not is_instance_valid(_name_label):
		return

	var available_width: float = max(_name_label.size.x - (NAME_TEXT_SIDE_PADDING * 2.0), 1.0)
	var font_size := NAME_FONT_SIZE_MAX

	while font_size > NAME_FONT_SIZE_MIN:
		if _get_text_width(_name_label.text, font_size) <= available_width:
			break

		font_size -= 1

	_name_label.add_theme_font_size_override("font_size", font_size)


func _get_text_width(text: String, font_size: int) -> float:
	if _app_font != null:
		return _app_font.get_string_size(
			text,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			font_size
		).x

	return float(text.length() * font_size) * 0.58


func _draw_static_stars() -> void:
	if not is_instance_valid(_stars_layer):
		return

	var area_size := _stars_layer.size

	if area_size.x <= 0.0 or area_size.y <= 0.0:
		return

	for i in range(CARD_STAR_COUNT):
		var x := _hash01(i, 11, _card_star_seed) * area_size.x
		var y := _hash01(i, 23, _card_star_seed) * area_size.y
		var radius := lerp(CARD_STAR_MIN_RADIUS, CARD_STAR_MAX_RADIUS, _hash01(i, 37, _card_star_seed))
		var alpha := lerp(CARD_STAR_MIN_ALPHA, CARD_STAR_MAX_ALPHA, _hash01(i, 41, _card_star_seed))

		if _hash01(i, 53, _card_star_seed) > 0.82:
			radius *= 1.55
			alpha = min(1.0, alpha + 0.18)

		_stars_layer.draw_circle(
			Vector2(x, y),
			radius,
			Color(1.0, 1.0, 1.0, alpha)
		)


func _make_star_seed() -> int:
	if data == null:
		return 918273

	var source := "%s_%s_%s" % [data.instance_id, data.name, str(data.planet_seed)]
	var seed := 2166136261

	for i in range(source.length()):
		seed = int(seed ^ source.unicode_at(i))
		seed = int(seed * 16777619)
		seed = seed & 0x7fffffff

	return max(seed, 1)


func _hash01(a: int, b: int, seed: int) -> float:
	var n := seed
	n ^= a * 374761393
	n ^= b * 668265263
	n = (n ^ (n >> 13)) * 1274126177
	n = n ^ (n >> 16)
	return float(n & 0x7fffffff) / 2147483647.0


func _draw_border_overlay() -> void:
	if not is_instance_valid(_border_overlay):
		return

	var border_color := COLOR_BORDER_HOVER if _hovered else COLOR_BORDER
	var rect := Rect2(
		Vector2(BORDER_WIDTH * 0.5, BORDER_WIDTH * 0.5),
		_border_overlay.size - Vector2(BORDER_WIDTH, BORDER_WIDTH)
	)

	var radius := min(CARD_RADIUS, min(rect.size.x, rect.size.y) * 0.5)

	_border_overlay.draw_arc(
		Vector2(rect.position.x + radius, rect.position.y + radius),
		radius,
		PI,
		PI * 1.5,
		24,
		border_color,
		BORDER_WIDTH,
		true
	)

	_border_overlay.draw_arc(
		Vector2(rect.end.x - radius, rect.position.y + radius),
		radius,
		PI * 1.5,
		TAU,
		24,
		border_color,
		BORDER_WIDTH,
		true
	)

	_border_overlay.draw_arc(
		Vector2(rect.end.x - radius, rect.end.y - radius),
		radius,
		0.0,
		PI * 0.5,
		24,
		border_color,
		BORDER_WIDTH,
		true
	)

	_border_overlay.draw_arc(
		Vector2(rect.position.x + radius, rect.end.y - radius),
		radius,
		PI * 0.5,
		PI,
		24,
		border_color,
		BORDER_WIDTH,
		true
	)

	_border_overlay.draw_line(
		Vector2(rect.position.x + radius, rect.position.y),
		Vector2(rect.end.x - radius, rect.position.y),
		border_color,
		BORDER_WIDTH,
		true
	)

	_border_overlay.draw_line(
		Vector2(rect.end.x, rect.position.y + radius),
		Vector2(rect.end.x, rect.end.y - radius),
		border_color,
		BORDER_WIDTH,
		true
	)

	_border_overlay.draw_line(
		Vector2(rect.end.x - radius, rect.end.y),
		Vector2(rect.position.x + radius, rect.end.y),
		border_color,
		BORDER_WIDTH,
		true
	)

	_border_overlay.draw_line(
		Vector2(rect.position.x, rect.end.y - radius),
		Vector2(rect.position.x, rect.position.y + radius),
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
			_bounce_down()
		else:
			if _pressing and _max_drag_distance <= _tap_threshold:
				_play_sfx("click")
				_bounce_tap()
				selected.emit(data)
				accept_event()
			else:
				_bounce_cancel()

			_pressing = false

		return

	if event is InputEventScreenTouch:
		if event.pressed:
			_pressing = true
			_press_start_pos = event.position
			_max_drag_distance = 0.0
			_bounce_down()
		else:
			if _pressing and _max_drag_distance <= _tap_threshold:
				_play_sfx("click")
				_bounce_tap()
				selected.emit(data)
				accept_event()
			else:
				_bounce_cancel()

			_pressing = false

		return

	if event is InputEventMouseMotion and _pressing:
		_max_drag_distance = max(_max_drag_distance, _press_start_pos.distance_to(event.position))

		if _max_drag_distance > _tap_threshold:
			_pressing = false
			_bounce_cancel()

		return

	if event is InputEventScreenDrag and _pressing:
		_max_drag_distance = max(_max_drag_distance, _press_start_pos.distance_to(event.position))

		if _max_drag_distance > _tap_threshold:
			_pressing = false
			_bounce_cancel()

		return


func _bounce_down() -> void:
	if _bounce_tween != null and _bounce_tween.is_valid():
		_bounce_tween.kill()

	pivot_offset = size * 0.5

	_bounce_tween = create_tween()
	_bounce_tween.set_trans(Tween.TRANS_BACK)
	_bounce_tween.set_ease(Tween.EASE_OUT)
	_bounce_tween.tween_property(self, "scale", Vector2.ONE * TAP_SCALE_DOWN, TAP_DOWN_TIME)


func _bounce_tap() -> void:
	if _bounce_tween != null and _bounce_tween.is_valid():
		_bounce_tween.kill()

	pivot_offset = size * 0.5

	_bounce_tween = create_tween()
	_bounce_tween.set_trans(Tween.TRANS_BACK)
	_bounce_tween.set_ease(Tween.EASE_OUT)
	_bounce_tween.tween_property(self, "scale", Vector2.ONE * TAP_SCALE_UP, TAP_UP_TIME)
	_bounce_tween.tween_property(self, "scale", Vector2.ONE, TAP_SETTLE_TIME)


func _bounce_cancel() -> void:
	if _bounce_tween != null and _bounce_tween.is_valid():
		_bounce_tween.kill()

	pivot_offset = size * 0.5

	_bounce_tween = create_tween()
	_bounce_tween.set_trans(Tween.TRANS_BACK)
	_bounce_tween.set_ease(Tween.EASE_OUT)
	_bounce_tween.tween_property(self, "scale", Vector2.ONE, TAP_SETTLE_TIME)


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


func _play_sfx(id: String) -> void:
	if has_node("/root/UnilearnSFX"):
		get_node("/root/UnilearnSFX").play(id)


func _clear_children() -> void:
	if _bounce_tween != null and _bounce_tween.is_valid():
		_bounce_tween.kill()

	scale = Vector2.ONE
	_stars_layer = null

	for child in get_children():
		child.queue_free()
