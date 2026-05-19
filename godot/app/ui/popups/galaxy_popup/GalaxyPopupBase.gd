extends CanvasLayer

@warning_ignore_start("unused_signal")
signal closed
signal config_value_changed(property_name: String, value)
signal reset_orbits_requested
signal center_anchor_requested
signal clear_trails_requested
signal feedback_refresh_requested
@warning_ignore_restore("unused_signal")

const FONT_PATH := "res://assets/fonts/JockeyOne-Regular.ttf"
const GALAXY_STATE_PATHS := [
	"/root/UnilearnGalaxyState",
	"/root/GalaxyState"
]

const POPUP_SLIDE_DURATION := 0.42
const POPUP_FADE_DURATION := 0.22
const DIM_FADE_DURATION := 0.26
const POPUP_SIDE_PADDING := 80.0

const BUTTON_PRESS_SCALE := Vector2(0.88, 0.88)
const BUTTON_RELEASE_SCALE := Vector2(1.10, 1.10)
const BUTTON_DOWN_TIME := 0.055
const BUTTON_UP_TIME := 0.11
const BUTTON_SETTLE_TIME := 0.10

const COLOR_PANEL := Color(0.0, 0.0, 0.0, 0.82)
const COLOR_BORDER := Color.WHITE
const COLOR_TEXT := Color.WHITE
const COLOR_SUBTITLE := Color(1.0, 1.0, 1.0, 0.58)
const COLOR_PLACEHOLDER := Color(1.0, 1.0, 1.0, 0.42)
const COLOR_SCROLL_TRACK := Color(1.0, 1.0, 1.0, 0.06)
const COLOR_SCROLL_GRAB := Color(1.0, 1.0, 1.0, 0.34)
const COLOR_SCROLL_GRAB_HOVER := Color(1.0, 1.0, 1.0, 0.52)
const COLOR_SOFT_PANEL := Color(1.0, 1.0, 1.0, 0.035)
const COLOR_DEEP_PANEL := Color(0.015, 0.018, 0.03, 0.94)

const STAT_KEYS := [
	"habitability",
	"magnetic_field",
	"atmosphere",
	"geology",
	"gravity",
	"radiation_safety"
]

const STAT_TITLES := {
	"habitability": "Habitability",
	"magnetic_field": "Magnetic Field",
	"atmosphere": "Atmosphere",
	"geology": "Geology",
	"gravity": "Gravity",
	"radiation_safety": "Radiation Safety"
}

const STAT_DESCRIPTIONS := {
	"habitability": "Life-support potential after atmosphere, radiation, gravity, and field protection are coupled.",
	"magnetic_field": "System-wide shielding, stellar influence, and electrically active worlds.",
	"atmosphere": "Atmospheric stability after gravity, magnetic protection, and radiation pressure are mixed.",
	"geology": "Surface activity, internal heat, material cycling, and orbit-driven disturbance.",
	"gravity": "How well the system keeps bodies bound without becoming violently unstable.",
	"radiation_safety": "Safety score after stars, magnetism, atmosphere, and shielding are factored together."
}

@export var panel_width_ratio: float = 0.96
@export var panel_height_ratio: float = 0.96
@export var panel_max_width: float = 1380.0
@export var panel_max_height: float = 1260.0
@export var panel_padding_x: int = 34
@export var panel_padding_y: int = 34

@export var content_separation: int = 24
@export var slider_row_height: float = 230.0
@export var toggle_row_height: float = 116.0
@export var action_button_height: float = 210.0

var config: SimulationPhysicsConfig = null
var reduce_motion_enabled: bool = false
var system_objects: Array = []

@warning_ignore_start("unused_private_class_variable")
var _root: Control
var _dim: ColorRect
var _slide_root: Control
var _panel: PanelContainer
var _body_root: Control
var _scroll: ScrollContainer
var _scroll_margin: MarginContainer
var _content: VBoxContainer
var _tab_bar: HBoxContainer
var _data_tab_button: Button
var _behavior_tab_button: Button
var _commands_tab_button: Button
var _results_tab_button: Button
var _data_content: VBoxContainer
var _behavior_content: VBoxContainer
var _commands_content: VBoxContainer
var _results_content: VBoxContainer
var _active_tab: String = "data"

var _center_position := Vector2.ZERO
var _closing := false
var _popup_tween: Tween
var _button_tween: Tween
var _app_font: Font = null

var _galaxy_state_node: Node = null
var _settings_node: Node = null
var _sfx_node: Node = null

var _style_cache: Dictionary = {}
var _sliders: Dictionary = {}
var _value_labels: Dictionary = {}
var _toggles: Dictionary = {}
var _action_buttons: Array[Button] = []
var _lines: Array[ColorRect] = []

var _system_feedback: Dictionary = {}
var _stat_widgets: Dictionary = {}
var _system_score_label: Label = null
var _system_grade_label: Label = null
var _system_profile_label: Label = null
var _system_count_label: Label = null
var _system_balance_label: Label = null
var _system_pressure_label: Label = null
var _system_mix_label: Label = null
var _system_scale_tag_label: Label = null
@warning_ignore_restore("unused_private_class_variable")


func setup(target_config: SimulationPhysicsConfig, _reduce_motion_enabled: bool = false, _system_objects: Array = []) -> void:
	config = target_config
	reduce_motion_enabled = _reduce_motion_enabled
	system_objects = _system_objects.duplicate()
	
	_galaxy_state_node = get_node_or_null("/root/GalaxyState")
	if _galaxy_state_node != null and config != null and _galaxy_state_node.has_method("apply_to_config"):
		_galaxy_state_node.apply_to_config(config)

	if is_inside_tree():
		_refresh_from_config()
		_refresh_system_feedback()
		_refresh_theme_live()


func set_system_objects(value: Array) -> void:
	system_objects = value.duplicate()
	_refresh_system_feedback()


func update_system_objects(value: Array) -> void:
	set_system_objects(value)


func _ready() -> void:
	layer = 1200
	process_mode = Node.PROCESS_MODE_ALWAYS

	_settings_node = get_node_or_null("/root/UnilearnUserSettings")
	_sfx_node = get_node_or_null("/root/UnilearnSFX")
	_app_font = load(FONT_PATH) as Font
	
	if config == null:
		config = SimulationPhysicsConfig.new()

	_load_saved_galaxy_config()

	_sync_reduce_motion_from_settings()
	_connect_settings_signal()
	_build_ui()
	_refresh_from_config()
	_refresh_system_feedback()
	_refresh_theme_live()

	await get_tree().process_frame
	await get_tree().process_frame

	if not is_inside_tree() or _closing:
		return

	_prepare_center_position()
	_style_scroll_bar()

	await _play_intro()


func _build_ui() -> void:
	pass


func _refresh_theme_live() -> void:
	pass


func _prepare_center_position() -> void:
	pass


func _play_intro() -> void:
	await get_tree().process_frame


func _apply_system_feedback_widgets() -> void:
	pass


func _make_base_style(bg: Color, border: Color, border_width: int = 0, radius: int = 0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	return style


func _panel_style() -> StyleBoxFlat:
	return _make_base_style(COLOR_PANEL, COLOR_BORDER, 5, 44)


func _control_style(bg: Color, border: Color, border_width: int = 4, radius: int = 34) -> StyleBoxFlat:
	var style := _make_base_style(bg, border, border_width, radius)
	style.content_margin_left = 28
	style.content_margin_right = 28
	style.content_margin_top = 27
	style.content_margin_bottom = 27
	return style


func _glass_panel_style() -> StyleBoxFlat:
	return _control_style(COLOR_SOFT_PANEL, Color(1.0, 1.0, 1.0, 0.55), 3, 34)


func _section_panel_style() -> StyleBoxFlat:
	return _control_style(Color(0.0, 0.0, 0.0, 0.24), Color(1.0, 1.0, 1.0, 0.82), 3, 34)


func _slider_card_style() -> StyleBoxFlat:
	return _control_style(Color(1.0, 1.0, 1.0, 0.018), Color(1.0, 1.0, 1.0, 0.72), 3, 32)


func _hero_score_style() -> StyleBoxFlat:
	return _control_style(_theme_accent_color(), Color.WHITE, 4, 38)


func _metric_card_style(color: Color) -> StyleBoxFlat:
	return _control_style(Color(1.0, 1.0, 1.0, 0.018), color.lerp(Color.WHITE, 0.20), 3, 30)


func _chip_style(color: Color, filled: bool = false) -> StyleBoxFlat:
	return _control_style(color if filled else Color.TRANSPARENT, color, 3, 24)


func _metric_bar_back_style() -> StyleBoxFlat:
	return _control_style(Color(1.0, 1.0, 1.0, 0.075), Color.TRANSPARENT, 0, 999)


func _metric_bar_fill_style(color: Color) -> StyleBoxFlat:
	return _control_style(color, Color.TRANSPARENT, 0, 999)


func _tabs_shell_style() -> StyleBoxFlat:
	return _control_style(Color(0.0, 0.0, 0.0, 0.26), Color.WHITE, 3, 34)


func _tab_button_style(active: bool, hovered: bool = false) -> StyleBoxFlat:
	var bg := _theme_accent_color() if active else Color.TRANSPARENT
	var border := Color.TRANSPARENT if active else Color.WHITE
	return _control_style(bg.lightened(0.08 if hovered and active else 0.0), border, 0 if active else 3, 22)


func _on_tab_button_down(button: Button) -> void:
	_on_button_down(button)


func _on_tab_button_up(button: Button) -> void:
	_on_button_up(button)


func _slider_track_style() -> StyleBoxFlat:
	return _control_style(Color.BLACK, Color.WHITE, 6, 999)


func _slider_grabber_area_style() -> StyleBoxFlat:
	return _control_style(Color.WHITE, Color.TRANSPARENT, 0, 999)


func _apply_slider_style(slider) -> void:
	if slider == null:
		return
	slider.track_bg_color = Color.BLACK
	slider.track_border_color = Color.WHITE
	slider.fill_color = Color.WHITE
	slider.knob_color = _theme_accent_color()


func _make_slider_grabber_texture(hovered: bool = false) -> Texture2D:
	var size := 90 if hovered else 82
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	var center := Vector2(size * 0.5, size * 0.5)
	var radius := float(size) * 0.44
	var color := _theme_accent_color().lightened(0.08) if hovered else _theme_accent_color()

	for y in range(size):
		for x in range(size):
			var point := Vector2(x + 0.5, y + 0.5)
			if point.distance_to(center) <= radius:
				image.set_pixel(x, y, color)

	return ImageTexture.create_from_image(image)


func _theme_accent_color() -> Color:
	return Color.WHITE


func _theme_text_color() -> Color:
	return Color.WHITE


func _theme_subtitle_color() -> Color:
	return COLOR_SUBTITLE


func _theme_line_color() -> Color:
	return Color.WHITE


func _theme_hover_color() -> Color:
	return Color(1.0, 1.0, 1.0, 0.055)


func _theme_pressed_color() -> Color:
	return Color(1.0, 0.78, 0.18, 0.14)



func _stat_color(stat_key: String) -> Color:
	match stat_key:
		"habitability":
			return Color("#7DFF8A")
		"magnetic_field":
			return Color("#B875FF")
		"atmosphere":
			return Color("#63D8FF")
		"geology":
			return Color("#FF9D42")
		"gravity":
			return Color("#FF5F7E")
		"radiation_safety":
			return Color("#FFE45C")
		_:
			return _theme_accent_color()

func _update_action_button_styles(_button: Button = null) -> void:
	pass



func _setup_dynamic_theme_refresh() -> void:
	pass


func _refresh_dynamic_theme(_force: bool = false) -> void:
	pass


func _register_accent_panel(_panel: PanelContainer, _style_method: String) -> void:
	pass


func _system_score_shell_style() -> StyleBoxFlat:
	return _control_style(Color.BLACK, Color.TRANSPARENT, 0, 30)


func _system_score_tile_style() -> StyleBoxFlat:
	return _control_style(_theme_accent_color(), _theme_accent_color(), 0, 28)


func _system_score_full_row_style() -> StyleBoxFlat:
	return _control_style(_theme_accent_color(), _theme_accent_color(), 0, 30)


func _system_metric_chip_style(color: Color) -> StyleBoxFlat:
	return _control_style(Color.BLACK, color, 2, 24)


func _system_attribute_panel_style() -> StyleBoxFlat:
	return _control_style(Color.BLACK, Color.WHITE, 3, 34)


func _system_attribute_bar_back_style() -> StyleBoxFlat:
	return _control_style(Color(0.035, 0.038, 0.048, 1.0), Color.TRANSPARENT, 0, 999)


func _system_attribute_bar_fill_style(color: Color) -> StyleBoxFlat:
	return _control_style(color, Color.TRANSPARENT, 0, 999)


func _active_bodies_panel_style() -> StyleBoxFlat:
	return _control_style(Color.BLACK, Color.WHITE, 3, 30)


func _active_bodies_counter_style() -> StyleBoxFlat:
	return _control_style(Color.BLACK, Color.WHITE, 3, 22)


func _active_body_row_style() -> StyleBoxFlat:
	return _control_style(Color.WHITE, Color.WHITE, 0, 24)


func _active_body_marker_style(color: Color) -> StyleBoxFlat:
	return _control_style(color, Color.BLACK, 3, 12)


func _body_type_color(_body_type: String) -> Color:
	return _theme_accent_color()


func _apply_app_font(control: Control) -> void:
	if _app_font != null and is_instance_valid(control):
		control.add_theme_font_override("font", _app_font)


func _find_galaxy_state_node() -> Node:
	if _galaxy_state_node != null and is_instance_valid(_galaxy_state_node):
		return _galaxy_state_node

	for path in GALAXY_STATE_PATHS:
		var node := get_node_or_null(str(path))
		if node != null:
			_galaxy_state_node = node
			return _galaxy_state_node

	return null


func _load_saved_galaxy_config() -> void:
	if config == null:
		config = SimulationPhysicsConfig.new()

	var state := _find_galaxy_state_node()
	if state == null:
		return

	if state.has_method("apply_to_config"):
		state.call("apply_to_config", config)
		return

	var saved := _read_saved_galaxy_config_dictionary(state)
	if saved.is_empty():
		return

	if config.has_method("apply_save_dict"):
		config.call("apply_save_dict", saved)
		return

	for key in saved.keys():
		var property_name := str(key)
		if not _object_has_property(config, property_name):
			continue

		if config.has_method("apply_safe_value"):
			config.call("apply_safe_value", property_name, saved[key])
		else:
			config.set(property_name, saved[key])


func _read_saved_galaxy_config_dictionary(state: Node) -> Dictionary:
	if state == null:
		return {}

	if state.has_method("get_config_dictionary"):
		var result = state.call("get_config_dictionary")
		if result is Dictionary:
			return result

	if state.has_method("get_config_data"):
		var result = state.call("get_config_data")
		if result is Dictionary:
			return result

	for property_name in ["config_values", "config_data", "galaxy_config", "physics_config_data"]:
		if _object_has_property(state, property_name):
			var value = state.get(property_name)
			if value is Dictionary:
				return value

	return {}


func _save_galaxy_config(immediate: bool = true) -> void:
	if config == null:
		return

	var state := _find_galaxy_state_node()
	if state == null:
		return

	if state.has_method("capture_config"):
		state.call("capture_config", config, immediate)
		return

	if state.has_method("save_config"):
		state.call("save_config", config, immediate)
		return

	if state.has_method("set_config_dictionary"):
		state.call("set_config_dictionary", _config_to_dictionary(), immediate)
		return

	if _object_has_property(state, "config_values"):
		state.set("config_values", _config_to_dictionary())

	if immediate and state.has_method("save"):
		state.call("save")


func _capture_runtime_galaxy_state(immediate: bool = true) -> void:
	var state := _find_galaxy_state_node()
	if state == null:
		return

	if state.has_method("capture_runtime"):
		state.call("capture_runtime", system_objects, config, immediate)
		return

	_save_galaxy_config(immediate)


func _config_to_dictionary() -> Dictionary:
	var result := {}
	if config == null:
		return result

	for property in config.get_property_list():
		if not property.has("name"):
			continue
		var property_name := str(property["name"])
		if property_name.begins_with("resource_") or property_name in ["script"]:
			continue
		result[property_name] = config.get(property_name)

	return result


func _connect_settings_signal() -> void:
	if _settings_node == null:
		return
	if not _settings_node.has_signal("settings_changed"):
		return

	var callable := Callable(self, "_on_settings_changed")
	if not _settings_node.settings_changed.is_connected(callable):
		_settings_node.settings_changed.connect(callable)


func _on_settings_changed() -> void:
	_sync_reduce_motion_from_settings()
	_refresh_theme_live()


func _sync_reduce_motion_from_settings() -> void:
	if _settings_node == null:
		_settings_node = get_node_or_null("/root/UnilearnUserSettings")
	if _settings_node == null:
		return
	if _object_has_property(_settings_node, "reduce_motion_enabled"):
		reduce_motion_enabled = bool(_settings_node.get("reduce_motion_enabled"))


func _motion_duration(duration: float) -> float:
	return 0.0 if reduce_motion_enabled else duration


func _should_reduce_motion() -> bool:
	return reduce_motion_enabled


func close_popup() -> void:
	if _closing:
		return
	
	_capture_runtime_galaxy_state(true)

	_closing = true
	_play_sfx("close")

	if _popup_tween != null and _popup_tween.is_valid():
		_popup_tween.kill()

	if _should_reduce_motion():
		closed.emit()
		queue_free()
		return

	if not is_instance_valid(_slide_root) or not is_instance_valid(_dim):
		closed.emit()
		queue_free()
		return

	_slide_root.position = _center_position
	_slide_root.modulate.a = 1.0

	_popup_tween = create_tween()
	_popup_tween.set_parallel(true)
	_popup_tween.tween_property(_slide_root, "position", _get_right_offscreen_position(), POPUP_SLIDE_DURATION)\
		.set_trans(Tween.TRANS_CUBIC)\
		.set_ease(Tween.EASE_IN)
	_popup_tween.tween_property(_slide_root, "modulate:a", 0.0, POPUP_FADE_DURATION)\
		.set_delay(max(0.0, POPUP_SLIDE_DURATION - POPUP_FADE_DURATION))\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN)
	_popup_tween.tween_property(_dim, "modulate:a", 0.0, DIM_FADE_DURATION)\
		.set_delay(max(0.0, POPUP_SLIDE_DURATION - DIM_FADE_DURATION))\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_IN)

	await _popup_tween.finished

	if is_inside_tree():
		closed.emit()
		queue_free()


func _set_config_value(property_name: String, value) -> void:
	if config == null:
		config = SimulationPhysicsConfig.new()
	if not _object_has_property(config, property_name):
		return

	var applied := false

	if config.has_method("apply_safe_value"):
		applied = bool(config.call("apply_safe_value", property_name, value))
	else:
		config.set(property_name, value)
		applied = true

	if not applied:
		return

	var saved_value = config.get(property_name)
	var state := _find_galaxy_state_node()
	if state != null:
		if state.has_method("set_config_value"):
			state.call("set_config_value", property_name, saved_value, true)
		else:
			_save_galaxy_config(true)

	config_value_changed.emit(property_name, saved_value)


func _refresh_from_config() -> void:
	if config == null:
		return

	_apply_slider_value("simulation_speed")
	_apply_slider_value("revolution_speed_multiplier")
	_apply_slider_value("center_anchor_strength")
	_apply_slider_value("orbit_lock_strength")
	_apply_slider_value("orbit_distance_padding")
	_apply_slider_value("orbit_spacing_multiplier")
	_apply_slider_value("moon_orbit_spacing_multiplier")
	_apply_slider_value("binary_orbit_spacing_multiplier")
	_apply_slider_value("gravitational_constant")
	_apply_slider_value("drag_throw_strength")
	_apply_slider_value("max_drag_throw_speed")
	_apply_slider_value("max_trail_points")
	_apply_toggle_value("stable_orbit_mode")
	_apply_toggle_value("hierarchical_orbits_enabled")
	_apply_toggle_value("binary_orbits_enabled")
	_apply_toggle_value("same_type_binary_enabled")
	_apply_toggle_value("center_largest_body")
	_apply_toggle_value("lock_planets_to_largest_body")
	_apply_toggle_value("ignore_drag_throw_velocity")
	_apply_toggle_value("trails_enabled")


func _apply_slider_value(property_name: String) -> void:
	if config == null or not _object_has_property(config, property_name):
		return
	if not _sliders.has(property_name):
		return

	var value = config.get(property_name)
	if value == null:
		return

	var slider = _sliders[property_name]
	if not is_instance_valid(slider):
		return

	slider.set_value_no_signal(float(value))

	if _value_labels.has(property_name):
		var value_label: Label = _value_labels[property_name]
		if is_instance_valid(value_label):
			value_label.text = _format_slider_scale(slider, value)


func _apply_toggle_value(property_name: String) -> void:
	if config == null or not _object_has_property(config, property_name):
		return
	if not _toggles.has(property_name):
		return

	var value = config.get(property_name)
	if value == null:
		return

	var toggle = _toggles[property_name]
	if is_instance_valid(toggle):
		if toggle.has_method("set_value_no_signal"):
			toggle.set_value_no_signal(bool(value))
		elif toggle.has_method("set_pressed_no_signal"):
			toggle.set_pressed_no_signal(bool(value))


func _refresh_system_feedback() -> void:
	_system_feedback = _calculate_system_feedback(system_objects)
	_apply_system_feedback_widgets()


func _calculate_system_feedback(objects: Array) -> Dictionary:
	var samples: Array = []
	var categories := {}
	var star_count: int = 0
	var planet_count: int = 0
	var moon_count: int = 0
	var total_mass: float = 0.0
	var total_level: int = 0
	var max_level: int = 0

	for object in objects:
		var meta := _extract_object_meta(object)
		var scores := _extract_object_scores(object, meta)
		var category := str(meta.get("category", "unknown"))
		var weight := float(meta.get("weight", 1.0))
		var body_level: int = int(meta.get("level", 1))

		if weight <= 0.0:
			continue

		categories[category] = int(categories.get(category, 0)) + 1
		total_mass += float(meta.get("mass", weight))
		total_level += int(max(body_level, 1))
		max_level = int(max(max_level, body_level))

		if category == "star" or category == "sun":
			star_count += 1
		elif category == "moon" or category == "satellite":
			moon_count += 1
		else:
			planet_count += 1

		samples.append({
			"meta": meta,
			"scores": scores,
			"weight": weight,
		})

	if samples.is_empty():
		var empty_stats := {}
		for stat_key in STAT_KEYS:
			empty_stats[stat_key] = 0
		return {
			"stats": empty_stats,
			"raw_stats": empty_stats.duplicate(true),
			"system_score": 0,
			"grade": "--",
			"weakest": "--",
			"strongest": "--",
			"balance": 0,
			"profile": "No active bodies yet. Add a star, planet, or moon to start reading the simulation.",
			"pressure": "Awaiting bodies",
			"mix": "Awaiting bodies",
			"object_count": 0,
			"active_bodies": [],
			"star_count": 0,
			"planet_count": 0,
			"moon_count": 0,
			"total_mass": 0.0,
			"average_level": 0.0,
			"max_level": 0,
			"scale_label": "EMPTY",
		}

	var raw := {}
	for stat_key in STAT_KEYS:
		raw[stat_key] = _aggregate_stat(samples, stat_key)

	var coupled := {}
	coupled["habitability"] = _clampi(round(raw["habitability"] * 0.54 + raw["atmosphere"] * 0.18 + raw["radiation_safety"] * 0.12 + raw["gravity"] * 0.10 + raw["magnetic_field"] * 0.06), 0, 100)
	coupled["magnetic_field"] = _clampi(round(raw["magnetic_field"] * 0.70 + raw["geology"] * 0.16 + raw["radiation_safety"] * 0.08 + raw["gravity"] * 0.06), 0, 100)
	coupled["atmosphere"] = _clampi(round(raw["atmosphere"] * 0.62 + raw["magnetic_field"] * 0.16 + raw["gravity"] * 0.12 + raw["radiation_safety"] * 0.10), 0, 100)
	coupled["geology"] = _clampi(round(raw["geology"] * 0.72 + raw["gravity"] * 0.16 + raw["magnetic_field"] * 0.12), 0, 100)
	coupled["gravity"] = _clampi(round(raw["gravity"] * 0.78 + _gravity_architecture_score(samples) * 0.22), 0, 100)
	coupled["radiation_safety"] = _clampi(round(raw["radiation_safety"] * 0.62 + raw["magnetic_field"] * 0.18 + raw["atmosphere"] * 0.12 - _stellar_pressure_penalty(samples, star_count) + 8.0), 0, 100)

	var average_level: float = float(total_level) / max(float(samples.size()), 1.0)
	var level_tag: String = ("MAX %d" % max_level) if max_level > 0 else "LVL --"
	var system_score: int = _calculate_overall_score(coupled, average_level, max_level, samples.size(), star_count, moon_count)
	var weakest: String = _weakest_stat(coupled)
	var strongest: String = _strongest_stat(coupled)
	var balance: int = _balance_score(coupled)
	var profile: String = _profile_label(system_score, balance, star_count, planet_count, moon_count)
	var pressure: String = _pressure_label(coupled, star_count, samples.size())
	var mix: String = _mix_label(categories)
	var active_bodies: Array = _extract_active_body_rows(objects)

	return {
		"stats": coupled,
		"raw_stats": raw,
		"system_score": system_score,
		"grade": _grade_for_score(system_score),
		"weakest": weakest,
		"strongest": strongest,
		"balance": balance,
		"profile": profile,
		"pressure": pressure,
		"mix": mix,
		"object_count": samples.size(),
		"active_bodies": active_bodies,
		"star_count": star_count,
		"planet_count": planet_count,
		"moon_count": moon_count,
		"total_mass": total_mass,
		"average_level": average_level,
		"max_level": max_level,
		"scale_label": level_tag,
	}


func _aggregate_stat(samples: Array, stat_key: String) -> float:
	if samples.is_empty():
		return 50.0

	var weighted_sum := 0.0
	var weight_sum := 0.0
	var square_sum := 0.0
	var inverse_sum := 0.0
	var inverse_weight := 0.0
	var values: Array[float] = []

	for sample in samples:
		var scores: Dictionary = sample["scores"]
		var meta: Dictionary = sample["meta"]
		var value := float(scores.get(stat_key, 50.0))
		var weight := float(sample.get("weight", 1.0)) * _stat_role_multiplier(stat_key, meta)
		weight = clamp(weight, 0.05, 20.0)

		weighted_sum += value * weight
		square_sum += value * value * weight
		weight_sum += weight
		inverse_sum += weight / max(value + 8.0, 1.0)
		inverse_weight += weight
		values.append(value)

	if weight_sum <= 0.0:
		return 50.0

	var mean := weighted_sum / weight_sum
	var rms := sqrt(square_sum / weight_sum)
	var harmonic: float = (inverse_weight / max(inverse_sum, 0.001)) - 8.0
	var diversity_bonus := _distribution_bonus(values)
	var pressure_adjust := _stat_pressure_adjustment(stat_key, samples)

	return clamp(mean * 0.50 + rms * 0.20 + harmonic * 0.20 + diversity_bonus + pressure_adjust, 0.0, 100.0)


func _distribution_bonus(values: Array) -> float:
	if values.size() <= 1:
		return 0.0

	var mean := 0.0
	for v in values:
		mean += float(v)
	mean /= float(values.size())

	var variance := 0.0
	for v in values:
		variance += pow(float(v) - mean, 2.0)
	variance /= float(values.size())

	var spread := sqrt(variance)
	return clamp(8.0 - spread * 0.16, -6.0, 8.0)


func _stat_pressure_adjustment(stat_key: String, samples: Array) -> float:
	var star_pressure := 0.0
	var moon_support := 0.0

	for sample in samples:
		var meta: Dictionary = sample["meta"]
		var category: String = str(meta.get("category", ""))
		var weight := float(sample.get("weight", 1.0))

		if category == "star" or category == "sun":
			star_pressure += weight
		elif category == "moon" or category == "satellite":
			moon_support += weight

	match stat_key:
		"radiation_safety":
			return -min(star_pressure * 1.8, 16.0)
		"gravity":
			return min(moon_support * 0.85, 8.0)
		"geology":
			return min(moon_support * 0.65, 6.0)
		_:
			return 0.0


func _gravity_architecture_score(samples: Array) -> float:
	if samples.is_empty():
		return 50.0

	var massive := 0
	var small := 0
	for sample in samples:
		var weight := float(sample.get("weight", 1.0))
		if weight >= 4.0:
			massive += 1
		else:
			small += 1

	var architecture: float = 58.0 + min(float(small) * 4.0, 18.0) - max(float(massive - 1) * 7.0, 0.0)
	return clamp(architecture, 0.0, 100.0)


func _stellar_pressure_penalty(samples: Array, star_count: int) -> float:
	if star_count <= 0:
		return 0.0

	var penalty := float(star_count) * 5.0
	for sample in samples:
		var meta: Dictionary = sample["meta"]
		var category: String = str(meta.get("category", ""))
		if category == "star" or category == "sun":
			penalty += float(sample.get("weight", 1.0)) * 0.6

	return clamp(penalty, 0.0, 28.0)


func _calculate_overall_score(stats: Dictionary, average_level: float = 1.0, max_level: int = 1, object_count: int = 0, star_count: int = 0, moon_count: int = 0) -> int:
	if object_count <= 0:
		return 0

	var weighted := 0.0
	var harmonic_inverse := 0.0
	var weakest := 100.0
	var strongest := 0.0
	var count := 0.0

	for stat_key in STAT_KEYS:
		var value := float(stats.get(stat_key, 50.0))
		weighted += value * _overall_stat_weight(stat_key)
		harmonic_inverse += _overall_stat_weight(stat_key) / max(value + 6.0, 1.0)
		weakest = min(weakest, value)
		strongest = max(strongest, value)
		count += _overall_stat_weight(stat_key)

	var mean: float = weighted / max(count, 0.001)
	var harmonic: float = (count / max(harmonic_inverse, 0.001)) - 6.0
	var balance: int = _balance_score(stats)
	var base_score := mean * 0.44 + harmonic * 0.30 + weakest * 0.10 + strongest * 0.05 + balance * 0.11
	var level_bonus: float = sqrt(max(average_level, 1.0)) * 8.5 + sqrt(max(float(max_level), 1.0)) * 5.0
	var architecture_bonus: float = min(float(object_count) * 2.6, 28.0) + min(float(moon_count) * 1.4, 18.0)
	if star_count == 1:
		architecture_bonus += 18.0
	elif star_count == 2:
		architecture_bonus += 10.0
	elif star_count > 2:
		architecture_bonus -= float(star_count - 2) * 10.0

	var result := base_score + level_bonus + architecture_bonus
	return _clampi(round(result), 0, 1221)


func _overall_stat_weight(stat_key: String) -> float:
	match stat_key:
		"habitability":
			return 1.12
		"radiation_safety":
			return 1.08
		"gravity":
			return 1.02
		_:
			return 1.0


func _balance_score(stats: Dictionary) -> int:
	var values: Array[float] = []
	for stat_key in STAT_KEYS:
		values.append(float(stats.get(stat_key, 50.0)))

	var mean := 0.0
	for v in values:
		mean += v
	mean /= max(float(values.size()), 1.0)

	var variance := 0.0
	for v in values:
		variance += pow(v - mean, 2.0)
	variance /= max(float(values.size()), 1.0)

	return _clampi(round(100.0 - sqrt(variance) * 1.65), 0, 100)


func _weakest_stat(stats: Dictionary) -> String:
	var best_key := "habitability"
	var best_value := INF
	for stat_key in STAT_KEYS:
		var value := float(stats.get(stat_key, 50.0))
		if value < best_value:
			best_value = value
			best_key = stat_key
	return str(STAT_TITLES.get(best_key, best_key))


func _strongest_stat(stats: Dictionary) -> String:
	var best_key := "habitability"
	var best_value := -INF
	for stat_key in STAT_KEYS:
		var value := float(stats.get(stat_key, 50.0))
		if value > best_value:
			best_value = value
			best_key = stat_key
	return str(STAT_TITLES.get(best_key, best_key))


func _profile_label(score: int, balance: int, star_count: int, planet_count: int, moon_count: int) -> String:
	if planet_count + moon_count + star_count <= 0:
		return "No active bodies yet"
	if score >= 82 and balance >= 72:
		return "Stable high-potential system"
	if star_count > 1:
		return "Multi-star pressure system"
	if balance < 45:
		return "Unbalanced experimental system"
	if moon_count >= planet_count and moon_count > 0:
		return "Satellite-heavy architecture"
	if score < 45:
		return "Fragile early system"
	return "Balanced sandbox system"


func _pressure_label(stats: Dictionary, star_count: int, object_count: int) -> String:
	if object_count <= 0:
		return "Add planets to receive feedback"
	var radiation := int(stats.get("radiation_safety", 50))
	var gravity := int(stats.get("gravity", 50))
	if star_count > 0 and radiation < 48:
		return "High stellar pressure"
	if gravity < 42:
		return "Weak orbital binding"
	if gravity > 78 and radiation > 65:
		return "Strong protected structure"
	return "Moderate system pressure"


func _mix_label(categories: Dictionary) -> String:
	if categories.is_empty():
		return "Awaiting bodies"

	var parts: Array[String] = []
	for key in categories.keys():
		parts.append("%s x%d" % [str(key).replace("_", " ").to_upper(), int(categories[key])])
	parts.sort()
	return "  •  ".join(parts)


func _grade_for_score(score: int) -> String:
	if score <= 0:
		return "--"
	if score >= 1000:
		return "Ω"
	if score >= 520:
		return "SSS"
	if score >= 260:
		return "SS"
	if score >= 122:
		return "S+"
	if score >= 90:
		return "S"
	if score >= 80:
		return "A"
	if score >= 68:
		return "B"
	if score >= 55:
		return "C"
	if score >= 42:
		return "D"
	return "E"


func _extract_active_body_rows(objects: Array) -> Array:
	var result: Array = []

	for i in range(objects.size()):
		var object: Variant = objects[i]
		if object == null:
			continue

		var meta: Dictionary = _extract_object_meta(object)
		var source: Variant = _extract_source_data(object)
		var name: String = str(meta.get("name", _read_value(source, "name", _read_value(object, "name", "Unknown body")))).strip_edges()
		var body_type: String = str(meta.get("category", _read_value(source, "object_category", _read_value(object, "object_category", "planet")))).strip_edges().to_lower().replace(" ", "_")
		var marker_color: Color = _extract_object_main_color(object, meta)
		var order_index: int = i

		if object is Dictionary:
			var body_dictionary: Dictionary = object
			order_index = int(body_dictionary.get("order_index", i))
			if name.is_empty():
				name = str(body_dictionary.get("title", body_dictionary.get("card_id", "Unknown body"))).strip_edges()
		else:
			order_index = int(_read_value(object, "order_index", i))

		if name.is_empty():
			name = "Unknown body"
		if body_type.is_empty() or body_type == "unknown":
			body_type = "planet"

		result.append({
			"name": name,
			"type": body_type,
			"marker_color": marker_color,
			"marker_color_hex": marker_color.to_html(true),
			"order_index": order_index,
		})

	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("order_index", 0)) < int(b.get("order_index", 0))
	)

	return result


func _extract_object_meta(object) -> Dictionary:
	var source = _extract_source_data(object)
	var category := str(_read_value(source, "object_category", _read_value(object, "object_category", "planet"))).strip_edges().to_lower().replace(" ", "_")
	var preset := str(_read_value(source, "planet_preset", _read_value(object, "planet_preset", ""))).strip_edges().to_lower().replace(" ", "_")
	var name := str(_read_value(source, "name", _read_value(object, "name", "Object")))
	var mass := float(_read_value(object, "mass", _estimate_mass_from_category(category, preset, name)))
	var radius := float(_read_value(object, "radius_world", _read_value(source, "planet_radius_px", 1.0)))
	var weight := _mass_to_weight(mass, category, preset)
	var level := int(_read_value(source, "game_level", _read_value(object, "game_level", 1)))
	var composition := str(_read_value(source, "composition", _read_value(object, "composition", ""))).strip_edges().to_lower()
	var atmosphere := str(_read_value(source, "atmosphere", _read_value(object, "atmosphere", ""))).strip_edges().to_lower()
	var gravity_text := str(_read_value(source, "gravity", _read_value(object, "gravity_text", ""))).strip_edges().to_lower()

	return {
		"category": category,
		"preset": preset,
		"name": name,
		"mass": mass,
		"radius": radius,
		"weight": weight,
		"level": max(level, 1),
		"composition": composition,
		"atmosphere_text": atmosphere,
		"gravity_text": gravity_text,
	}


func _extract_object_main_color(object, meta: Dictionary = {}) -> Color:
	var source: Variant = _extract_source_data(object)
	var source_color: Color = _resolve_main_color_from_value(source, Color.TRANSPARENT)
	if source_color.a > 0.0:
		return source_color

	var data_value: Variant = _read_value(object, "data", null)
	var data_color: Color = _resolve_main_color_from_value(data_value, Color.TRANSPARENT)
	if data_color.a > 0.0:
		return data_color

	var object_color: Color = _resolve_main_color_from_value(object, Color.TRANSPARENT)
	if object_color.a > 0.0:
		return object_color

	var body_type := str(meta.get("category", _read_value(source, "object_category", _read_value(object, "object_category", "planet")))).strip_edges().to_lower().replace(" ", "_")
	return _body_type_color(body_type)


func _resolve_main_color_from_value(value, fallback: Color = Color.TRANSPARENT) -> Color:
	if value == null:
		return fallback

	if value is Object and value.has_method("get_hero_main_color"):
		var method_color: Variant = value.call("get_hero_main_color")
		if method_color is Color:
			var resolved_method_color: Color = method_color
			resolved_method_color.a = 1.0
			return resolved_method_color

	var marker_color: Variant = _read_value(value, "marker_color", null)
	if marker_color is Color:
		var resolved_marker_color: Color = marker_color
		resolved_marker_color.a = 1.0
		return resolved_marker_color

	var marker_hex_color := str(_read_value(value, "marker_color_hex", "")).strip_edges()
	if not marker_hex_color.is_empty():
		return Color(marker_hex_color)

	var direct_color: Variant = _read_value(value, "hero_main_color", null)
	if direct_color is Color:
		var resolved_direct_color: Color = direct_color
		resolved_direct_color.a = 1.0
		return resolved_direct_color

	var hex_color := str(_read_value(value, "hero_main_color_hex", "")).strip_edges()
	if not hex_color.is_empty():
		return Color(hex_color)

	var custom_colors: Variant = _read_value(value, "custom_colors", null)
	var preset := str(_read_value(value, "planet_preset", "")).strip_edges().to_lower()
	var palette_color: Color = _pick_main_color_from_palette(custom_colors, preset, fallback)
	if palette_color.a > 0.0:
		return palette_color

	return fallback


func _pick_main_color_from_palette(colors_value, preset: String = "", fallback: Color = Color.TRANSPARENT) -> Color:
	var colors: Array[Color] = []

	if colors_value is PackedColorArray:
		for color in colors_value:
			colors.append(color)
	elif colors_value is Array:
		for item in colors_value:
			if item is Color:
				colors.append(item)
			else:
				var color_text := str(item).strip_edges()
				if not color_text.is_empty():
					colors.append(Color(color_text))

	if colors.is_empty():
		return fallback

	var preset_key := preset.strip_edges().to_lower().replace(" ", "_")
	var best: Color = colors[0]
	var best_score := -INF

	for raw_color in colors:
		var color: Color = raw_color
		var brightness := (color.r + color.g + color.b) / 3.0
		var max_channel: float = max(color.r, max(color.g, color.b))
		var min_channel: float = min(color.r, min(color.g, color.b))
		var saturation: float = max_channel - min_channel
		var score := saturation * 1.9 + brightness * 0.45

		if brightness < 0.08:
			score -= 1.2
		if brightness > 0.88 and saturation < 0.16:
			score -= 0.9
		if preset_key == "star" and color.r >= color.g and color.g >= color.b:
			score += 0.28
		if preset_key.contains("ice") and color.b >= color.r:
			score += 0.18
		if preset_key.contains("lava") and color.r >= color.g:
			score += 0.22
		if preset_key.contains("gas") and color.r >= color.b:
			score += 0.10

		if score > best_score:
			best_score = score
			best = color

	best.a = 1.0
	return best


func _extract_source_data(object):
	if object == null:
		return null

	var direct = _read_value(object, "source_planet_data", null)
	if direct != null:
		return direct

	var data_value = _read_value(object, "data", null)
	if data_value != null:
		var source = _read_value(data_value, "source_planet_data", null)
		if source != null:
			return source

	return object


func _extract_object_scores(object, meta: Dictionary) -> Dictionary:
	var source = _extract_source_data(object)
	var score_array = _read_value(source, "game_attribute_scores", null)

	if score_array == null:
		score_array = _read_value(object, "game_attribute_scores", null)

	var result := {}
	if score_array is Array:
		for item in score_array:
			if not item is Dictionary:
				continue
			var key := _normalize_stat_key(str(item.get("title", "")))
			if key.is_empty():
				continue
			result[key] = _clampi(int(item.get("value", 50)), 0, 100)

	for stat_key in STAT_KEYS:
		if not result.has(stat_key):
			result[stat_key] = _fallback_score_for_stat(stat_key, meta)

	return _adjust_scores_for_meta(result, meta)


func _adjust_scores_for_meta(scores: Dictionary, meta: Dictionary) -> Dictionary:
	var result: Dictionary = scores.duplicate(true) as Dictionary
	var composition: String = str(meta.get("composition", ""))
	var atmosphere_text: String = str(meta.get("atmosphere_text", ""))
	var gravity_text: String = str(meta.get("gravity_text", ""))
	var preset: String = str(meta.get("preset", ""))
	var category: String = str(meta.get("category", ""))
	var level: int = max(int(meta.get("level", 1)), 1)
	var level_bonus: int = int(min(int(sqrt(float(level)) * 3.5), 38))

	for stat_key in STAT_KEYS:
		result[stat_key] = _clampi(int(result.get(stat_key, 50)) + level_bonus, 0, 100)

	if composition.contains("water") or composition.contains("ocean") or composition.contains("ice"):
		result["habitability"] = _clampi(int(result.get("habitability", 50)) + 9, 0, 100)
		result["geology"] = _clampi(int(result.get("geology", 50)) + 5, 0, 100)
	if composition.contains("iron") or composition.contains("metal") or composition.contains("core"):
		result["magnetic_field"] = _clampi(int(result.get("magnetic_field", 50)) + 10, 0, 100)
		result["geology"] = _clampi(int(result.get("geology", 50)) + 4, 0, 100)
	if atmosphere_text.contains("oxygen") or atmosphere_text.contains("nitrogen") or atmosphere_text.contains("breath"):
		result["atmosphere"] = _clampi(int(result.get("atmosphere", 50)) + 13, 0, 100)
		result["habitability"] = _clampi(int(result.get("habitability", 50)) + 10, 0, 100)
		result["radiation_safety"] = _clampi(int(result.get("radiation_safety", 50)) + 5, 0, 100)
	if atmosphere_text.contains("toxic") or atmosphere_text.contains("thin") or atmosphere_text.contains("none"):
		result["atmosphere"] = _clampi(int(result.get("atmosphere", 50)) - 12, 0, 100)
		result["habitability"] = _clampi(int(result.get("habitability", 50)) - 8, 0, 100)
	if gravity_text.contains("earth") or gravity_text.contains("1 g"):
		result["gravity"] = _clampi(int(result.get("gravity", 50)) + 8, 0, 100)
	if preset.contains("lava"):
		result["habitability"] = _clampi(int(result.get("habitability", 50)) - 15, 0, 100)
		result["geology"] = _clampi(int(result.get("geology", 50)) + 16, 0, 100)
	if category == "star" or category == "sun":
		result["radiation_safety"] = _clampi(int(result.get("radiation_safety", 50)) - 34, 0, 100)
		result["gravity"] = _clampi(int(result.get("gravity", 50)) + 18, 0, 100)

	return result


func _normalize_stat_key(title: String) -> String:
	var key := title.strip_edges().to_lower().replace(" ", "_").replace("-", "_")
	if key.contains("habit"):
		return "habitability"
	if key.contains("magnet") or key.contains("field"):
		return "magnetic_field"
	if key.contains("atmos"):
		return "atmosphere"
	if key.contains("geolog") or key.contains("surface") or key.contains("volcan"):
		return "geology"
	if key.contains("grav"):
		return "gravity"
	if key.contains("radiation") or key.contains("safety"):
		return "radiation_safety"
	return ""


func _fallback_score_for_stat(stat_key: String, meta: Dictionary) -> int:
	var category := str(meta.get("category", "planet"))
	var preset: String = str(meta.get("preset", ""))
	var composition: String = str(meta.get("composition", ""))
	var atmosphere_text: String = str(meta.get("atmosphere_text", ""))
	var level_bonus: int = min(int(sqrt(float(max(int(meta.get("level", 1)), 1))) * 4.0), 44)
	var composition_bonus := 0
	if composition.contains("water") or composition.contains("ocean") or atmosphere_text.contains("oxygen") or atmosphere_text.contains("nitrogen"):
		composition_bonus = 8
	elif composition.contains("iron") or composition.contains("metal") or composition.contains("core"):
		composition_bonus = 5

	match category:
		"star", "sun":
			match stat_key:
				"habitability": return 18
				"magnetic_field": return 92
				"atmosphere": return 95
				"geology": return 8
				"gravity": return 100
				"radiation_safety": return 8
		"moon", "satellite":
			match stat_key:
				"habitability": return 26
				"magnetic_field": return 18
				"atmosphere": return 16
				"geology": return 66
				"gravity": return 28
				"radiation_safety": return 36
		"black_hole", "blackhole":
			match stat_key:
				"gravity": return 100
				"radiation_safety": return 2
				_: return 12

	if preset.contains("gas"):
		match stat_key:
			"habitability": return 35
			"magnetic_field": return 78
			"atmosphere": return 88
			"geology": return 18
			"gravity": return 82
			"radiation_safety": return 54

	if preset.contains("ice"):
		match stat_key:
			"habitability": return 42
			"magnetic_field": return 44
			"atmosphere": return 48
			"geology": return 58
			"gravity": return 48
			"radiation_safety": return 58

	match stat_key:
		"habitability", "atmosphere":
			return _clampi(50 + composition_bonus + level_bonus, 0, 100)
		"magnetic_field", "geology":
			return _clampi(50 + int(composition_bonus * 0.7) + level_bonus, 0, 100)
		"radiation_safety":
			return _clampi(50 + int(composition_bonus * 0.5) + level_bonus, 0, 100)
		_:
			return _clampi(50 + level_bonus, 0, 100)


func _stat_role_multiplier(stat_key: String, meta: Dictionary) -> float:
	var category: String = str(meta.get("category", ""))
	var preset: String = str(meta.get("preset", ""))

	if category == "star" or category == "sun":
		match stat_key:
			"magnetic_field", "gravity", "radiation_safety": return 1.85
			"habitability": return 0.42
			"geology": return 0.35
			_: return 1.25

	if category == "moon" or category == "satellite":
		match stat_key:
			"geology", "gravity": return 0.92
			"habitability", "atmosphere": return 0.62
			_: return 0.72

	if preset.contains("gas"):
		match stat_key:
			"magnetic_field", "atmosphere", "gravity": return 1.45
			"geology": return 0.38
			_: return 1.0

	return 1.0


func _estimate_mass_from_category(category: String, preset: String, name: String) -> float:
	if category == "star" or preset == "star" or name.to_lower().contains("sun"):
		return 1800.0
	if category == "black_hole" or preset == "black_hole":
		return 6500.0
	if category == "moon" or category == "satellite" or preset == "moon":
		return 1.0
	if preset.contains("gas"):
		return 90.0
	if preset.contains("ice"):
		return 45.0
	return 15.0


func _mass_to_weight(mass: float, category: String, preset: String) -> float:
	var weight := sqrt(max(mass, 0.001))
	if category == "star" or preset == "star":
		weight *= 0.22
	elif category == "black_hole":
		weight *= 0.16
	elif category == "moon" or category == "satellite":
		weight *= 0.72
	return clamp(weight, 0.45, 8.0)


func _read_value(source, property_name: String, fallback = null):
	if source == null:
		return fallback
	if source is Dictionary:
		return source.get(property_name, fallback)
	if source is Object and _object_has_property(source, property_name):
		return source.get(property_name)
	return fallback


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
	bar.add_theme_stylebox_override("grabber", _scroll_grab_style(false))
	bar.add_theme_stylebox_override("grabber_highlight", _scroll_grab_style(true))
	bar.add_theme_stylebox_override("grabber_pressed", _scroll_grab_style(true))


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


func _scroll_grab_style(hovered: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_SCROLL_GRAB_HOVER if hovered else COLOR_SCROLL_GRAB
	style.border_color = Color.TRANSPARENT
	style.set_border_width_all(0)
	style.set_corner_radius_all(999)
	style.content_margin_left = 3
	style.content_margin_right = 3
	style.content_margin_top = 3
	style.content_margin_bottom = 3
	return style


func _object_has_property(object: Object, property_name: String) -> bool:
	if object == null:
		return false
	for property in object.get_property_list():
		if property.has("name") and str(property["name"]) == property_name:
			return true
	return false


func _format_slider_scale_raw(min_value: float, max_value: float, value) -> String:
	var min_v := float(min_value)
	var max_v := float(max_value)
	var current: float = clamp(float(value), min_v, max_v)
	return _format_number_for_slider("", current)


func _format_slider_scale(slider, value) -> String:
	if not is_instance_valid(slider):
		return str(value)

	var min_v := float(slider.min_value)
	var max_v := float(slider.max_value)
	var current: float = clamp(float(value), min_v, max_v)
	var property_name := ""

	if slider.has_meta("property_name"):
		property_name = str(slider.get_meta("property_name"))

	return _format_number_for_slider(property_name, current)


func _format_number_for_slider(property_name: String, value: float) -> String:
	match property_name:
		"simulation_speed", "revolution_speed_multiplier":
			return "x%.2f" % value
		"center_anchor_strength", "orbit_lock_strength", "drag_throw_strength", "human_drag_influence", "drag_velocity_keep", "binary_mass_similarity":
			return "%d%%" % int(round(value * 100.0))
		"orbit_spacing_multiplier", "moon_orbit_spacing_multiplier", "binary_orbit_spacing_multiplier", "binary_max_distance_multiplier":
			return "x%.2f" % value
		"orbit_distance_padding", "max_drag_throw_speed", "softening_radius", "min_visible_orbit_radius", "max_acceleration", "gravitational_constant":
			return str(int(round(value)))
		"max_trail_points":
			return "OFF" if int(round(value)) <= 0 else str(int(round(value)))
		_:
			if abs(value - round(value)) < 0.001:
				return str(int(round(value)))
			return "%.2f" % value


func _format_value(value) -> String:
	if value is int:
		return str(value)
	var f := float(value)
	if abs(f) >= 100.0:
		return "%d" % int(round(f))
	if abs(f) >= 10.0:
		return "%.1f" % f
	return "%.2f" % f


func _get_left_offscreen_position() -> Vector2:
	var width := _slide_root.size.x if is_instance_valid(_slide_root) else 0.0
	return Vector2(-width - POPUP_SIDE_PADDING, _center_position.y)


func _get_right_offscreen_position() -> Vector2:
	var viewport_width := get_viewport().get_visible_rect().size.x if get_viewport() != null else 0.0
	return Vector2(viewport_width + POPUP_SIDE_PADDING, _center_position.y)


func _on_button_down(button: Button) -> void:
	if _closing or _should_reduce_motion() or not is_instance_valid(button):
		return
	button.pivot_offset = button.size * 0.5
	_tween_button_scale(button, BUTTON_PRESS_SCALE, BUTTON_DOWN_TIME)


func _on_button_up(button: Button) -> void:
	if _closing or not is_instance_valid(button):
		return
	if _should_reduce_motion():
		button.scale = Vector2.ONE
		return
	button.pivot_offset = button.size * 0.5
	_tween_button_scale(button, BUTTON_RELEASE_SCALE, BUTTON_UP_TIME)
	await get_tree().create_timer(BUTTON_UP_TIME).timeout
	if is_instance_valid(button):
		_tween_button_scale(button, Vector2.ONE, BUTTON_SETTLE_TIME)


func _tween_button_scale(button: Button, target_scale: Vector2, duration: float) -> void:
	if not is_instance_valid(button):
		return
	if _button_tween != null and _button_tween.is_valid():
		_button_tween.kill()
	_button_tween = create_tween()
	_button_tween.set_trans(Tween.TRANS_BACK)
	_button_tween.set_ease(Tween.EASE_OUT)
	_button_tween.tween_property(button, "scale", target_scale, duration)


func _theme_panel_color() -> Color:
	if _settings_node != null and _settings_node.has_method("get_panel_color"):
		return _settings_node.call("get_panel_color")

	return Color(0.0, 0.0, 0.0, 0.82)


func _theme_dark_mode() -> bool:
	if _settings_node != null:
		if _object_has_property(_settings_node, "theme_dark_mode"):
			return bool(_settings_node.get("theme_dark_mode"))

		if _object_has_property(_settings_node, "theme_accent_name"):
			var accent := str(_settings_node.get("theme_accent_name")).strip_edges().to_lower()
			return accent == "purple" or accent == "dark"

	return true


func _play_sfx(id: String) -> void:
	if _sfx_node != null and _sfx_node.has_method("play"):
		_sfx_node.call("play", id)


func _clampi(value: int, min_value: int, max_value: int) -> int:
	return int(clamp(value, min_value, max_value))
