extends "res://addons/UnilearnLib/planet_cards/details/PlanetCardDetailsInteraction.gd"

const HERO_EARTH_DIAMETER_KM := 12742.0
const HERO_EARTH_PREVIEW_WIDTH_FILL := 0.52
const HERO_PLANET_MAX_VIEW_FILL := 0.72
const HERO_STAR_MAX_VIEW_FILL := 0.90
const HERO_MIN_BODY_VIEW_FILL := 0.14

const HERO_PLANET_SIZE_POWER := 0.18
const HERO_STAR_SIZE_POWER := 0.10
const HERO_SMALL_BODY_SIZE_POWER := 0.28


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
	return true


func _accent_color() -> Color:
	var settings := _settings_node()

	if settings != null and settings.has_method("get_accent_color"):
		return settings.call("get_accent_color")

	return Color.WHITE


func _panel_color() -> Color:
	return Color(0.0, 0.0, 0.0, 0.70)


func _text_color() -> Color:
	return Color.WHITE


func _muted_color() -> Color:
	return Color(0.72, 0.76, 0.84, 1.0)


func _line_color() -> Color:
	return Color(1.0, 1.0, 1.0, 0.86)


func _card_color() -> Color:
	return Color(1.0, 1.0, 1.0, 0.075)


func _soft_panel_color() -> Color:
	return Color(0.0, 0.0, 0.0, 0.34)


func _accent_soft_color() -> Color:
	var accent := _accent_color()
	return Color(accent.r, accent.g, accent.b, 0.22)


func _transparent() -> Color:
	return Color(0, 0, 0, 0)


func _center_hero_planet() -> void:
	if not is_instance_valid(_hero_clip) or not is_instance_valid(_planet_node) or data == null:
		return

	var clip_size := _hero_clip.size

	if clip_size.x <= 0.0 or clip_size.y <= 0.0:
		return

	var desired_display_diameter := _get_hero_display_diameter(clip_size)
	var source_body_diameter := max(float(data.planet_radius_px) * 2.0, 1.0)
	var hero_scale: float = desired_display_diameter / source_body_diameter

	_planet_node.scale = Vector2.ONE * hero_scale
	_planet_node.position = (clip_size * 0.5) + _hero_visual_offset(data.instance_id)


func _get_hero_display_diameter(clip_size: Vector2) -> float:
	var base_size := min(clip_size.x, clip_size.y)
	var earth_display_diameter := clip_size.x * HERO_EARTH_PREVIEW_WIDTH_FILL
	var min_display_diameter: float = base_size * HERO_MIN_BODY_VIEW_FILL
	var object_diameter_km := _get_hero_object_diameter_km()
	var category := _hero_body_category()
	var max_fill := HERO_STAR_MAX_VIEW_FILL if category == "star" else HERO_PLANET_MAX_VIEW_FILL
	var max_display_diameter: float = base_size * max_fill

	if object_diameter_km > 0.0:
		var visual_ratio := _get_hero_visual_size_ratio(object_diameter_km, category)
		var display_diameter := earth_display_diameter * visual_ratio

		if category == "star":
			display_diameter = max(display_diameter, earth_display_diameter * 1.18)

		elif category == "planet" and object_diameter_km > HERO_EARTH_DIAMETER_KM:
			display_diameter = max(display_diameter, earth_display_diameter * 1.04)

		return clamp(display_diameter, min_display_diameter, max_display_diameter)

	return clamp(_fallback_hero_display_diameter(clip_size, category), min_display_diameter, max_display_diameter)


func _get_hero_visual_size_ratio(object_diameter_km: float, category: String) -> float:
	var real_ratio: float = max(object_diameter_km / HERO_EARTH_DIAMETER_KM, 0.01)

	match category:
		"star":
			return max(1.18, pow(real_ratio, HERO_STAR_SIZE_POWER))

		"moon", "satellite":
			return pow(real_ratio, HERO_SMALL_BODY_SIZE_POWER)

		"dwarf_planet":
			return min(0.92, pow(real_ratio, HERO_SMALL_BODY_SIZE_POWER))

		_:
			return max(0.18, pow(real_ratio, HERO_PLANET_SIZE_POWER))


func _parse_hero_first_number(value: String) -> float:
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


func _hero_body_category() -> String:
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


func _get_hero_object_diameter_km() -> float:
	if data == null:
		return 0.0

	var parsed := _parse_hero_first_number(data.diameter_km)

	if parsed > 0.0:
		return parsed

	var category := _hero_body_category()
	var archetype := data.archetype_id.strip_edges().to_lower()
	var preset := data.planet_preset.strip_edges().to_lower()
	var name := data.name.strip_edges().to_lower()
	var id := data.instance_id.strip_edges().to_lower()

	if category == "star":
		return HERO_EARTH_DIAMETER_KM * 109.0

	if name.contains("jupiter") or id.contains("jupiter"):
		return 139820.0

	if name.contains("saturn") or id.contains("saturn"):
		return 116460.0

	if name.contains("uranus") or id.contains("uranus"):
		return 50724.0

	if name.contains("neptune") or id.contains("neptune"):
		return 49244.0

	if name.contains("earth") or id.contains("earth"):
		return HERO_EARTH_DIAMETER_KM

	if name.contains("venus") or id.contains("venus"):
		return 12104.0

	if name.contains("mars") or id.contains("mars"):
		return 6779.0

	if name.contains("mercury") or id.contains("mercury"):
		return 4879.0

	if archetype.contains("gas") or preset.contains("gas"):
		return HERO_EARTH_DIAMETER_KM * 8.5

	if archetype.contains("ice"):
		return HERO_EARTH_DIAMETER_KM * 4.0

	if category == "satellite" or category == "moon":
		return HERO_EARTH_DIAMETER_KM * 0.32

	if category == "dwarf_planet":
		return HERO_EARTH_DIAMETER_KM * 0.22

	return 0.0


func _fallback_hero_display_diameter(clip_size: Vector2, category: String) -> float:
	var base_size := min(clip_size.x, clip_size.y)
	var earth_display_diameter := clip_size.x * HERO_EARTH_PREVIEW_WIDTH_FILL
	var radius_ratio := float(max(data.planet_radius_px, 1)) / 142.0

	if category == "star":
		return base_size * HERO_STAR_MAX_VIEW_FILL

	if category == "satellite" or category == "moon":
		return earth_display_diameter * 0.68

	if category == "dwarf_planet":
		return earth_display_diameter * 0.58

	return earth_display_diameter * pow(max(radius_ratio, 0.05), HERO_PLANET_SIZE_POWER)


func _hero_visual_offset(id: String) -> Vector2:
	match id.strip_edges().to_lower():
		"saturn":
			return Vector2(0, -4)

		_:
			return Vector2.ZERO


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
