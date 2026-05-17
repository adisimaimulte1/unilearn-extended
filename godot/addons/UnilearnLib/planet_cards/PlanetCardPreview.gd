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

const EARTH_DIAMETER_KM := 12742.0
const EARTH_PREVIEW_WIDTH_FILL := 0.52
const PLANET_MAX_VIEW_FILL := 0.72
const STAR_MAX_VIEW_FILL := 0.90
const MIN_BODY_VIEW_FILL := 0.14

const PLANET_SIZE_POWER := 0.18
const STAR_SIZE_POWER := 0.10
const SMALL_BODY_SIZE_POWER := 0.28

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

const TEXT_HEIGHT := 116.0

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

var _body_category_cache := "planet"
var _diameter_km_cache := 0.0
var _visual_offset_cache := Vector2.ZERO

var _last_layout_size := Vector2(-1.0, -1.0)
var _last_name_width := -1.0

var _normal_card_style: StyleBoxFlat
var _hover_card_style: StyleBoxFlat
var _planet_background_style_cache: StyleBoxFlat
var _text_background_style_cache: StyleBoxFlat


func setup(value: PlanetData) -> void:
	data = value

	if data != null:
		_cache_planet_metadata()

	if is_inside_tree():
		_rebuild()


func _ready() -> void:
	_app_font = load(FONT_PATH) as Font
	_rebuild()


func _rebuild() -> void:
	if data == null:
		return

	_clear_children()
	_cache_planet_metadata()
	_build_styles()

	_card_star_seed = _make_star_seed()

	custom_minimum_size = Vector2(0, 540)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	clip_contents = true
	pivot_offset = size * 0.5
	scale = Vector2.ONE

	add_theme_stylebox_override("panel", _normal_card_style)

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
	_planet_back.add_theme_stylebox_override("panel", _planet_background_style_cache)
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
	_text_back.add_theme_stylebox_override("panel", _text_background_style_cache)
	_root.add_child(_text_back)

	_name_label = _make_label(
		data.name.to_upper(),
		NAME_FONT_SIZE_MAX,
		COLOR_TEXT,
		HORIZONTAL_ALIGNMENT_CENTER
	)
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

	_last_layout_size = Vector2(-1.0, -1.0)
	_last_name_width = -1.0

	if not resized.is_connected(Callable(self, "_layout_card")):
		resized.connect(_layout_card)

	call_deferred("_layout_card")


func _cache_planet_metadata() -> void:
	_body_category_cache = _compute_body_category()
	_diameter_km_cache = _compute_object_diameter_km(_body_category_cache)
	_visual_offset_cache = _preview_visual_offset(data.instance_id)


func _build_styles() -> void:
	_normal_card_style = _make_card_style(COLOR_CARD_BG)
	_hover_card_style = _make_card_style(COLOR_CARD_BG_HOVER)
	_planet_background_style_cache = _make_planet_background_style()
	_text_background_style_cache = _make_text_background_style()


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

	if card_size == _last_layout_size:
		return

	_last_layout_size = card_size
	pivot_offset = card_size * 0.5

	var planet_height := max(0.0, card_size.y - TEXT_HEIGHT)

	_root.position = Vector2.ZERO
	_root.size = card_size

	var planet_rect := Rect2(Vector2.ZERO, Vector2(card_size.x, planet_height))
	var text_rect := Rect2(Vector2(0.0, planet_height), Vector2(card_size.x, TEXT_HEIGHT))

	_planet_back.position = planet_rect.position
	_planet_back.size = planet_rect.size

	_stars_layer.position = planet_rect.position
	_stars_layer.size = planet_rect.size
	_stars_layer.queue_redraw()

	_planet_clip.position = planet_rect.position
	_planet_clip.size = planet_rect.size

	_text_back.position = text_rect.position
	_text_back.size = text_rect.size

	_name_label.position = text_rect.position
	_name_label.size = text_rect.size
	_fit_name_label_font_size()

	_tap_catcher.position = Vector2.ZERO
	_tap_catcher.size = card_size

	if is_instance_valid(_border_overlay):
		_border_overlay.position = Vector2.ZERO
		_border_overlay.size = card_size
		_border_overlay.queue_redraw()

	_center_preview_planet()


func _center_preview_planet() -> void:
	if not is_instance_valid(_planet_clip) or not is_instance_valid(_planet_node) or data == null:
		return

	var clip_size := _planet_clip.size

	if clip_size.x <= 0.0 or clip_size.y <= 0.0:
		return

	var desired_display_diameter := _get_preview_display_diameter(clip_size)
	var source_body_diameter := max(float(data.planet_radius_px) * 2.0, 1.0)
	var preview_scale: float = desired_display_diameter / source_body_diameter

	_planet_node.scale = Vector2.ONE * preview_scale
	_planet_node.position = (clip_size * 0.5) + _visual_offset_cache


func _get_preview_display_diameter(clip_size: Vector2) -> float:
	var base_size := min(clip_size.x, clip_size.y)
	var earth_display_diameter := clip_size.x * EARTH_PREVIEW_WIDTH_FILL
	var min_display_diameter: float = base_size * MIN_BODY_VIEW_FILL
	var max_fill := STAR_MAX_VIEW_FILL if _body_category_cache == "star" else PLANET_MAX_VIEW_FILL
	var max_display_diameter: float = base_size * max_fill

	if _diameter_km_cache > 0.0:
		var visual_ratio := _get_visual_size_ratio(_diameter_km_cache, _body_category_cache)
		var display_diameter := earth_display_diameter * visual_ratio

		if _body_category_cache == "star":
			display_diameter = max(display_diameter, earth_display_diameter * 1.18)

		elif _body_category_cache == "planet" and _diameter_km_cache > EARTH_DIAMETER_KM:
			display_diameter = max(display_diameter, earth_display_diameter * 1.04)

		return clamp(display_diameter, min_display_diameter, max_display_diameter)

	return clamp(_fallback_display_diameter(clip_size, _body_category_cache), min_display_diameter, max_display_diameter)


func _get_visual_size_ratio(object_diameter_km: float, category: String) -> float:
	var real_ratio: float = max(object_diameter_km / EARTH_DIAMETER_KM, 0.01)

	match category:
		"star":
			return max(1.18, pow(real_ratio, STAR_SIZE_POWER))

		"moon", "satellite":
			return pow(real_ratio, SMALL_BODY_SIZE_POWER)

		"dwarf_planet":
			return min(0.92, pow(real_ratio, SMALL_BODY_SIZE_POWER))

		_:
			return max(0.18, pow(real_ratio, PLANET_SIZE_POWER))


func _compute_body_category() -> String:
	if data == null:
		return "planet"

	var category := data.object_category.strip_edges().to_lower()
	var archetype := data.archetype_id.strip_edges().to_lower()
	var preset := data.planet_preset.strip_edges().to_lower()
	var instance_id := data.instance_id.strip_edges().to_lower()

	if category == "star" or archetype == "star" or preset == "star" or instance_id.contains("sun") or instance_id.contains("star"):
		return "star"

	if category == "satellite" or category == "moon" or archetype.contains("moon") or preset == "moon":
		return "satellite"

	if category == "dwarf_planet" or archetype.contains("dwarf"):
		return "dwarf_planet"

	return "planet"


func _compute_object_diameter_km(category: String) -> float:
	if data == null:
		return 0.0

	var parsed := _parse_first_number(data.diameter_km)

	if parsed > 0.0:
		return parsed

	var archetype := data.archetype_id.strip_edges().to_lower()
	var preset := data.planet_preset.strip_edges().to_lower()
	var name := data.name.strip_edges().to_lower()
	var id := data.instance_id.strip_edges().to_lower()

	if category == "star":
		return EARTH_DIAMETER_KM * 109.0

	if name.contains("jupiter") or id.contains("jupiter"):
		return 139820.0

	if name.contains("saturn") or id.contains("saturn"):
		return 116460.0

	if name.contains("uranus") or id.contains("uranus"):
		return 50724.0

	if name.contains("neptune") or id.contains("neptune"):
		return 49244.0

	if name.contains("earth") or id.contains("earth"):
		return EARTH_DIAMETER_KM

	if name.contains("venus") or id.contains("venus"):
		return 12104.0

	if name.contains("mars") or id.contains("mars"):
		return 6779.0

	if name.contains("mercury") or id.contains("mercury"):
		return 4879.0

	if archetype.contains("gas") or preset.contains("gas"):
		return EARTH_DIAMETER_KM * 8.5

	if archetype.contains("ice"):
		return EARTH_DIAMETER_KM * 4.0

	if category == "satellite" or category == "moon":
		return EARTH_DIAMETER_KM * 0.32

	if category == "dwarf_planet":
		return EARTH_DIAMETER_KM * 0.22

	return 0.0


func _parse_first_number(value: String) -> float:
	return _parse_scaled_number(value)


func _parse_scaled_number(value: String) -> float:
	var text := value.strip_edges()

	if text.is_empty():
		return 0.0

	text = _clean_number_text(text)
	text = _normalize_superscript_exponents(text)

	var sci_value := _parse_scientific_notation_number(text)

	if sci_value > 0.0:
		return sci_value

	return _parse_normal_number(text)


func _clean_number_text(value: String) -> String:
	var text := value

	text = text.replace("~", "")
	text = text.replace("≈", "")
	text = text.replace("approx.", "")
	text = text.replace("Approx.", "")
	text = text.replace("approximately", "")
	text = text.replace("Approximately", "")
	text = text.replace("about", "")
	text = text.replace("About", "")
	text = text.replace("around", "")
	text = text.replace("Around", "")
	text = text.replace("roughly", "")
	text = text.replace("Roughly", "")

	text = text.replace("×", "x")
	text = text.replace("X", "x")
	text = text.replace("*", "x")

	text = text.replace(" to the power of ", "^")
	text = text.replace(" power of ", "^")
	text = text.replace(" at a power of ", "^")
	text = text.replace(" raised to ", "^")

	return text.strip_edges()


func _normalize_superscript_exponents(value: String) -> String:
	var text := value

	var superscripts := {
		"⁰": "0",
		"¹": "1",
		"²": "2",
		"³": "3",
		"⁴": "4",
		"⁵": "5",
		"⁶": "6",
		"⁷": "7",
		"⁸": "8",
		"⁹": "9",
		"⁻": "-"
	}

	for key in superscripts.keys():
		text = text.replace(key, superscripts[key])

	return text


func _parse_scientific_notation_number(text: String) -> float:
	var regex := RegEx.new()

	# Handles:
	# 1.2e10
	# 1.2E10
	# 1.2x10^10
	# 1.2 x 10^10
	# 1.2x10 10
	# 1.2 x 10 at a power of 10 -> cleaned before this
	regex.compile("([-+]?\\d+(?:[\\.,]\\d+)?)\\s*(?:e|x\\s*10\\s*\\^?|x\\s*10)\\s*([-+]?\\d+)")

	var match_result := regex.search(text)

	if match_result == null:
		return 0.0

	var base_text := match_result.get_string(1).replace(",", ".")
	var exponent_text := match_result.get_string(2)

	var base := base_text.to_float()
	var exponent := exponent_text.to_int()

	if base == 0.0:
		return 0.0

	return base * pow(10.0, float(exponent))


func _parse_normal_number(text: String) -> float:
	var regex := RegEx.new()
	regex.compile("[-+]?\\d[\\d\\.,\\s]*(?:[eE][-+]?\\d+)?")

	var match_result := regex.search(text)

	if match_result == null:
		return 0.0

	var raw := match_result.get_string().strip_edges()

	if raw.is_empty():
		return 0.0

	raw = raw.replace(" ", "")

	var comma_count := raw.count(",")
	var dot_count := raw.count(".")

	if raw.to_lower().contains("e"):
		raw = raw.replace(",", ".")
		return raw.to_float()

	if dot_count > 1 and comma_count == 0:
		raw = raw.replace(".", "")
		return raw.to_float()

	if comma_count > 1 and dot_count == 0:
		raw = raw.replace(",", "")
		return raw.to_float()

	if comma_count > 0 and dot_count == 1 and raw.find(",") < raw.find("."):
		raw = raw.replace(",", "")
		return raw.to_float()

	if dot_count > 0 and comma_count == 1 and raw.rfind(".") < raw.find(","):
		raw = raw.replace(".", "")
		raw = raw.replace(",", ".")
		return raw.to_float()

	if dot_count == 1 and comma_count == 0:
		var parts := raw.split(".")

		if parts.size() == 2 and parts[1].length() == 3 and parts[0].length() <= 3:
			raw = raw.replace(".", "")
			return raw.to_float()

		return raw.to_float()

	if comma_count == 1 and dot_count == 0:
		var parts := raw.split(",")

		if parts.size() == 2 and parts[1].length() == 3 and parts[0].length() <= 3:
			raw = raw.replace(",", "")
			return raw.to_float()

		raw = raw.replace(",", ".")
		return raw.to_float()

	raw = raw.replace(",", "")
	return raw.to_float()


func _fallback_display_diameter(clip_size: Vector2, category: String) -> float:
	var base_size := min(clip_size.x, clip_size.y)
	var earth_display_diameter := clip_size.x * EARTH_PREVIEW_WIDTH_FILL
	var radius_ratio := float(max(data.planet_radius_px, 1)) / 142.0

	if category == "star":
		return base_size * STAR_MAX_VIEW_FILL

	if category == "satellite" or category == "moon":
		return earth_display_diameter * 0.68

	if category == "dwarf_planet":
		return earth_display_diameter * 0.58

	return earth_display_diameter * pow(max(radius_ratio, 0.05), PLANET_SIZE_POWER)


func _fit_name_label_font_size() -> void:
	if not is_instance_valid(_name_label):
		return

	var available_width: float = max(_name_label.size.x - (NAME_TEXT_SIDE_PADDING * 2.0), 1.0)

	if is_equal_approx(available_width, _last_name_width):
		return

	_last_name_width = available_width

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


func _draw_border_overlay() -> void:
	if not is_instance_valid(_border_overlay):
		return

	var border_color := COLOR_BORDER_HOVER if _hovered else COLOR_BORDER
	var rect := Rect2(
		Vector2(BORDER_WIDTH * 0.5, BORDER_WIDTH * 0.5),
		_border_overlay.size - Vector2(BORDER_WIDTH, BORDER_WIDTH)
	)

	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return

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
	if _hovered:
		return

	_hovered = true
	add_theme_stylebox_override("panel", _hover_card_style)

	if is_instance_valid(_border_overlay):
		_border_overlay.queue_redraw()


func _on_mouse_exited() -> void:
	if not _hovered:
		return

	_hovered = false
	add_theme_stylebox_override("panel", _normal_card_style)

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
	
	var preset_key := planet_data.planet_preset.strip_edges().to_lower().replace(" ", "_").replace("-", "_")
	planet.set("backing_disk_enabled", true)
	planet.set("backing_disk_color", Color.BLACK)
	planet.set("backing_disk_padding_px", 0.0)

	if planet.has_method("rebuild"):
		planet.call("rebuild")


func _preview_visual_offset(id: String) -> Vector2:
	match id.strip_edges().to_lower():
		"saturn":
			return Vector2(0, -4)

		_:
			return Vector2.ZERO


func _make_card_style(bg: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()

	style.bg_color = bg

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


func _make_planet_background_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()

	style.bg_color = COLOR_PLANET_BACK
	style.border_color = Color.TRANSPARENT
	style.set_border_width_all(0)

	style.corner_radius_top_left = CARD_RADIUS
	style.corner_radius_top_right = CARD_RADIUS
	style.corner_radius_bottom_left = 0
	style.corner_radius_bottom_right = 0

	return style


func _make_text_background_style() -> StyleBoxFlat:
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
	_planet_node = null
	_border_overlay = null
	_last_layout_size = Vector2(-1.0, -1.0)
	_last_name_width = -1.0

	for child in get_children():
		child.queue_free()
